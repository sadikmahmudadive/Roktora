import { describe, expect, it } from "vitest";
import {
  COOLDOWN_DAYS,
  daysUntilEligible,
  groupTone,
  initials,
  isEligibleNow,
  parseDonorCode,
  publicName,
  stockLabel,
  stockLevel,
  stockTone,
  unitsOf,
  withPart,
} from "./models";
import type { InventoryRow } from "./types";

const row = (group: string, whole: number, target: number): InventoryRow => ({ group, target, parts: { whole, red: 0, plasma: 0, platelets: 0 } });
const DAY = 86_400_000;

describe("stock levels", () => {
  it("follows the share of target on hand", () => {
    expect(stockLevel(row("O−", 4, 15))).toBe("shortage"); // 27%
    expect(stockLevel(row("B+", 36, 60))).toBe("low"); // 60%
    expect(stockLevel(row("A+", 50, 60))).toBe("healthy"); // 83%
  });

  it("treats Rh-negative shortages as danger and other shortages as a warning", () => {
    expect(stockTone(row("O−", 1, 15))).toBe("danger");
    expect(stockTone(row("O+", 1, 15))).toBe("warning");
    expect(stockTone(row("A+", 50, 60))).toBe("success");
    expect(stockLabel(row("B+", 36, 60))).toBe("Low");
  });

  it("adds units across components and never lets one go below zero", () => {
    const r: InventoryRow = { group: "A+", target: 20, parts: { whole: 5, red: 3, plasma: 2, platelets: 1 } };
    expect(unitsOf(r)).toBe(11);
    expect(withPart(r, "whole", -4).parts.whole).toBe(0);
    expect(unitsOf(withPart(r, "red", 9))).toBe(17);
  });

  it("does not divide by a zero target", () => {
    expect(stockLevel(row("A+", 0, 0))).toBe("healthy");
  });
});

describe("blood group colours", () => {
  it("colours negatives red, B/O positives amber, others green", () => {
    expect(groupTone("AB−")).toBe("danger");
    expect(groupTone("O+")).toBe("warning");
    expect(groupTone("B+")).toBe("warning");
    expect(groupTone("A+")).toBe("success");
  });
});

describe("donor names and codes", () => {
  it("shows only first name and last initial", () => {
    expect(publicName("Nusrat Jahan Rahman")).toBe("Nusrat R.");
    expect(publicName("Sadia")).toBe("Sadia");
    expect(publicName("   ")).toBe("Donor");
  });

  it("builds initials", () => {
    expect(initials("Nusrat R.")).toBe("NR");
    expect(initials("Sadia")).toBe("SA");
    expect(initials("")).toBe("?");
  });

  it("accepts a raw donor id or the passport QR text", () => {
    expect(parseDonorCode("  abc123 ")).toBe("abc123");
    expect(parseDonorCode("roktora:checkin:req9:donor42")).toBe("donor42");
  });
});

describe("eligibility cooldown", () => {
  const now = new Date("2026-10-19T12:00:00Z");

  it("rests a donor until the cooldown ends", () => {
    const last = new Date(now.getTime() - 10 * DAY);
    expect(daysUntilEligible(last, now)).toBe(COOLDOWN_DAYS - 10);
    expect(isEligibleNow(true, last, now)).toBe(false);
  });

  it("restores eligibility on its own afterwards", () => {
    const last = new Date(now.getTime() - (COOLDOWN_DAYS + 1) * DAY);
    expect(daysUntilEligible(last, now)).toBe(0);
    expect(isEligibleNow(true, last, now)).toBe(true);
  });

  it("keeps a failed screening ineligible even after the cooldown", () => {
    expect(isEligibleNow(false, new Date(now.getTime() - 400 * DAY), now)).toBe(false);
  });

  it("treats someone who never donated as eligible", () => {
    expect(isEligibleNow(true, null, now)).toBe(true);
  });
});
