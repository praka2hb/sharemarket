import type { Metadata } from "next";
import { notFound } from "next/navigation";
import { FaucetCard } from "@/components/FaucetCard";
import { MarketHeader } from "@/components/MarketHeader";
import { PositionStrip } from "@/components/PositionStrip";
import { PriceChart } from "@/components/PriceChart";
import { SplitMergePanel } from "@/components/SplitMergePanel";
import { TradePanel } from "@/components/TradePanel";
import { MarketProvider } from "@/components/TradeTabContext";
import { MARKETS, getMarket } from "@/lib/markets";

export const dynamicParams = false;

export function generateStaticParams() {
  return MARKETS.map((m) => ({ id: m.id }));
}

export async function generateMetadata({ params }: { params: Promise<{ id: string }> }): Promise<Metadata> {
  const m = getMarket((await params).id);
  return m ? { title: `${m.company}: ${m.pieces.map((p) => p.name).join(" · ")}` } : {};
}

export default async function MarketPage({ params }: { params: Promise<{ id: string }> }) {
  const market = getMarket((await params).id);
  if (!market) notFound();
  return (
    <MarketProvider key={market.id} market={market}>
      {/* Mobile order: header → trade → the rest. Desktop: trade panel sticks in the right column. */}
      <div className="mx-auto grid max-w-[1080px] items-start gap-8 px-4 pt-8 pb-10 sm:px-6 lg:grid-cols-[1fr_380px] lg:gap-x-10">
        <div className="min-w-0 lg:col-start-1 lg:row-start-1">
          <MarketHeader />
        </div>
        <div id="trade" className="min-w-0 scroll-mt-24 lg:sticky lg:top-24 lg:col-start-2 lg:row-span-2 lg:row-start-1">
          <TradePanel />
          <div className="mt-3">
            <FaucetCard />
          </div>
        </div>
        <div className="min-w-0 space-y-8 lg:col-start-1 lg:row-start-2">
          <PriceChart />
          <PositionStrip />
          <SplitMergePanel />
        </div>
      </div>
    </MarketProvider>
  );
}
