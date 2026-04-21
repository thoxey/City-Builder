import { describe, expect, it } from "vitest";
import { validateEvent } from "./eventValidation";
import { blankEvent, cloneEvent } from "./blanks";
import { makeManifest } from "../test/manifestFixture";
import type { DialoguePayload, EventDoc, NewspaperPayload, NotificationPayload } from "../types";

function newDialogue(): EventDoc {
  const doc = blankEvent("dialogue");
  doc.event_id = "new_event";
  doc.trigger = { event: "character_arrived", character_id: "aristocrat_commercial" };
  const p = doc.payload as DialoguePayload;
  p.tree_id = "new_event_tree";
  p.nodes[0].body = "hello";
  return doc;
}

describe("validateEvent — envelope", () => {
  it("passes on a well-formed dialogue event", () => {
    const r = validateEvent(newDialogue(), makeManifest(), { isNew: true });
    expect(r.errors).toEqual([]);
  });

  it("blocks duplicate event_id on new event", () => {
    const doc = newDialogue();
    doc.event_id = "aristocrat_commercial_arrival";
    const r = validateEvent(doc, makeManifest(), { isNew: true });
    expect(r.errors.some((e) => e.includes("already exists"))).toBe(true);
  });

  it("rejects non-snake_case id", () => {
    const doc = newDialogue();
    doc.event_id = "Foo-Bar";
    const r = validateEvent(doc, makeManifest(), { isNew: true });
    expect(r.errors.some((e) => e.includes("snake_case"))).toBe(true);
  });

  it("warns on unknown trigger event", () => {
    const doc = newDialogue();
    doc.trigger = { event: "some_invented_trigger" };
    const r = validateEvent(doc, makeManifest(), { isNew: true });
    expect(r.warnings.some((w) => w.includes("not a known trigger"))).toBe(true);
  });

  it("rejects trigger.character_id not in manifest", () => {
    const doc = newDialogue();
    doc.trigger = { event: "character_arrived", character_id: "ghost" };
    const r = validateEvent(doc, makeManifest(), { isNew: true });
    expect(r.errors.some((e) => e.includes("trigger.character_id"))).toBe(true);
  });
});

describe("validateEvent — dialogue payload", () => {
  it("catches duplicate node_ids", () => {
    const doc = newDialogue();
    const p = doc.payload as DialoguePayload;
    p.nodes.push({ node_id: "n_start", speaker: "", body: "", on_enter: [], options: [] });
    const r = validateEvent(doc, makeManifest(), { isNew: true });
    expect(r.errors.some((e) => e.includes("duplicate node_id"))).toBe(true);
  });

  it("catches dangling option.next", () => {
    const doc = newDialogue();
    const p = doc.payload as DialoguePayload;
    p.nodes[0].options.push({ label: "Go", next: "n_nowhere", effects: [] });
    const r = validateEvent(doc, makeManifest(), { isNew: true });
    expect(r.errors.some((e) => e.includes("unknown node"))).toBe(true);
  });

  it("catches entry_node_id not in nodes", () => {
    const doc = newDialogue();
    (doc.payload as DialoguePayload).entry_node_id = "n_ghost";
    const r = validateEvent(doc, makeManifest(), { isNew: true });
    expect(r.errors.some((e) => e.includes("entry_node_id"))).toBe(true);
  });

  it("warns on unreachable node", () => {
    const doc = newDialogue();
    const p = doc.payload as DialoguePayload;
    p.nodes.push({ node_id: "n_orphan", speaker: "", body: "", on_enter: [], options: [] });
    const r = validateEvent(doc, makeManifest(), { isNew: true });
    expect(r.warnings.some((w) => w.includes("unreachable"))).toBe(true);
  });

  it("validates effects in options", () => {
    const doc = newDialogue();
    const p = doc.payload as DialoguePayload;
    p.nodes[0].options.push({
      label: "go",
      next: "",
      effects: [{ kind: "fire_event", target: "" }],
    });
    const r = validateEvent(doc, makeManifest(), { isNew: true });
    expect(r.errors.some((e) => e.includes("fire_event"))).toBe(true);
  });

  it("warns on fire_event referencing unknown target", () => {
    const doc = newDialogue();
    const p = doc.payload as DialoguePayload;
    p.nodes[0].options.push({
      label: "go",
      next: "",
      effects: [{ kind: "fire_event", target: "no_such_event" }],
    });
    const r = validateEvent(doc, makeManifest(), { isNew: true });
    expect(r.warnings.some((w) => w.includes("not in manifest"))).toBe(true);
    expect(r.errors.some((e) => e.includes("fire_event"))).toBe(false);
  });
});

describe("validateEvent — newspaper / notification", () => {
  it("warns on empty newspaper body", () => {
    const doc: EventDoc = cloneEvent(blankEvent("newspaper"));
    doc.event_id = "news";
    doc.trigger = { event: "manual" };
    const r = validateEvent(doc, makeManifest(), { isNew: true });
    expect(r.errors).toEqual([]);
    expect(r.warnings.some((w) => w.includes("body"))).toBe(true);
  });

  it("rejects non-positive notification duration", () => {
    const doc: EventDoc = cloneEvent(blankEvent("notification"));
    doc.event_id = "notif";
    doc.trigger = { event: "manual" };
    (doc.payload as NotificationPayload).duration = 0;
    const r = validateEvent(doc, makeManifest(), { isNew: true });
    expect(r.errors.some((e) => e.includes("duration"))).toBe(true);
  });

  it("allows newspaper with content", () => {
    const doc: EventDoc = cloneEvent(blankEvent("newspaper"));
    doc.event_id = "news";
    doc.trigger = { event: "manual" };
    const p = doc.payload as NewspaperPayload;
    p.headline = "Big News";
    p.body = "Stuff happened";
    const r = validateEvent(doc, makeManifest(), { isNew: true });
    expect(r.errors).toEqual([]);
    expect(r.warnings).toEqual([]);
  });
});
