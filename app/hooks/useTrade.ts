"use client";

import { useQuery } from "@tanstack/react-query";
import { useEffect, useMemo, useState } from "react";
import { parseEventLogs, type Abi, type TransactionReceipt } from "viem";
import { usePublicClient } from "wagmi";
import { faucetAbi, pieceAbi, routerAbi, stockAbi } from "@/lib/abis";
import { ADDRESSES } from "@/lib/addresses";
import { chain } from "@/lib/chain";
import { pieceLabel, type Market } from "@/lib/markets";
import { WAD, applySlippage, deadlineFromNow, formatAmount, parseAmount, priceImpact } from "@/lib/math";
import { quoteBuy, quoteSell } from "@/lib/quotes";
import type { TradeTab } from "@/components/TradeTabContext";
import type { AccountData } from "./useAccountData";
import type { MarketState } from "./useMarket";
import { useTx } from "./useTx";

export function useDebounced<T>(value: T, ms = 300) {
  const [v, setV] = useState(value);
  useEffect(() => {
    const t = setTimeout(() => setV(value), ms);
    return () => clearTimeout(t);
  }, [value, ms]);
  return v;
}

export type Quote = { out: bigint; minOut: bigint; impact: number };

export type Step =
  | { id: "connect"; label: string }
  | { id: "switch"; label: string }
  | { id: "gas"; label: string; href: string }
  | { id: "faucet"; label: string; disabled?: boolean }
  | { id: "enter"; label: string; disabled: true }
  | { id: "blocked"; label: string; disabled: true; hint?: string }
  | { id: "approve"; label: string; token: `0x${string}`; amount: bigint }
  | { id: "trade"; label: string };

export function useTrade({
  market,
  tab,
  input,
  slippageBps,
  acct,
  state,
}: {
  market: Market;
  tab: TradeTab;
  input: string;
  slippageBps: number;
  acct: AccountData;
  state: MarketState;
}) {
  const client = usePublicClient({ chainId: chain.id });
  const tx = useTx();
  const piece = market.pieces[tab.piece];
  const price = state.pieces[tab.piece]?.price; // stock per piece (WAD)
  const amount = parseAmount(input);
  const debounced = useDebounced(amount, 280);
  const now = Math.floor(Date.now() / 1000);
  const buying = tab.side === "buy";

  // ---- Quote ----
  const quote = useQuery({
    queryKey: ["quote", market.id, tab.side, tab.piece, debounced?.toString(), slippageBps, state.pieces[tab.piece]?.sqrtPriceX96?.toString()],
    enabled: !!client && !!debounced && debounced > 0n && price !== undefined && price > 0n,
    refetchInterval: 12_000,
    placeholderData: (prev) => prev,
    queryFn: async (): Promise<Quote> => {
      const a = debounced!;
      const out = buying ? await quoteBuy(client!, piece, a) : await quoteSell(client!, piece, a);
      const spot = buying ? (WAD * WAD) / price! : price!; // output per input (WAD)
      return { out, minOut: applySlippage(out, slippageBps), impact: priceImpact(a, out, spot) };
    },
  });

  const q = quote.data && debounced === amount ? quote.data : undefined;
  const quoting = !!amount && amount > 0n && (quote.isFetching || debounced !== amount) && !q;

  const inBalance = buying ? acct.stock : acct.pieces[tab.piece]?.balance;
  const inAllowance = buying ? acct.stockRouterAllowance : (acct.pieces[tab.piece]?.routerAllowance ?? 0n);
  const inToken = buying ? market.stock : piece.address;
  const inLabel = buying ? market.token : pieceLabel(piece);

  // ---- Step machine ----
  const step: Step = useMemo(() => {
    if (!acct.isConnected) return { id: "connect", label: "Connect wallet" };
    if (acct.wrongNetwork) return { id: "switch", label: "Switch to Base Sepolia" };
    if (acct.eth === 0n) return { id: "gas", label: "Get free Base Sepolia ETH for gas ↗", href: "https://portal.cdp.coinbase.com/products/faucet" };
    if (state.isPaused) return { id: "blocked", label: `Paused by the ${market.ticker} issuer`, disabled: true };

    if (buying && acct.stock === 0n) {
      const cooling = acct.nextClaimAt > now;
      return { id: "faucet", label: cooling ? "Faucet cooling down" : "Get free test stock tokens", disabled: cooling };
    }
    if (!buying && inBalance === 0n)
      return { id: "blocked", label: `You have no ${inLabel} yet`, disabled: true, hint: `Switch to Buy to get some ${inLabel}.` };

    if (!amount || amount === 0n) return { id: "enter", label: "Enter an amount", disabled: true };
    if (inBalance !== undefined && amount > inBalance) return { id: "blocked", label: `Not enough ${inLabel}`, disabled: true };
    if (!q) return { id: "enter", label: "Getting a quote…", disabled: true };
    if (inAllowance < amount) return { id: "approve", label: `Approve ${formatAmount(amount)} ${inLabel}`, token: inToken, amount };
    return { id: "trade", label: `${buying ? "Buy" : "Sell"} ${pieceLabel(piece)}` };
  }, [acct, state.isPaused, market, buying, inBalance, inAllowance, inToken, inLabel, piece, amount, q, now]);

  // ---- Execute ----
  const describe = (r: TransactionReceipt) => {
    const ev = parseEventLogs({ abi: routerAbi as Abi, logs: r.logs, eventName: buying ? "Bought" : "Sold" })[0] as
      | { args: Record<string, bigint> }
      | undefined;
    if (!ev) return { title: "Trade confirmed" };
    const a = ev.args;
    return buying
      ? { title: `Bought ${pieceLabel(piece)}`, lines: [`Paid ${formatAmount(a.stockIn)} ${market.token}`, `Received ${formatAmount(a.pieceOut)} ${pieceLabel(piece)}`] }
      : { title: `Sold ${pieceLabel(piece)}`, lines: [`Sold ${formatAmount(a.pieceIn)} ${pieceLabel(piece)}`, `Received ${formatAmount(a.stockOut)} ${market.token}`] };
  };

  async function run(): Promise<boolean> {
    const ok = await runStep();
    if (ok) await acct.refetch();
    return ok;
  }

  async function runStep(): Promise<boolean> {
    if (step.id === "faucet") {
      return !!(await tx.send({
        label: "Claiming test stock tokens",
        address: ADDRESSES.faucet,
        abi: faucetAbi as Abi,
        functionName: "claim",
        args: [],
        describe: () => ({ title: "Test tokens received", lines: ["20 GOOGLc and 20 NVDAc. You're ready to trade."] }),
      }));
    }
    if (step.id === "approve") {
      return !!(await tx.send({
        label: step.label.replace("Approve", "Approving"),
        address: step.token,
        abi: (buying ? stockAbi : pieceAbi) as Abi,
        functionName: "approve",
        args: [market.router, step.amount],
        describe: () => ({ title: "Approved", lines: ["Exact amount only. Now confirm the trade."] }),
      }));
    }
    if (step.id !== "trade" || !amount || !q) return false;
    return !!(await tx.send({
      label: `${buying ? "Buying" : "Selling"} ${pieceLabel(piece)}`,
      address: market.router,
      abi: routerAbi as Abi,
      functionName: buying ? "buy" : "sell",
      args: [BigInt(tab.piece), amount, q.minOut, deadlineFromNow()],
      describe,
    }));
  }

  return { piece, amount, quote: q, quoting, quoteError: quote.error, step, run, tx, inBalance, inLabel, buying };
}
