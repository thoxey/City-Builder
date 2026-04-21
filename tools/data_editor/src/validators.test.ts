import { describe, expect, it } from "vitest";
import { validateCharacter, validatePatron } from "./validators";
import { makeManifest } from "./test/manifestFixture";
import type { CharacterDoc, PatronDoc } from "./types";

const baseChar = (): CharacterDoc => ({
  character_id: "farmer_commercial",
  display_name: "Corn Queen",
  bio: "runs the market",
  patron_id: "aristocrat",       // reuses the existing patron in fixture
  associated_bucket: "commercial",
  arrival_threshold: 10,
  arrival_requires_tier: 1,
  want_building_id: "building_members_club",
  portrait: "",
});

describe("validateCharacter", () => {
  it("passes on a well-formed new character", () => {
    const r = validateCharacter(baseChar(), makeManifest(), { isNew: true });
    expect(r.errors).toEqual([]);
  });

  it("blocks duplicate id on new character", () => {
    const doc = { ...baseChar(), character_id: "aristocrat_commercial" };
    const r = validateCharacter(doc, makeManifest(), { isNew: true });
    expect(r.errors.some((e) => e.includes("already exists"))).toBe(true);
  });

  it("allows keeping the same id when editing", () => {
    const doc = { ...baseChar(), character_id: "aristocrat_commercial" };
    const r = validateCharacter(doc, makeManifest(), {
      isNew: false,
      originalId: "aristocrat_commercial",
    });
    expect(r.errors.some((e) => e.includes("already exists"))).toBe(false);
  });

  it("rejects non-snake_case ids", () => {
    const doc = { ...baseChar(), character_id: "Farmer-Commercial" };
    const r = validateCharacter(doc, makeManifest(), { isNew: true });
    expect(r.errors.some((e) => e.includes("snake_case"))).toBe(true);
  });

  it("rejects unknown patron and want_building", () => {
    const doc = { ...baseChar(), patron_id: "ghost", want_building_id: "building_ghost" };
    const r = validateCharacter(doc, makeManifest(), { isNew: true });
    expect(r.errors.some((e) => e.includes("patron_id"))).toBe(true);
    expect(r.errors.some((e) => e.includes("want_building_id"))).toBe(true);
  });

  it("rejects tier outside 1..3", () => {
    const doc = { ...baseChar(), arrival_requires_tier: 4 };
    const r = validateCharacter(doc, makeManifest(), { isNew: true });
    expect(r.errors.some((e) => e.includes("arrival_requires_tier"))).toBe(true);
  });

  it("warns (not errors) on empty want_building_id", () => {
    const doc = { ...baseChar(), want_building_id: "" };
    const r = validateCharacter(doc, makeManifest(), { isNew: true });
    expect(r.errors).toEqual([]);
    expect(r.warnings.some((w) => w.includes("want_building_id"))).toBe(true);
  });
});

const basePatron = (): PatronDoc => ({
  patron_id: "farmer",
  display_name: "Farmers",
  bio: "till the land",
  character_ids: [
    "aristocrat_residential",
    "aristocrat_commercial",
    "aristocrat_industrial",
  ],
  landmark_building_id: "building_theatre",
  portrait: "",
  donation_area: { shape: "rect", rect: [0, 0, 8, 8] },
});

describe("validatePatron", () => {
  it("passes on a well-formed new patron", () => {
    const r = validatePatron(basePatron(), makeManifest(), { isNew: true });
    expect(r.errors).toEqual([]);
  });

  it("blocks duplicate id on new patron", () => {
    const doc = { ...basePatron(), patron_id: "aristocrat" };
    const r = validatePatron(doc, makeManifest(), { isNew: true });
    expect(r.errors.some((e) => e.includes("already exists"))).toBe(true);
  });

  it("requires exactly 3 characters", () => {
    const doc = { ...basePatron(), character_ids: ["aristocrat_residential"] };
    const r = validatePatron(doc, makeManifest(), { isNew: true });
    expect(r.errors.some((e) => e.includes("exactly 3"))).toBe(true);
  });

  it("blocks duplicate buckets among the 3 characters", () => {
    // two "commercial" characters in the same patron roster
    const manifest = makeManifest({
      characters: [
        ...makeManifest().characters,
        {
          character_id: "farmer_commercial_alt",
          display_name: "Alt",
          bio: "",
          patron_id: "",
          associated_bucket: "commercial",
          arrival_threshold: 10,
          arrival_requires_tier: 1,
          want_building_id: "",
          portrait: "",
          _path: "",
        },
      ],
    });
    const doc = {
      ...basePatron(),
      character_ids: [
        "aristocrat_commercial",
        "farmer_commercial_alt",
        "aristocrat_industrial",
      ],
    };
    const r = validatePatron(doc, manifest, { isNew: true });
    expect(r.errors.some((e) => e.includes("duplicate bucket"))).toBe(true);
  });

  it("requires landmark_building_id", () => {
    const doc = { ...basePatron(), landmark_building_id: "" };
    const r = validatePatron(doc, makeManifest(), { isNew: true });
    expect(r.errors.some((e) => e.includes("landmark_building_id"))).toBe(true);
  });

  it("rejects zero-area donation rect", () => {
    const doc: PatronDoc = {
      ...basePatron(),
      donation_area: { shape: "rect", rect: [0, 0, 0, 0] },
    };
    const r = validatePatron(doc, makeManifest(), { isNew: true });
    expect(r.errors.some((e) => e.includes("rect width and height"))).toBe(true);
  });

  it("warns when landmark is not chain_role=landmark", () => {
    const manifest = makeManifest();
    const doc: PatronDoc = { ...basePatron(), landmark_building_id: "building_brewery" };
    const r = validatePatron(doc, manifest, { isNew: true });
    expect(r.warnings.some((w) => w.includes("chain_role=landmark"))).toBe(true);
  });
});
