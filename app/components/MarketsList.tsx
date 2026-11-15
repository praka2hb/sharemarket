"use client";

import Link from "next/link";
import { useMarket } from "@/hooks/useMarket";
import { MARKETS, SOON, marketHref, type Market, type SoonMarket } from "@/lib/markets";
import { formatPrice } from "@/lib/math";
import { SplitBar } from "./SplitBar";
import { StockIcon } from "./TokenIcon";

export function MarketsList() {
  return (
    <div className="overflow-hidden rounded-2xl border border-line">
      <div className="hidden grid-cols-[1fr_2.4fr_auto] gap-6 border-b border-line bg-bg-soft px-5 py-2.5 text-[12px] text-ink-3 md:grid">
        <span>Company</span>
        <span>Pieces you can trade · price in stock tokens</span>
        <span className="w-24 text-right">Status</span>
      </div>
      <ul className="divide-y divide-line">
        {MARKETS.map((m) => (
          <LiveRow key={m.id} m={m} />
        ))}
        {SOON.map((m) => (
          <SoonRow key={m.id} m={m} />
        ))}
      </ul>
    </div>
  );
}

function Company({ name, ticker, icon }: { name: string; ticker: string; icon: React.ReactNode }) {
  return (
    <div className="flex items-center gap-3">
      {icon}
      <div>
        <p className="text-[15px] font-medium">{name}</p>
        <p className="text-[12px] text-ink-3">{ticker}</p>
      </div>
    </div>
  );
}

function LiveRow({ m }: { m: Market }) {
  const mk = useMarket(m);
  return (
    <li>
      <Link href={marketHref(m.id)} className="group grid gap-4 px-5 py-5 transition-colors hover:bg-bg-soft md:grid-cols-[1fr_2.4fr_auto] md:items-center md:gap-6">
        <Company name={m.company} ticker={m.ticker} icon={<StockIcon market={m} size={32} />} />
        <div className="min-w-0">
          <div className="grid grid-cols-3 gap-3">
            {m.pieces.map((p, i) => (
              <div key={p.sym} className="min-w-0">
                <p className="flex items-center gap-1.5 truncate text-[13px] font-medium">
                  <span className="size-2 shrink-0 rounded-full" style={{ background: p.color }} aria-hidden />${p.sym}
                </p>
                <p className="num mt-0.5 text-[13px] text-ink-2">{formatPrice(mk.pieces[i]?.price)}</p>
              </div>
            ))}
          </div>
          <div className="mt-3">
            <SplitBar market={m} pcts={mk.pieces.map((p) => p.pct)} size="sm" />
          </div>
        </div>
        <span className="flex items-center justify-between gap-3 md:w-24 md:justify-end">
          <span className="flex items-center gap-1.5 text-[12px] font-medium text-up md:hidden">
            <span className="size-1.5 rounded-full bg-up" /> Live
          </span>
          <span className="inline-flex h-9 items-center rounded-full bg-ink px-4 text-[13px] font-medium text-bg transition group-hover:opacity-90">Trade</span>
        </span>
      </Link>
    </li>
  );
}

function SoonRow({ m }: { m: SoonMarket }) {
  return (
    <li className="grid gap-4 px-5 py-5 md:grid-cols-[1fr_2.4fr_auto] md:items-center md:gap-6">
      <Company
        name={m.company}
        ticker={m.ticker}
        icon={
          <span className="grid size-8 place-items-center rounded-full bg-bg-sunken text-[11px] font-semibold text-ink-2" aria-hidden>
            {m.ticker[0]}
          </span>
        }
      />
      <div className="flex flex-wrap gap-1.5">
        {m.lines.map((s) => (
          <span key={s} className="rounded-full border border-line px-2.5 py-1 text-[12px] text-ink-2">
            {s}
          </span>
        ))}
      </div>
      <span className="text-[12px] text-ink-3 md:w-24 md:text-right">Coming soon</span>
    </li>
  );
}
