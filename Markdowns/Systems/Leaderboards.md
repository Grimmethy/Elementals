# Leaderboards

**Status:** v1 scaffolded local-only (2026-05-25)
**Source:** `Core/LeaderboardManager.gd` (autoload)
**Spec:** `GameLoopIdea.md §10`

---

## Why leaderboards instead of a "you won" ending

Hand-authored endings age out. Leaderboards become the meta-game forever. Multiple boards mean different player types find their own home — combat skill, breeding skill, exploration, strategy, pure breeding flex.

The five boards + daily seeded run reach 80% of competitive game retention systems with very little authored content.

---

## The Five Boards

| Board | Score formula | Higher / Lower better | Player type |
|-------|---------------|----------------------|-------------|
| **Deepest Dive** | Number of floors cleared in a single endless dungeon | Higher | Combat skill, squad comp |
| **Apex Bloodline** | `hybrid_generation` of the first creature whose lineage covers all 14 D&D categories | **Lower** | Breeding skill, long-term planning |
| **Trait Library Speed (50/100/all)** | Days played to reach trait milestone | **Lower** | Exploration, capture mastery |
| **Contract Chain** | Longest consecutive successful run streak | Higher | Strategy, risk management |
| **Highest-Rated Chimera** | `graft_count × 8 + mutation_count × 6 + hybrid_generation × 4 + library_completeness × 0.5` for a single creature | Higher | Pure breeding flex |

The `LOWER_IS_BETTER` constant in the autoload lists which boards reverse the sort order.

---

## Daily Seeded Run

The killer feature. `LeaderboardManager.get_today_seed()` returns an integer derived from the current UTC day index. Same number worldwide for one day.

The daily run uses pre-rolled starter monsters (no breeding head-start matters), the seed picks the dungeon layout, and players race to the deepest floor / best score.

This is the **Slay the Spire Daily Climb** mechanic. Practically free to implement, infinite replayability.

Use `get_daily_seed_offset(days_from_today)` to query past or future seeds (e.g. for viewing yesterday's leaderboard).

---

## Submission

```gdscript
LeaderboardManager.submit_score(
    "deepest_dive",
    7.0,
    "Floor 7 — Crystal Caverns",
    {"squad_names": [...], "biome": "crystal", "run_duration_sec": 1234}
)
```

Returns the 1-indexed rank on that board after insertion. Boards are capped at 25 entries; lower-ranked entries fall off.

---

## Persistence

All scores save to `user://leaderboards.cfg` on every submission. Survives reloads. Local-only for MVP — online backend (Steam Leaderboards or custom REST API) is a later milestone.

---

## When score functions are called

- **Deepest Dive** — submit at run end with final floor count
- **Apex Bloodline** — submit once, when a creature with lineage_categories.size() == 14 hatches. Subsequent qualifying creatures just won't beat the first if you've already achieved it.
- **Trait Library Speed** — listen to `TraitLibrary.traits_added`; check if known_trait_count just crossed 50/100/all; submit `current_day` as the score
- **Contract Chain** — track in run controller; on `run_succeeded`, increment counter; on `run_failed`, submit if it was the longest and reset
- **Chimera Rating** — compute via `compute_chimera_rating(creature)` whenever a player wants to submit (e.g. on hatch, or via a "showcase" UI button)

---

## Future work

- Online backend (post-MVP)
- Weekly seeded run + monthly events
- "Pro" daily that uses the player's own herd (different leaderboard)
- Specialty boards: smallest-squad clear, no-capture clear, no-extract clear, single-species clear
