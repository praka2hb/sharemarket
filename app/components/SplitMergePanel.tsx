"use client";

import { Fragment, useId, useState } from "react";
import { isAddress, parseEventLogs, type Abi } from "viem";
import { useAccountData } from "@/hooks/useAccountData";
import { useMarket } from "@/hooks/useMarket";
import { useTx } from "@/hooks/useTx";
import { stockAbi, vaultAbi } from "@/lib/abis";
import { formatAmount, parseAmount, toInputString } from "@/lib/math";
import { PieceIcon, StockIcon } from "./TokenIcon";
import { useMarketCtx } from "./TradeTabContext";

/** Power-user panel: split the stock token into one of every piece, or merge a full set back, exactly 1:1. */
export function SplitMergePanel() {
  const { market } = useMarketCtx();
  const [mode, setMode] = useState<"split" | "merge">("split");
  const [input, setInput] = useState("");
  const [toOther, setToOther] = useState(false);
  const [to, setTo] = useState("");
  const acct = useAccountData(market);
  const state = useMarket(market);
  const tx = useTx();
  const id = useId();
  const amount = parseAmount(input);
  const max = mode === "split" ? acct.stock : acct.sets;
  const recipient = toOther ? to : acct.address;
  const badTo = toOther && !!to && !isAddress(to);
  const tok = market.token;
  const pieceList = market.pieces.map((p) => `$${p.sym}`).join(" + ");

  let label = mode === "split" ? "Split" : "Merge";
  let disabled = false;
  let needsApprove = false;
  if (!acct.isConnected) {
    label = "Connect wallet to continue";
    disabled = true;
  } else if (state.isPaused) {
    label = `Paused by the ${market.ticker} issuer`;
    disabled = true;
  } else if (!amount) {
    label = "Enter an amount";
    disabled = true;
  } else if (max !== undefined && amount > max) {
    label = mode === "split" ? `Not enough ${tok}` : "Not enough full sets";
    disabled = true;
  } else if (!recipient || badTo) {
    label = "Enter a valid address";
    disabled = true;
  } else if (mode === "split" && acct.stockVaultAllowance < amount) {
    needsApprove = true;
    label = `Approve ${formatAmount(amount)} ${tok}`;
  } else {
    label = mode === "split" ? `Split ${formatAmount(amount)} ${tok}` : `Merge ${formatAmount(amount)} sets`;
  }

  const go = async () => {
    if (!amount || !recipient) return;
    if (needsApprove) {
      await tx.send({
        label: `Approving ${tok} for the vault`,
        address: market.stock,
        abi: stockAbi as Abi,
        functionName: "approve",
        args: [market.vault, amount],
        describe: () => ({ title: "Approved", lines: ["Exact amount only. Now split."] }),
      });
    } else {
      const r = await tx.send({
        label: mode === "split" ? "Splitting" : "Merging",
        address: market.vault,
        abi: vaultAbi as Abi,
        functionName: mode,
        args: [amount, recipient as `0x${string}`],
        describe: (rc) => {
          const ev = parseEventLogs({ abi: vaultAbi as Abi, logs: rc.logs, eventName: mode === "split" ? "Split" : "Merged" })[0] as
            | { args: { amount: bigint } }
            | undefined;
          const a = formatAmount(ev?.args.amount ?? amount);
          const each = market.pieces.map((p) => `${a} $${p.sym}`).join(" + ");
          return mode === "split" ? { title: "Split complete", lines: [`${a} ${tok} → ${each}`] } : { title: "Merged", lines: [`${each} → ${a} ${tok}`] };
        },
      });
      if (r) setInput("");
    }
    await acct.refetch();
  };

  const stockEq = (
    <span className="inline-flex items-center gap-1 rounded-full bg-bg px-2 py-1">
      <StockIcon market={market} size={14} />
      <span className="num">1</span>
      <span className="hidden sm:inline">{tok}</span>
    </span>
  );
  const piecesEq = market.pieces.map((p, i) => (
    <Fragment key={p.sym}>
      {i > 0 && <span className="text-ink-3">+</span>}
      <span className="inline-flex items-center gap-1 rounded-full bg-bg px-2 py-1">
        <PieceIcon piece={p} size={14} />
        <span className="num">1</span>
        <span className="hidden sm:inline">${p.sym}</span>
      </span>
    </Fragment>
  ));

  return (
    <section id="split-merge" aria-labelledby="sm-title" className="scroll-mt-24 rounded-2xl border border-line bg-bg p-4 sm:p-5">
      <div className="flex items-center justify-between gap-3">
        <div>
          <h2 id="sm-title" className="text-[15px] font-semibold tracking-tight">
            Split &amp; merge
          </h2>
          <p className="text-[12px] text-ink-3">For power users · always exactly 1:1</p>
        </div>
        <div role="tablist" aria-label="Split or merge" className="flex rounded-full bg-bg-soft p-1 text-[12px] font-semibold">
          {(["split", "merge"] as const).map((m) => (
            <button
              key={m}
              role="tab"
              aria-selected={mode === m}
              onClick={() => {
                setMode(m);
                setInput("");
              }}
              className={`rounded-full px-3 py-1.5 capitalize transition ${mode === m ? "bg-bg text-ink" : "text-ink-3"}`}
            >
              {m}
            </button>
          ))}
        </div>
      </div>

      <div
        className="mt-4 flex flex-wrap items-center justify-center gap-2 rounded-2xl bg-bg-soft p-3 text-[13px] font-medium"
        aria-label={mode === "split" ? `1 ${tok} becomes ${pieceList}` : `${pieceList} becomes 1 ${tok}`}
      >
        {mode === "split" ? (
          <>
            {stockEq} <span className="text-ink-3">→</span> {piecesEq}
          </>
        ) : (
          <>
            {piecesEq} <span className="text-ink-3">→</span> {stockEq}
          </>
        )}
      </div>

      <label htmlFor={id} className="label mt-4 flex justify-between">
        <span>{mode === "split" ? `${tok} to split` : "Sets to merge"}</span>
        <span className="num normal-case tracking-normal">
          {mode === "split" ? "Balance" : "Full sets"} {formatAmount(max)}
          {max !== undefined && max > 0n && (
            <button onClick={() => setInput(toInputString(max))} className="ml-1.5 font-semibold text-ink">
              MAX
            </button>
          )}
        </span>
      </label>
      <input
        id={id}
        inputMode="decimal"
        placeholder="0"
        autoComplete="off"
        value={input}
        onChange={(e) => /^\d*\.?\d{0,8}$/.test(e.target.value) && setInput(e.target.value)}
        className="num mt-1.5 h-12 w-full rounded-xl border border-line bg-bg-soft px-3 text-[20px] font-medium outline-none focus:border-line-strong"
      />
      {amount ? (
        <p className="num mt-2 text-[12px] text-ink-2">
          {mode === "split"
            ? `You get ${market.pieces.map((p) => `${formatAmount(amount)} $${p.sym}`).join(" + ")}`
            : `You get exactly ${formatAmount(amount)} ${tok} back. No fee, no price.`}
        </p>
      ) : null}
      {mode === "merge" && <p className="mt-1.5 text-[11px] text-ink-3">A full set is one of every piece. Merging needs all {market.pieces.length}.</p>}

      <label className="mt-3 flex cursor-pointer items-center gap-2 text-[12px] text-ink-2">
        <input type="checkbox" checked={toOther} onChange={(e) => setToOther(e.target.checked)} className="size-3.5 accent-[var(--ink)]" />
        Send to a different address
      </label>
      {toOther && (
        <input
          aria-label="Recipient address"
          placeholder="0x…"
          value={to}
          onChange={(e) => setTo(e.target.value.trim())}
          className={`num mt-2 h-10 w-full rounded-xl border bg-bg-soft px-3 text-[13px] outline-none ${badTo ? "border-down" : "border-line focus:border-line-strong"}`}
        />
      )}
      {toOther && mode === "merge" && <p className="mt-1.5 text-[11px] text-ink-3">Useful if the {market.ticker} issuer has blocked your own address.</p>}

      <button
        onClick={go}
        disabled={disabled || tx.busy}
        className="mt-4 flex h-11 w-full items-center justify-center gap-2 rounded-xl bg-ink text-[14px] font-semibold text-bg transition active:scale-[0.99] disabled:cursor-not-allowed disabled:bg-bg-sunken disabled:text-ink-3"
      >
        {tx.busy && <span className="spinner size-4 rounded-full border-2 border-current border-t-transparent" />}
        {tx.status === "wallet" ? "Confirm in wallet…" : tx.status === "pending" ? "Confirming…" : label}
      </button>
      {needsApprove && <p className="mt-2 text-center text-[11px] text-ink-3">Exact approval to the vault, never unlimited.</p>}
      {tx.error && tx.error.kind !== "rejected" && (
        <p role="alert" className="mt-2 text-[12px] text-down">
          {tx.error.message}
        </p>
      )}
    </section>
  );
}
