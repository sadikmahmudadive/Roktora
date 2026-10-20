import { defineConfig } from "vitest/config";

// Security-rules tests run against the Firestore emulator (see `npm run test:rules`).
export default defineConfig({
  test: { environment: "node", include: ["rules-tests/**/*.test.ts"], testTimeout: 30_000, hookTimeout: 30_000 },
});
