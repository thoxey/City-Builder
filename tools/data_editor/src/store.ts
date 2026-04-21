import { create } from "zustand";
import type { Manifest } from "./types";
import type { Repo } from "./fs/repo";
import { pickRepoRoot, restoreRepoRoot } from "./fs/fsaRepo";
import { loadManifestFromFile } from "./fs/downloadRepo";

export type Tab = "characters" | "patrons" | "events" | "buildings";

interface AppState {
  repo: Repo | null;
  manifest: Manifest | null;
  loading: boolean;
  error: string | null;
  activeTab: Tab;

  setTab: (t: Tab) => void;
  connectFsa: () => Promise<void>;
  connectDownload: (file: File) => Promise<void>;
  tryRestoreRepo: () => Promise<void>;
  reloadManifest: () => Promise<void>;
  writeJson: (relPath: string[], payload: unknown) => Promise<void>;
}

export const useApp = create<AppState>((set, get) => ({
  repo: null,
  manifest: null,
  loading: false,
  error: null,
  activeTab: "characters",

  setTab: (t) => set({ activeTab: t }),

  connectFsa: async () => {
    set({ loading: true, error: null });
    try {
      const repo = await pickRepoRoot();
      set({ repo });
      await get().reloadManifest();
    } catch (e) {
      set({ error: (e as Error).message });
    } finally {
      set({ loading: false });
    }
  },

  connectDownload: async (file: File) => {
    set({ loading: true, error: null });
    try {
      const repo = await loadManifestFromFile(file);
      const manifest = await repo.readManifest();
      set({ repo, manifest });
    } catch (e) {
      set({ error: `Could not parse ${file.name} — ${(e as Error).message}` });
    } finally {
      set({ loading: false });
    }
  },

  tryRestoreRepo: async () => {
    try {
      const repo = await restoreRepoRoot();
      if (repo) {
        set({ repo });
        await get().reloadManifest();
      }
    } catch {
      // no-op — user will click Connect
    }
  },

  reloadManifest: async () => {
    const repo = get().repo;
    if (!repo) return;
    set({ loading: true, error: null });
    try {
      const manifest = await repo.readManifest();
      set({ manifest });
    } catch (e) {
      set({ error: `Could not load manifest — run Export in Godot first. (${(e as Error).message})` });
    } finally {
      set({ loading: false });
    }
  },

  writeJson: async (relPath, payload) => {
    const repo = get().repo;
    if (!repo) throw new Error("Not connected to a repo");
    await repo.writeJson(relPath, JSON.stringify(payload, null, 2) + "\n");
  },
}));
