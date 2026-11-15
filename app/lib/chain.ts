import { createPublicClient, fallback, http } from "viem";
import { baseSepolia } from "viem/chains";

export const chain = baseSepolia;
export const EXPLORER = "https://sepolia.basescan.org";

export const RPC_URL = process.env.NEXT_PUBLIC_RPC_URL || "https://sepolia.base.org";

/**
 * Base's public RPC caps eth_getLogs at 200 blocks, so event history is read from public RPCs
 * that accept wide ranges. Override with NEXT_PUBLIC_LOGS_RPC_URL.
 */
export const LOGS_RPC_URLS = process.env.NEXT_PUBLIC_LOGS_RPC_URL
  ? [process.env.NEXT_PUBLIC_LOGS_RPC_URL]
  : ["https://base-sepolia.gateway.tenderly.co", "https://base-sepolia-rpc.publicnode.com"];

/** Max block span per eth_getLogs call (publicnode allows 50k). */
export const LOGS_CHUNK = 45_000n;

export const logsClient = createPublicClient({
  chain,
  transport: fallback(LOGS_RPC_URLS.map((u) => http(u, { retryCount: 1 }))),
});

export const txUrl = (hash: string) => `${EXPLORER}/tx/${hash}`;
export const addressUrl = (a: string) => `${EXPLORER}/address/${a}`;

/** Base produces a block every 2 seconds; used to date events without fetching each block. */
export const BLOCK_TIME_S = 2;
