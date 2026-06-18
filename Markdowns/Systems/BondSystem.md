# Bond System

**Status:** v1 scaffolded (2026-05-25)
**Source:** `Components/BreedingComponents/BondManager.gd` (autoload)
**Spec:** `GameLoopIdea.md §7`

---

## What it does

Tracks the **relationship between pairs of monsters** that have shared dungeon runs together. Pairs build bond levels (0–5) as they survive runs. Bond unlocks perks. Losing a bonded packmate applies a Grief debuff to the survivor.

This is the emotional architecture of Hornbound — without it, monsters are interchangeable units. With it, players form attachments to specific pairs and the procedural names start meaning something.

---

## Bond Levels

| Level | Runs together | Unlock |
|-------|---------------|--------|
| 0 | 0 | (default) |
| 1 | 1 | +5% damage to a shared target when adjacent |
| 2 | 3 | **Unlocks species-pair combo move** (read from ActorTypeData.combo_pool) |
| 3 | 7 | Combo cooldown −30% |
| 4 | 15 | +2% all stats when paired |
| 5 | 30 | **Legacy bond** — +20% damage in biome where partner fell, for next run after death |

---

## Grief

When a packmate with bond ≥ 2 dies:
- Survivor gets `damage_dealt × 0.9` and `damage_taken × 1.05`
- Lasts `3 + (bond_level − 2)` days (3–6 days)
- Stacks if multiple bonded packmates die (each adds its own entry)
- Auto-expires on day-tick

Bond 0 or 1 → no grief. Casual acquaintances don't traumatize.

---

## API surface

```gdscript
# All called via the autoload, e.g. BondManager.tick_squad(...)

BondManager.tick_squad(squad: Array)
    # Called from the run controller after a successful run.
    # All pairs of survivors get their runs_together +1.

BondManager.get_bond(seed_a: int, seed_b: int) -> int
    # Returns 0-5.

BondManager.apply_grief(survivor: ActorData, dead: ActorData)
    # Called when a bonded packmate dies in combat.

BondManager.get_grief_modifiers(creature: ActorData) -> Dictionary
    # { damage_dealt: float, damage_taken: float }

BondManager.advance_day()
    # Called from hub day-tick (contract accept).
    # Prunes expired grief.

BondManager.bond_increased  # Signal — (seed_a, seed_b, new_level)
BondManager.grief_applied   # Signal — (survivor_seed, dead_seed, days)
```

---

## Identity: render_seed as the bond key

Bonds are keyed by **render_seed**, not an extra `monster_id` field. Every ActorData has one, set at creation and stable across saves. This avoids a redundant ID system and ensures bonds survive every reload.

Pair keys are canonicalized as `"min_seed,max_seed"` so lookup is order-independent.

---

## Combo move discovery

When two monsters reach bond 2, the system queries `ActorTypeData.get_combo_for_pair(species_a, species_b)`. Each species' `combo_pool` dict lists which partners it combos with and what the move is called:

```gdscript
"Goat": {
    "combo_pool": {
        "Mimic": "Bait & Charge",
        "Mushroom": "Spore Sweep",
        "Goblin": "Stab & Smash",
        "Wolf": "Wild Stampede"
    }
}
```

Combos are authored, not procedural. The bond system just unlocks them — what they DO mechanically is implemented in `AbilityComponent` (future work).

For hybrid kids, they inherit both parents' `combo_pool` (intersection of all pairings). A Goat × Mimic kid could combo with Mushroom (Goat's pairing) OR Goblin (Goat's pairing) etc.

---

## Persistence

Bonds and grief state save to `user://bond_state.cfg` on every tick. Survives reloads, save imports, and herd restructures.

---

## Future Hooks (not yet wired)

- **Combo execution** — when both bonded monsters are in the pack and the player issues "Combo" command, the appropriate combo fires
- **Bond visualizations** — small UI overlay shows pair bonds in the squad picker
- **Bond statistics** — leaderboard board for "longest-bonded pair"
- **Grief visuals** — debuff icon over grieving monster's portrait
