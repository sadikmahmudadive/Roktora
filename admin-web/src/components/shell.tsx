"use client";

import { BarChart3, Building2, Droplet, LayoutDashboard, LogOut, Menu, ScanLine, ShieldCheck, Siren, Users, X } from "lucide-react";
import Link from "next/link";
import { usePathname } from "next/navigation";
import { createContext, useContext, useEffect, useState, type ReactNode } from "react";
import { useAuth } from "@/lib/auth";
import { stockLevel } from "@/lib/models";
import { useHospital, useHospitalRequests, useInventory } from "@/lib/store";
import type { AdminAccess } from "@/lib/types";
import { VerifiedBadge } from "./badges";
import { Wordmark } from "./brand";
import { ThemeToggle } from "./theme-toggle";
import { Avatar, Button, IconButton, cn } from "./ui";

const AccessContext = createContext<AdminAccess | null>(null);

/** The signed-in staff member. Only valid below the dashboard guard. */
export function useStaff(): AdminAccess {
  const a = useContext(AccessContext);
  if (!a) throw new Error("useStaff must be used inside <Shell>");
  return a;
}

const NAV = [
  { href: "/", label: "Dashboard", icon: LayoutDashboard },
  { href: "/inventory", label: "Inventory", icon: Droplet },
  { href: "/requests", label: "Requests", icon: Siren },
  { href: "/checkin", label: "Check-in", icon: ScanLine },
  { href: "/donors", label: "Donors", icon: Users },
  { href: "/reports", label: "Reports", icon: BarChart3 },
  { href: "/profile", label: "Hospital profile", icon: Building2 },
] as const;

function isActive(pathname: string, href: string) {
  return href === "/" ? pathname === "/" : pathname === href || pathname.startsWith(`${href}/`);
}

function Sidebar({ access, onNavigate }: { access: AdminAccess; onNavigate?: () => void }) {
  const pathname = usePathname();
  const { signOut, isSuper } = useAuth();
  const hospital = useHospital(access.hospitalId).data;
  const requests = useHospitalRequests(access.hospitalId).data;
  const inventory = useInventory(access.hospitalId).data;
  const low = inventory.filter((r) => stockLevel(r) !== "healthy").length;
  const open = requests.filter((r) => r.status === "open").length;
  const badge = (href: string) => (href === "/inventory" && low > 0 ? `${low} low` : href === "/requests" && open > 0 ? String(open) : "");

  return (
    <div className="flex h-full flex-col bg-surface-1">
      <div className="px-5 pt-5 pb-4">
        <Wordmark />
      </div>
      <div className="px-5 pb-4">
        <div className="flex items-center gap-2.5 rounded-[var(--radius-ctl)] border border-line bg-surface-0 p-3">
          <span className="flex h-9 w-9 shrink-0 items-center justify-center rounded-xl bg-surface-2 text-ink-2">
            <Building2 size={18} />
          </span>
          <div className="min-w-0">
            <div className="truncate text-[13px] font-semibold">{hospital?.name || "Your hospital"}</div>
            {hospital?.verified ? <VerifiedBadge label="Verified" /> : <div className="text-xs text-ink-3">Not verified</div>}
          </div>
        </div>
      </div>
      <nav aria-label="Dashboard" className="flex-1 space-y-0.5 overflow-y-auto px-3">
        {NAV.map(({ href, label, icon: Icon }) => {
          const active = isActive(pathname, href);
          const b = badge(href);
          return (
            <Link
              key={href}
              href={href}
              onClick={onNavigate}
              aria-current={active ? "page" : undefined}
              className={cn("flex h-11 items-center gap-3 rounded-[var(--radius-ctl)] px-3 text-sm transition hover:bg-hover", active ? "bg-surface-2 font-semibold text-ink" : "text-ink-2")}
            >
              <Icon size={19} />
              <span className="flex-1">{label}</span>
              {b && <span className={cn("text-xs font-semibold", href === "/inventory" ? "text-danger-ink" : "text-ink-3")}>{b}</span>}
            </Link>
          );
        })}
        {isSuper && (
          <Link href="/platform" onClick={onNavigate} className="mt-2 flex h-11 items-center gap-3 rounded-[var(--radius-ctl)] border-t border-line px-3 text-sm text-ink-2 transition hover:bg-hover">
            <ShieldCheck size={19} />
            <span className="flex-1">Platform console</span>
          </Link>
        )}
      </nav>
      <div className="space-y-3 border-t border-line p-4">
        <div className="flex items-center gap-2.5">
          <Avatar name={access.name} />
          <div className="min-w-0 flex-1">
            <div className="truncate text-[13px] font-semibold">{access.name}</div>
            <div className="text-xs text-ink-3">{access.role === "admin" ? "Admin" : "Staff"}</div>
          </div>
          <ThemeToggle />
        </div>
        <Button variant="outline" size="sm" full icon={<LogOut size={15} />} onClick={() => void signOut()}>
          Sign out
        </Button>
      </div>
    </div>
  );
}

/** Sidebar on wide screens; a top bar with a slide-in drawer on narrow ones. */
export function Shell({ access, children }: { access: AdminAccess; children: ReactNode }) {
  const [open, setOpen] = useState(false);
  const pathname = usePathname();
  const current = NAV.find((n) => isActive(pathname, n.href))?.label ?? "Dashboard";

  useEffect(() => {
    if (!open) return;
    const onKey = (e: KeyboardEvent) => e.key === "Escape" && setOpen(false);
    window.addEventListener("keydown", onKey);
    return () => window.removeEventListener("keydown", onKey);
  }, [open]);

  return (
    <AccessContext.Provider value={access}>
      <div className="min-h-screen lg:grid lg:grid-cols-[256px_1fr]">
        <aside className="sticky top-0 hidden h-screen border-r border-line lg:block">
          <Sidebar access={access} />
        </aside>

        <header className="sticky top-0 z-30 flex h-14 items-center gap-3 border-b border-line bg-surface-0/90 px-3 backdrop-blur lg:hidden">
          <IconButton label="Open navigation menu" onClick={() => setOpen(true)}>
            <Menu size={18} />
          </IconButton>
          <span className="text-base font-semibold">{current}</span>
        </header>

        {open && (
          <div className="fixed inset-0 z-40 lg:hidden" role="dialog" aria-modal="true" aria-label="Navigation">
            <div className="absolute inset-0 bg-black/40" onClick={() => setOpen(false)} />
            <div className="absolute inset-y-0 left-0 w-[280px] max-w-[85vw] border-r border-line shadow-2xl">
              <div className="absolute top-3 right-3 z-10">
                <IconButton label="Close navigation menu" onClick={() => setOpen(false)}>
                  <X size={16} />
                </IconButton>
              </div>
              <Sidebar access={access} onNavigate={() => setOpen(false)} />
            </div>
          </div>
        )}

        <main className="min-w-0">{children}</main>
      </div>
    </AccessContext.Provider>
  );
}
