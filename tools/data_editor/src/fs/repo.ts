import type { Manifest } from "../types";

// Common interface so the store doesn't care whether we're using the File
// System Access API (Chrome/Edge) or the upload/download fallback
// (Firefox/Safari). Both modes share readManifest + writeJson; the Repo
// instance carries whatever state it needs (directory handle, uploaded
// manifest text, etc.).

export type RepoKind = "fsa" | "download";

export interface Repo {
  kind: RepoKind;
  description: string; // short label shown in the UI
  readManifest(): Promise<Manifest>;
  // Path is repo-relative, split into segments: ["data","characters","x.json"].
  // Download mode surfaces `contents` as a browser download; FSA mode writes
  // to disk in place.
  writeJson(path: string[], contents: string): Promise<void>;
  supportsAutoReload(): boolean;
}

export function triggerDownload(filename: string, contents: string): void {
  const blob = new Blob([contents], { type: "application/json" });
  const url = URL.createObjectURL(blob);
  const a = document.createElement("a");
  a.href = url;
  a.download = filename;
  document.body.appendChild(a);
  a.click();
  a.remove();
  URL.revokeObjectURL(url);
}
