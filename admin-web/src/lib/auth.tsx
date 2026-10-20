"use client";

import {
  GoogleAuthProvider,
  createUserWithEmailAndPassword,
  onAuthStateChanged,
  sendEmailVerification,
  sendPasswordResetEmail,
  signInWithEmailAndPassword,
  signInWithPopup,
  signOut as fbSignOut,
  type User,
} from "firebase/auth";
import { doc, getDoc, onSnapshot, serverTimestamp, setDoc, updateDoc, type DocumentData } from "firebase/firestore";
import { createContext, useCallback, useContext, useEffect, useMemo, useState, type ReactNode } from "react";
import { auth, db, isFirebaseConfigured, requireAuth } from "./firebase";
import type { AdminAccess } from "./types";

/** The sign-in record stored at accounts/{uid}. `role` and `hospitalId` are set by an owner in the console. */
export interface AccountRecord {
  role: string;
  hospitalId: string;
}

interface AuthContextValue {
  /** undefined while Firebase is still restoring the session. */
  user: User | null | undefined;
  /** undefined while loading, null if the user is not hospital staff. */
  access: AdminAccess | null | undefined;
  /** The raw account record, to explain to people why they have no access yet. */
  account: AccountRecord | null | undefined;
  /** True once the account record says role "superadmin" (platform team). */
  isSuper: boolean;
  configured: boolean;
  signInEmail: (email: string, password: string) => Promise<void>;
  signUpEmail: (email: string, password: string) => Promise<void>;
  signInGoogle: () => Promise<void>;
  resetPassword: (email: string) => Promise<void>;
  signOut: () => Promise<void>;
}

const AuthContext = createContext<AuthContextValue | null>(null);

/**
 * Makes sure accounts/{uid} exists and records the latest sign-in. New accounts are always role "user";
 * Firestore rules stop the client from ever writing `role` or `hospitalId`.
 */
export async function recordAccount(user: User): Promise<void> {
  if (!db) return;
  const ref = doc(db, "accounts", user.uid);
  const info = {
    email: user.email ?? null,
    phone: user.phoneNumber ?? null,
    displayName: user.displayName ?? null,
    photoURL: user.photoURL ?? null,
    providers: user.providerData.map((p) => p.providerId),
    lastLoginAt: serverTimestamp(),
  };
  const snap = await getDoc(ref);
  if (snap.exists()) await updateDoc(ref, info);
  else await setDoc(ref, { ...info, role: "user", createdAt: serverTimestamp() });
}

function toAccess(uid: string, d: DocumentData | undefined): AdminAccess | null {
  if (!d) return null;
  const role = d.role === "admin" ? "admin" : d.role === "staff" ? "staff" : null;
  const hospitalId = typeof d.hospitalId === "string" ? d.hospitalId.trim() : "";
  if (!role || !hospitalId) return null;
  const name = typeof d.displayName === "string" && d.displayName ? d.displayName : typeof d.email === "string" ? d.email : "Staff";
  return { uid, hospitalId, name, role };
}

export function AuthProvider({ children }: { children: ReactNode }) {
  const [user, setUser] = useState<User | null | undefined>(isFirebaseConfigured ? undefined : null);
  const [state, setState] = useState<{ uid: string; account: AccountRecord | null; access: AdminAccess | null } | null>(null);

  useEffect(() => {
    if (!auth) return;
    return onAuthStateChanged(auth, (u) => {
      setUser(u);
      // Store/refresh the account record on every sign-in. Failure must never block signing in.
      if (u) recordAccount(u).catch((e) => console.warn("Couldn't record the account:", e));
    });
  }, []);

  const uid = user?.uid;
  useEffect(() => {
    if (!db || !uid) return;
    return onSnapshot(
      doc(db, "accounts", uid),
      (snap) => {
        const d = snap.data();
        setState({ uid, account: d ? { role: String(d.role ?? "user"), hospitalId: String(d.hospitalId ?? "") } : null, access: toAccess(uid, d) });
      },
      () => setState({ uid, account: null, access: null }),
    );
  }, [uid]);

  // Derived, so switching accounts never briefly shows the previous account's access.
  const current = user && state?.uid === user.uid ? state : null;
  const access: AdminAccess | null | undefined = !user ? (user === null ? null : undefined) : current ? current.access : undefined;
  const account: AccountRecord | null | undefined = !user ? (user === null ? null : undefined) : current ? current.account : undefined;

  const signInEmail = useCallback(async (email: string, password: string) => {
    await signInWithEmailAndPassword(requireAuth(), email.trim(), password);
  }, []);

  const signUpEmail = useCallback(async (email: string, password: string) => {
    const cred = await createUserWithEmailAndPassword(requireAuth(), email.trim(), password);
    try {
      await sendEmailVerification(cred.user);
    } catch {
      // The verification mail is a courtesy; the account exists either way.
    }
  }, []);

  const signInGoogle = useCallback(async () => {
    const provider = new GoogleAuthProvider();
    provider.setCustomParameters({ prompt: "select_account" });
    await signInWithPopup(requireAuth(), provider);
  }, []);

  const resetPassword = useCallback(async (email: string) => {
    await sendPasswordResetEmail(requireAuth(), email.trim());
  }, []);

  const signOut = useCallback(async () => {
    await fbSignOut(requireAuth());
  }, []);

  const value = useMemo<AuthContextValue>(
    () => ({ user, access, account, isSuper: account?.role === "superadmin", configured: isFirebaseConfigured, signInEmail, signUpEmail, signInGoogle, resetPassword, signOut }),
    [user, access, account, signInEmail, signUpEmail, signInGoogle, resetPassword, signOut],
  );

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>;
}

export function useAuth(): AuthContextValue {
  const ctx = useContext(AuthContext);
  if (!ctx) throw new Error("useAuth must be used inside <AuthProvider>");
  return ctx;
}
