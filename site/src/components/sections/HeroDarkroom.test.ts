import { describe, expect, it } from "vitest";
import { fieldAt } from "./HeroDarkroom";

describe("fieldAt", () => {
  it("starts with nothing developed", () => {
    expect(fieldAt(0)).toEqual({ ink: 0, light: 0 });
  });

  it("ends on the finished print, light 0.8, about 2 s in", () => {
    expect(fieldAt(2)).toEqual({ ink: 1, light: 0.8 });
    expect(fieldAt(10)).toEqual({ ink: 1, light: 0.8 });
  });

  it("only ever develops forward", () => {
    let previous = fieldAt(0);
    for (let t = 0.05; t <= 2.2; t += 0.05) {
      const next = fieldAt(t);
      expect(next.ink).toBeGreaterThanOrEqual(previous.ink);
      expect(next.light).toBeGreaterThanOrEqual(previous.light);
      previous = next;
    }
  });
});
