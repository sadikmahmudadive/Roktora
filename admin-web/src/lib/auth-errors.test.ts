import { describe, expect, it } from "vitest";
import { authMessage } from "./auth-errors";

describe("authMessage", () => {
  it("explains wrong credentials without saying which part was wrong", () => {
    for (const code of ["auth/wrong-password", "auth/user-not-found", "auth/invalid-credential"]) {
      expect(authMessage({ code })).toBe("Email or password is incorrect.");
    }
  });

  it("covers sign-up problems", () => {
    expect(authMessage({ code: "auth/email-already-in-use" })).toMatch(/already exists/);
    expect(authMessage({ code: "auth/weak-password" })).toMatch(/at least 6/);
    expect(authMessage({ code: "auth/invalid-email" })).toMatch(/invalid/);
  });

  it("tells people how to fix an unauthorised domain or blocked popup", () => {
    expect(authMessage({ code: "auth/unauthorized-domain" })).toMatch(/Authorized domains/);
    expect(authMessage({ code: "auth/popup-blocked" })).toMatch(/pop-ups/);
  });

  it("stays silent when the user just closed the Google window", () => {
    expect(authMessage({ code: "auth/popup-closed-by-user" })).toBe("");
    expect(authMessage({ code: "auth/cancelled-popup-request" })).toBe("");
  });

  it("falls back for anything unknown", () => {
    expect(authMessage({ code: "auth/something-new" }, "Nope")).toBe("Nope");
    expect(authMessage(new Error("boom"), "Nope")).toBe("Nope");
    expect(authMessage(undefined)).toMatch(/Try again/);
  });
});
