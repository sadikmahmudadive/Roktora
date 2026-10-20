import { describe, expect, it } from "vitest";
import { buildReport } from "./report";
import type { BloodRequest, CheckIn } from "./types";

const now = new Date(2026, 9, 19, 12);
const DAY = 86_400_000;
const HOUR = 3_600_000;

const checkin = (daysAgo: number, group = "O+", status: CheckIn["status"] = "done"): CheckIn => ({
  id: `${daysAgo}${group}${status}`,
  donorName: "D",
  group,
  status,
  at: new Date(now.getTime() - daysAgo * DAY),
  donorUid: "",
  bay: null,
  requestId: "",
});

const request = (id: string, status: BloodRequest["status"], fillMs: number | null): BloodRequest => ({
  id,
  bloodGroup: "O+",
  title: "t",
  place: "p",
  note: "",
  postedBy: "",
  bagsNeeded: 1,
  urgency: "urgent",
  deadline: now,
  verified: true,
  committedUids: [],
  status,
  hospitalId: "h",
  createdAt: new Date(now.getTime() - DAY),
  fulfilledAt: fillMs === null ? null : new Date(now.getTime() - DAY + fillMs),
});

describe("buildReport", () => {
  it("counts completed donations in 7-day windows ending today", () => {
    const r = buildReport({ checkins: [checkin(0), checkin(1), checkin(2), checkin(9), checkin(10, "B+")], requests: [], period: "weekly", now });
    expect(r.values).toHaveLength(12);
    expect(r.values.at(-1)).toBe(3); // today, yesterday, two days ago
    expect(r.values[10]).toBe(2); // the week before
    expect(r.total).toBe(5);
    expect(r.byGroup[0]).toEqual(["O+", 4]);
  });

  it("does not count deferred or waiting check-ins as collections", () => {
    const r = buildReport({ checkins: [checkin(0), checkin(0, "O+", "deferred"), checkin(0, "O+", "waiting")], requests: [], period: "weekly", now });
    expect(r.values.at(-1)).toBe(1);
    // One donated and one deferred were screened: 50% deferral.
    expect(r.kpis.find((k) => k.label === "Deferral rate")?.value).toBe("50%");
  });

  it("derives fulfilment rate and median time to fill from closed requests", () => {
    const r = buildReport({
      checkins: [],
      requests: [request("a", "fulfilled", 2 * HOUR), request("b", "fulfilled", 4 * HOUR), request("c", "fulfilled", 6 * HOUR), request("d", "closed", null), request("e", "open", null)],
      period: "weekly",
      now,
    });
    expect(r.kpis.find((k) => k.label === "Requests fulfilled")?.value).toBe("75%"); // 3 of 4 closed
    expect(r.kpis.find((k) => k.label === "Median time to fill")?.value).toBe("4 h 0 m");
  });

  it("shows a dash instead of zero when there is nothing to measure", () => {
    const r = buildReport({ checkins: [], requests: [], period: "monthly", now });
    expect(r.total).toBe(0);
    expect(r.max).toBe(1);
    expect(r.kpis.find((k) => k.label === "Requests fulfilled")?.value).toBe("—");
    expect(r.rangeLabel).toBe("Last 12 months");
  });

  it("labels months in order, ending with the current one", () => {
    const r = buildReport({ checkins: [], requests: [], period: "monthly", now });
    expect(r.labels).toHaveLength(12);
    expect(r.labels.at(-1)).toBe("Oct");
    expect(r.labels[0]).toBe("Nov");
  });

  it("reports the change against the previous period", () => {
    const r = buildReport({ checkins: [checkin(0), checkin(1), checkin(8), checkin(9)], requests: [], period: "weekly", now });
    const k = r.kpis[0];
    expect(k.value).toBe("2");
    expect(k.sub).toBe("+0% vs last week");
    expect(k.positive).toBe(true);
  });
});
