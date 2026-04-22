import type {
  DialogueNodeDoc,
  DialogueOption,
  DialoguePayload,
  Manifest,
} from "../types";
import { EffectsEditor } from "./EffectEditors";

interface Props {
  node: DialogueNodeDoc;
  payload: DialoguePayload;
  manifest: Manifest;
  onChange: (next: DialogueNodeDoc) => void;
  onRename: (oldId: string, newId: string) => void;
  onDelete: (nodeId: string) => void;
}

export function NodeForm({
  node,
  payload,
  manifest,
  onChange,
  onRename,
  onDelete,
}: Props) {
  const isEntry = node.node_id === payload.entry_node_id;

  const updateOption = (idx: number, patch: Partial<DialogueOption>) => {
    const options = node.options.map((o, i) =>
      i === idx ? { ...o, ...patch } : o
    );
    onChange({ ...node, options });
  };

  const removeOption = (idx: number) =>
    onChange({ ...node, options: node.options.filter((_, i) => i !== idx) });

  const addOption = () =>
    onChange({
      ...node,
      options: [...node.options, { label: "Continue", next: "", effects: [] }],
    });

  return (
    <div className="node-form">
      <div className="form-grid">
        <label>node_id</label>
        <div>
          <input
            value={node.node_id}
            onChange={(e) => onRename(node.node_id, e.target.value)}
          />
          {isEntry && <div className="inline-note">This is the entry node.</div>}
        </div>

        <label>speaker</label>
        <input
          placeholder="(defaults to event's character / patron)"
          value={node.speaker}
          onChange={(e) => onChange({ ...node, speaker: e.target.value })}
        />

        <label>body</label>
        <textarea
          value={node.body}
          onChange={(e) => onChange({ ...node, body: e.target.value })}
          style={{ minHeight: 100 }}
        />

        <label>on_enter effects</label>
        <EffectsEditor
          effects={node.on_enter}
          manifest={manifest}
          onChange={(on_enter) => onChange({ ...node, on_enter })}
        />
      </div>

      <div className="option-list">
        <div className="option-list-header">
          <h3>Options</h3>
          <button onClick={addOption}>+ Add option</button>
        </div>
        {node.options.length === 0 && (
          <div className="inline-note">
            No options — renders as a "Continue" fallback (closes the modal).
          </div>
        )}
        {node.options.map((opt, idx) => (
          <div key={idx} className="option-card">
            <div className="option-row">
              <div>
                <label>label</label>
                <input
                  value={opt.label}
                  onChange={(e) => updateOption(idx, { label: e.target.value })}
                />
              </div>
              <div>
                <label>next</label>
                <select
                  value={opt.next}
                  onChange={(e) => updateOption(idx, { next: e.target.value })}
                >
                  <option value="">(close)</option>
                  {payload.nodes
                    .filter((n) => n.node_id !== node.node_id)
                    .map((n) => (
                      <option key={n.node_id} value={n.node_id}>
                        {n.node_id}
                      </option>
                    ))}
                </select>
              </div>
              <button
                onClick={() => removeOption(idx)}
                title="Remove option"
              >
                ✕
              </button>
            </div>
            <div>
              <label className="option-effects-label">effects</label>
              <EffectsEditor
                effects={opt.effects}
                manifest={manifest}
                onChange={(effects) => updateOption(idx, { effects })}
              />
            </div>
          </div>
        ))}
      </div>

      {!isEntry && (
        <div className="action-row">
          <button onClick={() => onDelete(node.node_id)}>Delete node</button>
        </div>
      )}
    </div>
  );
}
