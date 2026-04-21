import { useEffect, useMemo, useState } from "react";
import { useApp } from "../store";
import { Sidebar } from "../components/Sidebar";
import type { Bucket, CharacterDoc, Manifest } from "../types";
import { validateCharacter } from "../validators";

const EMPTY: CharacterDoc = {
  character_id: "",
  display_name: "",
  bio: "",
  patron_id: "",
  associated_bucket: "",
  arrival_threshold: 10,
  arrival_requires_tier: 1,
  want_building_id: "",
  portrait: "",
};

function manifestToDoc(m: Manifest, id: string): CharacterDoc | null {
  const c = m.characters.find((x) => x.character_id === id);
  if (!c) return null;
  return {
    character_id: c.character_id,
    display_name: c.display_name,
    bio: c.bio,
    patron_id: c.patron_id,
    associated_bucket: c.associated_bucket,
    arrival_threshold: c.arrival_threshold,
    arrival_requires_tier: c.arrival_requires_tier,
    want_building_id: c.want_building_id,
    portrait: c.portrait,
  };
}

export function CharactersTab() {
  const { manifest, writeJson, reloadManifest } = useApp();
  if (!manifest) return null;

  const [selectedId, setSelectedId] = useState<string | null>(
    manifest.characters[0]?.character_id ?? null
  );
  const [isNew, setIsNew] = useState(false);
  const [doc, setDoc] = useState<CharacterDoc>(EMPTY);
  const [saving, setSaving] = useState(false);
  const [saveError, setSaveError] = useState<string | null>(null);

  useEffect(() => {
    if (isNew) return;
    if (!selectedId) { setDoc(EMPTY); return; }
    const d = manifestToDoc(manifest, selectedId);
    if (d) setDoc(d);
  }, [selectedId, isNew, manifest]);

  const items = useMemo(
    () =>
      manifest.characters.map((c) => ({
        id: c.character_id,
        primary: c.display_name || c.character_id,
        secondary: `${c.patron_id || "—"} · ${c.associated_bucket || "—"}`,
      })),
    [manifest.characters]
  );

  const validation = useMemo(
    () => validateCharacter(doc, manifest, { isNew, originalId: selectedId ?? undefined }),
    [doc, manifest, isNew, selectedId]
  );

  const update = <K extends keyof CharacterDoc>(k: K, v: CharacterDoc[K]) =>
    setDoc((d) => ({ ...d, [k]: v }));

  // Auto-suggest character_id as "<patron>_<bucket>" when both set and id is empty.
  useEffect(() => {
    if (!isNew) return;
    if (doc.character_id) return;
    if (doc.patron_id && doc.associated_bucket)
      setDoc((d) => ({ ...d, character_id: `${d.patron_id}_${d.associated_bucket}` }));
  }, [isNew, doc.character_id, doc.patron_id, doc.associated_bucket]);

  const handleNew = () => {
    setIsNew(true);
    setSelectedId(null);
    setDoc(EMPTY);
    setSaveError(null);
  };

  const handleSelect = (id: string) => {
    setIsNew(false);
    setSelectedId(id);
    setSaveError(null);
  };

  const handleSave = async () => {
    if (validation.errors.length > 0) return;
    setSaving(true);
    setSaveError(null);
    try {
      await writeJson(["data", "characters", `${doc.character_id}.json`], doc);
      await reloadManifest();
      setIsNew(false);
      setSelectedId(doc.character_id);
    } catch (e) {
      setSaveError((e as Error).message);
    } finally {
      setSaving(false);
    }
  };

  const relatedEvents = manifest.events.filter(
    (e) => e.trigger_character_id === doc.character_id && doc.character_id !== ""
  );

  const wantBuildings = manifest.buildings.filter(
    (b) =>
      b.chain_role === "want" &&
      (!doc.patron_id || b.patron_id === doc.patron_id) &&
      (!doc.associated_bucket || b.bucket === doc.associated_bucket)
  );

  return (
    <div className="tab-layout">
      <Sidebar
        items={items}
        selectedId={isNew ? null : selectedId}
        onSelect={handleSelect}
        onNew={handleNew}
        newLabel="+ New"
        placeholder="Filter characters…"
      />

      <main className="editor-pane">
        <h2>
          {isNew
            ? "New character"
            : doc.display_name || doc.character_id || "—"}
        </h2>

        <div className="form-grid">
          <label>character_id</label>
          <div>
            <input
              value={doc.character_id}
              onChange={(e) => update("character_id", e.target.value)}
              disabled={!isNew}
              placeholder="aristocrat_commercial"
            />
            {isNew && (
              <div className="inline-note">
                snake_case. File: <code>data/characters/&lt;id&gt;.json</code>.
              </div>
            )}
          </div>

          <label>display_name</label>
          <input
            value={doc.display_name}
            onChange={(e) => update("display_name", e.target.value)}
          />

          <label>bio</label>
          <textarea
            value={doc.bio}
            onChange={(e) => update("bio", e.target.value)}
          />

          <label>patron_id</label>
          <select
            value={doc.patron_id}
            onChange={(e) => update("patron_id", e.target.value)}
          >
            <option value="">—</option>
            {manifest.patrons.map((p) => (
              <option key={p.patron_id} value={p.patron_id}>
                {p.display_name || p.patron_id}
              </option>
            ))}
          </select>

          <label>associated_bucket</label>
          <select
            value={doc.associated_bucket}
            onChange={(e) => update("associated_bucket", e.target.value as Bucket | "")}
          >
            <option value="">—</option>
            {manifest.buckets.map((b) => (
              <option key={b} value={b}>{b}</option>
            ))}
          </select>

          <label>arrival_threshold</label>
          <input
            type="number"
            min={0}
            value={doc.arrival_threshold}
            onChange={(e) => update("arrival_threshold", Number(e.target.value))}
          />

          <label>arrival_requires_tier</label>
          <input
            type="number"
            min={1}
            max={3}
            value={doc.arrival_requires_tier}
            onChange={(e) => update("arrival_requires_tier", Number(e.target.value))}
          />

          <label>want_building_id</label>
          <div>
            <select
              value={doc.want_building_id}
              onChange={(e) => update("want_building_id", e.target.value)}
            >
              <option value="">—</option>
              {wantBuildings.map((b) => (
                <option key={b.building_id} value={b.building_id}>
                  {b.display_name || b.building_id}
                </option>
              ))}
              {doc.want_building_id &&
                !wantBuildings.some((b) => b.building_id === doc.want_building_id) && (
                  <option value={doc.want_building_id}>
                    {doc.want_building_id} (unfiltered)
                  </option>
                )}
            </select>
            <div className="inline-note">
              Filtered to <code>chain_role=want</code>
              {doc.patron_id && ` · patron=${doc.patron_id}`}
              {doc.associated_bucket && ` · bucket=${doc.associated_bucket}`}.
            </div>
          </div>

          <label>portrait</label>
          <div>
            <input
              value={doc.portrait}
              onChange={(e) => update("portrait", e.target.value)}
              placeholder="res://data/characters/<id>/portrait.png"
            />
            <div className="inline-note">
              Path only in Pass A — upload UI comes in Pass C.
            </div>
          </div>
        </div>

        {validation.errors.length > 0 && (
          <div className="inline-error" style={{ marginTop: 12 }}>
            {validation.errors.map((e) => <div key={e}>⛔ {e}</div>)}
          </div>
        )}
        {validation.warnings.length > 0 && (
          <div className="inline-note" style={{ marginTop: 12 }}>
            {validation.warnings.map((w) => <div key={w}>⚠ {w}</div>)}
          </div>
        )}
        {saveError && (
          <div className="inline-error" style={{ marginTop: 12 }}>⛔ {saveError}</div>
        )}

        <div className="action-row">
          <button
            className="primary"
            onClick={handleSave}
            disabled={saving || validation.errors.length > 0}
          >
            {saving ? "Saving…" : "Save to JSON"}
          </button>
          {isNew && (
            <button
              onClick={() => {
                setIsNew(false);
                setSelectedId(manifest.characters[0]?.character_id ?? null);
              }}
            >
              Cancel
            </button>
          )}
        </div>

        <div className="quick-links">
          <h3>Events triggered by this character</h3>
          {relatedEvents.length === 0 ? (
            <div className="placeholder">
              {doc.character_id
                ? "No events reference this character yet."
                : "Set character_id to see related events."}
            </div>
          ) : (
            <ul>
              {relatedEvents.map((e) => (
                <li key={e.event_id}>
                  <span><code>{e.event_id}</code> — {e.event_type} · {e.trigger_event}</span>
                  <span className="secondary-label">{e._path.replace("res://", "")}</span>
                </li>
              ))}
            </ul>
          )}
          <div className="inline-note" style={{ marginTop: 8 }}>
            Event authoring UI comes in Pass B. Hand-edit JSON under{" "}
            <code>data/events/characters/{doc.character_id || "&lt;id&gt;"}/</code> for now.
          </div>
        </div>
      </main>
    </div>
  );
}
