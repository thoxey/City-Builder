import type { EventTrigger } from "../types";

// Categories the EventsTab UI presents in the top-level "Source" dropdown.
// The category is *derived* from trigger.event on load (events on disk only
// store the trigger fields, not a category) — see sourceForEvent below.
export type TriggerSource =
  | "character"
  | "patron"
  | "building"
  | "bucket"
  | "world"
  | "manual";

export interface TriggerSourceMeta {
  id: TriggerSource;
  label: string;
  events: string[];          // trigger.event names that belong to this source
  filterField:
    | "character_id"
    | "patron_id"
    | "building_id"
    | "bucket_type_id"
    | null;                   // null = no per-trigger filter (world / manual)
  description: string;
}

export const TRIGGER_SOURCES: TriggerSourceMeta[] = [
  {
    id: "character",
    label: "Character",
    events: [
      "character_arrived",
      "character_want_revealed",
      "character_satisfied",
      "character_state_changed",
    ],
    filterField: "character_id",
    description: "Fires on a per-character lifecycle beat.",
  },
  {
    id: "patron",
    label: "Patron",
    events: ["patron_landmark_ready", "patron_landmark_completed"],
    filterField: "patron_id",
    description: "Fires when a patron crosses a landmark milestone.",
  },
  {
    id: "building",
    label: "Building",
    events: ["unique_placed"],
    filterField: "building_id",
    description: "Fires when a unique building is placed on the map.",
  },
  {
    id: "bucket",
    label: "Demand bucket",
    events: [
      "demand_unserved_changed",
      "demand_total_changed",
      "demand_fulfilled_changed",
    ],
    filterField: "bucket_type_id",
    description:
      "Fires when a bucket's total / fulfilled / unserved value moves. Pair with enabled_if (e.g. fulfilled.housing_demand >= 50) for thresholds.",
  },
  {
    id: "world",
    label: "World",
    events: ["buildable_area_expanded"],
    filterField: null,
    description: "World-level events that don't filter by a single subject.",
  },
  {
    id: "manual",
    label: "Manual",
    events: ["manual"],
    filterField: null,
    description:
      "Fired explicitly via fire_event effects. Has no signal subscription on its own.",
  },
];

const EVENT_TO_SOURCE: Record<string, TriggerSource> = (() => {
  const out: Record<string, TriggerSource> = {};
  for (const s of TRIGGER_SOURCES) {
    for (const e of s.events) out[e] = s.id;
  }
  return out;
})();

/** Determine which Source dropdown a trigger belongs in, derived from its event name. */
export function sourceForEvent(eventName: string): TriggerSource {
  return EVENT_TO_SOURCE[eventName] ?? "manual";
}

export function metaForSource(source: TriggerSource): TriggerSourceMeta {
  return TRIGGER_SOURCES.find((s) => s.id === source) ?? TRIGGER_SOURCES[5];
}

/** Strip filter fields that are no longer relevant to the chosen source. */
export function pruneTriggerForSource(
  trigger: EventTrigger,
  source: TriggerSource
): EventTrigger {
  const keep = metaForSource(source).filterField;
  const next: EventTrigger = { event: trigger.event };
  if (keep === "character_id" && trigger.character_id) next.character_id = trigger.character_id;
  if (keep === "patron_id" && trigger.patron_id) next.patron_id = trigger.patron_id;
  if (keep === "building_id" && trigger.building_id) next.building_id = trigger.building_id;
  if (keep === "bucket_type_id" && trigger.bucket_type_id)
    next.bucket_type_id = trigger.bucket_type_id;
  return next;
}
