import { describe, expect, it } from "vitest";
import {
  ONE,
  WAD,
  addSlippage,
  applySlippage,
  formatAmount,
  formatPrice,
  parseAmount,
  piecePriceWad,
  priceImpact,
  pricePct,
  valueAt,
} from "./math";

// Live pools at deployment (Base Sepolia), read from StateView.getSlot0.
const SEARCH_SQRT = 61461856662125856118514617702n; // $SEARCH is currency0
const EDGE_SQRT = 289686852304721722713319097870n; // $EDGE is currency1

describe("piece price from sqrtPriceX96", () => {
  it("reads a piece that is currency0 (price = sqrt^2)", () => {
    const p = piecePriceWad(SEARCH_SQRT, true);
    expect(formatPrice(p)).toBe("0.6018");
    expect(pricePct(p)).toBeCloseTo(60.18, 1);
  });

  it("reads a piece that is currency1 (price = 1 / sqrt^2)", () => {
    expect(formatPrice(piecePriceWad(EDGE_SQRT, false))).toBe("0.0748");
  });

  it("is 1.0 either way when sqrtPrice is 2^96", () => {
    expect(piecePriceWad(1n << 96n, true)).toBe(WAD);
    expect(piecePriceWad(1n << 96n, false)).toBe(WAD);
  });

  it("returns 0 for an uninitialised pool", () => {
    expect(piecePriceWad(0n, true)).toBe(0n);
  });

  it("values a balance in stock tokens", () => {
    expect(valueAt(10n * ONE, WAD / 4n)).toBe(250_000_000n);
  });
});

describe("slippage", () => {
  it("takes 0.5% off a quote, rounding down", () => {
    expect(applySlippage(10_000n, 50)).toBe(9_950n);
    expect(applySlippage(999n, 50)).toBe(994n);
  });
  it("adds slippage to an input, rounding up", () => {
    expect(addSlippage(10_000n, 50)).toBe(10_050n);
    expect(addSlippage(999n, 50)).toBe(1_004n);
  });
  it("clamps silly values", () => {
    expect(applySlippage(100n, -5)).toBe(100n);
    expect(applySlippage(100n, 99_999)).toBe(50n);
  });
});

describe("8-decimal formatting", () => {
  it("formats with up to 4 decimals and trims zeros", () => {
    expect(formatAmount(20n * ONE)).toBe("20");
    expect(formatAmount(123_456_789n)).toBe("1.2346");
    expect(formatAmount(150_000_000n)).toBe("1.5");
    expect(formatAmount(123_456_700_000_000n)).toBe("1,234,567");
  });
  it("shows dust as <0.0001", () => {
    expect(formatAmount(1n)).toBe("<0.0001");
    expect(formatAmount(0n)).toBe("0");
  });
  it("parses user input to 8-dec units", () => {
    expect(parseAmount("1")).toBe(ONE);
    expect(parseAmount("0.12345678")).toBe(12_345_678n);
    expect(parseAmount("1,000.5")).toBe(100_050_000_000n);
    expect(parseAmount("0.123456789")).toBeNull();
    expect(parseAmount("abc")).toBeNull();
    expect(parseAmount("")).toBeNull();
  });
});

describe("price impact", () => {
  it("is ~0 for a trade at spot after fee", () => {
    const out = (ONE * 997n) / 1000n; // spot 1:1, minus 0.3% fee
    expect(priceImpact(ONE, out, WAD)).toBeCloseTo(0, 6);
  });
  it("measures a worse fill", () => {
    const out = (ONE * 997n * 99n) / 100_000n;
    expect(priceImpact(ONE, out, WAD)).toBeCloseTo(0.01, 4);
  });
});
