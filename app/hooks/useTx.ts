"use client";

import { useQueryClient } from "@tanstack/react-query";
import { useCallback, useState } from "react";
import type { Abi, TransactionReceipt } from "viem";
import { useAccount, useConfig } from "wagmi";
import { simulateContract, waitForTransactionReceipt, writeContract } from "wagmi/actions";
import { useToast } from "@/components/Toaster";
import { chain } from "@/lib/chain";
import { allErrorsAbi, humanizeError, type HumanError } from "@/lib/errors";

export type TxStatus = "idle" | "wallet" | "pending" | "success" | "error";

export type TxRequest = {
  /** Short verb shown while pending, e.g. "Approving 2 GOOGLc". */
  label: string;
  address: `0x${string}`;
  abi: Abi;
  functionName: string;
  args: readonly unknown[];
  /** Success toast title + lines, decoded from the receipt. */
  describe?: (r: TransactionReceipt) => { title: string; lines?: string[] };
  /** Hide the success toast (e.g. approvals that lead straight into the trade). */
  quietSuccess?: boolean;
};

/**
 * Simulate → sign → wait → decode. Every failure becomes a human sentence (see lib/errors).
 * Returns the receipt on success, or null.
 */
export function useTx() {
  const config = useConfig();
  const { address } = useAccount();
  const toast = useToast();
  const qc = useQueryClient();
  const [status, setStatus] = useState<TxStatus>("idle");
  const [error, setError] = useState<HumanError | null>(null);

  const send = useCallback(
    async (req: TxRequest): Promise<TransactionReceipt | null> => {
      setError(null);
      setStatus("wallet");
      let toastId: number | null = null;
      try {
        const { request } = await simulateContract(config, {
          chainId: chain.id,
          account: address,
          address: req.address,
          abi: [...req.abi, ...allErrorsAbi] as Abi,
          functionName: req.functionName,
          args: req.args,
        } as never);
        const hash = await writeContract(config, request as never);
        setStatus("pending");
        toastId = toast.push({ kind: "pending", title: `${req.label}…`, lines: ["Waiting for Base Sepolia to confirm."], hash });
        const receipt = await waitForTransactionReceipt(config, { hash, chainId: chain.id });
        if (receipt.status !== "success") throw new Error("The transaction reverted on-chain.");
        const d = req.describe?.(receipt) ?? { title: "Done" };
        if (req.quietSuccess) toast.dismiss(toastId);
        else toast.update(toastId, { kind: "success", title: d.title, lines: d.lines, hash });
        setStatus("success");
        await qc.invalidateQueries();
        return receipt;
      } catch (e) {
        const h = humanizeError(e);
        setError(h);
        setStatus(h.kind === "rejected" ? "idle" : "error");
        if (toastId !== null) toast.dismiss(toastId);
        if (h.kind !== "rejected") toast.push({ kind: "error", title: "Transaction failed", lines: [h.message] });
        return null;
      }
    },
    [config, address, toast, qc],
  );

  const reset = useCallback(() => {
    setStatus("idle");
    setError(null);
  }, []);

  return { send, status, error, reset, busy: status === "wallet" || status === "pending" };
}
