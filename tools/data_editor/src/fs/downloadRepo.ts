import type { Manifest } from "../types";
import { triggerDownload, type Repo } from "./repo";

// Fallback backend for Firefox / Safari.
//
// The author uploads `_manifest.json` once when connecting; the SPA keeps it
// in memory. When the author clicks Save in a tab, we trigger a browser
// download of the generated JSON; the author drops the file into the correct
// folder inside the repo by hand. No disk access needed — works in every
// browser.

export class DownloadRepo implements Repo {
  readonly kind = "download" as const;
  readonly description: string;
  private manifest: Manifest;

  constructor(manifest: Manifest, sourceLabel = "uploaded manifest") {
    this.manifest = manifest;
    this.description = sourceLabel;
  }

  supportsAutoReload(): boolean {
    return false;
  }

  async readManifest(): Promise<Manifest> {
    return this.manifest;
  }

  async writeJson(path: string[], contents: string): Promise<void> {
    // Path is segments from the repo root, e.g. ["data","characters","x.json"].
    // Use the filename only — the author places it in the right folder.
    const filename = path[path.length - 1];
    triggerDownload(filename, contents);
  }
}

export async function loadManifestFromFile(file: File): Promise<DownloadRepo> {
  const text = await file.text();
  const parsed = JSON.parse(text) as Manifest;
  return new DownloadRepo(parsed, file.name);
}
