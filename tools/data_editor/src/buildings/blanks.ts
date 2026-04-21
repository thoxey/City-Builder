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
    case "PoliceMetadata":
    case "MedicalMetadata":
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
  }
}

export const ALL_PROFILE_TYPES: ProfileType[] = [
  "BuildingMetadata",
  "BuildingProfile",
  "UniqueProfile",
  "GenericTierProfile",
  "PoliceMetadata",
  "MedicalMetadata",
  "RoadMetadata",
];
