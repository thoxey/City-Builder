import { useEffect, useMemo, useState } from "react";
import { useApp } from "../store";
import { Sidebar } from "../components/Sidebar";
import { MediaPreview } from "../components/MediaPreview";
import type { Bucket, CharacterDoc, CharacterType, Manifest } from "../types";
import { validateCharacter } from "../validators";

const MAX_TALKING_VIDEOS = 8;

const CHARACTER_TYPES: ReadonlyArray<{ id: CharacterType; label: string; hint: string }> = [
  { id: "character", label: "character", hint: "Quest-driven — arrives, has a want, becomes satisfied." },
  { id: "patron",    label: "patron",    hint: "The patron themselves speaking. Needs patron_id; no quest fields." },
  { id: "narrator",  label: "narrator",  hint: "Off-screen voice. Dialogue-only, no quest fields." },
  { id: "guide",     label: "guide",     hint: "Tutorial / hint speaker. Dialogue-only, no quest fields." },
];

const EMPTY: CharacterDoc = {
  character_id: "",
  character_type: "character",
  display_name: "",
  bio: "",
  patron_id: "",
  associated_bucket: "",
  arrival_threshold: 10,
  arrival_requires_tier: 1,
  want_building_id: "",
  portrait: "",
  talking_videos: [],
};

function manifestToDoc(m: Manifest, id: string): CharacterDoc | null {
  const c = m.characters.find((x) => x.character_id === id);
  if (!c) return null;
  return {
    character_id: c.character_id,
    character_type: c.character_type ?? "character",
    display_name: c.display_name,
    bio: c.bio,
    patron_id: c.patron_id,
    associated_bucket: c.associated_bucket,
    arrival_threshold: c.arrival_threshold,
    arrival_requires_tier: c.arrival_requires_tier,
    want_building_id: c.want_building_id,
    portrait: c.portrait,
    talking_videos: c.talking_videos ?? [],
  };
}

export function CharactersTab() {
  const { manifest, writeJson, patchCharacter } = useApp();
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
      manifest.characters.map((c) => {
        const type = c.character_type ?? "character";
        const secondary =
          type === "character"
            ? `${c.patron_id || "—"} · ${c.associated_bucket || "—"}`
            : type === "patron"
              ? `patron · ${c.patron_id || "—"}`
              : type;
        return {
          id: c.character_id,
          primary: c.display_name || c.character_id,
          secondary,
        };
      }),
    [manifest.characters]
  );

  const validation = useMemo(
    () => validateCharacter(doc, manifest, { isNew, originalId: selectedId ?? undefined }),
    [doc, manifest, isNew, selectedId]
  );

  const update = <K extends keyof CharacterDoc>(k: K, v: CharacterDoc[K]) =>
    setDoc((d) => ({ ...d, [k]: v }));

  // Auto-suggest character_id as "<patron>_<bucket>" when both set and id is empty.
  // Only meaningful for the quest-driven character type.
  useEffect(() => {
    if (!isNew) return;
    if (doc.character_id) return;
    if (doc.character_type !== "character") return;
    if (doc.patron_id && doc.associated_bucket)
      setDoc((d) => ({ ...d, character_id: `${d.patron_id}_${d.associated_bucket}` }));
  }, [isNew, doc.character_id, doc.character_type, doc.patron_id, doc.associated_bucket]);

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
      await patchCharacter(doc);
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
          <label>character_type</label>
          <div>
            <select
              value={doc.character_type}
              onChange={(e) => update("character_type", e.target.value as CharacterType)}
            >
              {CHARACTER_TYPES.map((t) => (
                <option key={t.id} value={t.id}>{t.label}</option>
              ))}
            </select>
            <div className="inline-note">
              {CHARACTER_TYPES.find((t) => t.id === doc.character_type)?.hint}
            </div>
          </div>

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

          {(doc.character_type === "character" || doc.character_type === "patron") && (
            <>
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
            </>
          )}

          {doc.character_type === "character" && (
            <>
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
            </>
          )}

          <label>portrait</label>
          <div className="media-field">
            <input
              value={doc.portrait}
              onChange={(e) => update("portrait", e.target.value)}
              placeholder="res://data/characters/<id>/portrait.png"
            />
            <MediaPreview path={doc.portrait} kind="image" />
          </div>

          <label>talking_videos</label>
          <div>
            {doc.talking_videos.length === 0 && (
              <div className="inline-note">
                No talking videos. Add one or more <code>res://</code>-prefixed{" "}
                <code>.ogv</code> paths.
              </div>
            )}
            {doc.talking_videos.map((p, i) => (
              <div key={i} className="media-field" style={{ marginBottom: 8 }}>
                <input
                  value={p}
                  onChange={(e) => {
                    const next = [...doc.talking_videos];
                    next[i] = e.target.value;
                    update("talking_videos", next);
                  }}
                  placeholder={`res://data/characters/${doc.character_id || "<id>"}/talking_${i + 1}.ogv`}
                />
                <button
                  type="button"
                  onClick={() => {
                    const next = doc.talking_videos.filter((_, j) => j !== i);
                    update("talking_videos", next);
                  }}
                  title="Remove this video"
                >
                  ✕
                </button>
                <MediaPreview path={p} kind="video" />
              </div>
            ))}
            {doc.talking_videos.length < MAX_TALKING_VIDEOS && (
              <button
                type="button"
                onClick={() =>
                  update("talking_videos", [...doc.talking_videos, ""])
                }
              >
                + Add talking video
              </button>
            )}
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
