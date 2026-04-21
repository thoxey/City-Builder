import { useMemo, useState } from "react";
import { useApp } from "../store";
import { validateCharacter, validatePatron } from "../validators";
import { validateEvent } from "../events/eventValidation";
import { validateBuilding } from "../buildings/validation";
import type { CharacterDoc, Manifest, PatronDoc } from "../types";

type Row = {
  scope: "characters" | "patrons" | "events" | "buildings";
  id: string;
  severity: "error" | "warning";
  message: string;
};

function sweep(manifest: Manifest): Row[] {
  const rows: Row[] = [];

  for (const c of manifest.characters) {
    const doc: CharacterDoc = {
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
    const r = validateCharacter(doc, manifest, {
      isNew: false,
      originalId: c.character_id,
    });
    for (const e of r.errors)
      rows.push({ scope: "characters", id: c.character_id, severity: "error", message: e });
    for (const w of r.warnings)
      rows.push({ scope: "characters", id: c.character_id, severity: "warning", message: w });
  }

  for (const p of manifest.patrons) {
    const doc: PatronDoc = {
      patron_id: p.patron_id,
      display_name: p.display_name,
      bio: p.bio,
      character_ids: p.character_ids,
      landmark_building_id: p.landmark_building_id,
      portrait: p.portrait,
      donation_area: p.donation_area,
    };
    const r = validatePatron(doc, manifest, {
      isNew: false,
      originalId: p.patron_id,
    });
    for (const e of r.errors)
      rows.push({ scope: "patrons", id: p.patron_id, severity: "error", message: e });
    for (const w of r.warnings)
      rows.push({ scope: "patrons", id: p.patron_id, severity: "warning", message: w });
  }

  for (const ev of manifest.events) {
    const r = validateEvent(ev.body, manifest, {
      isNew: false,
      originalId: ev.event_id,
    });
    for (const e of r.errors)
      rows.push({ scope: "events", id: ev.event_id, severity: "error", message: e });
    for (const w of r.warnings)
      rows.push({ scope: "events", id: ev.event_id, severity: "warning", message: w });
  }

  for (const b of manifest.buildings) {
    const r = validateBuilding(b.body, manifest, {
      isNew: false,
      originalId: b.building_id,
    });
    for (const e of r.errors)
      rows.push({ scope: "buildings", id: b.building_id, severity: "error", message: e });
    for (const w of r.warnings)
      rows.push({ scope: "buildings", id: b.building_id, severity: "warning", message: w });
  }

  return rows;
}

export function ValidatePanel() {
  const { manifest, setTab } = useApp();
  const [open, setOpen] = useState(false);

  const rows = useMemo(() => (manifest ? sweep(manifest) : []), [manifest]);
  const errorCount = rows.filter((r) => r.severity === "error").length;
  const warnCount = rows.filter((r) => r.severity === "warning").length;

  if (!manifest) return null;

  return (
    <>
      <button
        className={errorCount > 0 ? "validate-btn has-errors" : warnCount > 0 ? "validate-btn has-warnings" : "validate-btn"}
        onClick={() => setOpen(!open)}
        title="Run validation across every manifest entity"
      >
        {errorCount > 0
          ? `Validate ⛔ ${errorCount}`
          : warnCount > 0
          ? `Validate ⚠ ${warnCount}`
          : "Validate ✓"}
      </button>
      {open && (
        <div className="validate-panel">
          <div className="validate-panel-header">
            <strong>Validation report</strong>
            <span>
              {errorCount} error{errorCount === 1 ? "" : "s"} · {warnCount} warning
              {warnCount === 1 ? "" : "s"}
            </span>
            <button onClick={() => setOpen(false)}>✕</button>
          </div>
          {rows.length === 0 ? (
            <div className="validate-empty">All clear.</div>
          ) : (
            <ul className="validate-list">
              {rows.map((r, i) => (
                <li key={i} className={`validate-row ${r.severity}`}>
                  <span className="sev">
                    {r.severity === "error" ? "⛔" : "⚠"}
                  </span>
                  <button
                    className="jump"
                    onClick={() => {
                      setTab(r.scope);
                      setOpen(false);
                    }}
                    title={`Jump to ${r.scope} tab`}
                  >
                    {r.scope}:{r.id}
                  </button>
                  <span className="msg">{r.message}</span>
                </li>
              ))}
            </ul>
          )}
        </div>
      )}
    </>
  );
}
