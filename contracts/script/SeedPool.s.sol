// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Script, console2} from "forge-std/Script.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {TickMath} from "@uniswap/v4-core/src/libraries/TickMath.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {Currency} from "@uniswap/v4-core/src/types/Currency.sol";
import {IPositionManager} from "@uniswap/v4-periphery/src/interfaces/IPositionManager.sol";
import {Actions} from "@uniswap/v4-periphery/src/libraries/Actions.sol";
import {LiquidityAmounts} from "@uniswap/v4-periphery/src/libraries/LiquidityAmounts.sol";
import {IAllowanceTransfer} from "permit2/src/interfaces/IAllowanceTransfer.sol";
import {SegmentVault} from "../src/SegmentVault.sol";
import {SegmentRouter} from "../src/SegmentRouter.sol";
import {MockB20} from "../src/mocks/MockB20.sol";
import {PriceMath} from "../src/libraries/PriceMath.sol";

/// @notice Creates and seeds one pool per piece for one market (STOCK=GOOGL or NVDA) through
///         Uniswap's PositionManager. Each pool opens at that line's share of the company's latest
///         reported revenue, with a main range from half to double that price (90% of the
///         liquidity) and a wide backstop from a fifth to four times it (10%).
///         Env (all optional):
///           STOCK       GOOGL (default) or NVDA
///           START_PPMS  comma-separated opening prices in ppm, one per piece; defaults:
///                       GOOGL 601800,106500,291700  (Search, YouTube ads, Cloud; Q3 2026 revenue mix)
///                       NVDA  506200,419000,74800   (Hyperscale, AI clouds/enterprise, Edge; Q2 FY27)
///           SEED        stock tokens to commit, whole tokens; default 1000. Half is split into pieces.
///           MINT_MOCK   default true: mint SEED mock tokens to the wallet first (testnet only)
contract SeedPool is Script {
    address internal constant POSM_SEPOLIA = 0x4B2C77d209D3405F41a037Ec6c77F7F5b8e2ca80;
    address internal constant PERMIT2 = 0x000000000022D473030F116dDEE9F6B43aC78BA3;

    struct Ctx {
        SegmentVault vault;
        SegmentRouter router;
        IPoolManager manager;
        IPositionManager posm;
        IERC20 stock;
        address me;
        uint256 perPiece;
    }

    struct Pool {
        PoolKey key;
        uint160 sqrtP;
        bool pieceIs0;
    }

    function run() external {
        string memory file = vm.envOr("DEPLOYMENTS_FILE", string("../deployments/base-sepolia.json"));
        string memory dep = vm.readFile(file);
        string memory market = vm.envOr("STOCK", string("GOOGL"));

        Ctx memory c;
        c.vault = SegmentVault(vm.parseJsonAddress(dep, string.concat(".", market, ".vault")));
        c.router = SegmentRouter(payable(vm.parseJsonAddress(dep, string.concat(".", market, ".router"))));
        c.manager = IPoolManager(vm.parseJsonAddress(dep, ".poolManager"));
        c.posm = IPositionManager(vm.envOr("POSITION_MANAGER", POSM_SEPOLIA));
        c.stock = c.vault.collateralToken();

        uint256[] memory ppms = vm.envOr("START_PPMS", ",", _defaultPpms(market));
        uint256 n = c.vault.pieceCount();
        require(ppms.length == n, "one START_PPMS value per piece");
        uint256 sum;
        for (uint256 i; i < n; i++) {
            sum += ppms[i];
        }
        require(sum > 990_000 && sum < 1_010_000, "START_PPMS should sum to about 1,000,000");

        uint256 seed = vm.envOr("SEED", uint256(1_000)) * 1e8;
        c.perPiece = seed / 2;

        vm.startBroadcast();
        (, c.me,) = vm.readCallers();
        if (vm.envOr("MINT_MOCK", true)) MockB20(address(c.stock)).mint(c.me, seed);
        c.stock.approve(address(c.vault), c.perPiece);
        c.vault.split(c.perPiece, c.me);
        _approve(address(c.stock), address(c.posm));

        for (uint256 i; i < n; i++) {
            _seedPiece(c, i, ppms[i]);
        }
        vm.stopBroadcast();
        console2.log("seeded", n, "pools for", market);
    }

    function _seedPiece(Ctx memory c, uint256 i, uint256 ppm) internal {
        PoolKey memory key = c.router.poolKey(i);
        address pieceAddr = address(c.vault.piece(i));
        bool pieceIs0 = Currency.unwrap(key.currency0) == pieceAddr;
        _approve(pieceAddr, address(c.posm));

        Pool memory pool = Pool(key, PriceMath.sqrtPriceX96(ppm, pieceIs0), pieceIs0);
        c.manager.initialize(key, pool.sqrtP);

        uint256 stockAmt = c.perPiece * ppm / 1_000_000;
        _mint(c, pool, [ppm / 2, _cap(ppm * 2)], c.perPiece * 9 / 10, stockAmt * 9 / 10);
        _mint(c, pool, [ppm / 5, _cap(ppm * 4)], c.perPiece / 10, stockAmt / 10);
        console2.log(c.vault.piece(i).symbol(), "opened at ppm", ppm);
    }

    function _cap(uint256 ppm) internal pure returns (uint256) {
        return ppm > 990_000 ? 990_000 : ppm;
    }

    function _mint(Ctx memory c, Pool memory pool, uint256[2] memory rangePpm, uint256 pieceAmt, uint256 stockAmt)
        internal
    {
        (int24 tl, int24 tu) = PriceMath.range(rangePpm[0], rangePpm[1], pool.pieceIs0, pool.key.tickSpacing);
        (uint256 a0, uint256 a1) = pool.pieceIs0 ? (pieceAmt, stockAmt) : (stockAmt, pieceAmt);
        uint128 liq = LiquidityAmounts.getLiquidityForAmounts(
            pool.sqrtP, TickMath.getSqrtPriceAtTick(tl), TickMath.getSqrtPriceAtTick(tu), a0, a1
        );
        bytes memory actions = abi.encodePacked(uint8(Actions.MINT_POSITION), uint8(Actions.SETTLE_PAIR));
        bytes[] memory params = new bytes[](2);
        params[0] = _mintParams(pool.key, [tl, tu], liq, a0, a1, c.me);
        params[1] = abi.encode(pool.key.currency0, pool.key.currency1);
        c.posm.modifyLiquidities(abi.encode(actions, params), block.timestamp + 600);
    }

    function _mintParams(PoolKey memory key, int24[2] memory ticks, uint128 liq, uint256 a0, uint256 a1, address owner)
        internal
        pure
        returns (bytes memory)
    {
        // Max amounts get 1 unit of headroom for rounding up inside the pool.
        // casting to 'uint128' is safe because seed amounts are far below 2^128
        // forge-lint: disable-next-line(unsafe-typecast)
        return abi.encode(key, ticks[0], ticks[1], uint256(liq), uint128(a0 + 1), uint128(a1 + 1), owner, bytes(""));
    }

    function _approve(address token, address spender) internal {
        IERC20(token).approve(PERMIT2, type(uint256).max);
        IAllowanceTransfer(PERMIT2).approve(token, spender, type(uint160).max, type(uint48).max);
    }

    function _defaultPpms(string memory market) internal pure returns (uint256[] memory p) {
        p = new uint256[](3);
        if (keccak256(bytes(market)) == keccak256("NVDA")) {
            (p[0], p[1], p[2]) = (506_200, 419_000, 74_800);
        } else {
            (p[0], p[1], p[2]) = (601_800, 106_500, 291_700);
        }
    }
}
