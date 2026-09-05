# Clean shell acceptance

The old Palette list, HUD plugin, scene Top/Instructions/DevCommands controls,
QuestDebug surface, and default RoadDebug overlay are absent. PlayerUI owns one
full-width parchment status bar and one bottom dock. Insights, Inbox, Dialogue,
notifications, and DayNight remain reachable. The dock and radial reserve 380 px
while Insights is expanded, and the drawer begins below the status bar.

Reviewed screenshots: `01-clean-idle.png`, `08-community-drawer.png`,
`09-confirmation-modal.png`, and `11-wide-layout.png`. Debug/release activation
is also covered by `test_plugin_activation.gd`.
