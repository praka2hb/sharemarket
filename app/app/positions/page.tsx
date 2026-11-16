import type { Metadata } from "next";
import { PageHeader } from "@/components/PageHeader";
import { PositionsView } from "@/components/PositionsView";

export const metadata: Metadata = { title: "Positions" };

export default function PositionsPage() {
  return (
    <>
      <PageHeader eyebrow="Positions" title="What you hold, valued in stock tokens.">
        Each business token is valued at its live price, in its company's stock token.
      </PageHeader>
      <PositionsView />
    </>
  );
}
