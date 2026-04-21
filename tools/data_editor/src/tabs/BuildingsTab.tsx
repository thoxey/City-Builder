import { useEffect, useMemo, useState } from "react";
import { useApp } from "../store";
import { Sidebar } from "../components/Sidebar";
import type { BuildingDoc, BuildingCategory } from "../types";
import { blankBuilding, cloneBuilding } from "../buildings/blanks";
import { validateBuilding } from "../buildings/validation";
import { ProfilesEditor } from "../buildings/ProfileEditors";
import { FootprintEditor } from "../buildings/FootprintEditor";
import { pathFromRes } from "../events/paths";

export function BuildingsTab() {
  const { manifest, writeJson, reloadManifest } = useApp();
  if (!manifest) return null;

  const [selectedId, setSelectedId] = useState<string | null>(
    manifest.buildings[0]?.building_id ?? null
  );
  const [isNew, setIsNew] = useState(false);
  const [doc, setDoc] = useState<BuildingDoc>(
    manifest.buildings[0]?.body ?? blankBuilding()
  );
  const [originalPath, setOriginalPath] = useState<string | null>(
    manifest.buildings[0]?._path ?? null
  );
  const [categoryFilter, setCategoryFilter] = useState<"" | BuildingCategory>("");
  const [saving, setSaving] = useState(false);
  const [saveError, setSaveError] = useState<string | null>(null);

  useEffect(() => {
    if (isNew) return;
    if (!selectedId) return;
    const b = manifest.buildings.find((x) => x.building_id === selectedId);
    if (b) {
      setDoc(cloneBuilding(b.body));
      setOriginalPath(b._path);
    }
  }, [selectedId, isNew, manifest]);

  const items = useMemo(() => {
    const list = manifest.buildings.filter(
      (b) => !categoryFilter || b.category === categoryFilter
    );
    return list.map((b) => ({
      id: b.building_id,
      primary: b.display_name || b.building_id,
      secondary: `${b.category}${b.pool_id ? ` · ${b.pool_id}` : ""}${
        b.chain_role ? ` · ${b.chain_role}` : ""
      }`,
    }));
  }, [manifest.buildings, categoryFilter]);

  const validation = useMemo(
    () => validateBuilding(doc, manifest, { isNew, originalId: selectedId ?? undefined }),
    [doc, manifest, isNew, selectedId]
  );

  const update = <K extends keyof BuildingDoc>(k: K, v: BuildingDoc[K]) =>
    setDoc((d) => ({ ...d, [k]: v }));

  const handleNew = () => {
    setIsNew(true);
    setSelectedId(null);
    setDoc(blankBuilding());
    setOriginalPath(null);
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
      const toSave = cloneBuilding(doc);
      // Default pathing: existing → preserve, new → data/buildings/<category>/<id>.json.
      const path = originalPath
        ? pathFromRes(originalPath)
        : ["data", "buildings", toSave.category || "unique", `${toSave.building_id}.json`];
      await writeJson(path, toSave);
      await reloadManifest();
      setIsNew(false);
      setSelectedId(toSave.building_id);
    } catch (e) {
      setSaveError((e as Error).message);
    } finally {
      setSaving(false);
    }
  };

  return (
    <div className="tab-layout">
      <Sidebar
        items={items}
        selectedId={isNew ? null : selectedId}
        onSelect={handleSelect}
        onNew={handleNew}
        newLabel="+ New"
        placeholder="Filter buildings…"
      />

      <main className="editor-pane">
        <div className="buildings-header">
          <h2>{isNew ? "New building" : doc.display_name || doc.building_id || "—"}</h2>
          <label className="filter-label">
            category:
            <select
              value={categoryFilter}
              onChange={(e) =>
                setCategoryFilter(e.target.value as "" | BuildingCategory)
              }
            >
              <option value="">all</option>
              {manifest.categories.map((c) => (
                <option key={c} value={c}>{c}</option>
              ))}
            </select>
          </label>
        </div>

        <div className="form-grid" style={{ maxWidth: 820 }}>
          <label>building_id</label>
          <input
            value={doc.building_id}
            disabled={!isNew}
            onChange={(e) => update("building_id", e.target.value)}
            placeholder="building_members_club"
          />

          <label>display_name</label>
          <input
            value={doc.display_name}
            onChange={(e) => update("display_name", e.target.value)}
          />

          <label>description</label>
          <textarea
            value={doc.description}
            onChange={(e) => update("description", e.target.value)}
          />

          <label>category</label>
          <select
            value={doc.category}
            onChange={(e) => update("category", e.target.value as BuildingCategory | "")}
          >
            <option value="">—</option>
            {manifest.categories.map((c) => (
              <option key={c} value={c}>{c}</option>
            ))}
          </select>

          <label>pool_id</label>
          <input
            value={doc.pool_id ?? ""}
            onChange={(e) => update("pool_id", e.target.value || undefined)}
            placeholder="(optional — pooled generics & decoratives)"
          />

          <label>cash_cost</label>
          <input
            type="number"
            min={0}
            value={doc.cash_cost ?? 0}
            onChange={(e) => {
              const v = Number(e.target.value);
              update("cash_cost", v > 0 ? v : undefined);
            }}
            placeholder="0 = no cash cost"
          />

          <label>model_path</label>
          <div>
            <input
              value={doc.model_path}
              onChange={(e) => update("model_path", e.target.value)}
              placeholder="res://models/<folder>/<file>.glb"
            />
            <div className="inline-note">
              Drop the .glb into a <code>models/&lt;id&gt;/</code> folder in Godot,
              re-export the manifest, then paste the path here.
            </div>
          </div>

          <label>model_scale</label>
          <input
            type="number"
            step={0.05}
            min={0}
            value={doc.model_scale}
            onChange={(e) => update("model_scale", Number(e.target.value))}
          />

          <label>model_offset</label>
          <div className="xyz-row">
            {(["x", "y", "z"] as const).map((axis, idx) => (
              <label key={axis}>
                <span>{axis}</span>
                <input
                  type="number"
                  step={0.1}
                  value={doc.model_offset[idx]}
                  onChange={(e) => {
                    const next: [number, number, number] = [...doc.model_offset];
                    next[idx] = Number(e.target.value);
                    update("model_offset", next);
                  }}
                />
              </label>
            ))}
          </div>

          <label>model_rotation_y</label>
          <input
            type="number"
            step={15}
            value={doc.model_rotation_y}
            onChange={(e) => update("model_rotation_y", Number(e.target.value))}
          />

          <label>footprint</label>
          <FootprintEditor
            cells={doc.footprint}
            onChange={(c) => update("footprint", c)}
          />

          <label>tags</label>
          <TagsInput
            tags={doc.tags}
            onChange={(next) => update("tags", next)}
          />
        </div>

        <div className="section-break">
          <h3>Profiles</h3>
          <ProfilesEditor
            profiles={doc.profiles}
            manifest={manifest}
            selfId={doc.building_id}
            onChange={(profiles) => update("profiles", profiles)}
          />
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
                setSelectedId(manifest.buildings[0]?.building_id ?? null);
              }}
            >
              Cancel
            </button>
          )}
        </div>
      </main>
    </div>
  );
}

function TagsInput({
  tags,
  onChange,
}: {
  tags: string[];
  onChange: (next: string[]) => void;
}) {
  const [draft, setDraft] = useState("");
  const commit = () => {
    const t = draft.trim();
    if (!t || tags.includes(t)) {
      setDraft("");
      return;
    }
    onChange([...tags, t]);
    setDraft("");
  };

  return (
    <div className="tags-input">
      <div className="tag-chips">
        {tags.map((t) => (
          <span key={t} className="tag-chip">
            {t}
            <button onClick={() => onChange(tags.filter((x) => x !== t))}>✕</button>
          </span>
        ))}
      </div>
      <input
        value={draft}
        onChange={(e) => setDraft(e.target.value)}
        onKeyDown={(e) => {
          if (e.key === "Enter") {
            e.preventDefault();
            commit();
          }
        }}
        onBlur={commit}
        placeholder="type a tag + Enter"
      />
    </div>
  );
}
