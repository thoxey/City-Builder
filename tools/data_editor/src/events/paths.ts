import type { EventDoc } from "../types";

// Where a NEW event goes. Existing events preserve their `_path` from the
// manifest — we only compute a path here when the author creates an event
// from scratch. Mirrors the folder layout the game author has settled on
// (characters / patrons / newspaper / notifications / shared).

export function defaultPathForNewEvent(doc: EventDoc): string[] {
  const filename = `${doc.event_id || "new_event"}.json`;
  if (doc.event_type === "newspaper") {
    return ["data", "events", "newspaper", filename];
  }
  if (doc.event_type === "notification") {
    return ["data", "events", "notifications", filename];
  }
  // dialogue
  if (doc.trigger.character_id)
    return ["data", "events", "characters", doc.trigger.character_id, filename];
  if (doc.trigger.patron_id)
    return ["data", "events", "patrons", doc.trigger.patron_id, filename];
  return ["data", "events", "shared", filename];
}

// Convert a res:// path (from manifest `_path`) into segments the Repo layer
// writes with. Drops the "res://" prefix.
export function pathFromRes(resPath: string): string[] {
  return resPath.replace(/^res:\/\//, "").split("/");
}
