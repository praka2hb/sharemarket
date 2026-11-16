import type { Metadata } from "next";
import Link from "next/link";
import { PageHeader } from "@/components/PageHeader";

export const metadata: Metadata = { title: "How it works" };

const STEPS = [
  ["Pick a company", "Each company is broken into the businesses it reports: Alphabet into $SEARCH, $YOUTUBE and $CLOUD; NVIDIA into $HYPERSCALE, $AICLOUD and $EDGE."],
  ["Pick a business", "Each business trades as its own token. Its price is the market's view of how much of the company that business is worth."],
  ["Buy and sell any time", "Pay with the company's stock token, get the business token. Sell it back whenever you like. No expiry."],
  ["Backed by real shares", "Every business token comes from a real tokenized share locked in an on-chain vault. Check it live on the Proof page."],
];

export default function HowItWorks() {
  return (
    <>
      <PageHeader eyebrow="How it works" title="Trade the businesses inside a stock.">
        Alphabet is Search, YouTube ads and Google Cloud. NVIDIA sells to hyperscalers, to AI clouds and enterprises, and at the edge. ShareMarket lets you hold and
        trade each part on its own.
      </PageHeader>

      <div className="mx-auto max-w-[1080px] space-y-12 px-4 sm:px-6">
        <ol className="divide-y divide-line border-y border-line">
          {STEPS.map(([t, d], i) => (
            <li key={t} className="grid gap-2 py-5 sm:grid-cols-[48px_240px_1fr] sm:gap-6">
              <span className="num text-[13px] text-ink-3">0{i + 1}</span>
              <p className="text-[15px] font-medium">{t}</p>
              <p className="text-[15px] leading-relaxed text-ink-2">{d}</p>
            </li>
          ))}
        </ol>

        <section>
          <h2 className="text-[17px] font-semibold tracking-tight">Example</h2>
          <div className="mt-4 rounded-2xl border border-line p-5 text-[15px] leading-relaxed text-ink-2">
            <p>
              You think Google Cloud will grow faster than the rest of Alphabet. You buy <b className="font-medium text-ink">$CLOUD</b> at{" "}
              <span className="num text-ink">0.2917 GOOGLc</span>, meaning the market values Cloud at 29.17% of Alphabet.
            </p>
            <p className="mt-3">
              Others agree and buy, and the price moves to <span className="num text-ink">0.3500</span>. Your $CLOUD is now worth about{" "}
              <span className="num text-up">20% more</span> GOOGLc. If others sell instead, it falls.
            </p>
            <p className="mt-3 text-[13px] text-ink-3">Ignores the 0.30% pool fee and price impact.</p>
          </div>
        </section>

        <section className="grid gap-6 sm:grid-cols-2">
          <div>
            <h2 className="text-[17px] font-semibold tracking-tight">What&apos;s guaranteed</h2>
            <p className="mt-2 text-[15px] leading-relaxed text-ink-2">
              Every business token is backed by a real share held in a vault with no owner or admin. Together, a company's business tokens are worth about one share.
            </p>
          </div>
          <div>
            <h2 className="text-[17px] font-semibold tracking-tight">What isn&apos;t</h2>
            <p className="mt-2 text-[15px] leading-relaxed text-ink-2">
              Prices come only from trading. Nothing pulls them toward the revenue mix a company reports; those are shown as context only.
            </p>
          </div>
        </section>

        <div className="flex flex-wrap gap-3">
          <Link href="/" className="inline-flex h-11 items-center rounded-full bg-ink px-5 text-[14px] font-medium text-bg">
            Try the markets
          </Link>
          <Link href="/risks" className="inline-flex h-11 items-center rounded-full border border-line px-5 text-[14px] font-medium">
            Read the risks
          </Link>
        </div>
      </div>
    </>
  );
}
