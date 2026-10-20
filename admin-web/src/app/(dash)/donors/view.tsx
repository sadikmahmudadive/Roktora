"use client";

import { format } from "date-fns";
import { CheckCircle2, MessageSquare } from "lucide-react";
import { useState } from "react";
import { BloodPill } from "@/components/badges";
import { useStaff } from "@/components/shell";
import { Avatar, Banner, Button, CheckMark, Empty, Page, Panel, PickChip, Spinner, TextArea, cn } from "@/components/ui";
import { sendBulkMessage, useDirectory, useHospital } from "@/lib/store";
import { BLOOD_GROUPS } from "@/lib/types";

export default function DonorsPage() {
  const staff = useStaff();
  const hospital = useHospital(staff.hospitalId).data;
  const dir = useDirectory();
  const [group, setGroup] = useState("All");
  const [eligibleOnly, setEligibleOnly] = useState(false);
  const [selected, setSelected] = useState<Set<string>>(new Set());
  const [composing, setComposing] = useState(false);
  const [body, setBody] = useState("");
  const [sending, setSending] = useState(false);
  const [sent, setSent] = useState<number | null>(null);
  const [error, setError] = useState<string | null>(null);

  const visible = dir.data.filter((d) => (group === "All" || d.group === group) && (!eligibleOnly || d.eligible));

  function toggle(uid: string) {
    setSent(null);
    setSelected((prev) => {
      const next = new Set(prev);
      if (!next.delete(uid)) next.add(uid);
      if (next.size === 0) setComposing(false);
      return next;
    });
  }

  async function send() {
    const uids = [...selected];
    setSending(true);
    setError(null);
    try {
      await sendBulkMessage(hospital?.name || "Your hospital", uids, body.trim());
      setSent(uids.length);
      setSelected(new Set());
      setComposing(false);
      setBody("");
    } catch {
      setError("Couldn't send the message. Check your connection and try again.");
    } finally {
      setSending(false);
    }
  }

  return (
    <Page title="Donor directory" subtitle={`${dir.data.length} registered donor${dir.data.length === 1 ? "" : "s"}`}>
      <div className="mb-4 flex flex-wrap items-center gap-2">
        {["All", ...BLOOD_GROUPS].map((g) => <PickChip key={g} selected={g === group} onClick={() => setGroup(g)}>{g}</PickChip>)}
        <PickChip selected={eligibleOnly} onClick={() => setEligibleOnly((v) => !v)}>Eligible only</PickChip>
      </div>

      {sent !== null && <Banner tone="success" className="mb-3" icon={<CheckCircle2 size={18} />}>Message sent to {sent} donor{sent === 1 ? "" : "s"}. It appears in their Roktora inbox.</Banner>}
      {error && <Banner tone="danger" className="mb-3">{error}</Banner>}

      {selected.size > 0 && (
        <div className="mb-3 rounded-[var(--radius-ctl)] bg-accent-bg p-3" role="region" aria-label="Selected donors">
          <div className="flex items-center gap-2">
            <span className="flex-1 font-semibold text-accent-ink">{selected.size} selected</span>
            <Button variant="outline" size="sm" onClick={() => { setSelected(new Set()); setComposing(false); }}>Clear</Button>
            <Button size="sm" icon={<MessageSquare size={15} />} onClick={() => setComposing(true)}>Message</Button>
          </div>
          {composing && (
            <div className="mt-3">
              <TextArea label="Message" value={body} maxLength={300} onChange={(e) => setBody(e.target.value)} placeholder="e.g. We urgently need O− donors this week. Thank you." />
              <p className="mt-1 text-xs text-ink-2">Sent in the Roktora app only. Donors choose whether to respond.</p>
              <Button className="mt-2.5" disabled={!body.trim() || sending} onClick={() => void send()}>{sending ? "Sending…" : `Send to ${selected.size}`}</Button>
            </div>
          )}
        </div>
      )}

      <Panel flush>
        {dir.loading ? <Spinner /> : dir.error ? <Empty>Couldn&apos;t load donors. Check your connection and that you have staff access.</Empty> : visible.length === 0 ? <Empty>No donors match these filters.</Empty> : (
          <ul>
            {visible.map((d, i) => {
              const on = selected.has(d.uid);
              return (
                <li key={d.uid} className={i ? "border-t border-line" : ""}>
                  <label className={cn("flex cursor-pointer items-center gap-3 px-4 py-2.5", on && "bg-brand-bg")}>
                    <input type="checkbox" className="sr-only" checked={on} onChange={() => toggle(d.uid)} aria-label={`Select ${d.name}`} />
                    <CheckMark checked={on} />
                    <Avatar name={d.name} />
                    <span className="min-w-0 flex-[3]"><span className="block font-semibold">{d.name}</span><span className="block text-xs text-ink-2">{d.area} · {d.donations} donation{d.donations === 1 ? "" : "s"}</span></span>
                    <BloodPill group={d.group} small />
                    <span className="hidden w-20 text-xs text-ink-2 sm:block">{d.lastDonation ? format(d.lastDonation, "d MMM") : "—"}</span>
                    <span className={cn("w-24 text-right text-xs font-semibold", d.eligible ? "text-success-ink" : "text-warning-ink")}>{d.eligible ? "Eligible" : d.daysUntilEligible > 0 ? `In ${d.daysUntilEligible} d` : "Not eligible"}</span>
                  </label>
                </li>
              );
            })}
          </ul>
        )}
      </Panel>
    </Page>
  );
}
