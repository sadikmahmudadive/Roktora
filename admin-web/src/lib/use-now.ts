"use client";

import { useSyncExternalStore } from "react";

function subscribe(cb: () => void) {
  const t = setInterval(cb, 30_000);
  return () => clearInterval(t);
}

/**
 * The current time, refreshed every half minute. Returns null during server/prerender and on the
 * first client render, so nothing time-dependent is baked into prerendered HTML.
 */
export function useNow(): Date | null {
  const minute = useSyncExternalStore(
    subscribe,
    () => Math.floor(Date.now() / 60_000) * 60_000,
    () => 0,
  );
  return minute === 0 ? null : new Date(minute);
}
