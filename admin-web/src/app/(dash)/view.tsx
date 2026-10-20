"use client";

import { format } from "date-fns";
import { CheckCircle2 } from "lucide-react";
import Link from "next/link";
import { useState } from "react";
import { BloodPill } from "@/components/badges";
import { NewRequestDialog } from "@/components/new-request-dialog";
import { useStaff } from "@/components/shell";
import { Banner, Button, Empty, Grid, Page, Panel, Pill, PickChip, Progress, Avatar, Segmented, Spinner, StatTile, Stepper, TONE_TEXT } from "@/components/ui";
import { sameDay, stockLabel, stockRatio, stockTone, unitsOf } from "@/lib/models";
import { postHospitalRequest, useBatches, useCheckins, useHospital, useHospitalRequests, useInventory } from "@/lib/store";
import { BLOOD_GROUPS, type CheckIn, type InventoryRow, type Urgency } from "@/lib/types";
import { useNow } from "@/lib/use-now";

export default function OverviewPage() {
  const { hospitalId } = useStaff();
  const now = useNow();
  const hospital = useHospital(hospitalId).data;
  const requests = useHospitalRequests(hospitalId).data;
  const inventory = useInventory(hospitalId).data;
  const batches = useBatches(hospitalId).data;
  const checkins = useCheckins(hospitalId).data;

  if (!now) return <Spinner />;

  const open = requests.filter((r) => r.status === "open");
  const critical = open.filter((r) => r.urgency === "critical");
  const today = checkins.filter((c) => sameDay(c.at, now));
  const inBays = checkins.filter((c) => c.status === "donating").length;
  const week = 7 * 86_400_000;
  const done = checkins.filter((c) => c.status === "done");
  const thisWeek = done.filter((c) => now.getTime() - c.at.getTime() <= week).length;
  const lastWeek = done.filter((c) => now.getTime() - c.at.getTime() > week && now.getTime() - c.at.getTime() <= 2 * week).length;
  const weekDelta = lastWeek === 0 ? null : Math.round(((thisWeek - lastWeek) * 100) / lastWeek);
  const expiring = batches.filter((b) => b.expiresAt.getTime() - now.getTime() <= 72 * 3_600_000);
  const tomorrow = expiring.filter((b) => b.expiresAt.getTime() - now.getTime() <= 24 * 3_600_000);
  const queue = checkins.filter((c) => c.status === "waiting" || c.status === "screening" || c.status === "donating");

  return (
    <Page title="Dashboard" subtitle={`${format(now, "EEEE, d MMMM")} · ${hospital?.name || "Your hospital"}`}>
      <Grid cols="grid-cols-1 sm:grid-cols-2 xl:grid-cols-4">
        <StatTile label="Open requests" value={open.length} sub={critical.length ? `${critical.length} critical · ${critical[0].bloodGroup}` : "None critical"} tone={critical.length ? "danger" : undefined} />
        <StatTile label="Checked in today" value={today.length} sub={`${inBays} in bays now`} />
        <StatTile label="Collected this week" value={thisWeek} sub={weekDelta === null ? "No earlier week to compare" : `${weekDelta >= 0 ? "+" : "−"}${Math.abs(weekDelta)}% vs last week`} tone={weekDelta === null ? undefined : weekDelta >= 0 ? "success" : "warning"} />
        <StatTile label="Expiring in 72 h" value={expiring.length} sub={tomorrow.length ? `${tomorrow.length} expiring tomorrow` : "Nothing tomorrow"} tone={expiring.length ? "warning" : undefined} />
      </Grid>

      <div className="mt-4 grid gap-4 lg:grid-cols-[3fr_2fr]">
        <div className="space-y-4">
          <Panel title="Inventory" action={<Link href="/inventory" className="text-sm font-semibold text-accent-ink hover:underline">View all</Link>}>
            {inventory.length === 0 ? <p className="text-sm text-ink-2">No stock recorded yet. Open Inventory to set it up.</p> : (
              <div className="grid grid-cols-2 gap-2.5 sm:grid-cols-4">
                {inventory.map((r) => <StockTile key={r.group} row={r} />)}
              </div>
            )}
          </Panel>
          <Panel title="Open requests" flush action={<Link href="/requests" className="text-sm font-semibold text-accent-ink hover:underline">View all</Link>}>
            {open.length === 0 ? <Empty>No open requests. Use Quick post to ask donors for blood.</Empty> : (
              <ul>
                {open.slice(0, 5).map((r, i) => (
                  <li key={r.id} className={i ? "border-t border-line" : ""}>
                    <Link href={`/requests?id=${r.id}`} className={`flex items-center gap-3 border-l-2 px-4 py-3 hover:bg-hover ${r.urgency === "critical" ? "border-danger" : r.urgency === "urgent" ? "border-warning" : "border-line-2"}`}>
                      <BloodPill group={r.bloodGroup} tone={r.urgency === "critical" ? "danger" : r.urgency === "urgent" ? "warning" : "neutral"} />
                      <span className="min-w-0 flex-1">
                        <span className="block truncate font-semibold">{r.title}</span>
                        <span className="block text-xs text-ink-2">{r.committedUids.length} of {r.bagsNeeded} committed{r.note ? ` · ${r.note}` : ""}</span>
                      </span>
                      <span className={`text-xs font-semibold capitalize ${r.urgency === "critical" ? TONE_TEXT.danger : r.urgency === "urgent" ? TONE_TEXT.warning : TONE_TEXT.neutral}`}>{r.urgency}</span>
                    </Link>
                  </li>
                ))}
              </ul>
            )}
          </Panel>
        </div>
        <div className="space-y-4">
          <Panel title="Today's queue" flush action={<Link href="/checkin" className="text-sm font-semibold text-accent-ink hover:underline">Check in</Link>}>
            {queue.length === 0 ? <Empty>Nobody waiting.</Empty> : <ul>{queue.slice(0, 6).map((c, i) => <QueueRow key={c.id} c={c} first={i === 0} />)}</ul>}
          </Panel>
          <QuickPost />
        </div>
      </div>
    </Page>
  );
}

function StockTile({ row }: { row: InventoryRow }) {
  const tone = stockTone(row);
  return (
    <div className="rounded-[var(--radius-ctl)] border border-line bg-surface-0 p-3">
      <div className="flex items-center">
        <BloodPill group={row.group} row={row} small />
        <span className={`ml-auto text-[11px] font-semibold ${TONE_TEXT[tone]}`}>{stockLabel(row)}</span>
      </div>
      <div className="mt-2.5 font-semibold">{unitsOf(row)} units</div>
      <div className="text-[11px] text-ink-3">target {row.target}</div>
      <Progress className="mt-2" value={stockRatio(row)} tone={tone} />
    </div>
  );
}

const STATUS: Record<string, { label: string; tone: "neutral" | "warning" | "brand" | "success" }> = {
  waiting: { label: "Waiting", tone: "neutral" },
  screening: { label: "Screening", tone: "warning" },
  donating: { label: "Donating", tone: "brand" },
  done: { label: "Done", tone: "success" },
  deferred: { label: "Deferred", tone: "warning" },
};

function QueueRow({ c, first }: { c: CheckIn; first: boolean }) {
  const s = STATUS[c.status];
  return (
    <li className={`flex items-center gap-3 px-4 py-2.5 ${first ? "" : "border-t border-line"}`}>
      <Avatar name={c.donorName} />
      <span className="min-w-0 flex-1">
        <span className="block truncate font-semibold">{c.donorName}</span>
        <span className="block text-xs text-ink-2">{c.group} · {c.bay ? `bay ${c.bay}` : format(c.at, "h:mm a")}</span>
      </span>
      <Pill tone={s.tone} small>{s.label}</Pill>
    </li>
  );
}

/** Post the common case in a few taps; unusual requests go through the Requests page. */
function QuickPost() {
  const staff = useStaff();
  const hospital = useHospital(staff.hospitalId).data;
  const [group, setGroup] = useState<string>("B−");
  const [units, setUnits] = useState(4);
  const [urgency, setUrgency] = useState<Urgency>("urgent");
  const [busy, setBusy] = useState(false);
  const [detailing, setDetailing] = useState(false);
  const [posted, setPosted] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);

  async function post() {
    setBusy(true);
    setError(null);
    try {
      await postHospitalRequest(staff.hospitalId, hospital?.name || "Hospital", staff.uid, { bloodGroup: group, title: `${units} bag${units === 1 ? "" : "s"} of ${group}`, note: "", bagsNeeded: units, urgency, lat: hospital?.lat, lng: hospital?.lng });
      setPosted(`${units} bag${units === 1 ? "" : "s"} of ${group}`);
    } catch {
      setError("Couldn't post the request. Check your connection and try again.");
    } finally {
      setBusy(false);
    }
  }

  return (
    <Panel title="Quick post">
      <div className="flex flex-wrap gap-2">
        {BLOOD_GROUPS.map((g) => <PickChip key={g} selected={g === group} onClick={() => { setGroup(g); setPosted(null); }}>{g}</PickChip>)}
      </div>
      <div className="mt-4 flex items-center justify-between">
        <span className="font-medium">Units needed</span>
        <Stepper label="units" value={units} min={1} max={20} onChange={setUnits} />
      </div>
      <div className="mt-4">
        <Segmented<Urgency> label="Urgency" value={urgency} onChange={setUrgency} options={[["routine", "Routine"], ["urgent", "Urgent"], ["critical", "Critical"]]} />
      </div>
      <div className="mt-4 flex flex-wrap gap-2">
        <Button disabled={busy} onClick={() => void post()}>{busy ? "Posting…" : "Post request"}</Button>
        <Button variant="outline" disabled={busy} onClick={() => setDetailing(true)}>Add details…</Button>
      </div>
      {detailing && <NewRequestDialog open onClose={() => setDetailing(false)} hospitalId={staff.hospitalId} staffUid={staff.uid} draft={{ group, units, urgency }} />}
      {posted && <Banner className="mt-3" tone="success" icon={<CheckCircle2 size={18} />}>Request posted for {posted}. Donors with a matching blood group will see it in the app.</Banner>}
      {error && <Banner className="mt-3" tone="danger">{error}</Banner>}
    </Panel>
  );
}
