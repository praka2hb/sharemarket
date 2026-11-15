"use client";

import type { ContractFunctionParameters } from "viem";
import { useReadContracts } from "wagmi";
import { pieceAbi, stateViewAbi, stockAbi, vaultAbi } from "@/lib/abis";
import { ADDRESSES } from "@/lib/addresses";
import { chain } from "@/lib/chain";
import { MARKETS, type Market } from "@/lib/markets";
import { piecePriceWad, pricePct } from "@/lib/math";

export type PieceState = {
  sqrtPriceX96?: bigint;
  liquidity?: bigint;
  /** Piece price in stock tokens (WAD). */
  price?: bigint;
  /** Price as a percent of one stock token. */
  pct?: number;
  supply?: bigint;
};

/** Everything public about one market, in one multicall, refreshed every 10s. */
export function useMarket(market: Market) {
  const n = market.pieces.length;
  const sv = { chainId: chain.id, address: ADDRESSES.stateView, abi: stateViewAbi } as const;
  const q = useReadContracts({
    allowFailure: true,
    contracts: [
      { chainId: chain.id, address: market.stock, abi: stockAbi, functionName: "balanceOf", args: [market.vault] },
      { chainId: chain.id, address: market.stock, abi: stockAbi, functionName: "pausedFeatures" },
      { chainId: chain.id, address: market.vault, abi: vaultAbi, functionName: "setsOutstanding" },
      ...market.pieces.flatMap((p) => [
        { ...sv, functionName: "getSlot0", args: [p.poolId] } as const,
        { ...sv, functionName: "getLiquidity", args: [p.poolId] } as const,
        { chainId: chain.id, address: p.address, abi: pieceAbi, functionName: "totalSupply" } as const,
      ]),
    ] as ContractFunctionParameters[],
    query: { refetchInterval: 10_000 },
  });

  const d = q.data;
  const paused = d?.[1]?.result as readonly number[] | undefined;
  const pieces: PieceState[] = market.pieces.map((p, i) => {
    const base = 3 + i * 3;
    const slot0 = d?.[base]?.result as readonly [bigint, number, number, number] | undefined;
    const sqrt = slot0?.[0];
    const price = sqrt !== undefined && sqrt > 0n ? piecePriceWad(sqrt, p.pieceIs0) : undefined;
    return {
      sqrtPriceX96: sqrt,
      liquidity: d?.[base + 1]?.result as bigint | undefined,
      price,
      pct: price !== undefined ? pricePct(price) : undefined,
      supply: d?.[base + 2]?.result as bigint | undefined,
    };
  });
  const allPriced = pieces.every((p) => p.pct !== undefined);

  return {
    market,
    isLoading: q.isLoading,
    isError: q.isError && !d,
    refetch: q.refetch,
    updatedAt: q.dataUpdatedAt,
    pieces,
    /** Sum of all piece prices, percent of one stock token. Arbitrage keeps it near 100. */
    sumPct: allPriced ? pieces.reduce((a, p) => a + p.pct!, 0) : undefined,
    vaultStock: d?.[0]?.result as bigint | undefined,
    pausedFeatures: paused,
    isPaused: !!paused && paused.length > 0,
    setsOutstanding: d?.[2]?.result as bigint | undefined,
    count: n,
  };
}

export type MarketState = ReturnType<typeof useMarket>;

/** Pause state of every stock token, for the global banner. */
export function usePausedStocks() {
  const q = useReadContracts({
    allowFailure: true,
    contracts: MARKETS.map((m) => ({ chainId: chain.id, address: m.stock, abi: stockAbi, functionName: "pausedFeatures" }) as const),
    query: { refetchInterval: 15_000 },
  });
  return MARKETS.filter((_, i) => {
    const r = q.data?.[i]?.result as readonly number[] | undefined;
    return !!r && r.length > 0;
  });
}
