## ItemFarmingTool 0.1.0

Initial version of a lightweight item farming tracker for WoW Forever.

- Track multiple items with individual quantity goals in a compact movable box.
- Add items by ID, link, cached exact name, dragging, or Shift-clicking with the item field focused.
- See bag-only counts, progress bars, remaining quantities and green completion indicators.
- Edit goals, remove items, scroll the list, lock movement, collapse or hide the tracker.
- Save targets and tracker settings per character. No addon dependencies or polling loop.

Download **ItemFarmingTool.zip** and extract it into `_forever_/Interface/AddOns/`.
Use `/ift` to open the tracker. Counts exclude equipment, banks, mail and auctions.

Validated with offline Lua 5.1 inventory/UI tests and package checks. Live Forever
appearance and interactions still require in-game verification.
