# South West England building design code

## Purpose

This is a procedural design code for a fictional city influenced by South West England. It does not define one British style. Every asset resolves in this order:

`place -> building typology -> building expression -> render contract`

The code favours variation within coherence: neighbourhoods differ in grain and material balance; streets vary in height and roof rhythm; buildings vary by bays, entrances and roof features; occupant details vary without changing the shell grammar.

## Universal invariants

- The asset must read first as a plausible building type, then as an era/expression.
- Use and typology are separate classification axes, but every catalogue asset requires unique geometry. Shared geometry always means the later entry is missing a model.
- Background buildings form the majority and remain restrained; accents receive one exceptional feature; landmarks may receive a tower, cupola, special entrance or larger scale.
- A façade has a declared rhythm, vertical organisation and ground condition.
- A roof has a family, street orientation and skyline condition.
- Materials follow massing and construction logic; they are not decorative stickers.
- British utility detail is present but consolidated into readable masses.
- Mesh safety outranks picturesque clutter.

## Core schema

### Identity and context

- `region`: normally `south_west_england_fictional_city`.
- `neighbourhood_family`: `historic_core`, `georgian_formal`, `victorian_industrial`, `victorian_suburb`, `interwar_suburb`, `postwar_estate`, `high_street`, `industrial_edge`, `contemporary_regeneration`, `village_edge`.
- `density`: `low`, `medium`, `high`.
- `street_type`: `lane`, `residential_street`, `urban_street`, `high_street`, `square`, `industrial_yard`, `estate_access`.
- `era_character`: architectural expression, distinct from typology.
- `prominence`: `background`, `accent`, `landmark`.
- `street_role`: `mid_terrace`, `end_terrace`, `corner`, `detached_in_plot`, `pavilion_in_plot`, `standalone_destination`.

### Use and shell

- `use`: `residential`, `retail`, `mixed_use`, `civic`, `industrial`, `education`, `healthcare`, `leisure`, `hospitality`, `office`, `religious`, `transport`, `infrastructure`, `community`, `media`.
- `typology`: the physical shell, such as `terrace`, `townhouse`, `semi_detached`, `detached_villa`, `mansion_block`, `walkup_block`, `slab_block`, `point_block`, `shop_and_upper`, `public_house`, `civic_hall`, `warehouse`, `factory_hall`.
- `occupancy_expression`: the current tenant/use treatment, e.g. `cafe_plus_flats`, `public_house`, `estate_agent_plus_office`, `vacant_shop_plus_flats`.
- `model_id`: unique model identity for this catalogue asset.
- `geometry_signature`: auditable description or hash of the asset's massing and geometry; it must not match another catalogue entry.
- `geometry_reuse_allowed`: always `false` for catalogue assets.

### Geometry

- `footprint`, `attachment`, `storeys`, `bay_count`, `massing`, `setback`, `building_line`, `symmetry`.
- `roof_family`, `roof_orientation`, `roof_articulation`, `sky_condition`.
- `facade_rhythm`, `vertical_organisation`, `opening_character`, `opening_density`, `alignment`.
- `ground_condition` and `boundary_treatment`.

### Expression

- `primary_material`, `secondary_material`, `roof_material`.
- `window_family`, `door_family`, `decoration_level`, `detail_density`, `weathering`.
- `clutter_level`, `signage_policy`, `occlusion_budget`, `thin_detail_budget`, `component_separation`.

## Regional grammar

### Shared palette

- Warm red and brown brick for industrial, Victorian urban and many suburban shells.
- Limestone or pale stone for formal buildings and selected terraces; sandstone and occasional granite as local accents.
- Painted or white render for coastal, village and later suburban expressions.
- Dark grey slate as the default pitched-roof material; clay tile where typology and era justify it.
- Stone lintels/sills, restrained polychrome brick and timber shopfronts as controlled secondary elements.

Avoid making local identity synonymous with stone cottages. Avoid Tudor appliqué, fantasy medievalism, American suburban setbacks and continental shopfront proportions.

### Neighbourhood families

#### `victorian_industrial`

- Medium/high density, narrow attached plots, direct-to-pavement or tiny thresholds.
- Two or three storeys; two or three bays; tall narrow openings.
- Red/brown brick with stone lintels; slate ridge normally parallel to street.
- Repeated chimneys provide street rhythm; decoration low/moderate.
- Factories use long spans, sawtooth or gabled sheds, brick bases and readable loading openings.

#### `georgian_formal`

- Medium/high density, consistent building line and calm repeated façades.
- Three storeys typical; two to four bays; strong symmetry or disciplined terrace rhythm.
- Limestone, pale render or warm brick; slate roof often behind parapet or with restrained dormers.
- Tall sash openings, decreasing floor height, restrained door surrounds.
- Railings/lightwell or direct pavement; clutter very low.

#### `high_street`

- Continuous frontage; two or three storeys; narrow repeated shopfront modules.
- Expressed ground floor with separate upper-floor access.
- Shell supports multiple uses; signage stays subordinate and preferably blank/generic during mesh generation.
- Corners may be accents; most units remain background.

#### `victorian_suburb`

- Low/medium density; semis, detached villas and short terraces.
- Shallow front gardens, low walls/hedges; two storeys.
- Brick, stone or render; slate or compatible clay tile; gables and bays used sparingly.
- More silhouette variation than the industrial terrace but a calmer street rhythm than isolated storybook cottages.

#### `postwar_estate`

- Short terraces, walk-ups, slabs and point blocks share a restrained material palette.
- Flat or shallow-pitch roofs, repeated openings and clear communal entrances.
- Towers are accents/landmarks; ordinary terraces and walk-ups are background.
- Balconies are chunky readable recesses or slabs, not dense rail forests.

#### `industrial_edge`

- Large simple masses, long spans and clear service sides.
- Brick, corrugated metal and concrete; sawtooth, gable or low mono-pitch roofs.
- Loading bays and stacks are few, oversized enough to read, and separated from the main mass.

## Compatibility rules

### Hard failures unless explicitly overridden

- `terrace` with `detached_in_plot`, `pavilion_in_plot` or a large suburban setback.
- `mansion_block`, `slab_block` or `point_block` below three storeys.
- `high_street` retail/mixed use with a blank ground floor or no independent upper access.
- `landmark` treatment on a routine background request.
- `georgian_formal` with chaotic openings, unaligned bays or dominant asymmetry.
- Pitched slate roof combined with parapet-only sky condition unless the roof is explicitly concealed.
- `victorian_industrial` residential with curtain wall, garage-dominated frontage or American porch proportions.
- A `model_id`, `model_path` or `geometry_signature` already assigned to another catalogue entry.

### Soft corrections

- Suppress towers/cupolas for `background` prominence.
- Reduce decoration and skyline features as prominence decreases.
- Prefer direct-to-pavement in high-density urban families; prefer shallow front gardens in suburbs.
- Increase ground-floor opening scale for retail/hospitality but keep upper openings domestic.
- Consolidate gutters, vents and pipework when detail exceeds the mesh budget.

## Render contract

- Sunny, clear South West England daylight with soft readable shadows and one consistent shadow direction.
- Orthographic or near-orthographic 3/4 elevated isometric view; show front and one side.
- Entire building and roof visible, centred, with margin around silhouette.
- Plain warm-neutral or transparent background; one minimal base slab only if needed.
- No people, vehicles, legible brand text, street furniture, trees or foreground occlusion.
- No depth of field, dramatic perspective, cinematic atmosphere or cropped massing.
- Strong component separation: wall, roof, chimneys, projections, doors and recessed windows must remain visually distinct.
- Limit thin railings, wires, antennae, ivy, tiny pipes and overlapping awnings.
- Family sheets use a consistent camera, sun, scale, palette, stylisation and base treatment.

## Family generation contract

Generate 6-10 variants as one coherent design exercise. Declare:

- `family_invariants`: context, camera, sun, scale band, material palette, stylisation, mesh budgets.
- `variant_axes`: only the controlled dimensions that may vary.
- `variant_manifest`: every resolved variant before image generation.

Every variant is a separate model candidate with unique geometry and a unique model identifier. Typological coherence may repeat proportions and rules, but not the exact mesh.

Variation comes from architecture, not rendering drift. A useful eight-variant family usually contains five background buildings, two accents and one edge/corner condition; landmarks are generated separately unless the family itself is civic.
