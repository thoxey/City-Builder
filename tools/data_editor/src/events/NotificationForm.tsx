import type { NotificationPayload } from "../types";

interface Props {
  payload: NotificationPayload;
  onChange: (next: NotificationPayload) => void;
}

export function NotificationForm({ payload, onChange }: Props) {
  const update = <K extends keyof NotificationPayload>(k: K, v: NotificationPayload[K]) =>
    onChange({ ...payload, [k]: v });

  return (
    <div className="form-grid" style={{ maxWidth: 720 }}>
      <label>text</label>
      <textarea
        value={payload.text}
        onChange={(e) => update("text", e.target.value)}
        style={{ minHeight: 60 }}
      />

      <label>duration (s)</label>
      <input
        type="number"
        min={0.5}
        step={0.5}
        value={payload.duration}
        onChange={(e) => update("duration", Number(e.target.value))}
      />

      <label>icon</label>
      <input
        placeholder="res://data/events/notifications/<id>.png (optional)"
        value={payload.icon ?? ""}
        onChange={(e) => update("icon", e.target.value)}
      />
    </div>
  );
}
