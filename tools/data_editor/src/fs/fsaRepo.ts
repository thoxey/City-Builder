import type { Manifest } from "../types";
import type { Repo } from "./repo";

// File System Access API backend. Chrome/Edge only. Picks the repo root
// once, persists the handle in IndexedDB so subsequent sessions skip the
// picker, and reads/writes JSON directly into the repo.

type Handle = FileSystemDirectoryHandle;

const DB_NAME = "data-editor";
const STORE = "handles";
const KEY = "repo-root";

const MANIFEST_PATH = ["data", "events", "_manifest.json"];

export function supportsFileSystemAccess(): boolean {
  return typeof window !== "undefined" && "showDirectoryPicker" in window;
}

async function openDb(): Promise<IDBDatabase> {
  return new Promise((resolve, reject) => {
    const req = indexedDB.open(DB_NAME, 1);
    req.onupgradeneeded = () => req.result.createObjectStore(STORE);
    req.onsuccess = () => resolve(req.result);
    req.onerror = () => reject(req.error);
  });
}

async function idbGet<T>(key: string): Promise<T | undefined> {
  const db = await openDb();
  return new Promise((resolve, reject) => {
    const tx = db.transaction(STORE, "readonly");
    const req = tx.objectStore(STORE).get(key);
    req.onsuccess = () => resolve(req.result as T | undefined);
    req.onerror = () => reject(req.error);
  });
}

async function idbSet(key: string, value: unknown): Promise<void> {
  const db = await openDb();
  return new Promise((resolve, reject) => {
    const tx = db.transaction(STORE, "readwrite");
    tx.objectStore(STORE).put(value, key);
    tx.oncomplete = () => resolve();
    tx.onerror = () => reject(tx.error);
  });
}

async function ensurePermission(handle: Handle, mode: "read" | "readwrite"): Promise<boolean> {
  // @ts-expect-error queryPermission / requestPermission are not fully typed
  const existing: PermissionState = await handle.queryPermission({ mode });
  if (existing === "granted") return true;
  // @ts-expect-error requestPermission
  const requested: PermissionState = await handle.requestPermission({ mode });
  return requested === "granted";
}

async function getDir(
  root: Handle,
  segments: string[],
  { create = false }: { create?: boolean } = {}
): Promise<Handle> {
  let cur: Handle = root;
  for (const seg of segments) {
    cur = await cur.getDirectoryHandle(seg, { create });
  }
  return cur;
}

async function readText(root: Handle, path: string[]): Promise<string> {
  const filename = path[path.length - 1];
  const dir = await getDir(root, path.slice(0, -1));
  const file = await dir.getFileHandle(filename);
  return (await file.getFile()).text();
}

async function writeText(root: Handle, path: string[], contents: string): Promise<void> {
  const filename = path[path.length - 1];
  const dir = await getDir(root, path.slice(0, -1), { create: true });
  const file = await dir.getFileHandle(filename, { create: true });
  const writable = await file.createWritable();
  await writable.write(contents);
  await writable.close();
}

// ---- public API ----

export async function pickRepoRoot(): Promise<FsaRepo> {
  // @ts-expect-error showDirectoryPicker is not in lib.dom yet
  const handle: Handle = await window.showDirectoryPicker({ mode: "readwrite" });
  await idbSet(KEY, handle);
  return new FsaRepo(handle);
}

export async function restoreRepoRoot(): Promise<FsaRepo | null> {
  const handle = (await idbGet<Handle>(KEY)) ?? null;
  if (!handle) return null;
  const perm = await ensurePermission(handle, "readwrite");
  if (!perm) return null;
  return new FsaRepo(handle);
}

export class FsaRepo implements Repo {
  readonly kind = "fsa" as const;
  readonly description: string;

  constructor(private handle: Handle) {
    this.description = handle.name;
  }

  supportsAutoReload(): boolean {
    return true;
  }

  async readManifest(): Promise<Manifest> {
    const raw = await readText(this.handle, MANIFEST_PATH);
    return JSON.parse(raw) as Manifest;
  }

  async writeJson(path: string[], contents: string): Promise<void> {
    await writeText(this.handle, path, contents);
  }
}
