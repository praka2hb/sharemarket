// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Test} from "forge-std/Test.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SegmentVault} from "../../src/SegmentVault.sol";
import {PieceToken} from "../../src/PieceToken.sol";
import {MockB20} from "../../src/mocks/MockB20.sol";
import {MockPolicyRegistry} from "../../src/mocks/MockPolicyRegistry.sol";

/// @notice Shared local setup: mock GOOGLc with its blocklist, a 3-piece GOOGL vault, funded users.
abstract contract Fixture is Test {
    uint256 internal constant ONE = 1e8; // one stock token (8 decimals)
    uint256 internal constant SEARCH = 0;
    uint256 internal constant YOUTUBE = 1;
    uint256 internal constant CLOUD = 2;

    MockPolicyRegistry internal registry;
    MockB20 internal googl;
    SegmentVault internal vault;
    PieceToken[] internal pieces;

    address internal alice = makeAddr("alice");
    address internal bob = makeAddr("bob");
    address internal carol = makeAddr("carol");

    function setUp() public virtual {
        registry = new MockPolicyRegistry(address(this));
        googl = new MockB20("Alphabet Inc. (mock)", "GOOGLc", address(this), registry, registry.BLOCKLIST_POLICY());
        vault = new SegmentVault(IERC20(address(googl)), _symbols(), _names());
        PieceToken[] memory ps = vault.pieces();
        for (uint256 i; i < ps.length; i++) {
            pieces.push(ps[i]);
        }

        address[3] memory users = [alice, bob, carol];
        for (uint256 i; i < users.length; i++) {
            googl.mint(users[i], 1_000 * ONE);
            vm.prank(users[i]);
            googl.approve(address(vault), type(uint256).max);
        }
    }

    function _symbols() internal pure returns (string[] memory s) {
        s = new string[](3);
        s[0] = "SEARCH-GOOGL";
        s[1] = "YOUTUBE-GOOGL";
        s[2] = "CLOUD-GOOGL";
    }

    function _names() internal pure returns (string[] memory s) {
        s = new string[](3);
        s[0] = "Alphabet Search";
        s[1] = "Alphabet YouTube Ads";
        s[2] = "Alphabet Google Cloud";
    }

    function _assertBalances(address who, uint256 expected) internal view {
        for (uint256 i; i < pieces.length; i++) {
            assertEq(pieces[i].balanceOf(who), expected);
        }
    }
}
