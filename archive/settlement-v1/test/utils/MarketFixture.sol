// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Fixture} from "./Fixture.sol";
import {PoolManager} from "@uniswap/v4-core/src/PoolManager.sol";
import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {Hooks} from "@uniswap/v4-core/src/libraries/Hooks.sol";
import {TickMath} from "@uniswap/v4-core/src/libraries/TickMath.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {Currency} from "@uniswap/v4-core/src/types/Currency.sol";
import {ModifyLiquidityParams, SwapParams} from "@uniswap/v4-core/src/types/PoolOperation.sol";
import {PoolModifyLiquidityTest} from "@uniswap/v4-core/src/test/PoolModifyLiquidityTest.sol";
import {PoolSwapTest} from "@uniswap/v4-core/src/test/PoolSwapTest.sol";
import {CloseHook} from "../../src/CloseHook.sol";
import {SegmentRouter} from "../../src/SegmentRouter.sol";

/// @notice Fixture plus a local Uniswap v4: PoolManager, CloseHook at a flagged address, the
///         router, and one seeded $CLOUD / GOOGLc pool priced at a 27% Cloud share.
abstract contract MarketFixture is Fixture {
    /// ln(0.27) / ln(1.0001) ≈ -13,093, rounded to tick spacing 60.
    int24 internal constant TICK_27PCT = -13_080;
    int24 internal constant RANGE = 6_000; // about ±45% in price around the centre
    int256 internal constant LIQUIDITY = 2e13;

    IPoolManager internal manager;
    CloseHook internal hook;
    SegmentRouter internal router;
    PoolModifyLiquidityTest internal lpRouter;
    PoolSwapTest internal swapRouter;

    uint256 internal id;
    PoolKey internal key;
    bool internal cloudIs0;
    int24 internal tickLower;
    int24 internal tickUpper;

    function setUp() public virtual override {
        super.setUp();
        manager = new PoolManager(address(this));

        uint160 flags =
            uint160(Hooks.BEFORE_INITIALIZE_FLAG | Hooks.BEFORE_ADD_LIQUIDITY_FLAG | Hooks.BEFORE_SWAP_FLAG);
        address hookAddr = address(flags ^ (uint160(0x4444) << 144));
        deployCodeTo("CloseHook.sol:CloseHook", abi.encode(manager, vault), hookAddr);
        hook = CloseHook(hookAddr);

        router = new SegmentRouter(manager, vault, hook);
        lpRouter = new PoolModifyLiquidityTest(manager);
        swapRouter = new PoolSwapTest(manager);

        id = _createSeries("26Q4", _closeAt());
        (key,) = router.poolKeyOf(id);
        cloudIs0 = Currency.unwrap(key.currency0) == vault.getSeries(id).cloud;

        // Price is currency1 per currency0. If GOOGLc is currency0 the tick flips sign.
        int24 centre = cloudIs0 ? TICK_27PCT : -TICK_27PCT;
        manager.initialize(key, TickMath.getSqrtPriceAtTick(centre));
        tickLower = centre - RANGE;
        tickUpper = centre + RANGE;

        // The team seeds the pool: split GOOGLc for $CLOUD, add both sides.
        googl.mint(address(this), 2_000_000 * ONE);
        googl.approve(address(vault), type(uint256).max);
        vault.split(id, 1_000_000 * ONE);
        googl.approve(address(lpRouter), type(uint256).max);
        _cloud(id).approve(address(lpRouter), type(uint256).max);
        googl.approve(address(swapRouter), type(uint256).max);
        _cloud(id).approve(address(swapRouter), type(uint256).max);
        _addLiquidity(LIQUIDITY);

        address[3] memory users = [alice, bob, carol];
        for (uint256 i; i < users.length; i++) {
            vm.startPrank(users[i]);
            googl.approve(address(router), type(uint256).max);
            _cloud(id).approve(address(router), type(uint256).max);
            vm.stopPrank();
        }
    }

    function _addLiquidity(int256 delta) internal {
        lpRouter.modifyLiquidity(key, ModifyLiquidityParams(tickLower, tickUpper, delta, bytes32(0)), "");
    }

    /// Direct swap through Uniswap's test router, bypassing SegmentRouter's own checks.
    function _rawSwapGooglForCloud(uint256 amountIn) internal {
        bool zeroForOne = !cloudIs0; // GOOGLc in
        swapRouter.swap(
            key,
            _swapParams(zeroForOne, amountIn),
            PoolSwapTest.TestSettings({takeClaims: false, settleUsingBurn: false}),
            ""
        );
    }

    function _swapParams(bool zeroForOne, uint256 amountIn) internal pure returns (SwapParams memory) {
        uint160 limit = zeroForOne ? TickMath.MIN_SQRT_PRICE + 1 : TickMath.MAX_SQRT_PRICE - 1;
        return SwapParams(zeroForOne, -int256(amountIn), limit);
    }

    function _assertRouterEmpty() internal view {
        assertEq(googl.balanceOf(address(router)), 0, "router holds GOOGLc");
        assertEq(_cloud(id).balanceOf(address(router)), 0, "router holds CLOUD");
        assertEq(_svcs(id).balanceOf(address(router)), 0, "router holds SVCS");
    }
}

