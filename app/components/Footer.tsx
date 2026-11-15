import Link from "next/link";
import { LogoMark } from "./Logo";
import { ADDRESSES } from "@/lib/addresses";
import { MARKETS } from "@/lib/markets";
import { addressUrl } from "@/lib/chain";

const cols = [
  {
    title: "Product",
    links: [
      { href: "/", label: "Markets" },
      { href: "/positions", label: "Portfolio" },
      { href: "/how-it-works", label: "How it works" },
    ],
  },
  {
    title: "Trust",
    links: [
      { href: "/proof", label: "Proof of backing" },
      { href: "/risks", label: "Risks" },
      ...MARKETS.map((m) => ({ href: addressUrl(m.vault), label: `${m.ticker} vault ↗`, external: true })),
    ],
  },
  {
    title: "Testnet",
    links: [
      { href: "https://portal.cdp.coinbase.com/products/faucet", label: "Base Sepolia ETH faucet ↗", external: true },
      { href: addressUrl(ADDRESSES.faucet), label: "Stock token faucet ↗", external: true },
      ...MARKETS.map((m) => ({ href: addressUrl(m.stock), label: `Mock ${m.token} ↗`, external: true })),
    ],
  },
];

export function Footer() {
  return (
    <footer className="mt-20 border-t border-line">
      <div className="mx-auto grid max-w-[1080px] gap-10 px-4 py-14 sm:px-6 md:grid-cols-[1.4fr_1fr_1fr_1fr]">
        <div>
          <p className="flex items-center gap-2 text-[13px] font-medium text-cloud-ink">
            <span className="live-dot size-1.5 rounded-full bg-up" /> Live on Base Sepolia
          </p>
          <p className="mt-3 max-w-xs text-[14px] leading-relaxed text-ink-2">
            Trade the business segments of public companies, on Base.
          </p>
        </div>
        {cols.map((c) => (
          <div key={c.title}>
            <p className="label">{c.title}</p>
            <ul className="mt-3 space-y-2">
              {c.links.map((l) => (
                <li key={l.label}>
                  {"external" in l && l.external ? (
                    <a href={l.href} target="_blank" rel="noreferrer" className="text-[14px] text-ink-2 transition hover:text-ink">
                      {l.label}
                    </a>
                  ) : (
                    <Link href={l.href} className="text-[14px] text-ink-2 transition hover:text-ink">
                      {l.label}
                    </Link>
                  )}
                </li>
              ))}
            </ul>
          </div>
        ))}
      </div>
      <div className="border-t border-line">
        <div className="mx-auto flex max-w-[1080px] flex-wrap items-center justify-between gap-3 px-4 py-5 text-[12px] text-ink-3 sm:px-6">
          <span className="flex items-center gap-2">
            <LogoMark size={14} /> ShareMarket · Built for Base &ldquo;Stocks Maxxing&rdquo;
          </span>
          <span>Not affiliated with Alphabet or Google. Testnet only. Not investment advice.</span>
        </div>
      </div>
    </footer>
  );
}
