import type { Market, Piece } from "@/lib/markets";

/** Logo on a white disc, or a coloured disc with the first letter. Reads on light and dark. */
function Disc({ size, color, logo, letter, scale = 0.66 }: { size: number; color: string; logo?: string; letter: string; scale?: number }) {
  if (logo) {
    const inner = Math.round(size * scale);
    return (
      <span
        aria-hidden="true"
        className="inline-grid shrink-0 place-items-center rounded-full bg-white ring-1 ring-black/[0.06]"
        style={{ width: size, height: size }}
      >
        {/* eslint-disable-next-line @next/next/no-img-element */}
        <img src={logo} alt="" width={inner} height={inner} style={{ width: inner, height: inner, objectFit: "contain" }} draggable={false} />
      </span>
    );
  }
  return (
    <span
      aria-hidden="true"
      className="inline-grid shrink-0 place-items-center rounded-full font-semibold text-white"
      style={{ width: size, height: size, background: color, fontSize: Math.max(8, Math.round(size * 0.46)) }}
    >
      {letter}
    </span>
  );
}

export function StockIcon({ market, size = 20 }: { market: Market; size?: number }) {
  return <Disc size={size} color={market.tokenColor} logo={market.logo} letter={market.ticker[0]} scale={0.6} />;
}

export function PieceIcon({ piece, size = 20 }: { piece: Piece; size?: number }) {
  return <Disc size={size} color={piece.color} logo={piece.logo} letter={piece.sym[0]} scale={0.72} />;
}
