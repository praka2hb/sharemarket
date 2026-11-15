import { createConnector, type CreateConnectorFn } from "wagmi";

type Params = { appName: string };

/**
 * Coinbase Smart Wallet connector that loads the connector (and the Coinbase SDK) only when it is
 * first used. Importing `wagmi/connectors` eagerly ships every connector (WalletConnect, MetaMask, …)
 * in the first-load bundle, which costs ~100KB+ gzipped on a page that most visitors only read.
 */
export function lazyCoinbaseWallet(params: Params): CreateConnectorFn {
  return createConnector((config) => {
    type Inner = ReturnType<ReturnType<typeof import("./coinbaseConnector").coinbaseWallet>>;
    let inner: Inner | undefined;
    const load = async (): Promise<Inner> => {
      if (!inner) {
        const { coinbaseWallet } = await import("./coinbaseConnector");
        inner = coinbaseWallet({ appName: params.appName, preference: { options: "all" } })(config);
      }
      return inner;
    };
    const usedBefore = async () => (await config.storage?.getItem("recentConnectorId")) === "coinbaseWalletSDK";

    return {
      id: "coinbaseWalletSDK",
      name: "Coinbase Wallet",
      type: "coinbaseWallet",
      rdns: "com.coinbase.wallet",
      async connect(p) {
        return (await load()).connect(p as never) as never;
      },
      async disconnect() {
        return (await load()).disconnect();
      },
      async getAccounts() {
        return (await load()).getAccounts();
      },
      async getChainId() {
        return (await load()).getChainId();
      },
      async getProvider() {
        // wagmi's reconnect probes every connector's provider on page load; don't load the SDK for that
        // unless this wallet was the one used last time.
        if (!inner && !(await usedBefore())) return undefined as never;
        return (await load()).getProvider();
      },
      async isAuthorized() {
        if (!inner && !(await usedBefore())) return false;
        return (await load()).isAuthorized();
      },
      async switchChain(p) {
        return (await load()).switchChain!(p);
      },
      onAccountsChanged(accounts) {
        inner?.onAccountsChanged(accounts);
      },
      onChainChanged(chainId) {
        inner?.onChainChanged(chainId);
      },
      onDisconnect(error) {
        inner?.onDisconnect(error);
      },
    };
  });
}
