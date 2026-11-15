"use client";

import { useMemo, useRef, useState } from "react";
import { usePriceHistory } from "@/hooks/useHistory";
import { useMarket } from "@/hooks/useMarket";
import { formatPct } from "@/lib/math";
import { RollingNumber } from "./RollingNumber";
import { useMarketCtx } from "./TradeTabContext";

const W = 640;
const H = 220;
const PAD = { l: 8, r: 52, t: 16, b: 26 };

function fmtTime(t: number, span: number) {
  const d = new Date(t * 1000);
  return span > 2 * 86_400
    ? d.toLocaleDateString(undefined, { month: "short", day: "numeric" })
    : d.toLocaleTimeString(undefined, { hour: "2-digit", minute: "2-digit" });
}

/**
 * The selected piece's price (as % of one stock token) over time, from its pool's real Initialize + Swap events.
 * Drawn as a step line: the price holds until the next trade. Sparse history is shown as-is.
 */
export function PriceChart() {
  const { market, tab } = useMarketCtx();
  const piece = market.pieces[tab.piece];
  const hist = usePriceHistory(piece);
  const m = useMarket(market);
  const live = m.pieces[tab.piece]?.pct;
  const reported = piece.reported;
  const color = piece.color;
  const svgRef = useRef<SVGSVGElement>(null);
  const [hover, setHover] = useState<number | null>(null);

  const points = useMemo(() => {
    const p = (hist.data ?? []).map((x) => ({ t: x.t, v: x.pct, kind: x.kind }));
    if (live !== undefined && p.length) p.push({ t: Math.floor((m.updatedAt || Date.now()) / 1000), v: live, kind: "swap" as const });
    return p;
  }, [hist.data, live, m.updatedAt]);

  const swaps = (hist.data ?? []).filter((x) => x.kind === "swap").length;
  const first = points[0];
  const last = points[points.length - 1];
  const change = first && last ? last.v - first.v : 0;

  const geo = useMemo(() => {
    if (points.length < 1) return null;
    const t0 = points[0].t;
    const t1 = Math.max(points[points.length - 1].t, t0 + 60);
    const vals = [...points.map((p) => p.v), reported];
    let lo = Math.min(...vals);
    let hi = Math.max(...vals);
    const pad = Math.max(0.6, (hi - lo) * 0.25);
    lo -= pad;
    hi += pad;
    const x = (t: number) => PAD.l + ((t - t0) / (t1 - t0)) * (W - PAD.l - PAD.r);
    const y = (v: number) => PAD.t + (1 - (v - lo) / (hi - lo)) * (H - PAD.t - PAD.b);
    let d = `M${x(points[0].t)},${y(points[0].v)}`;
    for (let i = 1; i < points.length; i++) d += ` H${x(points[i].t)} V${y(points[i].v)}`;
    const area = `${d} V${H - PAD.b} H${x(points[0].t)} Z`;
    const ticks = [lo + (hi - lo) * 0.15, (lo + hi) / 2, hi - (hi - lo) * 0.15];
    return { x, y, d, area, t0, t1, ticks };
  }, [points, reported]);

  const onMove = (e: React.PointerEvent) => {
    if (!geo || !svgRef.current) return;
    const r = svgRef.current.getBoundingClientRect();
    const px = ((e.clientX - r.left) / r.width) * W;
    let best = 0;
    // Step chart: the active point is the last one at or before the cursor.
    for (let i = 0; i < points.length; i++) if (geo.x(points[i].t) <= px) best = i;
    setHover(best);
  };

  const hp = hover !== null ? points[hover] : null;
  const shown = hp?.v ?? live;
  const up = change >= 0;

  return (
    <section aria-labelledby="chart-title" className="rounded-2xl border border-line bg-bg p-4 sm:p-5">
      <div className="flex flex-wrap items-end justify-between gap-3">
        <div>
          <h2 id="chart-title" className="label">
            ${piece.sym} price · % of one {market.token}
          </h2>
          <div className="mt-1 flex items-baseline gap-3">
            <span className="text-[34px] font-semibold tracking-tight">
              {shown !== undefined ? <RollingNumber value={`${shown.toFixed(2)}%`} flash={hover === null} /> : <span className="skeleton inline-block h-9 w-28" />}
            </span>
            {points.length > 1 && hover === null && (
              <span className={`num text-[13px] font-medium ${Math.abs(change) < 0.005 ? "text-ink-3" : up ? "text-up" : "text-down"}`}>
                {Math.abs(change) < 0.005 ? "±0.00" : `${up ? "+" : ""}${change.toFixed(2)}`} pts since open
              </span>
            )}
            {hp && <span className="num text-[13px] text-ink-3">{new Date(hp.t * 1000).toLocaleString()}</span>}
          </div>
        </div>
        <div className="flex items-center gap-3 text-[11px] text-ink-2">
          <span className="flex items-center gap-1.5">
            <span className="h-[2px] w-4 rounded" style={{ background: color }} /> Market (from trades)
          </span>
          <span className="flex items-center gap-1.5">
            <span className="h-0 w-4 border-t border-dashed border-ink-2" /> Reported mix
          </span>
        </div>
      </div>

      <div className="relative mt-3">
        {hist.isLoading && !geo ? (
          <div className="skeleton h-[180px] w-full sm:h-[220px]" />
        ) : geo ? (
          <svg
            ref={svgRef}
            viewBox={`0 0 ${W} ${H}`}
            className="h-[180px] w-full touch-none sm:h-[220px]"
            onPointerMove={onMove}
            onPointerLeave={() => setHover(null)}
            role="img"
            aria-label={`$${piece.sym} price chart. ${swaps} trades so far. Current ${formatPct(live)} of one ${market.token}; reported mix ${reported}%.`}
          >
            <defs>
              <linearGradient id="area" x1="0" x2="0" y1="0" y2="1">
                <stop offset="0" stopColor={color} stopOpacity=".18" />
                <stop offset="1" stopColor={color} stopOpacity="0" />
              </linearGradient>
              <pattern id="dots" width="16" height="16" patternUnits="userSpaceOnUse">
                <circle cx="1" cy="1" r="0.9" fill="var(--line-strong)" />
              </pattern>
            </defs>
            <rect x={PAD.l} y={PAD.t} width={W - PAD.l - PAD.r} height={H - PAD.t - PAD.b} fill="url(#dots)" opacity=".7" />
            {geo.ticks.map((v) => (
              <text key={v} x={W - PAD.r + 8} y={geo.y(v) + 3} className="num" fontSize="10" fill="var(--ink-3)">
                {v.toFixed(1)}%
              </text>
            ))}
            {/* Reported line */}
            <line x1={PAD.l} x2={W - PAD.r} y1={geo.y(reported)} y2={geo.y(reported)} stroke="var(--ink-2)" strokeDasharray="4 4" strokeWidth="1" />
            <path d={geo.area} fill="url(#area)" />
            <path d={geo.d} fill="none" stroke={color} strokeWidth="2.25" strokeLinejoin="round" style={{ transition: "d 400ms var(--ease-out)" }} />
            {/* Trade markers */}
            {points.slice(0, -1).map((p, i) => (
              <circle key={i} cx={geo.x(p.t)} cy={geo.y(p.v)} r={p.kind === "open" ? 3.5 : 2.5} fill="var(--bg)" stroke={color} strokeWidth="1.5" />
            ))}
            {/* Live end */}
            {last && (
              <g>
                <circle cx={geo.x(last.t)} cy={geo.y(last.v)} r="7" fill={color} opacity=".18" className="live-dot" />
                <circle cx={geo.x(last.t)} cy={geo.y(last.v)} r="3.5" fill={color} />
              </g>
            )}
            {hp && (
              <g>
                <line x1={geo.x(hp.t)} x2={geo.x(hp.t)} y1={PAD.t} y2={H - PAD.b} stroke="var(--ink)" strokeOpacity=".25" />
                <circle cx={geo.x(hp.t)} cy={geo.y(hp.v)} r="4.5" fill={color} stroke="var(--bg)" strokeWidth="2" />
              </g>
            )}
            <text x={PAD.l} y={H - 6} fontSize="10" fill="var(--ink-3)" className="num">
              {fmtTime(geo.t0, geo.t1 - geo.t0)}
            </text>
            <text x={W - PAD.r} y={H - 6} fontSize="10" fill="var(--ink-3)" textAnchor="end" className="num">
              now
            </text>
          </svg>
        ) : (
          <p className="py-16 text-center text-sm text-ink-3">Couldn&apos;t load price history.</p>
        )}
      </div>
      <p className="mt-2 text-[12px] text-ink-3">
        {swaps === 0
          ? "No trades yet: the line holds at the pool's opening price. Every point here is a real on-chain trade."
          : `${swaps} trade${swaps === 1 ? "" : "s"} so far. Every point is a real on-chain swap; the line holds between trades.`}
      </p>
    </section>
  );
}
