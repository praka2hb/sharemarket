"use client";

import { createContext, useCallback, useContext, useMemo, useRef, useState, type ReactNode } from "react";
import { txUrl } from "@/lib/chain";

export type Toast = {
  id: number;
  kind: "pending" | "success" | "error" | "info";
  title: string;
  lines?: string[];
  hash?: string;
  action?: { label: string; onClick: () => void };
};

type Ctx = {
  push: (t: Omit<Toast, "id">) => number;
  update: (id: number, t: Partial<Omit<Toast, "id">>) => void;
  dismiss: (id: number) => void;
};

const ToastCtx = createContext<Ctx | null>(null);

export function useToast() {
  const c = useContext(ToastCtx);
  if (!c) throw new Error("ToastProvider missing");
  return c;
}

export function ToastProvider({ children }: { children: ReactNode }) {
  const [toasts, setToasts] = useState<Toast[]>([]);
  const nextId = useRef(1);
  const timers = useRef(new Map<number, ReturnType<typeof setTimeout>>());

  const dismiss = useCallback((id: number) => {
    setToasts((ts) => ts.filter((t) => t.id !== id));
    const tm = timers.current.get(id);
    if (tm) clearTimeout(tm);
    timers.current.delete(id);
  }, []);

  const schedule = useCallback(
    (id: number, kind: Toast["kind"]) => {
      const old = timers.current.get(id);
      if (old) clearTimeout(old);
      if (kind === "pending") return;
      timers.current.set(id, setTimeout(() => dismiss(id), kind === "error" ? 12_000 : 9_000));
    },
    [dismiss],
  );

  const push = useCallback(
    (t: Omit<Toast, "id">) => {
      const id = nextId.current++;
      setToasts((ts) => [...ts.slice(-3), { ...t, id }]);
      schedule(id, t.kind);
      return id;
    },
    [schedule],
  );

  const update = useCallback(
    (id: number, patch: Partial<Omit<Toast, "id">>) => {
      setToasts((ts) => ts.map((t) => (t.id === id ? { ...t, ...patch } : t)));
      if (patch.kind) schedule(id, patch.kind);
    },
    [schedule],
  );

  const value = useMemo(() => ({ push, update, dismiss }), [push, update, dismiss]);

  return (
    <ToastCtx.Provider value={value}>
      {children}
      <div
        aria-live="polite"
        className="pointer-events-none fixed inset-x-0 bottom-0 z-[90] flex flex-col items-center gap-2 p-3 sm:inset-x-auto sm:right-4 sm:bottom-4 sm:items-end sm:p-0"
      >
        {toasts.map((t) => (
          <ToastCard key={t.id} t={t} onClose={() => dismiss(t.id)} />
        ))}
      </div>
    </ToastCtx.Provider>
  );
}

function ToastCard({ t, onClose }: { t: Toast; onClose: () => void }) {
  const accent =
    t.kind === "success" ? "bg-up" : t.kind === "error" ? "bg-down" : t.kind === "pending" ? "bg-cloud" : "bg-ink-3";
  return (
    <div
      role={t.kind === "error" ? "alert" : "status"}
      className="pop-in pointer-events-auto relative w-full max-w-sm overflow-hidden rounded-2xl border border-line bg-bg shadow-lg"
    >
      <span className={`absolute inset-y-0 left-0 w-1 ${accent}`} aria-hidden />
      <div className="flex gap-3 p-4 pl-5">
        <div className="mt-0.5">
          {t.kind === "pending" ? (
            <span className="spinner block size-4 rounded-full border-2 border-cloud border-t-transparent" />
          ) : t.kind === "success" ? (
            <svg width="16" height="16" viewBox="0 0 16 16" aria-hidden>
              <circle cx="8" cy="8" r="8" fill="var(--up)" />
              <path d="M4.5 8.2l2.2 2.2 4.8-4.8" stroke="#fff" strokeWidth="1.8" fill="none" strokeLinecap="round" />
            </svg>
          ) : (
            <svg width="16" height="16" viewBox="0 0 16 16" aria-hidden>
              <circle cx="8" cy="8" r="8" fill={t.kind === "error" ? "var(--down)" : "var(--ink-3)"} />
              <path d="M8 4.5v4.2M8 11h.01" stroke="#fff" strokeWidth="1.8" strokeLinecap="round" />
            </svg>
          )}
        </div>
        <div className="min-w-0 flex-1">
          <p className="text-sm font-semibold">{t.title}</p>
          {t.lines?.map((l, i) => (
            <p key={i} className="num mt-0.5 text-[13px] text-ink-2">
              {l}
            </p>
          ))}
          <div className="mt-2 flex flex-wrap items-center gap-3 text-[13px]">
            {t.hash && (
              <a href={txUrl(t.hash)} target="_blank" rel="noreferrer" className="font-medium text-cloud-ink hover:underline">
                View on BaseScan ↗
              </a>
            )}
            {t.action && (
              <button onClick={t.action.onClick} className="font-medium text-ink underline underline-offset-2">
                {t.action.label}
              </button>
            )}
          </div>
        </div>
        <button onClick={onClose} aria-label="Dismiss" className="-m-1 h-6 w-6 rounded-full p-1 text-ink-3 hover:bg-bg-sunken hover:text-ink">
          <svg viewBox="0 0 12 12" aria-hidden>
            <path d="M3 3l6 6M9 3l-6 6" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" />
          </svg>
        </button>
      </div>
    </div>
  );
}
