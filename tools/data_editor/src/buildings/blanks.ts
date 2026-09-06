import type { BuildingDoc, Profile, ProfileType } from "../types";

export function blankBuilding(): BuildingDoc {
  return {
    building_id: "",
    display_name: "",
    description: "",
    model_path: "",
    model_scale: 1,
    model_offset: [0, 0, 0],
    model_rotation_y: 0,
    footprint: [[0, 0]],
    category: "",
    palette_excluded: false,
    profiles: [],
    tags: [],
  };
}

export function cloneBuilding(doc: BuildingDoc): BuildingDoc {
  return JSON.parse(JSON.stringify(doc)) as BuildingDoc;
}

export function blankProfile(type: ProfileType): Profile {
  switch (type) {
    case "BuildingMetadata":
      return { type };
    case "BuildingProfile":
      return {
        type: "BuildingProfile",
        category: "residential",
        capacity: 0,
        active_start: 6,
        active_end: 21,
      };
    case "UniqueProfile":
      return {
        type: "UniqueProfile",
        bucket: "residential",
        tier: 1,
        patron_id: "",
        character_id: "",
        chain_role: "chain",
        prerequisite_threshold: 0,
        prerequisite_ids: [],
        desirability_boost: 0,
      };
    case "GenericTierProfile":
      return {
        type: "GenericTierProfile",
        bucket: "residential",
        tier: 1,
        pool_id: "",
      };
    case "RoadMetadata":
      return { type: "RoadMetadata", road_type: 0, connections: [] };
    case "AttractivenessProfile":
      return {
        type: "AttractivenessProfile",
        base: 0,
        residential: 0,
        commercial: 0,
        industrial: 0,
        nature: 0,
        radius: 1,
      };
    case "CommunityEffectProfile":
      return {
        type: "CommunityEffectProfile",
        effects: [],
      };
  }
}

export const ALL_PROFILE_TYPES: ProfileType[] = [
  "BuildingMetadata",
  "BuildingProfile",
  "UniqueProfile",
  "GenericTierProfile",
  "RoadMetadata",
  "AttractivenessProfile",
  "CommunityEffectProfile",
];
