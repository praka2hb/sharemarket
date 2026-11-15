import { formatUnits, parseUnits } from "viem";

/** Stock tokens and pieces all use 8 decimals. */
export const DECIMALS = 8;
export const ONE = 10n ** 8n;
export const WAD = 10n ** 18n;
const Q192 = 1n << 192n;

/** Pool fee: 3000 pips = 0.30%. */
export const FEE_PIPS = 3000n;

/**
 * Piece price in stock tokens, as an 18-decimal fixed-point bigint.
 * A v4 pool stores sqrt(currency1 / currency0). Pieces and stock tokens both have 8 decimals,
 * so no decimal adjustment is needed.
 *   piece is currency0: stock per piece = price      = sqrt^2 / 2^192
 *   piece is currency1: stock per piece = 1 / price  = 2^192 / sqrt^2
 */
export function piecePriceWad(sqrtPriceX96: bigint, pieceIs0: boolean): bigint {
  if (sqrtPriceX96 <= 0n) return 0n;
  const sq = sqrtPriceX96 * sqrtPriceX96;
  return pieceIs0 ? (sq * WAD) / Q192 : (Q192 * WAD) / sq;
}

/** WAD → JS number. For display only; never send this on-chain. */
export function wadToNumber(wad: bigint): number {
  return Number(formatUnits(wad, 18));
}

/** A WAD price in stock tokens as a percent of one stock token (display). */
export function pricePct(priceWad: bigint): number {
  return wadToNumber(priceWad) * 100;
}

/** Value of `amount` (8-dec) at `priceWad`, in 8-dec GOOGLc. */
export function valueAt(amount: bigint, priceWad: bigint): bigint {
  return (amount * priceWad) / WAD;
}

/** Slippage in basis points (50 = 0.5%). minOut = quote × (1 − slippage), rounded down. */
export function applySlippage(quote: bigint, slippageBps: number): bigint {
  const bps = BigInt(Math.max(0, Math.min(5000, Math.round(slippageBps))));
  return (quote * (10_000n - bps)) / 10_000n;
}

/** Inflate an input amount for exact-output quotes (rounded up). */
export function addSlippage(amount: bigint, slippageBps: number): bigint {
  const bps = BigInt(Math.max(0, Math.min(5000, Math.round(slippageBps))));
  return (amount * (10_000n + bps) + 9_999n) / 10_000n;
}

/** Unix-seconds deadline, default 10 minutes from now. */
export function deadlineFromNow(seconds = 600): bigint {
  return BigInt(Math.floor(Date.now() / 1000) + seconds);
}

/**
 * Price impact (fraction, positive = worse than spot) of a swap, excluding the 0.30% fee.
 * `spotOutPerIn` is the spot rate as WAD: how much output 1 unit of input buys.
 */
export function priceImpact(amountIn: bigint, amountOut: bigint, spotOutPerInWad: bigint): number {
  if (amountIn === 0n || spotOutPerInWad === 0n) return 0;
  const inAfterFee = (amountIn * (1_000_000n - FEE_PIPS)) / 1_000_000n;
  const ideal = (inAfterFee * spotOutPerInWad) / WAD;
  if (ideal === 0n) return 0;
  const impact = Number(ideal - amountOut) / Number(ideal);
  return Math.max(0, impact);
}

/** Parse a user-typed amount into 8-dec units. Returns null for invalid or empty input. */
export function parseAmount(input: string): bigint | null {
  const s = input.trim().replace(/,/g, "");
  if (!s || !/^\d*\.?\d*$/.test(s) || s === ".") return null;
  const [, frac = ""] = s.split(".");
  if (frac.length > DECIMALS) return null;
  try {
    return parseUnits(s, DECIMALS);
  } catch {
    return null;
  }
}

/** 8-dec bigint → human string with up to `maxFrac` decimals, trailing zeros trimmed, thousands grouped. */
export function formatAmount(amount: bigint | undefined, maxFrac = 4): string {
  if (amount === undefined) return "—";
  const neg = amount < 0n;
  const abs = neg ? -amount : amount;
  const scale = 10n ** BigInt(DECIMALS - maxFrac);
  const rounded = (abs + scale / 2n) / scale; // round half up to maxFrac
  const whole = rounded / 10n ** BigInt(maxFrac);
  let frac = (rounded % 10n ** BigInt(maxFrac)).toString().padStart(maxFrac, "0").replace(/0+$/, "");
  if (whole === 0n && frac === "" && abs > 0n) {
    return `${neg ? "-" : ""}<0.${"0".repeat(maxFrac - 1)}1`;
  }
  const wholeStr = whole.toString().replace(/\B(?=(\d{3})+(?!\d))/g, ",");
  return `${neg ? "-" : ""}${wholeStr}${frac ? "." + frac : ""}`;
}

/** 8-dec bigint → plain string for an input field (full precision, no grouping). */
export function toInputString(amount: bigint): string {
  return formatUnits(amount, DECIMALS);
}

/** WAD price → fixed 4-decimal string. */
export function formatPrice(wad: bigint | undefined, digits = 4): string {
  if (wad === undefined) return "—";
  return wadToNumber(wad).toFixed(digits);
}

export function formatPct(n: number | undefined, digits = 2): string {
  if (n === undefined || !Number.isFinite(n)) return "—";
  return `${n.toFixed(digits)}%`;
}
