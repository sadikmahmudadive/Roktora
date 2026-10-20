"use client";

import { Building2, Check, CheckCircle2 } from "lucide-react";
import { useState } from "react";
import { AddressPicker } from "@/components/address-picker";
import { VerifiedBadge } from "@/components/badges";
import { Avatar, Banner, Button, Empty, Field, Page, Panel, Pill, Spinner, TextArea, cn } from "@/components/ui";
import { useStaff } from "@/components/shell";
import { saveHospital, useHospital } from "@/lib/store";
import type { Hospital } from "@/lib/types";

export default function ProfilePage() {
  const staff = useStaff();
  const live = useHospital(staff.hospitalId);
  if (live.loading) return <Spinner />;
  if (!live.data) {
    if (staff.role === "admin") {
      // First visit: the hospital admin fills in the details and saving creates the (unverified) record.
      const blank: Hospital = { id: staff.hospitalId, name: "", address: "", phone: "", about: "", verified: false, steps: [], docs: [], staff: [] };
      return <ProfileForm key={blank.id} hospital={blank} canEdit isNew />;
    }
    return (
      <Page title="Hospital profile" subtitle="Public details and verification">
        <Banner tone="warning">
          This hospital has no profile yet. A hospital admin needs to fill it in.
        </Banner>
      </Page>
    );
  }
  // Remount the form when the hospital changes so its fields reset from the new data.
  return <ProfileForm key={live.data.id} hospital={live.data} canEdit={staff.role === "admin"} />;
}

function ProfileForm({ hospital: h, canEdit, isNew }: { hospital: Hospital; canEdit: boolean; isNew?: boolean }) {
  const [name, setName] = useState(h.name);
  const [address, setAddress] = useState(h.address);
  const [phone, setPhone] = useState(h.phone);
  const [about, setAbout] = useState(h.about);
  const [pin, setPin] = useState<{ lat: number; lng: number } | null>(typeof h.lat === "number" && typeof h.lng === "number" ? { lat: h.lat, lng: h.lng } : null);
  const [busy, setBusy] = useState(false);
  const [saved, setSaved] = useState(false);
  const [error, setError] = useState<string | null>(null);

  async function save() {
    setBusy(true);
    setSaved(false);
    setError(null);
    try {
      await saveHospital({ id: h.id, name: name.trim(), address: address.trim(), phone: phone.trim(), about: about.trim(), lat: pin?.lat, lng: pin?.lng });
      setSaved(true);
    } catch {
      setError("Couldn't save. Check your connection and that you're a hospital admin.");
    } finally {
      setBusy(false);
    }
  }

  return (
    <Page title="Hospital profile" subtitle="Public details and verification">
      {isNew && <Banner className="mb-4" tone="accent">Set up your hospital: add its details below and save. A Roktora superadmin verifies it afterwards.</Banner>}
      <div className="grid gap-4 lg:grid-cols-[3fr_2fr]">
        <div className="space-y-4">
          <Panel title="Public details">
            <div className="mb-5 flex items-center gap-3.5">
              <span className="flex h-[52px] w-[52px] items-center justify-center rounded-[18px] bg-surface-2 text-ink-2"><Building2 size={26} /></span>
              <div>
                <div className="text-[22px] font-semibold tracking-tight">{h.name || "Unnamed hospital"}</div>
                {h.verified ? <VerifiedBadge /> : <span className="text-sm text-ink-3">Not verified yet</span>}
              </div>
            </div>
            <div className="space-y-3">
              <Field label="Hospital name" value={name} disabled={!canEdit} onChange={(e) => { setName(e.target.value); setSaved(false); }} />
              <Field label="Address" value={address} disabled={!canEdit} onChange={(e) => { setAddress(e.target.value); setSaved(false); }} />
              <AddressPicker
                lat={h.lat}
                lng={h.lng}
                disabled={!canEdit}
                onPick={(p) => {
                  if (p.address) setAddress(p.address);
                  setPin({ lat: p.lat, lng: p.lng });
                  setSaved(false);
                }}
              />
              <Field label="Blood bank phone" type="tel" value={phone} disabled={!canEdit} onChange={(e) => { setPhone(e.target.value); setSaved(false); }} />
              <TextArea label="About" value={about} disabled={!canEdit} rows={4} onChange={(e) => { setAbout(e.target.value); setSaved(false); }} />
            </div>
            {error && <Banner className="mt-3" tone="danger">{error}</Banner>}
            {canEdit ? (
              <div className="mt-4 flex items-center gap-3">
                <Button disabled={busy || name.trim().length < 2} onClick={() => void save()}>{busy ? "Saving…" : "Save changes"}</Button>
                {saved && <span className="inline-flex items-center gap-1.5 text-sm font-semibold text-success-ink" role="status"><CheckCircle2 size={17} />Saved</span>}
              </div>
            ) : <p className="mt-4 text-xs text-ink-3">Only admins can edit these details.</p>}
          </Panel>

          <Panel title="Staff" flush>
            {h.staff.length === 0 ? <Empty>No staff listed.</Empty> : (
              <ul>
                {h.staff.map((s, i) => (
                  <li key={s.name + i} className={cn("flex items-center gap-3 px-4 py-3", i > 0 && "border-t border-line")}>
                    <Avatar name={s.name} />
                    <span className="min-w-0 flex-1"><span className="block font-semibold">{s.name}</span><span className="block text-xs text-ink-2">{s.role}</span></span>
                    {s.twoFa && <Pill tone="success" small>2FA on</Pill>}
                  </li>
                ))}
              </ul>
            )}
          </Panel>
        </div>

        <div className="space-y-4">
          <Panel title="Verification">
            {h.steps.length === 0 ? <p className="text-sm text-ink-2">Verification steps will appear here.</p> : (
              <ol>
                {h.steps.map((s, i) => (
                  <li key={s.label} className="flex gap-3">
                    <div className="flex flex-col items-center">
                      <span className={cn("flex h-[22px] w-[22px] items-center justify-center rounded-full", s.done ? "bg-brand text-on-fill" : "border border-line-3")}>{s.done && <Check size={13} strokeWidth={3} />}</span>
                      {i < h.steps.length - 1 && <span className="w-0.5 flex-1 bg-accent/40" />}
                    </div>
                    <div className="pb-4"><div className="font-semibold">{s.label}</div><div className={cn("text-xs", s.done ? "text-ink-3" : "text-warning-ink")}>{s.when}</div></div>
                  </li>
                ))}
              </ol>
            )}
          </Panel>
          <Panel title="Documents" flush>
            {h.docs.length === 0 ? <Empty>No documents on file.</Empty> : (
              <ul>
                {h.docs.map((d, i) => (
                  <li key={d.name} className={cn("flex items-center gap-3 px-4 py-3", i > 0 && "border-t border-line")}>
                    <span className="flex-1 font-medium">{d.name}</span>
                    <Pill tone={d.warning ? "warning" : "success"} small>{d.status}</Pill>
                  </li>
                ))}
              </ul>
            )}
          </Panel>
        </div>
      </div>
    </Page>
  );
}
