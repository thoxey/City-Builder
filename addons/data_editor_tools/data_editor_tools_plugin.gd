@tool
extends EditorPlugin

## Data Editor Tools — editor-time helpers for the external data_editor SPA.
##
## Adds a **Project → Tools → Export Data Editor Manifest** menu item. Running
## it walks res://data/{characters,patrons,buildings,events} and writes a
## flattened summary to res://data/events/_manifest.json that the SPA consumes
## to populate dropdowns, validate references, and detect stale content.
##
## All scanning / writing lives in manifest_exporter.gd so the same logic can
## be driven from a headless SceneTree without instantiating an EditorPlugin.

const MENU_LABEL := "Export Data Editor Manifest"
const Exporter := preload("res://addons/data_editor_tools/manifest_exporter.gd")


func _enter_tree() -> void:
	add_tool_menu_item(MENU_LABEL, Callable(self, "_export_manifest"))

func _exit_tree() -> void:
	remove_tool_menu_item(MENU_LABEL)


func _export_manifest() -> void:
	var exporter := Exporter.new()
	var manifest := exporter.build_manifest()
	var err := exporter.write_manifest(manifest)
	if err == OK:
		var msg := "Wrote %s\n%d chars · %d patrons · %d buildings · %d events · %d flags" % [
			Exporter.MANIFEST_PATH,
			manifest["characters"].size(),
			manifest["patrons"].size(),
			manifest["buildings"].size(),
			manifest["events"].size(),
			manifest["flags"].size(),
		]
		print("[DataEditorTools] %s" % msg.replace("\n", " "))
		var fs := EditorInterface.get_resource_filesystem()
		if fs != null: fs.scan()
		_show_info("Manifest exported", msg)
	else:
		var emsg := "Failed to write %s (err=%d)" % [Exporter.MANIFEST_PATH, err]
		push_error(emsg)
		_show_info("Manifest export failed", emsg)


func _show_info(title: String, msg: String) -> void:
	var dlg := AcceptDialog.new()
	dlg.title = title
	dlg.dialog_text = msg
	EditorInterface.get_base_control().add_child(dlg)
	dlg.popup_centered()
	dlg.confirmed.connect(func(): dlg.queue_free())
	dlg.canceled.connect(func(): dlg.queue_free())
