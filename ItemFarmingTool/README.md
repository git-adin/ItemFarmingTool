# ItemFarmingTool 0.1.0

A compact, dependency-free item farming tracker for WoW Forever (Interface 16001).

Type `/ift`, click **Add**, choose an item by ID, link, cached exact name or dragging
it from a bag, and set a goal. Each row shows current bag count, goal and progress.
Click a row to edit its goal or **x** to remove it. Focus the item field and
Shift-click an item link to select it. Duplicate items update the existing goal.

Drag the title/background to move; **Lock** prevents movement. **- / +** collapses
or expands the box. The header **x** hides it; `/ift` shows it again. Scroll for
more than eight items. `/ift reset` restores the default position. Goals, position,
visibility and lock/collapse settings persist per character.

Only carried bags count. Equipment, bank, mail and auctions do not. Selling,
consuming or banking items reduces progress. Reached goals remain visible and
turn green. Up to 100 items can be tracked with goals from 1 to 999999.

Commands: `/ift add <ID, link or cached exact name> <goal>`, `/ift remove <item>`,
`/ift show`, `/ift hide`, `/ift lock`, `/ift unlock`, `/ift reset`, `/ift help`.

Install this folder under `_forever_/Interface/AddOns/ItemFarmingTool/` with the
TOC directly inside. Enable it in the AddOns list. No dependencies are required.
Offline regression-tested; the live Forever appearance and interactions still
need an in-game check.

[Source, releases and full instructions](https://github.com/git-adin/ItemFarmingTool).
GPL-3.0-or-later; see LICENSE.
