"use client";

import Link from "next/link";
import { useMarket } from "@/hooks/useMarket";
import { formatPrice } from "@/lib/math";
import { RollingNumber } from "./RollingNumber";
import { SplitBar } from "./SplitBar";
import { PieceIcon, StockIcon } from "./TokenIcon";
import { useMarketCtx } from "./TradeTabContext";

export function MarketHeader() {
  const { market, tab, setTab } = useMarketCtx();
  const m = useMarket(market);
  const pick = (i: number) => {
    setTab({ side: tab.side, piece: i });
    if (window.matchMedia("(max-width: 1023px)").matches) document.getElementById("trade")?.scrollIntoView({ behavior: "smooth" });
  };
  const sum = m.sumPct;

  return (
    <section aria-labelledby="mkt-title">
      <nav aria-label="Breadcrumb" className="text-[13px] text-ink-3">
        <Link href="/" className="hover:text-ink">
          Markets
        </Link>{" "}
        / <span className="text-ink-2">{market.company}</span>
      </nav>
      <div className="mt-4 flex items-center gap-3">
        <StockIcon market={market} size={40} />
        <div>
          <h1 id="mkt-title" className="text-[26px] font-semibold tracking-tight">
            {market.company}
          </h1>
          <p className="text-[13px] text-ink-2">
            {market.ticker} · 1 {market.token} = {market.pieces.map((p) => `1 $${p.sym}`).join(" + ")}
          </p>
        </div>
      </div>

      <div className="mt-6 grid gap-3 sm:grid-cols-3">
        {market.pieces.map((p, i) => {
          const s = m.pieces[i];
          const selected = tab.piece === i;
          return (
            <button
              key={p.sym}
              onClick={() => pick(i)}
              aria-pressed={selected}
              className={`rounded-2xl border p-4 text-left transition-colors ${selected ? "border-ink" : "border-line hover:border-line-strong"}`}
            >
              <p className="flex items-center gap-2 text-[13px] font-medium">
                <PieceIcon piece={p} size={18} />
                {p.name}
              </p>
              <p className="mt-3 text-[24px] font-semibold tracking-tight">
                {s?.price !== undefined ? <RollingNumber value={formatPrice(s.price)} /> : <span className="skeleton inline-block h-7 w-24" />}
                <span className="ml-1.5 text-[12px] font-normal text-ink-3">{market.token}</span>
              </p>
              <p className="mt-1 text-[12px] text-ink-2">
                ${p.sym} · market <span className="num">{s?.pct?.toFixed(2) ?? "—"}%</span> · reported <span className="num">{p.reported.toFixed(2)}%</span>
              </p>
              <p className="mt-2 hidden text-[12px] text-ink-3 sm:block">{p.includes}</p>
            </button>
          );
        })}
      </div>

      <div className="mt-5">
        <SplitBar market={market} pcts={m.pieces.map((p) => p.pct)} onPick={pick} />
        <p className="mt-2 text-[12px] text-ink-3">
          Pieces add up to <span className="num text-ink-2">{sum !== undefined ? `${sum.toFixed(2)}%` : "—"}</span> of one {market.token}. If the sum drifts
          from 100%, anyone can split or merge and trade the gap away. Reported mix is {market.company}&apos;s {market.reportedLabel} revenue, shown for context;
          it doesn&apos;t move prices.
        </p>
      </div>
    </section>
  );
}
