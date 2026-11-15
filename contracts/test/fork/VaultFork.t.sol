// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Test} from "forge-std/Test.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {TickMath} from "@uniswap/v4-core/src/libraries/TickMath.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {Currency} from "@uniswap/v4-core/src/types/Currency.sol";
import {ModifyLiquidityParams} from "@uniswap/v4-core/src/types/PoolOperation.sol";
import {PoolModifyLiquidityTest} from "@uniswap/v4-core/src/test/PoolModifyLiquidityTest.sol";
import {SegmentVault} from "../../src/SegmentVault.sol";
import {SegmentRouter} from "../../src/SegmentRouter.sol";
import {PieceToken} from "../../src/PieceToken.sol";
import {PriceMath} from "../../src/libraries/PriceMath.sol";

/// @notice Our real vault and router against the real Coinbase stock tokens (B20 precompiles) and the
///         real Uniswap v4 PoolManager, on a Base mainnet fork. No balances are minted: real holders
///         are impersonated.
///         Run: BASE_RPC_URL=https://mainnet.base.org base-forge test --match-path test/fork/VaultFork.t.sol -vv
abstract contract StockForkBase is Test {
    IPoolManager constant POOL_MANAGER = IPoolManager(0x498581fF718922c3f8e6A244956aF099B2652b2b);
    uint256 constant ONE = 1e8;

    SegmentVault vault;
    SegmentRouter router;
    address user = makeAddr("user");

    function _stock() internal pure virtual returns (IERC20);
    function _holder() internal pure virtual returns (address);
    function _forkBlock() internal pure virtual returns (uint256);
    function _symbols() internal pure virtual returns (string[] memory);
    function _startPpm(uint256 i) internal pure virtual returns (uint256);

    function setUp() public {
        vm.createSelectFork(vm.envOr("BASE_RPC_URL", string("https://mainnet.base.org")), _forkBlock());
        string[] memory s = _symbols();
        vault = new SegmentVault(_stock(), s, s);
        router = new SegmentRouter(POOL_MANAGER, vault);
    }

    function test_realStock_splitAndMerge() public {
        IERC20 stock = _stock();
        address holder = _holder();
        uint256 before = stock.balanceOf(holder);
        vm.startPrank(holder);
        stock.approve(address(vault), 3 * ONE);
        vault.split(3 * ONE, holder);
        assertEq(stock.balanceOf(address(vault)), 3 * ONE);
        for (uint256 i; i < vault.pieceCount(); i++) {
            assertEq(vault.piece(i).balanceOf(holder), 3 * ONE);
        }
        vault.merge(ONE, user); // exit to a different address
        vm.stopPrank();
        assertEq(stock.balanceOf(user), ONE);
        assertEq(stock.balanceOf(address(vault)), 2 * ONE);
        assertEq(stock.balanceOf(holder), before - 3 * ONE);
    }

    function test_realStock_realPoolManager_buyAndSellEveryPiece() public {
        IERC20 stock = _stock();
        address holder = _holder();
        PoolModifyLiquidityTest lp = new PoolModifyLiquidityTest(POOL_MANAGER);
        uint256 n = vault.pieceCount();

        vm.startPrank(holder);
        stock.approve(address(vault), 30 * ONE);
        vault.split(30 * ONE, holder);
        stock.approve(address(lp), type(uint256).max);
        for (uint256 i; i < n; i++) {
            PoolKey memory key = router.poolKey(i);
            bool pieceIs0 = Currency.unwrap(key.currency0) == address(vault.piece(i));
            uint256 ppm = _startPpm(i);
            POOL_MANAGER.initialize(key, PriceMath.sqrtPriceX96(ppm, pieceIs0));
            (int24 lo, int24 hi) = PriceMath.range(ppm / 2, ppm * 2 > 990_000 ? 990_000 : ppm * 2, pieceIs0, 60);
            vault.piece(i).approve(address(lp), type(uint256).max);
            lp.modifyLiquidity(key, ModifyLiquidityParams(lo, hi, 1e9, bytes32(0)), "");
        }
        stock.transfer(user, 3 * ONE);
        vm.stopPrank();

        vm.startPrank(user);
        stock.approve(address(router), type(uint256).max);
        for (uint256 i; i < n; i++) {
            PieceToken p = vault.piece(i);
            p.approve(address(router), type(uint256).max);
            uint256 got = router.buy(i, ONE / 10, 1, block.timestamp);
            assertApproxEqRel(got, (ONE / 10) * 1_000_000 / _startPpm(i), 0.05e18, "buy amount");
            uint256 back = router.sell(i, got, 1, block.timestamp);
            assertApproxEqRel(back, ONE / 10, 0.02e18, "sell back");
        }
        vm.stopPrank();

        assertEq(stock.balanceOf(address(router)), 0, "router kept stock");
        assertEq(stock.balanceOf(address(vault)), vault.piece(0).totalSupply(), "vault backing");
    }
}

/// Alphabet: $SEARCH / $YOUTUBE / $CLOUD on real GOOGLc.
contract GOOGLForkTest is StockForkBase {
    function _stock() internal pure override returns (IERC20) {
        return IERC20(0xb2000000000000000000002D0BA3164cc74f58B7);
    }

    function _holder() internal pure override returns (address) {
        return 0x16c70F04C3080a127486Cdf5a4C33c066bBF47C3; // ~3,877 GOOGLc at the block
    }

    function _forkBlock() internal pure override returns (uint256) {
        return 57_298_792;
    }

    function _symbols() internal pure override returns (string[] memory s) {
        s = new string[](3);
        s[0] = "SEARCH-GOOGL";
        s[1] = "YOUTUBE-GOOGL";
        s[2] = "CLOUD-GOOGL";
    }

    function _startPpm(uint256 i) internal pure override returns (uint256) {
        return [uint256(601_800), 106_500, 291_700][i];
    }
}
