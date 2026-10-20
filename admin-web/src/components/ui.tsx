"use client";

import clsx, { type ClassValue } from "clsx";
import { Check, X } from "lucide-react";
import { useEffect, useId, useRef, type ButtonHTMLAttributes, type InputHTMLAttributes, type ReactNode, type TextareaHTMLAttributes } from "react";
import { initials, type Tone } from "@/lib/models";

export const cn = (...v: ClassValue[]) => clsx(v);

const TONE: Record<Tone | "accent" | "brand", string> = {
  danger: "bg-danger-bg text-danger-ink",
  warning: "bg-warning-bg text-warning-ink",
  success: "bg-success-bg text-success-ink",
  neutral: "bg-surface-2 text-ink-2",
  accent: "bg-accent-bg text-accent-ink",
  brand: "bg-brand-bg text-brand-ink",
};

export const TONE_TEXT: Record<Tone, string> = {
  danger: "text-danger-ink",
  warning: "text-warning-ink",
  success: "text-success-ink",
  neutral: "text-ink-2",
};

export const TONE_FILL: Record<Tone, string> = {
  danger: "bg-danger",
  warning: "bg-warning",
  success: "bg-success",
  neutral: "bg-ink-3",
};

// ------------------------------------------------------------------ buttons

type ButtonProps = ButtonHTMLAttributes<HTMLButtonElement> & {
  variant?: "primary" | "outline" | "danger";
  size?: "sm" | "md" | "lg";
  icon?: ReactNode;
  full?: boolean;
};

export function Button({ variant = "primary", size = "md", icon, full, className, children, ...rest }: ButtonProps) {
  return (
    <button
      type="button"
      {...rest}
      className={cn(
        "inline-flex items-center justify-center gap-2 rounded-full font-semibold whitespace-nowrap transition active:scale-[0.98] disabled:cursor-not-allowed disabled:active:scale-100",
        size === "sm" && "h-9 px-4 text-[13px]",
        size === "md" && "h-10 px-5 text-sm",
        size === "lg" && "h-[52px] px-6 text-[15px]",
        full && "w-full",
        variant === "primary" && "bg-brand text-on-fill shadow-[0_8px_18px_-8px_var(--brand)] hover:brightness-95 disabled:bg-surface-2 disabled:text-ink-4 disabled:shadow-none",
        variant === "outline" && "border border-line-2 bg-transparent text-ink hover:bg-hover disabled:text-ink-4",
        variant === "danger" && "border border-danger bg-transparent text-danger-ink hover:bg-danger-bg disabled:text-ink-4",
        className,
      )}
    >
      {icon}
      {children}
    </button>
  );
}

export function IconButton({ label, className, children, ...rest }: ButtonHTMLAttributes<HTMLButtonElement> & { label: string }) {
  return (
    <button
      type="button"
      aria-label={label}
      title={label}
      {...rest}
      className={cn("inline-flex h-9 w-9 items-center justify-center rounded-full border border-line bg-surface-1 text-ink transition hover:bg-hover active:scale-95 disabled:text-ink-4", className)}
    >
      {children}
    </button>
  );
}

// ------------------------------------------------------------------ surfaces

export function Panel({ title, action, children, flush, className }: { title?: ReactNode; action?: ReactNode; children: ReactNode; flush?: boolean; className?: string }) {
  return (
    <section className={cn("overflow-hidden rounded-[var(--radius-card)] border border-line bg-surface-1", className)}>
      {title && (
        <header className="flex items-center gap-3 px-4 pt-3.5">
          <h2 className="flex-1 text-[15px] font-semibold">{title}</h2>
          {action}
        </header>
      )}
      <div className={flush ? "pt-2" : "p-4"}>{children}</div>
    </section>
  );
}

export function StatTile({ label, value, sub, tone }: { label: string; value: ReactNode; sub?: ReactNode; tone?: Tone }) {
  return (
    <div className="rounded-[var(--radius-card)] border border-line bg-surface-1 p-4">
      <div className="text-[13px] text-ink-2">{label}</div>
      <div className="mt-1 text-[32px] leading-tight font-semibold tracking-tight">{value}</div>
      <div className={cn("mt-1 min-h-4 truncate text-xs font-semibold", tone ? TONE_TEXT[tone] : "text-ink-2")}>{sub ?? " "}</div>
    </div>
  );
}

export function Banner({ tone = "neutral", icon, children, className }: { tone?: Tone | "accent"; icon?: ReactNode; children: ReactNode; className?: string }) {
  return (
    <div role={tone === "danger" ? "alert" : "status"} className={cn("flex items-start gap-3 rounded-2xl px-4 py-3 text-sm font-medium", TONE[tone], className)}>
      {icon && <span className="mt-0.5 shrink-0">{icon}</span>}
      <div className="min-w-0 flex-1">{children}</div>
    </div>
  );
}

export function Pill({ tone = "neutral", children, small, className }: { tone?: Tone | "accent" | "brand"; children: ReactNode; small?: boolean; className?: string }) {
  return (
    <span className={cn("inline-flex items-center rounded-full font-semibold whitespace-nowrap", small ? "h-6 px-2.5 text-xs" : "h-7 px-3 text-[13px]", TONE[tone], className)}>
      {children}
    </span>
  );
}

export function Progress({ value, tone = "brand", className }: { value: number; tone?: Tone | "brand" | "accent"; className?: string }) {
  const fill = tone === "brand" ? "bg-brand" : tone === "accent" ? "bg-accent" : TONE_FILL[tone];
  return (
    <div className={cn("h-1.5 overflow-hidden rounded-full bg-track", className)} role="progressbar" aria-valuemin={0} aria-valuemax={100} aria-valuenow={Math.round(Math.min(1, Math.max(0, value)) * 100)}>
      <div className={cn("h-full rounded-full transition-[width] duration-300", fill)} style={{ width: `${Math.min(1, Math.max(0, value)) * 100}%` }} />
    </div>
  );
}

export function Avatar({ name, size = 36 }: { name: string; size?: number }) {
  return (
    <span aria-hidden className="inline-flex shrink-0 items-center justify-center rounded-full border border-line bg-surface-2 font-semibold" style={{ width: size, height: size, fontSize: size * 0.36 }}>
      {initials(name)}
    </span>
  );
}

export function CheckMark({ checked }: { checked: boolean }) {
  return (
    <span aria-hidden className={cn("inline-flex h-[22px] w-[22px] shrink-0 items-center justify-center rounded-[7px]", checked ? "bg-brand text-on-fill" : "border border-line-3")}>
      {checked && <Check size={14} strokeWidth={3} />}
    </span>
  );
}

// ------------------------------------------------------------------ controls

export function Segmented<T extends string | number | boolean>({ options, value, onChange, label }: { options: readonly (readonly [T, string])[]; value: T; onChange: (v: T) => void; label?: string }) {
  return (
    <div role="group" aria-label={label} className="inline-flex overflow-hidden rounded-[var(--radius-ctl)] border border-line-2 bg-surface-1">
      {options.map(([k, text], i) => (
        <button
          key={String(k)}
          type="button"
          aria-pressed={k === value}
          onClick={() => onChange(k)}
          className={cn("h-10 px-4 text-[13px] font-medium transition", i > 0 && "border-l border-line-2", k === value ? "bg-primary text-on-primary" : "text-ink hover:bg-hover")}
        >
          {text}
        </button>
      ))}
    </div>
  );
}

export function PickChip({ selected, onClick, children }: { selected: boolean; onClick: () => void; children: ReactNode }) {
  return (
    <button
      type="button"
      aria-pressed={selected}
      onClick={onClick}
      className={cn("h-9 rounded-full border px-3.5 text-[13px] font-semibold transition active:scale-[0.97]", selected ? "border-brand bg-brand-bg text-brand-ink ring-1 ring-brand" : "border-line-2 bg-surface-1 text-ink hover:bg-hover")}
    >
      {children}
    </button>
  );
}

export function Stepper({ value, onChange, min = 0, max = 999, label }: { value: number; onChange: (v: number) => void; min?: number; max?: number; label: string }) {
  return (
    <div className="inline-flex items-center gap-2">
      <IconButton label={`Decrease ${label}`} disabled={value <= min} onClick={() => onChange(Math.max(min, value - 1))}>
        −
      </IconButton>
      <output aria-label={label} className="w-10 text-center text-lg font-semibold tabular-nums">
        {value}
      </output>
      <IconButton label={`Increase ${label}`} disabled={value >= max} onClick={() => onChange(Math.min(max, value + 1))}>
        +
      </IconButton>
    </div>
  );
}

const inputClass = "w-full rounded-[var(--radius-ctl)] border border-line-2 bg-surface-0 px-3.5 py-2.5 text-[15px] text-ink placeholder:text-ink-3 focus:border-brand focus:ring-2 focus:ring-brand-bg disabled:opacity-60";

export function Field({ label, hint, className, ...rest }: InputHTMLAttributes<HTMLInputElement> & { label: string; hint?: string }) {
  const id = useId();
  return (
    <div className={className}>
      <label htmlFor={id} className="mb-1.5 block text-[13px] font-semibold">
        {label}
      </label>
      <input id={id} {...rest} className={inputClass} />
      {hint && <p className="mt-1 text-xs text-ink-3">{hint}</p>}
    </div>
  );
}

export function TextArea({ label, className, ...rest }: TextareaHTMLAttributes<HTMLTextAreaElement> & { label: string }) {
  const id = useId();
  return (
    <div className={className}>
      <label htmlFor={id} className="mb-1.5 block text-[13px] font-semibold">
        {label}
      </label>
      <textarea id={id} {...rest} className={cn(inputClass, "min-h-24 resize-y")} />
    </div>
  );
}

// ------------------------------------------------------------------ dialog

export function Dialog({ open, onClose, title, children, footer, wide }: { open: boolean; onClose: () => void; title: string; children: ReactNode; footer?: ReactNode; wide?: boolean }) {
  const ref = useRef<HTMLDivElement>(null);
  const titleId = useId();

  useEffect(() => {
    if (!open) return;
    const onKey = (e: KeyboardEvent) => e.key === "Escape" && onClose();
    window.addEventListener("keydown", onKey);
    ref.current?.focus();
    return () => window.removeEventListener("keydown", onKey);
  }, [open, onClose]);

  if (!open) return null;
  return (
    <div className="fixed inset-0 z-50 flex items-end justify-center bg-black/40 p-0 sm:items-center sm:p-4" onMouseDown={(e) => e.target === e.currentTarget && onClose()}>
      <div ref={ref} role="dialog" aria-modal="true" aria-labelledby={titleId} tabIndex={-1} className={cn("max-h-[92vh] w-full overflow-auto rounded-t-[28px] border border-line-2 bg-surface-3 shadow-2xl outline-none sm:rounded-[28px]", wide ? "sm:max-w-xl" : "sm:max-w-md")}>
        <header className="flex items-center gap-3 px-5 pt-5">
          <h2 id={titleId} className="flex-1 text-lg font-semibold">
            {title}
          </h2>
          <IconButton label="Close" onClick={onClose}>
            <X size={16} />
          </IconButton>
        </header>
        <div className="px-5 py-4">{children}</div>
        {footer && <footer className="flex flex-wrap justify-end gap-2 px-5 pb-5">{footer}</footer>}
      </div>
    </div>
  );
}

export function Spinner({ label = "Loading" }: { label?: string }) {
  return (
    <div role="status" aria-label={label} className="flex items-center justify-center p-10">
      <span className="h-6 w-6 animate-spin rounded-full border-2 border-line-2 border-t-brand" />
    </div>
  );
}

export function Empty({ children }: { children: ReactNode }) {
  return <p className="px-4 py-5 text-sm text-ink-2">{children}</p>;
}

/** Page heading + actions. Content is capped so it reads well on very wide screens. */
export function Page({ title, subtitle, actions, children }: { title: string; subtitle?: ReactNode; actions?: ReactNode; children: ReactNode }) {
  return (
    <div className="mx-auto w-full max-w-[1180px] px-4 py-5 sm:px-7">
      <div className="mb-6 flex flex-wrap items-end gap-x-4 gap-y-3">
        <div className="min-w-60 flex-1">
          <h1 className="text-[32px] leading-tight font-semibold tracking-tight">{title}</h1>
          {subtitle && <p className="mt-1 text-sm text-ink-2">{subtitle}</p>}
        </div>
        {actions && <div className="flex flex-wrap items-center gap-2">{actions}</div>}
      </div>
      {children}
    </div>
  );
}

export function Grid({ cols, children, className }: { cols: string; children: ReactNode; className?: string }) {
  return <div className={cn("grid gap-3", cols, className)}>{children}</div>;
}

export { TONE };
