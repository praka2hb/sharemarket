"use client";

import type { Abi } from "viem";
import { useWallet } from "@/hooks/useAccountData";
import { formatCountdown, useNow } from "@/hooks/useNow";
import { useTx } from "@/hooks/useTx";
import { faucetAbi } from "@/lib/abis";
import { ADDRESSES } from "@/lib/addresses";
import { MARKETS } from "@/lib/markets";
import { StockIcon } from "./TokenIcon";

/** One-line testnet faucet: 20 of every mock stock token per 24h. */
export function FaucetCard() {
  const w = useWallet();
  const tx = useTx();
  const now = useNow();
  if (!w.isConnected) return null;
  const left = w.nextClaimAt - now;
  const cooling = left > 0;
  const names = MARKETS.map((m) => m.token).join(" + ");

  const claim = async () => {
    await tx.send({
      label: "Claiming test stock tokens",
      address: ADDRESSES.faucet,
      abi: faucetAbi as Abi,
      functionName: "claim",
      args: [],
      describe: () => ({ title: "Test tokens received", lines: [MARKETS.map((m) => `20 ${m.token}`).join(" and ")] }),
    });
    await w.refetch();
  };

  return (
    <div className="flex flex-wrap items-center justify-between gap-3 rounded-2xl border border-line px-4 py-3">
      <p className="flex items-center gap-2.5 text-[14px]">
        <span className="flex -space-x-1.5">
          {MARKETS.map((m) => (
            <StockIcon key={m.id} market={m} size={20} />
          ))}
        </span>
        <span>
          Test faucet <span className="text-ink-3">· 20 {names} per day</span>
        </span>
      </p>
      <button
        onClick={claim}
        disabled={cooling || tx.busy}
        className="num h-8 rounded-lg border border-line px-3 text-[13px] font-medium transition-colors hover:border-ink disabled:cursor-not-allowed disabled:text-ink-3 disabled:hover:border-line"
      >
        {tx.busy ? "Claiming…" : cooling ? `Next in ${formatCountdown(left)}` : "Claim"}
      </button>
    </div>
  );
}
