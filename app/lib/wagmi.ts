import { createConfig, http, injected } from "wagmi";
import { chain, RPC_URL } from "./chain";
import { lazyCoinbaseWallet } from "./lazyCoinbase";

export const wagmiConfig = createConfig({
  chains: [chain],
  connectors: [
    // Coinbase Smart Wallet first: the competition is on Base. Loaded on demand.
    lazyCoinbaseWallet({ appName: "ShareMarket" }),
    // MetaMask, Rabby etc. are also discovered automatically via EIP-6963.
    injected({ shimDisconnect: true }),
  ],
  transports: { [chain.id]: http(RPC_URL, { batch: { wait: 16 } }) },
  batch: { multicall: true },
  ssr: true,
});

declare module "wagmi" {
  interface Register {
    config: typeof wagmiConfig;
  }
}
