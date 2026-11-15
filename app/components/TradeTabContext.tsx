"use client";

import { createContext, useContext, useState, type ReactNode } from "react";
import type { Market } from "@/lib/markets";

export type Side = "buy" | "sell";
export type TradeTab = { side: Side; piece: number };

type Ctx = { market: Market; tab: TradeTab; setTab: (t: TradeTab) => void };
const C = createContext<Ctx | null>(null);

/** One per market page. Shared so the header cards and split bar can open a piece's trade tab. */
export function MarketProvider({ market, children }: { market: Market; children: ReactNode }) {
  const [tab, setTab] = useState<TradeTab>({ side: "buy", piece: 0 });
  return <C.Provider value={{ market, tab, setTab }}>{children}</C.Provider>;
}

export function useMarketCtx() {
  const c = useContext(C);
  if (!c) throw new Error("MarketProvider missing");
  return c;
}
