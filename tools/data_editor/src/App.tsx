import { useEffect, useRef } from "react";
import { useApp, type Tab } from "./store";
import { supportsFileSystemAccess } from "./fs/fsaRepo";
import { CharactersTab } from "./tabs/CharactersTab";
import { PatronsTab } from "./tabs/PatronsTab";
import { EventsTab } from "./tabs/EventsTab";

const TABS: { id: Tab; label: string; enabled: boolean }[] = [
  { id: "characters", label: "Characters", enabled: true },
  { id: "patrons", label: "Patrons", enabled: true },
  { id: "events", label: "Events", enabled: true },
  { id: "buildings", label: "Buildings", enabled: false },
];

export default function App() {
  const {
    repo,
    manifest,
    error,
    activeTab,
    setTab,
    connectFsa,
    connectDownload,
    tryRestoreRepo,
    reloadManifest,
  } = useApp();

  const fileInputRef = useRef<HTMLInputElement>(null);

  useEffect(() => {
    tryRestoreRepo();
  }, [tryRestoreRepo]);

  if (!repo) {
    return (
      <ConnectScreen
        onConnectFsa={connectFsa}
        onConnectDownload={connectDownload}
        error={error}
      />
    );
  }

  const onReloadClick = () => {
    if (repo.supportsAutoReload()) {
      reloadManifest();
    } else {
      fileInputRef.current?.click();
    }
  };

  return (
    <div className="app">
      <header className="topbar">
        <div className="title">Data Editor</div>
        <div className="tabs">
          {TABS.map((t) => (
            <button
              key={t.id}
              disabled={!t.enabled}
              className={activeTab === t.id ? "active" : ""}
              onClick={() => t.enabled && setTab(t.id)}
              title={t.enabled ? "" : "Coming in Pass B/C"}
            >
              {t.label}
            </button>
          ))}
        </div>
        <div className="spacer" />
        <div className={error ? "status error" : "status"}>
          {error
            ? error
            : manifest
            ? `${repo.kind === "fsa" ? "Repo" : "Manifest"}: ${repo.description} · ${manifest.exported_at} · ${manifest.characters.length}c / ${manifest.patrons.length}p / ${manifest.buildings.length}b / ${manifest.events.length}e`
            : "No manifest loaded"}
        </div>
        <button onClick={onReloadClick}>
          {repo.supportsAutoReload() ? "Reload Manifest" : "Re-upload Manifest"}
        </button>
        <input
          ref={fileInputRef}
          type="file"
          accept="application/json,.json"
          style={{ display: "none" }}
          onChange={(e) => {
            const f = e.target.files?.[0];
            if (f) connectDownload(f);
            e.target.value = "";
          }}
        />
      </header>

      {repo.kind === "download" && (
        <div className="banner">
          <b>Download mode.</b> Saves will trigger browser downloads — drop each
          file into the matching folder in your repo (
          <code>data/characters/</code>, <code>data/patrons/</code>, etc.). For
          direct writes, open this editor in Chrome or Edge.
        </div>
      )}

      {!manifest ? (
        <div className="empty">
          Manifest not loaded. Run the Godot exporter and click Reload Manifest.
        </div>
      ) : activeTab === "characters" ? (
        <CharactersTab />
      ) : activeTab === "patrons" ? (
        <PatronsTab />
      ) : activeTab === "events" ? (
        <EventsTab />
      ) : (
        <div className="empty">Tab not yet implemented.</div>
      )}
    </div>
  );
}

interface ConnectProps {
  onConnectFsa: () => Promise<void>;
  onConnectDownload: (f: File) => Promise<void>;
  error: string | null;
}

function ConnectScreen({ onConnectFsa, onConnectDownload, error }: ConnectProps) {
  const fsaSupported = supportsFileSystemAccess();
  const fileInputRef = useRef<HTMLInputElement>(null);

  return (
    <div className="connect-screen">
      <div className="card">
        <h1>Data Editor</h1>
        <p style={{ color: "var(--text-dim)" }}>
          Tip: run <b>Project → Tools → Export Data Editor Manifest</b> in
          Godot before connecting so the manifest is up to date.
        </p>

        <div className="connect-modes">
          <div className="mode">
            <h2>
              Connect to repo{" "}
              {!fsaSupported && <span className="muted">(Chrome / Edge)</span>}
            </h2>
            <p>
              Pick your <code>Starter-Kit-City-Builder</code> folder. Edits save
              straight to disk. Uses the File System Access API.
            </p>
            <button
              className="primary"
              onClick={onConnectFsa}
              disabled={!fsaSupported}
              title={fsaSupported ? "" : "Not supported in this browser"}
            >
              Pick folder…
            </button>
          </div>

          <div className="divider">or</div>

          <div className="mode">
            <h2>Upload manifest</h2>
            <p>
              Works in every browser. Drop <code>data/events/_manifest.json</code>{" "}
              here — saves will download JSON files you drop back into the repo
              by hand.
            </p>
            <button onClick={() => fileInputRef.current?.click()}>
              Upload _manifest.json…
            </button>
            <input
              ref={fileInputRef}
              type="file"
              accept="application/json,.json"
              style={{ display: "none" }}
              onChange={(e) => {
                const f = e.target.files?.[0];
                if (f) onConnectDownload(f);
                e.target.value = "";
              }}
            />
          </div>
        </div>

        {error && <p style={{ color: "var(--danger)", marginTop: 20 }}>{error}</p>}
      </div>
    </div>
  );
}
