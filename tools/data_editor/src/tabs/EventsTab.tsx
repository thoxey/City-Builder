import { useEffect, useMemo, useState } from "react";
import { useApp } from "../store";
import { Sidebar } from "../components/Sidebar";
import type {
  DialogueNodeDoc,
  DialoguePayload,
  EventDoc,
  EventType,
  NewspaperPayload,
  NotificationPayload,
} from "../types";
import { blankEvent, cloneEvent, blankDialogueNode } from "../events/blanks";
import { defaultPathForNewEvent, pathFromRes } from "../events/paths";
import { validateEvent } from "../events/eventValidation";
import { DialogueGraph } from "../events/DialogueGraph";
import { NodeForm } from "../events/NodeForm";
import { NewspaperForm } from "../events/NewspaperForm";
import { NotificationForm } from "../events/NotificationForm";
import { FlagSuggestions } from "../events/EffectEditors";
import { TriggerEditor } from "../events/TriggerEditor";

type NewMenu = null | "dialogue" | "newspaper" | "notification";

export function EventsTab() {
  const { manifest, writeJson, reloadManifest } = useApp();
  if (!manifest) return null;

  const [selectedId, setSelectedId] = useState<string | null>(
    manifest.events[0]?.event_id ?? null
  );
  const [isNew, setIsNew] = useState(false);
  const [newMenu, setNewMenu] = useState<NewMenu>(null);
  const [doc, setDoc] = useState<EventDoc>(manifest.events[0]?.body ?? blankEvent("dialogue"));
  const [originalPath, setOriginalPath] = useState<string | null>(
    manifest.events[0]?._path ?? null
  );
  const [selectedNodeId, setSelectedNodeId] = useState<string | null>(null);
  const [saving, setSaving] = useState(false);
  const [saveError, setSaveError] = useState<string | null>(null);
  const [filterType, setFilterType] = useState<"" | EventType>("");

  useEffect(() => {
    if (isNew) return;
    if (!selectedId) return;
    const ev = manifest.events.find((e) => e.event_id === selectedId);
    if (ev) {
      setDoc(cloneEvent(ev.body));
      setOriginalPath(ev._path);
      setSelectedNodeId(null);
    }
  }, [selectedId, isNew, manifest]);

  const items = useMemo(() => {
    const arr = manifest.events.filter(
      (e) => !filterType || e.event_type === filterType
    );
    return arr.map((e) => ({
      id: e.event_id,
      primary: e.event_id,
      secondary: `${e.event_type} · ${e.trigger_event}${
        e.trigger_character_id ? ` · ${e.trigger_character_id}` : ""
      }${e.trigger_patron_id ? ` · ${e.trigger_patron_id}` : ""}`,
    }));
  }, [manifest.events, filterType]);

  const validation = useMemo(
    () => validateEvent(doc, manifest, { isNew, originalId: selectedId ?? undefined }),
    [doc, manifest, isNew, selectedId]
  );

  const handleNew = (type: EventType) => {
    setIsNew(true);
    setSelectedId(null);
    setDoc(blankEvent(type));
    setOriginalPath(null);
    setSelectedNodeId(null);
    setSaveError(null);
    setNewMenu(null);
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
      // Derive on-disk payload: dialogue auto-fills tree_id if missing.
      const toSave = cloneEvent(doc);
      if (toSave.event_type === "dialogue") {
        const p = toSave.payload as DialoguePayload;
        if (!p.tree_id) p.tree_id = `${toSave.event_id}_tree`;
      }
      const path = originalPath ? pathFromRes(originalPath) : defaultPathForNewEvent(toSave);
      await writeJson(path, toSave);
      await reloadManifest();
      setIsNew(false);
      setSelectedId(toSave.event_id);
    } catch (e) {
      setSaveError((e as Error).message);
    } finally {
      setSaving(false);
    }
  };

  // ---- Payload + node helpers ----

  const updatePayload = <P extends EventDoc["payload"]>(patch: P) =>
    setDoc((d) => ({ ...d, payload: patch } as EventDoc));

  const dialoguePayload = doc.event_type === "dialogue" ? (doc.payload as DialoguePayload) : null;
  const selectedNode =
    dialoguePayload?.nodes.find((n) => n.node_id === selectedNodeId) ?? null;

  const addNode = () => {
    if (!dialoguePayload) return;
    const base = "n_";
    let n = 1;
    while (dialoguePayload.nodes.some((x) => x.node_id === `${base}${n}`)) n += 1;
    const newNode = blankDialogueNode(`${base}${n}`);
    updatePayload({ ...dialoguePayload, nodes: [...dialoguePayload.nodes, newNode] });
    setSelectedNodeId(newNode.node_id);
  };

  const updateNode = (next: DialogueNodeDoc) => {
    if (!dialoguePayload) return;
    const nodes = dialoguePayload.nodes.map((n) => (n.node_id === next.node_id ? next : n));
    updatePayload({ ...dialoguePayload, nodes });
  };

  const renameNode = (oldId: string, newId: string) => {
    if (!dialoguePayload) return;
    if (oldId === newId) return;
    if (!newId.trim()) return;
    if (dialoguePayload.nodes.some((n) => n.node_id === newId)) return; // ignore clashes
    const nodes = dialoguePayload.nodes.map((n) => {
      if (n.node_id === oldId) return { ...n, node_id: newId };
      return {
        ...n,
        options: n.options.map((o) => (o.next === oldId ? { ...o, next: newId } : o)),
      };
    });
    const entry =
      dialoguePayload.entry_node_id === oldId ? newId : dialoguePayload.entry_node_id;
    updatePayload({ ...dialoguePayload, entry_node_id: entry, nodes });
    setSelectedNodeId(newId);
  };

  const deleteNode = (nodeId: string) => {
    if (!dialoguePayload) return;
    if (nodeId === dialoguePayload.entry_node_id) return;
    const nodes = dialoguePayload.nodes
      .filter((n) => n.node_id !== nodeId)
      .map((n) => ({
        ...n,
        options: n.options.map((o) => (o.next === nodeId ? { ...o, next: "" } : o)),
      }));
    updatePayload({ ...dialoguePayload, nodes });
    setSelectedNodeId(null);
  };

  return (
    <div className="tab-layout">
      <FlagSuggestions manifest={manifest} />
      <Sidebar
        items={items}
        selectedId={isNew ? null : selectedId}
        onSelect={handleSelect}
        onNew={() => setNewMenu(newMenu ? null : "dialogue")}
        newLabel="+ New ▾"
        placeholder="Filter events…"
      />
      {newMenu && (
        <div className="new-menu">
          <button onClick={() => handleNew("dialogue")}>Dialogue</button>
          <button onClick={() => handleNew("newspaper")}>Newspaper</button>
          <button onClick={() => handleNew("notification")}>Notification</button>
          <button onClick={() => setNewMenu(null)}>Cancel</button>
        </div>
      )}

      <main className="editor-pane events-pane">
        <div className="events-envelope">
          <h2>{isNew ? `New ${doc.event_type}` : doc.event_id || "—"}</h2>
          <div className="form-grid" style={{ maxWidth: 900 }}>
            <label>event_id</label>
            <input
              value={doc.event_id}
              disabled={!isNew}
              onChange={(e) => setDoc({ ...doc, event_id: e.target.value })}
              placeholder="aristocrat_landmark_ready"
            />

            <label>event_type</label>
            <select
              value={doc.event_type}
              disabled={!isNew}
              onChange={(e) => {
                const fresh = blankEvent(e.target.value as EventType);
                // Preserve the envelope the author already filled out; swap
                // only the payload shape.
                setDoc({ ...fresh, event_id: doc.event_id, trigger: doc.trigger, enabled_if: doc.enabled_if });
              }}
            >
              {manifest.event_types.map((t) => (
                <option key={t} value={t}>{t}</option>
              ))}
            </select>

            <label>enabled_if</label>
            <div>
              <input
                value={doc.enabled_if}
                onChange={(e) => setDoc({ ...doc, enabled_if: e.target.value })}
                placeholder='cash > 100 && flag.met_aristocrat'
              />
              <div className="inline-note">
                DSL: <code>cash</code>, <code>flag.&lt;name&gt;</code>,{" "}
                <code>has_placed:&lt;id&gt;</code>,{" "}
                <code>total.&lt;bucket&gt;</code>, <code>fulfilled.&lt;bucket&gt;</code>,{" "}
                <code>unserved.&lt;bucket&gt;</code> (<code>demand.&lt;bucket&gt;</code> aliases unserved),{" "}
                <code>state.&lt;cid&gt;</code>, <code>count.&lt;event_id&gt;</code>. Combine with{" "}
                <code>&amp;&amp;</code> <code>||</code> and parens.
              </div>
            </div>
          </div>

          <TriggerEditor
            trigger={doc.trigger}
            manifest={manifest}
            onChange={(next) => setDoc({ ...doc, trigger: next })}
          />
        </div>

        <div className="events-payload">
          {doc.event_type === "dialogue" && dialoguePayload && (
            <div className="dialogue-editor">
              <DialogueGraph
                payload={dialoguePayload}
                selectedNodeId={selectedNodeId}
                onSelectNode={setSelectedNodeId}
                onUpdatePayload={(p) => updatePayload(p)}
                onAddNode={addNode}
              />
              <div className="dialogue-node-form">
                {selectedNode ? (
                  <NodeForm
                    node={selectedNode}
                    payload={dialoguePayload}
                    manifest={manifest}
                    onChange={updateNode}
                    onRename={renameNode}
                    onDelete={deleteNode}
                  />
                ) : (
                  <div className="empty small">
                    Select a node in the graph to edit it.
                  </div>
                )}
              </div>
            </div>
          )}

          {doc.event_type === "newspaper" && (
            <NewspaperForm
              payload={doc.payload as NewspaperPayload}
              onChange={(p) => updatePayload(p)}
            />
          )}

          {doc.event_type === "notification" && (
            <NotificationForm
              payload={doc.payload as NotificationPayload}
              onChange={(p) => updatePayload(p)}
            />
          )}
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
                setSelectedId(manifest.events[0]?.event_id ?? null);
              }}
            >
              Cancel
            </button>
          )}
          <div className="spacer" />
          <label style={{ display: "flex", alignItems: "center", gap: 6, color: "var(--text-dim)", fontSize: "0.85em" }}>
            filter:
            <select
              value={filterType}
              onChange={(e) => setFilterType(e.target.value as "" | EventType)}
            >
              <option value="">all</option>
              {manifest.event_types.map((t) => (
                <option key={t} value={t}>{t}</option>
              ))}
            </select>
          </label>
        </div>
      </main>
    </div>
  );
}
