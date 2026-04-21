import type {
  CharacterDoc,
  Manifest,
  PatronDoc,
} from "./types";

export interface ValidationResult {
  errors: string[];     // block save
  warnings: string[];   // allow save
}

const ID_PATTERN = /^[a-z][a-z0-9_]*$/;

export function validateCharacter(
  doc: CharacterDoc,
  manifest: Manifest,
  opts: { isNew: boolean; originalId?: string }
): ValidationResult {
  const errors: string[] = [];
  const warnings: string[] = [];

  if (!doc.character_id) errors.push("character_id is required");
  else if (!ID_PATTERN.test(doc.character_id))
    errors.push("character_id must be snake_case (lowercase letters, digits, underscores)");

  if (opts.isNew || doc.character_id !== opts.originalId) {
    if (manifest.characters.some((c) => c.character_id === doc.character_id))
      errors.push(`character_id "${doc.character_id}" already exists`);
  }

  if (!doc.display_name.trim()) warnings.push("display_name is empty");
  if (!doc.bio.trim()) warnings.push("bio is empty");

  if (!doc.patron_id) errors.push("patron_id is required");
  else if (!manifest.patrons.some((p) => p.patron_id === doc.patron_id))
    errors.push(`patron_id "${doc.patron_id}" not in manifest — author patron first`);

  if (!doc.associated_bucket) errors.push("associated_bucket is required");

  if (doc.arrival_threshold < 0) errors.push("arrival_threshold must be ≥ 0");
  if (doc.arrival_requires_tier < 1 || doc.arrival_requires_tier > 3)
    errors.push("arrival_requires_tier must be 1, 2, or 3");

  if (doc.want_building_id) {
    if (!manifest.buildings.some((b) => b.building_id === doc.want_building_id))
      errors.push(`want_building_id "${doc.want_building_id}" not in manifest`);
  } else {
    warnings.push("want_building_id is empty — character will never become satisfied");
  }

  return { errors, warnings };
}

export function validatePatron(
  doc: PatronDoc,
  manifest: Manifest,
  opts: { isNew: boolean; originalId?: string }
): ValidationResult {
  const errors: string[] = [];
  const warnings: string[] = [];

  if (!doc.patron_id) errors.push("patron_id is required");
  else if (!ID_PATTERN.test(doc.patron_id))
    errors.push("patron_id must be snake_case");

  if (opts.isNew || doc.patron_id !== opts.originalId) {
    if (manifest.patrons.some((p) => p.patron_id === doc.patron_id))
      errors.push(`patron_id "${doc.patron_id}" already exists`);
  }

  if (!doc.display_name.trim()) warnings.push("display_name is empty");
  if (!doc.bio.trim()) warnings.push("bio is empty");

  if (doc.character_ids.length !== 3)
    errors.push("character_ids must list exactly 3 characters");

  const buckets = new Set<string>();
  for (const cid of doc.character_ids) {
    if (!cid) {
      errors.push("a character slot is empty");
      continue;
    }
    const c = manifest.characters.find((x) => x.character_id === cid);
    if (!c) {
      errors.push(`character "${cid}" not in manifest`);
      continue;
    }
    if (c.patron_id !== doc.patron_id && c.patron_id !== "")
      warnings.push(`${cid} is currently assigned to patron "${c.patron_id}"`);
    if (c.associated_bucket) {
      if (buckets.has(c.associated_bucket))
        errors.push(`duplicate bucket "${c.associated_bucket}" — patron needs one of each`);
      buckets.add(c.associated_bucket);
    }
  }

  if (doc.landmark_building_id) {
    const b = manifest.buildings.find(
      (x) => x.building_id === doc.landmark_building_id
    );
    if (!b)
      errors.push(`landmark_building_id "${doc.landmark_building_id}" not in manifest`);
    else if (b.chain_role !== "landmark")
      warnings.push(`"${doc.landmark_building_id}" is not marked chain_role=landmark`);
  } else {
    errors.push("landmark_building_id is required");
  }

  if (doc.donation_area && "shape" in doc.donation_area) {
    if (doc.donation_area.shape === "rect") {
      const [, , w, h] = doc.donation_area.rect;
      if (w <= 0 || h <= 0)
        errors.push("donation_area rect width and height must be > 0");
    }
  } else {
    warnings.push("donation_area is empty");
  }

  return { errors, warnings };
}
