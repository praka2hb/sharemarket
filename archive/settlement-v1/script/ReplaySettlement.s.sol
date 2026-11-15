// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Script, console2} from "forge-std/Script.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SegmentVault} from "../src/SegmentVault.sol";
import {FilingResolver} from "../src/FilingResolver.sol";
import {MockB20} from "../src/mocks/MockB20.sol";
import {Faucet} from "../src/mocks/Faucet.sol";
import {Series, State, ResolverState} from "../src/libraries/SeriesTypes.sol";

/// @notice The demo settlement replay (CUJ 4 and 5) on a separate "26Q3-replay" series, so the live
///         26Q4 market is never touched. Each step is its own run, signed by the wallet that plays
///         that role:
///
///           1. setup      admin/guardian  create the replay series, split 10 GOOGLc, close early
///           2. propose    wallet A        propose WRONG figures (Cloud typed as 20,709)
///           3. challenge  wallet B        challenge with Alphabet's real Q3 2026 figures
///                                         (must be within the 15-minute dispute window)
///           4. decide     arbiter         side with the challenger
///           5. redeem     admin           redeem 10 $CLOUD (-> 2.41782 GOOGLc) and 10 $SERVICES
///           status        anyone          print where the replay stands (no transactions)
///
///         Run a step with: --sig "propose()" (etc.). Env: DEPLOYMENTS_FILE, LABEL (default
///         "26Q3-replay"), DOC_HASH (SHA-256 of Alphabet's Q3 2026 Exhibit 99.1).
contract ReplaySettlement is Script {
    // Alphabet Q3 2026 earnings release (docs/data/googl-cloud-share-history.csv).
    uint256 internal constant Q3_CLOUD = 30_709;
    uint256 internal constant Q3_SERVICES = 96_302;
    string internal constant Q3_ACCESSION = "0001652044-26-000080";
    /// The wrong proposal: one digit off in the Cloud figure. Inside the 10-point sanity band.
    uint256 internal constant WRONG_CLOUD = 20_709;
    /// Fallback for a Q3 series = the latest final share when it opened (Q1 2026).
    uint32 internal constant REPLAY_FALLBACK_PPM = 182_628;
    uint256 internal constant HOLDING = 10e8; // 10 GOOGLc split for the redemption step

    SegmentVault internal vault;
    FilingResolver internal resolver;
    MockB20 internal googl;
    IERC20 internal usdc;
    Faucet internal faucet;
    string internal depFile;
    string internal label;

    function _load() internal {
        depFile = vm.envOr("DEPLOYMENTS_FILE", string("../deployments/base-sepolia.json"));
        label = vm.envOr("LABEL", string("26Q3-replay"));
        string memory dep = vm.readFile(depFile);
        vault = SegmentVault(vm.parseJsonAddress(dep, ".vault"));
        resolver = FilingResolver(vm.parseJsonAddress(dep, ".resolver"));
        googl = MockB20(vm.parseJsonAddress(dep, ".googl"));
        usdc = IERC20(vm.parseJsonAddress(dep, ".usdc"));
        faucet = Faucet(vm.parseJsonAddress(dep, ".faucet"));
    }

    function _seriesFile() internal view returns (string memory) {
        return string.concat(depFile, ".series-", label, ".json");
    }

    function _id() internal view returns (uint256) {
        return vm.parseJsonUint(vm.readFile(_seriesFile()), ".id");
    }

    function _docHash() internal view returns (bytes32 h) {
        h = vm.envOr("DOC_HASH", bytes32(0));
        if (h == bytes32(0)) {
            console2.log("WARNING: DOC_HASH not set; the exhibit hash on-chain will be zero.");
            console2.log("Set DOC_HASH to the SHA-256 of Alphabet's Q3 2026 Exhibit 99.1 for the real demo.");
        }
    }

    /// Makes sure the signing wallet holds one bond in mock USDC (faucet, once per 24 hours).
    function _ensureBond(address me) internal {
        (,,, uint256 bond) = resolver.configOf(_id());
        if (usdc.balanceOf(me) < bond) faucet.claim();
        usdc.approve(address(resolver), bond);
    }

    // ------------------------------------------------------------------
    // Steps
    // ------------------------------------------------------------------

    function setup() external {
        _load();
        vm.startBroadcast();
        (, address me,) = vm.readCallers();
        uint64 closeAt = uint64(block.timestamp + 1 days);
        bytes32 ruleHash = keccak256(bytes(vm.readFile("../docs/rules/GOOGL-segment-rule-v1.md")));
        uint256 id = vault.createSeries(label, closeAt, ruleHash);
        resolver.configureSeries(id, REPLAY_FALLBACK_PPM, 1_000e6);

        googl.mint(me, HOLDING);
        googl.approve(address(vault), HOLDING);
        vault.split(id, HOLDING);
        vault.closeEarly(id); // guardian: results are out, trading stops
        vm.stopBroadcast();

        string memory k = "replay";
        vm.serializeString(k, "label", label);
        vm.serializeUint(k, "id", id);
        vm.serializeAddress(k, "holder", me);
        vm.serializeUint(k, "fallbackPpm", REPLAY_FALLBACK_PPM);
        string memory json = vm.serializeAddress(k, "cloud", vault.getSeries(id).cloud);
        vm.writeJson(json, _seriesFile());
        console2.log("replay series id", id, "closed early; written to", _seriesFile());
    }

    function propose() external {
        _load();
        uint256 id = _id();
        vm.startBroadcast();
        (, address me,) = vm.readCallers();
        _ensureBond(me);
        resolver.propose(id, WRONG_CLOUD, Q3_SERVICES, Q3_ACCESSION, _docHash());
        vm.stopBroadcast();
        console2.log("wrong proposal posted, ppm", resolver.computePpm(WRONG_CLOUD, Q3_SERVICES));
        console2.log("challenge before unix time", resolver.getProposal(id).proposedAt + resolver.disputeWindow());
    }

    function challenge() external {
        _load();
        uint256 id = _id();
        vm.startBroadcast();
        (, address me,) = vm.readCallers();
        _ensureBond(me);
        resolver.challenge(id, Q3_CLOUD, Q3_SERVICES, Q3_ACCESSION, _docHash());
        vm.stopBroadcast();
        console2.log("challenged with real figures, ppm", resolver.computePpm(Q3_CLOUD, Q3_SERVICES));
    }

    function decide() external {
        _load();
        uint256 id = _id();
        vm.startBroadcast();
        resolver.decide(id, FilingResolver.Choice.Challenger);
        vm.stopBroadcast();
        console2.log("arbiter sided with the challenger; final ppm", vault.getSeries(id).cloudPpm);
    }

    function redeem() external {
        _load();
        uint256 id = _id();
        Series memory s = vault.getSeries(id);
        vm.startBroadcast();
        (, address me,) = vm.readCallers();
        uint256 c = IERC20(s.cloud).balanceOf(me);
        uint256 v = IERC20(s.services).balanceOf(me);
        uint256 paidCloud = c == 0 ? 0 : vault.redeem(id, c, 0, me);
        uint256 paidSvcs = v == 0 ? 0 : vault.redeem(id, 0, v, me);
        vm.stopBroadcast();
        console2.log("redeemed $CLOUD", c, "-> GOOGLc units", paidCloud);
        console2.log("redeemed $SERVICES", v, "-> GOOGLc units", paidSvcs);
    }

    function status() external {
        _load();
        uint256 id = _id();
        Series memory s = vault.getSeries(id);
        FilingResolver.Proposal memory p = resolver.getProposal(id);
        console2.log("series", id, label);
        console2.log("vault state (0 Trading, 1 Closed, 2 Final)", uint8(s.state));
        console2.log("resolver state (0 Open, 1 Proposed, 2 Disputed, 3 Done)", uint8(resolver.stateOf(id)));
        console2.log("final ppm", s.cloudPpm);
        console2.log("proposer", p.proposer, "ppm", p.proposed.ppm);
        console2.log("challenger", p.challenger, "ppm", p.challenged.ppm);
        if (p.proposedAt != 0) {
            console2.log("dispute window ends", p.proposedAt + resolver.disputeWindow(), "now", block.timestamp);
        }
    }
}
