import type { Metadata } from "next";
import { PageHeader } from "@/components/PageHeader";
import { PositionsView } from "@/components/PositionsView";

export const metadata: Metadata = { title: "Positions" };

export default function PositionsPage() {
  return (
    <>
      <PageHeader eyebrow="Positions" title="What you hold, valued in stock tokens.">
        Each piece is valued at its pool price, in its company's stock token. Every full set is worth exactly one stock token, because you can merge it right now.
      </PageHeader>
      <PositionsView />
    </>
  );
}
