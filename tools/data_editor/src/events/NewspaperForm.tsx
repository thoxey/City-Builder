import type { NewspaperPayload } from "../types";

interface Props {
  payload: NewspaperPayload;
  onChange: (next: NewspaperPayload) => void;
}

export function NewspaperForm({ payload, onChange }: Props) {
  const update = <K extends keyof NewspaperPayload>(k: K, v: NewspaperPayload[K]) =>
    onChange({ ...payload, [k]: v });

  return (
    <div className="form-grid" style={{ maxWidth: 720 }}>
      <label>headline</label>
      <input value={payload.headline} onChange={(e) => update("headline", e.target.value)} />

      <label>kicker</label>
      <input value={payload.kicker} onChange={(e) => update("kicker", e.target.value)} />

      <label>dateline</label>
      <input
        placeholder="optional — e.g. &quot;Friday, Year One&quot;"
        value={payload.dateline}
        onChange={(e) => update("dateline", e.target.value)}
      />

      <label>body</label>
      <textarea
        value={payload.body}
        onChange={(e) => update("body", e.target.value)}
        style={{ minHeight: 120 }}
      />

      <label>image</label>
      <input
        placeholder="res://data/events/newspaper/<id>.png"
        value={payload.image}
        onChange={(e) => update("image", e.target.value)}
      />
    </div>
  );
}
