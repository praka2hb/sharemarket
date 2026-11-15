"use client";

import { useQuery } from "@tanstack/react-query";
import { parseAbiItem, type Address } from "viem";
import { ADDRESSES, DEPLOY_BLOCK } from "@/lib/addresses";
import { BLOCK_TIME_S, LOGS_CHUNK, logsClient } from "@/lib/chain";
import { MARKETS, type Market, type Piece } from "@/lib/markets";
import { piecePriceWad, pricePct } from "@/lib/math";

const initializeEvent = parseAbiItem(
  "event Initialize(bytes32 indexed id, address indexed currency0, address indexed currency1, uint24 fee, int24 tickSpacing, address hooks, uint160 sqrtPriceX96, int24 tick)",
);
const swapEvent = parseAbiItem(
  "event Swap(bytes32 indexed id, address indexed sender, int128 amount0, int128 amount1, uint160 sqrtPriceX96, uint128 liquidity, int24 tick, uint24 fee)",
);

async function head() {
  const block = await logsClient.getBlock({ blockTag: "latest" });
  return { number: block.number, timestamp: Number(block.timestamp) };
}

/** Block → unix seconds. Base makes a block every 2s, so we can date events without fetching each block. */
const dateOf = (h: { number: bigint; timestamp: number }, bn: bigint) => h.timestamp - Number(h.number - bn) * BLOCK_TIME_S;

function ranges(from: bigint, to: bigint) {
  const out: [bigint, bigint][] = [];
  for (let a = from; a <= to; a += LOGS_CHUNK) out.push([a, a + LOGS_CHUNK - 1n > to ? to : a + LOGS_CHUNK - 1n]);
  return out;
}

export type PricePoint = { t: number; block: bigint; pct: number; kind: "open" | "swap" };

/** Real price history of one piece from its pool's Initialize + Swap events. Never synthesised. */
export function usePriceHistory(piece: Piece) {
  return useQuery({
    queryKey: ["price-history", piece.poolId],
    refetchInterval: 30_000,
    queryFn: async (): Promise<PricePoint[]> => {
      const h = await head();
      const chunks = ranges(DEPLOY_BLOCK, h.number);
      const results = await Promise.all(
        chunks.map(async ([fromBlock, toBlock]) => {
          const [init, swaps] = await Promise.all([
            logsClient.getLogs({ address: ADDRESSES.poolManager, event: initializeEvent, args: { id: piece.poolId }, fromBlock, toBlock }),
            logsClient.getLogs({ address: ADDRESSES.poolManager, event: swapEvent, args: { id: piece.poolId }, fromBlock, toBlock }),
          ]);
          return [
            ...init.map((l) => ({ l, kind: "open" as const, sqrt: l.args.sqrtPriceX96! })),
            ...swaps.map((l) => ({ l, kind: "swap" as const, sqrt: l.args.sqrtPriceX96! })),
          ];
        }),
      );
      return results
        .flat()
        .sort((a, b) => Number(a.l.blockNumber! - b.l.blockNumber!) || (a.l.logIndex ?? 0) - (b.l.logIndex ?? 0))
        .map(({ l, kind, sqrt }) => ({ t: dateOf(h, l.blockNumber!), block: l.blockNumber!, pct: pricePct(piecePriceWad(sqrt, piece.pieceIs0)), kind }));
    },
  });
}

const routerEvents = [
  parseAbiItem("event Bought(address indexed user, uint256 indexed piece, uint256 stockIn, uint256 pieceOut)"),
  parseAbiItem("event Sold(address indexed user, uint256 indexed piece, uint256 pieceIn, uint256 stockOut)"),
] as const;
const vaultEvents = [
  parseAbiItem("event Split(address indexed user, address indexed to, uint256 amount)"),
  parseAbiItem("event Merged(address indexed user, address indexed to, uint256 amount)"),
] as const;

export type Activity = {
  kind: "Bought" | "Sold" | "Split" | "Merged";
  market: Market;
  hash: `0x${string}`;
  t: number;
  block: bigint;
  args: Record<string, bigint | string>;
};

/** The user's own router and vault events across every market, newest first. */
export function useActivity(user?: Address) {
  return useQuery({
    queryKey: ["activity", user],
    enabled: !!user,
    refetchInterval: 30_000,
    queryFn: async (): Promise<Activity[]> => {
      const h = await head();
      const chunks = ranges(DEPLOY_BLOCK, h.number);
      const jobs = MARKETS.flatMap((market) =>
        chunks.flatMap(([fromBlock, toBlock]) => [
          ...routerEvents.map((event) =>
            logsClient.getLogs({ address: market.router, event, args: { user }, fromBlock, toBlock }).then((ls) => ls.map((l) => ({ l, market }))),
          ),
          ...vaultEvents.map((event) =>
            logsClient.getLogs({ address: market.vault, event, args: { user }, fromBlock, toBlock }).then((ls) => ls.map((l) => ({ l, market }))),
          ),
        ]),
      );
      const all = await Promise.all(jobs);
      return all
        .flat()
        .map(({ l, market }) => ({
          kind: l.eventName as Activity["kind"],
          market,
          hash: l.transactionHash!,
          block: l.blockNumber!,
          t: dateOf(h, l.blockNumber!),
          args: l.args as Record<string, bigint | string>,
        }))
        .sort((a, b) => Number(b.block - a.block));
    },
  });
}
