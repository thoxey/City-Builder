import { beforeEach, describe, expect, it } from "vitest";
import type { Repo } from "./fs/repo";
import { makeManifest } from "./test/manifestFixture";
import type { BuildingDoc, Manifest } from "./types";
import { useApp } from "./store";

function clone<T>(value: T): T {
  return structuredClone(value);
}

describe("building manifest refresh", () => {
  beforeEach(() => {
    useApp.setState({ repo: null, manifest: null, loading: false, error: null });
  });

  it("patches a just-saved building body before persisting the manifest", async () => {
    const manifest = makeManifest();
    const writes: Array<{ path: string[]; contents: string }> = [];
    const repo: Repo = {
      kind: "fsa",
      description: "fixture",
      readManifest: async () => clone(manifest),
      writeJson: async (path, contents) => { writes.push({ path, contents }); },
      supportsAutoReload: () => true,
    };
    useApp.setState({ repo, manifest: clone(manifest) });

    const original = manifest.buildings[0];
    const edited: BuildingDoc = { ...clone(original.body), palette_excluded: true };
    await useApp.getState().patchBuilding(edited, ["data", "buildings", "unique", "ignored.json"]);

    const current = useApp.getState().manifest!.buildings.find(
      (building) => building.building_id === edited.building_id
    )!;
    expect(current.palette_excluded).toBe(true);
    expect(current.body.palette_excluded).toBe(true);
    expect(current._path).toBe(original._path);

    const manifestWrite = writes.find(
      (write) => write.path.join("/") === "data/events/_manifest.json"
    );
    expect(manifestWrite).toBeDefined();
    const persisted = JSON.parse(manifestWrite!.contents) as Manifest;
    const persistedBuilding = persisted.buildings.find(
      (building) => building.building_id === edited.building_id
    )!;
    expect(persistedBuilding.palette_excluded).toBe(true);
    expect(persistedBuilding.body.palette_excluded).toBe(true);
  });

  it("reloads building bodies from disk instead of restoring stale exporter data", async () => {
    const stale = makeManifest();
    const target = stale.buildings[0];
    const fresh: BuildingDoc = { ...clone(target.body), palette_excluded: true };
    const repo: Repo = {
      kind: "fsa",
      description: "fixture",
      readManifest: async () => clone(stale),
      writeJson: async () => {},
      supportsAutoReload: () => true,
      readJson: async (path) => {
        if (path.join("/") === target._path.replace(/^res:\/\//, "")) return clone(fresh);
        throw new Error("fixture file unavailable");
      },
    };
    useApp.setState({ repo, manifest: clone(stale) });

    await useApp.getState().reloadManifest();

    const reloaded = useApp.getState().manifest!.buildings.find(
      (building) => building.building_id === target.building_id
    )!;
    expect(reloaded.palette_excluded).toBe(true);
    expect(reloaded.body.palette_excluded).toBe(true);
    expect(reloaded._path).toBe(target._path);
  });
});
