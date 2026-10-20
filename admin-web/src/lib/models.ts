import { COMPONENT_KEYS, type Batch, type ComponentKey, type InventoryRow } from "./types";

/** Whole-blood donors rest this long between donations (matches the mobile app). */
export const COOLDOWN_DAYS = 120;

/** Minimum haemoglobin (g/dL) for a whole-blood donation. */
export const MIN_HAEMOGLOBIN = 12.5;

export type StockLevel = "shortage" | "low" | "healthy";

export function unitsOf(row: InventoryRow): number {
  return COMPONENT_KEYS.reduce((sum, k) => sum + (row.parts[k] ?? 0), 0);
}

export function stockRatio(row: InventoryRow): number {
  return row.target === 0 ? 1 : unitsOf(row) / row.target;
}

/** Under 40% of target is a shortage, under 75% is low. */
export function stockLevel(row: InventoryRow): StockLevel {
  const r = stockRatio(row);
  return r < 0.4 ? "shortage" : r < 0.75 ? "low" : "healthy";
}

export function isNegativeGroup(group: string): boolean {
  return group.endsWith("−") || group.endsWith("-");
}

export type Tone = "danger" | "warning" | "success" | "neutral";

/** Rh-negative shortages read as danger; elsewhere a shortage is a warning. */
export function stockTone(row: InventoryRow): Tone {
  const level = stockLevel(row);
  if (level === "shortage") return isNegativeGroup(row.group) ? "danger" : "warning";
  return level === "low" ? "warning" : "success";
}

export function stockLabel(row: InventoryRow): string {
  return { shortage: "Shortage", low: "Low", healthy: "Healthy" }[stockLevel(row)];
}

/** Colour for a blood-group pill when there is no stock context: negatives red, B/O amber, others green. */
export function groupTone(group: string): Tone {
  if (isNegativeGroup(group)) return "danger";
  return group.startsWith("B") || group.startsWith("O") ? "warning" : "success";
}

export function withPart(row: InventoryRow, key: ComponentKey, units: number): InventoryRow {
  return { ...row, parts: { ...row.parts, [key]: Math.max(0, units) } };
}

export function emptyParts(): Record<ComponentKey, number> {
  return { whole: 0, red: 0, plasma: 0, platelets: 0 };
}

export function daysLeft(batch: Batch, now: Date): number {
  const ms = batch.expiresAt.getTime() - now.getTime();
  return ms <= 0 ? 0 : Math.ceil(ms / 86_400_000);
}

/** "Farhan Hossain" -> "Farhan H." Hospitals never see full donor names. */
export function publicName(full: string): string {
  const parts = full.trim().split(/\s+/).filter(Boolean);
  if (parts.length === 0) return "Donor";
  if (parts.length === 1) return parts[0];
  return `${parts[0]} ${parts[parts.length - 1][0]}.`;
}

export function initials(name: string): string {
  const parts = name.trim().split(/\s+/).filter(Boolean);
  if (parts.length === 0) return "?";
  const raw = parts.length === 1 ? parts[0].slice(0, 2) : parts[0][0] + parts[parts.length - 1][0];
  return raw.toUpperCase();
}

export function daysUntilEligible(lastDonation: Date | null, now: Date): number {
  if (!lastDonation) return 0;
  const next = lastDonation.getTime() + COOLDOWN_DAYS * 86_400_000;
  return next <= now.getTime() ? 0 : Math.ceil((next - now.getTime()) / 86_400_000);
}

/** Screening passed AND the cooldown since the last donation has finished. */
export function isEligibleNow(screeningOk: boolean, lastDonation: Date | null, now: Date): boolean {
  return screeningOk && daysUntilEligible(lastDonation, now) === 0;
}

export function sameDay(a: Date, b: Date): boolean {
  return a.getFullYear() === b.getFullYear() && a.getMonth() === b.getMonth() && a.getDate() === b.getDate();
}

/** Accepts a donor ID, or the passport QR text `roktora:checkin:<requestId>:<donorUid>`. */
export function parseDonorCode(raw: string): string {
  const t = raw.trim();
  return t.startsWith("roktora:checkin:") ? (t.split(":").pop() ?? "") : t;
}
