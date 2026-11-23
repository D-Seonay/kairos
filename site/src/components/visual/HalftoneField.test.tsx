import { act, render } from "@testing-library/react";
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import { HalftoneField } from "./HalftoneField";

type Callback = (time: number) => void;

let rafQueue: Map<number, Callback>;
let rafId: number;
let rafCalls: number;
let ctx: Record<string, ReturnType<typeof vi.fn>>;
let intersect: (isIntersecting: boolean) => void;
let reducedMotion: boolean;

function setVisibility(state: "visible" | "hidden") {
  Object.defineProperty(document, "visibilityState", { configurable: true, value: state });
  document.dispatchEvent(new Event("visibilitychange"));
}

function flushFrame(time = 16) {
  const callbacks = [...rafQueue.values()];
  rafQueue.clear();
  for (const cb of callbacks) cb(time);
}

beforeEach(() => {
  rafQueue = new Map();
  rafId = 0;
  rafCalls = 0;
  reducedMotion = false;
  ctx = {
    setTransform: vi.fn(),
    clearRect: vi.fn(),
    beginPath: vi.fn(),
    moveTo: vi.fn(),
    arc: vi.fn(),
    fill: vi.fn(),
  };
  vi.stubGlobal(
    "requestAnimationFrame",
    vi.fn((cb: Callback) => {
      rafCalls += 1;
      rafId += 1;
      rafQueue.set(rafId, cb);
      return rafId;
    }),
  );
  vi.stubGlobal(
    "cancelAnimationFrame",
    vi.fn((id: number) => {
      rafQueue.delete(id);
    }),
  );
  vi.stubGlobal(
    "IntersectionObserver",
    class {
      constructor(cb: (entries: { isIntersecting: boolean }[]) => void) {
        intersect = (isIntersecting) => cb([{ isIntersecting }]);
      }
      observe() {}
      unobserve() {}
      disconnect() {}
    },
  );
  vi.stubGlobal(
    "matchMedia",
    vi.fn((query: string) => ({
      matches: reducedMotion && query.includes("reduce"),
      media: query,
      addEventListener: vi.fn(),
      removeEventListener: vi.fn(),
    })),
  );
  vi.spyOn(HTMLCanvasElement.prototype, "getContext").mockImplementation(
    () => ctx as unknown as CanvasRenderingContext2D,
  );
  Object.defineProperty(HTMLElement.prototype, "clientWidth", { configurable: true, value: 400 });
  Object.defineProperty(HTMLElement.prototype, "clientHeight", { configurable: true, value: 300 });
  setVisibility("visible");
});

afterEach(() => {
  vi.unstubAllGlobals();
  vi.restoreAllMocks();
  Reflect.deleteProperty(HTMLElement.prototype, "clientWidth");
  Reflect.deleteProperty(HTMLElement.prototype, "clientHeight");
});

describe("HalftoneField", () => {
  it("renders an aria-hidden canvas", () => {
    const { container } = render(<HalftoneField light={0.5} ink={1} />);
    const canvas = container.querySelector("canvas");
    expect(canvas).not.toBeNull();
    expect(canvas).toHaveAttribute("aria-hidden", "true");
  });

  it("does not loop until the field is in view", () => {
    render(<HalftoneField light={0.5} ink={1} />);
    expect(rafCalls).toBe(0);
    act(() => intersect(true));
    expect(rafCalls).toBeGreaterThan(0);
  });

  it("stops requesting frames once the tab is hidden", () => {
    render(<HalftoneField light={0.5} ink={1} />);
    act(() => intersect(true));
    act(() => flushFrame());
    const before = rafCalls;
    expect(before).toBeGreaterThan(0);

    act(() => setVisibility("hidden"));
    act(() => flushFrame());
    act(() => flushFrame());
    expect(rafCalls).toBe(before);
    expect(rafQueue.size).toBe(0);
  });

  it("stops the loop when the field leaves the viewport and resumes on return", () => {
    render(<HalftoneField light={0.5} ink={1} />);
    act(() => intersect(true));
    act(() => flushFrame());
    act(() => intersect(false));
    const painted = ctx.fill.mock.calls.length;
    act(() => flushFrame());
    act(() => flushFrame());
    expect(ctx.fill.mock.calls.length).toBe(painted);

    act(() => intersect(true));
    act(() => flushFrame());
    expect(ctx.fill.mock.calls.length).toBeGreaterThan(painted);
  });

  it("draws one static frame and never loops under reduced motion", () => {
    reducedMotion = true;
    render(<HalftoneField light={0.5} ink={1} interactive />);
    act(() => intersect(true));
    act(() => flushFrame());
    expect(rafCalls).toBe(0);
    expect(ctx.fill).toHaveBeenCalledTimes(1);
  });

  it("caps the backing store at a device pixel ratio of 2", () => {
    vi.stubGlobal("devicePixelRatio", 3);
    const { container } = render(<HalftoneField light={0.5} ink={1} />);
    const canvas = container.querySelector("canvas") as HTMLCanvasElement;
    expect(canvas.width).toBe(800);
    expect(canvas.height).toBe(600);
  });
});
