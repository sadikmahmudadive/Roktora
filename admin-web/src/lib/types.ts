// Shapes mirror the Firestore documents written by the Roktora mobile app.

export const BLOOD_GROUPS = ["A+", "A−", "B+", "B−", "O+", "O−", "AB+", "AB−"] as const;
export type BloodGroup = (typeof BLOOD_GROUPS)[number];

export const COMPONENTS = ["Whole blood", "Red cells", "Plasma", "Platelets"] as const;
export const COMPONENT_KEYS = ["whole", "red", "plasma", "platelets"] as const;
export type ComponentKey = (typeof COMPONENT_KEYS)[number];

/** Shelf life in days for each entry of {@link COMPONENTS}. */
export const SHELF_LIFE_DAYS = [35, 42, 365, 5] as const;

export type Urgency = "critical" | "urgent" | "routine";
export type RequestStatus = "open" | "fulfilled" | "closed";
export type CheckInStatus = "waiting" | "screening" | "donating" | "done" | "deferred";

/** A signed-in user's staff record on accounts/{uid} (role + hospitalId). */
export interface AdminAccess {
  uid: string;
  hospitalId: string;
  name: string;
  role: "admin" | "staff";
}

export interface VerificationStep {
  label: string;
  when: string;
  done: boolean;
}
export interface HospitalDoc {
  name: string;
  status: string;
  warning: boolean;
}
export interface StaffMember {
  name: string;
  role: string;
  twoFa: boolean;
}

export interface Hospital {
  id: string;
  name: string;
  address: string;
  phone: string;
  about: string;
  /** Map position picked on Google Maps; null until set. */
  lat?: number | null;
  lng?: number | null;
  verified: boolean;
  steps: VerificationStep[];
  docs: HospitalDoc[];
  staff: StaffMember[];
}

export interface InventoryRow {
  group: string;
  target: number;
  parts: Record<ComponentKey, number>;
}

export interface Batch {
  id: string;
  group: string;
  component: string;
  expiresAt: Date;
  shelfLifeDays: number;
}

export interface BloodRequest {
  id: string;
  bloodGroup: string;
  title: string;
  place: string;
  note: string;
  postedBy: string;
  bagsNeeded: number;
  urgency: Urgency;
  deadline: Date;
  verified: boolean;
  committedUids: string[];
  status: RequestStatus;
  hospitalId: string;
  createdAt: Date | null;
  fulfilledAt: Date | null;
}

export interface CheckIn {
  id: string;
  donorName: string;
  group: string;
  status: CheckInStatus;
  at: Date;
  donorUid: string;
  bay: number | null;
  requestId: string;
}

/** A registered donor as hospital staff see them: first name + initial only. */
export interface DonorEntry {
  uid: string;
  name: string;
  group: string;
  area: string;
  donations: number;
  lastDonation: Date | null;
  eligible: boolean;
  daysUntilEligible: number;
}

export type ReportPeriod = "weekly" | "monthly";

export interface ReportKpi {
  label: string;
  value: string;
  sub?: string;
  /** true = good, false = needs attention, null = neutral */
  positive: boolean | null;
}

export interface ReportData {
  labels: string[];
  values: number[];
  kpis: ReportKpi[];
  byGroup: [string, number][];
  rangeLabel: string;
  max: number;
  total: number;
}
