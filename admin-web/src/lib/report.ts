import type { BloodRequest, CheckIn, ReportData, ReportPeriod } from "./types";

const MONTHS = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
const DAY = 86_400_000;

function isoWeek(d: Date): number {
  const start = new Date(d.getFullYear(), 0, 1);
  const dayOfYear = Math.floor((d.getTime() - start.getTime()) / DAY) + 1;
  const weekday = d.getDay() === 0 ? 7 : d.getDay();
  return Math.min(53, Math.max(1, Math.floor((dayOfYear - weekday + 10) / 7)));
}

function duration(ms: number): string {
  const h = Math.floor(ms / 3_600_000);
  const m = Math.floor((ms % 3_600_000) / 60_000);
  return h > 0 ? `${h} h ${m} m` : `${m} m`;
}

/**
 * Aggregates check-ins and requests for the Reports page: 12 weekly or monthly buckets,
 * KPIs and a blood-group breakdown. Aggregate only, never per donor.
 */
export function buildReport(args: {
  checkins: CheckIn[];
  requests: BloodRequest[];
  period: ReportPeriod;
  now?: Date;
}): ReportData {
  const { checkins, requests, period } = args;
  const today = args.now ?? new Date();
  const weekly = period === "weekly";
  const n = 12;

  const midnight = new Date(today.getFullYear(), today.getMonth(), today.getDate());
  const start = (i: number) =>
    weekly ? new Date(midnight.getTime() - 7 * (n - i) * DAY) : new Date(today.getFullYear(), today.getMonth() - (n - 1 - i), 1);
  const end = (i: number) => (i === n - 1 ? new Date(today.getTime() + DAY) : start(i + 1));

  const labels = Array.from({ length: n }, (_, i) => (weekly ? `W${isoWeek(start(i))}` : MONTHS[start(i).getMonth()]));

  const done = checkins.filter((c) => c.status === "done");
  const values = Array.from({ length: n }, (_, i) => done.filter((c) => c.at >= start(i) && c.at < end(i)).length);

  const inRange = done.filter((c) => c.at >= start(0));
  const groups = new Map<string, number>();
  for (const c of inRange) groups.set(c.group, (groups.get(c.group) ?? 0) + 1);
  const byGroup = [...groups.entries()].sort((a, b) => b[1] - a[1]);

  const closed = requests.filter((r) => r.status !== "open");
  const fulfilled = closed.filter((r) => r.status === "fulfilled");
  const fulfilmentPct = closed.length === 0 ? null : Math.round((fulfilled.length * 100) / closed.length);
  const times = fulfilled
    .filter((r) => r.createdAt && r.fulfilledAt)
    .map((r) => r.fulfilledAt!.getTime() - r.createdAt!.getTime())
    .sort((a, b) => a - b);
  const median = times.length === 0 ? null : times[Math.floor(times.length / 2)];

  const screened = checkins.filter((c) => c.status === "done" || c.status === "deferred").length;
  const deferred = checkins.filter((c) => c.status === "deferred").length;
  const deferralPct = screened === 0 ? null : Math.round((deferred * 100) / screened);

  const last = values[values.length - 1];
  const prev = values.length > 1 ? values[values.length - 2] : 0;
  let delta: string | undefined;
  if (prev > 0) {
    const pct = Math.round(((last - prev) * 100) / prev);
    delta = `${pct >= 0 ? "+" : "−"}${Math.abs(pct)}% vs ${weekly ? "last week" : "last month"}`;
  }

  return {
    labels,
    values,
    byGroup,
    rangeLabel: weekly ? "Last 12 weeks" : "Last 12 months",
    max: Math.max(1, ...values),
    total: values.reduce((a, b) => a + b, 0),
    kpis: [
      { label: "Units collected", value: String(last), sub: delta, positive: prev === 0 ? null : last >= prev },
      { label: "Requests fulfilled", value: fulfilmentPct === null ? "—" : `${fulfilmentPct}%`, positive: fulfilmentPct === null ? null : fulfilmentPct >= 80 },
      { label: "Median time to fill", value: median === null ? "—" : duration(median), positive: null },
      { label: "Deferral rate", value: deferralPct === null ? "—" : `${deferralPct}%`, positive: deferralPct === null ? null : deferralPct <= 10 },
    ],
  };
}
