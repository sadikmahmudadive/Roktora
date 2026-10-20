import { render, screen, waitFor } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { beforeEach, describe, expect, it, vi } from "vitest";

const auth = vi.hoisted(() => ({
  signInEmail: vi.fn(),
  signUpEmail: vi.fn(),
  signInGoogle: vi.fn(),
  resetPassword: vi.fn(),
  state: { user: null as unknown, access: undefined as unknown, configured: true },
  replace: vi.fn(),
}));

vi.mock("@/lib/auth", () => ({
  useAuth: () => ({
    ...auth.state,
    signInEmail: auth.signInEmail,
    signUpEmail: auth.signUpEmail,
    signInGoogle: auth.signInGoogle,
    resetPassword: auth.resetPassword,
  }),
}));
vi.mock("next/navigation", () => ({ useRouter: () => ({ replace: auth.replace }), usePathname: () => "/login" }));

import LoginPage from "./view";

beforeEach(() => {
  vi.clearAllMocks();
  auth.state = { user: null, access: undefined, configured: true };
  auth.signInEmail.mockResolvedValue(undefined);
  auth.signUpEmail.mockResolvedValue(undefined);
  auth.signInGoogle.mockResolvedValue(undefined);
  auth.resetPassword.mockResolvedValue(undefined);
});

describe("login page", () => {
  it("offers email and Google", () => {
    render(<LoginPage />);
    expect(screen.getByRole("heading", { name: "Welcome back" })).toBeInTheDocument();
    expect(screen.getByLabelText("Email")).toBeInTheDocument();
    expect(screen.getByRole("button", { name: /google/i })).toBeInTheDocument();
  });

  it("keeps Sign in disabled until the email is valid and the password has 6+ characters", async () => {
    const user = userEvent.setup();
    render(<LoginPage />);
    const submit = screen.getByRole("button", { name: "Sign in" });
    expect(submit).toBeDisabled();

    await user.type(screen.getByLabelText("Email"), "staff@hospital.org");
    await user.type(screen.getByLabelText("Password"), "123");
    expect(submit).toBeDisabled();

    await user.type(screen.getByLabelText("Password"), "456");
    expect(submit).toBeEnabled();
  });

  it("signs in with the trimmed email and password", async () => {
    const user = userEvent.setup();
    render(<LoginPage />);
    await user.type(screen.getByLabelText("Email"), "staff@hospital.org");
    await user.type(screen.getByLabelText("Password"), "secret123");
    await user.click(screen.getByRole("button", { name: "Sign in" }));
    expect(auth.signInEmail).toHaveBeenCalledWith("staff@hospital.org", "secret123");
  });

  it("shows a friendly message for a wrong password", async () => {
    auth.signInEmail.mockRejectedValue({ code: "auth/invalid-credential" });
    const user = userEvent.setup();
    render(<LoginPage />);
    await user.type(screen.getByLabelText("Email"), "staff@hospital.org");
    await user.type(screen.getByLabelText("Password"), "wrongpass");
    await user.click(screen.getByRole("button", { name: "Sign in" }));
    expect(await screen.findByRole("alert")).toHaveTextContent("Email or password is incorrect.");
  });

  it("creates an account in create mode", async () => {
    const user = userEvent.setup();
    render(<LoginPage />);
    await user.click(screen.getByRole("button", { name: "Create account" }));
    expect(screen.getByRole("heading", { name: "Create your account" })).toBeInTheDocument();
    await user.type(screen.getByLabelText("Email"), "new@hospital.org");
    await user.type(screen.getByLabelText("Password"), "secret123");
    await user.click(screen.getByRole("button", { name: "Create account" }));
    expect(auth.signUpEmail).toHaveBeenCalledWith("new@hospital.org", "secret123");
  });

  it("sends a reset link without asking for a password", async () => {
    const user = userEvent.setup();
    render(<LoginPage />);
    await user.click(screen.getByRole("button", { name: "Forgot password?" }));
    expect(screen.queryByLabelText("Password")).not.toBeInTheDocument();
    await user.type(screen.getByLabelText("Email"), "staff@hospital.org");
    await user.click(screen.getByRole("button", { name: "Send reset link" }));
    expect(auth.resetPassword).toHaveBeenCalledWith("staff@hospital.org");
    expect(await screen.findByRole("status")).toHaveTextContent("a reset link is on its way");
  });

  it("starts Google sign-in, and says nothing if the user closes the window", async () => {
    auth.signInGoogle.mockRejectedValue({ code: "auth/popup-closed-by-user" });
    const user = userEvent.setup();
    render(<LoginPage />);
    await user.click(screen.getByRole("button", { name: /google/i }));
    expect(auth.signInGoogle).toHaveBeenCalledTimes(1);
    await waitFor(() => expect(screen.getByRole("button", { name: /google/i })).toBeEnabled());
    expect(screen.queryByRole("alert")).not.toBeInTheDocument();
  });

  it("explains an unauthorised domain when Google sign-in fails", async () => {
    auth.signInGoogle.mockRejectedValue({ code: "auth/unauthorized-domain" });
    const user = userEvent.setup();
    render(<LoginPage />);
    await user.click(screen.getByRole("button", { name: /google/i }));
    expect(await screen.findByRole("alert")).toHaveTextContent(/Authorized domains/);
  });

  it("sends signed-in visitors on to the dashboard", () => {
    auth.state = { user: { uid: "u1" }, access: { uid: "u1", hospitalId: "mch", name: "A", role: "admin" }, configured: true };
    render(<LoginPage />);
    expect(auth.replace).toHaveBeenCalledWith("/");
  });

  it("shows setup instructions when Firebase isn't configured", () => {
    auth.state = { user: null, access: undefined, configured: false };
    render(<LoginPage />);
    expect(screen.getByRole("heading", { name: "Connect Firebase to continue" })).toBeInTheDocument();
  });
});
