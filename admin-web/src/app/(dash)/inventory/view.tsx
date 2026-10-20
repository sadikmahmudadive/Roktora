"use client";

import { format } from "date-fns";
import { Plus } from "lucide-react";
import { useState } from "react";
import { BloodPill } from "@/components/badges";
import { useStaff } from "@/components/shell";
import { Banner, Button, Dialog, Empty, Page, Panel, PickChip, Progress, Segmented, Spinner, Stepper, TONE_TEXT, cn } from "@/components/ui";
import { daysLeft, stockLabel, stockTone, unitsOf } from "@/lib/models";
import { addBatch, seedInventory, setStock, useBatches, useInventory } from "@/lib/store";
import { BLOOD_GROUPS, COMPONENTS, COMPONENT_KEYS, SHELF_LIFE_DAYS, type InventoryRow } from "@/lib/types";
import { useNow } from "@/lib/use-now";

export default function InventoryPage() {
  const { hospitalId } = useStaff();
  const now = useNow();
  const inv = useInventory(hospitalId);
  const batchesLive = useBatches(hospitalId);
  /** -1 = all components, otherwise an index into COMPONENTS. */
  const [comp, setComp] = useState(-1);
  const [edit, setEdit] = useState<{ row: InventoryRow; ci: number } | null>(null);
  const [logging, setLogging] = useState(false);
  const [seeding, setSeeding] = useState(false);

  if (!now) return <Spinner />;

  const rows = inv.data;
  const total = rows.reduce((s, r) => s + unitsOf(r), 0);
  const batches = batchesLive.data.filter((b) => comp < 0 || b.component === COMPONENTS[comp]);

  return (
    <Page
      title="Blood inventory"
      subtitle={`${total} units on hand`}
      actions={<Segmented<number> label="Component" value={comp} onChange={setComp} options={[[-1, "All"], ...COMPONENTS.map((c, i) => [i, c] as const)]} />}
    >
      {inv.error && <Banner tone="danger" className="mb-4">Couldn&apos;t load stock: {inv.error}</Banner>}

      <Panel title="Stock by group" flush>
        {inv.loading ? <Spinner /> : rows.length === 0 ? (
          <div className="px-4 pb-4">
            <p className="text-sm text-ink-2">No stock recorded yet.</p>
            <Button className="mt-3" icon={<Plus size={16} />} disabled={seeding} onClick={async () => { setSeeding(true); try { await seedInventory(hospitalId); } finally { setSeeding(false); } }}>
              Set up inventory
            </Button>
          </div>
        ) : (
          <div className="overflow-x-auto">
            <table className="w-full min-w-[720px] text-left text-sm">
              <thead>
                <tr className="text-xs text-ink-3">
                  <th scope="col" className="w-28 px-4 py-2.5 font-semibold">Group</th>
                  {COMPONENTS.map((c, i) => <th key={c} scope="col" className={cn("px-4 py-2.5 font-semibold", i === comp && "bg-brand-bg text-ink")}>{c}</th>)}
                  <th scope="col" className="w-52 px-4 py-2.5 font-semibold">Status</th>
                </tr>
              </thead>
              <tbody>
                {rows.map((r) => {
                  const tone = stockTone(r);
                  return (
                    <tr key={r.group} className="border-t border-line">
                      <th scope="row" className="px-4 py-2.5"><BloodPill group={r.group} row={r} /></th>
                      {COMPONENT_KEYS.map((k, i) => (
                        <td key={k} className={cn("p-0", i === comp && "bg-brand-bg")}>
                          <button type="button" aria-label={`Edit ${r.group} ${COMPONENTS[i]}`} onClick={() => setEdit({ row: r, ci: i })} className={cn("h-[52px] w-full px-4 text-left font-semibold hover:bg-hover", r.parts[k] === 0 && "text-danger-ink")}>
                            {r.parts[k]}
                          </button>
                        </td>
                      ))}
                      <td className={cn("px-4 text-[13px] font-semibold", TONE_TEXT[tone])}>{stockLabel(r)} · {unitsOf(r)} of {r.target}</td>
                    </tr>
                  );
                })}
              </tbody>
            </table>
          </div>
        )}
      </Panel>

      <Panel className="mt-4" title={`Expiring batches · ${batches.length}`} flush action={<Button variant="outline" size="sm" icon={<Plus size={15} />} onClick={() => setLogging(true)}>Log batch</Button>}>
        {batches.length === 0 ? <Empty>No batches to show.</Empty> : (
          <ul>
            {batches.map((b, i) => {
              const left = daysLeft(b, now);
              const crit = left <= 2;
              return (
                <li key={b.id} className={cn("flex flex-wrap items-center gap-x-4 gap-y-1 border-l-2 px-4 py-3", crit ? "border-danger" : "border-warning", i > 0 && "border-t border-t-line")}>
                  <code className="min-w-40 flex-1 font-mono text-xs">{b.id}</code>
                  <BloodPill group={b.group} small />
                  <span className="w-28 text-sm text-ink-2">{b.component}</span>
                  <span className="w-16 text-sm text-ink-2">{format(b.expiresAt, "d MMM")}</span>
                  <span className={cn("w-20 text-sm font-semibold", crit ? "text-danger-ink" : "text-warning-ink")}>{left <= 1 ? "Tomorrow" : `${left} days`}</span>
                  <Progress className="w-24" value={Math.max(0.04, left / Math.min(b.shelfLifeDays, 7))} tone={crit ? "danger" : "warning"} />
                </li>
              );
            })}
          </ul>
        )}
      </Panel>

      {edit && <StockDialog key={`${edit.row.group}-${edit.ci}`} row={edit.row} ci={edit.ci} onClose={() => setEdit(null)} hospitalId={hospitalId} />}
      <BatchDialog open={logging} onClose={() => setLogging(false)} hospitalId={hospitalId} />
    </Page>
  );
}

function StockDialog({ row, ci, onClose, hospitalId }: { row: InventoryRow; ci: number; onClose: () => void; hospitalId: string }) {
  const key = COMPONENT_KEYS[ci];
  const [value, setValue] = useState(row.parts[key]);
  const [busy, setBusy] = useState(false);
  return (
    <Dialog
      open
      onClose={onClose}
      title={`${row.group} · ${COMPONENTS[ci]}`}
      footer={<>
        <Button variant="outline" onClick={onClose}>Cancel</Button>
        <Button disabled={busy} onClick={async () => { setBusy(true); try { await setStock(hospitalId, row.group, key, value); onClose(); } finally { setBusy(false); } }}>Save</Button>
      </>}
    >
      <div className="flex justify-center py-4"><Stepper label="units" value={value} onChange={setValue} /></div>
    </Dialog>
  );
}

function BatchDialog({ open, onClose, hospitalId }: { open: boolean; onClose: () => void; hospitalId: string }) {
  const [group, setGroup] = useState<string>("O+");
  const [ci, setCi] = useState(0);
  const [busy, setBusy] = useState(false);
  return (
    <Dialog
      open={open}
      onClose={onClose}
      title="Log a batch"
      footer={<>
        <Button variant="outline" onClick={onClose}>Cancel</Button>
        <Button
          disabled={busy}
          onClick={async () => {
            setBusy(true);
            try {
              const now = new Date();
              const id = `B-${format(now, "yyMM")}-${1000 + Math.floor(Math.random() * 9000)}`;
              await addBatch(hospitalId, { id, group, component: COMPONENTS[ci], expiresAt: new Date(now.getTime() + SHELF_LIFE_DAYS[ci] * 86_400_000), shelfLifeDays: SHELF_LIFE_DAYS[ci] });
              onClose();
            } finally {
              setBusy(false);
            }
          }}
        >
          Log batch
        </Button>
      </>}
    >
      <p className="mb-2 text-[13px] font-semibold">Blood group</p>
      <div className="flex flex-wrap gap-2">{BLOOD_GROUPS.map((g) => <PickChip key={g} selected={g === group} onClick={() => setGroup(g)}>{g}</PickChip>)}</div>
      <p className="mt-4 mb-2 text-[13px] font-semibold">Component</p>
      <div className="flex flex-wrap gap-2">{COMPONENTS.map((c, i) => <PickChip key={c} selected={i === ci} onClick={() => setCi(i)}>{c}</PickChip>)}</div>
      <p className="mt-3 text-xs text-ink-3">Shelf life: {SHELF_LIFE_DAYS[ci]} days</p>
    </Dialog>
  );
}
