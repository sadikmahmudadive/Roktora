"use client";

import { Building2, LayoutDashboard, LogOut, Plus, Search, ShieldCheck } from "lucide-react";
import Link from "next/link";
import { useRouter } from "next/navigation";
import { useEffect, useMemo, useState } from "react";
import { VerifiedBadge } from "@/components/badges";
import { Wordmark } from "@/components/brand";
import { SetupNotice } from "@/components/guard";
import { ThemeToggle } from "@/components/theme-toggle";
import { Avatar, Banner, Button, Dialog, Empty, Field, Page, Panel, Pill, Segmented, Spinner, cn } from "@/components/ui";
import { useAuth } from "@/lib/auth";
import { createHospital, setAccountAccess, setHospitalVerified, useAccounts, useHospitals, type AccountRow } from "@/lib/platform";

const selectClass = "w-full rounded-[var(--radius-ctl)] border border-line-2 bg-surface-0 px-3.5 py-2.5 text-[15px] text-ink focus:border-brand focus:ring-2 focus:ring-brand-bg";

export default function PlatformPage() {
  const { user, access, isSuper, account, configured, signOut } = useAuth();
  const router = useRouter();

  useEffect(() => {
    if (configured && user === null) router.replace("/login");
    if (user && account !== undefined && !isSuper) router.replace("/");
  }, [configured, user, account, isSuper, router]);

  if (!configured) return <SetupNotice />;
  if (!user || account === undefined || !isSuper) return <Spinner label="Checking your access" />;

  return (
    <div className="min-h-screen">
      <header className="sticky top-0 z-30 flex h-14 items-center gap-3 border-b border-line bg-surface-0/90 px-4 backdrop-blur">
        <Wordmark />
        <Pill tone="accent" small>Platform</Pill>
        <span className="flex-1" />
        {access && (
          <Link href="/" className="hidden items-center gap-1.5 text-sm text-ink-2 hover:text-ink sm:inline-flex">
            <LayoutDashboard size={16} />
            Hospital dashboard
          </Link>
        )}
        <ThemeToggle />
        <Button variant="outline" size="sm" icon={<LogOut size={15} />} onClick={() => void signOut()}>
          Sign out
        </Button>
      </header>
      <Console />
    </div>
  );
}

function Console() {
  const [tab, setTab] = useState<"accounts" | "hospitals">("accounts");
  const accounts = useAccounts(true);
  const hospitals = useHospitals(true);

  return (
    <Page title="Platform console" subtitle="Link people to hospitals and verify hospitals. Superadmins are set only in the Firebase console.">
      <div className="mb-4">
        <Segmented
          label="Section"
          value={tab}
          onChange={setTab}
          options={[
            ["accounts", `Accounts${accounts.loading ? "" : ` (${accounts.data.length})`}`],
            ["hospitals", `Hospitals${hospitals.loading ? "" : ` (${hospitals.data.length})`}`],
          ]}
        />
      </div>
      {tab === "accounts" ? (
        <Accounts rows={accounts.data} loading={accounts.loading} error={accounts.error} hospitals={hospitals.data.map((h) => ({ id: h.id, name: h.name }))} />
      ) : (
        <Hospitals />
      )}
    </Page>
  );
}

function roleTone(r: AccountRow["role"]) {
  return r === "superadmin" ? "accent" : r === "admin" ? "brand" : r === "staff" ? "success" : "neutral";
}

function Accounts({ rows, loading, error, hospitals }: { rows: AccountRow[]; loading: boolean; error: string | null; hospitals: { id: string; name: string }[] }) {
  const [q, setQ] = useState("");
  const [editing, setEditing] = useState<AccountRow | null>(null);
  const shown = useMemo(() => {
    const needle = q.trim().toLowerCase();
    const list = needle ? rows.filter((r) => `${r.name} ${r.email} ${r.phone} ${r.uid} ${r.hospitalId}`.toLowerCase().includes(needle)) : rows;
    return [...list].sort((a, b) => (b.lastLoginAt?.getTime() ?? 0) - (a.lastLoginAt?.getTime() ?? 0));
  }, [rows, q]);

  if (loading) return <Spinner />;
  return (
    <>
      {error && <Banner className="mb-3" tone="danger">Couldn&apos;t load accounts: {error}</Banner>}
      <div className="relative mb-3">
        <Search size={16} className="pointer-events-none absolute top-1/2 left-3.5 -translate-y-1/2 text-ink-3" />
        <input aria-label="Search accounts" placeholder="Search by name, email, phone or ID" value={q} onChange={(e) => setQ(e.target.value)} className={cn(selectClass, "pl-10")} />
      </div>
      <Panel flush>
        {shown.length === 0 ? (
          <Empty>No accounts match.</Empty>
        ) : (
          <ul>
            {shown.map((r, i) => (
              <li key={r.uid} className={cn("flex items-center gap-3 px-4 py-3", i > 0 && "border-t border-line")}>
                <Avatar name={r.name || r.email || "?"} />
                <div className="min-w-0 flex-1">
                  <div className="truncate font-semibold">{r.name || r.email || r.phone || r.uid}</div>
                  <div className="truncate text-xs text-ink-2">{[r.email, r.phone].filter(Boolean).join(" · ") || r.uid}</div>
                </div>
                {r.hospitalId && <span className="hidden font-mono text-xs text-ink-3 sm:inline">{r.hospitalId}</span>}
                <Pill tone={roleTone(r.role)} small>{r.role}</Pill>
                <Button variant="outline" size="sm" disabled={r.role === "superadmin"} onClick={() => setEditing(r)} aria-label={`Edit access for ${r.name || r.email || r.uid}`}>
                  Edit
                </Button>
              </li>
            ))}
          </ul>
        )}
      </Panel>
      {editing && <AccessDialog key={editing.uid} account={editing} hospitals={hospitals} onClose={() => setEditing(null)} />}
    </>
  );
}

function AccessDialog({ account: a, hospitals, onClose }: { account: AccountRow; hospitals: { id: string; name: string }[]; onClose: () => void }) {
  const [role, setRole] = useState<"user" | "staff" | "admin">(a.role === "superadmin" ? "user" : a.role);
  const [hid, setHid] = useState(a.hospitalId);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const needsHospital = role !== "user";
  const valid = !needsHospital || hid.trim().length > 0;

  async function save() {
    setBusy(true);
    setError(null);
    try {
      await setAccountAccess(a.uid, role, hid);
      onClose();
    } catch {
      setError("Couldn't save. Check your connection and that you're a superadmin.");
      setBusy(false);
    }
  }

  return (
    <Dialog
      open
      onClose={onClose}
      title="Edit access"
      footer={
        <>
          <Button variant="outline" onClick={onClose}>Cancel</Button>
          <Button disabled={busy || !valid} onClick={() => void save()}>{busy ? "Saving…" : "Save"}</Button>
        </>
      }
    >
      <p className="mb-4 text-sm text-ink-2">{a.name || a.email || a.phone || a.uid}</p>
      <div className="space-y-3">
        <div>
          <label htmlFor="acc-role" className="mb-1.5 block text-[13px] font-semibold">Role</label>
          <select id="acc-role" className={selectClass} value={role} onChange={(e) => setRole(e.target.value as typeof role)}>
            <option value="user">User (donor only)</option>
            <option value="staff">Hospital staff</option>
            <option value="admin">Hospital admin</option>
          </select>
        </div>
        {needsHospital && (
          <div>
            <label htmlFor="acc-hospital" className="mb-1.5 block text-[13px] font-semibold">Hospital</label>
            <select id="acc-hospital" className={selectClass} value={hid} onChange={(e) => setHid(e.target.value)}>
              <option value="">Choose a hospital…</option>
              {hospitals.map((h) => (
                <option key={h.id} value={h.id}>{h.name || h.id} ({h.id})</option>
              ))}
              {hid && !hospitals.some((h) => h.id === hid) && <option value={hid}>{hid}</option>}
            </select>
          </div>
        )}
        {error && <Banner tone="danger">{error}</Banner>}
      </div>
    </Dialog>
  );
}

function Hospitals() {
  const { data, loading, error } = useHospitals(true);
  const [adding, setAdding] = useState(false);
  const [failed, setFailed] = useState<string | null>(null);

  async function toggle(id: string, verified: boolean) {
    setFailed(null);
    try {
      await setHospitalVerified(id, verified);
    } catch {
      setFailed("Couldn't update that hospital.");
    }
  }

  if (loading) return <Spinner />;
  return (
    <>
      {error && <Banner className="mb-3" tone="danger">Couldn&apos;t load hospitals: {error}</Banner>}
      {failed && <Banner className="mb-3" tone="danger">{failed}</Banner>}
      <div className="mb-3 flex justify-end">
        <Button icon={<Plus size={16} />} onClick={() => setAdding(true)}>Add hospital</Button>
      </div>
      <Panel flush>
        {data.length === 0 ? (
          <Empty>No hospitals yet. Add the first one.</Empty>
        ) : (
          <ul>
            {data.map((h, i) => (
              <li key={h.id} className={cn("flex items-center gap-3 px-4 py-3", i > 0 && "border-t border-line")}>
                <span className="flex h-10 w-10 shrink-0 items-center justify-center rounded-xl bg-surface-2 text-ink-2"><Building2 size={18} /></span>
                <div className="min-w-0 flex-1">
                  <div className="truncate font-semibold">{h.name || "Unnamed hospital"}</div>
                  <div className="truncate font-mono text-xs text-ink-3">{h.id}</div>
                </div>
                {h.verified ? <VerifiedBadge label="Verified" /> : <Pill tone="warning" small>Unverified</Pill>}
                <Button variant="outline" size="sm" onClick={() => void toggle(h.id, !h.verified)} aria-label={`${h.verified ? "Remove verification from" : "Verify"} ${h.name || h.id}`}>
                  {h.verified ? "Unverify" : "Verify"}
                </Button>
              </li>
            ))}
          </ul>
        )}
      </Panel>
      {adding && <AddHospital existing={data.map((h) => h.id)} onClose={() => setAdding(false)} />}
    </>
  );
}

function AddHospital({ existing, onClose }: { existing: string[]; onClose: () => void }) {
  const [name, setName] = useState("");
  const [id, setId] = useState("");
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const slug = (id || name).toLowerCase().replace(/[^a-z0-9]+/g, "-").replace(/^-+|-+$/g, "");
  const taken = existing.includes(slug);
  const valid = name.trim().length >= 2 && slug.length >= 2 && !taken;

  async function save() {
    setBusy(true);
    setError(null);
    try {
      await createHospital(slug, name);
      onClose();
    } catch {
      setError("Couldn't create the hospital. Check you're a superadmin.");
      setBusy(false);
    }
  }

  return (
    <Dialog
      open
      onClose={onClose}
      title="Add hospital"
      footer={
        <>
          <Button variant="outline" onClick={onClose}>Cancel</Button>
          <Button disabled={busy || !valid} onClick={() => void save()}>{busy ? "Creating…" : "Create"}</Button>
        </>
      }
    >
      <div className="space-y-3">
        <Field label="Hospital name" value={name} onChange={(e) => setName(e.target.value)} />
        <Field label="Hospital ID" value={id} placeholder={slug || "mirpur-central"} hint={taken ? "That ID is already used." : `Used when linking staff: ${slug || "…"}`} onChange={(e) => setId(e.target.value)} />
        {error && <Banner tone="danger">{error}</Banner>}
        <p className="flex items-center gap-1.5 text-xs text-ink-3"><ShieldCheck size={14} />New hospitals start unverified.</p>
      </div>
    </Dialog>
  );
}
