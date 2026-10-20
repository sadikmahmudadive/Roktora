import { DashGuard } from "@/components/guard";

// The dashboard is behind a client-side Firebase sign-in, so there's no static shell to validate
// for instant navigation (the guard shows a spinner until the session resolves). Opt out of that
// development-only check; it never affects builds.
export const instant = false;

export default function DashLayout({ children }: LayoutProps<"/">) {
  return <DashGuard>{children}</DashGuard>;
}
