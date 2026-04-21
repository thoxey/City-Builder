import type { Effect, Manifest } from "../types";

const EFFECT_KINDS: Array<Effect["kind"]> = [
  "set_flag",
  "fire_event",
  "discount_cost",
  "delay_want",
  "emit_signal",
];

interface Props {
  effects: Effect[];
  manifest: Manifest;
  onChange: (next: Effect[]) => void;
}

export function EffectsEditor({ effects, manifest, onChange }: Props) {
  const update = (idx: number, patch: Partial<Effect>) => {
    const next = effects.map((e, i) => (i === idx ? { ...e, ...patch } : e));
    onChange(next);
  };
  const remove = (idx: number) => onChange(effects.filter((_, i) => i !== idx));
  const add = () =>
    onChange([...effects, { kind: "set_flag", target: "" }]);

  return (
    <div className="effects-editor">
      {effects.length === 0 && (
        <div className="empty-effects">No effects.</div>
      )}
      {effects.map((eff, idx) => (
        <div key={idx} className="effect-row">
          <select
            value={eff.kind}
            onChange={(e) => {
              const kind = e.target.value;
              // Reset fields when kind changes — keeps the doc tidy on save.
              update(idx, {
                kind,
                target: "",
                amount: kind === "discount_cost" || kind === "delay_want" ? 1 : undefined,
              });
            }}
          >
            {EFFECT_KINDS.map((k) => (
              <option key={k} value={k}>{k}</option>
            ))}
            {!EFFECT_KINDS.includes(eff.kind) && (
              <option value={eff.kind}>{eff.kind} (custom)</option>
            )}
          </select>
          <EffectTargetInput effect={eff} manifest={manifest} onChange={(patch) => update(idx, patch)} />
          <button onClick={() => remove(idx)} title="Remove effect">✕</button>
        </div>
      ))}
      <button className="add-effect" onClick={add}>+ Add effect</button>
    </div>
  );
}

interface TargetProps {
  effect: Effect;
  manifest: Manifest;
  onChange: (patch: Partial<Effect>) => void;
}

function EffectTargetInput({ effect, manifest, onChange }: TargetProps) {
  switch (effect.kind) {
    case "set_flag":
      return (
        <input
          placeholder="flag_name"
          value={effect.target ?? ""}
          onChange={(e) => onChange({ target: e.target.value })}
          list="flag-suggestions"
        />
      );
    case "fire_event":
      return (
        <select
          value={effect.target ?? ""}
          onChange={(e) => onChange({ target: e.target.value })}
        >
          <option value="">—</option>
          {manifest.events.map((ev) => (
            <option key={ev.event_id} value={ev.event_id}>
              {ev.event_id} ({ev.event_type})
            </option>
          ))}
          {effect.target &&
            !manifest.events.some((ev) => ev.event_id === effect.target) && (
              <option value={effect.target}>{effect.target} (unresolved)</option>
            )}
        </select>
      );
    case "discount_cost":
      return (
        <div className="effect-compound">
          <select
            value={effect.target ?? ""}
            onChange={(e) => onChange({ target: e.target.value })}
          >
            <option value="">—</option>
            {manifest.buildings.map((b) => (
              <option key={b.building_id} value={b.building_id}>
                {b.display_name || b.building_id}
              </option>
            ))}
          </select>
          <input
            type="number"
            min={1}
            placeholder="amount"
            value={effect.amount ?? 0}
            onChange={(e) => onChange({ amount: Number(e.target.value) })}
          />
        </div>
      );
    case "delay_want":
      return (
        <div className="effect-compound">
          <select
            value={effect.target ?? ""}
            onChange={(e) => onChange({ target: e.target.value })}
          >
            <option value="">—</option>
            {manifest.characters.map((c) => (
              <option key={c.character_id} value={c.character_id}>
                {c.display_name || c.character_id}
              </option>
            ))}
          </select>
          <input
            type="number"
            min={1}
            placeholder="hours"
            value={effect.amount ?? 0}
            onChange={(e) => onChange({ amount: Number(e.target.value) })}
          />
        </div>
      );
    case "emit_signal":
      return (
        <input
          placeholder="signal_name"
          value={effect.target ?? ""}
          onChange={(e) => onChange({ target: e.target.value })}
        />
      );
    default:
      return (
        <input
          placeholder="target"
          value={effect.target ?? ""}
          onChange={(e) => onChange({ target: e.target.value })}
        />
      );
  }
}

// Exposed so the parent can render a shared <datalist> with all known flags.
export function FlagSuggestions({ manifest }: { manifest: Manifest }) {
  return (
    <datalist id="flag-suggestions">
      {manifest.flags.map((f) => (
        <option key={f} value={f} />
      ))}
    </datalist>
  );
}
