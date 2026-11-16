"use client";

import Link from "next/link";
import { useActivity, type Activity } from "@/hooks/useHistory";
import { useWallet } from "@/hooks/useAccountData";
import { txUrl } from "@/lib/chain";
import { MARKETS, marketHref, type Market } from "@/lib/markets";
import { formatAmount, formatPrice } from "@/lib/math";
import { Card } from "./PageHeader";
import { usePortfolio } from "./PositionStrip";
import { PieceIcon, StockIcon } from "./TokenIcon";
import { ConnectButton } from "./Wallet";

export function PositionsView() {
  const w = useWallet();
  const activity = useActivity(w.address);

  if (!w.isConnected)
    return (
      <section className="mx-auto max-w-[1080px] px-4 sm:px-6">
        <Card className="flex flex-col items-center gap-4 py-16 text-center">
          <p className="text-[17px] font-medium">Connect a wallet to see your pieces.</p>
          <ConnectButton size="lg" />
        </Card>
      </section>
    );

  return (
    <section className="mx-auto grid max-w-[1080px] gap-4 px-4 sm:px-6 lg:grid-cols-[1.35fr_1fr]">
      <div className="min-w-0 space-y-4">
        {MARKETS.map((m) => (
          <MarketHoldings key={m.id} market={m} />
        ))}
      </div>

      <Card className="min-w-0 self-start">
        <div className="flex items-baseline justify-between">
          <h2 className="text-[17px] font-semibold tracking-tight">Recent activity</h2>
          <span className="label">From chain</span>
        </div>
        {activity.isLoading ? (
          <div className="mt-4 space-y-2">
            {[0, 1, 2].map((i) => (
              <div key={i} className="skeleton h-14" />
            ))}
          </div>
        ) : activity.error ? (
          <p className="mt-6 text-[14px] text-down">Couldn&apos;t load activity. It retries automatically.</p>
        ) : !activity.data?.length ? (
          <p className="mt-6 text-[14px] text-ink-2">
            No trades yet.{" "}
            <Link href={marketHref(MARKETS[0].id)} className="font-medium text-cloud-ink underline">
              Make your first one →
            </Link>
          </p>
        ) : (
          <ul className="mt-3 divide-y divide-line">
            {activity.data.slice(0, 25).map((a) => (
              <ActivityRow key={a.hash + a.kind + a.market.id} a={a} />
            ))}
          </ul>
        )}
      </Card>
    </section>
  );
}

function MarketHoldings({ market }: { market: Market }) {
  const p = usePortfolio(market);
  const tot = p.total ?? 0n;
  const share = (v?: bigint) => (v !== undefined && tot > 0n ? Number((v * 10_000n) / tot) / 100 : 0);
  return (
    <Card>
      <div className="flex items-start justify-between gap-3">
        <div className="flex items-center gap-3">
          <StockIcon market={market} size={32} />
          <div>
            <p className="font-semibold">{market.company}</p>
            <p className="label">Total value</p>
          </div>
        </div>
        <p className="flex items-baseline gap-1.5 text-right">
          <span className="num text-[28px] font-semibold tracking-tight">{formatAmount(p.total)}</span>
          <span className="text-[13px] text-ink-2">{market.token}</span>
        </p>
      </div>
      <div className="mt-4 flex h-2.5 w-full gap-1 overflow-hidden rounded-full bg-bg-sunken" aria-label="Composition">
        <span className="h-full rounded-full bg-ink-3 transition-[flex-basis] duration-500" style={{ flexBasis: `${share(p.acct.stock)}%` }} />
        {market.pieces.map((piece, i) => (
          <span key={piece.sym} className="h-full rounded-full transition-[flex-basis] duration-500" style={{ flexBasis: `${share(p.values[i])}%`, background: piece.color }} />
        ))}
      </div>
      <div className="mt-4 divide-y divide-line">
        <Row icon={<StockIcon market={market} size={28} />} name={market.token} note="The stock token (mock on testnet)" price="1.0000" bal={p.acct.stock} val={p.acct.stock} token={market.token} />
        {market.pieces.map((piece, i) => (
          <Row
            key={piece.sym}
            icon={<PieceIcon piece={piece} size={28} />}
            name={`$${piece.sym}`}
            note={piece.name}
            price={formatPrice(p.m.pieces[i]?.price)}
            bal={p.acct.pieces[i]?.balance}
            val={p.values[i]}
            token={market.token}
          />
        ))}
      </div>
      <div className="mt-3 flex flex-wrap items-center justify-between gap-3 border-t border-line pt-3">
        <p className="text-[13px] text-ink-2">Valued at live pool prices.</p>
        <Link href={`${marketHref(market.id)}#trade`} className="inline-flex h-9 items-center rounded-full bg-ink px-4 text-[13px] font-semibold text-bg">
          Trade →
        </Link>
      </div>
    </Card>
  );
}

function Row({ icon, name, note, price, bal, val, token }: { icon: React.ReactNode; name: string; note: string; price: string; bal?: bigint; val?: bigint; token: string }) {
  return (
    <div className="grid grid-cols-[1fr_auto] items-center gap-3 py-3 sm:grid-cols-[1.4fr_1fr_1fr]">
      <div className="flex items-center gap-3">
        {icon}
        <div>
          <p className="font-semibold">{name}</p>
          <p className="text-[12px] text-ink-3">{note}</p>
        </div>
      </div>
      <div className="hidden text-right sm:block">
        <p className="label">Price</p>
        <p className="num text-[14px]">{price}</p>
      </div>
      <div className="text-right">
        <p className="num text-[16px] font-semibold">{formatAmount(bal)}</p>
        <p className="num text-[12px] text-ink-3">
          ≈ {formatAmount(val)} {token}
        </p>
      </div>
    </div>
  );
}

function describe(a: Activity): { title: string; detail: string; color: string } {
  const v = (k: string) => formatAmount(a.args[k] as bigint);
  const m = a.market;
  const piece = a.kind === "Bought" || a.kind === "Sold" ? m.pieces[Number(a.args.piece as bigint)] : undefined;
  const sym = piece ? `$${piece.sym}` : "";
  switch (a.kind) {
    case "Bought":
      return { title: `Bought ${sym}`, detail: `${v("stockIn")} ${m.token} → ${v("pieceOut")} ${sym}`, color: piece?.color ?? "var(--ink)" };
    case "Sold":
      return { title: `Sold ${sym}`, detail: `${v("pieceIn")} ${sym} → ${v("stockOut")} ${m.token}`, color: piece?.color ?? "var(--ink)" };
  }
}

function ActivityRow({ a }: { a: Activity }) {
  const d = describe(a);
  return (
    <li>
      <a href={txUrl(a.hash)} target="_blank" rel="noreferrer" className="group flex items-center gap-3 py-3">
        <span className="size-2 shrink-0 rounded-full" style={{ background: d.color }} aria-hidden />
        <span className="min-w-0 flex-1">
          <span className="block text-[14px] font-medium">{d.title}</span>
          <span className="num block truncate text-[12px] text-ink-2">{d.detail}</span>
        </span>
        <span className="shrink-0 text-right text-[11px] text-ink-3">
          {new Date(a.t * 1000).toLocaleString(undefined, { month: "short", day: "numeric", hour: "2-digit", minute: "2-digit" })}
          <span className="block text-cloud-ink opacity-0 transition group-hover:opacity-100">BaseScan ↗</span>
        </span>
      </a>
    </li>
  );
}
