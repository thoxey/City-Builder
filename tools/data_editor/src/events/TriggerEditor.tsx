import type { EventTrigger, Manifest } from "../types";
import {
  TRIGGER_SOURCES,
  metaForSource,
  pruneTriggerForSource,
  sourceForEvent,
  type TriggerSource,
} from "./triggerSource";

interface Props {
  trigger: EventTrigger;
  manifest: Manifest;
  onChange: (next: EventTrigger) => void;
}

/** Section-based trigger picker. Source dropdown gates the events list and
 *  shows only the subject picker (character / patron / building / bucket)
 *  that this source actually filters on. */
export function TriggerEditor({ trigger, manifest, onChange }: Props) {
  const source: TriggerSource = sourceForEvent(trigger.event);
  const meta = metaForSource(source);

  const changeSource = (next: TriggerSource) => {
    const nextMeta = metaForSource(next);
    // Default the event to the first one in the new source.
    const nextEvent = nextMeta.events[0] ?? "manual";
    const pruned = pruneTriggerForSource({ ...trigger, event: nextEvent }, next);
    onChange(pruned);
  };

  const changeEvent = (nextEvent: string) => {
    onChange({ ...trigger, event: nextEvent });
  };

  return (
    <fieldset className="trigger-editor">
      <legend>Trigger</legend>
      <div className="form-grid" style={{ maxWidth: 720 }}>
        <label>source</label>
        <select value={source} onChange={(e) => changeSource(e.target.value as TriggerSource)}>
          {TRIGGER_SOURCES.map((s) => (
            <option key={s.id} value={s.id}>
              {s.label}
            </option>
          ))}
        </select>

        <label>event</label>
        <div>
          <select value={trigger.event} onChange={(e) => changeEvent(e.target.value)}>
            {meta.events.map((ev) => (
              <option key={ev} value={ev}>
                {ev}
              </option>
            ))}
          </select>
          <div className="inline-note">{meta.description}</div>
        </div>

        {meta.filterField === "character_id" && (
          <>
            <label>character</label>
            <select
              value={trigger.character_id ?? ""}
              onChange={(e) =>
                onChange({ ...trigger, character_id: e.target.value || undefined })
              }
            >
              <option value="">— any —</option>
              {manifest.characters.map((c) => (
                <option key={c.character_id} value={c.character_id}>
                  {c.display_name || c.character_id}
                </option>
              ))}
            </select>
          </>
        )}

        {meta.filterField === "patron_id" && (
          <>
            <label>patron</label>
            <select
              value={trigger.patron_id ?? ""}
              onChange={(e) =>
                onChange({ ...trigger, patron_id: e.target.value || undefined })
              }
            >
              <option value="">— any —</option>
              {manifest.patrons.map((p) => (
                <option key={p.patron_id} value={p.patron_id}>
                  {p.display_name || p.patron_id}
                </option>
              ))}
            </select>
          </>
        )}

        {meta.filterField === "building_id" && (
          <>
            <label>building</label>
            <select
              value={trigger.building_id ?? ""}
              onChange={(e) =>
                onChange({ ...trigger, building_id: e.target.value || undefined })
              }
            >
              <option value="">— any —</option>
              {manifest.buildings.map((b) => (
                <option key={b.building_id} value={b.building_id}>
                  {b.display_name || b.building_id}
                </option>
              ))}
            </select>
          </>
        )}

        {meta.filterField === "bucket_type_id" && (
          <>
            <label>bucket</label>
            <select
              value={trigger.bucket_type_id ?? ""}
              onChange={(e) =>
                onChange({ ...trigger, bucket_type_id: e.target.value || undefined })
              }
            >
              <option value="">— any —</option>
              {(manifest.bucket_type_ids ?? []).map((b) => (
                <option key={b} value={b}>
                  {b}
                </option>
              ))}
            </select>
          </>
        )}
      </div>
    </fieldset>
  );
}
