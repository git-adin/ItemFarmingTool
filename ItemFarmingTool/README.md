# ItemFarmingTool 0.2.1

A compact, dependency-free item farming tracker for WoW Forever (Interface 16001).

Type `/ift`, click **Add**, choose an item by ID, link, cached exact name or dragging
it from a bag, and set a goal. Each row shows combined bags + bank, a storage breakdown, goal and progress.
Click a row to edit its goal or **x** to remove it. Focus the item field and
Shift-click an item link to select it. Duplicate items update the existing goal.

Drag the title/background to move; **Lock** prevents movement. **- / +** collapses
or expands the box. The header **x** hides it; `/ift` shows it again. Scroll for
more than eight items. `/ift reset` restores the default position. Goals, position,
visibility and lock/collapse settings persist per character.

Click the footer **Bags + bank / Bags only** button to choose what counts toward
goals. The choice is saved per character. Bags only uses current carried bags,
without bank amounts or unknown-bank indicators. Bank snapshots still refresh
during visits so switching back uses the latest check.

In Bags + bank mode, bags and your last checked personal bank count toward goals. Open the bank to
scan tracked items. Deposits and withdrawals update while it is open; the last
counts are saved across bank closing, reloads and logouts. The footer shows the
last check time. Reagent storage is included when supported; equipment, guild and
account banks, mail and auctions are excluded.

**Bank ? (visit bank)** and a **+** on the total mean that item's bank amount is
unknown. Visit the bank after adding an item to check it. Cached bank counts stay
visible away from the bank while bag counts update live. Selling or consuming
items reduces progress; transfers between bags and bank preserve the total.
Reached goals turn green. Track up to 100 items with goals from 1 to 999999.

Commands: `/ift add <ID, link or cached exact name> <goal>`, `/ift remove <item>`,
`/ift show`, `/ift hide`, `/ift lock`, `/ift unlock`, `/ift reset`, `/ift help`.

Install this folder under `_forever_/Interface/AddOns/ItemFarmingTool/` with the
TOC directly inside. Enable it in the AddOns list. No dependencies are required.
Offline regression-tested; the live Forever appearance and interactions still
need an in-game check.

[Source, releases and full instructions](https://github.com/git-adin/ItemFarmingTool).
GPL-3.0-or-later; see LICENSE.
