import { Check } from "lucide-react";
import { groupTone, stockTone, type Tone } from "@/lib/models";
import type { InventoryRow } from "@/lib/types";
import { Pill } from "./ui";

/** Blood-group pill. Pass a row to colour by stock, otherwise by group rarity. */
export function BloodPill({ group, row, tone, small }: { group: string; row?: InventoryRow; tone?: Tone; small?: boolean }) {
  return (
    <Pill tone={tone ?? (row ? stockTone(row) : groupTone(group))} small={small}>
      {group}
    </Pill>
  );
}

/** The one verified shape used everywhere: an accent disc with a check. */
export function VerifiedBadge({ label = "Verified hospital" }: { label?: string }) {
  return (
    <span className="inline-flex items-center gap-1.5 text-[13px] font-semibold text-accent-ink">
      <span className="inline-flex h-4 w-4 items-center justify-center rounded-full bg-accent text-on-fill">
        <Check size={11} strokeWidth={3} />
      </span>
      {label}
    </span>
  );
}
