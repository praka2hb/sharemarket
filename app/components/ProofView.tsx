"use client";

import { useState } from "react";
import { useMarket } from "@/hooks/useMarket";
import { ADDRESSES } from "@/lib/addresses";
import { addressUrl } from "@/lib/chain";
import { MARKETS, type Market } from "@/lib/markets";
import { formatAmount } from "@/lib/math";
import { Card } from "./PageHeader";
import { RollingNumber } from "./RollingNumber";
import { PieceIcon, StockIcon } from "./TokenIcon";

export function ProofView() {
  return (
    <div className="mx-auto max-w-[1080px] space-y-4 px-4 sm:px-6">
      {MARKETS.map((m) => (
        <MarketProof key={m.id} market={m} />
      ))}

      <div className="grid gap-4 md:grid-cols-2">
        <Card>
          <h2 className="text-[17px] font-semibold tracking-tight">Why it stays backed</h2>
          <ul className="mt-4 space-y-3 text-[14px] leading-relaxed text-ink-2">
            {[
              "Each vault has no owner, no admin, no pause and no withdraw function.",
              "Shares only leave the vault when one of every business token is handed back and burned.",
              "New business tokens are only created when a real share is deposited.",
              "Only the vault can mint or burn its piece tokens.",
            ].map((t) => (
              <li key={t} className="flex gap-3">
                <svg width="18" height="18" viewBox="0 0 18 18" className="mt-0.5 shrink-0" aria-hidden>
                  <circle cx="9" cy="9" r="9" fill="var(--up)" opacity=".14" />
                  <path d="M5.2 9.2l2.4 2.4 5-5" stroke="var(--up)" strokeWidth="1.8" fill="none" strokeLinecap="round" />
                </svg>
                {t}
              </li>
            ))}
          </ul>
          <p className="mt-4 rounded-xl bg-warn-bg p-3 text-[13px] text-warn-ink">
            The vault can&apos;t stop the stock issuer: on mainnet the issuer can pause or blocklist its token. See{" "}
            <a href="/risks" className="font-semibold underline">
              Risks
            </a>
            .
          </p>
        </Card>

        <Card>
          <h2 className="text-[17px] font-semibold tracking-tight">Shared contracts</h2>
          <ul className="mt-3 divide-y divide-line">
            <AddressRow label="Faucet" address={ADDRESSES.faucet} />
            <AddressRow label="Uniswap v4 PoolManager" address={ADDRESSES.poolManager} />
            <AddressRow label="Mock policy registry" address={ADDRESSES.policyRegistry} />
          </ul>
        </Card>
      </div>
    </div>
  );
}

function MarketProof({ market }: { market: Market }) {
  const m = useMarket(market);
  const supplies = m.pieces.map((p) => p.supply);
  const ready = m.vaultStock !== undefined && supplies.every((s) => s !== undefined);
  const equal = ready && supplies.every((s) => s === supplies[0]);
  const ok = ready && equal && m.vaultStock === supplies[0];
  // Strictly the invariant is vault ≥ supply; tokens sent straight to the vault only over-back.
  const overBacked = ready && equal && m.vaultStock! > supplies[0]!;
  const [open, setOpen] = useState(false);

  return (
    <Card className={ok || overBacked ? "border-up/40" : ready ? "border-down/40" : ""}>
      <div className="flex flex-wrap items-center justify-between gap-4">
        <div className="flex items-center gap-3">
          <StatusBadge state={!ready ? "loading" : ok || overBacked ? "ok" : "bad"} />
          <div>
            <p className="text-[20px] font-semibold tracking-tight">
              {market.company}:{" "}
              {!ready ? "reading the chain…" : ok ? `fully backed, 1:${market.pieces.map(() => "1").join(":")}` : overBacked ? "fully backed (over-collateralised)" : "mismatch detected"}
            </p>
            <p className="text-[13px] text-ink-2">
              Last read {m.updatedAt ? new Date(m.updatedAt).toLocaleTimeString() : "—"} · auto-refreshes every 10s
            </p>
          </div>
        </div>
        <button onClick={() => m.refetch()} className="h-9 rounded-full border border-line px-4 text-[13px] font-medium transition hover:border-line-strong">
          Refresh now
        </button>
      </div>

      <div className="mt-5 grid gap-3 sm:grid-cols-2 lg:grid-cols-4">
        <Cell icon={<StockIcon market={market} size={18} />} label={`${market.token} in the vault`} v={m.vaultStock} />
        {market.pieces.map((p, i) => (
          <Cell key={p.sym} icon={<PieceIcon piece={p} size={18} />} label={`$${p.sym} supply`} v={m.pieces[i]?.supply} />
        ))}
      </div>
      <p className="mt-4 text-[13px] text-ink-2">
        Shown to 8 decimals: exact on-chain values. <span className="num">setsOutstanding()</span> ={" "}
        <span className="num font-medium text-ink">{formatAmount(m.setsOutstanding, 8)}</span>.{" "}
        <button onClick={() => setOpen((o) => !o)} className="font-medium text-ink underline underline-offset-2">
          {open ? "Hide contracts" : "Show contracts"}
        </button>
      </p>
      {open && (
        <ul className="mt-3 grid gap-x-6 divide-y divide-line md:grid-cols-2 md:divide-y-0">
          <AddressRow label="Vault" address={market.vault} />
          <AddressRow label="Router" address={market.router} />
          <AddressRow label={`Mock ${market.token}`} address={market.stock} />
          {market.pieces.map((p) => (
            <AddressRow key={p.sym} label={`$${p.sym} · pool ${p.poolId.slice(0, 10)}…`} address={p.address} />
          ))}
        </ul>
      )}
    </Card>
  );
}

function Cell({ icon, label, v }: { icon: React.ReactNode; label: string; v?: bigint }) {
  return (
    <div className="rounded-2xl bg-bg-soft p-4">
      <p className="flex items-center gap-2 text-[13px] font-medium text-ink-2">
        {icon} {label}
      </p>
      <p className="mt-2 text-[22px] font-semibold tracking-tight">
        {v !== undefined ? <RollingNumber value={formatAmount(v, 8)} flash={false} /> : <span className="skeleton inline-block h-7 w-28" />}
      </p>
    </div>
  );
}

function StatusBadge({ state }: { state: "loading" | "ok" | "bad" }) {
  if (state === "loading") return <span className="spinner size-10 rounded-full border-[3px] border-line border-t-ink" />;
  return (
    <span className={`grid size-10 shrink-0 place-items-center rounded-full ${state === "ok" ? "bg-up" : "bg-down"} pop-in`}>
      <svg width="18" height="18" viewBox="0 0 18 18" aria-hidden>
        {state === "ok" ? (
          <path d="M4 9.5l3.2 3.2L14 6" stroke="#fff" strokeWidth="2.2" fill="none" strokeLinecap="round" strokeLinejoin="round" />
        ) : (
          <path d="M9 4.5v6M9 13.5h.01" stroke="#fff" strokeWidth="2.2" strokeLinecap="round" />
        )}
      </svg>
    </span>
  );
}

function AddressRow({ label, address }: { label: string; address: string }) {
  const [copied, setCopied] = useState(false);
  return (
    <li className="flex items-center justify-between gap-3 py-2.5">
      <div className="min-w-0">
        <p className="text-[13px] font-medium">{label}</p>
        <a href={addressUrl(address)} target="_blank" rel="noreferrer" className="num block truncate text-[12px] text-cloud-ink hover:underline">
          {address}
        </a>
      </div>
      <button
        onClick={() => {
          navigator.clipboard?.writeText(address);
          setCopied(true);
          setTimeout(() => setCopied(false), 1200);
        }}
        className="shrink-0 rounded-lg border border-line px-2.5 py-1 text-[11px] font-medium text-ink-2 hover:text-ink"
        aria-label={`Copy ${label} address`}
      >
        {copied ? "Copied" : "Copy"}
      </button>
    </li>
  );
}
