// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {MarketFixture} from "./utils/MarketFixture.sol";
import {SegmentRouter} from "../src/SegmentRouter.sol";
import {IV4Router} from "@uniswap/v4-periphery/src/interfaces/IV4Router.sol";

contract SegmentRouterTest is MarketFixture {
    uint256 internal deadline;

    function setUp() public override {
        super.setUp();
        deadline = block.timestamp + 1 hours;
    }

    /// CUJ 1: at a 27.0% price, 2 GOOGLc buys about 7.4 $CLOUD (less the 0.30% fee and price impact).
    function test_buyCloud_cuj1() public {
        uint256 before = googl.balanceOf(alice);
        vm.prank(alice);
        uint256 out = router.buyCloud(id, 2 * ONE, 7 * ONE, deadline);
        assertEq(googl.balanceOf(alice), before - 2 * ONE, "exact input pulled");
        assertEq(_cloud(id).balanceOf(alice), out);
        // 2 / 0.27 = 7.407; after 0.30% fee about 7.385.
        assertApproxEqRel(out, 7_385_000_00, 0.005e18);
        _assertRouterEmpty();
    }

    function test_sellCloud_roundTripLosesOnlyFees() public {
        vm.prank(alice);
        uint256 cloudOut = router.buyCloud(id, 10 * ONE, 0, deadline);
        vm.prank(alice);
        uint256 googlBack = router.sellCloud(id, cloudOut, 0, deadline);
        assertLt(googlBack, 10 * ONE);
        assertApproxEqRel(googlBack, 10 * ONE, 0.007e18); // two 0.30% fees plus tiny impact
        assertEq(_cloud(id).balanceOf(alice), 0);
        _assertRouterEmpty();
    }

    /// CUJ 2: take the other side. 10 GOOGLc in -> 10 $SERVICES plus about 2.7 GOOGLc back.
    function test_buyServices_cuj2() public {
        uint256 before = googl.balanceOf(alice);
        vm.prank(alice);
        uint256 back = router.buyServices(id, 10 * ONE, 2 * ONE, deadline);
        assertEq(_svcs(id).balanceOf(alice), 10 * ONE);
        assertEq(_cloud(id).balanceOf(alice), 0);
        assertEq(googl.balanceOf(alice), before - 10 * ONE + back);
        // 10 x 0.27 = 2.7; after fee about 2.69.
        assertApproxEqRel(back, 2_690_000_00, 0.005e18);
        _assertRouterEmpty();
        // The vault backs the new pieces 1:1.
        assertEq(vault.getSeries(id).collateral, 1_000_010 * ONE);
    }

    function test_exitServices_buyCloudThenMerge() public {
        vm.startPrank(alice);
        router.buyServices(id, 10 * ONE, 0, deadline);
        uint256 cloudOut = router.buyCloud(id, 3 * ONE, 0, deadline);
        uint256 m = cloudOut < 10 * ONE ? cloudOut : 10 * ONE;
        vault.merge(id, m, alice);
        vm.stopPrank();
        _assertRouterEmpty();
    }

    // ---------------- limits ----------------

    function test_slippageLimitReverts() public {
        vm.prank(alice);
        vm.expectPartialRevert(IV4Router.V4TooLittleReceived.selector);
        router.buyCloud(id, 2 * ONE, 8 * ONE, deadline);

        vm.prank(alice);
        vm.expectPartialRevert(IV4Router.V4TooLittleReceived.selector);
        router.buyServices(id, 10 * ONE, 3 * ONE, deadline);
    }

    function test_deadlineReverts() public {
        vm.warp(deadline + 1);
        vm.prank(alice);
        vm.expectRevert(SegmentRouter.DeadlinePassed.selector);
        router.buyCloud(id, ONE, 0, deadline);
    }

    function test_zeroAmountReverts() public {
        vm.prank(alice);
        vm.expectRevert(SegmentRouter.ZeroAmount.selector);
        router.sellCloud(id, 0, 0, deadline);
    }

    function test_closedSeriesReverts() public {
        vm.prank(guardian);
        vault.closeEarly(id);
        vm.startPrank(alice);
        vm.expectRevert(SegmentRouter.ClosedForSettlement.selector);
        router.buyCloud(id, ONE, 0, deadline);
        vm.expectRevert(SegmentRouter.ClosedForSettlement.selector);
        router.sellCloud(id, ONE, 0, deadline);
        vm.expectRevert(SegmentRouter.ClosedForSettlement.selector);
        router.buyServices(id, ONE, 0, deadline);
        vm.stopPrank();
    }

    function test_fuzz_routerAlwaysEndsEmpty(uint96 amount, uint8 path) public {
        amount = uint96(bound(amount, 1e4, 100 * ONE));
        vm.startPrank(alice);
        if (path % 3 == 0) {
            router.buyCloud(id, amount, 0, deadline);
        } else if (path % 3 == 1) {
            router.buyServices(id, amount, 0, deadline);
        } else {
            uint256 c = router.buyCloud(id, amount, 0, deadline);
            router.sellCloud(id, c, 0, deadline);
        }
        vm.stopPrank();
        _assertRouterEmpty();
    }

    function test_unlockCallbackOnlyFromPoolManager() public {
        vm.expectRevert();
        router.unlockCallback("");
    }
}
