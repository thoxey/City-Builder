@tool
extends SceneTree

## Headless driver — runs the manifest exporter without opening the editor UI.
## Usage: Godot --headless -s res://addons/data_editor_tools/export_manifest_headless.gd

const Exporter := preload("res://addons/data_editor_tools/manifest_exporter.gd")

func _init() -> void:
	var exporter := Exporter.new()
	var manifest: Dictionary = exporter.build_manifest()
	var err := exporter.write_manifest(manifest)
	if err != OK:
		push_error("headless export failed: %d" % err)
		quit(1); return
	print("[DataEditorTools] headless export OK: chars=%d patrons=%d buildings=%d events=%d flags=%d" % [
		manifest["characters"].size(),
		manifest["patrons"].size(),
		manifest["buildings"].size(),
		manifest["events"].size(),
		manifest["flags"].size(),
	])
	quit()
