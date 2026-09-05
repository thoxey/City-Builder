# Design code reference

## Resolution schema

Resolve at least these fields:

```yaml
mode:
seed:
region:
neighbourhood_family:
density:
street_type:
era_character:
prominence:
use:
typology:
occupancy_expression:
model_id:
geometry_signature:
geometry_reuse_allowed: false
street_role:
attachment:
storeys:
bay_count:
massing:
setback:
building_line:
roof_family:
roof_orientation:
roof_articulation:
facade_rhythm:
vertical_organisation:
opening_character:
opening_density:
alignment:
symmetry:
ground_condition:
sky_condition:
primary_material:
secondary_material:
roof_material:
window_family:
door_family:
decoration_level:
detail_density:
weathering:
clutter_level:
boundary_treatment:
signage_policy:
occlusion_budget:
thin_detail_budget:
component_separation:
```

## South West defaults

- Region: fictional city influenced by South West England.
- Palette: red/brown brick, limestone, sandstone, occasional granite, painted/rendered façades, slate roofs and justified clay tile.
- Detail: stone or brick lintels, restrained Victorian/Georgian detail, believable consolidated gutters/downpipes/vents.
- Influences: urban Bristol/Bath/Exeter/Plymouth/Gloucester/Cheltenham, Somerset and Cornish towns, port/rail/manufacturing history. Do not reproduce a named place.
- Avoid: generic storybook Britain, excessive Tudor cues, fantasy, American suburban proportions, continental shopfronts and random period mixing.

## Neighbourhood presets

### `victorian_industrial`

- Medium/high density, residential or industrial street.
- Terrace residential default: 2 storeys, 2 bays, red/brown brick, slate gable roof, ridge parallel, paired chimneys, tall narrow windows, direct to pavement, restrained detail.
- Weighted variants: 2/3 storeys; 2/3 bays; brick/local stone/painted render; plain/modest bay; paired/individual chimneys.

### `georgian_formal`

- Medium/high density, consistent building line.
- Townhouse/terrace default: 3 storeys, 2-3 bays, disciplined symmetry, tall sash openings with decreasing floor height, limestone/pale render/warm brick, slate roof or concealed roof, direct pavement or railings/lightwell.

### `high_street`

- Continuous frontage; 2-3 storeys; narrow shopfront module; separate upper-floor entrance.
- Expressed ground floor, domestic upper openings, blank or generic signage for mesh inputs.
- Café, shop, office, pub, restaurant, vacant unit and flats may share this typological grammar, but every catalogue entry must have distinct geometry and its own model path.

### `victorian_suburb`

- Low/medium density; two-storey semi, detached villa or short terrace.
- Shallow front garden, low wall/hedge, brick/stone/render, slate or restrained clay tile.
- Gable, cross-gable or modest bay window may create accent variants.

### `postwar_estate`

- Short terraces, walk-ups, slabs and point blocks; restrained concrete/brick/render palette.
- Flat or shallow roofs; repeated windows; clear communal entrances; chunky simple balconies.

### `industrial_edge`

- Long-span simple masses; warehouse/factory/workshop shells.
- Brick, corrugated metal and concrete; sawtooth/gable/mono-pitch roof; few large loading bays and stacks.

## Validation

Hard conflicts unless explicitly overridden:

- Terrace shell with detached/pavilion plot logic or large setback.
- Mansion, slab or point block below 3 storeys.
- High-street retail/mixed use with blank ground floor or no separate upper access.
- Background prominence with a civic tower/cupola or landmark scale.
- Georgian formal expression with chaotic or unaligned openings.
- Victorian industrial residential with curtain wall, garage-dominated frontage or American porch proportions.
- Any model ID, model path or geometry signature already used by another catalogue entry.

## Model uniqueness

- One catalogue entry equals one unique model.
- A texture, sign or colour change does not create a new model.
- Family resemblance comes from shared rules, not shared meshes.
- In audits, preserve the model for the entry that best matches it; classify every other entry using that geometry as `missing`.
- In generation, assign every variant a unique `model_id` and require visible geometric differentiation in massing, bays, openings, roof articulation, frontage or corner/end condition.

Soft corrections:

- Suppress towers and cupolas for background buildings.
- Direct-to-pavement for dense urban families; shallow gardens for suburbs.
- Retail/hospitality has larger ground openings and domestic upper openings.
- Consolidate utility detail when it exceeds mesh budgets.

## Prominence

- `background`: simple silhouette, restrained decoration, strict grammar.
- `accent`: one unusual architectural feature.
- `landmark`: stronger scale/silhouette and intentional rule-breaking; reserve for civic/destination roles.

## Render contract

- Sunny clear daylight; soft readable shadows; fixed direction.
- Orthographic/near-orthographic front 3/4 elevated isometric; minimal perspective.
- Entire building and roof visible with clear margin.
- Plain warm-neutral background; optional minimal base slab.
- No people, vehicles, readable brand text, clutter, foreground vegetation or occlusion.
- No depth of field, cinematic lighting or dramatic perspective.
- Clearly recessed windows and doors; readable roof and chimney masses.
- Low occlusion and thin-detail budgets; strong separation of components.
