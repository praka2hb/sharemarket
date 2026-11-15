import { encodeAbiParameters, keccak256, type Address } from "viem";
import { DEPLOYED } from "./addresses";

/**
 * A market = one company's stock token split into one piece per reported business line.
 * 1 stock token = 1 of every piece. Each piece trades against the stock token in its own Uniswap v4 pool.
 */
export type Piece = {
  index: number;
  /** Short ticker shown in the UI, e.g. "SEARCH". On-chain symbol is "SEARCH-GOOGL". */
  sym: string;
  name: string;
  includes: string;
  /** Display colour (works on light and dark). */
  color: string;
  /** Optional logo in /public. */
  logo?: string;
  /** Share of the pieces' combined revenue in the latest report, percent. Context only. */
  reported: number;
  address: Address;
  /** True if the piece is currency0 in its pool (sorted below the stock token). */
  pieceIs0: boolean;
  poolKey: PoolKey;
  poolId: `0x${string}`;
};

export type PoolKey = {
  currency0: Address;
  currency1: Address;
  fee: number;
  tickSpacing: number;
  hooks: Address;
};

export type Market = {
  id: string;
  company: string;
  ticker: string;
  /** Stock token symbol, e.g. GOOGLc. */
  token: string;
  logo?: string;
  /** Brand colour for the stock token's fallback icon. */
  tokenColor: string;
  /** Where the reported mix comes from. */
  reportedLabel: string;
  stock: Address;
  vault: Address;
  router: Address;
  pieces: Piece[];
};

export type SoonMarket = { id: string; company: string; ticker: string; lines: string[] };

const FEE = 3000;
const TICK_SPACING = 60;
const NO_HOOKS = "0x0000000000000000000000000000000000000000" as const;

function poolFor(stock: Address, piece: Address) {
  const pieceIs0 = piece.toLowerCase() < stock.toLowerCase();
  const key: PoolKey = {
    currency0: pieceIs0 ? piece : stock,
    currency1: pieceIs0 ? stock : piece,
    fee: FEE,
    tickSpacing: TICK_SPACING,
    hooks: NO_HOOKS,
  };
  const poolId = keccak256(
    encodeAbiParameters(
      [{ type: "address" }, { type: "address" }, { type: "uint24" }, { type: "int24" }, { type: "address" }],
      [key.currency0, key.currency1, key.fee, key.tickSpacing, key.hooks],
    ),
  );
  return { pieceIs0, poolKey: key, poolId };
}

type PieceMeta = Omit<Piece, "index" | "address" | "pieceIs0" | "poolKey" | "poolId">;

function build(
  id: keyof typeof DEPLOYED,
  meta: Omit<Market, "id" | "stock" | "vault" | "router" | "pieces">,
  pieces: PieceMeta[],
): Market {
  const d = DEPLOYED[id];
  if (d.pieces.length !== pieces.length) throw new Error(`${id}: deployment has ${d.pieces.length} pieces, config has ${pieces.length}`);
  return {
    id: id.toLowerCase(),
    ...meta,
    stock: d.stock,
    vault: d.vault,
    router: d.router,
    pieces: pieces.map((p, i) => ({ ...p, index: i, address: d.pieces[i], ...poolFor(d.stock, d.pieces[i]) })),
  };
}

export const MARKETS: Market[] = [
  build(
    "GOOGL",
    { company: "Alphabet", ticker: "GOOGL", token: "GOOGLc", logo: "/tokens/google.png", tokenColor: "#4285F4", reportedLabel: "Q3 2026" },
    [
      { sym: "SEARCH", name: "Google Search", includes: "Search & other ads revenue", color: "#4285F4", reported: 60.18 },
      { sym: "YOUTUBE", name: "YouTube ads", includes: "Advertising on YouTube", color: "#FF3B30", reported: 10.65 },
      { sym: "CLOUD", name: "Google Cloud", includes: "Cloud platform, Workspace, AI infrastructure", color: "#34A853", logo: "/tokens/cloud.png", reported: 29.17 },
    ],
  ),
  build(
    "NVDA",
    { company: "NVIDIA", ticker: "NVDA", token: "NVDAc", tokenColor: "#76B900", reportedLabel: "Q2 FY2027" },
    [
      { sym: "HYPERSCALE", name: "Hyperscale", includes: "GPUs and systems sold to the biggest cloud providers", color: "#76B900", reported: 50.62 },
      { sym: "AICLOUD", name: "AI clouds & enterprise", includes: "AI clouds, industrial and enterprise customers", color: "#0EA5E9", reported: 41.9 },
      { sym: "EDGE", name: "Edge", includes: "Gaming, PCs, robotics and cars", color: "#A855F7", reported: 7.48 },
    ],
  ),
];

export const SOON: SoonMarket[] = [
  { id: "amzn", company: "Amazon", ticker: "AMZN", lines: ["AWS", "North America", "International"] },
  { id: "msft", company: "Microsoft", ticker: "MSFT", lines: ["Intelligent Cloud", "Productivity & Business", "Personal Computing"] },
];

export const getMarket = (id: string) => MARKETS.find((m) => m.id === id.toLowerCase());
export const marketHref = (id: string) => `/markets/${id}`;
export const pieceLabel = (p: Pick<Piece, "sym">) => `$${p.sym}`;
