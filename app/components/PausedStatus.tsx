"use client";

import { useMarket } from "@/hooks/useMarket";
import { MARKETS, type Market } from "@/lib/markets";

/** Live read of each mock stock token's pausedFeatures(). */
export function PausedStatus() {
  return (
    <div className="space-y-2">
      {MARKETS.map((m) => (
        <Status key={m.id} market={m} />
      ))}
    </div>
  );
}

function Status({ market }: { market: Market }) {
  const m = useMarket(market);
  const loading = m.pausedFeatures === undefined;
  return (
    <div className="flex flex-wrap items-center justify-between gap-3 rounded-2xl border border-line bg-bg-soft px-5 py-4">
      <p className="flex items-center gap-2.5 text-[14px] font-medium">
        <span className={`size-2 rounded-full ${loading ? "bg-ink-3" : m.isPaused ? "bg-down" : "bg-up live-dot"}`} aria-hidden />
        Live: {market.token} issuer status
      </p>
      <p className="num text-[13px] text-ink-2">
        pausedFeatures() = {loading ? "…" : `[${m.pausedFeatures!.join(", ")}]`} ·{" "}
        <span className={m.isPaused ? "font-semibold text-down" : "text-up"}>{loading ? "" : m.isPaused ? "PAUSED" : "not paused"}</span>
      </p>
    </div>
  );
}
