# Building asset audit and catalogue gaps

## Executive finding

The catalogue exposes 21 named building entries but only 14 distinct models. Seven catalogue entries therefore have no model of their own. Five duplicate-geometry groups account for 12 entries, so apparent use coverage is much broader than actual asset coverage. The strongest existing references are the Town Hall, Pub, Cottage Residence D and Small Residence A. They demonstrate useful façade rhythm, roofscape and British material cues, but all need some simplification for image-to-mesh work.

Use and typology remain separate classification concepts, but geometry is not reusable between catalogue entries. Every named asset requires its own model, geometry signature and model path. A pub, restaurant and shop may share a high-street typological grammar, but each must express that grammar through distinct massing, proportions, openings or frontage geometry rather than a retexture of one mesh.

## Status summary

| Status | Count | Meaning |
|---|---:|---|
| keep | 0 | No current asset is production-ready under the new code. |
| minor_rework | 7 | Duck Pond, Garage, Nature Patch, Pub, Small Residence A, Cottage Residence D and Town Hall. |
| major_rework | 4 | Postwar Mid-Block, Postwar Terrace, Small Commercial B and Tower Residence C. |
| replace | 3 | Nightclub, Postwar Tower Block and Windmill have distinct models, but those models are unsuitable. |
| missing | 7 | Crazy Golf, Lumber Mill, Pipe Factory, Members' Club, Pirate Radio, Restaurant and Theatre share another entry's geometry and therefore lack their own model. |

The CSV is authoritative if this prose count becomes stale.

## Duplicate-geometry groups

| Shared geometry | Catalogue entries | Model ownership and missing assets |
|---|---|---|
| `duck_pond_shell` | Crazy Golf, Duck Pond | Duck Pond owns the current model; Crazy Golf is missing a model. |
| `acme_business_park_shell` | Garage, Lumber Mill, Pipe Factory | Garage owns the current model; Lumber Mill and Pipe Factory are each missing a model. |
| `clocktower_city_hall_shell` | Members' Club, Theatre, Town Hall | Town Hall owns the current model; Members' Club and Theatre are each missing a model. |
| `green_dragon_pub_shell` | Pub, Restaurant | Pub owns the current model; Restaurant is missing a model. |
| `tower_of_tomorrow_shell` | Pirate Radio, Tower Residence C | Tower Residence C owns the current model; Pirate Radio is missing a model. |

## Preferred references

1. **Cottage Residence D** — the clearest seed for Georgian/formal South West residential: limestone or pale render, calm three-bay frontage, slate roof and restrained detail.
2. **Pub** — the clearest seed for a Victorian high-street shell: brown brick, vertical windows, chimneys, strong ground-floor identity and a compact urban section.
3. **Town Hall** — the clearest seed for landmark hierarchy, symmetry and a roofline that signals civic importance.
4. **Small Residence A** — a useful modest domestic mass for suburb variants, after removing Tudor-like cues and reducing garden clutter.
5. **Garage** — a useful background industrial shell, especially the brick plinth plus corrugated upper expression.

These are references for design logic, not assets to copy unchanged.

## Catalogue gaps by urgency

### Priority 0: coherent street-forming background stock

- Victorian industrial terraces: 2-3 storey attached houses, end terraces and one corner/shop conversion.
- Georgian/formal terraces and townhouses: 3-storey, calm repeated bays, direct-to-pavement and railings/lightwell variants.
- High-street mixed-use shells: shops, cafés, offices and flats sharing 2-3 storey narrow shells.
- Victorian suburb: semi-detached pairs, detached villas and short terraces with shallow front gardens.
- Postwar estate housing: credible short terraces, walk-up blocks, slab blocks and point blocks.

### Priority 1: everyday facilities needed for a functioning city

- Education: primary school, board school, secondary school/college.
- Healthcare: GP surgery, clinic, community hospital.
- Community/religious: church/chapel, community hall, library, fire/police station.
- Transport: railway station, bus depot, small goods shed.
- Workplaces: workshop row, warehouse, sawtooth factory, dock/rail warehouse and office conversion.
- Residential breadth: cottage, bungalow, mansion block, sheltered housing, modern apartment block and warehouse conversion.

### Priority 2: destinations and landmarks

- Theatre/cinema, market hall, baths/leisure centre, hotel, museum, church tower, industrial chimney/water tower and a distinct members' club.
- Park structures and leisure: pavilion, bandstand, boathouse and actual crazy-golf course.

## Neighbourhood clusters for current assets

- `historic_core`: Town Hall; Theatre only as a placeholder.
- `georgian_formal`: Cottage Residence D; Members' Club only as a placeholder.
- `victorian_industrial`: no convincing residential stock; Pipe Factory placeholder.
- `victorian_suburb`: Small Residence A.
- `postwar_estate`: three named entries, none yet convincing enough to keep without major work.
- `high_street`: Pub is the strongest; Restaurant and Small Commercial B need a new shell/expression split; Nightclub is out of language.
- `industrial_edge`: Garage is viable; Lumber Mill and Pipe Factory need distinct masses.
- `contemporary_regeneration`: Tower Residence C is a possible accent after simplification.
- `village_edge`: Cottage Residence D and landscape props; Windmill is missing in practice.

## Shape-language adjustments learned from the audit

- Add `model_id`, `model_path` and `geometry_signature`; these must be unique for every catalogue entry.
- Keep `occupancy_expression` separate from typology, but never satisfy a new entry by retexturing or relabelling existing geometry.
- Add `street_role` (`mid_terrace`, `end_terrace`, `corner`, `detached_in_plot`, `standalone_destination`) because current isolated models do not reliably compose into streets.
- Add `occlusion_budget` and `thin_detail_budget` for mesh-generation safety.
- Add `component_separation` to require readable roof, chimney, wall, shopfront and rear-projection masses.
- Add `signage_policy` because current fixed text creates semantic collisions.
- Add `family_invariants` and `variant_axes` so variation happens within a stable camera, palette, scale and grammar.

## Source basis

The code follows the National Design Guide's distinction between broad guidance and locally specific design requirements. In particular it operationalises the guide's emphasis on context, local building types, roofscape, façade proportions, building line, active frontage, mixed and adaptable uses, ground/sky relationships, materials and integrated utility details. The official source is the [National Design Guide](https://www.gov.uk/government/publications/national-design-guide).
