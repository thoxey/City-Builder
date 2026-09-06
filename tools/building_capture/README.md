## Building screenshot capture rig

Run the scene directly:

```sh
godot --path . --editor --quit
godot --path . --scene res://tools/building_capture/building_capture.tscn
```

The rig recursively reads every JSON definition under `res://data/buildings`
(excluding underscore-prefixed sidecar directories), applies the catalogue model
scale/rotation/offset, auto-frames the mesh, and writes two 1024×1024 PNGs per
entry plus `manifest.json` under `res://artifacts/building_screenshots`.
