# Third-party notices

This repository contains software and assets under different terms. The root
[MIT license](LICENSE.md) is not a blanket license for every model, image,
font, sound, generated asset, or vendored dependency.

This notice is an attribution and provenance index, not a replacement for the
license text shipped with each component. If this summary conflicts with an
upstream license, the upstream license controls.

## Kenney Starter Kit City Builder

This project is derived from
[Kenney's Starter Kit City Builder](https://github.com/KenneyNL/Starter-Kit-City-Builder).

- Upstream software: copyright Kenney and contributors, distributed under the
  MIT License. The inherited license is preserved in [LICENSE.md](LICENSE.md).
- Upstream asset bundle: Kenney's upstream README identifies the 2D sprites,
  3D models, and sound effects included with that starter kit as
  [CC0 1.0](https://creativecommons.org/publicdomain/zero/1.0/).

That CC0 statement applies only to assets traceable to the original Kenney
starter-kit distribution. It does not apply to assets added by this fork.

## GUT

`addons/gut/` vendors GUT 9.3.0, the Godot Unit Test framework by Tom
“Butch” Wesley. GUT is distributed under the MIT License; the retained license
text is [addons/gut/LICENSE.md](addons/gut/LICENSE.md).

The GUT directory is development/test tooling. Do not remove its license when
redistributing the vendored addon.

## Fonts

### Lilita One

`fonts/lilita_one_regular.ttf` is Lilita One by Juan Montoreano, with
“Lilita” as a Reserved Font Name. It is distributed under the SIL Open Font
License 1.1. The copyright and full license text are retained in
[fonts/license.txt](fonts/license.txt).

### Anonymous Pro

`addons/gut/fonts/AnonymousPro-*.ttf` is Anonymous Pro by Mark Simonson, with
“Anonymous Pro” as a Reserved Font Name. It is distributed under the SIL Open
Font License 1.1. The copyright and full license text are retained in
[addons/gut/fonts/OFL.txt](addons/gut/fonts/OFL.txt).

The vendored GUT tree also contains Courier Prime and Lobster Two font files,
but this repository does not currently retain separate font-specific notices
for those families. Treat them as GUT development assets and verify/add their
upstream notices before repackaging them independently or including the test
addon in an external distribution.

## Low Poly City Vehicles Pack

The runtime vehicles in `models/city-vehicles/` are derived from
**Low Poly City Vehicles Pack** by **Pavel 3D**:

- Source:
  [pavel-3d.itch.io/low-poly-city-vehicles-pack](https://pavel-3d.itch.io/low-poly-city-vehicles-pack)
- License:
  [Creative Commons Attribution 4.0 International](https://creativecommons.org/licenses/by/4.0/)
- Attribution: “Low Poly City Vehicles Pack” © Pavel 3D, used under CC BY 4.0.
- Changes made by this project: selected one colour variant for each of 31 body
  styles; flattened the selected FBX files into one runtime directory; retained
  one shared palette texture; and excluded the original source archive from the
  repository.

See [models/city-vehicles/README.md](models/city-vehicles/README.md) for the
runtime packaging details. CC BY 4.0 requires attribution, a link to the
license, and an indication that changes were made; preserve this section in
redistributions containing those vehicles.

## Meshy and project-generated art

The repository includes AI-assisted or project-generated material, including
files under `models/Meshy_AI_*/`, packaged runtime models under
`models/city-builder/`, and generated or derived UI/portrait work under
`art/`, `sprites/`, and `data/characters/`.

No single open-content license is asserted for that material. Its
redistribution basis depends on the underlying source inputs, the applicable
service terms at the time of generation, and the project owner's rights and
records. In particular:

- do not assume these files are CC0 because some original Kenney assets are;
- do not assume the repository's MIT software license grants independent asset
  reuse rights;
- preserve the nearby manifests, READMEs, source references, and modification
  notes; and
- before an external release, confirm that the project records identify the
  source, generation account/terms, human modifications, and redistribution
  authority for each shipped asset family.

This cautious classification is intentional. Add a specific notice when an
asset family's provenance and license are verified; do not replace missing
provenance with a blanket license claim.

## Maintainer checklist

When adding third-party or generated material:

1. Record the asset title, creator, source URL, version or retrieval date, and
   destination paths.
2. Retain the complete license file when required.
3. State material modifications, including format conversion, cropping,
   recolouring, remeshing, or derivative generation.
4. Confirm that the committed runtime files—not only an ignored source
   archive—can be tied back to that record.
5. Update this notice before merging the material to `main`.
