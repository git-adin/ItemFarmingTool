# ItemFarmingTool

A lightweight item farming tracker for **World of Warcraft: Forever**. Pick items,
set a goal for each, and watch your current bag totals update in a small movable box.
No libraries or other addons are required.

**[Download ItemFarmingTool.zip](https://github.com/git-adin/ItemFarmingTool/releases/latest/download/ItemFarmingTool.zip)**
· [All releases](https://github.com/git-adin/ItemFarmingTool/releases)

## Install

1. Close WoW and download **ItemFarmingTool.zip** from Releases.
2. Extract it into `_forever_/Interface/AddOns/`.
   The resulting path must be `AddOns/ItemFarmingTool/ItemFarmingTool.toc`.
3. Enable **ItemFarmingTool** in the character selection AddOns list.
4. Log in and type `/ift` to show the tracker.

Use the release ZIP; GitHub's **Code > Download ZIP** includes extra development
folders. To update, replace the installed `ItemFarmingTool` folder. Your character's
saved goals and position live separately in `WTF` and are preserved.

## Use

- Click **Add**, enter an item ID, item link, or cached exact item name, set a
  positive whole-number goal, and click **Save goal**. Use an ID or link if the
  client does not yet know an item's name.
- You can drop an item onto the tracker or item input to select it. With the item
  input focused, Shift-clicking an item link also fills the field.
- Each item shows an icon, name, **current / goal**, progress bar, and the amount
  still needed. Goals turn green when reached and remain visible.
- Click an item row to edit its goal; click its **x** to remove it. Adding an item
  already on the list updates its goal instead of creating a duplicate.
- Drag the background/title to move the box. **Lock** prevents dragging; **Unlock**
  restores it. **- / +** collapses or expands the box. The header **x** hides it.
- Scroll the list with the mouse wheel for more than eight items. Up to 100 items
  can be tracked, with goals from 1 to 999999.

Counts are **current carried bag contents**, including a reagent bag when the
client supports one. Equipment, bank slots, reagent bank, mail and auctions do not
count. Looting increases progress; selling, consuming, crafting with, mailing or
banking an item decreases it. This tracks what you have, rather than a session's
cumulative loot. Goals, visibility, collapse state, lock state and position are
saved per character.

| Command | Action |
| --- | --- |
| `/ift` or `/ift show` | Show tracker |
| `/ift hide` | Hide tracker |
| `/ift add 2589 200` | Track 200 Linen Cloth, or update its goal |
| `/ift add Linen Cloth 200` | Use a cached exact item name |
| `/ift remove 2589` | Remove item by ID, link or cached name |
| `/ift lock` / `/ift unlock` | Prevent / allow moving |
| `/ift reset` | Restore default position and show the tracker |
| `/ift help` | Show command help |

`/itemfarmingtool` is an alias for `/ift`.

## Compatibility and validation

Targets Forever's **Interface 16001**, matching QuestLite. Uses the client's
`C_Container` bag API, with legacy global container functions as a fallback, and
refreshes on bag and item-data events. Inventory event bursts are batched; there
is no per-frame polling, item database, network call or bundled dependency.

Offline tests execute the actual addon in Lua 5.1 with an inventory/UI harness.
They cover bag-only totals, inventory changes, async item names, commands, input
validation, saved settings, progress, editing, item selection, scrolling and
moving. They do not replace testing the appearance and interactions in Forever.

Before promoting a build, check in game: add two items (one not currently owned),
loot/sell/bank a stack, change a goal, reach it, remove an item, scroll more than
eight items, drag/drop and Shift-click an item, lock/move/collapse/hide the box,
then `/reload` and confirm settings persist. Use `/ift reset` to recover its position.

## Development and release

Python 3 is needed only for development:

```powershell
python -m pip install --target .tools -r tests/requirements.txt
python tests/test_addon.py
python tests/test_package.py
python tools/package.py --tag v0.1.0
```

The output contains only the installable addon folder. `dist/` and test dependencies
are excluded from Git. Runtime API signatures are checked against the
[Blizzard UI source mirror](https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_APIDocumentationGenerated/ContainerDocumentation.lua)
and the installed Forever addons.

Follow the same release process as QuestLite: update `## Version:` in
`ItemFarmingTool/ItemFarmingTool.toc`, the addon README heading, and
`.github/RELEASE_NOTES.md`. Commit and push, then tag that commit:

```powershell
git tag v0.1.0
git push origin v0.1.0
```

For later releases, substitute the new version. The workflow runs both test suites,
checks that the tag matches the TOC, builds `ItemFarmingTool-<version>.zip`,
`ItemFarmingTool.zip` and `SHA256SUMS.txt`, then creates a draft release, uploads
all assets, and publishes it. The download link above always targets the latest
published release. GPL-3.0-or-later; see [LICENSE](LICENSE).
