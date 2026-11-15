// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Fixture} from "./Fixture.sol";
import {PoolManager} from "@uniswap/v4-core/src/PoolManager.sol";
import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {TickMath} from "@uniswap/v4-core/src/libraries/TickMath.sol";
import {StateLibrary} from "@uniswap/v4-core/src/libraries/StateLibrary.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {PoolId, PoolIdLibrary} from "@uniswap/v4-core/src/types/PoolId.sol";
import {Currency} from "@uniswap/v4-core/src/types/Currency.sol";
import {ModifyLiquidityParams} from "@uniswap/v4-core/src/types/PoolOperation.sol";
import {PoolModifyLiquidityTest} from "@uniswap/v4-core/src/test/PoolModifyLiquidityTest.sol";
import {LiquidityAmounts} from "@uniswap/v4-periphery/src/libraries/LiquidityAmounts.sol";
import {SegmentRouter} from "../../src/SegmentRouter.sol";
import {PriceMath} from "../../src/libraries/PriceMath.sol";

/// @notice Fixture plus a local Uniswap v4 PoolManager, the router, and one pool per piece seeded
///         at Alphabet's Q3 2026 revenue mix among the three lines:
///         Search 60.18%, YouTube ads 10.65%, Cloud 29.17%.
abstract contract MarketFixture is Fixture {
    using PoolIdLibrary for PoolKey;
    using StateLibrary for IPoolManager;

    uint256 internal constant SEED_PER_POOL = 300_000e8; // pieces per pool

    IPoolManager internal manager;
    SegmentRouter internal router;
    PoolModifyLiquidityTest internal lpRouter;

    uint256[3] internal startPpm = [uint256(601_800), 106_500, 291_700];
    PoolKey[3] internal keys;
    bool[3] internal pieceIs0;

    function setUp() public virtual override {
        super.setUp();
        manager = new PoolManager(address(this));
        router = new SegmentRouter(manager, vault);
        lpRouter = new PoolModifyLiquidityTest(manager);

        googl.mint(address(this), 2_000_000 * ONE);
        googl.approve(address(vault), type(uint256).max);
        vault.split(1_000_000 * ONE, address(this));
        googl.approve(address(lpRouter), type(uint256).max);

        for (uint256 i; i < 3; i++) {
            keys[i] = router.poolKey(i);
            pieceIs0[i] = Currency.unwrap(keys[i].currency0) == address(pieces[i]);
            pieces[i].approve(address(lpRouter), type(uint256).max);
            _seed(i);
        }

        address[3] memory users = [alice, bob, carol];
        for (uint256 u; u < users.length; u++) {
            vm.startPrank(users[u]);
            googl.approve(address(router), type(uint256).max);
            for (uint256 i; i < 3; i++) {
                pieces[i].approve(address(router), type(uint256).max);
            }
            vm.stopPrank();
        }
    }

    function _seed(uint256 i) internal {
        uint256 ppm = startPpm[i];
        uint160 sqrtP = PriceMath.sqrtPriceX96(ppm, pieceIs0[i]);
        manager.initialize(keys[i], sqrtP);
        uint256 high = ppm * 2 > 990_000 ? 990_000 : ppm * 2;
        (int24 lo, int24 hi) = PriceMath.range(ppm / 2, high, pieceIs0[i], keys[i].tickSpacing);
        uint256 stockAmt = SEED_PER_POOL * ppm / 1_000_000;
        (uint256 a0, uint256 a1) = pieceIs0[i] ? (SEED_PER_POOL, stockAmt) : (stockAmt, SEED_PER_POOL);
        uint128 liq = LiquidityAmounts.getLiquidityForAmounts(
            sqrtP, TickMath.getSqrtPriceAtTick(lo), TickMath.getSqrtPriceAtTick(hi), a0, a1
        );
        lpRouter.modifyLiquidity(keys[i], ModifyLiquidityParams(lo, hi, int256(uint256(liq)), bytes32(0)), "");
    }

    /// Current pool price of piece i, in ppm of one stock token.
    function _pricePpm(uint256 i) internal view returns (uint256) {
        (uint160 sqrtP,,,) = manager.getSlot0(keys[i].toId());
        return PriceMath.ppmFromSqrtPrice(sqrtP, pieceIs0[i]);
    }

    function _sumPpm() internal view returns (uint256 s) {
        for (uint256 i; i < 3; i++) {
            s += _pricePpm(i);
        }
    }

    function _assertRouterEmpty() internal view {
        assertEq(googl.balanceOf(address(router)), 0, "router holds stock");
        for (uint256 i; i < 3; i++) {
            assertEq(pieces[i].balanceOf(address(router)), 0, "router holds a piece");
        }
    }
}
