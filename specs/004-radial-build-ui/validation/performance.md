# Performance

Measured on Apple M2 Max with Godot 4.6.2 using
`scripts/profile_radial_ui.gd`: cold open 14.101 ms; mean warm open/close 0.504
ms; mean navigation 0.002 ms; mean model refresh 0.490 ms; node delta after 100
opens was 0. Catalog loading appears once at boot and no open performs a disk
scan. The existing 500-resident Community projection benchmark also passes at
15.787 ms against its 16.7 ms frame budget.
