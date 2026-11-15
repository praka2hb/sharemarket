"use client";

import { usePausedStocks } from "@/hooks/useMarket";
import { addressUrl } from "@/lib/chain";

/** Shows when a stock issuer pauses its token. Reads `pausedFeatures()` live. */
export function GlobalBanners() {
  const paused = usePausedStocks();
  if (!paused.length) return null;
  return (
    <div role="alert" className="border-b border-down/30 bg-down/10">
      {paused.map((m) => (
        <p key={m.id} className="mx-auto max-w-[1080px] px-4 py-3 text-center text-[14px] font-medium text-down sm:px-6">
          {m.token} paused by its issuer. {m.company} trading and merging are stopped.{" "}
          <a className="underline" href={addressUrl(m.stock) + "#readContract"} target="_blank" rel="noreferrer">
            Check pausedFeatures ↗
          </a>
        </p>
      ))}
    </div>
  );
}
