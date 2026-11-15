"use client";

import Link from "next/link";
import { useState } from "react";

export function AnnouncementBar() {
  const [open, setOpen] = useState(true);
  if (!open) return null;
  return (
    <div className="relative border-b border-line bg-bg-soft">
      <p className="mx-auto max-w-[1080px] px-10 py-2.5 text-center text-[13px] text-ink-2">
        <span className="font-medium text-ink">Testnet demo.</span> GOOGLc and NVDAc here are mock tokens, not real stock. Contracts are unaudited.{" "}
        <Link href="/risks" className="whitespace-nowrap font-medium text-cloud-ink hover:underline">
          Read the risks ›
        </Link>
      </p>
      <button
        onClick={() => setOpen(false)}
        aria-label="Dismiss notice"
        className="absolute top-1/2 right-3 size-7 -translate-y-1/2 rounded-full p-2 text-ink-3 hover:bg-bg-sunken hover:text-ink"
      >
        <svg viewBox="0 0 12 12" aria-hidden>
          <path d="M3 3l6 6M9 3l-6 6" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" />
        </svg>
      </button>
    </div>
  );
}
