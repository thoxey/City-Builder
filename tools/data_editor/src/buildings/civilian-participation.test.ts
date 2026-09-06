import { describe, expect, it } from "vitest";
import type { BuildingDoc, CommunityEffectEntry, CommunityEffectProfileEntry } from "../types";
import { makeManifest } from "../test/manifestFixture";
import { validateBuilding } from "./validation";
import pub from "../../../../data/buildings/unique/building_pub.json";
import restaurant from "../../../../data/buildings/unique/building_restaurant.json";
import membersClub from "../../../../data/buildings/unique/building_members_club.json";
import crazyGolf from "../../../../data/buildings/unique/building_crazy_golf.json";
import townHall from "../../../../data/buildings/unique/building_town_hall.json";
import pirateRadio from "../../../../data/buildings/unique/building_pirate_radio.json";
import theatre from "../../../../data/buildings/unique/building_theatre.json";

const docs = {building_pub:pub, building_restaurant:restaurant, building_members_club:membersClub,
  building_crazy_golf:crazyGolf, building_town_hall:townHall, building_pirate_radio:pirateRadio,
  building_theatre:theatre};

function load(name: string): BuildingDoc {
  return structuredClone(docs[name as keyof typeof docs]) as unknown as BuildingDoc;
}

function effects(doc: BuildingDoc): CommunityEffectEntry[] {
  return doc.profiles
    .filter((profile): profile is CommunityEffectProfileEntry => profile.type === "CommunityEffectProfile")
    .flatMap((profile) => [profile.effects ?? [], ...Object.values(profile.programmes ?? {}).map((value) => Array.isArray(value) ? value : value.effects)])
    .flat();
}

describe("civilian participation authoring", () => {
  it.each([
    ["building_pub", "participant"], ["building_restaurant", "participant"],
    ["building_members_club", "participant"], ["building_crazy_golf", "participant"],
    ["building_town_hall", "local_only"], ["building_pirate_radio", "productive"],
    ["building_theatre", "participant"],
  ])("records one explicit role for %s", (name, role) => {
    expect(load(name).community_role).toBe(role);
  });

  it.each(["building_pub", "building_restaurant", "building_members_club", "building_crazy_golf", "building_theatre"])(
    "%s has valid scheduled participant capacity", (name) => {
      const doc = load(name); const participantEffects = effects(doc).filter((effect) => effect.scope === "participant");
      expect(participantEffects.length).toBeGreaterThan(0);
      for (const effect of participantEffects) {
        expect(effect.capacity).toBeGreaterThan(0);
        expect(effect.schedule).toEqual(expect.objectContaining({start: expect.any(Number), end: expect.any(Number)}));
      }
      const relevantErrors = validateBuilding(doc, makeManifest(), {isNew:false, originalId:doc.building_id}).errors
        .filter((error) => /community|participant|effect|capacity|schedule/i.test(error));
      expect(relevantErrors).toEqual([]);
    });

  it("accepts an overnight participant range and rejects a missing schedule", () => {
    const overnight = load("building_members_club");
    expect(effects(overnight).find((effect) => effect.scope === "participant")?.schedule).toEqual({start:18,end:2});
    const broken = structuredClone(overnight); delete effects(broken)[0].schedule;
    expect(validateBuilding(broken, makeManifest(), {isNew:false, originalId:broken.building_id}).errors.some((error) => error.includes("schedule"))).toBe(true);
  });
});
