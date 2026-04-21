import { describe, expect, it } from "vitest";
import { defaultPathForNewEvent, pathFromRes } from "./paths";
import { blankEvent } from "./blanks";

describe("defaultPathForNewEvent", () => {
  it("newspaper goes under data/events/newspaper/", () => {
    const doc = blankEvent("newspaper");
    doc.event_id = "big_news";
    doc.trigger = { event: "manual" };
    expect(defaultPathForNewEvent(doc)).toEqual([
      "data", "events", "newspaper", "big_news.json",
    ]);
  });

  it("notification goes under data/events/notifications/", () => {
    const doc = blankEvent("notification");
    doc.event_id = "toast";
    doc.trigger = { event: "manual" };
    expect(defaultPathForNewEvent(doc)).toEqual([
      "data", "events", "notifications", "toast.json",
    ]);
  });

  it("dialogue with character trigger nests under characters/<cid>/", () => {
    const doc = blankEvent("dialogue");
    doc.event_id = "arrival";
    doc.trigger = { event: "character_arrived", character_id: "farmer_commercial" };
    expect(defaultPathForNewEvent(doc)).toEqual([
      "data", "events", "characters", "farmer_commercial", "arrival.json",
    ]);
  });

  it("dialogue with patron trigger nests under patrons/<pid>/", () => {
    const doc = blankEvent("dialogue");
    doc.event_id = "ready";
    doc.trigger = { event: "patron_landmark_ready", patron_id: "aristocrat" };
    expect(defaultPathForNewEvent(doc)).toEqual([
      "data", "events", "patrons", "aristocrat", "ready.json",
    ]);
  });

  it("dialogue without character or patron trigger falls back to shared/", () => {
    const doc = blankEvent("dialogue");
    doc.event_id = "shared_thing";
    doc.trigger = { event: "manual" };
    expect(defaultPathForNewEvent(doc)).toEqual([
      "data", "events", "shared", "shared_thing.json",
    ]);
  });
});

describe("pathFromRes", () => {
  it("strips res:// and splits", () => {
    expect(
      pathFromRes("res://data/events/characters/aristocrat_commercial/arrival.json")
    ).toEqual(["data", "events", "characters", "aristocrat_commercial", "arrival.json"]);
  });
});
