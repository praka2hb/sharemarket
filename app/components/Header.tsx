"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import { useEffect, useState } from "react";
import { Wordmark } from "./Logo";
import { ConnectButton, NetworkBadge } from "./Wallet";
import { ThemeToggle } from "./ThemeToggle";

export const NAV = [
  { href: "/", label: "Markets" },
  { href: "/positions", label: "Portfolio" },
  { href: "/how-it-works", label: "How it works" },
  { href: "/proof", label: "Proof" },
];

export function Header() {
  const path = usePathname();
  const [scrolled, setScrolled] = useState(false);
  const [menu, setMenu] = useState(false);

  useEffect(() => {
    const on = () => setScrolled(window.scrollY > 8);
    on();
    window.addEventListener("scroll", on, { passive: true });
    return () => window.removeEventListener("scroll", on);
  }, []);
  useEffect(() => setMenu(false), [path]);

  return (
    <header
      className={`sticky top-0 z-40 transition-[background,border-color,backdrop-filter] duration-200 ${
        scrolled || menu ? "border-b border-line bg-bg/85 backdrop-blur-md" : "border-b border-transparent bg-bg"
      }`}
    >
      <div className="mx-auto flex h-16 max-w-[1080px] items-center gap-4 px-4 sm:px-6">
        <Link href="/" aria-label="ShareMarket home" className="shrink-0">
          <Wordmark />
        </Link>
        <nav aria-label="Main" className="mx-auto hidden items-center gap-1 lg:flex">
          {NAV.map((n) => {
            const active = n.href === "/" ? path === "/" || path.startsWith("/markets") : path.startsWith(n.href);
            return (
              <Link
                key={n.href}
                href={n.href}
                aria-current={active ? "page" : undefined}
                className={`relative whitespace-nowrap rounded-full px-3 py-2 text-[14px] font-medium transition-colors xl:px-3.5 ${
                  active ? "text-ink" : "text-ink-2 hover:text-ink"
                }`}
              >
                {n.label}
                <span
                  className={`absolute inset-x-3 -bottom-[13px] h-[2px] rounded-full bg-ink transition-transform duration-200 ease-out-expo ${
                    active ? "scale-x-100" : "scale-x-0"
                  }`}
                  aria-hidden
                />
              </Link>
            );
          })}
        </nav>
        <div className="ml-auto flex items-center gap-2 lg:ml-0">
          <NetworkBadge />
          <span className="hidden sm:block">
            <ThemeToggle />
          </span>
          <ConnectButton />
          <button
            className="grid size-9 place-items-center rounded-full border border-line lg:hidden"
            aria-label={menu ? "Close menu" : "Open menu"}
            aria-expanded={menu}
            onClick={() => setMenu((m) => !m)}
          >
            <svg width="14" height="14" viewBox="0 0 14 14" aria-hidden>
              <path
                d={menu ? "M3 3l8 8M11 3l-8 8" : "M2 4h10M2 10h10"}
                stroke="currentColor"
                strokeWidth="1.6"
                strokeLinecap="round"
                style={{ transition: "d 200ms" }}
              />
            </svg>
          </button>
        </div>
      </div>
      {menu && (
        <nav aria-label="Mobile" className="pop-in border-t border-line px-4 pb-4 lg:hidden">
          {NAV.map((n) => (
            <Link key={n.href} href={n.href} className="flex items-center justify-between border-b border-line py-3.5 text-[17px] font-medium">
              {n.label}
              <span className="text-ink-3">→</span>
            </Link>
          ))}
          <div className="mt-3 flex items-center justify-between">
            <p className="flex items-center gap-2 text-[12px] text-ink-2">
              <span className="live-dot size-1.5 rounded-full bg-up" /> Base Sepolia · testnet
            </p>
            <ThemeToggle />
          </div>
        </nav>
      )}
    </header>
  );
}
