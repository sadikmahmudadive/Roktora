import { getApp, getApps, initializeApp, type FirebaseApp } from "firebase/app";
import { connectAuthEmulator, getAuth, type Auth } from "firebase/auth";
import { connectFirestoreEmulator, getFirestore, type Firestore } from "firebase/firestore";

// Web app config from Firebase console -> Project settings -> Your apps -> Web.
// These values identify the project; they are not secrets. Access is enforced by Firestore rules.
const config = {
  apiKey: process.env.NEXT_PUBLIC_FIREBASE_API_KEY,
  authDomain: process.env.NEXT_PUBLIC_FIREBASE_AUTH_DOMAIN,
  projectId: process.env.NEXT_PUBLIC_FIREBASE_PROJECT_ID,
  storageBucket: process.env.NEXT_PUBLIC_FIREBASE_STORAGE_BUCKET,
  messagingSenderId: process.env.NEXT_PUBLIC_FIREBASE_MESSAGING_SENDER_ID,
  appId: process.env.NEXT_PUBLIC_FIREBASE_APP_ID,
  measurementId: process.env.NEXT_PUBLIC_FIREBASE_MEASUREMENT_ID,
};

/** False until the .env.local values are filled in; the UI then shows a setup notice. */
export const isFirebaseConfigured = Boolean(config.apiKey && config.projectId && config.appId);

let app: FirebaseApp | undefined;
if (isFirebaseConfigured) app = getApps().length ? getApp() : initializeApp(config);

export const auth: Auth | undefined = app ? getAuth(app) : undefined;
export const db: Firestore | undefined = app ? getFirestore(app) : undefined;

// Local development against the Firebase emulators (`npm run seed:emulator`, see the README).
// Never set NEXT_PUBLIC_FIREBASE_EMULATOR in production.
if (auth && db && process.env.NEXT_PUBLIC_FIREBASE_EMULATOR === "true") {
  const g = globalThis as { __roktoraEmulators?: boolean };
  if (!g.__roktoraEmulators) {
    g.__roktoraEmulators = true;
    connectAuthEmulator(auth, "http://127.0.0.1:9099", { disableWarnings: true });
    connectFirestoreEmulator(db, "127.0.0.1", 8080);
  }
}

/** Non-null accessors for code that only runs when configured. */
export function requireDb(): Firestore {
  if (!db) throw new Error("Firebase is not configured. Copy .env.local.example to .env.local and fill it in.");
  return db;
}
export function requireAuth(): Auth {
  if (!auth) throw new Error("Firebase is not configured. Copy .env.local.example to .env.local and fill it in.");
  return auth;
}
