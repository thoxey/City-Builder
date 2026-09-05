# Release/debug activation

`PluginManager.should_activate_plugin()` is the explicit policy seam.
QuestDebug is always rejected; RoadDebug requires both a debug build and the
`development/road_debug_enabled` opt-in; Playtest is rejected in release;
PlayerUI is ordinary runtime UI. QuestDebug and RoadDebug also guard themselves
if instantiated manually. The two release/debug activation tests pass.

This repository has no `export_presets.cfg`, so no distributable release binary
was produced or inspected. The release decision itself is deterministic and
covered without changing project-wide export configuration.
