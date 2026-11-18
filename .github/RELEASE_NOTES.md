## ItemFarmingTool 0.2.3

Fix bank-cache persistence and add Clear all.

- Save a complete character-bank snapshot, including items not currently tracked.
- Scan Forever's character-bank containers directly rather than subtracting item-count API results.
- Preserve saved bank quantities and scan times across reloads, logouts, loading states and failed scans.
- Preserve bank data when individual goals are removed or the list is cleared.
- Items added after a full scan immediately use the saved snapshot.
- Wait briefly for bank data on opening and retry unavailable scans a bounded number of times.
- Add a **Clear all** button to remove tracked goals while retaining the bank cache and settings.

After updating, use `/reload` and visit your bank once to populate the full snapshot.
Older saved bank counts are retained. Choose **Bags + bank** to include stored items.

Validated with offline Lua 5.1 tests, saved-file reloads in fresh Lua sessions, and
release-package checks. Live Forever behavior still requires an in-game check.
