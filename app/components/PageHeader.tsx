import type { ReactNode } from "react";

export function PageHeader({ eyebrow, title, children }: { eyebrow: string; title: ReactNode; children?: ReactNode }) {
  return (
    <header className="mx-auto max-w-[1080px] px-4 pt-12 pb-10 sm:px-6 sm:pt-16">
      <p className="text-[13px] text-ink-3">{eyebrow}</p>
      <h1 className="display mt-2 max-w-[22ch] text-[34px] sm:text-[48px]">{title}</h1>
      {children && <div className="mt-4 max-w-[62ch] text-[16px] leading-relaxed text-ink-2">{children}</div>}
    </header>
  );
}

export function Card({ children, className = "" }: { children: ReactNode; className?: string }) {
  return <div className={`rounded-2xl border border-line bg-bg p-5 ${className}`}>{children}</div>;
}
