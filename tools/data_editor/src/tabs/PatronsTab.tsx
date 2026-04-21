import { useEffect, useMemo, useState } from "react";
import { useApp } from "../store";
import { Sidebar } from "../components/Sidebar";
import type { Bucket, DonationAreaRect, Manifest, PatronDoc } from "../types";
import { validatePatron } from "../validators";

const EMPTY_RECT: DonationAreaRect = { shape: "rect", rect: [0, 0, 8, 8] };

const EMPTY: PatronDoc = {
  patron_id: "",
  display_name: "",
  bio: "",
  character_ids: ["", "", ""],
  landmark_building_id: "",
  portrait: "",
  donation_area: EMPTY_RECT,
};

const BUCKET_ORDER: Bucket[] = ["residential", "commercial", "industrial"];

function manifestToDoc(m: Manifest, id: string): PatronDoc | null {
  const p = m.patrons.find((x) => x.patron_id === id);
  if (!p) return null;
  // Normalise character_ids to length 3 in residential/commercial/industrial order.
  const bucketToCid = new Map<Bucket, string>();
  for (const cid of p.character_ids) {
    const c = m.characters.find((x) => x.character_id === cid);
    if (c?.associated_bucket) bucketToCid.set(c.associated_bucket as Bucket, cid);
  }
  const ordered = BUCKET_ORDER.map((b) => bucketToCid.get(b) ?? "");
  return {
    patron_id: p.patron_id,
    display_name: p.display_name,
    bio: p.bio,
    character_ids: ordered,
    landmark_building_id: p.landmark_building_id,
    portrait: p.portrait,
    donation_area: p.donation_area,
  };
}

export function PatronsTab() {
  const { manifest, writeJson, reloadManifest } = useApp();
  if (!manifest) return null;

  const [selectedId, setSelectedId] = useState<string | null>(
    manifest.patrons[0]?.patron_id ?? null
  );
  const [isNew, setIsNew] = useState(false);
  const [doc, setDoc] = useState<PatronDoc>(EMPTY);
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
      manifest.patrons.map((p) => ({
        id: p.patron_id,
        primary: p.display_name || p.patron_id,
        secondary: `landmark: ${p.landmark_building_id || "—"}`,
      })),
    [manifest.patrons]
  );

  const validation = useMemo(
    () => validatePatron(doc, manifest, { isNew, originalId: selectedId ?? undefined }),
    [doc, manifest, isNew, selectedId]
  );

  const update = <K extends keyof PatronDoc>(k: K, v: PatronDoc[K]) =>
    setDoc((d) => ({ ...d, [k]: v }));

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
      // Drop empty-string slots so disk shape matches hand-authored files.
      const toSave: PatronDoc = {
        ...doc,
        character_ids: doc.character_ids.filter((x) => x !== ""),
      };
      await writeJson(["data", "patrons", `${doc.patron_id}.json`], toSave);
      await reloadManifest();
      setIsNew(false);
      setSelectedId(doc.patron_id);
    } catch (e) {
      setSaveError((e as Error).message);
    } finally {
      setSaving(false);
    }
  };

  const characterOptionsFor = (bucket: Bucket) =>
    manifest.characters.filter(
      (c) =>
        c.associated_bucket === bucket &&
        (!c.patron_id || c.patron_id === doc.patron_id || c.patron_id === "")
    );

  const landmarkBuildings = manifest.buildings.filter(
    (b) =>
      b.chain_role === "landmark" &&
      (!doc.patron_id || b.patron_id === doc.patron_id)
  );

  const rect: [number, number, number, number] =
    "shape" in doc.donation_area && doc.donation_area.shape === "rect"
      ? doc.donation_area.rect
      : [0, 0, 8, 8];
  const setRect = (idx: 0 | 1 | 2 | 3, val: number) => {
    const next: [number, number, number, number] = [...rect] as [number, number, number, number];
    next[idx] = val;
    update("donation_area", { shape: "rect", rect: next });
  };

  const relatedEvents = manifest.events.filter(
    (e) => e.trigger_patron_id === doc.patron_id && doc.patron_id !== ""
  );

  return (
    <div className="tab-layout">
      <Sidebar
        items={items}
        selectedId={isNew ? null : selectedId}
        onSelect={handleSelect}
        onNew={handleNew}
        newLabel="+ New"
        placeholder="Filter patrons…"
      />

      <main className="editor-pane">
        <h2>
          {isNew
            ? "New patron"
            : doc.display_name || doc.patron_id || "—"}
        </h2>

        <div className="form-grid">
          <label>patron_id</label>
          <div>
            <input
              value={doc.patron_id}
              onChange={(e) => update("patron_id", e.target.value)}
              disabled={!isNew}
              placeholder="aristocrat"
            />
            {isNew && (
              <div className="inline-note">
                snake_case. File: <code>data/patrons/&lt;id&gt;.json</code>.
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

          <label>character_ids</label>
          <div style={{ display: "grid", gap: 8 }}>
            {BUCKET_ORDER.map((bucket, idx) => (
              <div key={bucket} style={{ display: "grid", gridTemplateColumns: "100px 1fr", gap: 8, alignItems: "center" }}>
                <span style={{ color: "var(--text-dim)", fontSize: "0.85em" }}>{bucket}</span>
                <select
                  value={doc.character_ids[idx] ?? ""}
                  onChange={(e) => {
                    const next = [...doc.character_ids];
                    next[idx] = e.target.value;
                    update("character_ids", next);
                  }}
                >
                  <option value="">—</option>
                  {characterOptionsFor(bucket).map((c) => (
                    <option key={c.character_id} value={c.character_id}>
                      {c.display_name || c.character_id}
                    </option>
                  ))}
                  {doc.character_ids[idx] &&
                    !characterOptionsFor(bucket).some((c) => c.character_id === doc.character_ids[idx]) && (
                      <option value={doc.character_ids[idx]}>
                        {doc.character_ids[idx]} (unfiltered)
                      </option>
                    )}
                </select>
              </div>
            ))}
            <div className="inline-note">
              One character per bucket. Filtered to characters whose{" "}
              <code>patron_id</code> is unset or matches this patron.
            </div>
          </div>

          <label>landmark_building_id</label>
          <div>
            <select
              value={doc.landmark_building_id}
              onChange={(e) => update("landmark_building_id", e.target.value)}
            >
              <option value="">—</option>
              {landmarkBuildings.map((b) => (
                <option key={b.building_id} value={b.building_id}>
                  {b.display_name || b.building_id}
                </option>
              ))}
              {doc.landmark_building_id &&
                !landmarkBuildings.some((b) => b.building_id === doc.landmark_building_id) && (
                  <option value={doc.landmark_building_id}>
                    {doc.landmark_building_id} (unfiltered)
                  </option>
                )}
            </select>
            <div className="inline-note">
              Filtered to <code>chain_role=landmark</code>
              {doc.patron_id && ` · patron=${doc.patron_id}`}.
            </div>
          </div>

          <label>portrait</label>
          <input
            value={doc.portrait}
            onChange={(e) => update("portrait", e.target.value)}
            placeholder="res://data/patrons/<id>/portrait.png"
          />

          <label>donation_area</label>
          <div className="donation-grid">
            <div className="rect-inputs">
              <label>
                <span>x</span>
                <input type="number" value={rect[0]} onChange={(e) => setRect(0, Number(e.target.value))} />
              </label>
              <label>
                <span>y</span>
                <input type="number" value={rect[1]} onChange={(e) => setRect(1, Number(e.target.value))} />
              </label>
              <label>
                <span>w</span>
                <input type="number" min={1} value={rect[2]} onChange={(e) => setRect(2, Number(e.target.value))} />
              </label>
              <label>
                <span>h</span>
                <input type="number" min={1} value={rect[3]} onChange={(e) => setRect(3, Number(e.target.value))} />
              </label>
            </div>
            <div className="inline-note">
              Grid cells donated when the landmark completes. Polygon shape deferred.
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
                setSelectedId(manifest.patrons[0]?.patron_id ?? null);
              }}
            >
              Cancel
            </button>
          )}
        </div>

        <div className="quick-links">
          <h3>Events triggered by this patron</h3>
          {relatedEvents.length === 0 ? (
            <div className="placeholder">
              {doc.patron_id
                ? "No events reference this patron yet."
                : "Set patron_id to see related events."}
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
            Event authoring UI comes in Pass B.
          </div>
        </div>
      </main>
    </div>
  );
}
