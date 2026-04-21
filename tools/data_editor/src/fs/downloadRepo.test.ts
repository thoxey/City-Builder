import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import { DownloadRepo, loadManifestFromFile } from "./downloadRepo";
import { makeManifest } from "../test/manifestFixture";

describe("DownloadRepo", () => {
  let createdAnchors: HTMLAnchorElement[];

  beforeEach(() => {
    createdAnchors = [];
    // Spy on anchor click so we can assert what triggerDownload does without
    // actually opening a download dialog.
    const originalCreateElement = document.createElement.bind(document);
    vi.spyOn(document, "createElement").mockImplementation(
      ((tag: string) => {
        const el = originalCreateElement(tag);
        if (tag === "a") {
          (el as HTMLAnchorElement).click = vi.fn();
          createdAnchors.push(el as HTMLAnchorElement);
        }
        return el;
      }) as typeof document.createElement
    );
    // jsdom doesn't implement URL.createObjectURL by default.
    if (!URL.createObjectURL) {
      Object.defineProperty(URL, "createObjectURL", { value: () => "blob:mock" });
    }
    if (!URL.revokeObjectURL) {
      Object.defineProperty(URL, "revokeObjectURL", { value: () => {} });
    }
  });

  afterEach(() => {
    vi.restoreAllMocks();
  });

  it("exposes the stored manifest and reports kind=download", async () => {
    const manifest = makeManifest();
    const repo = new DownloadRepo(manifest, "_manifest.json");
    expect(repo.kind).toBe("download");
    expect(repo.supportsAutoReload()).toBe(false);
    await expect(repo.readManifest()).resolves.toEqual(manifest);
  });

  it("writeJson triggers a download with the repo-relative filename", async () => {
    const repo = new DownloadRepo(makeManifest(), "_manifest.json");
    await repo.writeJson(
      ["data", "characters", "aristocrat_commercial.json"],
      JSON.stringify({ foo: "bar" })
    );
    expect(createdAnchors).toHaveLength(1);
    expect(createdAnchors[0].download).toBe("aristocrat_commercial.json");
    expect(createdAnchors[0].click).toHaveBeenCalled();
  });

  it("loadManifestFromFile parses JSON and returns a DownloadRepo", async () => {
    const manifest = makeManifest();
    const body = JSON.stringify(manifest);
    // jsdom 25's File doesn't implement .text(); shim it for the test.
    const file = new File([body], "_manifest.json", { type: "application/json" });
    Object.defineProperty(file, "text", { value: async () => body });
    const repo = await loadManifestFromFile(file);
    expect(repo.kind).toBe("download");
    expect(repo.description).toBe("_manifest.json");
    await expect(repo.readManifest()).resolves.toEqual(manifest);
  });
});
