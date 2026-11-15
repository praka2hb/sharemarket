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

    function test_poolKeys_noHook_fixedFeeAndSpacing() public view {
        for (uint256 i; i < 3; i++) {
            assertEq(address(keys[i].hooks), address(0));
            assertEq(keys[i].fee, 3000);
            assertEq(keys[i].tickSpacing, 60);
        }
    }

    function test_seededPricesMatchRevenueMixAndSumToOne() public view {
        for (uint256 i; i < 3; i++) {
            assertApproxEqRel(_pricePpm(i), startPpm[i], 0.0001e18);
        }
        assertApproxEqAbs(_sumPpm(), 1_000_000, 50);
    }

    /// Buying each piece with 1 stock token gives about 1 / price pieces, less the 0.30% fee.
    function test_buyEachPiece() public {
        for (uint256 i; i < 3; i++) {
            uint256 before = googl.balanceOf(alice);
            vm.prank(alice);
            uint256 out = router.buy(i, ONE, 0, deadline);
            assertEq(googl.balanceOf(alice), before - ONE, "exact input pulled");
            assertEq(pieces[i].balanceOf(alice), out);
            uint256 expected = ONE * 1_000_000 / startPpm[i] * 997 / 1000;
            assertApproxEqRel(out, expected, 0.003e18);
        }
        _assertRouterEmpty();
    }

    function test_sellRoundTripLosesOnlyFees() public {
        for (uint256 i; i < 3; i++) {
            vm.prank(alice);
            uint256 got = router.buy(i, 10 * ONE, 0, deadline);
            vm.prank(alice);
            uint256 back = router.sell(i, got, 0, deadline);
            assertLt(back, 10 * ONE);
            assertApproxEqRel(back, 10 * ONE, 0.007e18);
        }
        _assertRouterEmpty();
    }

    /// Conviction moves the price: heavy buying of $CLOUD raises its price for the next buyer.
    function test_buyingPushesPriceUp() public {
        uint256 before = _pricePpm(CLOUD);
        vm.prank(bob);
        router.buy(CLOUD, 500 * ONE, 0, deadline);
        assertGt(_pricePpm(CLOUD), before, "price did not rise");
    }

    /// When buying pushes the pieces' prices above 1 stock token in total, splitting and selling
    /// every piece earns more than 1 stock token: the arbitrage that keeps the sum anchored.
    function test_arbitrageKeepsSumNearOne() public {
        googl.mint(bob, 20_000 * ONE);
        vm.prank(bob);
        router.buy(CLOUD, 20_000 * ONE, 0, deadline);
        assertGt(_sumPpm(), 1_020_000, "sum not well above 1");

        vm.startPrank(carol);
        vault.split(20 * ONE, carol);
        uint256 got;
        for (uint256 i; i < 3; i++) {
            got += router.sell(i, 20 * ONE, 0, deadline);
        }
        vm.stopPrank();
        assertGt(got, 20 * ONE, "split-and-sell should profit");
    }

    // ---------------- limits ----------------

    function test_slippageLimitReverts() public {
        vm.prank(alice);
        vm.expectPartialRevert(IV4Router.V4TooLittleReceived.selector);
        router.buy(CLOUD, ONE, 4 * ONE, deadline); // ~3.42 possible
    }

    function test_deadlineReverts() public {
        vm.warp(deadline + 1);
        vm.prank(alice);
        vm.expectRevert(SegmentRouter.DeadlinePassed.selector);
        router.buy(SEARCH, ONE, 0, deadline);
    }

    function test_zeroAmountReverts() public {
        vm.prank(alice);
        vm.expectRevert(SegmentRouter.ZeroAmount.selector);
        router.sell(SEARCH, 0, 0, deadline);
    }

    function test_badPieceReverts() public {
        vm.prank(alice);
        vm.expectRevert(SegmentRouter.BadPiece.selector);
        router.buy(3, ONE, 0, deadline);
    }

    function testFuzz_routerAlwaysEndsEmpty(uint96 amount, uint8 index, bool roundTrip) public {
        amount = uint96(bound(amount, 1e4, 100 * ONE));
        uint256 i = index % 3;
        vm.startPrank(alice);
        uint256 got = router.buy(i, amount, 0, deadline);
        if (roundTrip) router.sell(i, got, 0, deadline);
        vm.stopPrank();
        _assertRouterEmpty();
    }

    function test_unlockCallbackOnlyFromPoolManager() public {
        vm.expectRevert();
        router.unlockCallback("");
    }
}
