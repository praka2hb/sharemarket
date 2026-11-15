"use client";

import type { Market } from "@/lib/markets";

/**
 * One bar, one segment per piece, sized by live piece prices (normalised to 100%).
 * A thinner bar beneath shows the company's last reported mix, for context.
 */
export function SplitBar({
  market,
  pcts,
  size = "md",
  onPick,
}: {
  market: Market;
  pcts: (number | undefined)[];
  size?: "md" | "sm";
  onPick?: (i: number) => void;
}) {
  const loaded = pcts.every((p) => p !== undefined);
  const total = loaded ? pcts.reduce<number>((a, p) => a + p!, 0) : 0;
  const widths = loaded && total > 0 ? pcts.map((p) => Math.max(1.5, (p! / total) * 100)) : market.pieces.map(() => 100 / market.pieces.length);
  return (
    <div className="w-full">
      <div className={`flex w-full gap-1 ${size === "sm" ? "h-1.5" : "h-2.5"} ${loaded ? "" : "animate-pulse"}`}>
        {market.pieces.map((p, i) =>
          onPick ? (
            <button
              key={p.sym}
              onClick={() => onPick(i)}
              aria-label={`Trade $${p.sym}`}
              className="rounded-full transition-[flex-basis] duration-500 ease-out-expo hover:opacity-80"
              style={{ flexBasis: `${widths[i]}%`, background: p.color }}
            />
          ) : (
            <span key={p.sym} className="rounded-full transition-[flex-basis] duration-500 ease-out-expo" style={{ flexBasis: `${widths[i]}%`, background: p.color }} />
          ),
        )}
      </div>
      {size === "md" && (
        <>
          <div className="mt-1.5 flex h-1 w-full gap-1 opacity-35" aria-hidden>
            {market.pieces.map((p) => (
              <span key={p.sym} className="rounded-full" style={{ flexBasis: `${p.reported}%`, background: p.color }} />
            ))}
          </div>
          <p className="mt-1.5 text-[11px] text-ink-3">Top: market prices · Faint: reported revenue mix ({market.reportedLabel})</p>
        </>
      )}
    </div>
  );
}
