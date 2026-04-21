// Shape of res://data/events/_manifest.json, written by the Godot editor plugin.
// Matches addons/data_editor_tools/manifest_exporter.gd. Keep in sync.

export type Bucket = "residential" | "commercial" | "industrial";
export type CharacterState =
  | "NOT_ARRIVED"
  | "ARRIVED"
  | "WANT_REVEALED"
  | "SATISFIED"
  | "CONTRIBUTES_TO_LANDMARK";
export type PatronState = "LOCKED" | "LANDMARK_AVAILABLE" | "COMPLETED";
export type BuildingCategory = "road" | "nature" | "generic" | "unique";
export type EventType = "dialogue" | "newspaper" | "notification";

export interface ManifestCharacter {
  character_id: string;
  display_name: string;
  bio: string;
  patron_id: string;
  associated_bucket: Bucket | "";
  arrival_threshold: number;
  arrival_requires_tier: number;
  want_building_id: string;
  portrait: string;
  _path: string;
}

export interface ManifestPatron {
  patron_id: string;
  display_name: string;
  bio: string;
  character_ids: string[];
  landmark_building_id: string;
  portrait: string;
  donation_area: DonationArea;
  _path: string;
}

export interface DonationAreaRect {
  shape: "rect";
  rect: [number, number, number, number]; // x, y, w, h
}
export interface DonationAreaPolygon {
  shape: "polygon";
  points: Array<[number, number]>;
}
export type DonationArea = DonationAreaRect | DonationAreaPolygon | Record<string, never>;

export interface ManifestBuilding {
  building_id: string;
  display_name: string;
  category: BuildingCategory | "";
  pool_id: string;
  model_path: string;
  chain_role: string; // "" | "chain" | "want" | "landmark"
  patron_id: string;
  character_id: string;
  bucket: Bucket | "";
  tier: number;
  _path: string;
}

export interface ManifestEvent {
  event_id: string;
  event_type: EventType | "";
  trigger_event: string;
  trigger_character_id: string;
  trigger_patron_id: string;
  trigger_building_id: string;
  enabled_if: string;
  category: string;
  _path: string;
}

export interface Manifest {
  exported_at: string;
  event_types: EventType[];
  triggers: string[];
  buckets: Bucket[];
  categories: BuildingCategory[];
  character_states: CharacterState[];
  patron_states: PatronState[];
  characters: ManifestCharacter[];
  patrons: ManifestPatron[];
  buildings: ManifestBuilding[];
  events: ManifestEvent[];
  flags: string[];
}

// ---- JSON file shapes on disk (matches data/characters/*.json etc.) ----

export interface CharacterDoc {
  character_id: string;
  display_name: string;
  bio: string;
  patron_id: string;
  associated_bucket: Bucket | "";
  arrival_threshold: number;
  arrival_requires_tier: number;
  want_building_id: string;
  portrait: string;
}

export interface PatronDoc {
  patron_id: string;
  display_name: string;
  bio: string;
  character_ids: string[];
  landmark_building_id: string;
  portrait: string;
  donation_area: DonationArea;
}
