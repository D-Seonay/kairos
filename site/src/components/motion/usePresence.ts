"use client";

import { useEffect, useState } from "react";

/** `enter`: just mounted, play the entrance. `exit`: leaving, play the exit then go. */
export type PresencePhase = "static" | "enter" | "exit";

export type PresenceEntry<T> = { key: string; item: T; phase: PresencePhase };

type State<T> = { signature: string; entries: PresenceEntry<T>[] };

/**
 * What AnimatePresence did for this page, with CSS doing the animating: it
 * keeps an item that has left the list in place for `exitMs`, flagged `exit`,
 * and flags a newcomer `enter`. Whatever is there on the first render is
 * `static` (nothing animates on mount), and under reduced motion every change
 * is immediate: no `enter`, no leaving item.
 */
export function usePresence<T>(
  items: T[],
  getKey: (item: T) => string,
  reduced: boolean,
  exitMs: number,
): PresenceEntry<T>[] {
  const signature = items.map(getKey).join("\u0000");
  const [state, setState] = useState<State<T>>(() => ({
    signature,
    entries: items.map((item) => ({ key: getKey(item), item, phase: "static" as const })),
  }));

  let entries = state.entries;
  if (state.signature !== signature) {
    const before = new Map(state.entries.map((entry) => [entry.key, entry]));
    const next: PresenceEntry<T>[] = items.map((item) => {
      const key = getKey(item);
      const old = before.get(key);
      const phase: PresencePhase = reduced ? "static" : old && old.phase !== "exit" ? old.phase : "enter";
      return { key, item, phase };
    });
    if (!reduced) {
      const live = new Set(next.map((entry) => entry.key));
      state.entries.forEach((entry, index) => {
        if (live.has(entry.key)) return;
        next.splice(Math.min(index, next.length), 0, { ...entry, phase: "exit" });
      });
    }
    entries = next;
    setState({ signature, entries: next });
  }

  const leaving = entries.some((entry) => entry.phase === "exit");
  useEffect(() => {
    if (!leaving) return;
    const id = window.setTimeout(
      () => setState((current) => ({ ...current, entries: current.entries.filter((entry) => entry.phase !== "exit") })),
      exitMs,
    );
    return () => window.clearTimeout(id);
  }, [leaving, signature, exitMs]);

  const latest = new Map(items.map((item) => [getKey(item), item]));
  return entries.map((entry) =>
    entry.phase === "exit" ? entry : { ...entry, item: latest.get(entry.key) ?? entry.item },
  );
}
