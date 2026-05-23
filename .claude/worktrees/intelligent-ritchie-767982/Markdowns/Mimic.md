# Mimic — Procedural Creature Reference

> **STATUS: v1.1 (Patch 3 — spawn-on-arena + capturable via Net)**
>
> Implemented in this patch: spawn pipeline, MimicData resource, scan loop
> via TileSignalComponent, morph loop via CreatureMorphComponent, skill copy
> via SkillCopyComponent + AbilityRegistry. Bite attack uses the existing
> `Unarmed strike` weapon fallback.
>
> **Patch 3 additions:**
> - `ArenaSpawner` now seeds `mimic_count` Mimics (default 1) at arena init,
>   so the player can actually encounter one without a debug spawn. See
>   `Components/Arena/ArenaSpawner.gd` `mimic_count` export.
> - Mimics are capturable via the Net through the new minimum-viable
>   Capture flow (see `Markdowns/Capture.md`). On Net hit the Mimic gets
>   a `CaptureComponent` lazily attached; save → on fail: stun + catch
>   roll → on catch success: `MimicData` is built from the actor's live
>   ability scores and pushed to `HerdManager` via `add_goat`. The Mimic
>   then `queue_free`s — note `queue_free` rather than `die()` so no
>   fall-over visual fires (clean capture, not death).
>
> Deferred for later patches: breeding integration with HerdManager
> (asexual breeding code path), save/load of morph + stolen skills
> (currently transient), restraint stacking and drag mechanics (the full
> Capture system that the Patch-3 primitives are designed to extend into).

---

## Vision

The Mimic is a procedural ambusher. It scans nearby creatures, **copies up to
N of their abilities** (default `skill_copy_limit = 2`), **morphs into one of
them visually**, and uses the copied skills + a generic unarmed bite for a
fixed `morph_duration` (default 8s). Then it reverts to its base violet form,
drops the stolen skills, and goes looking for a new target.

The design goal is to demonstrate the project's "data-driven actor + clock +
tile-signal" pattern end to end with a creature that is built from existing
components rather than a new hardcoded subsystem.

---

## Files

| Path | Role |
|------|------|
| `Components/BreedingComponents/MimicData.gd` | `ActorData` subclass — every field is `@export`-tunable; `create_offspring()` is asexual budding with mutation. |
| `src/actors/types/MimicActor.gd` | `Actor` subclass — mirrors `GoatActor.goat_data` accessor pattern via `mimic_data: MimicData`. |
| `scenes/actors/MimicActor.tscn` | Minimal `CharacterBody3D` scene — sphere body, capsule collider, default `MimicData` sub-resource. |
| `src/actors/types/MimicController.gd` | `ActorAIController` subclass — owns the TileSignal trigger, GameClock tick, and dispatches to the morph + copy helpers. |
| `Components/ActorComponents/CreatureMorphComponent.gd` | Visual swap helper — generic; reusable by any morph-capable creature. |
| `Components/ActorComponents/SkillCopyComponent.gd` | Ability cloning helper — uses `AbilityRegistry.instantiate_for()` so cloned actions are bound to the copier, never shared. |

The Mimic is registered with `ActorFactory` at boot
(`ArenaSpawner._register_default_actor_types()`); the engine reaches it via
`ActorFactory.spawn(&"mimic", parent, position)`.

---

## MimicData fields

| Field | Default | Purpose |
|-------|---------|---------|
| `mimic_name: StringName` | `&"Mimic"` | Display label. |
| `aggression: float` (0-1) | `0.6` | Reserved for future chase-state tuning. |
| `scan_radius: int` | `4` | Hex radius watched by the TileSignal trigger. |
| `scan_interval: float` | `0.5` | Seconds between scan ticks (GameClock). |
| `morph_duration: float` | `8.0` | Seconds a morph lasts before automatic revert. |
| `skill_copy_limit: int` | `2` | Max stolen abilities at once. |
| `disallowed_target_types: Array[StringName]` | `[&"mimic", &"scarecrow"]` | Targets skipped during pick. Prevents feedback loops. |
| Inherited stat block (str/dex/con/int/wis/cha) | `0.5/1.5/0.0/0.5/1.0/-1.0` | Initialized in `_init()` — slightly dexterous, fragile. |

---

## Scan loop

1. `MimicController._register_scan_trigger()` registers a continuous-mode
   trigger of radius `mimic_data.scan_radius` on the Mimic's current tile.
   The center moves with the Mimic via `tile_changed → update_trigger_center`.
2. `_on_scan_trigger_activated` / `_on_scan_trigger_deactivated` maintain
   `_nearby_actors: Array[Actor]` symmetrically. The cache is pruned of
   freed / dead instances on every scan tick.
3. `_on_scan_tick` is registered with `Actor.register_tick(callback,
   scan_interval)` — which routes through `GameClockComponent` per
   AGENTS.md.

No `Timer.new()` and no per-frame distance math. The Mimic's distance
authority is `TileSignalComponent`; its cadence authority is
`GameClockComponent`.

## Morph loop

- **Base form + at least one valid target nearby** → pick a target uniform-random
  from `_nearby_actors`, filtered by `disallowed_target_types`. Call
  `CreatureMorphComponent.morph_into(target)` and
  `SkillCopyComponent.copy_from(target, skill_copy_limit)`.
- **Morphed** → increment `_morph_elapsed += scan_interval`. When it reaches
  `morph_duration`, call `_morph_component.revert()` and
  `_skill_copy_component.restore()`.

`CreatureMorphComponent` snapshots the Mimic's original `_data` on first
morph and dispatches `actor.visual_component.setup_visuals(target._data)` —
which is the new polymorphic entry point on `ActorVisualComponent` (B12).
Without that dispatch the visual swap is a no-op; today the dispatch
handles `GoatData` and `MimicData`. Goblin / Farmer / Fire / Water carry no
`*Data` resource, so morphing into one of them is currently a **behavioral
morph only** (the visuals don't change). That is by design — adding visual
swap for those types requires `*Data` subclasses to ship first.

## Skill copy loop

`SkillCopyComponent.copy_from(donor, limit)`:

1. Reads `donor.ability_component.actions: Array[AbilityAction]`.
2. For each action up to `limit`, reads its `ability_name`.
3. Calls `AbilityRegistry.instantiate_for(name, self, ability_component)` to
   build a **fresh** instance bound to the Mimic (the donor's instance is
   never shared — `AbilityAction` is `RefCounted` and `actor`-bound).
4. Adds the clone to `actor.ability_component.actions` and tracks the name
   in `_copied_names`.

`restore()` removes only those copies (by name multiset) so the Mimic's
permanent ability set, if any, is untouched.

The stealable pool today is small (GoatCharge, NimbleEscape, RedirectAttack
— three classes total). Adding new `AbilityAction` subclasses to
`Components/ActorComponents/AbilityComponents/` automatically extends the
Mimic's vocabulary because the registry scans the folder on autoload boot.

---

## Bite attack

The Mimic equips the global `Unarmed strike` weapon (assigned in
`MimicActor._equip_default_bite()` after WeaponComponent setup). This routes
through the existing `MeleeHitbox` path with the catalog's default 1-point
bludgeoning damage. No new `WeaponData` entry is shipped — per the agent
spec.

A future "bite" weapon Resource with stronger damage and a piercing damage
type can be added by registering a new `WeaponData` in `Core/ItemsAutoload.gd`
and assigning it from `MimicActor._equip_default_bite()`.

---

## Deferred features and their prerequisites

| Feature | Why deferred | Gating prerequisite |
|---------|--------------|----------------------|
| Visual morph into Goblin / Farmer / Fire / Water | None of those actor types carry a `*Data` resource. `ActorVisualComponent.setup_visuals` no-ops on null data. | `GoblinData`, `FarmerData`, `ElementalData` subclasses (Breeding.md Phase 4). |
| Mimic breeding | `HerdManager.next_day()` only re-adds offspring that pass `kid as GoatData`, so MimicData kids are silently dropped. `BreedingComponent.breed()` requires male+female. | B7 (HerdManager generalization) + B18 (`BreedableComponent` for ASEXUAL mode, or a `breed_asexual` code path). |
| Mimic capture | The Capture system is zero implemented today. | `CaptureComponent` + `ActorState` enum (Capture.md / Breeding.md §Capture canonical). |
| Save/load of morph + stolen actions | `Core/Managers/SaveComponent.gd` writes `GoatSaveData` only and has no schema for transient combat state. | Schema change. **Design choice for v1.0: morph + stolen skills are transient and reset on save/load.** Document this in patch notes so players are not surprised. |

---

## Performance notes

- The Mimic adds **one TileSignal trigger** and **one GameClock callback** per
  actor instance — both centralized authorities that are already exercised
  by `DetectionComponent` and `StatusEffectComponent`. Each Mimic in the
  scene therefore costs roughly the same as one extra goblin's detection
  component.
- `_nearby_actors` is pruned only on scan ticks, so a freed actor lingers in
  the array for at most `scan_interval` seconds. That's harmless because
  `_is_valid_target` filters in real time.
- Morphs do not allocate per-frame — the visual swap is a single material
  parameter set + scale assignment. Skill copies allocate fresh
  `AbilityAction` instances each morph (small, refcounted) and free them on
  revert.

---

## How to extend

- **New Mimic ability vocabulary**: drop a new `AbilityAction` subclass into
  `Components/ActorComponents/AbilityComponents/`. `AbilityRegistry` scans
  the folder on boot and the Mimic will copy the new ability from any donor
  that already has it.
- **Tunable variants**: author a `MimicData.tres` with different stat /
  aggression / radius / duration values and assign it to a Mimic instance's
  `_data` in the inspector or via `ArenaSpawner` extensions.
- **New morph-capable creature**: add `CreatureMorphComponent` and
  `SkillCopyComponent` to its controller. The components are not Mimic-
  specific.
- **Visual morph into more actor types**: add a `*Data` resource for the
  target type and a branch in `ActorVisualComponent.setup_visuals()`.

---

*Last updated: 2026-05-16 (Extended Slice).*
