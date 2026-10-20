"use client";

import { AlertCircle, CheckCircle2, Eye, EyeOff, Lock, Mail } from "lucide-react";
import { useRouter } from "next/navigation";
import { useEffect, useState, type FormEvent } from "react";
import { Wordmark } from "@/components/brand";
import { SetupNotice } from "@/components/guard";
import { Banner, Button } from "@/components/ui";
import { useAuth } from "@/lib/auth";
import { authMessage } from "@/lib/auth-errors";

type Mode = "signIn" | "create" | "reset";

const COPY: Record<Mode, { title: string; sub: string; cta: string }> = {
  signIn: { title: "Welcome back", sub: "Sign in to manage your blood bank.", cta: "Sign in" },
  create: { title: "Create your account", sub: "You'll be able to open the dashboard once a Roktora admin links your account to a hospital.", cta: "Create account" },
  reset: { title: "Reset your password", sub: "Enter your email and we'll send a link to choose a new one.", cta: "Send reset link" },
};

function GoogleMark() {
  return (
    <svg width="18" height="18" viewBox="0 0 48 48" aria-hidden>
      <path fill="#EA4335" d="M24 9.5c3.5 0 6.6 1.2 9 3.5l6.7-6.7C35.6 2.4 30.2 0 24 0 14.6 0 6.5 5.4 2.6 13.2l7.8 6.1C12.3 13.6 17.7 9.5 24 9.5z" />
      <path fill="#4285F4" d="M46.5 24.5c0-1.6-.1-3.1-.4-4.5H24v9h12.7c-.6 3-2.3 5.5-4.8 7.2l7.5 5.8c4.4-4.1 7.1-10.1 7.1-17.5z" />
      <path fill="#FBBC05" d="M10.4 28.7A14.5 14.5 0 0 1 9.5 24c0-1.6.3-3.2.9-4.7l-7.8-6.1A24 24 0 0 0 0 24c0 3.9.9 7.5 2.6 10.8l7.8-6.1z" />
      <path fill="#34A853" d="M24 48c6.2 0 11.4-2 15.2-5.5l-7.5-5.8c-2.1 1.4-4.7 2.3-7.7 2.3-6.3 0-11.7-4.1-13.6-9.8l-7.8 6.1C6.5 42.6 14.6 48 24 48z" />
    </svg>
  );
}

export default function LoginPage() {
  const { user, access, configured, signInEmail, signUpEmail, signInGoogle, resetPassword } = useAuth();
  const router = useRouter();
  const [mode, setMode] = useState<Mode>("signIn");
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [show, setShow] = useState(false);
  const [busy, setBusy] = useState<"form" | "google" | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [info, setInfo] = useState<string | null>(null);

  // Signed in already (e.g. returning visitor): the dashboard guard decides what they see.
  useEffect(() => {
    if (user && access !== undefined) router.replace("/");
  }, [user, access, router]);

  if (!configured) return <SetupNotice />;

  const emailValid = /^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(email.trim());
  const canSubmit = emailValid && (mode === "reset" || password.length >= 6) && busy === null;
  const copy = COPY[mode];

  const switchMode = (m: Mode) => {
    setMode(m);
    setError(null);
    setInfo(null);
  };

  async function submit(e: FormEvent) {
    e.preventDefault();
    if (!canSubmit) return;
    setBusy("form");
    setError(null);
    setInfo(null);
    try {
      if (mode === "signIn") await signInEmail(email, password);
      else if (mode === "create") await signUpEmail(email, password);
      else {
        await resetPassword(email);
        setInfo(`If an account exists for ${email.trim()}, a reset link is on its way. Check your inbox and spam folder.`);
      }
    } catch (err) {
      const msg = authMessage(err, "That didn't work. Check your details and try again.");
      if (msg) setError(msg);
    } finally {
      setBusy(null);
    }
  }

  async function google() {
    setBusy("google");
    setError(null);
    try {
      await signInGoogle();
    } catch (err) {
      const msg = authMessage(err, "Google sign-in didn't work. Try again or use email.");
      if (msg) setError(msg);
    } finally {
      setBusy(null);
    }
  }

  return (
    <main className="mx-auto flex min-h-screen w-full max-w-[440px] flex-col justify-center gap-6 px-5 py-10">
      <Wordmark />
      <div>
        <h1 className="text-[34px] leading-tight font-semibold tracking-tight">{copy.title}</h1>
        <p className="mt-2 text-[15px] text-ink-2">{copy.sub}</p>
      </div>

      <form onSubmit={submit} className="space-y-3" noValidate>
        <div>
          <label htmlFor="email" className="mb-1.5 block text-[13px] font-semibold">
            Email
          </label>
          <div className="relative">
            <Mail size={18} className="pointer-events-none absolute top-1/2 left-3.5 -translate-y-1/2 text-ink-3" />
            <input
              id="email"
              type="email"
              autoComplete="email"
              inputMode="email"
              value={email}
              onChange={(e) => setEmail(e.target.value)}
              placeholder="you@hospital.org"
              className="w-full rounded-2xl border border-line-2 bg-surface-1 py-3.5 pr-4 pl-11 text-[15px] focus:border-brand focus:ring-2 focus:ring-brand-bg"
            />
          </div>
        </div>

        {mode !== "reset" && (
          <div>
            <label htmlFor="password" className="mb-1.5 block text-[13px] font-semibold">
              Password
            </label>
            <div className="relative">
              <Lock size={18} className="pointer-events-none absolute top-1/2 left-3.5 -translate-y-1/2 text-ink-3" />
              <input
                id="password"
                type={show ? "text" : "password"}
                autoComplete={mode === "create" ? "new-password" : "current-password"}
                value={password}
                onChange={(e) => setPassword(e.target.value)}
                className="w-full rounded-2xl border border-line-2 bg-surface-1 py-3.5 pr-12 pl-11 text-[15px] focus:border-brand focus:ring-2 focus:ring-brand-bg"
              />
              <button type="button" aria-label={show ? "Hide password" : "Show password"} onClick={() => setShow((s) => !s)} className="absolute top-1/2 right-3 -translate-y-1/2 rounded-full p-1.5 text-ink-3 hover:bg-hover">
                {show ? <EyeOff size={18} /> : <Eye size={18} />}
              </button>
            </div>
            {mode === "create" && <p className="mt-1.5 text-xs text-ink-3">At least 6 characters.</p>}
          </div>
        )}

        {error && (
          <Banner tone="danger" icon={<AlertCircle size={18} />}>
            {error}
          </Banner>
        )}
        {info && (
          <Banner tone="success" icon={<CheckCircle2 size={18} />}>
            {info}
          </Banner>
        )}

        <Button type="submit" size="lg" full disabled={!canSubmit}>
          {busy === "form" ? "Please wait…" : copy.cta}
        </Button>
      </form>

      <div className="flex items-center justify-between text-sm">
        {mode === "signIn" ? (
          <>
            <button type="button" className="font-semibold text-accent-ink hover:underline" onClick={() => switchMode("reset")}>
              Forgot password?
            </button>
            <button type="button" className="font-semibold text-accent-ink hover:underline" onClick={() => switchMode("create")}>
              Create account
            </button>
          </>
        ) : (
          <button type="button" className="font-semibold text-accent-ink hover:underline" onClick={() => switchMode("signIn")}>
            Back to sign in
          </button>
        )}
      </div>

      <div className="flex items-center gap-3 text-[13px] text-ink-3">
        <span className="h-px flex-1 bg-line" />
        or continue with
        <span className="h-px flex-1 bg-line" />
      </div>

      <Button variant="outline" size="lg" full icon={<GoogleMark />} onClick={() => void google()} disabled={busy !== null} className="bg-surface-1">
        {busy === "google" ? "Opening Google…" : "Google"}
      </Button>
    </main>
  );
}
