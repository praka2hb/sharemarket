"use client";

import { useEffect, useRef, useState } from "react";
import { useAccount, useConnect, useDisconnect, useSwitchChain, type Connector } from "wagmi";
import { addressUrl, chain } from "@/lib/chain";
import { short } from "@/lib/errors";

function useHydrated() {
  const [h, setH] = useState(false);
  useEffect(() => setH(true), []);
  return h;
}

export function NetworkBadge() {
  return (
    <span className="hidden items-center gap-2 whitespace-nowrap rounded-full border border-line px-3 py-1.5 text-[12px] font-medium text-ink-2 xl:inline-flex">
      <span className="live-dot size-1.5 rounded-full bg-up" aria-hidden />
      Base Sepolia <span className="text-ink-3">· testnet</span>
    </span>
  );
}

export function ConnectButton({ size = "sm", className = "" }: { size?: "sm" | "lg"; className?: string }) {
  const hydrated = useHydrated();
  const { address, isConnected, chainId } = useAccount();
  const { switchChain, isPending: switching } = useSwitchChain();
  const [open, setOpen] = useState(false);
  const pad = size === "lg" ? "h-12 px-6 text-[15px]" : "h-9 px-4 text-[13px]";

  if (!hydrated) return <span className={`skeleton inline-block ${size === "lg" ? "h-12 w-40" : "h-9 w-28"} rounded-full ${className}`} />;

  if (isConnected && chainId !== chain.id) {
    return (
      <button
        onClick={() => switchChain({ chainId: chain.id })}
        disabled={switching}
        className={`${pad} ${className} inline-flex items-center gap-2 whitespace-nowrap rounded-full bg-down font-medium text-white transition hover:opacity-90`}
      >
        {switching ? "Switching…" : <>Switch<span className="hidden sm:inline"> to Base Sepolia</span></>}
      </button>
    );
  }

  if (isConnected && address) return <AccountMenu address={address} className={className} />;

  return (
    <>
      <button
        onClick={() => setOpen(true)}
        className={`${pad} ${className} group inline-flex items-center gap-2 whitespace-nowrap rounded-full bg-ink font-medium text-bg transition-[transform,background] duration-150 hover:scale-[1.02] active:scale-[0.98]`}
      >
<span>
          Connect<span className="hidden sm:inline"> wallet</span>
        </span>
        <svg width="10" height="10" viewBox="0 0 10 10" aria-hidden className="transition-transform duration-200 group-hover:translate-x-0.5">
          <path d="M3 1.5L6.5 5 3 8.5" stroke="currentColor" strokeWidth="1.6" fill="none" strokeLinecap="round" />
        </svg>
      </button>
      {open && <ConnectModal onClose={() => setOpen(false)} />}
    </>
  );
}

function AccountMenu({ address, className }: { address: string; className: string }) {
  const { disconnect } = useDisconnect();
  const [open, setOpen] = useState(false);
  const [copied, setCopied] = useState(false);
  const ref = useRef<HTMLDivElement>(null);
  useEffect(() => {
    const onDoc = (e: MouseEvent) => !ref.current?.contains(e.target as Node) && setOpen(false);
    const onKey = (e: KeyboardEvent) => e.key === "Escape" && setOpen(false);
    document.addEventListener("mousedown", onDoc);
    document.addEventListener("keydown", onKey);
    return () => {
      document.removeEventListener("mousedown", onDoc);
      document.removeEventListener("keydown", onKey);
    };
  }, []);
  return (
    <div ref={ref} className={`relative ${className}`}>
      <button
        onClick={() => setOpen((o) => !o)}
        aria-expanded={open}
        className="num inline-flex h-9 items-center gap-2 rounded-full border border-line bg-bg px-3 text-[13px] font-medium transition hover:border-line-strong"
      >
        <span className="size-4 rounded-full" style={{ background: `conic-gradient(var(--cloud) 0 30%, var(--services) 30% 100%)` }} aria-hidden />
        {short(address)}
      </button>
      {open && (
        <div className="pop-in absolute right-0 z-50 mt-2 w-56 overflow-hidden rounded-2xl border border-line bg-bg p-1.5 shadow-lg">
          <button
            className="w-full rounded-xl px-3 py-2 text-left text-sm hover:bg-bg-soft"
            onClick={() => {
              navigator.clipboard?.writeText(address);
              setCopied(true);
              setTimeout(() => setCopied(false), 1200);
            }}
          >
            {copied ? "Copied ✓" : "Copy address"}
          </button>
          <a className="block rounded-xl px-3 py-2 text-sm hover:bg-bg-soft" href={addressUrl(address)} target="_blank" rel="noreferrer">
            View on BaseScan ↗
          </a>
          <button className="w-full rounded-xl px-3 py-2 text-left text-sm text-down hover:bg-bg-soft" onClick={() => disconnect()}>
            Disconnect
          </button>
        </div>
      )}
    </div>
  );
}

function connectorMeta(c: Connector) {
  if (c.id === "coinbaseWalletSDK")
    return { name: "Coinbase Smart Wallet", hint: "Recommended · sign in with a passkey, no extension", primary: true };
  if (c.id === "injected") return { name: "Browser wallet", hint: "Any injected wallet", primary: false };
  return { name: c.name, hint: "Browser extension", primary: false };
}

export function ConnectModal({ onClose }: { onClose: () => void }) {
  const { connectors, connect, isPending, variables, error } = useConnect();
  const dialog = useRef<HTMLDivElement>(null);
  const discovered = connectors.filter((c) => c.id !== "coinbaseWalletSDK" && c.id !== "injected" && c.id !== "com.coinbase.wallet");
  const list = [
    ...connectors.filter((c) => c.id === "coinbaseWalletSDK"),
    ...discovered,
    ...(discovered.length === 0 ? connectors.filter((c) => c.id === "injected") : []),
  ];

  useEffect(() => {
    const onKey = (e: KeyboardEvent) => e.key === "Escape" && onClose();
    document.addEventListener("keydown", onKey);
    dialog.current?.querySelector<HTMLButtonElement>("button[data-first]")?.focus();
    const prev = document.body.style.overflow;
    document.body.style.overflow = "hidden";
    return () => {
      document.removeEventListener("keydown", onKey);
      document.body.style.overflow = prev;
    };
  }, [onClose]);

  return (
    <div className="fixed inset-0 z-[80] flex items-end justify-center sm:items-center" role="dialog" aria-modal="true" aria-labelledby="connect-title">
      <button aria-label="Close" className="absolute inset-0 bg-black/40 backdrop-blur-[2px]" onClick={onClose} />
      <div ref={dialog} className="pop-in relative w-full max-w-md rounded-t-2xl border border-line bg-bg p-5 shadow-lg sm:rounded-2xl">
        <div className="mb-4 flex items-center justify-between">
          <h2 id="connect-title" className="text-lg font-semibold tracking-tight">
            Connect a wallet
          </h2>
          <button onClick={onClose} aria-label="Close" className="size-8 rounded-full p-2 text-ink-3 hover:bg-bg-soft hover:text-ink">
            <svg viewBox="0 0 12 12" aria-hidden>
              <path d="M3 3l6 6M9 3l-6 6" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" />
            </svg>
          </button>
        </div>
        <ul className="space-y-2">
          {list.map((c, i) => {
            const m = connectorMeta(c);
            const loading = isPending && variables?.connector === c;
            return (
              <li key={c.uid}>
                <button
                  data-first={i === 0 ? "" : undefined}
                  onClick={() => connect({ connector: c, chainId: chain.id }, { onSuccess: onClose })}
                  disabled={isPending}
                  className={`flex w-full items-center gap-3 rounded-2xl border p-3.5 text-left transition hover:-translate-y-px ${
                    m.primary ? "border-cloud/40 bg-cloud-soft hover:border-cloud" : "border-line hover:border-line-strong"
                  }`}
                >
                  {c.icon ? (
                    // eslint-disable-next-line @next/next/no-img-element
                    <img src={c.icon} alt="" className="size-9 rounded-xl" />
                  ) : (
                    <span className={`grid size-9 place-items-center rounded-xl ${m.primary ? "bg-cloud" : "bg-bg-sunken"}`} aria-hidden>
                      <span className={`size-3.5 rounded-[4px] ${m.primary ? "bg-white" : "bg-ink-3"}`} />
                    </span>
                  )}
                  <span className="min-w-0 flex-1">
                    <span className="block text-[15px] font-medium">{m.name}</span>
                    <span className="block truncate text-[12px] text-ink-2">{m.hint}</span>
                  </span>
                  {loading && <span className="spinner size-4 rounded-full border-2 border-ink border-t-transparent" />}
                </button>
              </li>
            );
          })}
        </ul>
        {error && <p className="mt-3 text-sm text-down">{error.message.split("\n")[0]}</p>}
        <p className="mt-4 text-[12px] leading-relaxed text-ink-3">
          Testnet only. You&apos;ll need a little free Base Sepolia ETH for gas; the app gives you the test stock tokens.
        </p>
      </div>
    </div>
  );
}
