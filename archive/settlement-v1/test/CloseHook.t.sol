// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {MarketFixture} from "./utils/MarketFixture.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {Currency} from "@uniswap/v4-core/src/types/Currency.sol";
import {IHooks} from "@uniswap/v4-core/src/interfaces/IHooks.sol";
import {TickMath} from "@uniswap/v4-core/src/libraries/TickMath.sol";
import {ModifyLiquidityParams} from "@uniswap/v4-core/src/types/PoolOperation.sol";
import {CustomRevert} from "@uniswap/v4-core/src/libraries/CustomRevert.sol";
import {Hooks} from "@uniswap/v4-core/src/libraries/Hooks.sol";
import {CloseHook} from "../src/CloseHook.sol";

contract CloseHookTest is MarketFixture {
    /// The PoolManager wraps a hook's revert; check the wrapped reason is the hook's own error.
    function _expectHookError(bytes4 hookFn, bytes4 err) internal {
        vm.expectRevert(
            abi.encodeWithSelector(
                CustomRevert.WrappedError.selector,
                address(hook),
                hookFn,
                abi.encodeWithSelector(err),
                abi.encodeWithSelector(Hooks.HookCallFailed.selector)
            )
        );
    }

    function _key(address a, address b, uint24 fee, int24 spacing, address hooks)
        internal
        pure
        returns (PoolKey memory)
    {
        (address c0, address c1) = a < b ? (a, b) : (b, a);
        return PoolKey(Currency.wrap(c0), Currency.wrap(c1), fee, spacing, IHooks(hooks));
    }

    // ---------------- while Trading ----------------

    function test_swapAndAddLiquidityWorkWhileTrading() public {
        _rawSwapGooglForCloud(ONE);
        _addLiquidity(1e10);
    }

    // ---------------- after close ----------------

    function test_swapBlockedAfterTradingCloseAt() public {
        vm.warp(vault.getSeries(id).tradingCloseAt);
        _expectHookError(IHooks.beforeSwap.selector, CloseHook.ClosedForSettlement.selector);
        _rawSwapGooglForCloud(ONE);
    }

    function test_swapBlockedAfterCloseEarly() public {
        vm.prank(guardian);
        vault.closeEarly(id);
        _expectHookError(IHooks.beforeSwap.selector, CloseHook.ClosedForSettlement.selector);
        _rawSwapGooglForCloud(ONE);
    }

    function test_addLiquidityBlockedAfterClose() public {
        vm.prank(guardian);
        vault.closeEarly(id);
        _expectHookError(IHooks.beforeAddLiquidity.selector, CloseHook.ClosedForSettlement.selector);
        _addLiquidity(1e10);
    }

    function test_removeLiquidityAlwaysWorks() public {
        vm.warp(vault.getSeries(id).tradingCloseAt + 30 days);
        uint256 before = googl.balanceOf(address(this));
        _addLiquidityRemove(-LIQUIDITY);
        assertGt(googl.balanceOf(address(this)) + _cloud(id).balanceOf(address(this)), before);
    }

    function _addLiquidityRemove(int256 delta) internal {
        lpRouter.modifyLiquidity(key, ModifyLiquidityParams(tickLower, tickUpper, delta, bytes32(0)), "");
    }

    function test_closedErrorIsTheHooksOwn() public {
        vm.prank(guardian);
        vault.closeEarly(id);
        vm.prank(address(manager));
        vm.expectRevert(CloseHook.ClosedForSettlement.selector);
        hook.beforeSwap(address(this), key, _swapParams(true, 1), "");
    }

    // ---------------- which pools may initialize ----------------

    function test_initRejectsUnknownToken() public {
        address other = address(new DummyToken());
        PoolKey memory k = _key(other, address(googl), 3000, 60, address(hook));
        _expectHookError(IHooks.beforeInitialize.selector, CloseHook.BadPool.selector);
        manager.initialize(k, TickMath.getSqrtPriceAtTick(0));
    }

    function test_initRejectsCloudAgainstNonGoogl() public {
        PoolKey memory k = _key(vault.getSeries(id).cloud, address(usdc), 3000, 60, address(hook));
        _expectHookError(IHooks.beforeInitialize.selector, CloseHook.BadPool.selector);
        manager.initialize(k, TickMath.getSqrtPriceAtTick(0));
    }

    function test_initRejectsServicesToken() public {
        PoolKey memory k = _key(vault.getSeries(id).services, address(googl), 3000, 60, address(hook));
        _expectHookError(IHooks.beforeInitialize.selector, CloseHook.BadPool.selector);
        manager.initialize(k, TickMath.getSqrtPriceAtTick(0));
    }

    function test_initRejectsOtherFeeOrSpacing() public {
        // A second series' $CLOUD, otherwise valid.
        uint256 id2 = _createSeries("27Q1", _closeAt());
        address cloud2 = vault.getSeries(id2).cloud;
        _expectHookError(IHooks.beforeInitialize.selector, CloseHook.BadPool.selector);
        manager.initialize(_key(cloud2, address(googl), 500, 60, address(hook)), TickMath.getSqrtPriceAtTick(0));
        _expectHookError(IHooks.beforeInitialize.selector, CloseHook.BadPool.selector);
        manager.initialize(_key(cloud2, address(googl), 3000, 10, address(hook)), TickMath.getSqrtPriceAtTick(0));
        manager.initialize(_key(cloud2, address(googl), 3000, 60, address(hook)), TickMath.getSqrtPriceAtTick(0));
    }

    function test_seriesOf_eitherTokenOrder() public view {
        address cloud = vault.getSeries(id).cloud;
        PoolKey memory a = PoolKey(Currency.wrap(cloud), Currency.wrap(address(googl)), 3000, 60, IHooks(address(hook)));
        PoolKey memory b = PoolKey(Currency.wrap(address(googl)), Currency.wrap(cloud), 3000, 60, IHooks(address(hook)));
        assertEq(hook.seriesOf(a), id);
        assertEq(hook.seriesOf(b), id);
    }

    function test_hookCallsOnlyFromPoolManager() public {
        vm.expectRevert(CloseHook.NotPoolManager.selector);
        hook.beforeSwap(address(this), key, _swapParams(true, 1), "");
        vm.expectRevert(CloseHook.NotPoolManager.selector);
        hook.beforeInitialize(address(this), key, TickMath.getSqrtPriceAtTick(0));
    }
}

contract DummyToken {
    function balanceOf(address) external pure returns (uint256) {
        return 0;
    }
}
