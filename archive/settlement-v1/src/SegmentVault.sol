// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {PieceToken} from "./PieceToken.sol";
import "./libraries/SeriesTypes.sol";

/// @notice Holds GOOGLc and splits it into $CLOUD + $SERVICES per quarter ("series").
///         After the resolver sets Cloud's share, each piece redeems for its slice of the GOOGLc.
/// @dev The only ways GOOGLc leaves this contract are `merge` and `redeem`. There is no admin
///      withdrawal and no pause in this contract.
contract SegmentVault is ReentrancyGuard {
    using SafeERC20 for IERC20;

    IERC20 public immutable collateralToken;
    uint8 public immutable collateralDecimals;
    address public immutable admin;
    address public immutable guardian;
    address public immutable deployer;
    address public resolver;

    /// @notice Series ids start at 1, so 0 means "no series".
    uint256 public seriesCount;
    mapping(uint256 => Series) internal _series;
    mapping(address => uint256) internal _seriesOfCloud;

    event ResolverSet(address resolver);
    event SeriesCreated(
        uint256 indexed id, string label, address cloud, address services, uint64 tradingCloseAt, bytes32 ruleHash
    );
    event DepositCapSet(uint256 indexed id, uint256 cap);
    event Split(uint256 indexed id, address indexed user, uint256 amount);
    event Merged(uint256 indexed id, address indexed user, address to, uint256 amount);
    event Redeemed(uint256 indexed id, address indexed user, address to, uint256 cloudAmt, uint256 svcsAmt, uint256 paid);
    event Closed(uint256 indexed id, bool early);
    event Finalized(uint256 indexed id, uint32 cloudPpm);

    constructor(IERC20 collateralToken_, address admin_, address guardian_) {
        collateralToken = collateralToken_;
        collateralDecimals = IERC20Metadata(address(collateralToken_)).decimals();
        admin = admin_;
        guardian = guardian_;
        deployer = msg.sender;
    }

    // ------------------------------------------------------------------
    // Setup and admin
    // ------------------------------------------------------------------

    /// @notice Sets the only address allowed to call `finalize`. Once, by the deployer, before any series.
    function setResolver(address resolver_) external {
        if (msg.sender != deployer) revert NotDeployer();
        if (resolver != address(0) || seriesCount != 0 || resolver_ == address(0)) revert WrongState();
        resolver = resolver_;
        emit ResolverSet(resolver_);
    }

    /// @notice Opens a new quarter in Trading. Deploys its two piece tokens.
    function createSeries(string calldata label, uint64 tradingCloseAt, bytes32 ruleHash)
        external
        returns (uint256 id)
    {
        if (msg.sender != admin) revert NotAdmin();
        if (resolver == address(0)) revert WrongState();
        if (tradingCloseAt <= block.timestamp) revert BadTime();

        id = ++seriesCount;
        string memory cloudName = string.concat("CLOUD-GOOGL-", label);
        string memory svcsName = string.concat("SVCS-GOOGL-", label);
        PieceToken cloud = new PieceToken(cloudName, cloudName, collateralDecimals);
        PieceToken services = new PieceToken(svcsName, svcsName, collateralDecimals);

        Series storage s = _series[id];
        s.cloud = address(cloud);
        s.services = address(services);
        s.tradingCloseAt = tradingCloseAt;
        s.ruleHash = ruleHash;
        s.state = State.Trading;
        _seriesOfCloud[address(cloud)] = id;

        emit SeriesCreated(id, label, address(cloud), address(services), tradingCloseAt, ruleHash);
    }

    /// @notice Limits new splits in a series. 0 means no cap. Cannot affect merge or redeem.
    function setDepositCap(uint256 id, uint256 cap) external {
        if (msg.sender != admin) revert NotAdmin();
        _get(id).depositCap = cap;
        emit DepositCapSet(id, cap);
    }

    /// @notice Guardian closes trading early. Can never reopen.
    function closeEarly(uint256 id) external {
        if (msg.sender != guardian) revert NotGuardian();
        Series storage s = _sync(id);
        if (s.state != State.Trading) revert WrongState();
        s.state = State.Closed;
        emit Closed(id, true);
    }

    /// @notice Resolver sets the final Cloud share. Only from Closed.
    function finalize(uint256 id, uint32 ppm) external {
        if (msg.sender != resolver) revert NotResolver();
        if (ppm > PPM) revert BadPpm();
        Series storage s = _sync(id);
        if (s.state != State.Closed) revert WrongState();
        s.cloudPpm = ppm;
        s.state = State.Final;
        emit Finalized(id, ppm);
    }

    /// @notice Moves Trading -> Closed once tradingCloseAt has passed. Anyone can call.
    function poke(uint256 id) external {
        _sync(id);
    }

    // ------------------------------------------------------------------
    // User actions
    // ------------------------------------------------------------------

    /// @notice Deposit `amount` GOOGLc, receive `amount` $CLOUD and `amount` $SERVICES.
    function split(uint256 id, uint256 amount) external nonReentrant {
        if (amount == 0) revert ZeroAmount();
        Series storage s = _sync(id);
        if (s.state == State.Final) revert WrongState();
        if (s.depositCap != 0 && s.collateral + amount > s.depositCap) revert CapExceeded();

        uint256 before = collateralToken.balanceOf(address(this));
        collateralToken.safeTransferFrom(msg.sender, address(this), amount);
        if (collateralToken.balanceOf(address(this)) - before != amount) revert TransferMismatch();

        s.collateral += amount;
        PieceToken(s.cloud).mint(msg.sender, amount);
        PieceToken(s.services).mint(msg.sender, amount);
        emit Split(id, msg.sender, amount);
    }

    /// @notice Burn `amount` of each piece and receive `amount` GOOGLc at `to`. Works in every state.
    function merge(uint256 id, uint256 amount, address to) external nonReentrant {
        if (amount == 0) revert ZeroAmount();
        Series storage s = _sync(id);

        PieceToken(s.cloud).burn(msg.sender, amount);
        PieceToken(s.services).burn(msg.sender, amount);
        s.collateral -= amount;
        collateralToken.safeTransfer(to, amount);
        emit Merged(id, msg.sender, to, amount);
    }

    /// @notice After Final, burn pieces and receive their GOOGLc value at `to`.
    function redeem(uint256 id, uint256 cloudAmt, uint256 svcsAmt, address to)
        external
        nonReentrant
        returns (uint256 paid)
    {
        if (cloudAmt == 0 && svcsAmt == 0) revert ZeroAmount();
        Series storage s = _get(id);
        if (s.state != State.Final) revert WrongState();

        paid = _payout(cloudAmt, svcsAmt, s.cloudPpm);
        if (cloudAmt != 0) PieceToken(s.cloud).burn(msg.sender, cloudAmt);
        if (svcsAmt != 0) PieceToken(s.services).burn(msg.sender, svcsAmt);
        s.collateral -= paid;
        if (paid != 0) collateralToken.safeTransfer(to, paid);
        emit Redeemed(id, msg.sender, to, cloudAmt, svcsAmt, paid);
    }

    // ------------------------------------------------------------------
    // Views
    // ------------------------------------------------------------------

    /// @notice State including time: reports Closed once tradingCloseAt passes, even before a write.
    function stateOf(uint256 id) public view returns (State) {
        Series storage s = _get(id);
        if (s.state == State.Trading && block.timestamp >= s.tradingCloseAt) return State.Closed;
        return s.state;
    }

    function getSeries(uint256 id) external view returns (Series memory s) {
        s = _get(id);
        s.state = stateOf(id);
    }

    /// @notice Series id for a $CLOUD token. Reverts for any other address.
    function seriesOfToken(address cloud) external view returns (uint256 id) {
        id = _seriesOfCloud[cloud];
        if (id == 0) revert UnknownSeries();
    }

    /// @notice GOOGLc the vault owes all holders of this series (rounded up).
    function owed(uint256 id) external view returns (uint256) {
        Series storage s = _get(id);
        uint256 cloudSupply = PieceToken(s.cloud).totalSupply();
        if (s.state != State.Final) return cloudSupply;
        uint256 svcsSupply = PieceToken(s.services).totalSupply();
        return Math.ceilDiv(cloudSupply * s.cloudPpm + svcsSupply * (PPM - s.cloudPpm), PPM);
    }

    /// @notice What `redeem` would pay right now for these amounts at `ppm`.
    function previewRedeem(uint256 cloudAmt, uint256 svcsAmt, uint32 ppm) external pure returns (uint256) {
        return _payout(cloudAmt, svcsAmt, ppm);
    }

    // ------------------------------------------------------------------
    // Internal
    // ------------------------------------------------------------------

    function _get(uint256 id) internal view returns (Series storage s) {
        if (id == 0 || id > seriesCount) revert UnknownSeries();
        s = _series[id];
    }

    function _sync(uint256 id) internal returns (Series storage s) {
        s = _get(id);
        if (s.state == State.Trading && block.timestamp >= s.tradingCloseAt) {
            s.state = State.Closed;
            emit Closed(id, false);
        }
    }

    function _payout(uint256 cloudAmt, uint256 svcsAmt, uint32 ppm) internal pure returns (uint256) {
        return cloudAmt * ppm / PPM + svcsAmt * (PPM - ppm) / PPM;
    }
}
