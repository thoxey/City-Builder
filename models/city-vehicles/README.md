# Runtime vehicle subset

These files are the runtime subset of `[Low Poly] City Vehicles Pack v1.2.rar`.
It contains one mixed-colour FBX for each of the 31 distinct body styles in the
Coupes, Minivan, Muscle cars, Pickup, Retro Cars, Sedans, Sports cars, SUVs,
Trucks, and Vans folders.

The FBXs are flattened into this directory so every model resolves the one
shared `city_vehicles_pallete.png`. Keeping one colour per body style avoids
loading 152 geometry duplicates while retaining all regular-vehicle shapes.

`CarManager` merges each FBX's body and wheel child meshes once at pool setup.
The variants then partition the existing 256 logical car slots; they do not
create a 256-instance pool per model.

## Attribution and license

The original **Low Poly City Vehicles Pack** is by **Pavel 3D** and is licensed
under [Creative Commons Attribution 4.0 International](https://creativecommons.org/licenses/by/4.0/).
The source pack is available from
[pavel-3d.itch.io](https://pavel-3d.itch.io/low-poly-city-vehicles-pack).

This repository selects one colour variant for each included body style and
places those files in a flat runtime directory. The original source archive is
not redistributed in the repository.
