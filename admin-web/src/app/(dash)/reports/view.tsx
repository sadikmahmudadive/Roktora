"use client";

import { useMemo, useState } from "react";
import { BloodPill } from "@/components/badges";
import { useStaff } from "@/components/shell";
import { Grid, Page, Panel, Progress, Segmented, Spinner, StatTile } from "@/components/ui";
import { buildReport } from "@/lib/report";
import { useCheckins, useHospitalRequests } from "@/lib/store";
import type { ReportPeriod } from "@/lib/types";
import { useNow } from "@/lib/use-now";

export default function ReportsPage() {
  const { hospitalId } = useStaff();
  const now = useNow();
  const checkins = useCheckins(hospitalId).data;
  const requests = useHospitalRequests(hospitalId).data;
  const [period, setPeriod] = useState<ReportPeriod>("weekly");

  // Recomputed only when data or the minute changes; `now` is null during prerender.
  const report = useMemo(() => (now ? buildReport({ checkins, requests, period, now }) : null), [checkins, requests, period, now]);
  if (!report) return <Spinner />;

  return (
    <Page
      title="Reports"
      subtitle="Collections and fulfilment · aggregate only"
      actions={<Segmented<ReportPeriod> label="Period" value={period} onChange={setPeriod} options={[["weekly", "Weekly"], ["monthly", "Monthly"]]} />}
    >
      <Grid cols="grid-cols-1 sm:grid-cols-2 xl:grid-cols-4">
        {report.kpis.map((k) => (
          <StatTile key={k.label} label={k.label} value={k.value} sub={k.sub ?? (k.positive === null ? undefined : k.positive ? "On track" : "Needs attention")} tone={k.positive === null ? undefined : k.positive ? "success" : "warning"} />
        ))}
      </Grid>

      <div className="mt-4 grid gap-4 lg:grid-cols-[3fr_2fr]">
        <Panel title="Units collected" action={<span className="text-xs text-ink-3">{report.rangeLabel}</span>}>
          {report.total === 0 ? (
            <p className="flex h-56 items-center justify-center text-sm text-ink-2">No completed donations in this period yet.</p>
          ) : (
            <div className="flex h-56 items-end gap-1.5" role="img" aria-label={`Units collected per ${period === "weekly" ? "week" : "month"}: ${report.values.join(", ")}`}>
              {report.values.map((v, i) => (
                <div key={i} className="flex flex-1 flex-col items-center justify-end">
                  <span className="mb-1 text-[11px] text-ink-3">{v}</span>
                  <div className={`w-full rounded-md transition-[height] duration-300 ${i === report.values.length - 1 ? "bg-brand" : "bg-track"}`} style={{ height: Math.max(2, (v / report.max) * 160) }} />
                  <span className="mt-1.5 text-[10px] text-ink-3">{report.labels[i]}</span>
                </div>
              ))}
            </div>
          )}
        </Panel>
        <Panel title="By blood group">
          {report.byGroup.length === 0 ? <p className="text-sm text-ink-2">Nothing to show yet.</p> : (
            <ul className="space-y-2.5">
              {report.byGroup.map(([g, n]) => (
                <li key={g} className="flex items-center gap-2.5">
                  <span className="w-14"><BloodPill group={g} small /></span>
                  <Progress className="flex-1" tone="accent" value={n / report.byGroup[0][1]} />
                  <span className="w-9 text-right text-[13px] font-semibold">{n}</span>
                </li>
              ))}
            </ul>
          )}
        </Panel>
      </div>
      <p className="mt-4 font-mono text-[11px] text-ink-3">Reports are aggregate by design: no per-donor figures leave this page.</p>
    </Page>
  );
}
