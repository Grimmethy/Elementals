# Procedural Character Framework (PCF)

<!--
Document Version: 2.1
Status: ACTIVE DEVELOPMENT — Phases 1–12 + Game Integration + Ragdoll complete
Last Updated: 2026-05-25
-->

> **What this is:** A fully code-driven character body system for Godot 4. No external mesh files, no AnimationPlayer, no keyframes. Characters are defined by `CreatureDefinition` Resource files and assembled + animated entirely at runtime from GDScript.

---

## Implementation Status

### ✅ Completed

| Phase | What | Key Files |
|-------|------|-----------|
| 1 | `CreatureDefinition` resource | `core/creature_definition.gd` |
| 2 | LimbBuilder geometry | `core/shape_assembler.gd` (folded in) |
| 3 | TorsoBuilder + HeadBuilder | `core/shape_assembler.gd` (folded in) |
| 4 | ShapeAssembler + BoneAnchor | `core/shape_assembler.gd`, `core/bone_anchor.gd` |
| 5 | CreatureGenerator | `core/creature_generator.gd` |
| 6 | SkeletonInferer | `core/skeleton_inferer.gd` |
| 7 | Editor Plugin + Inspector buttons | `plugin.gd`, `editor/creature_inspector_plugin.gd` |
| 8 | Gizmo overlay | `editor/creature_gizmo_plugin.gd` |
| 9 | Locomotion (procedural walk) | `core/locomotion_controller.gd` |
| 10 | Secondary motion (spring-damper) | `core/secondary_motion_controller.gd` |
| 11 | Serializer (save / load / variant) | `core/creature_serializer.gd` |
| 12 | Breeder (offspring definitions) | `core/creature_breeder.gd` |
| — | CharacterBody3D demo | `demo/creature_character.gd`, `demo/test_character_scene.tscn` |
| — | FarmerActor integration | `scenes/actors/FarmerActor.tscn`, `src/actors/types/FarmerActor.gd` |
| — | Ragdoll death effect | `core/ragdoll_controller.gd` |

### 🔲 Not Yet Built

| What | Notes |
|------|-------|
| Foot IK / terrain-conforming steps | Planned Phase 13 |
| MimicData visual bridge | PCF body for Mimic creatures |
| Quadruped body plan | ShapeAssembler only handles BIPED today |
| Vertex-color zones | Belly lighter than back, etc. — no UV/texture needed |
| Additive combat pose offsets | On top of locomotion, distinct from ragdoll |
| Distance-based LOD auto-switching | CreatureManager singleton idea |
| CharacterDesignerDock (full slider UI) | Inspector buttons exist; full panel not built |
| Drag handles in viewport | Gizmo draws overlay; handles not interactive yet |

---

## Actual File Structure

```
res://
├── addons/procedural_creature/
│   ├── plugin.cfg
│   ├── plugin.gd                          ← EditorPlugin entry point
│   ├── core/
│   │   ├── creature_definition.gd         ← Data model (Resource)
│   │   ├── bone_anchor.gd                 ← Joint marker node
│   │   ├── shape_assembler.gd             ← Builds the full biped scene tree
│   │   ├── skeleton_inferer.gd            ← Walks BoneAnchor tree → Skeleton3D
│   │   ├── creature_generator.gd          ← @tool orchestrator node
│   │   ├── locomotion_controller.gd       ← Procedural walk animation
│   │   ├── secondary_motion_controller.gd ← Spring-damped head/neck/breath
│   │   ├── creature_serializer.gd         ← Save / load / validate / variant
│   │   ├── creature_breeder.gd            ← Cross two definitions → offspring
│   │   ├── ragdoll_controller.gd          ← Simulated bone ragdoll on death
│   │   └── debug_colors.gd               ← Per-body-part colour palette
│   ├── editor/
│   │   ├── creature_inspector_plugin.gd   ← Adds LOD buttons to Inspector
│   │   └── creature_gizmo_plugin.gd       ← Skeleton overlay in 3D viewport
│   └── icons/
│       └── creature_generator.svg
│
├── creatures/
│   └── definitions/
│       └── humanoid_base.tres             ← Default humanoid definition
│
└── demo/
	├── creature_character.gd              ← Reusable CharacterBody3D controller
	├── test_character_scene.gd            ← Follow-camera root script
	├── test_character_scene.tscn          ← Full playable demo (F6)
	├── test_locomotion_scene.tscn         ← Locomotion in-place test
	├── test_serializer_scene.tscn         ← Save/load/validate test
	├── test_breeder_scene.tscn            ← Offspring breeding test
	└── [other phase test scenes]
```

---

## Architecture Overview

```
CreatureDefinition.tres   ← the only shared surface between editor and runtime
		│
		▼
CreatureGenerator  (@tool Node3D)
		├── ShapeAssembler.assemble()   → builds _CreatureRig (Node3D subtree)
		│       └── BoneAnchor nodes, each with MeshInstance3D children
		├── SkeletonInferer.infer()     → walks BoneAnchors → Skeleton3D
		└── emits rebuilt signal
				│
				├── LocomotionController      (sibling Node, reads rebuilt signal)
				├── SecondaryMotionController (sibling Node, reads rebuilt signal)
				└── RagdollController         (sibling Node, inactive until die())
```

### Key Constraint: BoneAnchor, not Skeleton3D

The mesh segments are **children of BoneAnchor nodes**, not skinned vertices. `Skeleton3D.set_bone_pose_*()` only affects skinned mesh vertices — it has zero effect on scene-tree children. All animation (locomotion + secondary motion) drives **BoneAnchor transforms directly**. The `Skeleton3D` exists for future skinning work (Phase 12+) but is not the animation target today.

---

## Data Model — CreatureDefinition

A plain Godot `Resource` with `@export` properties. No logic. Saved as `.tres`.

| Group | Properties |
|-------|-----------|
| **Proportions** | `torso_height`, `torso_width`, `torso_depth`, `limb_thickness`, `arm_length`, `leg_length`, `head_scale` |
| **Posture** | `spine_bend`, `neck_angle`, `shoulder_droop` (degrees; can be negative) |
| **Head** | `head_shape` enum, `snout_length`, `eye_size`, `eye_spacing`, `jaw_width` |
| **Extras** | `has_tail`, `tail_segments`, `tail_length`, `has_wings`, `horn_count` |
| **Appearance** | `body_color`, `accent_color`, `eye_color`, `roughness` |
| **Animation** | `walk_speed`, `bounce_amount`, `secondary_motion_strength`, `step_height` |
| **Detail** | `detail_level` (SIMPLE / MODERATE / COMPLEX), `body_plan` (BIPED / …) |

---

## Bone Hierarchy (BIPED)

```
Hips  (BoneAnchor, y = leg_length)
├── Midriff  (BoneAnchor)
│   └── Chest  (BoneAnchor)
│       ├── Neck  (BoneAnchor)
│       │   └── Head  (BoneAnchor)
│       ├── ShoulderL  (BoneAnchor, rotation.z = π  ← hangs down)
│       │   └── UpperArmL → ForearmL → HandL
│       └── ShoulderR  (BoneAnchor, rotation.z = π)
│           └── UpperArmR → ForearmR → HandR
├── HipJointL  (BoneAnchor, rotation.z = π  ← hangs down)
│   └── ThighL → ShinL → FootL
└── HipJointR  (BoneAnchor, rotation.z = π)
	└── ThighR → ShinR → FootR
```

**Rotation convention (critical):**
- Spine bones have **identity** rest rotation: `rotation.x > 0` = lean forward ✓
- Shoulder/HipJoint bones have `rotation.z = PI` rest: their local +Y points world −Y so limbs hang down naturally. Consequence: `rotation.x > 0` on these bones = limb swings **backward**; `rotation.x < 0` = forward.

---

## Locomotion Controller

Drives BoneAnchor transforms each frame from a single phase scalar.

```
speed = velocity.length()
phase += delta * TAU * def.walk_speed * 1.4   ← 1.4 strides/sec at walk_speed=1
blend = lerp(blend, clamp(speed/walk_speed, 0,1), delta * 8)

Hips.position.y  = leg_length + cos(phase*2) * bounce * blend
Hips.position.x  = sin(phase) * bounce * 0.6 * blend

HipJointL.rotation.x = sin(phase)     * 0.28 * blend
HipJointR.rotation.x = sin(phase+PI)  * 0.28 * blend
ShoulderL.rotation.x = sin(phase+PI)  * 0.35 * blend   ← opposite leg
ShoulderR.rotation.x = sin(phase)     * 0.35 * blend
Head.rotation.x      = sin(phase*2)   * 0.04 * blend   ← nod at 2× stride
Chest.rotation.x     = lean                             ← forward tilt from speed
```

**Owns only the X axis on every bone** — leaves Y and Z free for SecondaryMotionController.

---

## Secondary Motion Controller

Spring-damper secondary motion layered on top. **Owns only Y and Z axes** — no conflict with LocomotionController.

| Bone | Axis | Effect |
|------|------|--------|
| Chest | Z | Idle breath — always active, even when standing still |
| Head | Y | Yaw lag — head momentarily faces old direction on turns |
| Head | Z | Roll lag — head tilts into lateral acceleration |
| Neck | Z | Follows head roll at half amplitude |

Velocity is auto-synced from a sibling `LocomotionController` — no manual wiring needed. Converts world velocity to generator-local space so lag is correct regardless of which way the generator faces.

**Spring class (inner):** `tick(target, stiffness, damping, dt) -> float` — simple critically-underdamped spring-damper.

---

## Serializer — CreatureSerializer

Static utility class (no scene tree node needed).

| Method | Returns | Notes |
|--------|---------|-------|
| `validate(def)` | `Array[String]` | Empty = clean. Checks enums, positive floats, roughness ∈ [0,1], tail coherence |
| `save(def, path)` | `Error` | Validates first — refuses if any errors. Auto-creates directories |
| `load(path)` | `CreatureDefinition?` | Type-checks, non-fatal validation warnings, returns null on failure |
| `create_variant(base, overrides)` | `CreatureDefinition` | `duplicate_definition()` + applies property dict; warns on unknown keys |

---

## Breeder — CreatureBreeder

Static utility. Takes two parent definitions and returns an offspring definition. No save — call `CreatureSerializer.save()` separately.

| Property type | Inheritance rule |
|---------------|-----------------|
| `float` (positive) | Average × `randf_range(1 ± jitter)`, floor-clamped to 0.01 |
| `float` (free sign) | Same, no floor — for posture angles that can be negative |
| `Color` | `lerp` at random weight + rare single-channel spike at high mutation |
| `int` | 50/50 pick from one parent, rare ±1 nudge, range-clamped |
| `enum` | 50/50 pick, rare full re-roll within valid range |
| `bool` | 50/50 pick, rare flip |
| `detail_level` | Not bred — inherits parent_a's value |

`mutation_strength` scales all jitter and mutation probabilities: `0.0` = pure blend, `1.0` = natural, `2.0` = wild/feral.

**Integration with ActorData breeding:**
```gdscript
# Game layer: handles stats / gold / mimic_blood / gender
var kid_data := goat_a.create_offspring(goat_b)

# PCF layer: decides what the kid looks like
var kid_def  := CreatureBreeder.breed(goat_a.definition, goat_b.definition)

# Spawn
creature_generator.definition = kid_def
```

---

## Ragdoll Controller

Simulates physical death collapse without a real physics rig. Lives as a sibling `Node` inside `CreatureGenerator`, inactive until `activate()` is called.

**Settle condition:** all bones at rest **AND** host `CharacterBody3D.is_on_floor()`. This maps directly to "becomes still when it reaches the ground." Hard timeout: **1 second** (safety net for edge cases).

**Per-frame simulation per bone:**
```
ang_vel.x  += gravity_bias * delta     ← per-bone "weight" droop
ang_vel    -= ang_vel * DAMPING * delta ← exponential drag (2.5/s ≈ 92% loss/s)
anchor.rotation += ang_vel * delta
anchor.rotation  = clamp(rotation, -TAU, TAU)  ← prevent runaway spin
```

**Per-bone gravity bias (local X, rad/s²):**

| Bone | Bias | Reason |
|------|------|--------|
| Hips | 0.0 | Position handled by CharacterBody3D |
| Midriff / Chest | +1.0 – +1.2 | Spine slumps forward |
| Head | +1.8 | Heaviest — drops furthest |
| Neck | +0.6 | Follows head |
| ShoulderL/R | −1.2 | PI-rest: negative = arm drops outward |
| ForearmL/R | −1.8 | Forearm droops past shoulder |
| HipJointL/R | +0.6 | Legs sprawl |
| ShinL/R | +0.8 | Shins follow thighs |

**Initial impulse:** each bone receives `randf_range(-1, 1)` on X, `±0.3` on Y, `±0.8` on Z, all multiplied by `impulse_strength` (default 1.5). This makes every death pose unique.

**Public API:**

| Method | Notes |
|--------|-------|
| `activate(impulse_strength, host)` | Gathers BoneAnchors, fires impulse, starts `_process`. `host` = CharacterBody3D for floor check |
| `freeze()` | Stops simulation, holds current pose, emits `settled` |
| `is_settled` | Bool — true after freeze() |
| `settled` signal | Fired once when the body comes to rest |

---

## Game Integration — FarmerActor

The first live in-game use of PCF. The Farmer NPC now has a 3D procedural body instead of a billboarding 2D sprite.

**Changes made:**

`scenes/actors/FarmerActor.tscn`
- `Body` (AnimatedSprite3D) → `visible = false`
- Added `CreatureGenerator` (with `humanoid_base.tres`) + `LocomotionController` + `SecondaryMotionController` + `RagdollController`

`src/actors/types/FarmerActor.gd`
- `_physics_process` override: after `super()` runs `move_and_slide()`, passes post-collision velocity to `LocomotionController` and smooth-rotates the generator to face movement direction. When `is_dead` and the ragdoll is active, manually applies gravity and calls `move_and_slide()` so the body falls to the floor before settling.
- `die()` override: zeros and disables walk controllers; re-enables the collision shape (see Challenge 7); activates `RagdollController`; tweens generator 90° on Z (body tips over). Connects `RagdollController.settled` (one-shot) to disable the collision shape once the body has come to rest.

**How it plugs in — alive:**
```
ArenaSpawner → instantiates FarmerActor.tscn → CharacterBody3D
  MovementComponent sets velocity each frame
  Actor._physics_process calls move_and_slide()
  FarmerActor._physics_process (override) then:
    → loco.velocity = velocity         (drives walk animation)
    → generator rotates to face vel    (drives facing direction)
```

**How it plugs in — death:**
```
health_component.health_depleted → FarmerActor.die()
  super.die() → is_dead = true, _disable_living_components()
  collision re-enabled (deferred, overrides the disable above)
  _loco.enabled = false   → walk cycle stops
  _secondary.enabled = false
  _ragdoll.activate(1.5, self) → bone impulse simulation starts
  tween generator rotation.z → PI/2 over 0.8s  (body tips over)

Per-frame while ragdoll is active:
  FarmerActor._physics_process applies gravity + move_and_slide()
  RagdollController._process drives BoneAnchor rotations
  → bones flail under impulse + gravity torque + damping

When angular vels < threshold AND is_on_floor():
  _ragdoll.freeze() → settled signal
  _on_ragdoll_settled() → collision.set_deferred("disabled", true)
  (or hard stop after 1 s timeout)
```

---

## Key Challenges & Solutions

### 1. Skeleton3D drives nothing visible
**Problem:** Implemented locomotion using `Skeleton3D.set_bone_pose_rotation()`. No visual change. Spent time debugging.

**Root cause:** `Skeleton3D.set_bone_pose_*()` only deforms *skinned* mesh vertices. Our `MeshInstance3D` segments are **children of BoneAnchor nodes** in the scene tree — they are NOT skinned to the Skeleton3D. Driving skeleton poses had zero visual effect.

**Fix:** Rewrote `LocomotionController` to drive `BoneAnchor.rotation` and `BoneAnchor.position` directly. MeshInstance3D children follow through normal parent-child transform propagation.

**Lesson:** In this architecture, the Skeleton3D is a future concern (for skinned meshes). Today's visual animation is purely scene-tree parenting.

---

### 2. Timing: rebuilt signal fires before scene root _ready
**Problem:** `CreatureGenerator._ready()` fires (and emits `rebuilt`) before the test scene root's `_ready()` runs — Godot fires children's `_ready()` before parents'. The test script connected to `rebuilt` after it had already fired.

**Fix:** Added an explicit `_print_skeleton(generator.get_skeleton())` call in `_ready()` after connecting the signal, in addition to the signal for future rebuilds.

**Lesson:** When connecting to signals in parent `_ready()`, always assume the signal may have already fired once. Read the current state explicitly after connecting.

---

### 3. Limb swing direction inverted on PI-rest bones
**Problem:** ShoulderL and HipJointL bones have `rotation.z = PI` so they hang down by default. This means their local +Y points world −Y. Applying `rotation.x = sin(phase)` caused the limb to swing the wrong direction relative to world space.

**Fix:** The PI-rest is intentional — `rotation.x > 0` on these bones swings the limb *backward* (which is correct for the back half of a stride). The forward swing is `rotation.x < 0`. Arms and legs are offset by PI from each other to create the contralateral gait pattern.

**Lesson:** Document the rotation convention prominently. It is non-obvious and causes bugs whenever a new developer (or AI session) touches the bone animation code.

---

### 4. Walk animation persisted after death
**Problem:** After the farmer died, `_disable_living_components()` disabled `MovementComponent` and stopped `move_and_slide()` — but `LocomotionController` kept running in its own `_process`. The `velocity` field was never cleared, so `_walk_blend` held at full and the creature kept animating indefinitely.

**Root cause:** `Actor._disable_living_components()` has no knowledge of PCF controllers. They're not in the list.

**Fix:** Override `die()` in `FarmerActor`:
1. `_loco.velocity = Vector3.ZERO` + `_loco.enabled = false` — stops the walk cycle immediately
2. `_secondary.enabled = false` — stops spring updates
3. Tween `_generator.rotation.z` to `PI/2` — falls over sideways in 0.5s

---

### 5. Fall-over animation played on hidden sprite
**Problem:** The original fall-over was `visual_component.fall_over()` which animates the `AnimatedSprite3D`. We hid that sprite — so the farmer "died" but the 3D body stayed upright.

**Fix:** Same `die()` override as above. The 3D body falls via a Tween, keeping the sprite-based visual_component for other side effects (stealth alpha fades, etc.) that still reference the hidden sprite node.

---

### 6. Ragdoll falls through floor — collision shape disabled by _disable_living_components
**Problem:** `Actor._disable_living_components()` calls `collision.set_deferred("disabled", true)`. With no capsule, `is_on_floor()` always returns false and `move_and_slide()` has nothing to collide with — the actor falls into infinity during the ragdoll.

**Root cause:** The base class disables the collision shape as a reasonable cleanup step. It can't know a ragdoll needs physics to keep running.

**Fix:** Immediately after `super.die()`, queue a counter-deferred call `collision.set_deferred("disabled", false)`. Because `set_deferred` calls execute in queue order, the `false` call lands after the `true` call and wins, leaving the shape active. When the ragdoll's `settled` signal fires, `_on_ragdoll_settled()` disables it for real.

**Lesson:** `set_deferred` calls are FIFO within a frame — you can reliably cancel an earlier queued call by immediately queueing the inverse.

---

### 7. Inspector rebuilt signal timing in editor
**Problem:** In `@tool` mode, `CreatureGenerator` rebuilds on property change. But calling `rebuild()` inside `set_detail_level()` while the editor is running caused occasional double-rebuilds and orphaned nodes.

**Fix:** Used `is_node_ready()` guard before calling `rebuild()` from the definition setter. Added `call_deferred` for the signal emission to avoid mutating the scene tree mid-frame in `@tool` context.

---

## Rotation Convention Reference

This burns people repeatedly. Pinning it here.

```
Spine bones (Midriff, Chest, Neck, Head) — rest rotation = IDENTITY
  rotation.x > 0  →  +Y tips toward +Z  →  FORWARD lean  ✓

Limb root bones (ShoulderL/R, HipJointL/R) — rest rotation.z = PI
  Local +Y points WORLD −Y (hanging down)
  rotation.x > 0  →  limb tip moves toward world −Z  →  BACKWARD swing
  rotation.x < 0  →  limb tip moves toward world +Z  →  FORWARD swing

Natural gait (right-hand contralateral):
  HipJointL  = sin(phase)        ← left leg
  HipJointR  = sin(phase + PI)   ← right leg, opposite
  ShoulderL  = sin(phase + PI)   ← left arm swings with right leg
  ShoulderR  = sin(phase)        ← right arm swings with left leg
```

---

## Open Questions / Remaining Work

### High Priority
- [ ] **Foot IK** — raycasts below each foot → spring-smoothed step targets that conform to terrain height. Currently feet float or clip through slopes.
- [ ] **MimicData visual bridge** — factory that reads a `MimicData` genome and produces a `CreatureDefinition`, so Mimics use the PCF body generator.
- [ ] **Resurrect / respawn pose reset** — `Actor.resurrect()` doesn't notify PCF controllers. Generator stays fallen and ragdoll remains frozen after a resurrect. Need to reset generator rotation and call `_ragdoll.freeze()` / `_loco.enabled = true` in a `resurrect()` override.

### Medium Priority
- [ ] **Other actor types** — GoatActor, GoblinMinion need the same treatment as FarmerActor (generator + velocity sync + death handling).
- [ ] **Walk speed tuning per actor** — `humanoid_base.tres` has `walk_speed = 1.0` but the Farmer moves at `3.0 m/s`. The animation phase tempo should scale to actual movement speed to avoid the sliding/moonwalk effect.
- [ ] **CharacterDesignerDock** — full slider panel in the Godot editor for live authoring without editing `.tres` files by hand.
- [ ] **Interactive viewport handles** — current gizmo draws overlay lines only; drag handles not yet implemented.

### Low Priority / Future
- [ ] Quadruped body plan
- [ ] Vertex color zones (belly/back gradient)
- [ ] Distance-based auto LOD switching
- [ ] Additive combat/state pose offsets
- [ ] Cloth/cape simulation via extended JiggleSolver
- [ ] SIMPLE-level `MultiMeshInstance3D` for crowd instancing

---

## Design Principles (Still Holds)

- **Zero art assets** — all geometry via `SurfaceTool` / `ArrayMesh`
- **Flat shading** — normals computed per-face; never call `calculate_normals()`
- **Data-driven** — every character is a `.tres` file; the generator reads, never hardcodes
- **No AnimationPlayer, no keyframes** — all motion is math in `_process()`
- **Two controllers, zero conflict** — LocomotionController owns X axes; SecondaryMotionController owns Y and Z axes. They can run in any order.
- **Editor plugin is optional** — deleting `editor/` has zero runtime impact; they share only `CreatureDefinition`
