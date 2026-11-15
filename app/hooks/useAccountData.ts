"use client";

import type { ContractFunctionParameters } from "viem";
import { useAccount, useBalance, useReadContracts } from "wagmi";
import { faucetAbi, pieceAbi, stockAbi } from "@/lib/abis";
import { ADDRESSES } from "@/lib/addresses";
import { chain } from "@/lib/chain";
import type { Market } from "@/lib/markets";

const ZERO = "0x0000000000000000000000000000000000000000" as const;

/** Wallet, gas and faucet state (shared by every market). */
export function useWallet() {
  const { address, isConnected, chainId } = useAccount();
  const user = address ?? ZERO;
  const q = useReadContracts({
    allowFailure: true,
    contracts: [
      { chainId: chain.id, address: ADDRESSES.faucet, abi: faucetAbi, functionName: "lastClaim", args: [user] },
      { chainId: chain.id, address: ADDRESSES.faucet, abi: faucetAbi, functionName: "COOLDOWN" },
    ],
    query: { enabled: !!address, refetchInterval: 15_000 },
  });
  const eth = useBalance({ address, chainId: chain.id, query: { enabled: !!address, refetchInterval: 20_000 } });
  const lastClaim = q.data?.[0]?.result as bigint | undefined;
  const cooldown = (q.data?.[1]?.result as bigint | undefined) ?? 86_400n;
  return {
    address,
    isConnected,
    wrongNetwork: isConnected && chainId !== chain.id,
    eth: eth.data?.value,
    nextClaimAt: lastClaim && lastClaim > 0n ? Number(lastClaim + cooldown) : 0,
    refetch: async () => {
      await Promise.all([q.refetch(), eth.refetch()]);
    },
  };
}

/** Balances and allowances for one market, plus wallet state. */
export function useAccountData(market: Market) {
  const w = useWallet();
  const user = w.address ?? ZERO;
  const q = useReadContracts({
    allowFailure: true,
    contracts: [
      { chainId: chain.id, address: market.stock, abi: stockAbi, functionName: "balanceOf", args: [user] },
      { chainId: chain.id, address: market.stock, abi: stockAbi, functionName: "allowance", args: [user, market.router] },
      { chainId: chain.id, address: market.stock, abi: stockAbi, functionName: "allowance", args: [user, market.vault] },
      ...market.pieces.flatMap((p) => [
        { chainId: chain.id, address: p.address, abi: pieceAbi, functionName: "balanceOf", args: [user] } as const,
        { chainId: chain.id, address: p.address, abi: pieceAbi, functionName: "allowance", args: [user, market.router] } as const,
      ]),
    ] as ContractFunctionParameters[],
    query: { enabled: !!w.address, refetchInterval: 10_000 },
  });

  const r = <T,>(i: number) => q.data?.[i]?.result as T | undefined;
  const pieces = market.pieces.map((_, i) => ({ balance: r<bigint>(3 + i * 2), routerAllowance: r<bigint>(4 + i * 2) ?? 0n }));
  const balances = pieces.map((p) => p.balance);
  /** Complete sets you can merge right now: the smallest piece balance. */
  const sets = balances.every((b) => b !== undefined) ? balances.reduce((a, b) => (b! < a! ? b : a), balances[0]) : undefined;

  return {
    ...w,
    isLoading: !!w.address && q.isLoading,
    refetch: async () => {
      await Promise.all([q.refetch(), w.refetch()]);
    },
    stock: r<bigint>(0),
    stockRouterAllowance: r<bigint>(1) ?? 0n,
    stockVaultAllowance: r<bigint>(2) ?? 0n,
    pieces,
    sets,
  };
}

export type AccountData = ReturnType<typeof useAccountData>;
