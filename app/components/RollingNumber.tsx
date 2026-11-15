"use client";

import { useEffect, useRef, useState } from "react";

/**
 * Odometer-style number: each digit is a vertical strip that rolls to its new value.
 * Flashes green/red on change. Reduced-motion users get an instant swap (via global CSS).
 */
export function RollingNumber({ value, className = "", flash = true }: { value: string; className?: string; flash?: boolean }) {
  const prev = useRef<string | null>(null);
  const [dir, setDir] = useState<"up" | "down" | null>(null);

  useEffect(() => {
    const p = prev.current;
    prev.current = value;
    if (!flash || p === null || p === value) return;
    const a = parseFloat(p.replace(/[^\d.-]/g, ""));
    const b = parseFloat(value.replace(/[^\d.-]/g, ""));
    if (Number.isFinite(a) && Number.isFinite(b) && a !== b) {
      setDir(b > a ? "up" : "down");
      const t = setTimeout(() => setDir(null), 900);
      return () => clearTimeout(t);
    }
  }, [value, flash]);

  return (
    <span className={`num inline-flex ${dir === "up" ? "flash-up" : dir === "down" ? "flash-down" : ""} ${className}`} aria-label={value} role="text">
      {value.split("").map((ch, i) =>
        /\d/.test(ch) ? (
          <span key={i} className="relative inline-block h-[1em] overflow-hidden leading-none" style={{ width: "0.62em" }} aria-hidden>
            <span
              className="absolute left-0 top-0 flex flex-col"
              style={{
                transform: `translateY(-${Number(ch) * 10}%)`,
                transition: `transform 600ms var(--ease-out) ${i * 30}ms`,
              }}
            >
              {"0123456789".split("").map((d) => (
                <span key={d} className="block h-[1em] leading-none">
                  {d}
                </span>
              ))}
            </span>
          </span>
        ) : (
          <span key={i} className="inline-block leading-none" aria-hidden>
            {ch}
          </span>
        ),
      )}
    </span>
  );
}
