// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Fixture} from "./utils/Fixture.sol";
import {SegmentVault} from "../src/SegmentVault.sol";
import {PieceToken} from "../src/PieceToken.sol";
import {MockB20} from "../src/mocks/MockB20.sol";
import "../src/libraries/SeriesTypes.sol";

contract SegmentVaultTest is Fixture {
    uint256 internal id;

    function setUp() public override {
        super.setUp();
        id = _createSeries("26Q3", _closeAt());
    }

    /// A vault where this test contract is the resolver, so any ppm can be finalized directly.
    function _vaultFinalAt(uint32 ppm, uint256 amount) internal returns (SegmentVault v, uint256 sid) {
        v = new SegmentVault(IERC20(address(googl)), admin, guardian);
        v.setResolver(address(this));
        vm.prank(admin);
        sid = v.createSeries("T", _closeAt(), bytes32(0));
        vm.startPrank(alice);
        googl.approve(address(v), type(uint256).max);
        v.split(sid, amount);
        vm.stopPrank();
        vm.warp(block.timestamp + 1 days);
        v.finalize(sid, ppm);
    }

    // ---------------- series creation ----------------

    function test_createSeries_namesDecimalsAndState() public view {
        PieceToken c = _cloud(id);
        PieceToken s = _svcs(id);
        assertEq(c.symbol(), "CLOUD-GOOGL-26Q3");
        assertEq(s.symbol(), "SVCS-GOOGL-26Q3");
        assertEq(c.decimals(), 8);
        assertEq(s.decimals(), 8);
        assertEq(uint8(vault.stateOf(id)), uint8(State.Trading));
        assertEq(vault.seriesOfToken(address(c)), id);
        assertEq(vault.getSeries(id).ruleHash, keccak256("26Q3"));
    }

    function test_seriesOfToken_revertsForOtherAddresses() public {
        address svcs = address(_svcs(id));
        vm.expectRevert(UnknownSeries.selector);
        vault.seriesOfToken(svcs);
        vm.expectRevert(UnknownSeries.selector);
        vault.seriesOfToken(address(googl));
    }

    function test_unknownSeriesReverts() public {
        vm.expectRevert(UnknownSeries.selector);
        vault.stateOf(0);
        vm.expectRevert(UnknownSeries.selector);
        vm.prank(alice);
        vault.split(99, ONE);
    }

    function test_createSeries_rejectsPastClose() public {
        vm.prank(admin);
        vm.expectRevert(BadTime.selector);
        vault.createSeries("X", uint64(block.timestamp), bytes32(0));
    }

    // ---------------- split / merge ----------------

    function test_split_mintsBothPiecesOneForOne() public {
        vm.prank(alice);
        vault.split(id, 10 * ONE);
        assertEq(_cloud(id).balanceOf(alice), 10 * ONE);
        assertEq(_svcs(id).balanceOf(alice), 10 * ONE);
        assertEq(googl.balanceOf(address(vault)), 10 * ONE);
        assertEq(vault.getSeries(id).collateral, 10 * ONE);
        assertEq(vault.owed(id), 10 * ONE);
    }

    function test_merge_returnsExactCollateralToAnyAddress() public {
        vm.startPrank(alice);
        vault.split(id, 10 * ONE);
        vault.merge(id, 4 * ONE, bob);
        vm.stopPrank();
        assertEq(googl.balanceOf(bob), 1_004 * ONE);
        assertEq(_cloud(id).balanceOf(alice), 6 * ONE);
        assertEq(vault.getSeries(id).collateral, 6 * ONE);
    }

    function test_merge_needsBothPieces() public {
        vm.prank(alice);
        vault.split(id, 10 * ONE);
        PieceToken cloud = _cloud(id);
        vm.prank(alice);
        cloud.transfer(bob, 10 * ONE);
        vm.prank(alice);
        vm.expectRevert();
        vault.merge(id, 1, alice);
    }

    function test_zeroAmountsRevert() public {
        vm.startPrank(alice);
        vm.expectRevert(ZeroAmount.selector);
        vault.split(id, 0);
        vm.expectRevert(ZeroAmount.selector);
        vault.merge(id, 0, alice);
        vm.stopPrank();
    }

    // ---------------- lifecycle ----------------

    function test_closesByTimeWithoutAWrite() public {
        vm.warp(block.timestamp + 1 days);
        assertEq(uint8(vault.stateOf(id)), uint8(State.Closed));
        assertEq(uint8(vault.getSeries(id).state), uint8(State.Closed));
    }

    function test_splitAndMergeAllowedWhileClosed() public {
        vm.warp(block.timestamp + 1 days);
        vm.startPrank(alice);
        vault.split(id, ONE);
        vault.merge(id, ONE, alice);
        vm.stopPrank();
    }

    function test_redeemBlockedBeforeFinal() public {
        vm.prank(alice);
        vault.split(id, ONE);
        vm.prank(alice);
        vm.expectRevert(WrongState.selector);
        vault.redeem(id, ONE, 0, alice);
        vm.warp(block.timestamp + 1 days);
        vm.prank(alice);
        vm.expectRevert(WrongState.selector);
        vault.redeem(id, ONE, 0, alice);
    }

    function test_splitBlockedAfterFinal_mergeStillWorks() public {
        (SegmentVault v, uint256 sid) = _vaultFinalAt(Q3_PPM, 10 * ONE);
        vm.startPrank(alice);
        vm.expectRevert(WrongState.selector);
        v.split(sid, ONE);
        v.merge(sid, ONE, alice);
        vm.stopPrank();
    }

    function test_finalizeOnlyFromClosed() public {
        SegmentVault v = new SegmentVault(IERC20(address(googl)), admin, guardian);
        v.setResolver(address(this));
        vm.prank(admin);
        uint256 sid = v.createSeries("T", _closeAt(), bytes32(0));
        vm.expectRevert(WrongState.selector);
        v.finalize(sid, Q3_PPM); // still Trading
        vm.warp(block.timestamp + 1 days);
        v.finalize(sid, Q3_PPM);
        vm.expectRevert(WrongState.selector);
        v.finalize(sid, 500_000); // already Final
        assertEq(v.getSeries(sid).cloudPpm, Q3_PPM);
    }

    function test_finalizeRejectsPpmAboveOneMillion() public {
        SegmentVault v = new SegmentVault(IERC20(address(googl)), admin, guardian);
        v.setResolver(address(this));
        vm.prank(admin);
        uint256 sid = v.createSeries("T", _closeAt(), bytes32(0));
        vm.warp(block.timestamp + 1 days);
        vm.expectRevert(BadPpm.selector);
        v.finalize(sid, 1_000_001);
    }

    function test_closeEarly_onlyGuardian_neverReopens() public {
        vm.prank(alice);
        vm.expectRevert(NotGuardian.selector);
        vault.closeEarly(id);

        vm.prank(guardian);
        vault.closeEarly(id);
        assertEq(uint8(vault.stateOf(id)), uint8(State.Closed));

        vm.prank(guardian);
        vm.expectRevert(WrongState.selector);
        vault.closeEarly(id);
    }

    // ---------------- redeem ----------------

    /// CUJ 5: 10 $CLOUD at the Q3 2026 share pays exactly 2.41782000 GOOGLc.
    function test_redeem_cuj5_realQ3Share() public {
        (SegmentVault v, uint256 sid) = _vaultFinalAt(Q3_PPM, 10 * ONE);
        uint256 before = googl.balanceOf(alice);
        vm.prank(alice);
        uint256 paid = v.redeem(sid, 10 * ONE, 0, alice);
        assertEq(paid, 241_782_000);
        assertEq(googl.balanceOf(alice) - before, 241_782_000);

        vm.prank(alice);
        paid = v.redeem(sid, 0, 10 * ONE, alice);
        assertEq(paid, 758_218_000);
        assertEq(googl.balanceOf(address(v)), 0);
    }

    function test_redeem_edgePpms() public {
        uint32[4] memory ppms = [uint32(0), 1, 999_999, 1_000_000];
        for (uint256 i; i < ppms.length; i++) {
            (SegmentVault v, uint256 sid) = _vaultFinalAt(ppms[i], 3 * ONE + 7);
            vm.startPrank(alice);
            uint256 a = v.redeem(sid, 3 * ONE + 7, 0, alice);
            uint256 b = v.redeem(sid, 0, 3 * ONE + 7, alice);
            vm.stopPrank();
            assertEq(a, (3 * ONE + 7) * ppms[i] / PPM);
            assertEq(b, (3 * ONE + 7) * (PPM - ppms[i]) / PPM);
            assertLe(a + b, 3 * ONE + 7);
            assertGe(a + b + 1, 3 * ONE + 7, "more than 1 unit of dust");
            assertEq(googl.balanceOf(address(v)), 3 * ONE + 7 - a - b);
        }
    }

    function testFuzz_redeemNeverPaysMoreThanHeld(uint32 ppm, uint96 amount, uint96 cloudPart, uint96 svcsPart) public {
        ppm = uint32(bound(ppm, 0, PPM));
        amount = uint96(bound(amount, 1, 1_000 * ONE));
        cloudPart = uint96(bound(cloudPart, 0, amount));
        svcsPart = uint96(bound(svcsPart, 0, amount));
        vm.assume(cloudPart != 0 || svcsPart != 0);
        (SegmentVault v, uint256 sid) = _vaultFinalAt(ppm, amount);

        vm.startPrank(alice);
        v.redeem(sid, cloudPart, svcsPart, alice);
        if (amount - cloudPart != 0 || amount - svcsPart != 0) {
            v.redeem(sid, amount - cloudPart, amount - svcsPart, alice);
        }
        vm.stopPrank();
        assertEq(googl.balanceOf(address(v)), v.getSeries(sid).collateral);
        // Four floored terms across two redeems: under 1 unit each.
        assertLe(v.getSeries(sid).collateral, 3, "dust above 3 units");
    }

    function test_redeemToAnotherAddress() public {
        (SegmentVault v, uint256 sid) = _vaultFinalAt(Q3_PPM, 10 * ONE);
        uint256 before = googl.balanceOf(bob);
        vm.prank(alice);
        v.redeem(sid, 10 * ONE, 0, bob);
        assertEq(googl.balanceOf(bob) - before, 241_782_000);
    }

    // ---------------- deposit cap ----------------

    function test_depositCap() public {
        vm.prank(alice);
        vm.expectRevert(NotAdmin.selector);
        vault.setDepositCap(id, 5 * ONE);

        vm.prank(admin);
        vault.setDepositCap(id, 5 * ONE);
        vm.startPrank(alice);
        vault.split(id, 5 * ONE);
        vm.expectRevert(CapExceeded.selector);
        vault.split(id, 1);
        vault.merge(id, 5 * ONE, alice); // cap never blocks merge
        vm.stopPrank();
    }

    // ---------------- issuer controls on the mock ----------------

    function test_blockedHolderExitsToAllowedAddress() public {
        vm.prank(alice);
        vault.split(id, 10 * ONE);
        registry.setBlocked(alice, true);

        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(MockB20.PolicyForbids.selector, alice));
        vault.merge(id, 10 * ONE, alice);

        vm.prank(alice);
        vault.merge(id, 10 * ONE, bob);
        assertEq(googl.balanceOf(bob), 1_010 * ONE);
    }

    function test_blockedVaultStopsDeposits() public {
        registry.setBlocked(address(vault), true);
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(MockB20.PolicyForbids.selector, address(vault)));
        vault.split(id, ONE);
    }

    function test_pausedToken_actionsRevert_nothingLost() public {
        vm.prank(alice);
        vault.split(id, 10 * ONE);
        googl.pause();
        assertEq(googl.pausedFeatures().length, 1);

        vm.startPrank(alice);
        vm.expectRevert(abi.encodeWithSelector(MockB20.FeaturePaused.selector, uint8(0)));
        vault.split(id, ONE);
        vm.expectRevert(abi.encodeWithSelector(MockB20.FeaturePaused.selector, uint8(0)));
        vault.merge(id, ONE, alice);
        vm.stopPrank();

        assertEq(_cloud(id).balanceOf(alice), 10 * ONE);
        assertEq(vault.getSeries(id).collateral, 10 * ONE);

        googl.unpause();
        vm.prank(alice);
        vault.merge(id, 10 * ONE, alice);
        assertEq(googl.balanceOf(alice), 1_000 * ONE);
    }

    function test_multiplierChangeLeavesClaimsAlone() public {
        vm.prank(alice);
        vault.split(id, 10 * ONE);
        googl.setMultiplier(1.05e18);
        vm.prank(alice);
        vault.merge(id, 10 * ONE, alice);
        assertEq(googl.balanceOf(alice), 1_000 * ONE);
    }

    // ---------------- access control (design section 8) ----------------

    function test_onlyAdminCreatesSeries() public {
        vm.prank(alice);
        vm.expectRevert(NotAdmin.selector);
        vault.createSeries("X", _closeAt(), bytes32(0));
    }

    function test_onlyResolverFinalizes() public {
        vm.warp(block.timestamp + 1 days);
        vm.prank(admin);
        vm.expectRevert(NotResolver.selector);
        vault.finalize(id, Q3_PPM);
    }

    function test_pieceMintBurnOnlyVault() public {
        PieceToken c = _cloud(id);
        vm.startPrank(admin);
        vm.expectRevert(NotVault.selector);
        c.mint(admin, 1);
        vm.expectRevert(NotVault.selector);
        c.burn(alice, 1);
        vm.stopPrank();
    }

    function test_setResolver_onceOnlyDeployerOnlyBeforeSeries() public {
        // Already set in the fixture.
        vm.expectRevert(WrongState.selector);
        vault.setResolver(alice);

        SegmentVault v = new SegmentVault(IERC20(address(googl)), admin, guardian);
        vm.prank(alice);
        vm.expectRevert(NotDeployer.selector);
        v.setResolver(alice);

        vm.expectRevert(WrongState.selector);
        v.setResolver(address(0));

        // No series before a resolver exists.
        vm.prank(admin);
        vm.expectRevert(WrongState.selector);
        v.createSeries("X", _closeAt(), bytes32(0));

        v.setResolver(address(this));
        vm.expectRevert(WrongState.selector);
        v.setResolver(alice);
    }
}
