import type {
  DialoguePayload,
  EventDoc,
  Manifest,
  NewspaperPayload,
  NotificationPayload,
} from "../types";
import type { ValidationResult } from "../validators";

const ID_PATTERN = /^[a-z][a-z0-9_]*$/;

export function validateEvent(
  doc: EventDoc,
  manifest: Manifest,
  opts: { isNew: boolean; originalId?: string }
): ValidationResult {
  const errors: string[] = [];
  const warnings: string[] = [];

  if (!doc.event_id) errors.push("event_id is required");
  else if (!ID_PATTERN.test(doc.event_id))
    errors.push("event_id must be snake_case");

  if (opts.isNew || doc.event_id !== opts.originalId) {
    if (manifest.events.some((e) => e.event_id === doc.event_id))
      errors.push(`event_id "${doc.event_id}" already exists`);
  }

  if (!doc.event_type) errors.push("event_type is required");
  else if (!manifest.event_types.includes(doc.event_type))
    errors.push(`event_type "${doc.event_type}" is not registered`);

  if (!doc.trigger.event) errors.push("trigger.event is required");
  else if (!manifest.triggers.includes(doc.trigger.event))
    warnings.push(`trigger.event "${doc.trigger.event}" is not a known trigger`);

  if (doc.trigger.character_id &&
      !manifest.characters.some((c) => c.character_id === doc.trigger.character_id))
    errors.push(`trigger.character_id "${doc.trigger.character_id}" not in manifest`);
  if (doc.trigger.patron_id &&
      !manifest.patrons.some((p) => p.patron_id === doc.trigger.patron_id))
    errors.push(`trigger.patron_id "${doc.trigger.patron_id}" not in manifest`);
  if (doc.trigger.building_id &&
      !manifest.buildings.some((b) => b.building_id === doc.trigger.building_id))
    errors.push(`trigger.building_id "${doc.trigger.building_id}" not in manifest`);

  if (doc.event_type === "dialogue") {
    validateDialogue(doc.payload as DialoguePayload, manifest, errors, warnings);
  } else if (doc.event_type === "newspaper") {
    validateNewspaper(doc.payload as NewspaperPayload, warnings);
  } else if (doc.event_type === "notification") {
    validateNotification(doc.payload as NotificationPayload, errors, warnings);
  }

  return { errors, warnings };
}

function validateDialogue(
  p: DialoguePayload,
  manifest: Manifest,
  errors: string[],
  warnings: string[]
) {
  const ids = new Set<string>();
  for (const n of p.nodes) {
    if (!n.node_id) {
      errors.push("a dialogue node is missing node_id");
      continue;
    }
    if (ids.has(n.node_id))
      errors.push(`duplicate node_id "${n.node_id}"`);
    ids.add(n.node_id);
  }

  if (!p.entry_node_id) errors.push("entry_node_id is required");
  else if (!ids.has(p.entry_node_id))
    errors.push(`entry_node_id "${p.entry_node_id}" is not a defined node`);

  // Options → next references must resolve (or be blank for close).
  for (const n of p.nodes) {
    for (const opt of n.options) {
      if (opt.next && !ids.has(opt.next))
        errors.push(`node "${n.node_id}" option "${opt.label}" points at unknown node "${opt.next}"`);
      for (const eff of opt.effects) {
        validateEffect(eff, manifest, errors, warnings);
      }
    }
    for (const eff of n.on_enter) {
      validateEffect(eff, manifest, errors, warnings);
    }
    if (n.options.length === 0 && n.node_id === p.entry_node_id && p.nodes.length > 1)
      warnings.push(`entry node "${n.node_id}" has no options — player will see a Continue fallback`);
  }

  // Unreachability (warning only — spec says don't block save).
  const reachable = new Set<string>();
  const queue = [p.entry_node_id];
  while (queue.length) {
    const id = queue.shift()!;
    if (!id || reachable.has(id)) continue;
    reachable.add(id);
    const node = p.nodes.find((n) => n.node_id === id);
    if (!node) continue;
    for (const opt of node.options) if (opt.next) queue.push(opt.next);
  }
  for (const n of p.nodes) {
    if (!reachable.has(n.node_id))
      warnings.push(`node "${n.node_id}" is unreachable from the entry`);
  }
}

function validateNewspaper(p: NewspaperPayload, warnings: string[]) {
  if (!p.headline.trim()) warnings.push("newspaper headline is empty");
  if (!p.body.trim()) warnings.push("newspaper body is empty");
}

function validateNotification(p: NotificationPayload, errors: string[], warnings: string[]) {
  if (!p.text.trim()) warnings.push("notification text is empty");
  if (p.duration <= 0) errors.push("notification duration must be > 0");
}

function validateEffect(
  eff: { kind: string; target?: string; amount?: number },
  manifest: Manifest,
  errors: string[],
  warnings: string[]
) {
  switch (eff.kind) {
    case "set_flag":
      if (!eff.target) errors.push("set_flag effect requires target");
      return;
    case "fire_event":
      if (!eff.target) errors.push("fire_event effect requires target event_id");
      else if (!manifest.events.some((e) => e.event_id === eff.target))
        warnings.push(`fire_event target "${eff.target}" not in manifest`);
      return;
    case "discount_cost":
      if (!eff.target) errors.push("discount_cost effect requires target building_id");
      else if (!manifest.buildings.some((b) => b.building_id === eff.target))
        warnings.push(`discount_cost target "${eff.target}" not in manifest`);
      if ((eff.amount ?? 0) <= 0) errors.push("discount_cost amount must be > 0");
      return;
    case "delay_want":
      if (!eff.target) errors.push("delay_want effect requires target character_id");
      else if (!manifest.characters.some((c) => c.character_id === eff.target))
        warnings.push(`delay_want target "${eff.target}" not in manifest`);
      if ((eff.amount ?? 0) <= 0) errors.push("delay_want amount must be > 0");
      return;
    case "emit_signal":
      if (!eff.target) errors.push("emit_signal effect requires target signal name");
      return;
    default:
      warnings.push(`unknown effect kind "${eff.kind}"`);
  }
}
