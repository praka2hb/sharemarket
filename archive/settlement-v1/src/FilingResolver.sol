// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {SegmentVault} from "./SegmentVault.sol";
import "./libraries/SeriesTypes.sol";

/// @notice Settles each series from Alphabet's 8-K earnings release (Exhibit 99.1).
///         Anyone proposes the two revenue figures with a USDC bond; anyone can challenge within the
///         dispute window; a named arbiter decides disputes; a fixed fallback share applies if nothing
///         settles before the fallback deadline.
/// @dev The Cloud share is always computed here from the two figures, never taken as input.
contract FilingResolver is ReentrancyGuard {
    using SafeERC20 for IERC20;

    enum Choice {
        Proposer,
        Challenger,
        Reject
    }

    struct Figures {
        uint256 cloudRev; // USD millions, as printed
        uint256 servicesRev; // USD millions, as printed
        uint32 ppm; // computed
        string accession; // EDGAR accession number
        bytes32 docHash; // SHA-256 of the exhibit file
    }

    struct Proposal {
        address proposer;
        address challenger;
        address arbiter; // arbiter at the time of proposing; only it can decide
        uint64 proposedAt;
        uint256 bond;
        Figures proposed;
        Figures challenged;
    }

    struct SeriesConfig {
        uint32 fallbackPpm;
        bool configured;
        ResolverState state;
        uint256 bond;
    }

    address public constant BURN = 0x000000000000000000000000000000000000dEaD;
    uint32 public constant SANITY_BAND_PPM = 100_000;
    uint256 public constant MAX_REVENUE = 1e15; // USD millions; keeps the ppm math far from overflow

    SegmentVault public immutable vault;
    IERC20 public immutable bondToken;
    address public immutable admin;
    uint64 public immutable disputeWindow;
    uint64 public immutable fallbackDelay;
    address public arbiter;

    mapping(uint256 => SeriesConfig) public configOf;
    mapping(uint256 => Proposal) internal _proposals;

    error NotArbiter();
    error NotConfigured();
    error AlreadyConfigured();
    error BadFigures();
    error WindowOpen();
    error WindowClosed();
    error AlreadyChallenged();
    error SameFigures();
    error NoChallenger();
    error FallbackNotDue();
    error FallbackPassed();

    event SeriesConfigured(uint256 indexed id, uint32 fallbackPpm, uint256 bond);
    event ArbiterSet(address arbiter);
    event Proposed(
        uint256 indexed id,
        address indexed proposer,
        uint256 cloudRev,
        uint256 servicesRev,
        uint32 ppm,
        string accession,
        bytes32 docHash,
        bool outsideBand
    );
    event Challenged(
        uint256 indexed id,
        address indexed challenger,
        uint256 cloudRev,
        uint256 servicesRev,
        uint32 ppm,
        string accession,
        bytes32 docHash
    );
    event Decided(uint256 indexed id, Choice choice, address winner, uint32 ppm, string accession, bytes32 docHash);
    event Rejected(uint256 indexed id, uint256 bondsBurned);
    event Finalized(
        uint256 indexed id, uint32 ppm, uint256 cloudRev, uint256 servicesRev, string accession, bytes32 docHash
    );
    event FallbackFinalized(uint256 indexed id, uint32 ppm);

    constructor(
        SegmentVault vault_,
        IERC20 bondToken_,
        address admin_,
        address arbiter_,
        uint64 disputeWindow_,
        uint64 fallbackDelay_
    ) {
        vault = vault_;
        bondToken = bondToken_;
        admin = admin_;
        arbiter = arbiter_;
        disputeWindow = disputeWindow_;
        fallbackDelay = fallbackDelay_;
        emit ArbiterSet(arbiter_);
    }

    // ------------------------------------------------------------------
    // Admin
    // ------------------------------------------------------------------

    /// @notice Sets a series' fallback share and bond. Once per series.
    function configureSeries(uint256 id, uint32 fallbackPpm, uint256 bond) external {
        if (msg.sender != admin) revert NotAdmin();
        if (id == 0 || id > vault.seriesCount()) revert UnknownSeries();
        if (fallbackPpm > PPM) revert BadPpm();
        SeriesConfig storage c = configOf[id];
        if (c.configured) revert AlreadyConfigured();
        c.configured = true;
        c.fallbackPpm = fallbackPpm;
        c.bond = bond;
        emit SeriesConfigured(id, fallbackPpm, bond);
    }

    /// @notice Changes who decides future disputes. Live proposals keep their arbiter.
    function setArbiter(address arbiter_) external {
        if (msg.sender != admin) revert NotAdmin();
        arbiter = arbiter_;
        emit ArbiterSet(arbiter_);
    }

    // ------------------------------------------------------------------
    // Settlement flow
    // ------------------------------------------------------------------

    function propose(uint256 id, uint256 cloudRev, uint256 servicesRev, string calldata accession, bytes32 docHash)
        external
        nonReentrant
    {
        SeriesConfig storage c = _configured(id);
        if (c.state != ResolverState.Open) revert WrongState();
        if (vault.stateOf(id) != State.Closed) revert WrongState();
        if (block.timestamp >= fallbackAt(id)) revert FallbackPassed();

        uint32 ppm = computePpm(cloudRev, servicesRev);
        bondToken.safeTransferFrom(msg.sender, address(this), c.bond);

        Proposal storage p = _proposals[id];
        p.proposer = msg.sender;
        p.arbiter = arbiter;
        p.proposedAt = uint64(block.timestamp);
        p.bond = c.bond;
        p.proposed = Figures(cloudRev, servicesRev, ppm, accession, docHash);

        bool outside = _distance(ppm, c.fallbackPpm) > SANITY_BAND_PPM;
        c.state = outside ? ResolverState.Disputed : ResolverState.Proposed;
        emit Proposed(id, msg.sender, cloudRev, servicesRev, ppm, accession, docHash, outside);
    }

    function challenge(uint256 id, uint256 cloudRev, uint256 servicesRev, string calldata accession, bytes32 docHash)
        external
        nonReentrant
    {
        SeriesConfig storage c = _configured(id);
        Proposal storage p = _proposals[id];
        if (p.challenger != address(0)) revert AlreadyChallenged();
        if (c.state != ResolverState.Proposed) revert WrongState();
        if (block.timestamp >= p.proposedAt + disputeWindow) revert WindowClosed();
        if (cloudRev == p.proposed.cloudRev && servicesRev == p.proposed.servicesRev) revert SameFigures();

        uint32 ppm = computePpm(cloudRev, servicesRev);
        bondToken.safeTransferFrom(msg.sender, address(this), p.bond);

        p.challenger = msg.sender;
        p.challenged = Figures(cloudRev, servicesRev, ppm, accession, docHash);
        c.state = ResolverState.Disputed;
        emit Challenged(id, msg.sender, cloudRev, servicesRev, ppm, accession, docHash);
    }

    /// @notice Unchallenged proposal becomes final after the window. Bond is returned.
    function settle(uint256 id) external nonReentrant {
        SeriesConfig storage c = _configured(id);
        if (c.state != ResolverState.Proposed) revert WrongState();
        Proposal storage p = _proposals[id];
        if (block.timestamp < p.proposedAt + disputeWindow) revert WindowOpen();

        c.state = ResolverState.Done;
        Figures memory f = p.proposed;
        bondToken.safeTransfer(p.proposer, p.bond);
        vault.finalize(id, f.ppm);
        emit Finalized(id, f.ppm, f.cloudRev, f.servicesRev, f.accession, f.docHash);
    }

    /// @notice Arbiter (as recorded on the proposal) picks proposer, challenger, or rejects.
    function decide(uint256 id, Choice choice) external nonReentrant {
        SeriesConfig storage c = _configured(id);
        if (c.state != ResolverState.Disputed) revert WrongState();
        Proposal storage p = _proposals[id];
        if (msg.sender != p.arbiter) revert NotArbiter();

        bool hasChallenger = p.challenger != address(0);
        uint256 pot = hasChallenger ? p.bond * 2 : p.bond;

        if (choice == Choice.Reject) {
            c.state = ResolverState.Open;
            delete _proposals[id];
            bondToken.safeTransfer(BURN, pot);
            emit Rejected(id, pot);
            return;
        }

        Figures memory f;
        address winner;
        if (choice == Choice.Proposer) {
            f = p.proposed;
            winner = p.proposer;
        } else {
            if (!hasChallenger) revert NoChallenger();
            f = p.challenged;
            winner = p.challenger;
        }

        c.state = ResolverState.Done;
        bondToken.safeTransfer(winner, pot);
        vault.finalize(id, f.ppm);
        emit Decided(id, choice, winner, f.ppm, f.accession, f.docHash);
        emit Finalized(id, f.ppm, f.cloudRev, f.servicesRev, f.accession, f.docHash);
    }

    /// @notice After the fallback deadline, anyone finalizes at the series' fixed fallback share.
    ///         Any posted bonds are returned.
    function fallbackFinalize(uint256 id) external nonReentrant {
        SeriesConfig storage c = _configured(id);
        if (c.state == ResolverState.Done) revert WrongState();
        if (block.timestamp < fallbackAt(id)) revert FallbackNotDue();

        ResolverState prev = c.state;
        c.state = ResolverState.Done;
        if (prev != ResolverState.Open) {
            Proposal storage p = _proposals[id];
            bondToken.safeTransfer(p.proposer, p.bond);
            if (p.challenger != address(0)) bondToken.safeTransfer(p.challenger, p.bond);
        }
        vault.finalize(id, c.fallbackPpm);
        emit FallbackFinalized(id, c.fallbackPpm);
    }

    // ------------------------------------------------------------------
    // Views
    // ------------------------------------------------------------------

    function computePpm(uint256 cloudRev, uint256 servicesRev) public pure returns (uint32) {
        if (cloudRev > MAX_REVENUE || servicesRev > MAX_REVENUE) revert BadFigures();
        uint256 total = cloudRev + servicesRev;
        if (total == 0) revert BadFigures();
        // casting to 'uint32' is safe because cloudRev <= total, so the result is at most PPM (1e6)
        // forge-lint: disable-next-line(unsafe-typecast)
        return uint32(cloudRev * PPM / total);
    }

    function fallbackAt(uint256 id) public view returns (uint256) {
        return uint256(vault.getSeries(id).tradingCloseAt) + fallbackDelay;
    }

    function stateOf(uint256 id) external view returns (ResolverState) {
        return configOf[id].state;
    }

    function getProposal(uint256 id) external view returns (Proposal memory) {
        return _proposals[id];
    }

    // ------------------------------------------------------------------
    // Internal
    // ------------------------------------------------------------------

    function _configured(uint256 id) internal view returns (SeriesConfig storage c) {
        c = configOf[id];
        if (!c.configured) revert NotConfigured();
    }

    function _distance(uint32 a, uint32 b) internal pure returns (uint32) {
        return a > b ? a - b : b - a;
    }
}
