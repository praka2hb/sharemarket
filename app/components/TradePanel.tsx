"use client";

import { useEffect, useId, useRef, useState } from "react";
import { useSwitchChain } from "wagmi";
import { useAccountData } from "@/hooks/useAccountData";
import { useMarket } from "@/hooks/useMarket";
import { formatCountdown, useNow } from "@/hooks/useNow";
import { useTrade } from "@/hooks/useTrade";
import { chain } from "@/lib/chain";
import { pieceLabel } from "@/lib/markets";
import { formatAmount, formatPrice, toInputString } from "@/lib/math";
import { PieceIcon, StockIcon } from "./TokenIcon";
import { useMarketCtx } from "./TradeTabContext";
import { ConnectModal } from "./Wallet";

export function TradePanel() {
  const { market, tab, setTab } = useMarketCtx();
  const acct = useAccountData(market);
  const state = useMarket(market);
  const [input, setInput] = useState("");
  const [slippageBps, setSlippageBps] = useState(50);
  const [showConnect, setShowConnect] = useState(false);
  const { switchChain } = useSwitchChain();
  const t = useTrade({ market, tab, input, slippageBps, acct, state });
  const inputId = useId();
  const now = useNow();
  const piece = t.piece;

  // Amounts never carry across tokens.
  const first = useRef(true);
  useEffect(() => {
    if (first.current) {
      first.current = false;
      return;
    }
    setInput("");
    t.tx.reset();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [tab.side, tab.piece]);

  const onPrimary = async () => {
    const s = t.step;
    if (s.id === "connect") return setShowConnect(true);
    if (s.id === "switch") return switchChain({ chainId: chain.id });
    if (s.id === "gas") return window.open(s.href, "_blank", "noopener");
    const ok = await t.run();
    if (ok && s.id === "trade") setInput("");
  };

  const s = t.step;
  const disabled = ("disabled" in s && s.disabled) || t.tx.busy;
  const busyLabel = t.tx.status === "wallet" ? "Confirm in your wallet…" : t.tx.status === "pending" ? "Confirming…" : null;
  const stepHint = s.id === "approve" ? "Step 1 of 2 · exact amount only, never unlimited" : null;
  const balance = t.inBalance;

  return (
    <section aria-labelledby="trade-title" className="rounded-2xl border border-line bg-bg p-4 sm:p-5">
      <div className="flex items-center justify-between">
        <h2 id="trade-title" className="text-[15px] font-semibold">
          Trade
        </h2>
        <SlippageControl value={slippageBps} onChange={setSlippageBps} />
      </div>

      {/* Buy / Sell */}
      <div role="radiogroup" aria-label="Buy or sell" className="mt-4 grid grid-cols-2 rounded-xl bg-bg-sunken p-1 text-[14px] font-medium">
        {(["buy", "sell"] as const).map((v) => (
          <button
            key={v}
            role="radio"
            aria-checked={tab.side === v}
            onClick={() => setTab({ ...tab, side: v })}
            className={`h-9 rounded-lg capitalize transition-colors ${tab.side === v ? "bg-bg text-ink shadow-[0_1px_2px_rgba(0,0,0,0.08)]" : "text-ink-2 hover:text-ink"}`}
          >
            {v}
          </button>
        ))}
      </div>

      {/* Piece */}
      <p className="mt-4 mb-2 text-[12px] text-ink-3">Piece</p>
      <div role="radiogroup" aria-label="Piece" className="grid grid-cols-3 gap-2">
        {market.pieces.map((p, i) => (
          <button
            key={p.sym}
            role="radio"
            aria-checked={tab.piece === i}
            onClick={() => setTab({ ...tab, piece: i })}
            className={`flex min-w-0 flex-col gap-1 rounded-xl border px-2.5 py-2 text-left transition-colors ${tab.piece === i ? "border-ink" : "border-line hover:border-line-strong"}`}
          >
            <span className="flex min-w-0 items-center gap-1.5">
              <PieceIcon piece={p} size={16} />
              <span className="truncate text-[12px] font-medium">{p.sym}</span>
            </span>
            <span className="num block text-[11px] text-ink-3">{formatPrice(state.pieces[i]?.price)}</span>
          </button>
        ))}
      </div>

      {/* Amount */}
      <div className="mt-4 rounded-xl border border-line p-3 transition-colors focus-within:border-ink">
        <div className="flex items-center justify-between text-[12px] text-ink-3">
          <label htmlFor={inputId}>{t.buying ? "You pay" : "You sell"}</label>
          {acct.isConnected && (
            <span className="num">
              {formatAmount(balance)} available
              {balance !== undefined && balance > 0n && (
                <button onClick={() => setInput(toInputString(balance))} className="ml-2 font-medium text-ink hover:underline">
                  Max
                </button>
              )}
            </span>
          )}
        </div>
        <div className="mt-1 flex items-center gap-2">
          <input
            id={inputId}
            inputMode="decimal"
            autoComplete="off"
            placeholder="0"
            value={input}
            onChange={(e) => {
              const v = e.target.value.replace(",", ".");
              if (/^\d*\.?\d{0,8}$/.test(v)) setInput(v);
            }}
            className="num min-w-0 flex-1 bg-transparent text-[28px] font-medium tracking-tight outline-none placeholder:text-ink-3/50"
          />
          <span className="flex shrink-0 items-center gap-1.5 text-[14px] font-medium">
            {t.buying ? <StockIcon market={market} size={20} /> : <PieceIcon piece={piece} size={20} />}
            {t.inLabel}
          </span>
        </div>
      </div>

      {/* Receive */}
      <Receive t={t} outLabel={t.buying ? pieceLabel(piece) : market.token} outIcon={t.buying ? <PieceIcon piece={piece} size={16} /> : <StockIcon market={market} size={16} />} />

      <button
        onClick={onPrimary}
        disabled={disabled}
        className="mt-4 flex h-12 w-full items-center justify-center gap-2 rounded-xl bg-ink text-[15px] font-medium text-bg transition-opacity hover:opacity-90 active:opacity-80 disabled:cursor-not-allowed disabled:bg-bg-sunken disabled:text-ink-3 disabled:hover:opacity-100"
      >
        {t.tx.busy && <span className="spinner size-4 rounded-full border-2 border-current border-t-transparent" />}
        {busyLabel ?? s.label}
      </button>

      <p className="mt-2 min-h-[16px] text-center text-[12px] text-ink-3">
        {s.id === "faucet" && s.disabled
          ? `Next free tokens in ${formatCountdown(acct.nextClaimAt - now)}`
          : "hint" in s && s.hint
            ? s.hint
            : (stepHint ?? (s.id === "gas" ? "Free test ETH from the Coinbase faucet" : ""))}
      </p>

      {t.tx.error && t.tx.error.kind !== "rejected" && (
        <p role="alert" className="mt-2 rounded-lg bg-down/8 p-3 text-[13px] text-down">
          {t.tx.error.message}
        </p>
      )}
      {t.quoteError && !t.quote && (
        <p role="alert" className="mt-2 text-center text-[13px] text-down">
          Couldn&apos;t get a quote. The amount may be too large for the pool.
        </p>
      )}
      {showConnect && <ConnectModal onClose={() => setShowConnect(false)} />}
    </section>
  );
}

type T = ReturnType<typeof useTrade>;

function Receive({ t, outLabel, outIcon }: { t: T; outLabel: string; outIcon: React.ReactNode }) {
  const q = t.quote;
  const has = !!t.amount && t.amount > 0n;
  const impact = q ? q.impact * 100 : 0;
  const rows: [string, string, string?][] = [];
  if (q && has) {
    rows.push(["Minimum", `${formatAmount(q.minOut)} ${outLabel}`]);
    rows.push(["Price impact", `${impact < 0.01 ? "<0.01" : impact.toFixed(2)}%`, impact > 5 ? "bad" : impact > 1.5 ? "warn" : undefined]);
    rows.push(["Fee", "0.30%"]);
  }

  return (
    <div className="mt-3 rounded-xl bg-bg-soft p-3 text-[13px]">
      <div className="flex items-center justify-between">
        <span className="text-ink-2">You receive</span>
        <span className="num flex items-center gap-1.5 font-medium">
          {t.quoting ? <span className="skeleton inline-block h-4 w-16" /> : has && q ? formatAmount(q.out) : "0"}
          {outIcon}
          {outLabel}
        </span>
      </div>
      {rows.length > 0 && (
        <dl className="mt-2 space-y-1 border-t border-line pt-2 text-[12px]">
          {rows.map(([k, v, tone]) => (
            <div key={k} className="flex justify-between">
              <dt className="text-ink-3">{k}</dt>
              <dd className={`num ${tone === "bad" ? "text-down" : tone === "warn" ? "text-warn-ink" : "text-ink-2"}`}>{v}</dd>
            </div>
          ))}
        </dl>
      )}
    </div>
  );
}

function SlippageControl({ value, onChange }: { value: number; onChange: (v: number) => void }) {
  const [open, setOpen] = useState(false);
  const [custom, setCustom] = useState("");
  const ref = useRef<HTMLDivElement>(null);
  useEffect(() => {
    const on = (e: MouseEvent) => !ref.current?.contains(e.target as Node) && setOpen(false);
    document.addEventListener("mousedown", on);
    return () => document.removeEventListener("mousedown", on);
  }, []);
  return (
    <div ref={ref} className="relative">
      <button
        onClick={() => setOpen((o) => !o)}
        aria-expanded={open}
        className="num rounded-lg px-2 py-1 text-[12px] text-ink-2 transition-colors hover:bg-bg-sunken hover:text-ink"
      >
        Slippage {(value / 100).toFixed(1)}%
      </button>
      {open && (
        <div className="pop-in absolute right-0 z-30 mt-1 w-56 rounded-xl border border-line bg-bg p-3 shadow-lg">
          <p className="mb-2 text-[12px] text-ink-3">Max slippage</p>
          <div className="grid grid-cols-4 gap-1.5">
            {[10, 50, 100].map((b) => (
              <button
                key={b}
                onClick={() => {
                  onChange(b);
                  setCustom("");
                }}
                className={`num h-8 rounded-lg text-[12px] transition-colors ${value === b && !custom ? "bg-ink text-bg" : "bg-bg-sunken hover:bg-line"}`}
              >
                {b / 100}%
              </button>
            ))}
            <input
              aria-label="Custom slippage percent"
              inputMode="decimal"
              placeholder="—"
              value={custom}
              onChange={(e) => {
                const v = e.target.value;
                if (!/^\d*\.?\d{0,2}$/.test(v)) return;
                setCustom(v);
                const n = parseFloat(v);
                if (n > 0 && n <= 50) onChange(Math.round(n * 100));
              }}
              className="num h-8 w-full rounded-lg bg-bg-sunken px-1 text-center text-[12px] outline-none focus:ring-1 focus:ring-ink"
            />
          </div>
        </div>
      )}
    </div>
  );
}
