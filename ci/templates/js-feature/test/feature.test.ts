import { describe, it, expect, beforeEach } from "vitest";
import * as fc from "fast-check";
import { getOrCreate, clearStore } from "../src/modules/feature/featureService.js";

describe("feature", () => {
  beforeEach(() => clearStore());

  it("AC-006-01: creates feature when not exists", () => {
    const f = getOrCreate("123", "demo");
    expect(f.id).toBe("123");
    expect(f.name).toBe("demo");
  });

  it("AC-006-02: returns existing feature", () => {
    getOrCreate("123", "existing");
    const f = getOrCreate("123", "new");
    expect(f.name).toBe("existing");
  });

  it("AC-006-03: property id round-trips via fast-check", () => {
    fc.assert(
      fc.property(fc.string(), (id) => {
        clearStore();
        const f = getOrCreate(id, "x");
        return f.id === id;
      })
    );
  });
});
