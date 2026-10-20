import type { Metadata } from "next";
import View from "./view";

export const metadata: Metadata = { title: "Reports" };

// Behind a client-side Firebase sign-in there is no static shell to validate for instant navigation.
// Opting out only silences a development-time check.
export const instant = false;

export default function Page() {
  return <View />;
}
