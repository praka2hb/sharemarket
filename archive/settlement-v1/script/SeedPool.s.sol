// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Script, console2} from "forge-std/Script.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
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

/// @notice Creates and seeds the $CLOUD / GOOGLc pool for one series through Uniswap's PositionManager:
///         a main range of EXPECTED_PPM ± HALF_WIDTH_PPM, plus a backstop from 10% to 45%.
///         Env (all optional):
///           SERIES_ID       default 1
///           EXPECTED_PPM    default 272000 (27.2%: Q3's 24.18% plus ~3 points of trend)
///           HALF_WIDTH_PPM  default 50000 (±5 points)
///           SEED_GOOGL      GOOGLc to commit, in whole tokens; default 1000. Half is split into pieces.
///           MINT_MOCK       default true: mint SEED_GOOGL mock GOOGLc to the wallet first (testnet only)
contract SeedPool is Script {
    address internal constant POSM_SEPOLIA = 0x4B2C77d209D3405F41a037Ec6c77F7F5b8e2ca80;
    address internal constant PERMIT2 = 0x000000000022D473030F116dDEE9F6B43aC78BA3;
    uint256 internal constant PPM = 1_000_000;
    uint32 internal constant BACKSTOP_LOW = 100_000;
    uint32 internal constant BACKSTOP_HIGH = 450_000;

    struct Ctx {
        SegmentVault vault;
        SegmentRouter router;
        IPoolManager manager;
        IPositionManager posm;
        PoolKey key;
        bool cloudIs0;
        address me;
    }

    function run() external {
        string memory file = vm.envOr("DEPLOYMENTS_FILE", string("../deployments/base-sepolia.json"));
        string memory dep = vm.readFile(file);

        Ctx memory c;
        c.vault = SegmentVault(vm.parseJsonAddress(dep, ".vault"));
        c.router = SegmentRouter(payable(vm.parseJsonAddress(dep, ".router")));
        c.manager = IPoolManager(vm.parseJsonAddress(dep, ".poolManager"));
        c.posm = IPositionManager(vm.envOr("POSITION_MANAGER", POSM_SEPOLIA));

        uint256 id = vm.envOr("SERIES_ID", uint256(1));
        uint32 expected = uint32(vm.envOr("EXPECTED_PPM", uint256(272_000)));
        uint32 half = uint32(vm.envOr("HALF_WIDTH_PPM", uint256(50_000)));
        uint256 seed = vm.envOr("SEED_GOOGL", uint256(1_000)) * 1e8;
        bool mintMock = vm.envOr("MINT_MOCK", true);

        (c.key,) = c.router.poolKeyOf(id);
        address cloud = c.vault.getSeries(id).cloud;
        c.cloudIs0 = Currency.unwrap(c.key.currency0) == cloud;
        IERC20 googl = c.vault.collateralToken();

        vm.startBroadcast();
        (, c.me,) = vm.readCallers();

        if (mintMock) MockB20(address(googl)).mint(c.me, seed);
        googl.approve(address(c.vault), seed / 2);
        c.vault.split(id, seed / 2); // seed/2 $CLOUD (and $SERVICES kept by the team)

        _approve(address(googl), address(c.posm));
        _approve(cloud, address(c.posm));

        uint160 sqrtPrice = _sqrtPriceForPpm(expected, c.cloudIs0);
        c.manager.initialize(c.key, sqrtPrice);

        // 90% into the main range, 10% into the backstop.
        uint256 cloudAmt = seed / 2;
        uint256 googlAmt = seed / 2;
        _mint(c, sqrtPrice, expected - half, expected + half, cloudAmt * 9 / 10, googlAmt * 9 / 10);
        _mint(c, sqrtPrice, BACKSTOP_LOW, BACKSTOP_HIGH, cloudAmt / 10, googlAmt / 10);
        vm.stopBroadcast();

        console2.log("pool seeded for series", id);
        console2.log("cloud is currency0", c.cloudIs0);
    }

    function _approve(address token, address spender) internal {
        IERC20(token).approve(PERMIT2, type(uint256).max);
        IAllowanceTransfer(PERMIT2).approve(token, spender, type(uint160).max, type(uint48).max);
    }

    function _mint(Ctx memory c, uint160 sqrtPrice, uint32 lowPpm, uint32 highPpm, uint256 cloudAmt, uint256 googlAmt)
        internal
    {
        (int24 tl, int24 tu) = _ticksForRange(lowPpm, highPpm, c.cloudIs0, c.key.tickSpacing);
        (uint256 amt0, uint256 amt1) = c.cloudIs0 ? (cloudAmt, googlAmt) : (googlAmt, cloudAmt);
        uint128 liquidity = LiquidityAmounts.getLiquidityForAmounts(
            sqrtPrice, TickMath.getSqrtPriceAtTick(tl), TickMath.getSqrtPriceAtTick(tu), amt0, amt1
        );

        _submitMint(c, tl, tu, liquidity, amt0, amt1);
        console2.log("position ticks");
        console2.logInt(tl);
        console2.logInt(tu);
    }

    function _submitMint(Ctx memory c, int24 tl, int24 tu, uint128 liquidity, uint256 amt0, uint256 amt1) internal {
        bytes memory actions = abi.encodePacked(uint8(Actions.MINT_POSITION), uint8(Actions.SETTLE_PAIR));
        bytes[] memory params = new bytes[](2);
        params[0] = _mintParams(c, tl, tu, liquidity, amt0, amt1);
        params[1] = abi.encode(c.key.currency0, c.key.currency1);
        c.posm.modifyLiquidities(abi.encode(actions, params), block.timestamp + 600);
    }

    function _mintParams(Ctx memory c, int24 tl, int24 tu, uint128 liquidity, uint256 amt0, uint256 amt1)
        internal
        pure
        returns (bytes memory)
    {
        // Max amounts get 1 unit of headroom for rounding up inside the pool.
        // casting to 'uint128' is safe because seed amounts are far below 2^128
        // forge-lint: disable-next-line(unsafe-typecast)
        return abi.encode(c.key, tl, tu, uint256(liquidity), uint128(amt0 + 1), uint128(amt1 + 1), c.me, bytes(""));
    }

    /// Pool price is currency1 per currency0. $CLOUD's price in GOOGLc equals the Cloud share.
    function _sqrtPriceForPpm(uint32 ppm, bool cloudIs0) internal pure returns (uint160) {
        uint256 ratioX192 = cloudIs0 ? (uint256(ppm) << 192) / PPM : (PPM << 192) / ppm;
        return uint160(Math.sqrt(ratioX192));
    }

    function _ticksForRange(uint32 lowPpm, uint32 highPpm, bool cloudIs0, int24 spacing)
        internal
        pure
        returns (int24 tl, int24 tu)
    {
        int24 a = _floorTick(TickMath.getTickAtSqrtPrice(_sqrtPriceForPpm(lowPpm, cloudIs0)), spacing);
        int24 b = _floorTick(TickMath.getTickAtSqrtPrice(_sqrtPriceForPpm(highPpm, cloudIs0)), spacing);
        (tl, tu) = a < b ? (a, b) : (b, a);
    }

    function _floorTick(int24 t, int24 spacing) internal pure returns (int24) {
        int24 q = t / spacing;
        if (t < 0 && t % spacing != 0) q--;
        return q * spacing;
    }
}
