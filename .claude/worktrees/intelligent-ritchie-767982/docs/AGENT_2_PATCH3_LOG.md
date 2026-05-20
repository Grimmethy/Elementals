# Agent 2 — Patch 3 Implementation Log

> Scope: **Minimum-viable Net catch + Mimic spawn wiring**. The previously
> planned Patch 3 (ProgressionComponent generalization, sell_goat polymorphism,
> die() hooks, GoatRenderer rename) is deferred to Patch 4 per the scope pivot
> in the agent brief.
>
> All paths repo-relative.

---

## 1. Files Inspected

| Path | Why |
|------|-----|
| [docs/ELEMENTALS_PATCH2_STATUS.md](ELEMENTALS_PATCH2_STATUS.md) | Baseline state. |
| [docs/COWORKER_IMPLEMENTATION_NOTES.md](COWORKER_IMPLEMENTATION_NOTES.md) §0 | Patch 2 addendum + canonical breeding-data state. |
| [Markdowns/Capture.md](../Markdowns/Capture.md) | Pre-existing design (deprecation pointer + canonical model). |
| [Markdowns/Breeding.md](../Markdowns/Breeding.md) | Canonical ActorState target for the full Capture patch. |
| [Markdowns/Mimic.md](../Markdowns/Mimic.md) | Existing Mimic implementation reference. |
| [Components/Arena/ArenaSpawner.gd](../Components/Arena/ArenaSpawner.gd) | Spawn pipeline + ActorFactory registration. |
| [Components/WeaponComponents/WeaponComponent.gd](../Components/WeaponComponents/WeaponComponent.gd) | Attack flow — `attack_target` → `secondary_attack` for thrown. |
| [Components/WeaponComponents/MeleeHitbox.gd](../Components/WeaponComponents/MeleeHitbox.gd) | Damage path for melee swings (read for reference, not modified). |
| [Components/WeaponComponents/RangedComponent.gd](../Components/WeaponComponents/RangedComponent.gd) | Projectile spawn — sets `proj.source_weapon_data = _weapon_data` (line 102). |
| [Components/WeaponComponents/ProjectileComponent.gd](../Components/WeaponComponents/ProjectileComponent.gd) | Per-attack-pattern projectile launchers. |
| [src/actors/projectiles/BaseProjectile.gd](../src/actors/projectiles/BaseProjectile.gd) | Projectile hit + damage application — **the hit hook lives here**. |
| [src/actors/base/Actor.gd](../src/actors/base/Actor.gd) | `stun(duration)`, `is_dead`, `_data`, `element_type`, `ability_scores_component`. |
| [Components/ActorComponents/StunComponent.gd](../Components/ActorComponents/StunComponent.gd) | Existing stun authority — already routed through `_process(delta)`, not Timer.new(). |
| [Components/ActorComponents/AbilityScoresComponent.gd](../Components/ActorComponents/AbilityScoresComponent.gd) | Source of `dexterity` modifier for save rolls. |
| [Components/ActorComponents/SkillCheckComponent.gd](../Components/ActorComponents/SkillCheckComponent.gd) | Existing d20-check convention (`d20 + stat_value vs DC`). |
| [Components/BreedingComponents/HerdManager.gd](../Components/BreedingComponents/HerdManager.gd) | `add_goat(actor_data: ActorData)` is the persistence path. |
| [Components/BreedingComponents/MimicData.gd](../Components/BreedingComponents/MimicData.gd) / [GoblinData.gd](../Components/BreedingComponents/GoblinData.gd) / [FarmerData.gd](../Components/BreedingComponents/FarmerData.gd) / [ElementalData.gd](../Components/BreedingComponents/ElementalData.gd) / [GoatData.gd](../Components/BreedingComponents/GoatData.gd) | Subclass shapes for the dispatch table in `CaptureComponent._create_data_for_actor`. |
| [Core/ItemsAutoload.gd](../Core/ItemsAutoload.gd) | Net entry at line 121; `_add(...)` signature. |
| [Core/WeaponData.gd](../Core/WeaponData.gd) | `_parse_notes()` parser — extension target for the `"capture"` keyword. |
| [src/actors/types/MimicActor.gd](../src/actors/types/MimicActor.gd) | Mimic auto-creates `MimicData` so the capture flow has a data resource to copy visuals from. |

---

## 2. Systems Found

### Existing systems used as-is

- `Actor.stun(duration)` → routes through `StunComponent`. `StunComponent` already uses `_process(delta)` for decrement (NOT `Timer.new()` — compliant). No new stun infrastructure was added; `CaptureComponent.apply_stun()` is a thin wrapper.
- `Actor.ability_scores_component.dexterity` is a **modifier** float (e.g. `1.5`), not a 1–20 score. The `SkillCheckComponent` convention is `d20 + modifier vs DC` — matched exactly in `CaptureComponent.roll_save()`.
- `BaseProjectile.source_weapon_data` is already populated by `RangedComponent.launch()` at line 102 — no plumbing needed to get the Net's WeaponData to the hit handler.
- `HerdManager.add_goat(actor_data: ActorData)` already accepts any `ActorData` subclass (B7 fix from Patch 2). The capture flow uses this verbatim.
- `ActorFactory` already had a `"mimic"` registration ([ArenaSpawner.gd:39](../Components/Arena/ArenaSpawner.gd)) from Patch 1 — Mimic spawn is just adding the missing seeding call to `spawn_initial_actors()`.

### Existing systems EXTENDED additively (no behavior change for non-Net weapons)

- `WeaponData._parse_notes()` — new `is_capture_tool = "capture" in n` line. All other weapons leave `is_capture_tool = false` (default) so the damage path is unchanged.
- `BaseProjectile._on_body_entered()` — new early-return branch that only fires when `source_weapon_data.is_capture_tool == true`. Damage flow below is untouched.

---

## 3. Bugs or Gaps Found (with patch approach per item)

### Bug 1 — User-reported: Net "doesn't roll a save / catch chance when used"

**Cause:** before this patch, the Net was just a regular thrown weapon. `BaseProjectile._on_body_entered` called `_apply_hit_damage` → `damage_component.deal_damage` with the Net's `damage = "-"` (rolls `1` per `WeaponData.roll_damage`). No save, no stun, no catch. The `"special"` flag in notes was a design intent that never had a parser.

**Fix:** introduced three primitives (`CaptureComponent`, `CaptureProfile`, `WeaponData.is_capture_tool`), wired Net's notes from `"special"` to `"capture"` so `_parse_notes()` flips the flag, and added the data-driven hit hook in `BaseProjectile._on_body_entered`.

### Bug 2 — User-reported: Mimic "isn't actually in the game"

**Cause:** Patch 1 registered the Mimic with `ActorFactory` ([ArenaSpawner.gd:39](../Components/Arena/ArenaSpawner.gd)) but `spawn_initial_actors()` never seeded any. The MimicActor scene exists, the AI works, the morph loop works — but without an instance in the world, the Mimic is dead code.

**Fix:** added `@export var mimic_count: int = 1` to ArenaSpawner and a spawn pass in `spawn_initial_actors()` that runs through the existing `_get_random_spawn_tile + spawn_actor_at_tile("mimic", tile)` pipeline (same path used for goblins). Default 1 mimic per arena run — designer can crank it up via the inspector.

### Gap (intentionally NOT fixed in this patch)

- `ProgressionComponent.advance_day()` still has GoatData-only field reads. Deferred to Patch 4 per the brief.
- Asexual breeding code path for Mimic. Deferred.
- Restraint stacking, drag mechanics, ActorState enum, taming loyalty. All deferred to the full Capture patch — the Patch-3 primitives are designed to extend.

---

## 4. Files Patched

| Path | Change |
|------|--------|
| [Core/WeaponData.gd](../Core/WeaponData.gd) | Added `is_capture_tool: bool` and `capture_profile_path: String` `@export`s. Extended `_parse_notes()` to set `is_capture_tool = "capture" in n`. Other parser branches unchanged. |
| [Core/ItemsAutoload.gd](../Core/ItemsAutoload.gd) | Updated Net entry notes from `"Thrown (range 5/15), special"` to `"Thrown (range 5/15), capture"`. Added a post-`_add` loop that finds the Net in `weapons[]` and sets `capture_profile_path = "res://Components/ActorComponents/CaptureProfiles/DefaultNet.tres"`. |
| [src/actors/projectiles/BaseProjectile.gd](../src/actors/projectiles/BaseProjectile.gd) | Added capture-tool early-return branch in `_on_body_entered()` that calls `_run_capture_flow(body)` + `queue_free()` before any damage / stick logic. Added `_run_capture_flow(target: Actor)` and `_load_capture_profile()` helpers. Damage flow below the new branch unchanged. |
| [Components/Arena/ArenaSpawner.gd](../Components/Arena/ArenaSpawner.gd) | Added `@export_range(0,10,1) var mimic_count: int = 1`. Added a spawn pass in `spawn_initial_actors()` that loops `mimic_count` times calling `spawn_actor_at_tile("mimic", _get_random_spawn_tile())`. |
| [Markdowns/Capture.md](../Markdowns/Capture.md) | Updated deprecation header to document Patch 3's minimum-viable subset and the canonical full design. |
| [Markdowns/Mimic.md](../Markdowns/Mimic.md) | Bumped status to v1.1, documented spawn-on-arena + capturable-via-Net additions. |

---

## 5. New Files Created

| Path | Purpose |
|------|---------|
| [Components/ActorComponents/CaptureComponent.gd](../Components/ActorComponents/CaptureComponent.gd) | Lazy-attached component with the three primitives `roll_save() / roll_catch() / apply_stun() / apply_capture()` plus `can_be_captured()` gate. Owns the `[Capture] ...` print readouts. |
| [Components/ActorComponents/CaptureProfile.gd](../Components/ActorComponents/CaptureProfile.gd) | Designer-authored `Resource` with `save_dc / save_ability / stun_duration / catch_chance / allowed_actor_types`. |
| [Components/ActorComponents/CaptureProfiles/DefaultNet.tres](../Components/ActorComponents/CaptureProfiles/DefaultNet.tres) | The Net's default profile — `save_dc=12, save_ability=&"dexterity", stun_duration=4.0, catch_chance=0.4`. |
| [docs/AGENT_2_PATCH3_LOG.md](AGENT_2_PATCH3_LOG.md) | This file. |

No `.gd.uid` files created — the editor generates them on first open.

---

## 6. Systems Preserved (explicit list)

The following were inspected and **deliberately not modified** to avoid the previously planned (now deferred) Patch 3 work:

- `Core/Managers/ProgressionComponent.gd` — still reads GoatData-only fields. Deferred.
- `Components/BreedingComponents/HerdManager.gd` `sell_goat()` — already polymorphic via `actor.get_sell_value()` (lifted in Patch 2). No change needed.
- `Components/BreedingComponents/HerdManager.gd` `next_day()` — uses Patch 2's generic `for kid in new_kids: if kid: add_goat(kid)` already.
- `Core/Managers/BreedingComponent.gd` — gender gate unchanged. Mimic asexual breeding deferred.
- `UI/DisplayCard/GoatRenderer.gd` — rename deferred.
- `src/actors/types/GoatActor.gd` / `GoblinMinion.gd` / `FarmerActor.gd` / `FireActor.gd` / `WaterActor.gd` — no `die()` hook changes. `MimicActor.die()` was already updated in Patch 1.
- `Components/WeaponComponents/MeleeHitbox.gd` — not modified. Capture is currently only triggered via thrown / projectile path because the Net is `is_thrown=true` and uses `secondary_attack` → `RangedComponent.launch`. If a melee capture tool ships later, mirror the same `is_capture_tool` check inside `MeleeHitbox._handle_hit` — keep the dispatch identical to keep the data-driven design.
- `Components/WeaponComponents/WeaponComponent.gd` / `RangedComponent.gd` — no changes needed; `source_weapon_data` plumbing already in place.

---

## 7. Implementation Summary

The patch lands two visible features:

**A. Mimic spawn wiring.** One new `@export` (`mimic_count: int = 1`), six new lines in `spawn_initial_actors()` that mirror the existing goblin spawn pass. Routes through the existing `ActorFactory.spawn(&"mimic", ...)` registration. Mimic appears on the map at arena init, walks around per `MimicController`, scans for targets, eventually bites someone or morphs.

**B. Minimum-viable Net capture.** Three primitives (`CaptureComponent`, `CaptureProfile`, the `BaseProjectile` hit hook) plus one data-driven flag on `WeaponData`. The flow on Net throw:

1. Player throws Net at target. `WeaponComponent.attack_target` detects `is_thrown` + `current_ammo > 1` → `secondary_attack` → `_perform_attack(..., true)` → `RangedComponent.launch` spawns `ArrowProjectile.tscn` (the Net's fallback projectile scene — `projectile_scene_path = ""` for the Net catalog entry) with `proj.source_weapon_data = NetWeaponData`.
2. Projectile flies, collides with target Actor, `BaseProjectile._on_body_entered` fires.
3. New early-return branch detects `source_weapon_data.is_capture_tool` → calls `_run_capture_flow(target)` and `queue_free()`s the projectile.
4. `_run_capture_flow` loads `DefaultNet.tres`, lazy-attaches a `CaptureComponent` to the target, runs `can_be_captured()` gate → `roll_save()` (prints `[Capture] Net hit X. Save: rolled N vs DC 12 → SUCCESS/FAIL (d20=K + dexterity=M)` — the trailing breakdown is a Patch-3 addition for designer debugging, kept compatible with the user's spec).
5. On save fail: `apply_stun(4.0)` → `roll_catch()` (prints `[Capture] X stunned for 4.0s. Catch roll: N.NN vs 0.40 → CAUGHT/ESCAPED`).
6. On catch success: `apply_capture()` → builds `MimicData.new()` from the actor's element_type, populates ability scores from `actor.ability_scores_component`, pushes to `HerdManager.add_goat`, `queue_free()`s the actor. Prints `[Capture] X added to herd as mimic`.

Data resource creation is **at capture time** (option (b) per advisor) — no spawn-time data changes were required for wild actors. Wild actors that lack `_data` (goblin, fire, water, farmer) work fine because `CaptureComponent._create_data_for_actor()` dispatches on `actor.element_type` (set in each subclass's `_init()`), not on `actor._data`.

---

## 8. Procedural / Modular Design Summary

The three primitives are designed to be **extended verbatim** by the full Capture patch (not replaced):

- **`CaptureProfile` fields are additive.** Future Capture patch adds `restraint_rating: int`, `escape_dc_curve: Curve`, `taming_loyalty_per_session: float`, etc. — none of the existing fields are removed. Existing `.tres` files continue to load.
- **`CaptureComponent` API is additive.** `can_be_captured()`, `roll_save()`, `roll_catch()`, `apply_stun()`, `apply_capture()` all stay; future patch adds `apply_restraint(item: WeaponData)`, `roll_escape()`, `transition_to_taming()`, `transition_to_tamed()`. The `apply_capture()` body — build data + `HerdManager.add_goat` + `queue_free` — moves into `transition_to_tamed()` so the WILD → RESTRAINED → CONFINED → TAMING → TAMED chain calls it at the right moment instead of immediately at hit time.
- **`BaseProjectile._run_capture_flow` is the single hit-side dispatch.** When restraint items ship (rope, chain), they all flow through the same lazy-attach + `apply_restraint` chain rather than each one growing its own hit handler. The `is_capture_tool` flag stays as the single gate.
- **Data dispatch is one method (`_create_data_for_actor`).** When new capturable creatures land they get one case in this match statement — no scattered `if`s elsewhere.
- **All readouts use a single `[Capture]` tag** so they're easy to grep / pipe to a future UI panel.

The `WeaponData.is_capture_tool` flag is data-driven (notes string keyword), so adding new capture tools (Rope, Chain, Manacles) is one new `_add(...)` entry in `ItemsAutoload` per tool + one new `CaptureProfile.tres` per tool. Zero code changes.

---

## 9. Testing Notes — Trace of Net-throw-at-Mimic flow for code-reading verification

This trace is for Agent 3 to verify by reading the code alone (no editor required).

**Setup pre-conditions:**
1. Mimic spawned at arena init. Look at [ArenaSpawner.gd `spawn_initial_actors`](../Components/Arena/ArenaSpawner.gd) — the new `for i in range(mimic_count)` loop runs after goblin + goat spawns. `spawn_actor_at_tile("mimic", mimic_tile)` dispatches via `ActorFactory.spawn(&"mimic", arena, pos)`. The Mimic is registered at [ArenaSpawner.gd:43](../Components/Arena/ArenaSpawner.gd).
2. Mimic's MimicActor `_init()` sets `element_type = "mimic"` and `is_playable = false`. `_ready()` auto-creates `MimicData.new()` and sets faction to MONSTERS. So at world-time the Mimic has `_data: MimicData` and `element_type = "mimic"`.
3. Player selects Net from inventory. `ItemsAutoload.set_selected_weapon(net_weapon_data)` populates `selected_weapon`. The Net's `WeaponData.is_capture_tool = true` (parsed in `_parse_notes` from the new `"capture"` notes token) and `capture_profile_path = "res://Components/ActorComponents/CaptureProfiles/DefaultNet.tres"` (set in the new post-`_add` loop in `ItemsAutoload._init_weapons`).

**The throw:**
1. Player clicks. `WeaponComponent.attack_target(target_pos)` ([WeaponComponent.gd:213](../Components/WeaponComponents/WeaponComponent.gd)) → since `weapon_data.is_thrown == true` AND `current_ammo > 1` (Net has `max_ammo = 5` per the thrown-default in `_parse_notes`), calls `secondary_attack(target_pos, true)`.
2. `secondary_attack` → `_perform_attack(target_pos, true)` → since `is_secondary == true`, calls `_ranged_component.launch(target_pos, dir, true)`.
3. `RangedComponent.launch` ([RangedComponent.gd:26](../Components/WeaponComponents/RangedComponent.gd)) — `_weapon_data.name == "Net"`, `projectile_scene_path == ""`, no other branch matches, so `projectile_path` stays at the default `"res://scenes/projectiles/ArrowProjectile.tscn"`. The projectile is spawned, initialized with `damage = roll_damage()` (which returns 1 for the Net since `damage == "-"`), and crucially at line 102: `proj.source_weapon_data = _weapon_data` — the Net's WeaponData is attached.

**The hit:**
4. Projectile collides with Mimic. `BaseProjectile._on_body_entered(body: Mimic)` ([BaseProjectile.gd:234](../src/actors/projectiles/BaseProjectile.gd)) fires.
5. `if _is_stuck or body == caster: return` — false on first hit.
6. **NEW BRANCH:** `if source_weapon_data and source_weapon_data.is_capture_tool and body is Actor:` — all three true. Calls `_run_capture_flow(body as Actor)` then `queue_free()` and returns. The damage path below is skipped.

**The save:**
7. `_run_capture_flow(target: Mimic)`:
   - `target.is_dead == false` — continue.
   - `_load_capture_profile()` → loads `DefaultNet.tres` via `load(source_weapon_data.capture_profile_path)`, casts to `CaptureProfile`. Returns the loaded profile with `save_dc=12, stun_duration=4.0, catch_chance=0.4`.
   - `target.get_node_or_null("CaptureComponent")` → null (Mimic doesn't carry one by default).
   - Builds new `CaptureComponent`, sets `capture_profile = profile`, `target.add_child(...)`, calls `capture_comp.setup(target)`.
   - `can_be_captured()`: actor non-null, profile non-null, not dead, allowlist empty → returns true.
8. **Primitive 1 — `roll_save()`:** reads `target.ability_scores_component.dexterity` (MimicData default is `1.5`). Rolls `d20: int = randi() % 20 + 1`. `total = d20 + int(round(1.5))`. Prints e.g. `[Capture] Net hit Mimic. Save: rolled 8 vs DC 12 → FAIL`. Returns `total >= 12`.

**Branch A — save SUCCESS:** function returns; nothing else happens. The projectile is gone; the Mimic walks away.

**Branch B — save FAIL:**
9. **Primitive 2 — `apply_stun(4.0)`:** calls `target.stun(4.0)` → `Actor.stun` ([Actor.gd:409](../src/actors/base/Actor.gd)) → `StunComponent.stun(4.0)` sets `_stun_timer = max(_stun_timer, 4.0)`. The StunComponent's `_process(delta)` decrements; the Mimic AI's `MimicController` checks `actor.is_stunned()` (or upstream blockers in `WeaponComponent._can_attack` and movement) and idles.
10. **Primitive 3 — `roll_catch()`:** `randf()` rolled vs `0.4`. Prints e.g. `[Capture] Mimic stunned for 4.0s. Catch roll: 0.32 vs 0.40 → CAUGHT`. Returns `roll <= 0.4`.

**Branch B.1 — catch FAIL:** function returns. Mimic stays stunned for 4.0s, then recovers.

**Branch B.2 — catch SUCCESS:**
11. **`apply_capture()`:**
    - `_create_data_for_actor()` matches on `actor.element_type == "mimic"` → returns `MimicData.new()`.
    - `_populate_data_from_actor(new_data)`:
        - Reads `actor.ability_scores_component.strength/dex/con/int/wis/cha` and writes them to `new_data`.
        - Reads `actor._data.base_color / pattern_color` (non-null because MimicActor auto-creates MimicData) and writes them to `new_data`.
    - Resolves `/root/HerdManager`, calls `hm.add_goat(new_data)` → goes to `HerdComponent.add_goat`, appends to `herd: Array[ActorData]`. Save fires via `GameEvents.herd_updated`.
    - Prints `[Capture] Mimic added to herd as mimic`.
    - `actor.queue_free()` — NOT `actor.die()`. No fall-over visual, no `actor_died` signal, no inventory drop. Clean exit.

**Edge cases verified by reading the code:**
- Net hit on a goblin / farmer / fire / water: `_create_data_for_actor()` dispatches via `element_type` (set in each `_init()`). `_populate_data_from_actor` reads `ability_scores_component` for all six stats. Visuals are copied only if `actor._data != null` — for wild goblins/farmers/fire/water this is null today, so the captured creature gets the data subclass's default colors from `_init()`. Acceptable for v1.0.
- Net hit on a scarecrow: `element_type` doesn't match any branch in `_create_data_for_actor`, returns null. `apply_capture` prints failure and skips `add_goat`. Actor stays in world. (No `queue_free`.)
- Net hit on a friendly goat: dispatches via `element_type == "goat"` → `GoatData.new()`. **Note:** this means you can capture friendlies. Not gated this patch; document as known v1.0 limitation. Wild capture is the intended target; a `faction_component.faction != PLAYER` gate in `can_be_captured` is the natural place to add it.
- Net hit on a dead actor: `can_be_captured()` rejects via `actor.is_dead`.
- Net's projectile is `ArrowProjectile.tscn` fallback. Visually it's an arrow, not a net. Fixable later by setting `projectile_scene_path` on the Net's WeaponData entry; deferred since the user's discriminator test is the readout, not the visual.

---

## 10. Open Questions for Agent 3 (editor-verification candidates)

1. **Readout messages actually print.** The acceptance test hinges on these. Hard to verify without the editor — Agent 3 should code-read the format strings in `CaptureComponent.roll_save / roll_catch / apply_capture` and confirm the unicode `→` (U+2192), the `[Capture]` tag, and the exact phrasing match the user's spec. I matched verbatim during writing.
2. **`.tres` loads in editor.** The `DefaultNet.tres` script reference uses `path="res://Components/ActorComponents/CaptureProfile.gd"`. Godot 4 should resolve this even before `.gd.uid` is generated. If the editor refuses to load on first open, the fix is to open `CaptureProfile.gd` once so the uid is created, then update the `.tres` to use `uid="uid://..."` form.
3. **Mimic actually spawns.** `spawn_initial_actors()` is called from `Play Space/Arena.gd:74`. Verify the arena scene is loaded, that `mimic_scene = preload("res://scenes/actors/MimicActor.tscn")` resolves, and that `mimic_count = 1` exports correctly. The MimicActor.tscn must be a valid scene with a CollisionShape3D — verified to exist (Patch 1).
4. **Capture flow doesn't conflict with the Mimic's morph state.** If the Mimic is morphed at hit time, does `roll_save` use the Mimic's own `dexterity` or the morphed-into actor's? Code-read: morphing only swaps visuals (`CreatureMorphComponent.morph_into` calls `setup_visuals(target._data)`), not ability scores — so the Mimic always saves with its own dex. Correct.
5. **`stun()` doesn't break the AI permanently.** Verified by reading `StunComponent._process(delta)` — `_stun_timer` decrements every frame, and stun ends naturally. The MimicController's `_on_scan_tick` does NOT check `actor.is_stunned()` explicitly, but movement / attacks are blocked by other components, and the Mimic should resume normal behavior after the timer expires.

---

*End of Agent 2 Patch 3 implementation log.*
