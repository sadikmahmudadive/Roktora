"use client";

import { format } from "date-fns";
import { AlertTriangle, CheckCircle2, Clock } from "lucide-react";
import { useEffect, useMemo, useState } from "react";
import { BloodPill } from "@/components/badges";
import { useStaff } from "@/components/shell";
import { Avatar, Banner, Button, CheckMark, Empty, Field, Page, Panel, PickChip, cn } from "@/components/ui";
import { MIN_HAEMOGLOBIN, parseDonorCode } from "@/lib/models";
import { completeDonation, donorLookup, startCheckIn, useCheckins, useHospitalRequests } from "@/lib/store";
import { BLOOD_GROUPS, type CheckIn, type DonorEntry } from "@/lib/types";

interface Donor {
  name: string;
  group: string;
  uid: string;
  entry: DonorEntry | null;
}

const CHECKS = ["Photo ID matches the passport name", "Blood pressure within range", "Donor confirmed consent at the desk"];
const BAYS = [1, 2, 3, 4, 5, 6];

/** Desk flow: find the donor, verify on the spot, assign a bay. */
export default function CheckInPage() {
  const staff = useStaff();
  const hid = staff.hospitalId;
  const checkins = useCheckins(hid).data;
  const requests = useHospitalRequests(hid).data;

  const [step, setStep] = useState(0);
  const [donor, setDonor] = useState<Donor | null>(null);
  const [code, setCode] = useState("");
  const [lookupError, setLookupError] = useState<string | null>(null);
  const [walkIn, setWalkIn] = useState("");
  const [walkInGroup, setWalkInGroup] = useState<string>("O+");
  const [checks, setChecks] = useState([false, false, false]);
  const [hb, setHb] = useState("");
  const [bay, setBay] = useState<number | null>(null);
  const [busy, setBusy] = useState(false);
  const [message, setMessage] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);

  const inBays = checkins.filter((c) => c.status === "donating");
  const busyBays = new Set(inBays.map((c) => c.bay).filter((b): b is number => b !== null));

  // Donors who committed to open requests are the likely arrivals.
  const expectedKey = useMemo(() => [...new Set(requests.filter((r) => r.status === "open").flatMap((r) => r.committedUids))].slice(0, 8).join(","), [requests]);
  const [expected, setExpected] = useState<DonorEntry[]>([]);
  useEffect(() => {
    if (!expectedKey) return;
    let cancelled = false;
    donorLookup(expectedKey.split(",")).then((d) => !cancelled && setExpected(d)).catch(() => undefined);
    return () => { cancelled = true; };
  }, [expectedKey]);

  const hbValue = Number.parseFloat(hb.replace(",", "."));
  const verified = checks.every(Boolean) && Number.isFinite(hbValue) && hbValue >= MIN_HAEMOGLOBIN;

  function reset() {
    setStep(0); setDonor(null); setCode(""); setLookupError(null); setWalkIn(""); setChecks([false, false, false]); setHb(""); setBay(null); setMessage(null); setError(null);
  }

  function choose(d: DonorEntry) {
    setDonor({ name: d.name, group: d.group, uid: d.uid, entry: d });
    setStep(1);
  }

  async function findByCode() {
    const uid = parseDonorCode(code);
    if (!uid) return;
    setLookupError(null);
    try {
      const found = await donorLookup([uid]);
      if (found.length === 0) setLookupError("No donor found for that code. Check it, or add them as a walk-in below.");
      else choose(found[0]);
    } catch {
      setLookupError("Couldn't look that donor up. Check your connection and your staff access.");
    }
  }

  async function finish(defer: boolean) {
    if (!donor) return;
    setBusy(true);
    setError(null);
    try {
      await startCheckIn(hid, { donorName: donor.name, group: donor.group, donorUid: donor.uid, status: defer ? "deferred" : "donating", bay: defer ? null : bay });
      setMessage(defer ? `${donor.name} was deferred. No donation recorded.` : `${donor.name} is checked in to bay ${bay}.`);
      setStep(3);
    } catch {
      setError("Couldn't save the check-in. Try again.");
    } finally {
      setBusy(false);
    }
  }

  async function donated(c: CheckIn) {
    try { await completeDonation(hid, c); } catch { setError(`Couldn't record the donation for ${c.donorName}. Try again.`); }
  }

  return (
    <Page title="Donor check-in" subtitle="Find the donor, verify, assign a bay">
      <div className="grid gap-4 lg:grid-cols-[3fr_2fr]">
        <Panel>
          <ol className="mb-5 flex gap-1.5" aria-label="Progress">
            {["Find", "Verify", "Assign bay"].map((label, i) => (
              <li key={label} className="flex-1" aria-current={i === step ? "step" : undefined}>
                <div className={cn("h-1 rounded-full", i <= Math.min(step, 2) ? "bg-brand" : "bg-track")} />
                <div className={cn("mt-2 text-xs", i === step ? "font-semibold text-ink" : "text-ink-3")}>{i + 1}. {label}</div>
              </li>
            ))}
          </ol>

          {error && <Banner tone="danger" className="mb-4">{error}</Banner>}

          {step === 0 && (
            <div className="space-y-5">
              <div>
                <h2 className="text-base font-semibold">Scan or enter the donor&apos;s passport code</h2>
                <p className="mt-1 text-[13px] text-ink-2">Paste the code shown under the donor&apos;s QR, or the full QR text.</p>
                <form className="mt-3 flex gap-2" onSubmit={(e) => { e.preventDefault(); void findByCode(); }}>
                  <input aria-label="Donor code" value={code} onChange={(e) => setCode(e.target.value)} placeholder="Donor ID or roktora:checkin:…" className="min-w-0 flex-1 rounded-[var(--radius-ctl)] border border-line-2 bg-surface-0 px-3.5 py-2.5 text-[15px]" />
                  <Button type="submit" disabled={!code.trim()}>Find</Button>
                </form>
                {lookupError && <Banner tone="warning" className="mt-3" icon={<AlertTriangle size={18} />}>{lookupError}</Banner>}
              </div>

              <div>
                <h3 className="mb-2 font-semibold">Committed donors</h3>
                {expected.length === 0 ? <p className="text-sm text-ink-2">Donors who commit to your requests appear here.</p> : (
                  <div className="flex flex-wrap gap-2">
                    {expected.map((d) => (
                      <button key={d.uid} type="button" onClick={() => choose(d)} className="inline-flex h-10 items-center gap-2 rounded-full border border-line-2 bg-surface-1 pr-4 pl-1.5 text-sm hover:bg-hover">
                        <Avatar name={d.name} size={28} />{d.name} · {d.group}
                      </button>
                    ))}
                  </div>
                )}
              </div>

              <div>
                <h3 className="mb-2 font-semibold">Walk-in donor</h3>
                <Field label="Full name" value={walkIn} onChange={(e) => setWalkIn(e.target.value)} />
                <div className="mt-3 flex flex-wrap gap-2">{BLOOD_GROUPS.map((g) => <PickChip key={g} selected={g === walkInGroup} onClick={() => setWalkInGroup(g)}>{g}</PickChip>)}</div>
                <Button className="mt-3" variant="outline" disabled={walkIn.trim().length < 2} onClick={() => { setDonor({ name: walkIn.trim(), group: walkInGroup, uid: "", entry: null }); setStep(1); }}>Continue as walk-in</Button>
              </div>
            </div>
          )}

          {step === 1 && donor && (
            <div>
              <div className="flex items-center gap-3 rounded-[var(--radius-ctl)] bg-surface-2 p-3.5">
                <Avatar name={donor.name} size={44} />
                <div className="min-w-0 flex-1">
                  <div className="text-base font-semibold">{donor.name}</div>
                  <div className="text-[13px] text-ink-2">
                    {donor.entry ? `${donor.entry.area} · ${donor.entry.donations} donation${donor.entry.donations === 1 ? "" : "s"}${donor.entry.lastDonation ? ` · last ${format(donor.entry.lastDonation, "d MMM yyyy")}` : ""}` : "Walk-in · no Roktora passport"}
                  </div>
                </div>
                <BloodPill group={donor.group} />
              </div>
              {donor.entry && !donor.entry.eligible && (
                <Banner className="mt-3" tone="warning" icon={<Clock size={18} />}>
                  The app says this donor is not eligible yet{donor.entry.daysUntilEligible > 0 ? ` (${donor.entry.daysUntilEligible} more days)` : ""}. Confirm at the desk before continuing.
                </Banner>
              )}

              <h3 className="mt-5 font-semibold">Verify at the desk</h3>
              <ul>
                {CHECKS.map((label, i) => (
                  <li key={label}>
                    <label className="flex cursor-pointer items-center gap-3 py-2.5">
                      <input type="checkbox" className="sr-only" checked={checks[i]} onChange={() => setChecks((c) => c.map((v, j) => (j === i ? !v : v)))} />
                      <CheckMark checked={checks[i]} />
                      <span>{label}</span>
                    </label>
                  </li>
                ))}
              </ul>
              <Field className="mt-2 max-w-60" label="Haemoglobin (g/dL)" inputMode="decimal" placeholder="e.g. 13.2" value={hb} onChange={(e) => setHb(e.target.value)} />
              {Number.isFinite(hbValue) && hbValue < MIN_HAEMOGLOBIN && (
                <Banner className="mt-3" tone="danger" icon={<AlertTriangle size={18} />}>Below {MIN_HAEMOGLOBIN} g/dL. This donor should be deferred.</Banner>
              )}
              <div className="mt-5 flex flex-wrap gap-2">
                <Button variant="outline" onClick={() => setStep(0)}>Back</Button>
                <Button variant="danger" disabled={busy} onClick={() => void finish(true)}>Defer donor</Button>
                <Button disabled={!verified} onClick={() => setStep(2)}>Continue</Button>
              </div>
            </div>
          )}

          {step === 2 && (
            <div>
              <h2 className="mb-3 text-base font-semibold">Assign a bay</h2>
              <div className="grid grid-cols-2 gap-2.5 sm:grid-cols-3">
                {BAYS.map((n) => {
                  const taken = busyBays.has(n);
                  return (
                    <button key={n} type="button" disabled={taken} aria-pressed={bay === n} onClick={() => setBay(n)} className={cn("rounded-[var(--radius-ctl)] border p-3.5 text-left", taken ? "border-line bg-surface-2 text-ink-3" : bay === n ? "border-brand bg-brand-bg ring-1 ring-brand" : "border-line bg-surface-1 hover:bg-hover")}>
                      <div className={cn("font-semibold", bay === n && "text-brand-ink")}>Bay {n}</div>
                      <div className="mt-1 flex items-center gap-1.5 text-xs">
                        <span className={cn("h-2 w-2 rounded-full", taken ? "bg-brand" : "bg-success")} />
                        <span className={taken ? "text-ink-3" : "text-success-ink"}>{taken ? "Donating" : "Free"}</span>
                      </div>
                    </button>
                  );
                })}
              </div>
              <div className="mt-5 flex flex-wrap gap-2">
                <Button variant="outline" onClick={() => setStep(1)}>Back</Button>
                <Button disabled={bay === null || busy} onClick={() => void finish(false)}>{busy ? "Saving…" : "Start donation"}</Button>
              </div>
            </div>
          )}

          {step === 3 && (
            <div>
              <span className="inline-flex h-14 w-14 items-center justify-center rounded-2xl bg-success-bg text-success-ink"><CheckCircle2 size={28} /></span>
              <p className="mt-3.5 text-lg font-semibold">{message}</p>
              <p className="mt-1 text-sm text-ink-2">Mark the donation as done from &quot;In bays now&quot; when the bag is collected.</p>
              <Button className="mt-4" onClick={reset}>Check in another donor</Button>
            </div>
          )}
        </Panel>

        <Panel title={`In bays now · ${inBays.length}`} flush>
          {inBays.length === 0 ? <Empty>No one is donating right now.</Empty> : (
            <ul>
              {inBays.map((c, i) => (
                <li key={c.id} className={cn("flex items-center gap-3 px-4 py-2.5", i > 0 && "border-t border-line")}>
                  <Avatar name={c.donorName} />
                  <span className="min-w-0 flex-1"><span className="block font-semibold">{c.donorName}</span><span className="block text-xs text-ink-2">{c.group} · bay {c.bay ?? "—"} · since {format(c.at, "h:mm a")}</span></span>
                  <Button size="sm" onClick={() => void donated(c)}>Donated</Button>
                </li>
              ))}
            </ul>
          )}
        </Panel>
      </div>
    </Page>
  );
}
