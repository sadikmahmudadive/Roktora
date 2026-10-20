"use client";

import { Copy, Lock, Settings2 } from "lucide-react";
import { useRouter } from "next/navigation";
import { useEffect, useState, type ReactNode } from "react";
import { useAuth } from "@/lib/auth";
import { Wordmark } from "./brand";
import { Shell } from "./shell";
import { Banner, Button, Spinner } from "./ui";

export function SetupNotice() {
  return (
    <div className="mx-auto flex min-h-screen w-full max-w-xl flex-col justify-center gap-4 p-6">
      <Wordmark />
      <h1 className="text-3xl font-semibold tracking-tight">Connect Firebase to continue</h1>
      <Banner tone="warning" icon={<Settings2 size={18} />}>
        This site has no Firebase settings yet. Copy <code className="font-mono">.env.local.example</code> to <code className="font-mono">.env.local</code>, fill in your web app&apos;s config, and restart the dev server.
      </Banner>
      <p className="text-sm text-ink-2">The values come from Firebase console → Project settings → Your apps → Web app. See the README for the full checklist.</p>
    </div>
  );
}

function NoAccess() {
  const { user, signOut } = useAuth();
  const [copied, setCopied] = useState(false);
  const uid = user?.uid ?? "";
  return (
    <div className="mx-auto flex min-h-screen w-full max-w-lg flex-col justify-center gap-5 p-6">
      <Wordmark />
      <span className="inline-flex h-14 w-14 items-center justify-center rounded-2xl bg-warning-bg text-warning-ink">
        <Lock size={26} />
      </span>
      <h1 className="text-3xl font-semibold tracking-tight">This account isn&apos;t linked to a hospital</h1>
      <p className="text-ink-2">
        The dashboard is for verified hospital staff. Your account is saved automatically. A Roktora admin links you in the Firebase console by opening your document in the <code className="font-mono">accounts</code> collection (ID below) and setting <code className="font-mono">role</code> to <code className="font-mono">admin</code> or <code className="font-mono">staff</code>, plus a <code className="font-mono">hospitalId</code>.
      </p>
      <div className="rounded-[var(--radius-ctl)] bg-surface-2 p-3">
        <div className="mb-1 text-xs text-ink-3">Signed in as {user?.email ?? "this account"}</div>
        <div className="flex items-center gap-2">
          <code className="min-w-0 flex-1 font-mono text-xs break-all">{uid}</code>
          <Button
            variant="outline"
            size="sm"
            icon={<Copy size={14} />}
            onClick={() => {
              void navigator.clipboard?.writeText(uid);
              setCopied(true);
            }}
          >
            {copied ? "Copied" : "Copy"}
          </Button>
        </div>
      </div>
      <div>
        <Button variant="outline" onClick={() => void signOut()}>
          Sign out
        </Button>
      </div>
    </div>
  );
}

/** Everything under (dash) needs a signed-in user with a staff record. */
export function DashGuard({ children }: { children: ReactNode }) {
  const { user, access, account, isSuper, configured } = useAuth();
  const router = useRouter();

  useEffect(() => {
    if (configured && user === null) router.replace("/login");
    // Platform team members without a hospital land on their own console.
    if (isSuper && access === null) router.replace("/platform");
  }, [configured, user, isSuper, access, router]);

  if (!configured) return <SetupNotice />;
  if (!user || access === undefined || account === undefined) return <Spinner label="Checking your access" />;
  if (isSuper && access === null) return <Spinner label="Opening the platform console" />;
  if (access === null) return <NoAccess />;
  return <Shell access={access}>{children}</Shell>;
}
