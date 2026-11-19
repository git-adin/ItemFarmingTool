# ItemFarmingTool

- Target WoW Forever. Keep Lua and the TOC in `ItemFarmingTool/`. Use the private namespace for tracker logic and initialize per-character SavedVariables on the add-on's `ADDON_LOADED`.
- Keep integration behavior behind a documented public API. Preserve player slash-command behavior, existing goals, and saved bank data across updates.
- Run `python tests/test_addon.py`, `python tests/test_package.py`, and `python tools/package.py`. For a release candidate pass `--tag vX.Y.Z` with the TOC version. Record a Forever smoke test for changes to bank APIs or in-game export behavior.
