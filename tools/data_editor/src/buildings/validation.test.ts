import { describe, expect, it } from "vitest";
import { validateBuilding } from "./validation";
import { blankBuilding, blankProfile, cloneBuilding } from "./blanks";
import { makeManifest } from "../test/manifestFixture";
import type { BuildingDoc, UniqueProfile } from "../types";

function newUnique(): BuildingDoc {
  const doc = blankBuilding();
  doc.building_id = "building_new_theatre";
  doc.display_name = "New Theatre";
  doc.model_path = "res://models/new_theatre/new_theatre.glb";
  doc.category = "unique";
  return doc;
}

describe("validateBuilding — top level", () => {
  it("passes on a minimal well-formed building", () => {
    const r = validateBuilding(newUnique(), makeManifest(), { isNew: true });
    expect(r.errors).toEqual([]);
  });

  it("blocks duplicate building_id", () => {
    const doc = newUnique();
    doc.building_id = "building_members_club";
    const r = validateBuilding(doc, makeManifest(), { isNew: true });
    expect(r.errors.some((e) => e.includes("already exists"))).toBe(true);
  });

  it("rejects empty category", () => {
    const doc = newUnique();
    doc.category = "";
    const r = validateBuilding(doc, makeManifest(), { isNew: true });
    expect(r.errors.some((e) => e.includes("category"))).toBe(true);
  });

  it("requires at least one footprint cell", () => {
    const doc = newUnique();
    doc.footprint = [];
    const r = validateBuilding(doc, makeManifest(), { isNew: true });
    expect(r.errors.some((e) => e.includes("footprint"))).toBe(true);
  });

  it("warns on duplicate footprint cells", () => {
    const doc = newUnique();
    doc.footprint = [[0, 0], [0, 0]];
    const r = validateBuilding(doc, makeManifest(), { isNew: true });
    expect(r.warnings.some((w) => w.includes("duplicate footprint"))).toBe(true);
  });

  it("warns on suspicious model_path", () => {
    const doc = newUnique();
    doc.model_path = "./foo.glb";
    const r = validateBuilding(doc, makeManifest(), { isNew: true });
    expect(r.warnings.some((w) => w.includes("res://"))).toBe(true);
  });

  it("rejects non-positive model_scale", () => {
    const doc = newUnique();
    doc.model_scale = 0;
    const r = validateBuilding(doc, makeManifest(), { isNew: true });
    expect(r.errors.some((e) => e.includes("model_scale"))).toBe(true);
  });
});

describe("validateBuilding — profiles", () => {
  it("errors on BuildingProfile with empty category", () => {
    const doc = newUnique();
    doc.profiles = [blankProfile("BuildingProfile")];
    (doc.profiles[0] as { category: string }).category = "";
    const r = validateBuilding(doc, makeManifest(), { isNew: true });
    expect(r.errors.some((e) => e.includes("BuildingProfile requires category"))).toBe(true);
  });

  it("errors on GenericTierProfile missing pool_id", () => {
    const doc = newUnique();
    doc.category = "generic";
    doc.profiles = [blankProfile("GenericTierProfile")];
    (doc.profiles[0] as { pool_id: string }).pool_id = "";
    const r = validateBuilding(doc, makeManifest(), { isNew: true });
    expect(r.errors.some((e) => e.includes("pool_id"))).toBe(true);
  });

  it("warns on UniqueProfile referencing unknown patron", () => {
    const doc = newUnique();
    const prof = blankProfile("UniqueProfile") as UniqueProfile;
    prof.patron_id = "ghost";
    doc.profiles = [prof];
    const r = validateBuilding(doc, makeManifest(), { isNew: true });
    expect(r.warnings.some((w) => w.includes("patron_id"))).toBe(true);
  });

  it("accepts UniqueProfile with known patron and character", () => {
    const doc = newUnique();
    const prof = blankProfile("UniqueProfile") as UniqueProfile;
    prof.patron_id = "aristocrat";
    prof.character_id = "aristocrat_commercial";
    prof.bucket = "commercial";
    prof.chain_role = "chain";
    doc.profiles = [prof];
    const r = validateBuilding(doc, makeManifest(), { isNew: true });
    expect(r.errors).toEqual([]);
  });

  it("warns on UniqueProfile prereq referencing missing building", () => {
    const doc = newUnique();
    const prof = blankProfile("UniqueProfile") as UniqueProfile;
    prof.prerequisite_ids = ["building_ghost"];
    doc.profiles = [prof];
    const r = validateBuilding(doc, makeManifest(), { isNew: true });
    expect(r.warnings.some((w) => w.includes("prerequisite"))).toBe(true);
  });
});

describe("blanks", () => {
  it("cloneBuilding produces an independent copy", () => {
    const a = blankBuilding();
    a.building_id = "x";
    const b = cloneBuilding(a);
    b.building_id = "y";
    expect(a.building_id).toBe("x");
    expect(b.building_id).toBe("y");
  });

  it("blankProfile returns the right shape per type", () => {
    const a = blankProfile("UniqueProfile");
    expect(a.type).toBe("UniqueProfile");
    const b = blankProfile("BuildingMetadata");
    expect(Object.keys(b)).toEqual(["type"]);
  });
});
