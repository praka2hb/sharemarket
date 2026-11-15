import Link from "next/link";
import { MarketsList } from "@/components/MarketsList";
import { MARKETS, marketHref } from "@/lib/markets";

const STEPS = [
  { n: "1", t: "Deposit a stock token", d: "For example 1 GOOGLc (Alphabet) or 1 NVDAc (NVIDIA), tokenized shares on Base." },
  { n: "2", t: "Get one piece per business", d: "1 GOOGLc becomes 1 $SEARCH + 1 $YOUTUBE + 1 $CLOUD. Together they're always worth exactly 1 GOOGLc." },
  { n: "3", t: "Trade the piece you believe in", d: "Buy Cloud, sell Search, or back NVIDIA's edge business. Merge a full set back into the stock any time." },
];

export default function Home() {
  return (
    <div className="mx-auto max-w-[1080px] px-4 sm:px-6">
      <section className="pt-14 pb-12 sm:pt-20">
        <h1 className="display max-w-[16ch] text-[40px] sm:text-[60px]">Trade the parts of a company.</h1>
        <p className="mt-5 max-w-[58ch] text-[17px] leading-relaxed text-ink-2">
          Big companies are several businesses in one. ShareMarket splits a stock into the business lines it reports, so you can back just the part you believe in: Google
          Cloud instead of all of Alphabet, or NVIDIA&apos;s hyperscale sales instead of its edge chips.
        </p>
        <div className="mt-7 flex flex-wrap gap-3">
          {MARKETS.map((m, i) => (
            <Link
              key={m.id}
              href={marketHref(m.id)}
              className={`inline-flex h-11 items-center rounded-full px-5 text-[14px] font-medium transition ${i === 0 ? "bg-ink text-bg hover:opacity-90" : "border border-line hover:border-line-strong"}`}
            >
              Trade {m.company}
            </Link>
          ))}
          <Link href="/how-it-works" className="inline-flex h-11 items-center rounded-full border border-line px-5 text-[14px] font-medium transition hover:border-line-strong">
            How it works
          </Link>
        </div>
      </section>

      <section aria-labelledby="markets-title">
        <div className="mb-3 flex items-baseline justify-between">
          <h2 id="markets-title" className="text-[17px] font-semibold tracking-tight">
            Markets
          </h2>
          <span className="text-[12px] text-ink-3">Prices live from Base Sepolia</span>
        </div>
        <MarketsList />
      </section>

      <section aria-labelledby="how-title" className="mt-16">
        <h2 id="how-title" className="text-[17px] font-semibold tracking-tight">
          How it works
        </h2>
        <ol className="mt-4 grid gap-px overflow-hidden rounded-2xl border border-line bg-line md:grid-cols-3">
          {STEPS.map((s) => (
            <li key={s.n} className="bg-bg p-5">
              <span className="num text-[12px] text-ink-3">{s.n}</span>
              <p className="mt-2 text-[15px] font-medium">{s.t}</p>
              <p className="mt-1.5 text-[14px] leading-relaxed text-ink-2">{s.d}</p>
            </li>
          ))}
        </ol>
        <p className="mt-4 text-[13px] text-ink-3">
          Prices come only from trading. There is no settlement and no expiry; the reported revenue mix is shown as context only.{" "}
          <Link href="/risks" className="underline underline-offset-2 hover:text-ink">
            Risks
          </Link>
        </p>
      </section>
    </div>
  );
}
