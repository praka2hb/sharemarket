"use client";

import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { useEffect, useState, type ReactNode } from "react";
import { WagmiProvider } from "wagmi";
import { reconnect } from "wagmi/actions";
import { wagmiConfig } from "@/lib/wagmi";
import { ToastProvider } from "@/components/Toaster";

/**
 * Reconnecting probes every connector, which pulls in the Coinbase wallet SDK.
 * Do it once the page is idle so it never competes with first paint.
 */
function useIdleReconnect() {
  useEffect(() => {
    const run = () => reconnect(wagmiConfig);
    const w = window as Window & { requestIdleCallback?: (cb: () => void, o?: { timeout: number }) => number };
    if (w.requestIdleCallback) {
      const id = w.requestIdleCallback(run, { timeout: 2500 });
      return () => (window as Window & { cancelIdleCallback?: (id: number) => void }).cancelIdleCallback?.(id);
    }
    const t = setTimeout(run, 1200);
    return () => clearTimeout(t);
  }, []);
}

export function Providers({ children }: { children: ReactNode }) {
  const [client] = useState(
    () => new QueryClient({ defaultOptions: { queries: { staleTime: 5_000, refetchOnWindowFocus: true, retry: 1 } } }),
  );
  useIdleReconnect();
  return (
    <WagmiProvider config={wagmiConfig} reconnectOnMount={false}>
      <QueryClientProvider client={client}>
        <ToastProvider>
          {children}
        </ToastProvider>
      </QueryClientProvider>
    </WagmiProvider>
  );
}
