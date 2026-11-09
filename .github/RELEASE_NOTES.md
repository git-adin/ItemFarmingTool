## ItemFarmingTool 0.2.2

- Add a small gold sparkle at the progress bar tip when an item crosses its goal.
- The effect fades out after 0.63 seconds using native UI animations.
- Refreshes, reloads, goal edits and counting-mode switches do not replay the effect.
- Falling below the goal rearms it; hidden or collapsed completions do not queue an animation.

Download **ItemFarmingTool.zip** and extract it into `_forever_/Interface/AddOns/`.
Use `/ift` to show the tracker. Choose Bags only or Bags + bank using the footer.

Validated with offline Lua 5.1 inventory/UI tests and package checks. Animation
appearance still requires an in-game check on Forever.
