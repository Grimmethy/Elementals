# Agent 3 — Patch 3 Verification Review

> Scope: independent code-read verification of Agent 2's minimum-viable Net
> catch + Mimic spawn wiring (Patch 3). Read-only pass — no edits made.
> All paths repo-relative unless absolute is needed for clarity.

---

## 1. Implementation Reviewed

| Path | Read | Verified |
|------|------|----------|
| `docs/AGENT_2_PATCH3_LOG.md` | yes | Agent 2 claims log |
| `Components/Arena/ArenaSpawner.gd` | full file | Part 1 — Mimic spawn |
| `Components/ActorComponents/CaptureComponent.gd` | full file | Part 2 — primitives + dispatch |
| `Components/ActorComponents/CaptureProfile.gd` | full file | Part 2 — resource shape |
| `Components/ActorComponents/CaptureProfiles/DefaultNet.tres` | full file | Part 2 — designer values |
| `Core/WeaponData.gd` | full file | Part 3 — `is_capture_tool` + parser |
| `Core/ItemsAutoload.gd` | full file | Part 3 — Net entry + profile path |
| `src/actors/projectiles/BaseProjectile.gd` | full file | Part 4 — combat flow |
| `Components/ActorComponents/StunComponent.gd` | full file | Part 5 — stun routing |
| `src/actors/base/Actor.gd:405–415` | snippet | `Actor.stun(duration)` exists |
| `Components/WeaponComponents/RangedComponent.gd:101–102` | grep | `source_weapon_data` set on projectile |
| `Components/WeaponComponents/WeaponComponent.gd:213–215` | grep | thrown → `secondary_attack` |
| `Components/ActorComponents/AbilityScoresComponent.gd:9–14` | grep | six ability fields are `@export` floats |
| `Components/BreedingComponents/HerdManager.gd:78–79` | snippet | `add_goat(actor: ActorData)` accepts any subclass |
| `Components/BreedingComponents/MimicData.gd:62` | snippet | `get_actor_type() -> "mimic"` |
| `Markdowns/Capture.md` | head 60 | Patch 3 implementation status documented |
| `Markdowns/Mimic.md` | head 60 | v1.1 bump documented |

Cross-codebase greps performed:
- `weapon.name == "Net"` / `weapon_data.name == "Net"` / `.name == "Net"` across all `.gd` → **1 hit**, in `ItemsAutoload.gd:128` (catalog post-`_add` profile-path setup loop). No behavior-gate hardcoding anywhere.
- `Timer.new(` / `create_timer(` inside the three new files and the modified `BaseProjectile.gd` → **0 functional hits**. Only one comment reference at `CaptureComponent.gd:105` ("NEVER `Timer.new()`, NEVER `create_timer()`") which is documentation, not code.

---

## 2. Discriminator Test — Readout Messages

The user's spec demands three readouts. Quoted directly from `CaptureComponent.gd`:

**`roll_save`** (lines 70–78):
```
"[Capture] Net hit %s. Save: rolled %d vs DC %d → %s (d20=%d + %s=%d)"
```
Renders as: `[Capture] Net hit Mimic. Save: rolled 11 vs DC 12 → FAIL (d20=9 + dexterity=2)` ✓ matches spec exactly, including unicode `→` (U+2192) and the `(d20=K + dexterity=M)` breakdown.

**`roll_catch`** (lines 95–101):
```
"[Capture] %s stunned for %.1fs. Catch roll: %.2f vs %.2f → %s"
```
Renders as: `[Capture] Mimic stunned for 4.0s. Catch roll: 0.32 vs 0.40 → CAUGHT` ✓ matches spec exactly.

**`apply_capture`** (lines 140–142):
```
"[Capture] %s added to herd as %s"
```
Renders as: `[Capture] Mimic added to herd as mimic` ✓ matches spec exactly.

All three readouts are emitted by `print()` (not `print_verbose`), so they surface in the editor's Output panel without config gating. The `[Capture]` tag is greppable, so a future UI panel can pipe it.

**Discriminator result: PASS.**

---

## 3. Mimic Spawn Verification (Part 1)

`Components/Arena/ArenaSpawner.gd`:
- Line 12: `mimic_scene: PackedScene = preload("res://scenes/actors/MimicActor.tscn")` — scene preloaded.
- Line 17: `@export_range(0, 10, 1) var mimic_count: int = 1` — designer-tunable, default 1. ✓ Matches spec.
- Line 43: `_actor_factory.register(&"mimic", mimic_scene)` (preserved from Patch 1).
- Lines 59–62 inside `spawn_initial_actors()`:
  ```
  for i in range(mimic_count):
      var mimic_tile: HexTileData = _get_random_spawn_tile()
      if mimic_tile:
          spawn_actor_at_tile("mimic", mimic_tile)
  ```
- Routes through the same `_get_random_spawn_tile + spawn_actor_at_tile` pipeline used for goblins (lines 47–50). ✓ no new spawn picker.
- Existing spawn counts preserved:
  - 1 goblin (lines 47–50) ✓
  - `random_wild_goat_count = 4` wild goats via `spawn_random_wild_goats` (line 53) ✓
  - Scarecrow via `spawn_scarecrow()` is still called elsewhere (existing call sites untouched).
  - Persistent player goats from HerdManager (lines 65–79) ✓.

No regression to existing spawn counts. Mimic seeding is purely additive.

---

## 4. CaptureComponent + CaptureProfile + DefaultNet.tres Verification (Part 2)

### `CaptureComponent.gd`
- `class_name CaptureComponent extends Node` ✓
- `@export var capture_profile: CaptureProfile` ✓
- `setup(p_actor: Actor)` line 32 ✓
- `can_be_captured()` line 39 — null/dead/allowlist gate ✓
- `roll_save(attacker_modifier: int = 0)` line 59 — d20 + modifier vs DC, prints readout ✓
- `roll_catch(attacker_modifier: int = 0)` line 86 — `randf()` vs `catch_chance`, prints readout ✓
- `apply_stun(duration)` line 109 — calls `actor.stun(duration)`. No `Timer.new`, no `create_timer`. ✓
- `apply_capture()` line 127 — `_create_data_for_actor()` dispatch, `_populate_data_from_actor`, `hm.add_goat(new_data)`, `actor.queue_free()`. Uses `queue_free` NOT `die()`. ✓ Per spec.
- `_create_data_for_actor()` lines 176–198 — dispatches on `actor.element_type`:
  - `"goblin"` → `GoblinData.new()` ✓
  - `"mimic"` → `MimicData.new()` ✓
  - `"fire"` → `ElementalData.new()` w/ `element_subtype = &"fire"` ✓
  - `"water"` → `ElementalData.new()` w/ `element_subtype = &"water"` ✓
  - `"farmer"` → `FarmerData.new()` ✓
  - `"goat"` → `GoatData.new()` ✓
  - `_:` → returns null (refuses to capture rather than push a base ActorData) ✓
- `_populate_data_from_actor` line 204 — copies six ability scores + visuals (when `_data` exists). ✓

### `CaptureProfile.gd`
- `class_name CaptureProfile extends Resource` ✓
- `@export var save_dc: int = 12` ✓
- `@export var save_ability: StringName = &"dexterity"` ✓
- `@export var stun_duration: float = 4.0` ✓
- `@export_range(0.0, 1.0, 0.05) var catch_chance: float = 0.4` ✓
- `@export var allowed_actor_types: Array[StringName] = []` ✓

### `DefaultNet.tres`
- Header: `[gd_resource type="Resource" script_class="CaptureProfile" load_steps=2 format=3]` ✓
- `script = ExtResource("1_capture")` resolves to `CaptureProfile.gd` ✓
- `save_dc = 12`, `save_ability = &"dexterity"`, `stun_duration = 4.0`, `catch_chance = 0.4`, `allowed_actor_types = []` ✓ all values per spec.

---

## 5. Net Data-Driven Wiring (Part 3)

### `Core/WeaponData.gd`
- Line 32: `@export var is_capture_tool: bool = false` ✓
- Line 38: `@export_file("*.tres") var capture_profile_path: String = ""` ✓
- Line 78 inside `_parse_notes()`: `is_capture_tool = "capture" in n` ✓ Additive — does NOT modify any other parser branches.

### `Core/ItemsAutoload.gd:126`
- Net entry now: `_add("Net", "1 gp", "-", "none", 3, "Thrown (range 5/15), capture", net_icon)`
- Notes string contains `"capture"` (not `"special"`) ✓
- Lines 127–130 post-`_add` loop:
  ```
  for w in weapons:
      if w.name == "Net":
          w.capture_profile_path = "res://Components/ActorComponents/CaptureProfiles/DefaultNet.tres"
          break
  ```
- Profile path correctly points to the `.tres` ✓

### Grep for hardcoded `"Net"` behavior gates
- Pattern `weapon\.name\s*==\s*[\"']Net[\"']|weapon_data\.name\s*==\s*[\"']Net[\"']|\.name\s*==\s*"Net"` across all `.gd` returns **1 hit**: `ItemsAutoload.gd:128` (catalog-setup loop). This is **not a behavior gate** — it's the data-population step. ✓ Net behavior is 100% data-driven via `is_capture_tool`.

---

## 6. Combat Flow Trace (Part 4)

Step-by-step verified by code reading:

1. **Player clicks with Net selected.** `WeaponComponent.attack_target(target_pos)` (line 213) detects `weapon_data.is_thrown == true` AND `current_ammo > 1` → returns `secondary_attack(target_position, true)`.
2. **`secondary_attack`** (line 235) → `_perform_attack(target_pos, true)` → with `is_secondary=true` calls `_ranged_component.launch(...)`.
3. **`RangedComponent.launch`** spawns the projectile and at line 102: `proj.source_weapon_data = _weapon_data`. The Net's `WeaponData` (with `is_capture_tool = true` and `capture_profile_path = DefaultNet.tres`) is carried on the projectile.
4. **Net projectile uses `ArrowProjectile.tscn` fallback** because `projectile_scene_path == ""` on the Net entry. Visually it appears as an arrow — Agent 2 documented this as a known v1.0 limitation.
5. **Collision: `BaseProjectile._on_body_entered(body)`** (line 234):
   - `_is_stuck` / `body == caster` guard (line 235).
   - **NEW BRANCH lines 242–245:** `if source_weapon_data and source_weapon_data.is_capture_tool and body is Actor:` → calls `_run_capture_flow(body as Actor)`, then `queue_free()`, then `return`. The damage / `_stick` flow below is skipped entirely. **No double-fire.** ✓
6. **`_run_capture_flow(target)`** (line 268):
   - Dead-target guard (line 269).
   - `_load_capture_profile()` (line 310) → `load(source_weapon_data.capture_profile_path) as CaptureProfile` → returns DefaultNet profile.
   - Lazy-attach: `target.get_node_or_null("CaptureComponent")` → null on first hit → builds new `CaptureComponent`, sets `capture_profile = profile`, adds as child, calls `setup(target)` (lines 275–281).
   - Existing-component branch (lines 282–286) swaps the profile to the tool's — sensible behavior for the future when designers preinstall components.
   - `can_be_captured()` check (line 288).
   - **Primitive 1: `roll_save()`** (line 293) — prints save readout. If SUCCESS, returns.
   - **Primitive 2: `apply_stun(profile.stun_duration)`** (line 298) — routes through `Actor.stun(4.0)` → `StunComponent.stun(4.0)`.
   - **Primitive 3: `roll_catch()`** (line 301) — prints catch readout.
   - On catch SUCCESS: `apply_capture()` (line 303) — builds matching `*Data`, populates from actor's ability scores, calls `hm.add_goat(new_data)`, prints "added to herd" readout, calls `actor.queue_free()`.

**Flow trace: PASS.** Every step is reachable, no dead branches, no double-fire, capture-tool branch correctly skips damage path.

---

## 7. Stun Routing (Part 5)

- `CaptureComponent.apply_stun()` lines 109–113 calls `actor.stun(duration)` and nothing else. No `Timer.new()`, no `create_timer()`. ✓
- `Actor.stun()` at `src/actors/base/Actor.gd:409`: `if stun_component: stun_component.stun(duration)` — single-line passthrough. ✓
- `StunComponent.stun()` at `Components/ActorComponents/StunComponent.gd:27` sets `_stun_timer = max(_stun_timer, duration)`. Decrement happens in `_process(delta)` (lines 24, 36–47). **No `Timer.new`, no `create_timer`.** ✓
- Grep across the new + modified files for `Timer\.new\(\)|create_timer\(` → 0 functional matches. Only the documentation comment at `CaptureComponent.gd:105`.

**Stun routing: PASS.** Pure GameClock-friendly `_process`-driven decrement; no anti-patterns introduced.

---

## 8. Anti-Pattern Audit (Red Flags)

| Red flag | Status | Notes |
|---|---|---|
| `Timer.new()` introduced | **CLEAN** | 0 functional matches in patch files. |
| `await get_tree().create_timer()` introduced | **CLEAN** | 0 matches in patch files. |
| Hardcoded `weapon.name == "Net"` behavior gate | **CLEAN** | Only hit is the catalog-setup loop in `ItemsAutoload.gd:128`, which populates `capture_profile_path` — data setup, not behavior gate. |
| Double-fire (damage AND capture) | **CLEAN** | `BaseProjectile._on_body_entered:242–245` early-returns after capture flow + `queue_free()`. Damage path at line 247+ is unreachable for capture-tool projectiles. |
| `actor.die()` inside `apply_capture()` | **CLEAN** | Uses `actor.queue_free()` per spec (line 145). Comment at 123–126 documents the deliberate choice. |
| New `Array[GoblinData]` or other typed-subclass array | **CLEAN** | `HerdManager.add_goat(actor: ActorData)` accepts the polymorphic supertype. No new typed-subclass arrays introduced. |
| Per-frame distance math in capture handling | **CLEAN** | All capture logic runs on collision events (`_on_body_entered`), not per-frame. |
| Mimic spawn regression on other counts | **CLEAN** | Goblin (1), goat (4), scarecrow, persistent goats — all preserved. Mimic added below the goblin loop. |
| Readouts that don't fire | **CLEAN** | All three readouts use unconditional `print()` inside reachable code paths. Verified the format strings render correctly with sample args. |

---

## 9. Doc Updates Verified

- `Markdowns/Capture.md` — lines 1–35 contain a clearly-labeled "**IMPLEMENTATION STATUS (Patch 3 — Minimum Viable Net Catch):**" block. Lists the three primitives, the lazy-attach behavior, the data-driven profile path, and explicitly calls out what's deferred (ActorState, restraint stacking, drag, taming, ropes/chains/manacles/traps). ✓
- `Markdowns/Mimic.md` — header bumped to `v1.1 (Patch 3 — spawn-on-arena + capturable via Net)`. Patch 3 additions documented (lines 10–20), including the explicit note about `queue_free` vs `die()`. ✓
- `Markdowns/Abilities.md` / `Markdowns/UI.md` — not touched. Not required by this patch — no new abilities, no new UI surfaces. ✓

---

## 10. Performance / Resource Impact

- **Mimic spawn at arena init.** Single instantiation through the existing `ActorFactory.spawn` pipeline. Trivial — same cost as the existing single-goblin spawn that's been running since Patch 1.
- **Lazy `CaptureComponent` attach at hit time.** Allocates one `CaptureComponent` node + one `load(DefaultNet.tres)` Resource per capture-tool hit. Net throws are low-rate (≤ 5 max ammo, ≤ ~1/sec cooldown), so allocation pressure is negligible. Acceptable for v1.0.
- **`load(profile_path)`** on every capture-tool hit. Godot caches loaded resources, so subsequent loads are near-free. Future optimization: cache the loaded profile on the WeaponData itself (one-line change later if measured as hot).
- **Existing damage flow for non-capture weapons.** Verified via the BaseProjectile early-return: `is_capture_tool` defaults to `false` on every other weapon (no parser change for non-capture notes). Damage path at line 247+ runs unchanged for arrows / daggers / spears / etc.
- **StunComponent decrement** runs in `_process(delta)` once per stunned actor — already in the budget pre-patch.

No regressions identified.

---

## 11. Known v1.0 Limitations Agent 2 Documented

Faithfully preserved from `AGENT_2_PATCH3_LOG.md` §9:
1. **Net visual is an arrow.** `projectile_scene_path` on the Net entry is `""` so it falls back to `ArrowProjectile.tscn`. The hit/save/catch flow works; only the in-flight visual is wrong. Fixable later by setting the path on the Net's WeaponData entry.
2. **Default colors on captured wild creatures.** Wild goblins/farmers/fire/water carry `_data == null` in-world, so `_populate_data_from_actor` skips the visual copy (line 214). The captured creature inherits the subclass's `_init()` defaults rather than the live actor's visuals. Acceptable for v1.0; fix is to seed `_data` at spawn time (option (a) from the earlier plan).
3. **No friendly-faction gate.** `can_be_captured()` does not check faction. You can capture friendly goats and farmers. Per the log: the fix is a `faction_component.faction != PLAYER` check inside `can_be_captured` — natural extension point.
4. **Scarecrows: `_create_data_for_actor` returns null** → `apply_capture` prints "Failed to create data resource" and skips `add_goat`. The actor stays in the world — no `queue_free`. Expected behavior, but worth knowing.
5. **No UI feedback yet.** All capture outcomes are console-only. The `[Capture]` tag is greppable for a future panel.

---

## 12. Tests Performed by Code Reading

| Test | Method | Result |
|---|---|---|
| Mimic spawns at arena init | Read `ArenaSpawner.spawn_initial_actors` | PASS — `mimic_count`-loop reachable after goblin/goat spawns |
| Net carries `is_capture_tool == true` after parse | Read `WeaponData._parse_notes` + `ItemsAutoload` Net notes | PASS — `"capture"` literal in notes flips the flag |
| Net carries `capture_profile_path` set to DefaultNet | Read `ItemsAutoload._init_weapons:127–130` post-`_add` loop | PASS |
| Projectile carries `source_weapon_data` to hit handler | Read `RangedComponent.launch:101–102` | PASS |
| Capture-tool early-return in `_on_body_entered` | Read `BaseProjectile.gd:242–245` | PASS — branch returns before damage path |
| `_run_capture_flow` lazily attaches `CaptureComponent` | Read `BaseProjectile.gd:275–281` | PASS — null check + `add_child` + `setup` |
| `roll_save` prints readout in exact spec format | Read `CaptureComponent.gd:70–78` | PASS — matches `[Capture] Net hit %s. Save: rolled %d vs DC %d → %s (d20=%d + %s=%d)` |
| `roll_catch` prints readout in exact spec format | Read `CaptureComponent.gd:95–101` | PASS |
| `apply_capture` prints readout + calls `add_goat` + `queue_free` | Read `CaptureComponent.gd:127–145` | PASS — uses `queue_free`, NOT `die()` |
| `apply_stun` routes through `Actor.stun → StunComponent` | Read all three files | PASS — no `Timer.new`, no `create_timer` |
| Dispatch covers goblin/mimic/fire/water/farmer/goat | Read `_create_data_for_actor:176–198` | PASS — all 6 keys present |
| No hardcoded `weapon.name == "Net"` behavior gate | Grep `.gd` corpus | PASS — only catalog setup hit |
| Existing damage path unchanged for non-capture weapons | Read `BaseProjectile._on_body_entered:247+` | PASS — branch reachable only when `is_capture_tool == false` |

---

## 13. Tests Still Needed (Godot Editor)

1. **DefaultNet.tres loads on first open** without `.gd.uid` errors. The script reference uses `path="res://Components/ActorComponents/CaptureProfile.gd"`. Godot 4 should resolve this; if it doesn't, open `CaptureProfile.gd` once in the editor to generate the uid, then optionally switch the `.tres` to a `uid://` reference.
2. **Mimic actually appears on arena spawn.** Verify the `mimic_scene` preload resolves and `MimicActor.tscn` is structurally valid (CollisionShape3D, _data preset).
3. **Throw a Net at the Mimic** and confirm all three console readouts appear in the Output panel with the exact format strings quoted in §2.
4. **Catch success path** — confirm the Mimic disappears (no fall-over) and appears in HerdManager (open the Ranch UI / inspector to verify the herd array grew).
5. **Catch failure path** — confirm the Mimic stays stunned for 4 seconds, then resumes wandering / target-scanning.
6. **Save success path** — confirm the Mimic is unharmed and continues normally; only one readout line prints.
7. **Net thrown at a non-target (scarecrow)** — confirm "Failed to create data resource" prints and the scarecrow remains in the world.
8. **Edge: Net thrown at a friendly goat / farmer** — confirm it captures (known v1.0 limitation; verify the behavior so we know what to gate next patch).
9. **Net visual is still an arrow** (documented limitation) — confirm by observation.

---

## 14. Final Recommendation

**SAFE TO CONTINUE.** Patch 3 implements exactly what the user spec asked for, with no anti-patterns and clean documentation. The three readouts will fire in the spec'd format, the Mimic will spawn on arena init, and the data-driven design leaves clear extension hooks for the full Capture patch.

**Top 3 things the human must verify in-editor:**
1. Open the Arena scene → confirm a Mimic (violet sphere) is walking around at start.
2. Throw a Net at it → confirm the exact `[Capture] Net hit Mimic. Save: rolled N vs DC 12 → ...` readout appears in the Output panel, with subsequent stun + catch lines on save fail.
3. On catch success → confirm the Mimic disappears cleanly (no fall-over) and shows up in the HerdManager (Ranch UI or print(`HerdManager.herd`) snapshot).

If all three check out, ship and proceed to Patch 4 (ProgressionComponent generalization, sell_goat polymorphism, die() hooks, GoatRenderer rename).
