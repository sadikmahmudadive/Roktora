"use client";

import { MapPin } from "lucide-react";
import { useState } from "react";
import { postHospitalRequest, useHospital } from "@/lib/store";
import { BLOOD_GROUPS, type Urgency } from "@/lib/types";
import { AddressPicker } from "./address-picker";
import { Banner, Button, Dialog, Field, PickChip, Segmented, Stepper } from "./ui";

export interface RequestDraft {
  group: string;
  units: number;
  urgency: Urgency;
}

/**
 * The full "new blood request" form: what it is for, group and units, urgency, when it is needed by and
 * where donors should go (the hospital by default, or any point picked on Google Maps).
 */
export function NewRequestDialog({ open, onClose, hospitalId, staffUid, draft }: { open: boolean; onClose: () => void; hospitalId: string; staffUid: string; draft?: RequestDraft }) {
  const hospital = useHospital(hospitalId).data;
  const hospitalName = hospital?.name || "Hospital";
  const [title, setTitle] = useState("");
  const [note, setNote] = useState("");
  const [group, setGroup] = useState<string>(draft?.group ?? "O−");
  const [units, setUnits] = useState(draft?.units ?? 2);
  const [urgency, setUrgency] = useState<Urgency>(draft?.urgency ?? "urgent");
  const [neededBy, setNeededBy] = useState("");
  const [custom, setCustom] = useState<{ place: string; lat: number; lng: number } | null>(null);
  const [mapOpen, setMapOpen] = useState(false);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const deadline = neededBy ? new Date(neededBy) : null;
  const deadlineBad = deadline !== null && (Number.isNaN(deadline.getTime()) || deadline.getTime() <= new Date().getTime());
  const valid = title.trim().length > 3 && !deadlineBad;
  const hasHospitalPin = typeof hospital?.lat === "number" && typeof hospital?.lng === "number";

  async function submit() {
    setBusy(true);
    setError(null);
    try {
      await postHospitalRequest(hospitalId, hospitalName, staffUid, {
        bloodGroup: group,
        title: title.trim(),
        note: note.trim(),
        bagsNeeded: units,
        urgency,
        deadline: deadline ?? undefined,
        place: custom?.place || hospitalName,
        lat: custom?.lat ?? hospital?.lat ?? null,
        lng: custom?.lng ?? hospital?.lng ?? null,
      });
      setTitle("");
      setNote("");
      setNeededBy("");
      setCustom(null);
      onClose();
    } catch {
      setError("Couldn't post the request. Check your connection and try again.");
    } finally {
      setBusy(false);
    }
  }

  return (
    <Dialog
      open={open}
      onClose={onClose}
      title="New blood request"
      wide
      footer={
        <>
          <Button variant="outline" onClick={onClose}>Cancel</Button>
          <Button disabled={!valid || busy} onClick={() => void submit()}>{busy ? "Posting…" : "Post request"}</Button>
        </>
      }
    >
      <div className="space-y-3">
        <Field label="What is it for?" value={title} onChange={(e) => setTitle(e.target.value)} placeholder="e.g. 3 bags for cardiac surgery" />
        <Field label="Ward or department (optional)" value={note} onChange={(e) => setNote(e.target.value)} />
        <div>
          <p className="mb-2 text-[13px] font-semibold">Blood group</p>
          <div className="flex flex-wrap gap-2">{BLOOD_GROUPS.map((g) => <PickChip key={g} selected={g === group} onClick={() => setGroup(g)}>{g}</PickChip>)}</div>
        </div>
        <div className="flex items-center justify-between"><span className="text-[13px] font-semibold">Units needed</span><Stepper label="units" value={units} min={1} max={30} onChange={setUnits} /></div>
        <Segmented<Urgency> label="Urgency" value={urgency} onChange={setUrgency} options={[["routine", "Routine"], ["urgent", "Urgent"], ["critical", "Critical"]]} />
        <Field
          label="Needed by (optional)"
          type="datetime-local"
          value={neededBy}
          onChange={(e) => setNeededBy(e.target.value)}
          hint={deadlineBad ? "Pick a time in the future." : "Leave empty to use the urgency default: critical 6 h, urgent 24 h, routine 72 h."}
        />
        <div>
          <p className="mb-1.5 text-[13px] font-semibold">Where donors should go</p>
          <div className="flex items-center gap-2 rounded-[var(--radius-ctl)] bg-surface-2 p-3">
            <MapPin size={16} className="shrink-0 text-ink-2" />
            <span className="min-w-0 flex-1 truncate text-sm">{custom?.place || (hasHospitalPin ? `${hospitalName} (saved hospital location)` : hospitalName)}</span>
            <Button variant="outline" size="sm" onClick={() => setMapOpen((v) => !v)}>{mapOpen ? "Hide map" : "Change on map"}</Button>
          </div>
          {!hasHospitalPin && !custom && <p className="mt-1 text-xs text-ink-3">No pin yet: donors won&apos;t see this on the map. Set your hospital location in Hospital profile, or pick a point here.</p>}
          {mapOpen && (
            <div className="mt-2">
              <AddressPicker lat={custom?.lat ?? hospital?.lat} lng={custom?.lng ?? hospital?.lng} onPick={(p) => setCustom({ place: p.address || hospitalName, lat: p.lat, lng: p.lng })} />
            </div>
          )}
        </div>
        {error && <Banner tone="danger">{error}</Banner>}
      </div>
    </Dialog>
  );
}
