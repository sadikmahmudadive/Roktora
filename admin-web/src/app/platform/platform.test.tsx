import { render, screen, within } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { beforeEach, describe, expect, it, vi } from "vitest";
import type { AccountRow } from "@/lib/platform";

const mocks = vi.hoisted(() => ({
  replace: vi.fn(),
  auth: { user: { uid: "s1" } as unknown, access: null as unknown, account: { role: "superadmin", hospitalId: "" } as unknown, isSuper: true, configured: true, signOut: vi.fn() },
  accounts: [] as AccountRow[],
  setAccountAccess: vi.fn(),
  createHospital: vi.fn(),
  setHospitalVerified: vi.fn(),
}));

vi.mock("next/navigation", () => ({ useRouter: () => ({ replace: mocks.replace }) }));
vi.mock("@/components/theme-toggle", () => ({ ThemeToggle: () => null }));
vi.mock("@/lib/auth", () => ({ useAuth: () => mocks.auth }));
vi.mock("@/lib/platform", () => ({
  useAccounts: () => ({ data: mocks.accounts, loading: false, error: null }),
  useHospitals: () => ({ data: [{ id: "mch", name: "Mirpur Central", verified: false }], loading: false, error: null }),
  setAccountAccess: mocks.setAccountAccess,
  createHospital: mocks.createHospital,
  setHospitalVerified: mocks.setHospitalVerified,
}));

import PlatformPage from "./view";

const acct = (uid: string, name: string, role: AccountRow["role"], hospitalId = ""): AccountRow => ({ uid, email: `${uid}@x.test`, phone: "", name, role, hospitalId, lastLoginAt: null });

beforeEach(() => {
  vi.clearAllMocks();
  mocks.auth.user = { uid: "s1" };
  mocks.auth.account = { role: "superadmin", hospitalId: "" };
  mocks.auth.isSuper = true;
  mocks.accounts = [acct("a1", "Farhan Hossain", "user"), acct("s1", "Boss", "superadmin")];
  mocks.setAccountAccess.mockResolvedValue(undefined);
  mocks.setHospitalVerified.mockResolvedValue(undefined);
});

describe("platform console", () => {
  it("sends non-superadmins back to the dashboard", () => {
    mocks.auth.isSuper = false;
    mocks.auth.account = { role: "user", hospitalId: "" };
    render(<PlatformPage />);
    expect(mocks.replace).toHaveBeenCalledWith("/");
    expect(screen.queryByText("Platform console")).not.toBeInTheDocument();
  });

  it("links an account to a hospital", async () => {
    const user = userEvent.setup();
    render(<PlatformPage />);
    await user.click(screen.getByRole("button", { name: "Edit access for Farhan Hossain" }));
    const dialog = screen.getByRole("dialog");
    await user.selectOptions(within(dialog).getByLabelText("Role"), "admin");
    expect(within(dialog).getByRole("button", { name: "Save" })).toBeDisabled(); // needs a hospital
    await user.selectOptions(within(dialog).getByLabelText("Hospital"), "mch");
    await user.click(within(dialog).getByRole("button", { name: "Save" }));
    expect(mocks.setAccountAccess).toHaveBeenCalledWith("a1", "admin", "mch");
  });

  it("does not let you edit a superadmin", () => {
    render(<PlatformPage />);
    expect(screen.getByRole("button", { name: "Edit access for Boss" })).toBeDisabled();
  });

  it("verifies a hospital", async () => {
    const user = userEvent.setup();
    render(<PlatformPage />);
    await user.click(screen.getByRole("button", { name: /^Hospitals/ }));
    await user.click(screen.getByRole("button", { name: "Verify Mirpur Central" }));
    expect(mocks.setHospitalVerified).toHaveBeenCalledWith("mch", true);
  });
});
