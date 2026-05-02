---
name: JellyUp improvement task list
description: Prioritized list of improvements to work through for the JellyUp game
type: project
---

Improvement list agreed on 2026-03-23:

1. **Refactor coral walls (pipes) to move on Y axis** — walls should spawn at top and move downward, simulating the jellyfish traveling upward. Also consolidate left/right pipe scripts into a single parameterized script. Fix scaling/resolution issue with wall sizes. (IN PROGRESS)
2. **Fix cleanup bounds bugs** — `abs(global_position.x) < 0` in Plants.gd and `abs(global_position.y) < 0` in rightSidePipeTileMap.gd never evaluate to true, causing memory leaks.
3. **Fix Player input feel** — impulse fires on key release instead of press; animation replays every frame in `_process`.
4. **ScoreTracker hardcoded paths** — replace absolute node paths with autoload/signals.
5. **Rename pipe folders/files** to thematic ocean names (Coral, Rocks, etc.).
6. **Break up world.gd** — extract spawning logic into dedicated spawner nodes.
7. **Design polish** — bioluminescent glow (PointLight2D), varying obstacle types, depth meter.

**Why:** User wants to systematically work through all issues. Starting with items 1-3 this session.
**How to apply:** Track progress here; check off items as completed.
