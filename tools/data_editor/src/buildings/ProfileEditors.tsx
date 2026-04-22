import type {
  BuildingProfile,
  Bucket,
  GenericTierProfile,
  Manifest,
  Profile,
  ProfileType,
  RoadMetadataProfile,
  UniqueProfile,
} from "../types";
import { ALL_PROFILE_TYPES, blankProfile } from "./blanks";

interface Props {
  profiles: Profile[];
  manifest: Manifest;
  selfId: string;
  onChange: (next: Profile[]) => void;
}

export function ProfilesEditor({ profiles, manifest, selfId, onChange }: Props) {
  const update = (idx: number, next: Profile) =>
    onChange(profiles.map((p, i) => (i === idx ? next : p)));

  const remove = (idx: number) => onChange(profiles.filter((_, i) => i !== idx));

  const addOfType = (type: ProfileType) => {
    if (profiles.some((p) => p.type === type)) return; // one of each
    onChange([...profiles, blankProfile(type)]);
  };

  const availableTypes = ALL_PROFILE_TYPES.filter(
    (t) => !profiles.some((p) => p.type === t)
  );

  return (
    <div className="profiles-editor">
      {profiles.length === 0 && (
        <div className="inline-note">No profiles. Add one below.</div>
      )}
      {profiles.map((p, idx) => (
        <div key={`${p.type}-${idx}`} className="profile-card">
          <div className="profile-card-header">
            <span className="profile-type">{p.type}</span>
            <button onClick={() => remove(idx)} title="Remove profile">✕</button>
          </div>
          <ProfileForm
            profile={p}
            manifest={manifest}
            selfId={selfId}
            onChange={(next) => update(idx, next)}
          />
        </div>
      ))}
      {availableTypes.length > 0 && (
        <div className="profile-add-row">
          <label style={{ color: "var(--text-dim)", fontSize: "0.85em" }}>
            Add profile:
          </label>
          {availableTypes.map((t) => (
            <button key={t} onClick={() => addOfType(t)}>+ {t}</button>
          ))}
        </div>
      )}
    </div>
  );
}

interface FormProps {
  profile: Profile;
  manifest: Manifest;
  selfId: string;
  onChange: (next: Profile) => void;
}

function ProfileForm({ profile, manifest, selfId, onChange }: FormProps) {
  switch (profile.type) {
    case "BuildingMetadata":
    case "PoliceMetadata":
    case "MedicalMetadata":
      return <div className="inline-note">No fields — marker profile.</div>;
    case "BuildingProfile":
      return <BuildingProfileForm p={profile} onChange={onChange} />;
    case "UniqueProfile":
      return (
        <UniqueProfileForm
          p={profile}
          manifest={manifest}
          selfId={selfId}
          onChange={onChange}
        />
      );
    case "GenericTierProfile":
      return <GenericTierProfileForm p={profile} manifest={manifest} onChange={onChange} />;
    case "RoadMetadata":
      return <RoadMetadataForm p={profile} onChange={onChange} />;
  }
}

// ---- individual profile forms ----

function BuildingProfileForm({
  p,
  onChange,
}: {
  p: BuildingProfile;
  onChange: (next: BuildingProfile) => void;
}) {
  const update = <K extends keyof BuildingProfile>(k: K, v: BuildingProfile[K]) =>
    onChange({ ...p, [k]: v });
  return (
    <div className="form-grid">
      <label>category</label>
      <select value={p.category} onChange={(e) => update("category", e.target.value as Bucket)}>
        <option value="">—</option>
        <option value="residential">residential</option>
        <option value="commercial">commercial</option>
        <option value="industrial">industrial</option>
      </select>

      <label>capacity</label>
      <input
        type="number"
        min={0}
        value={p.capacity}
        onChange={(e) => update("capacity", Number(e.target.value))}
      />

      <label>active window</label>
      <div className="active-window">
        <input
          type="number"
          step={0.5}
          min={0}
          max={24}
          value={p.active_start}
          onChange={(e) => update("active_start", Number(e.target.value))}
        />
        <span>→</span>
        <input
          type="number"
          step={0.5}
          min={0}
          max={24}
          value={p.active_end}
          onChange={(e) => update("active_end", Number(e.target.value))}
        />
      </div>
    </div>
  );
}

function UniqueProfileForm({
  p,
  manifest,
  selfId,
  onChange,
}: {
  p: UniqueProfile;
  manifest: Manifest;
  selfId: string;
  onChange: (next: UniqueProfile) => void;
}) {
  const update = <K extends keyof UniqueProfile>(k: K, v: UniqueProfile[K]) =>
    onChange({ ...p, [k]: v });

  const togglePrereq = (bid: string) => {
    const has = p.prerequisite_ids.includes(bid);
    update(
      "prerequisite_ids",
      has ? p.prerequisite_ids.filter((x) => x !== bid) : [...p.prerequisite_ids, bid]
    );
  };

  const eligiblePrereqs = manifest.buildings.filter(
    (b) => b.building_id !== selfId && b.building_id !== ""
  );

  return (
    <div className="form-grid">
      <label>bucket</label>
      <select value={p.bucket} onChange={(e) => update("bucket", e.target.value as Bucket)}>
        <option value="">—</option>
        <option value="residential">residential</option>
        <option value="commercial">commercial</option>
        <option value="industrial">industrial</option>
      </select>

      <label>tier</label>
      <input
        type="number"
        min={0}
        max={3}
        value={p.tier}
        onChange={(e) => update("tier", Number(e.target.value))}
      />

      <label>patron_id</label>
      <select value={p.patron_id} onChange={(e) => update("patron_id", e.target.value)}>
        <option value="">—</option>
        {manifest.patrons.map((pt) => (
          <option key={pt.patron_id} value={pt.patron_id}>
            {pt.display_name || pt.patron_id}
          </option>
        ))}
      </select>

      <label>character_id</label>
      <select
        value={p.character_id}
        onChange={(e) => update("character_id", e.target.value)}
      >
        <option value="">—</option>
        {manifest.characters
          .filter((c) => !p.patron_id || c.patron_id === p.patron_id)
          .map((c) => (
            <option key={c.character_id} value={c.character_id}>
              {c.display_name || c.character_id}
            </option>
          ))}
      </select>

      <label>chain_role</label>
      <select
        value={p.chain_role}
        onChange={(e) => update("chain_role", e.target.value as UniqueProfile["chain_role"])}
      >
        <option value="">—</option>
        <option value="chain">chain</option>
        <option value="want">want</option>
        <option value="landmark">landmark</option>
      </select>

      <label>prereq_threshold</label>
      <input
        type="number"
        min={0}
        value={p.prerequisite_threshold}
        onChange={(e) => update("prerequisite_threshold", Number(e.target.value))}
      />

      <label>desirability_boost</label>
      <input
        type="number"
        step={0.01}
        value={p.desirability_boost}
        onChange={(e) => update("desirability_boost", Number(e.target.value))}
      />

      <label>prerequisite_ids</label>
      <div className="prereq-picker">
        {p.prerequisite_ids.length === 0 && (
          <div className="inline-note">No prerequisites selected.</div>
        )}
        {p.prerequisite_ids.map((pid) => (
          <span key={pid} className="prereq-chip">
            {pid}
            <button onClick={() => togglePrereq(pid)}>✕</button>
          </span>
        ))}
        <select
          value=""
          onChange={(e) => {
            if (e.target.value) togglePrereq(e.target.value);
          }}
        >
          <option value="">+ Add prerequisite…</option>
          {eligiblePrereqs
            .filter((b) => !p.prerequisite_ids.includes(b.building_id))
            .map((b) => (
              <option key={b.building_id} value={b.building_id}>
                {b.display_name || b.building_id} ({b.category})
              </option>
            ))}
        </select>
      </div>
    </div>
  );
}

function GenericTierProfileForm({
  p,
  manifest,
  onChange,
}: {
  p: GenericTierProfile;
  manifest: Manifest;
  onChange: (next: GenericTierProfile) => void;
}) {
  const knownPools = Array.from(
    new Set(manifest.buildings.map((b) => b.pool_id).filter((x): x is string => !!x))
  );
  const update = <K extends keyof GenericTierProfile>(k: K, v: GenericTierProfile[K]) =>
    onChange({ ...p, [k]: v });
  return (
    <div className="form-grid">
      <label>bucket</label>
      <select value={p.bucket} onChange={(e) => update("bucket", e.target.value as Bucket)}>
        <option value="">—</option>
        <option value="residential">residential</option>
        <option value="commercial">commercial</option>
        <option value="industrial">industrial</option>
      </select>
      <label>tier</label>
      <input
        type="number"
        min={1}
        max={3}
        value={p.tier}
        onChange={(e) => update("tier", Number(e.target.value))}
      />
      <label>pool_id</label>
      <div>
        <input
          list="pool-suggestions"
          value={p.pool_id}
          onChange={(e) => update("pool_id", e.target.value)}
          placeholder="residential_t1"
        />
        <datalist id="pool-suggestions">
          {knownPools.map((pl) => (
            <option key={pl} value={pl} />
          ))}
        </datalist>
        <div className="inline-note">
          Matches a pool config in <code>data/buildings/generic/_pools/</code>.
        </div>
      </div>
    </div>
  );
}

function RoadMetadataForm({
  p,
  onChange,
}: {
  p: RoadMetadataProfile;
  onChange: (next: RoadMetadataProfile) => void;
}) {
  const update = <K extends keyof RoadMetadataProfile>(k: K, v: RoadMetadataProfile[K]) =>
    onChange({ ...p, [k]: v });

  const setConnection = (idx: number, axis: 0 | 1, val: number) => {
    const next = p.connections.map((c, i) =>
      i === idx ? ([axis === 0 ? val : c[0], axis === 1 ? val : c[1]] as [number, number]) : c
    );
    update("connections", next);
  };

  return (
    <div className="form-grid">
      <label>road_type</label>
      <input
        type="number"
        min={0}
        value={p.road_type}
        onChange={(e) => update("road_type", Number(e.target.value))}
      />
      <label>connections</label>
      <div className="connections-editor">
        {p.connections.length === 0 && (
          <div className="inline-note">No connections. Each entry is a unit-vector cell offset.</div>
        )}
        {p.connections.map((c, idx) => (
          <div key={idx} className="connection-row">
            <input
              type="number"
              value={c[0]}
              onChange={(e) => setConnection(idx, 0, Number(e.target.value))}
            />
            <input
              type="number"
              value={c[1]}
              onChange={(e) => setConnection(idx, 1, Number(e.target.value))}
            />
            <button
              onClick={() =>
                update(
                  "connections",
                  p.connections.filter((_, i) => i !== idx)
                )
              }
            >
              ✕
            </button>
          </div>
        ))}
        <button
          onClick={() => update("connections", [...p.connections, [0, 0]])}
          className="add-connection"
        >
          + Add connection
        </button>
      </div>
    </div>
  );
}
