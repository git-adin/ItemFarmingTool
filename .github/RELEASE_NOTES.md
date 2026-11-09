## ItemFarmingTool 0.2.0

Adds personal bank tracking for WoW Forever.

- Goals now combine carried bags and personal bank items, with a bag/bank breakdown.
- Open your bank to scan tracked items; deposits and withdrawals refresh counts.
- Cached bank totals persist per character across bank closing, reloads and logouts.
- The footer shows the bank scan time. Unchecked items show Bank ? and a + on the known total.
- Equipment, guild/account banks, mail and auctions are excluded. Reagent storage is included when supported.

Download **ItemFarmingTool.zip** and extract it into `_forever_/Interface/AddOns/`.
Use `/ift` to open the tracker, then visit your bank to initialize stored-item counts.

Validated with offline Lua 5.1 inventory/UI tests and package checks. Live Forever
appearance and interactions still require in-game verification.
