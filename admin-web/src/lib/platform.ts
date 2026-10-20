"use client";

import { collection, doc, onSnapshot, query, setDoc, updateDoc, limit, Timestamp, type DocumentData } from "firebase/firestore";
import { useEffect, useState } from "react";
import { db, requireDb } from "./firebase";
import { toHospital } from "./store";
import type { Hospital } from "./types";

/** Platform-team (superadmin) data: every account and every hospital. */

export type AccountRole = "user" | "staff" | "admin" | "superadmin";

export interface AccountRow {
  uid: string;
  email: string;
  phone: string;
  name: string;
  role: AccountRole;
  hospitalId: string;
  lastLoginAt: Date | null;
}

const ROLES: AccountRole[] = ["user", "staff", "admin", "superadmin"];
const s = (v: unknown) => (typeof v === "string" ? v : "");

export function toAccountRow(uid: string, d: DocumentData): AccountRow {
  return {
    uid,
    email: s(d.email),
    phone: s(d.phone),
    name: s(d.displayName),
    role: ROLES.includes(d.role) ? (d.role as AccountRole) : "user",
    hospitalId: s(d.hospitalId),
    lastLoginAt: d.lastLoginAt instanceof Timestamp ? d.lastLoginAt.toDate() : null,
  };
}

interface Live<T> {
  data: T;
  loading: boolean;
  error: string | null;
}

function useCollection<T>(path: string, map: (id: string, d: DocumentData) => T, enabled: boolean): Live<T[]> {
  const [state, setState] = useState<Live<T[]>>({ data: [], loading: true, error: null });
  useEffect(() => {
    if (!db || !enabled) return;
    return onSnapshot(
      query(collection(db, path), limit(500)),
      (snap) => setState({ data: snap.docs.map((d) => map(d.id, d.data())), loading: false, error: null }),
      (e) => setState({ data: [], loading: false, error: e.message }),
    );
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [path, enabled]);
  return state;
}

export const useAccounts = (enabled: boolean) => useCollection<AccountRow>("accounts", toAccountRow, enabled);
export const useHospitals = (enabled: boolean) => useCollection<Hospital>("hospitals", toHospital, enabled);

/** Links an account to a hospital (or unlinks it with role "user"). Rules forbid touching superadmins. */
export async function setAccountAccess(uid: string, role: Exclude<AccountRole, "superadmin">, hospitalId: string) {
  await updateDoc(doc(requireDb(), "accounts", uid), { role, hospitalId: role === "user" ? "" : hospitalId.trim() });
}

export async function createHospital(id: string, name: string) {
  await setDoc(doc(requireDb(), "hospitals", id), { name: name.trim(), address: "", phone: "", about: "", verified: false });
}

export async function setHospitalVerified(id: string, verified: boolean) {
  await updateDoc(doc(requireDb(), "hospitals", id), { verified });
}
