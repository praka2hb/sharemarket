"use client";

import Link from "next/link";
import { useAccountData } from "@/hooks/useAccountData";
import { useMarket } from "@/hooks/useMarket";
import type { Market } from "@/lib/markets";
import { formatAmount, valueAt } from "@/lib/math";
import { PieceIcon, StockIcon } from "./TokenIcon";
import { useMarketCtx } from "./TradeTabContext";

/** Holdings in one market, each piece valued at its pool price, in stock tokens. */
export function usePortfolio(market: Market) {
  const acct = useAccountData(market);
  const m = useMarket(market);
  const stock = acct.stock ?? 0n;
  const values = market.pieces.map((_, i) => {
    const bal = acct.pieces[i]?.balance;
    const price = m.pieces[i]?.price;
    return bal !== undefined && price !== undefined ? valueAt(bal, price) : undefined;
  });
  const total = values.every((v) => v !== undefined) && acct.stock !== undefined ? values.reduce<bigint>((a, v) => a + v!, stock) : undefined;
  return { acct, m, values, total };
}

export function PositionStrip() {
  const { market } = useMarketCtx();
  const p = usePortfolio(market);
  if (!p.acct.isConnected) return null;
  return (
    <section aria-labelledby="pos-title" className="rounded-2xl border border-line bg-bg p-4 sm:p-5">
      <div className="flex items-baseline justify-between">
        <h2 id="pos-title" className="label">
          Your position
        </h2>
        <Link href="/positions" className="text-[12px] font-medium text-ink-2 hover:text-ink">
          Details →
        </Link>
      </div>
      <div className="mt-3 grid grid-cols-2 gap-2 sm:grid-cols-4">
        <div className="rounded-2xl bg-bg-soft p-3">
          <span className="flex items-center gap-1.5 text-[12px] font-medium text-ink-2">
            <StockIcon market={market} size={14} /> {market.token}
          </span>
          <p className="num mt-1 truncate text-[17px] font-medium">{p.acct.isLoading ? "…" : formatAmount(p.acct.stock)}</p>
        </div>
        {market.pieces.map((piece, i) => (
          <div key={piece.sym} className="rounded-2xl bg-bg-soft p-3">
            <span className="flex items-center gap-1.5 text-[12px] font-medium text-ink-2">
              <PieceIcon piece={piece} size={14} /> ${piece.sym}
            </span>
            <p className="num mt-1 truncate text-[17px] font-medium">{p.acct.isLoading ? "…" : formatAmount(p.acct.pieces[i]?.balance)}</p>
            <p className="num truncate text-[11px] text-ink-3">
              ≈ {formatAmount(p.values[i])} {market.token}
            </p>
          </div>
        ))}
      </div>
      <div className="mt-3 flex items-center justify-between border-t border-line pt-3 text-[13px]">
        <span className="text-ink-2">Total value</span>
        <span className="num font-semibold">
          {formatAmount(p.total)} {market.token}
        </span>
      </div>
    </section>
  );
}
