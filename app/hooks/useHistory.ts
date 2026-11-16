"use client";

import { useQuery } from "@tanstack/react-query";
import { parseAbiItem, type Address } from "viem";
import { ADDRESSES, DEPLOY_BLOCK } from "@/lib/addresses";
import { LOGS_CHUNK, logsClient } from "@/lib/chain";
import { MARKETS, type Market, type Piece } from "@/lib/markets";
import { piecePriceWad, pricePct } from "@/lib/math";

const initializeEvent = parseAbiItem(
  "event Initialize(bytes32 indexed id, address indexed currency0, address indexed currency1, uint24 fee, int24 tickSpacing, address hooks, uint160 sqrtPriceX96, int24 tick)",
);
const swapEvent = parseAbiItem(
  "event Swap(bytes32 indexed id, address indexed sender, int128 amount0, int128 amount1, uint160 sqrtPriceX96, uint128 liquidity, int24 tick, uint24 fee)",
);

type Head = { number: bigint; timestamp: number; start: number };

let deployTs: Promise<number> | null = null;

/** Latest block, plus the deploy block's timestamp (fetched once), for dating events. */
async function head(): Promise<Head> {
  deployTs ??= logsClient.getBlock({ blockNumber: DEPLOY_BLOCK }).then((b) => Number(b.timestamp));
  const [block, start] = await Promise.all([logsClient.getBlock({ blockTag: "latest" }), deployTs]);
  return { number: block.number, timestamp: Number(block.timestamp), start };
}

/**
 * Block → unix seconds without fetching each block: interpolate between the deploy block and the latest block.
 * Block times change (Base Sepolia went from 2s to sub-second), so the rate is measured, not assumed.
 */
const dateOf = (h: Head, bn: bigint) => {
  const span = Number(h.number - DEPLOY_BLOCK);
  if (span <= 0) return h.timestamp;
  const perBlock = (h.timestamp - h.start) / span;
  return Math.round(h.start + Number(bn - DEPLOY_BLOCK) * perBlock);
};

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

export type Activity = {
  kind: "Bought" | "Sold";
  market: Market;
  hash: `0x${string}`;
  t: number;
  block: bigint;
  args: Record<string, bigint | string>;
};

/** The user's own trades across every market, newest first. */
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
