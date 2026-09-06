# Dialogue Authoring Baseline

Captured 2026-09-06 before feature 011 authoring/export changes.

## Runtime event record

Dialogue JSON currently uses the common event envelope fields `event_id`,
`event_type`, `trigger`, `enabled_if`, and `payload`. A dialogue payload contains
`tree_id`, `entry_node_id`, and `nodes`. Existing nodes contain `node_id`, `speaker`,
`body`, `on_enter`, and `options`; options contain `label`, `next`, and `effects`.

There is no existing `participants` collection or ordered `beats` collection. The
production residential arrival is a two-node body-only graph. Its two reply labels are
`Continue` and `Close`, and its final option sets
`met_aristocrat_residential`.

## Runtime character record

Character JSON currently carries `character_id`, `character_type`, `display_name`,
`bio`, `patron_id`, `associated_bucket`, `arrival_threshold`,
`arrival_requires_tier`, `want_building_id`, `portrait`, and `talking_videos`.

There is no `default_expression` or semantic `expressions` map. Ambrose, Baba Soyink
(`aristocrat_residential`), and Flick (`aristocrat_commercial`) each declare one
512x512 portrait plus four talking-video paths.

## Generated manifest projection

`addons/data_editor_tools/manifest_exporter.gd` currently projects each event as:

- `event_id`, `event_type`, `trigger_event`, `trigger_character_id`,
  `trigger_patron_id`, `trigger_building_id`, `enabled_if`, `category`, `_path`, and
  the complete source record under `body`.

It currently projects each character as:

- `character_id`, `character_type`, `display_name`, `bio`, `patron_id`,
  `associated_bucket`, `arrival_threshold`, `arrival_requires_tier`,
  `want_building_id`, `portrait`, `talking_videos`, and `_path`.

The full event body already preserves unknown/new source fields during export, but the
top-level character projection does not yet expose expression metadata.
