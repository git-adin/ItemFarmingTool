## ItemFarmingTool 0.2.4

Fix tracker overlap with other addon windows, including ProfessionGuide.

- Keep the tracker background and controls together above ordinary addon panels.
- Use a fully opaque background so underlying text cannot show through.
- Bring the tracker forward when reopened and support native click-to-front behavior.
- Keep dialogs and tooltips above the tracker.

Use `/reload` after updating. Goals, saved bank counts and window settings are preserved.

Validation: offline Lua UI behavior tests and installable-package checks passed.
Forever visual smoke test pending: open ProfessionGuide and the profession panel,
overlap the tracker with both, click its rows and controls, hide/show it, collapse
and expand it, and verify that windows no longer draw through the tracker.
