# Run Structure — The 4-Room Dungeon

**Status:** v1 scaffolded (2026-05-25)
**Source:** `Components/Arena/DungeonRunController.gd` + `RoomTemplates/` + `UI/ExtractScreen.tscn`
**Spec:** `GameLoopIdea.md §1`

---

## What's a Run?

A bounded **15-25 minute permadeath expedition** through a 4-room dungeon. Player picks a contract at the hub, accepts (advances day), enters the dungeon. Four rooms in sequence. At the end, three buttons: Leave, Push, Abandon.

The state machine sits in `DungeonRunController`. The arena spawns enemies / loot according to `RoomTemplate` resources (one per room type per biome).

---

## State Machine

```
NOT_STARTED → WARMUP → BRANCH → MIDBOSS → EXTRACT ─┬→ LEAVE → DONE_SUCCESS
                                                    ├→ PUSH  → BOSS → DONE_SUCCESS
                                                    └→ ABANDON → DONE_ABANDON

(At any state, if player pack is wiped) → DONE_FAILURE
```

| State | Purpose | Estimated time |
|-------|---------|----------------|
| WARMUP | Easy fight, confirm squad works | ~3 min |
| BRANCH | Choice between Loot or Alpha (capturable rare) | ~4 min |
| MIDBOSS | The test. ~40% of deaths happen here. | ~6 min |
| EXTRACT | UI screen: leave/push/abandon | ~30s |
| PUSH_BOSS | Bonus room with rare reward (only if PUSH chosen) | ~6 min |

---

## Rewards Accumulate, Don't Bank

The `pending_rewards` dict on the controller accumulates as rooms are cleared:

```gdscript
pending_rewards = {
    "gold": int,
    "parts": Array[String],
    "captured": Array[ActorData],
    "traits_learned": Array[String],
    "loot_items": Array[String],
}
```

At EXTRACT, the three buttons handle this dict differently:

- **LEAVE** → emits `run_succeeded(pending_rewards)`. Hub processes them.
- **PUSH** → keeps the dict, enters PUSH_BOSS. On boss kill, emits `run_succeeded(pending_rewards + boss_bonus)`. On wipe in boss, full dict is lost.
- **ABANDON** → clears `pending_rewards` to empty, emits `run_succeeded({})`. Monsters survive.

The PUSH gamble is the design heart: take what you have, or risk it for more.

---

## Bond + Day Ticking

When a run completes successfully (`run_succeeded` fires):
1. `BondManager.tick_squad(player_squad)` — surviving pairs increase their bond
2. `BondManager.advance_day()` — day counter advances, grief entries expire

On a wipe (`run_failed`): bonds don't increase. Day doesn't advance — the world isn't moving on without you.

On abandon: day DOES advance. You used up the day; just didn't earn anything.

---

## RoomTemplate Schema

Each room is described by a `RoomTemplate` resource:

```gdscript
@export var room_id: String       # unique within a biome
@export var biome: String          # "" = generic
@export var difficulty: float       # multiplier
@export var enemy_types: Array     # ActorTypeData species
@export var loot_gold_min: int
@export var loot_gold_max: int
@export var loot_parts: Array[String]
@export var alpha_species: String   # for BRANCH alpha rooms — capturable rare
```

The arena spawn logic reads these fields and populates the room. Authoring new content = creating new RoomTemplate .tres files. No code per room.

---

## Pack Wipe Detection

When the controlled actor dies, `PlayerInputComponent._on_controlled_actor_died` tries to possess the nearest packmate. If all packmates are dead, it emits `player_pack_wiped` on the arena, which the run controller listens to. Run ends in failure.

---

## How rooms are wired

```
DungeonRunController            Arena (existing)             RoomTemplate (resource)
       │                              │                              │
   start_run()                        │                              │
       │                              │                              │
   _transition(WARMUP)                │                              │
       │  room_entered(WARMUP)        │                              │
       │ ─────────────────────────────→ populate_room(template)      │
       │                              │      ↓ read enemy_types     │
       │                              │      ↓ spawn via ArenaSpawner│
       │                              │                              │
       │  (player kills all enemies)  │                              │
       │  ←─────── arena signals room_cleared() ─────────────────────│
       │                              │                              │
   complete_current_room()            │                              │
       │  room_completed(WARMUP)      │                              │
       │  template.on_room_completed()→ add_gold, add_part to rewards│
       │                              │                              │
   _transition(BRANCH) ... (and so on)
```

The controller has no opinion on HOW rooms are populated; it only knows when a room is done. Spawning logic stays in the Arena.

---

## Why no save mid-run

Permadeath needs a clean break. Save mid-run defeats the entire risk/reward gambit. Run failure is the punishment; the punishment isn't real if you can reload. So no save buttons during a run.

(Save points exist at the hub, between runs, like Hades' House of Hades.)

---

## Future Work

Room generation logic itself (which template gets picked per slot, biome layouts, layout pools per biome) lives outside this file in `Arena` integration. Phase 7 scaffolded the *contract* — `Arena` calls room template's `populate_room()`. The actual room population code is a follow-up after `DungeonRunController` is wired into Arena.
