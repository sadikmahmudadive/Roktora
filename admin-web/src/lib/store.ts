"use client";

import {
  Timestamp,
  addDoc,
  collection,
  doc,
  getDoc,
  getDocs,
  increment,
  limit,
  onSnapshot,
  orderBy,
  query,
  serverTimestamp,
  setDoc,
  updateDoc,
  where,
  writeBatch,
  type DocumentData,
  type Unsubscribe,
} from "firebase/firestore";
import { useCallback, useEffect, useState } from "react";
import { db, requireDb } from "./firebase";
import { daysUntilEligible, emptyParts, isEligibleNow, publicName } from "./models";
import {
  BLOOD_GROUPS,
  COMPONENT_KEYS,
  type Batch,
  type BloodRequest,
  type CheckIn,
  type CheckInStatus,
  type DonorEntry,
  type Hospital,
  type InventoryRow,
  type RequestStatus,
  type Urgency,
} from "./types";

// ------------------------------------------------------------------ converters

const toDate = (v: unknown): Date | null => (v instanceof Timestamp ? v.toDate() : null);
const str = (v: unknown, fallback = ""): string => (typeof v === "string" ? v : fallback);
const num = (v: unknown, fallback = 0): number => (typeof v === "number" ? v : fallback);

export function toHospital(id: string, d: DocumentData): Hospital {
  const list = <T,>(v: unknown, map: (x: DocumentData) => T): T[] => (Array.isArray(v) ? v.map((x) => map(x as DocumentData)) : []);
  return {
    id,
    name: str(d.name),
    address: str(d.address),
    phone: str(d.phone),
    about: str(d.about),
    lat: typeof d.lat === "number" ? d.lat : null,
    lng: typeof d.lng === "number" ? d.lng : null,
    verified: d.verified === true,
    steps: list(d.steps, (s) => ({ label: str(s.label), when: str(s.when), done: s.done === true })),
    docs: list(d.docs, (s) => ({ name: str(s.name), status: str(s.status), warning: s.warning === true })),
    staff: list(d.staff, (s) => ({ name: str(s.name), role: str(s.role), twoFa: s.twoFa !== false })),
  };
}

export function toInventory(group: string, d: DocumentData): InventoryRow {
  const parts = emptyParts();
  for (const k of COMPONENT_KEYS) parts[k] = num(d[k]);
  return { group, target: num(d.target), parts };
}

export function toBatch(id: string, d: DocumentData): Batch {
  return { id, group: str(d.group), component: str(d.component), expiresAt: toDate(d.expiresAt) ?? new Date(), shelfLifeDays: num(d.shelfLifeDays, 35) };
}

export function toRequest(id: string, d: DocumentData): BloodRequest {
  const urgency = (["critical", "urgent", "routine"] as const).includes(d.urgency) ? (d.urgency as Urgency) : "routine";
  const status = (["open", "fulfilled", "closed"] as const).includes(d.status) ? (d.status as RequestStatus) : "open";
  return {
    id,
    bloodGroup: str(d.bloodGroup),
    title: str(d.title),
    place: str(d.place),
    note: str(d.note),
    postedBy: str(d.postedBy),
    bagsNeeded: num(d.bagsNeeded, 1),
    urgency,
    deadline: toDate(d.deadline) ?? new Date(),
    verified: d.verified === true,
    committedUids: Array.isArray(d.committedUids) ? d.committedUids.map(String) : [],
    status,
    hospitalId: str(d.hospitalId),
    createdAt: toDate(d.createdAt),
    fulfilledAt: toDate(d.fulfilledAt),
  };
}

export function toCheckIn(id: string, d: DocumentData): CheckIn {
  const valid: CheckInStatus[] = ["waiting", "screening", "donating", "done", "deferred"];
  return {
    id,
    donorName: str(d.donorName),
    group: str(d.group),
    status: valid.includes(d.status) ? (d.status as CheckInStatus) : "waiting",
    at: toDate(d.at) ?? new Date(),
    donorUid: str(d.donorUid),
    bay: typeof d.bay === "number" ? d.bay : null,
    requestId: str(d.requestId),
  };
}

function toDonor(uid: string, d: DocumentData, now: Date): DonorEntry {
  const last = toDate(d.lastDonation);
  const screeningOk = d.eligible !== false;
  return {
    uid,
    name: publicName(str(d.name, "Donor")),
    group: str(d.bloodGroup, "?"),
    area: str(d.area),
    donations: num(d.donations),
    lastDonation: last,
    eligible: isEligibleNow(screeningOk, last, now),
    daysUntilEligible: daysUntilEligible(last, now),
  };
}

// ------------------------------------------------------------------ live hooks

interface Live<T> {
  data: T;
  loading: boolean;
  error: string | null;
}

/** Subscribes to a Firestore source and exposes { data, loading, error }. */
function useLive<T>(initial: T, subscribe: ((emit: (v: T) => void, fail: (e: Error) => void) => Unsubscribe) | null, deps: unknown[]): Live<T> {
  const [state, setState] = useState<Live<T>>({ data: initial, loading: true, error: null });
  useEffect(() => {
    if (!subscribe) return;
    return subscribe(
      (data) => setState({ data, loading: false, error: null }),
      (e) => setState((s) => ({ ...s, loading: false, error: e.message })),
    );
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, deps);
  return state;
}

export function useHospital(hid: string | undefined) {
  return useLive<Hospital | null>(null, hid && db ? (emit, fail) => onSnapshot(doc(db!, "hospitals", hid), (s) => emit(s.exists() ? toHospital(s.id, s.data()) : null), fail) : null, [hid]);
}

export function useInventory(hid: string | undefined) {
  return useLive<InventoryRow[]>(
    [],
    hid && db
      ? (emit, fail) =>
          onSnapshot(
            collection(db!, "hospitals", hid, "inventory"),
            (s) => {
              const rows = s.docs.map((d) => toInventory(d.id, d.data()));
              rows.sort((a, b) => BLOOD_GROUPS.indexOf(a.group as never) - BLOOD_GROUPS.indexOf(b.group as never));
              emit(rows);
            },
            fail,
          )
      : null,
    [hid],
  );
}

export function useBatches(hid: string | undefined) {
  return useLive<Batch[]>(
    [],
    hid && db ? (emit, fail) => onSnapshot(query(collection(db!, "hospitals", hid, "batches"), orderBy("expiresAt"), limit(60)), (s) => emit(s.docs.map((d) => toBatch(d.id, d.data()))), fail) : null,
    [hid],
  );
}

export function useHospitalRequests(hid: string | undefined) {
  return useLive<BloodRequest[]>(
    [],
    hid && db
      ? (emit, fail) =>
          onSnapshot(
            query(collection(db!, "requests"), where("hospitalId", "==", hid)),
            (s) => emit(s.docs.map((d) => toRequest(d.id, d.data())).sort((a, b) => a.deadline.getTime() - b.deadline.getTime())),
            fail,
          )
      : null,
    [hid],
  );
}

export function useCheckins(hid: string | undefined) {
  return useLive<CheckIn[]>(
    [],
    hid && db ? (emit, fail) => onSnapshot(query(collection(db!, "hospitals", hid, "checkins"), orderBy("at", "desc"), limit(500)), (s) => emit(s.docs.map((d) => toCheckIn(d.id, d.data()))), fail) : null,
    [hid],
  );
}

/** One-off fetch of the donor directory (first names + initial only). */
export function useDirectory(): Live<DonorEntry[]> & { reload: () => void } {
  const [tick, setTick] = useState(0);
  const [state, setState] = useState<Live<DonorEntry[]>>({ data: [], loading: true, error: null });
  useEffect(() => {
    let cancelled = false;
    if (!db) return;
    getDocs(query(collection(db, "users"), limit(300)))
      .then((snap) => {
        if (cancelled) return;
        const now = new Date();
        const list = snap.docs.map((d) => toDonor(d.id, d.data(), now)).sort((a, b) => a.name.localeCompare(b.name));
        setState({ data: list, loading: false, error: null });
      })
      .catch((e: Error) => !cancelled && setState({ data: [], loading: false, error: e.message }));
    return () => {
      cancelled = true;
    };
  }, [tick]);
  const reload = useCallback(() => setTick((t) => t + 1), []);
  return { ...state, reload };
}

// ------------------------------------------------------------------ actions

export async function seedInventory(hid: string) {
  const batch = writeBatch(requireDb());
  for (const g of BLOOD_GROUPS) {
    batch.set(doc(requireDb(), "hospitals", hid, "inventory", g), { target: g.includes("−") ? 12 : 40, whole: 0, red: 0, plasma: 0, platelets: 0 }, { merge: true });
  }
  await batch.commit();
}

export async function setStock(hid: string, group: string, key: (typeof COMPONENT_KEYS)[number], units: number) {
  await setDoc(doc(requireDb(), "hospitals", hid, "inventory", group), { [key]: Math.max(0, Math.round(units)) }, { merge: true });
}

export async function addBatch(hid: string, b: Batch) {
  await setDoc(doc(requireDb(), "hospitals", hid, "batches", b.id), {
    group: b.group,
    component: b.component,
    expiresAt: Timestamp.fromDate(b.expiresAt),
    shelfLifeDays: b.shelfLifeDays,
  });
}

export interface NewRequest {
  bloodGroup: string;
  title: string;
  note: string;
  bagsNeeded: number;
  urgency: Urgency;
  /** When the blood is needed by; defaults from the urgency. */
  deadline?: Date;
  /** Where donors should go; defaults to the hospital's name. */
  place?: string;
  lat?: number | null;
  lng?: number | null;
}

const URGENCY_HOURS: Record<Urgency, number> = { critical: 6, urgent: 24, routine: 72 };

export async function postHospitalRequest(hid: string, hospitalName: string, staffUid: string, r: NewRequest) {
  await addDoc(collection(requireDb(), "requests"), {
    bloodGroup: r.bloodGroup,
    title: r.title,
    place: r.place || hospitalName,
    note: r.note,
    distanceKm: 0,
    bagsNeeded: r.bagsNeeded,
    urgency: r.urgency,
    deadline: r.deadline ? Timestamp.fromDate(r.deadline) : Timestamp.fromMillis(Date.now() + URGENCY_HOURS[r.urgency] * 3_600_000),
    ...(typeof r.lat === "number" && typeof r.lng === "number" ? { lat: r.lat, lng: r.lng } : {}),
    verified: true,
    postedBy: hospitalName,
    committedUids: [],
    status: "open",
    hospitalId: hid,
    createdBy: staffUid,
    createdAt: serverTimestamp(),
  });
}

export async function setRequestStatus(id: string, status: RequestStatus) {
  await updateDoc(doc(requireDb(), "requests", id), { status, ...(status === "fulfilled" ? { fulfilledAt: serverTimestamp() } : {}) });
}

export async function donorLookup(uids: string[]): Promise<DonorEntry[]> {
  const now = new Date();
  const out: DonorEntry[] = [];
  for (const uid of uids) {
    const s = await getDoc(doc(requireDb(), "users", uid));
    if (s.exists()) out.push(toDonor(uid, s.data(), now));
  }
  return out;
}

export async function startCheckIn(hid: string, c: { donorName: string; group: string; donorUid?: string; requestId?: string; status: CheckInStatus; bay?: number | null }) {
  const ref = await addDoc(collection(requireDb(), "hospitals", hid, "checkins"), {
    donorName: c.donorName,
    group: c.group,
    status: c.status,
    at: Timestamp.now(),
    donorUid: c.donorUid ?? "",
    requestId: c.requestId ?? "",
    ...(c.bay != null ? { bay: c.bay } : {}),
  });
  return ref.id;
}

/** Marks the donation done: logs it for the donor, rests them, and adds a unit of whole blood to stock. */
export async function completeDonation(hid: string, c: CheckIn) {
  const d = requireDb();
  const batch = writeBatch(d);
  batch.update(doc(d, "hospitals", hid, "checkins", c.id), { status: "done" });
  batch.set(doc(d, "hospitals", hid, "inventory", c.group), { whole: increment(1) }, { merge: true });
  if (c.donorUid) {
    const hospital = await getDoc(doc(d, "hospitals", hid));
    const place = str(hospital.data()?.name, "Hospital");
    batch.set(doc(collection(d, "users", c.donorUid, "donations")), { date: Timestamp.now(), place, note: "Whole blood", status: "donated" });
    batch.update(doc(d, "users", c.donorUid), { donations: increment(1), lastDonation: Timestamp.now() });
    batch.update(doc(d, "donors", c.donorUid), { donations: increment(1), available: false });
  }
  await batch.commit();
}

export async function sendBulkMessage(hospitalName: string, uids: string[], body: string) {
  const d = requireDb();
  for (let i = 0; i < uids.length; i += 400) {
    const batch = writeBatch(d);
    for (const uid of uids.slice(i, i + 400)) {
      batch.set(doc(collection(d, "users", uid, "inbox")), { title: `Message from ${hospitalName}`, body, from: hospitalName, at: Timestamp.now(), read: false });
    }
    await batch.commit();
  }
}

export async function saveHospital(h: Pick<Hospital, "id" | "name" | "address" | "phone" | "about" | "lat" | "lng">) {
  const place = typeof h.lat === "number" && typeof h.lng === "number" ? { lat: h.lat, lng: h.lng } : {};
  await setDoc(doc(requireDb(), "hospitals", h.id), { name: h.name, address: h.address, phone: h.phone, about: h.about, ...place }, { merge: true });
}

// ------------------------------------------------------------------ request chat

export interface ChatMsg {
  id: string;
  fromUid: string;
  senderName: string;
  text: string;
  sentAt: Date | null;
  /** Set for a shared location. */
  lat: number | null;
  lng: number | null;
  pending: boolean;
}

export function toChatMsg(id: string, d: DocumentData, pending: boolean): ChatMsg {
  const loc = d.kind === "location";
  return {
    id,
    fromUid: str(d.fromUid),
    senderName: str(d.senderName),
    text: str(d.text),
    sentAt: toDate(d.sentAt),
    lat: loc && typeof d.lat === "number" ? d.lat : null,
    lng: loc && typeof d.lng === "number" ? d.lng : null,
    pending,
  };
}

/** Live chat for one request (the requester, committed donors and the hospital's staff can read it). */
export function useMessages(requestId: string | undefined) {
  return useLive<ChatMsg[]>(
    [],
    requestId && db
      ? (emit, fail) =>
          onSnapshot(
            query(collection(db!, "requests", requestId, "messages"), orderBy("sentAt")),
            { includeMetadataChanges: true },
            (s) => emit(s.docs.map((d) => toChatMsg(d.id, d.data({ serverTimestamps: "estimate" }), d.metadata.hasPendingWrites))),
            fail,
          )
      : null,
    [requestId],
  );
}

export async function sendChatMessage(requestId: string, fromUid: string, senderName: string, text: string) {
  await addDoc(collection(requireDb(), "requests", requestId, "messages"), {
    fromUid,
    senderName: senderName.slice(0, 60),
    text: text.slice(0, 1000),
    sentAt: serverTimestamp(),
  });
}
