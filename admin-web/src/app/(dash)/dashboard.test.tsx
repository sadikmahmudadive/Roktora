import { render, screen, within } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { beforeEach, describe, expect, it, vi } from "vitest";
import type { CheckIn, DonorEntry, InventoryRow } from "@/lib/types";

const NOW = new Date(2026, 9, 19, 12);

const store = vi.hoisted(() => ({
  inventory: [] as InventoryRow[],
  directory: [] as DonorEntry[],
  checkins: [] as CheckIn[],
  setStock: vi.fn(),
  seedInventory: vi.fn(),
  addBatch: vi.fn(),
  startCheckIn: vi.fn(),
  completeDonation: vi.fn(),
  donorLookup: vi.fn(),
  sendBulkMessage: vi.fn(),
}));

vi.mock("@/components/shell", () => ({ useStaff: () => ({ uid: "u1", hospitalId: "mch", name: "Dr. Sultana", role: "admin" }) }));
vi.mock("@/lib/use-now", () => ({ useNow: () => NOW }));
vi.mock("@/lib/store", () => ({
  useInventory: () => ({ data: store.inventory, loading: false, error: null }),
  useBatches: () => ({ data: [], loading: false, error: null }),
  useCheckins: () => ({ data: store.checkins, loading: false, error: null }),
  useHospitalRequests: () => ({ data: [], loading: false, error: null }),
  useHospital: () => ({ data: { id: "mch", name: "Mirpur Central Hospital" }, loading: false, error: null }),
  useDirectory: () => ({ data: store.directory, loading: false, error: null, reload: vi.fn() }),
  setStock: store.setStock,
  seedInventory: store.seedInventory,
  addBatch: store.addBatch,
  startCheckIn: store.startCheckIn,
  completeDonation: store.completeDonation,
  donorLookup: store.donorLookup,
  sendBulkMessage: store.sendBulkMessage,
}));

import CheckInPage from "./checkin/view";
import DonorsPage from "./donors/view";
import InventoryPage from "./inventory/view";

const row = (group: string, whole: number, target: number): InventoryRow => ({ group, target, parts: { whole, red: 0, plasma: 0, platelets: 0 } });
const donor = (uid: string, name: string, group: string, eligible = true): DonorEntry => ({ uid, name, group, area: "Mirpur", donations: 3, lastDonation: null, eligible, daysUntilEligible: eligible ? 0 : 40 });

beforeEach(() => {
  vi.clearAllMocks();
  store.inventory = [row("A+", 19, 50), row("B+", 36, 60), row("O−", 2, 15), row("O+", 55, 60)];
  store.directory = [donor("d1", "Farhan H.", "O−"), donor("d2", "Sadia K.", "O−"), donor("d3", "Rafiq M.", "B−", false)];
  store.checkins = [];
  store.setStock.mockResolvedValue(undefined);
  store.startCheckIn.mockResolvedValue("c1");
  store.completeDonation.mockResolvedValue(undefined);
  store.donorLookup.mockResolvedValue([]);
  store.sendBulkMessage.mockResolvedValue(undefined);
});

describe("inventory page", () => {
  it("shows stock by group with its status", () => {
    render(<InventoryPage />);
    expect(screen.getByText("Blood inventory")).toBeInTheDocument();
    expect(screen.getByText("112 units on hand")).toBeInTheDocument();
    expect(screen.getByText("Shortage · 19 of 50")).toBeInTheDocument(); // 38% of target
    expect(screen.getByText("Low · 36 of 60")).toBeInTheDocument(); // 60%
    expect(screen.getByText("Shortage · 2 of 15")).toBeInTheDocument();
    expect(screen.getByText("Healthy · 55 of 60")).toBeInTheDocument();
  });

  it("edits a cell and saves the new number", async () => {
    const user = userEvent.setup();
    render(<InventoryPage />);
    await user.click(screen.getByRole("button", { name: "Edit A+ Whole blood" }));
    const dialog = screen.getByRole("dialog");
    expect(within(dialog).getByText("A+ · Whole blood")).toBeInTheDocument();
    await user.click(within(dialog).getByRole("button", { name: "Increase units" }));
    await user.click(within(dialog).getByRole("button", { name: "Save" }));
    expect(store.setStock).toHaveBeenCalledWith("mch", "A+", "whole", 20);
  });

  it("offers to set up inventory when there is none", async () => {
    store.inventory = [];
    const user = userEvent.setup();
    render(<InventoryPage />);
    await user.click(screen.getByRole("button", { name: /set up inventory/i }));
    expect(store.seedInventory).toHaveBeenCalledWith("mch");
  });
});

describe("check-in page", () => {
  async function walkInThroughVerify(user: ReturnType<typeof userEvent.setup>, hb: string) {
    render(<CheckInPage />);
    await user.type(screen.getByLabelText("Full name"), "Karim Uddin");
    await user.click(screen.getByRole("button", { name: "B+" }));
    await user.click(screen.getByRole("button", { name: "Continue as walk-in" }));
    for (const label of ["Photo ID matches the passport name", "Blood pressure within range", "Donor confirmed consent at the desk"]) {
      await user.click(screen.getByLabelText(label));
    }
    await user.type(screen.getByLabelText("Haemoglobin (g/dL)"), hb);
  }

  it("moves a walk-in through verify and bay assignment, then records the check-in", async () => {
    const user = userEvent.setup();
    await walkInThroughVerify(user, "13.4");
    await user.click(screen.getByRole("button", { name: "Continue" }));
    expect(screen.getByText("Assign a bay")).toBeInTheDocument();
    await user.click(screen.getByRole("button", { name: /Bay 2/ }));
    await user.click(screen.getByRole("button", { name: "Start donation" }));

    expect(store.startCheckIn).toHaveBeenCalledWith("mch", { donorName: "Karim Uddin", group: "B+", donorUid: "", status: "donating", bay: 2 });
    expect(await screen.findByText("Karim Uddin is checked in to bay 2.")).toBeInTheDocument();
  });

  it("blocks Continue and warns when haemoglobin is too low, then defers", async () => {
    const user = userEvent.setup();
    await walkInThroughVerify(user, "11.0");
    expect(screen.getByRole("button", { name: "Continue" })).toBeDisabled();
    expect(screen.getByText(/should be deferred/)).toBeInTheDocument();

    await user.click(screen.getByRole("button", { name: "Defer donor" }));
    expect(store.startCheckIn).toHaveBeenCalledWith("mch", expect.objectContaining({ donorName: "Karim Uddin", status: "deferred", bay: null }));
  });

  it("needs all three desk checks before Continue is enabled", async () => {
    const user = userEvent.setup();
    render(<CheckInPage />);
    await user.type(screen.getByLabelText("Full name"), "Karim Uddin");
    await user.click(screen.getByRole("button", { name: "Continue as walk-in" }));
    await user.type(screen.getByLabelText("Haemoglobin (g/dL)"), "14");
    await user.click(screen.getByLabelText("Photo ID matches the passport name"));
    expect(screen.getByRole("button", { name: "Continue" })).toBeDisabled();
  });

  it("marks someone in a bay as donated", async () => {
    store.checkins = [{ id: "c9", donorName: "Tania S.", group: "O+", status: "donating", at: NOW, donorUid: "t1", bay: 1, requestId: "" }];
    const user = userEvent.setup();
    render(<CheckInPage />);
    expect(screen.getByText("In bays now · 1")).toBeInTheDocument();
    await user.click(screen.getByRole("button", { name: "Donated" }));
    expect(store.completeDonation).toHaveBeenCalledWith("mch", store.checkins[0]);
  });
});

describe("donor directory page", () => {
  it("filters by eligibility", async () => {
    const user = userEvent.setup();
    render(<DonorsPage />);
    expect(screen.getByText("Rafiq M.")).toBeInTheDocument();
    await user.click(screen.getByRole("button", { name: "Eligible only" }));
    expect(screen.queryByText("Rafiq M.")).not.toBeInTheDocument();
    expect(screen.getByText("Farhan H.")).toBeInTheDocument();
  });

  it("messages the selected donors", async () => {
    const user = userEvent.setup();
    render(<DonorsPage />);
    await user.click(screen.getByLabelText("Select Farhan H."));
    await user.click(screen.getByLabelText("Select Sadia K."));
    expect(screen.getByText("2 selected")).toBeInTheDocument();

    await user.click(screen.getByRole("button", { name: "Message" }));
    await user.type(screen.getByLabelText("Message"), "We urgently need O− donors this week.");
    await user.click(screen.getByRole("button", { name: "Send to 2" }));

    expect(store.sendBulkMessage).toHaveBeenCalledWith("Mirpur Central Hospital", ["d1", "d2"], "We urgently need O− donors this week.");
    expect(await screen.findByText(/Message sent to 2 donors/)).toBeInTheDocument();
  });
});
