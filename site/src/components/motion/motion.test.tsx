import { act, cleanup, render, renderHook } from "@testing-library/react";
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import { usePresence } from "./usePresence";
import { useSpringNumber } from "./useSpringNumber";

afterEach(() => {
  cleanup();
  vi.useRealTimers();
  vi.restoreAllMocks();
});

describe("usePresence", () => {
  const key = (value: string) => value;

  it("shows what is there on the first render as static", () => {
    const { result } = renderHook(() => usePresence(["a", "b"], key, false, 100));
    expect(result.current.map((e) => [e.key, e.phase])).toEqual([
      ["a", "static"],
      ["b", "static"],
    ]);
  });

  it("flags a newcomer as entering and keeps the leaver for the exit time", () => {
    vi.useFakeTimers();
    const { result, rerender } = renderHook(({ items }) => usePresence(items, key, false, 100), {
      initialProps: { items: ["a"] },
    });
    rerender({ items: ["b"] });
    expect(result.current.map((e) => [e.key, e.phase])).toEqual([
      ["a", "exit"],
      ["b", "enter"],
    ]);
    act(() => {
      vi.advanceTimersByTime(120);
    });
    expect(result.current.map((e) => [e.key, e.phase])).toEqual([["b", "enter"]]);
  });

  it("changes at once under reduced motion: no entrance, no leaver", () => {
    const { result, rerender } = renderHook(({ items }) => usePresence(items, key, true, 100), {
      initialProps: { items: ["a"] },
    });
    rerender({ items: ["b"] });
    expect(result.current.map((e) => [e.key, e.phase])).toEqual([["b", "static"]]);
  });
});

describe("useSpringNumber", () => {
  let now = 0;
  let queue: FrameRequestCallback[] = [];

  beforeEach(() => {
    now = 0;
    queue = [];
    vi.spyOn(performance, "now").mockImplementation(() => now);
    vi.stubGlobal("requestAnimationFrame", (callback: FrameRequestCallback) => queue.push(callback));
    vi.stubGlobal("cancelAnimationFrame", () => {
      queue = [];
    });
  });

  afterEach(() => {
    vi.unstubAllGlobals();
  });

  function run(frames: number) {
    for (let i = 0; i < frames; i += 1) {
      const callbacks = queue;
      queue = [];
      now += 16;
      act(() => callbacks.forEach((callback) => callback(now)));
    }
  }

  function Probe({ target, reduced }: { target: number; reduced: boolean }) {
    const value = useSpringNumber(target, reduced, { stiffness: 90, damping: 13 });
    return <output>{value}</output>;
  }

  it("starts at its target, follows a new one and settles on it", () => {
    const { container, rerender } = render(<Probe target={50} reduced={false} />);
    const read = () => Number(container.querySelector("output")?.textContent);
    expect(read()).toBe(50);

    rerender(<Probe target={80} reduced={false} />);
    run(10);
    expect(read()).toBeGreaterThan(50);
    expect(read()).not.toBe(80);

    run(400);
    expect(read()).toBe(80);
  });

  it("is its target at once under reduced motion", () => {
    const { container, rerender } = render(<Probe target={50} reduced />);
    rerender(<Probe target={10} reduced />);
    expect(Number(container.querySelector("output")?.textContent)).toBe(10);
  });
});
