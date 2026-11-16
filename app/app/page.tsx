import Link from "next/link";
import { MarketsList } from "@/components/MarketsList";
import { MARKETS, marketHref } from "@/lib/markets";

const STEPS = [
  { n: "1", t: "Pick a company", d: "Alphabet or NVIDIA today. Each one is broken into the businesses it reports." },
  { n: "2", t: "Pick the business you believe in", d: "Google Search, YouTube ads or Google Cloud. NVIDIA's hyperscale, AI cloud or edge sales." },
  { n: "3", t: "Buy it, sell it any time", d: "Each business trades like its own token. Its price is what the market thinks that part of the company is worth." },
];

export default function Home() {
  return (
    <div className="mx-auto max-w-[1080px] px-4 sm:px-6">
      <section className="pt-14 pb-12 sm:pt-20">
        <h1 className="display max-w-[16ch] text-[40px] sm:text-[60px]">Trade the parts of a company.</h1>
        <p className="mt-5 max-w-[58ch] text-[17px] leading-relaxed text-ink-2">
          Big companies are several businesses in one. ShareMarket lets you buy and sell each business inside a stock on its own, so you can back just the part you believe in: Google
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
