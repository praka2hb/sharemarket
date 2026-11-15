// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {TickMath} from "@uniswap/v4-core/src/libraries/TickMath.sol";

/// @notice Converts a piece price (in parts per million of one stock token) to Uniswap v4 prices
///         and ticks. Used by the seeding script and tests; not used by the core contracts.
/// @dev Pool price is currency1 per currency0. If the piece is currency0, price = ppm / 1e6;
///      otherwise it is the inverse.
library PriceMath {
    uint256 internal constant PPM = 1_000_000;

    function sqrtPriceX96(uint256 ppm, bool pieceIs0) internal pure returns (uint160) {
        uint256 ratioX192 = pieceIs0 ? (ppm << 192) / PPM : (PPM << 192) / ppm;
        // casting to 'uint160' is safe because ppm is within (0, 1e6], so the root fits
        // forge-lint: disable-next-line(unsafe-typecast)
        return uint160(Math.sqrt(ratioX192));
    }

    function tick(uint256 ppm, bool pieceIs0, int24 spacing) internal pure returns (int24) {
        return floorTick(TickMath.getTickAtSqrtPrice(sqrtPriceX96(ppm, pieceIs0)), spacing);
    }

    /// @notice Ticks for a price range [lowPpm, highPpm], ordered low to high.
    function range(uint256 lowPpm, uint256 highPpm, bool pieceIs0, int24 spacing)
        internal
        pure
        returns (int24 lower, int24 upper)
    {
        int24 a = tick(lowPpm, pieceIs0, spacing);
        int24 b = tick(highPpm, pieceIs0, spacing);
        (lower, upper) = a < b ? (a, b) : (b, a);
        if (lower == upper) upper += spacing;
    }

    function floorTick(int24 t, int24 spacing) internal pure returns (int24) {
        int24 q = t / spacing;
        if (t < 0 && t % spacing != 0) q--;
        return q * spacing;
    }

    /// @notice Piece price in ppm of a stock token, from a pool's sqrtPriceX96.
    function ppmFromSqrtPrice(uint160 sqrtP, bool pieceIs0) internal pure returns (uint256) {
        // price (currency1 per currency0) in X96, computed with 512-bit intermediate math
        uint256 priceX96 = Math.mulDiv(sqrtP, sqrtP, 1 << 96);
        if (pieceIs0) return Math.mulDiv(priceX96, PPM, 1 << 96);
        return Math.mulDiv(1 << 96, PPM, priceX96);
    }
}
