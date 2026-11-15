// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Fixture} from "./utils/Fixture.sol";
import {SegmentVault} from "../src/SegmentVault.sol";
import {PieceToken} from "../src/PieceToken.sol";
import {MockB20} from "../src/mocks/MockB20.sol";

contract SegmentVaultTest is Fixture {
    function test_threePiecesNamedWithCollateralDecimals() public view {
        assertEq(vault.pieceCount(), 3);
        assertEq(pieces[SEARCH].symbol(), "SEARCH-GOOGL");
        assertEq(pieces[YOUTUBE].symbol(), "YOUTUBE-GOOGL");
        assertEq(pieces[CLOUD].symbol(), "CLOUD-GOOGL");
        assertEq(pieces[CLOUD].name(), "Alphabet Google Cloud");
        for (uint256 i; i < 3; i++) {
            assertEq(pieces[i].decimals(), 8);
            assertEq(pieces[i].vault(), address(vault));
            assertEq(address(vault.piece(i)), address(pieces[i]));
        }
    }

    function test_constructorRejectsBadPieceCounts() public {
        string[] memory one = new string[](1);
        one[0] = "X";
        vm.expectRevert(SegmentVault.BadPieceCount.selector);
        new SegmentVault(IERC20(address(googl)), one, one);

        string[] memory nine = new string[](9);
        vm.expectRevert(SegmentVault.BadPieceCount.selector);
        new SegmentVault(IERC20(address(googl)), nine, nine);

        string[] memory two = new string[](2);
        vm.expectRevert(SegmentVault.BadPieceCount.selector);
        new SegmentVault(IERC20(address(googl)), two, one); // names length mismatch
    }

    function test_twoPieceVaultAlsoWorks() public {
        string[] memory two = new string[](2);
        two[0] = "A";
        two[1] = "B";
        SegmentVault v = new SegmentVault(IERC20(address(googl)), two, two);
        vm.startPrank(alice);
        googl.approve(address(v), ONE);
        v.split(ONE, alice);
        v.merge(ONE, alice);
        vm.stopPrank();
        assertEq(googl.balanceOf(alice), 1_000 * ONE);
    }

    function test_split_mintsEveryPieceOneForOne() public {
        vm.prank(alice);
        vault.split(10 * ONE, alice);
        _assertBalances(alice, 10 * ONE);
        assertEq(googl.balanceOf(address(vault)), 10 * ONE);
        assertEq(vault.setsOutstanding(), 10 * ONE);
    }

    function test_split_toAnotherAddress() public {
        vm.prank(alice);
        vault.split(3 * ONE, bob);
        _assertBalances(bob, 3 * ONE);
        _assertBalances(alice, 0);
    }

    function test_merge_returnsExactCollateral() public {
        vm.startPrank(alice);
        vault.split(10 * ONE, alice);
        vault.merge(4 * ONE, bob);
        vm.stopPrank();
        assertEq(googl.balanceOf(bob), 1_004 * ONE);
        _assertBalances(alice, 6 * ONE);
        assertEq(googl.balanceOf(address(vault)), 6 * ONE);
    }

    function test_merge_needsEveryPiece() public {
        vm.startPrank(alice);
        vault.split(10 * ONE, alice);
        pieces[YOUTUBE].transfer(bob, 10 * ONE); // missing just one piece
        vm.expectRevert();
        vault.merge(1, alice);
        vm.stopPrank();
    }

    function test_zeroAmountsRevert() public {
        vm.startPrank(alice);
        vm.expectRevert(SegmentVault.ZeroAmount.selector);
        vault.split(0, alice);
        vm.expectRevert(SegmentVault.ZeroAmount.selector);
        vault.merge(0, alice);
        vm.stopPrank();
    }

    function test_pieceMintBurnOnlyVault() public {
        vm.startPrank(alice);
        vm.expectRevert(PieceToken.NotVault.selector);
        pieces[CLOUD].mint(alice, 1);
        vm.expectRevert(PieceToken.NotVault.selector);
        pieces[SEARCH].burn(bob, 1);
        vm.stopPrank();
    }

    // ---------------- issuer controls on the mock ----------------

    function test_blockedHolderExitsToAllowedAddress() public {
        vm.prank(alice);
        vault.split(10 * ONE, alice);
        registry.setBlocked(alice, true);

        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(MockB20.PolicyForbids.selector, alice));
        vault.merge(10 * ONE, alice);

        vm.prank(alice);
        vault.merge(10 * ONE, bob);
        assertEq(googl.balanceOf(bob), 1_010 * ONE);
    }

    function test_blockedVaultStopsDeposits() public {
        registry.setBlocked(address(vault), true);
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(MockB20.PolicyForbids.selector, address(vault)));
        vault.split(ONE, alice);
    }

    function test_pausedToken_actionsRevert_nothingLost() public {
        vm.prank(alice);
        vault.split(10 * ONE, alice);
        googl.pause();

        vm.startPrank(alice);
        vm.expectRevert(abi.encodeWithSelector(MockB20.FeaturePaused.selector, uint8(0)));
        vault.split(ONE, alice);
        vm.expectRevert(abi.encodeWithSelector(MockB20.FeaturePaused.selector, uint8(0)));
        vault.merge(ONE, alice);
        vm.stopPrank();
        _assertBalances(alice, 10 * ONE);

        googl.unpause();
        vm.prank(alice);
        vault.merge(10 * ONE, alice);
        assertEq(googl.balanceOf(alice), 1_000 * ONE);
    }

    function test_multiplierChangeLeavesClaimsAlone() public {
        vm.prank(alice);
        vault.split(10 * ONE, alice);
        googl.setMultiplier(1.05e18);
        vm.prank(alice);
        vault.merge(10 * ONE, alice);
        assertEq(googl.balanceOf(alice), 1_000 * ONE);
    }

    function testFuzz_splitMergeRoundTrip(uint96 a, uint96 b) public {
        a = uint96(bound(a, 1, 1_000 * ONE));
        b = uint96(bound(b, 1, a));
        vm.startPrank(alice);
        vault.split(a, alice);
        vault.merge(b, alice);
        vm.stopPrank();
        assertEq(googl.balanceOf(address(vault)), a - b);
        for (uint256 i; i < 3; i++) {
            assertEq(pieces[i].totalSupply(), a - b);
        }
        assertEq(googl.balanceOf(alice), 1_000 * ONE - a + b);
    }
}
