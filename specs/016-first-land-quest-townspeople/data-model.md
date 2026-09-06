# Data Model: First Land Quest and Townspeople

## Persisted FirstLandQuestState

`DataMap.first_land_quest_state: Dictionary` is owned by `FirstLandQuest`. Missing or
empty means a fresh/legacy save and normalizes conservatively.

```text
FirstLandQuestState {
  schema_version: 1
  quest_id: "first_land_quest"
  phase: "LOCKED" | "AVAILABLE" | "PENDING" | "AGREED" | "COMPLETED"
  activation: QuestReceipt
  selected_approach_id: "" | ApproachId
  agreement: QuestReceipt
  outcome: QuestOutcome
  completion: QuestReceipt
  diagnostics: Array<Diagnostic>
}
```

Phases are monotonic. The reconciler derives the furthest provable phase from receipts,
EventSystem pending/count/flags, and BuildableArea grants. Unknown or contradictory
fields do not advance progress and produce stable diagnostics.

### QuestReceipt

```text
QuestReceipt {
  receipt_id: String
  evidence_kind: String
  evidence: Dictionary        # detached and JSON-safe
}
```

Expected receipt IDs:

- `first_land_quest.activated`
- `first_land_quest.agreed`
- `first_land_quest.land_granted` or an approved follow-up equivalent
- `first_land_quest.completed`

Receipts contain semantic IDs and relevant cell counts, never prose, portrait paths,
transcript state, or wall-clock timestamps.

## FirstLandQuestDefinition

Authored data loaded from `data/quests/first_land_quest.json` after approval:

```text
FirstLandQuestDefinition {
  quest_id: "first_land_quest"
  schema_version: 1
  invitation_event_id: String
  negotiation_event_id: String
  reaction_event_ids: Array<String>
  place_association: PlaceAssociation
  approaches: Array<ApproachDefinition>
  outcome: OutcomeDefinition
  townsperson_ids: Array<String>   # exactly four, one dominant quality each
}
```

The definition contains no dialogue prose. Event IDs must resolve to valid dialogue
records and townsperson IDs must resolve to valid character definitions.

## PlaceAssociation

```text
PlaceAssociation {
  place_id: String
  owner_character_id: "aristocrat_patron"
  kind: "residence" | "estate" | "office" | "other"
  building_id: String             # approved existing/new canonical ID
  staging_mode: "world_anchor" | "placed_structure" | "dialogue_establishing_shot"
  anchor: Coordinate | null
}
```

The association makes Sir William's relationship to a place explicit even when the
dialogue UI remains modal. If a new structure is approved, its placement/world-loading
contract belongs in the implementation tasks; the quest state stores only semantic
identity and detached coordinate evidence.

## ApproachDefinition

```text
ApproachDefinition {
  approach_id: "practical_case" | "community_case" | "stewardship_case"
  option_flag: String
  outcome_id: String
}
```

IDs above are proposed semantic defaults, not approved option labels. Every approved
DialogueOption sets exactly one option flag. Normalization rejects multiple approach
flags; recovery may select the first in declared definition order only as a diagnostic,
never silently.

## QuestOutcome

```text
QuestOutcome {
  outcome_id: String
  kind: "land_grant" | "follow_up"
  applied: bool
  grant_id: String
  added_cell_count: int
  overlapping_cell_count: int
  follow_up_id: String
}
```

For the recommended first slice, `kind` is `land_grant`, all approaches resolve to one
outcome ID, and `grant_id` is `first_land_quest_parcel`.

## LandGrantDefinition and receipt

```text
LandGrantDefinition {
  grant_id: "first_land_quest_parcel"
  shape: "rect" | "polygon"
  rect: [x, z, width, height]      # when rect
  polygon: Array<[x, z]>           # when polygon
}

DataMap.land_grants_applied {
  <grant_id>: {
    applied: true
    requested_cell_count: int
    added_cell_count: int
    overlapping_cell_count: int
  }
}
```

BuildableArea expands the definition through the existing `LandDonationPayload` parser,
writes the receipt after successful validation/application, and returns detached added
cells for diagnostics. This receipt is separate from `patron_donations_applied`.

## TownspersonProfile

Each approved named minor townsperson extends the existing character JSON with:

```text
townsperson_profile: {
  profile_version: 1
  dominant_quality: "opportunity" | "liveability" | "beauty" | "belonging"
  motivation_id: String
  wants: Array<String>             # semantic tags, not displayed prose
  tolerates: Array<String>
  refuses: Array<String>
  tensions_with: Array<CharacterId>
  reaction_tags: Array<String>
  voice_anchor: {
    rhythm: String
    social_posture: String
    humour_mode: String
    avoids: Array<String>
  }
}
```

The ordinary CharacterSystem continues to own identity, display name, portrait,
default expression, and expression map. The profile is an authored reaction-selection
contract. It does not modify CommunityResident weights or live quality scores.

Exactly four profiles in this quest definition must cover every canonical quality once.
Names, biographical prose, and voice-anchor values require user approval before runtime
data is added.

## ApprovedScenePackage

```text
ApprovedScenePackage {
  approval_status: "approved"
  approved_on: YYYY-MM-DD
  events: Array<DialogueEvent>
  beat_ids: Array<String>
  option_ids: Array<String>
  townsperson_ids: Array<String>
}
```

Approval metadata is documented in `dialogue-workshop.md`; runtime JSON contains only
the final event fields supported by DialogueSchema. CI/validation compares runtime beat
IDs/event IDs against the workshop approval record and rejects draft markers.

## Transient state

Transcript rows, reveal cursors, portraits, scene camera/UI state, and current modal
choice focus remain transient under the existing Dialogue contract. A reload restarts a
pending scene but does not erase committed flags or quest receipts.

## Normalized playtest projection

```text
first_land_quest: {
  phase: String
  activated: bool
  pending_event_ids: Array<String>
  selected_approach_id: String
  agreed: bool
  outcome_kind: String
  grant_id: String
  grant_applied: bool
  added_cell_count: int
  completed: bool
  diagnostic_codes: Array<String>
}
```

The projection contains no copy, portraits, voice notes, or workshop drafts and is safe
for deterministic hashing.
