/** The mark: one square, two segments. Cloud (blue) on the left, Services (amber) on the right. */
export function LogoMark({ size = 24, cloudPct = 30 }: { size?: number; cloudPct?: number }) {
  const gap = 1.6;
  const w = 24;
  const cw = Math.max(3, Math.min(w - 3 - gap, (w * cloudPct) / 100));
  return (
    <svg width={size} height={size} viewBox="0 0 24 24" aria-hidden="true">
      <rect x="0" y="0" width={cw} height="24" rx="3" fill="var(--cloud)" style={{ transition: "width 250ms var(--ease-out)" }} />
      <rect x={cw + gap} y="0" width={w - cw - gap} height="24" rx="3" fill="var(--services)" />
    </svg>
  );
}

export function Wordmark() {
  return (
    <span className="flex items-center gap-2.5">
      <LogoMark />
      <span className="text-[16px] font-semibold tracking-[-0.03em] whitespace-nowrap">
        Share<span className="text-ink-3">Market</span>
      </span>
    </span>
  );
}
