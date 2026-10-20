"use client";

import { format } from "date-fns";
import { Check, Plus, X } from "lucide-react";
import { useSearchParams } from "next/navigation";
import { Suspense, useEffect, useState } from "react";
import { BloodPill } from "@/components/badges";
import { NewRequestDialog } from "@/components/new-request-dialog";
import { useStaff } from "@/components/shell";
import { Avatar, Banner, Button, Dialog, Empty, IconButton, Page, Panel, Pill, Progress, Segmented, Spinner, cn } from "@/components/ui";
import { useMedia } from "@/lib/use-media";
import { donorLookup, setRequestStatus, useCheckins, useHospitalRequests } from "@/lib/store";
import { type BloodRequest, type CheckIn, type DonorEntry, type Urgency } from "@/lib/types";

export default function RequestsPage() {
  // useSearchParams needs a Suspense boundary under Cache Components.
  return (
    <Suspense fallback={<Spinner />}>
      <Requests />
    </Suspense>
  );
}

const tone = (u: Urgency) => (u === "critical" ? "danger" : u === "urgent" ? "warning" : "neutral");

function Requests() {
  const staff = useStaff();
  const live = useHospitalRequests(staff.hospitalId);
  const params = useSearchParams();
  const [selectedId, setSelectedId] = useState<string | null>(params.get("id"));
  const [closed, setClosed] = useState(false);
  const [creating, setCreating] = useState(false);
  const sideBySide = useMedia("(min-width: 1280px)");

  const all = live.data;
  const open = all.filter((r) => r.status === "open");
  const list = closed ? all.filter((r) => r.status !== "open") : open;
  const selected = all.find((r) => r.id === selectedId) ?? null;

  const detail = selected && <RequestDetail key={selected.id} request={selected} onClose={() => setSelectedId(null)} />;

  return (
    <Page
      title="Requests"
      subtitle={`${open.length} open · ${open.filter((r) => r.urgency === "critical").length} critical`}
      actions={<>
        <Segmented<boolean> label="Status" value={closed} onChange={setClosed} options={[[false, "Open"], [true, "Closed"]]} />
        <Button icon={<Plus size={16} />} onClick={() => setCreating(true)}>New request</Button>
      </>}
    >
      {live.error && <Banner tone="danger" className="mb-4">Couldn&apos;t load requests: {live.error}</Banner>}
      <div className={cn("grid gap-4", sideBySide && "grid-cols-[3fr_2fr]")}>
        <Panel flush>
          {live.loading ? <Spinner /> : list.length === 0 ? (
            <Empty>{closed ? "No closed requests yet." : "No open requests. Post one to ask donors for blood."}</Empty>
          ) : (
            <ul>
              {list.map((r, i) => (
                <li key={r.id} className={i ? "border-t border-line" : ""}>
                  <button type="button" onClick={() => setSelectedId(r.id)} aria-pressed={r.id === selectedId} className={cn("flex w-full items-center gap-3 border-l-2 px-4 py-3.5 text-left hover:bg-hover", r.id === selectedId && "bg-brand-bg", r.urgency === "critical" ? "border-danger" : r.urgency === "urgent" ? "border-warning" : "border-line-2")}>
                    <BloodPill group={r.bloodGroup} tone={tone(r.urgency)} />
                    <span className="min-w-0 flex-[3]">
                      <span className="block truncate font-semibold">{r.title}</span>
                      <span className="block truncate text-xs text-ink-2">{r.note || r.place} · by {format(r.deadline, "d MMM, h:mm a")}</span>
                    </span>
                    <span className="hidden min-w-0 flex-[2] sm:block">
                      <span className="block text-xs text-ink-2">{r.committedUids.length} of {r.bagsNeeded} committed</span>
                      <Progress className="mt-1" value={r.committedUids.length / Math.max(1, r.bagsNeeded)} />
                    </span>
                    <span className="w-16 text-right text-xs font-semibold capitalize text-ink-2">{r.status === "open" ? r.urgency : r.status}</span>
                  </button>
                </li>
              ))}
            </ul>
          )}
        </Panel>

        {sideBySide ? (
          <Panel>{detail ?? <p className="py-10 text-center text-sm text-ink-2">Select a request to see who has committed.</p>}</Panel>
        ) : (
          <Dialog open={!!selected} onClose={() => setSelectedId(null)} title="Request" wide>{detail}</Dialog>
        )}
      </div>

      <NewRequestDialog open={creating} onClose={() => setCreating(false)} hospitalId={staff.hospitalId} staffUid={staff.uid} />
    </Page>
  );
}

function statusOf(donor: DonorEntry, checkins: CheckIn[]) {
  const c = checkins.find((x) => (x.donorUid && x.donorUid === donor.uid) || x.donorName === donor.name);
  switch (c?.status) {
    case "done": return { label: "Donated", tone: "success" as const };
    case "donating": return { label: "Donating", tone: "brand" as const };
    case "screening":
    case "waiting": return { label: "Checked in", tone: "success" as const };
    case "deferred": return { label: "Deferred", tone: "warning" as const };
    default: return { label: "Committed", tone: "neutral" as const };
  }
}

function RequestDetail({ request: r, onClose }: { request: BloodRequest; onClose: () => void }) {
  const staff = useStaff();
  const checkins = useCheckins(staff.hospitalId).data;
  const [donors, setDonors] = useState<DonorEntry[] | null>(r.committedUids.length ? null : []);
  const [failed, setFailed] = useState(false);
  const [busy, setBusy] = useState(false);
  const uidsKey = r.committedUids.join(",");

  useEffect(() => {
    if (!uidsKey) return;
    let cancelled = false;
    donorLookup(uidsKey.split(","))
      .then((d) => !cancelled && setDonors(d))
      .catch(() => !cancelled && (setFailed(true), setDonors([])));
    return () => { cancelled = true; };
  }, [uidsKey]);

  async function change(status: "open" | "fulfilled" | "closed") {
    setBusy(true);
    try { await setRequestStatus(r.id, status); } finally { setBusy(false); }
  }

  return (
    <div>
      <div className="flex items-center gap-2">
        <BloodPill group={r.bloodGroup} tone={tone(r.urgency)} />
        <span className="font-semibold capitalize">{r.status === "open" ? r.urgency : r.status}</span>
        <span className="flex-1" />
        <IconButton label="Close panel" onClick={onClose}><X size={16} /></IconButton>
      </div>
      <h3 className="mt-2 text-2xl font-semibold tracking-tight">{r.title}</h3>
      <p className="mt-1 text-sm text-ink-2">{r.note || r.place}{r.createdAt ? ` · posted ${format(r.createdAt, "d MMM, h:mm a")}` : ""}</p>
      <dl className="mt-4 flex gap-8 text-sm">
        <div><dt className="text-xs text-ink-3">Needed by</dt><dd className="font-semibold">{format(r.deadline, "d MMM, h:mm a")}</dd></div>
        <div><dt className="text-xs text-ink-3">Committed</dt><dd className="font-semibold">{r.committedUids.length} of {r.bagsNeeded}</dd></div>
      </dl>
      <Progress className="mt-3" value={r.committedUids.length / Math.max(1, r.bagsNeeded)} />

      <h4 className="mt-5 mb-2 font-semibold">Committed donors</h4>
      {r.committedUids.length === 0 ? <p className="text-sm text-ink-2">Nobody has committed yet.</p> : donors === null ? <Spinner /> : failed ? (
        <p className="text-sm text-ink-2">{r.committedUids.length} donor(s) committed. Details couldn&apos;t be loaded.</p>
      ) : (
        <ul>
          {donors.map((d, i) => {
            const s = statusOf(d, checkins);
            return (
              <li key={d.uid} className={cn("flex items-center gap-3 py-2.5", i > 0 && "border-t border-line")}>
                <Avatar name={d.name} />
                <span className="min-w-0 flex-1"><span className="block font-semibold">{d.name}</span><span className="block text-xs text-ink-2">{d.group} · {d.area}</span></span>
                <Pill tone={s.tone} small>{s.label}</Pill>
              </li>
            );
          })}
        </ul>
      )}

      <div className="mt-5 flex flex-wrap gap-2">
        {r.status === "open" ? (
          <>
            <Button icon={<Check size={16} />} disabled={busy} onClick={() => void change("fulfilled")}>Mark fulfilled</Button>
            <Button variant="outline" disabled={busy} onClick={() => void change("closed")}>Close request</Button>
          </>
        ) : (
          <Button variant="outline" disabled={busy} onClick={() => void change("open")}>Reopen</Button>
        )}
      </div>
    </div>
  );
}
