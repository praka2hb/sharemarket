// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Test} from "forge-std/Test.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SegmentVault} from "../../src/SegmentVault.sol";
import {FilingResolver} from "../../src/FilingResolver.sol";
import {PieceToken} from "../../src/PieceToken.sol";
import {MockB20} from "../../src/mocks/MockB20.sol";
import {MockUSDC} from "../../src/mocks/MockUSDC.sol";
import {MockPolicyRegistry} from "../../src/mocks/MockPolicyRegistry.sol";

/// @notice Shared local deployment: mocks, vault, resolver, funded users.
abstract contract Fixture is Test {
    uint256 internal constant ONE = 1e8; // one GOOGLc (8 decimals)
    uint256 internal constant BOND = 1_000e6; // 1,000 mock USDC
    uint64 internal constant WINDOW = 15 minutes;
    uint64 internal constant FALLBACK_DELAY = 1 hours;

    // Real Alphabet figures (USD millions), docs/data/googl-cloud-share-history.csv
    uint256 internal constant Q3_CLOUD = 30_709;
    uint256 internal constant Q3_SERVICES = 96_302;
    uint32 internal constant Q3_PPM = 241_782;
    /// Fallback for a 26Q3 series = latest final share known when it opened (2026Q1).
    uint32 internal constant FALLBACK_PPM = 182_628;
    string internal constant Q3_ACCESSION = "0001652044-26-000080";
    bytes32 internal constant Q3_DOC_HASH = keccak256("q3-2026-ex99.1");

    MockPolicyRegistry internal registry;
    MockB20 internal googl;
    MockUSDC internal usdc;
    SegmentVault internal vault;
    FilingResolver internal resolver;

    address internal admin = makeAddr("admin");
    address internal guardian = makeAddr("guardian");
    address internal arbiter = makeAddr("arbiter");
    address internal alice = makeAddr("alice");
    address internal bob = makeAddr("bob");
    address internal carol = makeAddr("carol");

    function setUp() public virtual {
        registry = new MockPolicyRegistry(address(this));
        googl = new MockB20(address(this), registry, registry.BLOCKLIST_POLICY());
        usdc = new MockUSDC(address(this));
        vault = new SegmentVault(IERC20(address(googl)), admin, guardian);
        resolver = new FilingResolver(vault, IERC20(address(usdc)), admin, arbiter, WINDOW, FALLBACK_DELAY);
        vault.setResolver(address(resolver));

        address[3] memory users = [alice, bob, carol];
        for (uint256 i; i < users.length; i++) {
            googl.mint(users[i], 1_000 * ONE);
            usdc.mint(users[i], 10_000e6);
            vm.startPrank(users[i]);
            googl.approve(address(vault), type(uint256).max);
            usdc.approve(address(resolver), type(uint256).max);
            vm.stopPrank();
        }
    }

    function _createSeries(string memory label, uint64 closeAt) internal returns (uint256 id) {
        vm.prank(admin);
        id = vault.createSeries(label, closeAt, keccak256(bytes(label)));
        vm.prank(admin);
        resolver.configureSeries(id, FALLBACK_PPM, BOND);
    }

    function _cloud(uint256 id) internal view returns (PieceToken) {
        return PieceToken(vault.getSeries(id).cloud);
    }

    function _svcs(uint256 id) internal view returns (PieceToken) {
        return PieceToken(vault.getSeries(id).services);
    }

    function _closeAt() internal view returns (uint64) {
        return uint64(block.timestamp + 1 days);
    }
}
