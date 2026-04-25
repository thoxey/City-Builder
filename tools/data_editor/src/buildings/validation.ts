import type { BuildingDoc, Manifest, Profile } from "../types";
import type { ValidationResult } from "../validators";

const ID_PATTERN = /^[a-z][a-z0-9_]*$/;

export function validateBuilding(
  doc: BuildingDoc,
  manifest: Manifest,
  opts: { isNew: boolean; originalId?: string }
): ValidationResult {
  const errors: string[] = [];
  const warnings: string[] = [];

  if (!doc.building_id) errors.push("building_id is required");
  else if (!ID_PATTERN.test(doc.building_id))
    errors.push("building_id must be snake_case");

  if (opts.isNew || doc.building_id !== opts.originalId) {
    if (manifest.buildings.some((b) => b.building_id === doc.building_id))
      errors.push(`building_id "${doc.building_id}" already exists`);
  }

  if (!doc.display_name.trim()) warnings.push("display_name is empty");
  if (!doc.model_path) warnings.push("model_path is empty");
  else if (!doc.model_path.startsWith("res://"))
    warnings.push("model_path should start with res://");
  else if (!doc.model_path.endsWith(".glb"))
    warnings.push("model_path should point at a .glb file");

  if (!doc.category) errors.push("category is required");
  else if (!manifest.categories.includes(doc.category))
    errors.push(`category "${doc.category}" is not registered`);

  if (doc.footprint.length === 0)
    errors.push("footprint must contain at least one cell");
  for (const [x, y] of doc.footprint) {
    if (!Number.isFinite(x) || !Number.isFinite(y))
      errors.push(`footprint cell [${x}, ${y}] is invalid`);
  }
  // Duplicate footprint cells are almost always a mistake.
  const seen = new Set<string>();
  for (const [x, y] of doc.footprint) {
    const k = `${x},${y}`;
    if (seen.has(k)) warnings.push(`duplicate footprint cell [${x}, ${y}]`);
    seen.add(k);
  }

  if (doc.model_scale <= 0) errors.push("model_scale must be > 0");

  for (const p of doc.profiles) {
    validateProfile(p, manifest, doc, errors, warnings);
  }

  return { errors, warnings };
}

function validateProfile(
  p: Profile,
  manifest: Manifest,
  doc: BuildingDoc,
  errors: string[],
  warnings: string[]
) {
  switch (p.type) {
    case "BuildingProfile":
      if (!p.category) errors.push("BuildingProfile requires category");
      if (p.capacity < 0) errors.push("BuildingProfile capacity must be ≥ 0");
      if (p.active_start < 0 || p.active_start > 24)
        errors.push("active_start must be between 0 and 24");
      if (p.active_end < 0 || p.active_end > 24)
        errors.push("active_end must be between 0 and 24");
      return;
    case "UniqueProfile":
      if (!p.bucket) errors.push("UniqueProfile requires bucket");
      if (p.tier < 0) errors.push("UniqueProfile tier must be ≥ 0");
      if (p.patron_id &&
          !manifest.patrons.some((pt) => pt.patron_id === p.patron_id))
        warnings.push(`UniqueProfile.patron_id "${p.patron_id}" not in manifest`);
      if (p.character_id &&
          !manifest.characters.some((c) => c.character_id === p.character_id))
        warnings.push(`UniqueProfile.character_id "${p.character_id}" not in manifest`);
      for (const pre of p.prerequisite_ids) {
        if (!manifest.buildings.some((b) => b.building_id === pre) && pre !== doc.building_id)
          warnings.push(`UniqueProfile prerequisite "${pre}" not in manifest`);
      }
      if (p.desirability_boost < 0)
        warnings.push("UniqueProfile desirability_boost is negative");
      return;
    case "GenericTierProfile":
      if (!p.bucket) errors.push("GenericTierProfile requires bucket");
      if (!p.pool_id) errors.push("GenericTierProfile requires pool_id");
      if (p.tier < 1) errors.push("GenericTierProfile tier must be ≥ 1");
      return;
    case "RoadMetadata":
      if (p.road_type < 0) errors.push("RoadMetadata road_type must be ≥ 0");
      return;
    case "BuildingMetadata":
      return;
  }
}
