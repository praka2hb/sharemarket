import type { Metadata } from "next";
import { PageHeader } from "@/components/PageHeader";
import { ProofView } from "@/components/ProofView";

export const metadata: Metadata = { title: "Proof of backing" };

export default function ProofPage() {
  return (
    <>
      <PageHeader eyebrow="Proof" title="Every set is backed by one stock token. Check it live.">
        Read directly from Base Sepolia, refreshed every 10 seconds. In each market, the vault&apos;s stock token balance and the supply of every piece must always be equal.
      </PageHeader>
      <ProofView />
    </>
  );
}
