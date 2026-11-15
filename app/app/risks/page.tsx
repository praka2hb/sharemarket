import type { Metadata } from "next";
import { PageHeader } from "@/components/PageHeader";
import { PausedStatus } from "@/components/PausedStatus";

export const metadata: Metadata = { title: "Risks" };

const RISKS: { title: string; body: React.ReactNode; level: "info" | "med" | "high" }[] = [
  {
    title: "This is a testnet, and the stock tokens here are mocks",
    level: "info",
    body: (
      <>
        On Base Sepolia, GOOGLc and NVDAc are mock tokens the team deployed. They copy the real Coinbase B20 tokens&apos; rules (8 decimals, an issuer blocklist,
        pause), but they aren&apos;t real stock and have no value. The real tokens only exist on Base mainnet.
      </>
    ),
  },
  {
    title: "The contracts are unaudited",
    level: "high",
    body: "The vaults and routers are small and tested, but no third party has audited them. Bugs could lose funds.",
  },
  {
    title: "Prices aren't tied to the reported numbers",
    level: "high",
    body: "Piece prices come only from trading. Nothing pulls them toward the revenue mix a company reports, and they can drift far from it. There is no settlement, no expiry and no payout.",
  },
  {
    title: "Thin liquidity means price impact",
    level: "med",
    body: "The pools are small, and small pieces like $YOUTUBE and $EDGE move most. Larger trades move the price, so you may receive noticeably less than the spot price suggests. The trade panel shows price impact and a minimum-received before you confirm.",
  },
  {
    title: "The stock issuer can pause or blocklist",
    level: "med",
    body: (
      <>
        The issuer of each stock token can pause transfers or block addresses. If that happens, trading and merging in that market stop until it&apos;s lifted. If your
        own address is blocked, merge can send the stock token to a different address. The mocks copy this behaviour; their live status is shown above.
      </>
    ),
  },
  {
    title: "Merging needs every piece",
    level: "info",
    body: "To turn pieces back into the stock token through merge, you need one of every piece. If you only hold one piece, you exit by selling it in its pool.",
  },
  {
    title: "Other pools can exist",
    level: "info",
    body: "Anyone can create other pools for any piece elsewhere. This app only trades on the pools listed on the Proof page; prices elsewhere may differ.",
  },
];

const tone = {
  info: "bg-bg-sunken text-ink-2",
  med: "bg-warn-bg text-warn-ink",
  high: "bg-down/10 text-down",
};
const toneLabel = { info: "Know this", med: "Medium", high: "High" };

export default function RisksPage() {
  return (
    <>
      <PageHeader eyebrow="Risks" title="Read this before you trade.">
        We&apos;d rather you understand the product than be surprised by it. Nothing here is investment advice.
      </PageHeader>
      <section className="mx-auto max-w-[1080px] space-y-3 px-4 sm:px-6">
        <PausedStatus />
        {RISKS.map((r, i) => (
            <article key={r.title} className="grid gap-3 rounded-2xl border border-line bg-bg p-5 sm:grid-cols-[40px_1fr_auto] sm:items-start">
              <span className="num text-[13px] text-ink-3">0{i + 1}</span>
              <div>
                <h2 className="text-[16px] font-semibold tracking-tight">{r.title}</h2>
                <p className="mt-1.5 text-[15px] leading-relaxed text-ink-2">{r.body}</p>
              </div>
              <span className={`w-fit rounded-full px-2.5 py-1 text-[11px] font-semibold ${tone[r.level]}`}>{toneLabel[r.level]}</span>
            </article>
        ))}
      </section>
    </>
  );
}
