// Runs `next dev` pointed at the local Firebase emulators with throwaway project settings.
// Nothing here touches your real Firebase project.
import { spawn } from "node:child_process";

const port = process.env.PORT ?? "3000";
const child = spawn("npx", ["next", "dev", "-p", port], {
  stdio: "inherit",
  shell: true,
  env: {
    ...process.env,
    NEXT_PUBLIC_FIREBASE_EMULATOR: "true",
    NEXT_PUBLIC_FIREBASE_API_KEY: "demo-key",
    NEXT_PUBLIC_FIREBASE_AUTH_DOMAIN: "demo-roktora.firebaseapp.com",
    NEXT_PUBLIC_FIREBASE_PROJECT_ID: "demo-roktora",
    NEXT_PUBLIC_FIREBASE_APP_ID: "1:0:web:demo",
  },
});
child.on("exit", (code) => process.exit(code ?? 0));
