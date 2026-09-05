# US1 placement acceptance

The PlayerUI integration suite verifies that an accepted entry calls Palette
once, closes the wheel once, starts Builder placement once, and updates the
dock. A rejected entry leaves the wheel open and never starts placement. The
live scenario applied residential, industrial, and commercial pool placements,
then advanced 48 hours; all four commands returned `applied` at sequence 4.
Builder retains its established rotation, pool variant, road-paint, repeat,
replacement confirmation, and cancellation command bodies.
