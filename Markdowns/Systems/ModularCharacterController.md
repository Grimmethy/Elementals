# Modular Character Controller

## Overview

The Modular Character Controller decouples **control scheme logic** from the `ActorController` base class. Currently `ActorController._handle_controlled_input()` is hardcoded to a single top-down twin-stick style. This system replaces that with a swappable **`ControllerMode`** resource that can be hot-swapped at runtime, allowing the same actor to be driven by any of four distinct control paradigms.

The `PlayerInputComponent` (Arena action layer — attacks, abilities, cycling patterns) is intentionally kept separate. Controller modes handle **movement and orientation** only; `PlayerInputComponent` continues to handle **combat actions** and delegates aiming to the active mode's `get_aim_target()` method.

---

## 1. Architecture

### Strategy Pattern via GDScript Resources

Each mode is a `ControllerModeBase` resource. `ActorController` holds a reference to the active mode and delegates movement and orientation decisions to it.

```
ActorController
 ├── @export current_mode: ControllerModeBase   ← swap to change behavior
 ├── _handle_controlled_input(delta)
 │       └── calls current_mode.process_input(actor, camera, delta)
 └── is_controlled: bool  ← unchanged gate

ControllerModeBase (Resource)
 ├── process_input(actor, camera, delta) → void   [virtual]
 ├── get_aim_target(actor, camera) → Vector3      [virtual]
 ├── get_camera_config() → CameraConfig           [virtual]
 ├── on_mode_entered(actor, camera) → void        [virtual]
 └── on_mode_exited(actor, camera) → void         [virtual]

PlayerInputComponent
 └── _get_aim_target() → calls arena's active mode's get_aim_target()
```

### Mode Registry

A lightweight autoload (`ControllerModeRegistry`) maps mode enum keys to pre-instantiated resources. Switching modes triggers `on_mode_exited` on the old and `on_mode_entered` on the new.

```
enum ControlMode {
    TWIN_STICK,       # top-down overhead
    THIRD_PERSON,     # over-the-shoulder
    FIRST_PERSON,     # FPS
    RTS,              # click-to-move, free camera
}
```

---

## 2. Control Modes

### 2.1 Twin-Stick (Overhead Top-Down) — *current behavior*

**Camera**: Fixed overhead or mild isometric angle. Orbits only in the Y axis if at all. No pitch.

**Movement**: WASD/arrows. Direction projected onto the XZ plane relative to camera forward (existing logic in `ActorController._handle_controlled_input()`).

**Orientation**: Actor faces the mouse cursor's world-space position on the ground plane. Uses the existing `_get_mouse_3d_position()` raycast.

**Aim target**: Mouse ground-plane intersection (current `PlayerInputComponent` behavior — no change needed).

**Jump**: Spacebar.

| Input | Action |
|-------|--------|
| WASD / Arrows | Move |
| Mouse position | Actor facing / aim direction |
| Left Click | Primary attack toward cursor |
| Right Click | Secondary attack toward cursor |
| Space | Jump |
| Shift (tap) | Disengage dash (away from cursor) |
| Shift (hold) | Hide |

---

### 2.2 Third Person (Over-the-Shoulder)

**Camera**: Orbits the actor. Mouse X rotates camera (and character) horizontally. Mouse Y tilts camera vertically (clamped). Spring-arm style, configurable arm length and collision fallback.

**Movement**: WASD moves relative to the **character's facing direction**, not the camera. W = forward, S = back, A/D = strafe or rotate depending on `strafe_mode` flag.

**Orientation**: Character always faces camera-forward on the horizontal plane. Look direction = camera look direction projected to XZ.

**Aim target**: A point `aim_distance` units along the camera's forward ray from the center of the screen. For abilities/attacks: screen-center raycast first, fallback to `aim_distance` projection.

**Mouse mode**: `MOUSE_MODE_CAPTURED` while in play. Toggle with Escape.

| Input | Action |
|-------|--------|
| WASD | Move relative to character facing |
| Mouse X | Rotate camera + character horizontally |
| Mouse Y | Tilt camera (clamped ±70°) |
| Left Click | Primary attack (screen-center aim) |
| Right Click | Secondary attack / ADS toggle |
| Space | Jump |
| Shift | Sprint / dash |
| Escape | Release mouse cursor |

---

### 2.3 First Person (FPS)

**Camera**: Attached to the actor's head bone or a head-offset `Marker3D`. Full mouselook — pitch and yaw. Pitch clamped to ±89°.

**Movement**: WASD relative to character facing. Character body yaw matches camera yaw continuously.

**Orientation**: Body always aligns to camera yaw. Camera pitch is independent (head-only).

**Aim target**: Screen-center raycast. No cursor visible during play.

**Mouse mode**: `MOUSE_MODE_CAPTURED` always while active.

| Input | Action |
|-------|--------|
| WASD | Move (camera-relative) |
| Mouse | Full mouselook (pitch + yaw) |
| Left Click | Primary attack |
| Right Click | ADS / secondary attack |
| Space | Jump |
| Shift | Sprint |
| Ctrl | Crouch (if actor has crouch capability) |
| Escape | Release cursor / pause |

---

### 2.4 RTS (Real-Time Strategy)

**Camera**: Freely panning top-down camera, decoupled from the actor entirely. Pan via WASD or edge-scrolling. Zoom via scroll wheel. Optional rotation via middle mouse drag.

**Movement**: Left-click on the ground issues a move command to the actor's `MovementComponent` (sets a destination, not a direction). Actor uses its tile navigation component to path there.

**Orientation**: Actor faces its movement direction while moving; faces last-attack target when idle.

**Aim target**: World position of the left-click hit (same as current `_get_mouse_3d_position()` but decoupled from the actor's facing).

**Selection**: The active `PlayerInputComponent` controlled actor is highlighted. Switching actors uses existing Tab/Shift-Tab flow.

| Input | Action |
|-------|--------|
| WASD | Pan camera |
| Scroll Wheel | Zoom camera |
| Middle Mouse Drag | Rotate camera |
| Left Click (ground) | Move actor to position |
| Left Click (enemy) | Attack target |
| Right Click | Cancel / secondary |
| Tab | Cycle to next actor |
| Shift+Tab | Cycle to previous actor |
| Space | Jump (if applicable) |

---

## 3. Component Breakdown

### 3.1 `ControllerModeBase` (Resource)

```
res://src/actors/ai/controller_modes/ControllerModeBase.gd
```

Base resource all modes extend.

| Property | Type | Description |
|----------|------|-------------|
| `mode_id` | `ControlMode` (enum) | Identifies this mode |
| `sensitivity_x` | `float` | Horizontal mouse/stick sensitivity |
| `sensitivity_y` | `float` | Vertical mouse/stick sensitivity |
| `invert_y` | `bool` | Flip vertical axis |

| Method | Returns | Description |
|--------|---------|-------------|
| `process_input(actor, camera, delta)` | `void` | Drive movement and orientation each physics tick |
| `get_aim_target(actor, camera)` | `Vector3` | World-space point to aim attacks/abilities at |
| `get_camera_config()` | `CameraConfig` | Camera distance, pitch limits, FOV |
| `on_mode_entered(actor, camera)` | `void` | Setup: capture mouse, reposition camera |
| `on_mode_exited(actor, camera)` | `void` | Teardown: restore mouse mode |

---

### 3.2 `TwinStickMode` (Resource)

```
res://src/actors/ai/controller_modes/TwinStickMode.gd
```

Migrated from `ActorController._handle_controlled_input()`. Minimal changes to existing behavior — this is a lift-and-shift extraction.

---

### 3.3 `ThirdPersonMode` (Resource)

```
res://src/actors/ai/controller_modes/ThirdPersonMode.gd
```

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `arm_length` | `float` | `4.0` | Spring-arm camera distance |
| `min_arm_length` | `float` | `1.5` | Minimum zoom |
| `max_arm_length` | `float` | `12.0` | Maximum zoom |
| `pitch_min` | `float` | `-60.0` | Degrees |
| `pitch_max` | `float` | `70.0` | Degrees |
| `strafe_mode` | `bool` | `false` | A/D strafes instead of rotating |

---

### 3.4 `FirstPersonMode` (Resource)

```
res://src/actors/ai/controller_modes/FirstPersonMode.gd
```

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `head_offset` | `Vector3` | `(0, 1.7, 0)` | Head position relative to actor origin |
| `pitch_min` | `float` | `-89.0` | Degrees |
| `pitch_max` | `float` | `89.0` | Degrees |
| `fov` | `float` | `75.0` | Camera field of view |
| `ads_fov` | `float` | `55.0` | Field of view when aiming down sights |

---

### 3.5 `RTSMode` (Resource)

```
res://src/actors/ai/controller_modes/RTSMode.gd
```

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `pan_speed` | `float` | `20.0` | Camera pan speed (units/sec) |
| `edge_scroll_margin` | `int` | `20` | Pixels from screen edge that trigger pan |
| `edge_scroll_enabled` | `bool` | `true` | Enable edge-scroll panning |
| `zoom_min` | `float` | `5.0` | Minimum camera height |
| `zoom_max` | `float` | `80.0` | Maximum camera height |
| `zoom_speed` | `float` | `5.0` | Scroll wheel zoom speed |
| `rotation_enabled` | `bool` | `true` | Allow middle-mouse rotation |

---

### 3.6 `CameraConfig` (Resource)

```
res://src/actors/ai/controller_modes/CameraConfig.gd
```

Returned by `get_camera_config()` so the `CameraFollower` (or equivalent) can reconfigure itself when a mode is activated.

| Property | Type | Description |
|----------|------|-------------|
| `mode` | `CameraMode` enum | FOLLOW_ACTOR, FREE, FIRST_PERSON |
| `distance` | `float` | Spring-arm length (FOLLOW) or height (FREE) |
| `pitch` | `float` | Initial pitch in degrees |
| `fov` | `float` | Camera field of view |
| `smooth_speed` | `float` | Lerp factor for position tracking |

---

### 3.7 Updated `ActorController`

The existing `ActorController._handle_controlled_input()` is replaced with:

```gdscript
func _handle_controlled_input(delta: float) -> void:
    if not current_mode:
        return
    current_mode.process_input(actor, get_viewport().get_camera_3d(), delta)
```

`get_aim_target()` on `ActorController` becomes a pass-through to `current_mode.get_aim_target()`, used by `PlayerInputComponent` instead of its internal `_get_mouse_3d_position()`.

---

### 3.8 Updated `PlayerInputComponent`

Replace the direct `_get_mouse_3d_position()` call in attack/ability handling with:

```gdscript
func _get_aim_target() -> Vector3:
    if current_controlled_actor and current_controlled_actor.get("controller"):
        return current_controlled_actor.controller.get_aim_target()
    return _get_mouse_3d_position()  # fallback
```

This keeps `PlayerInputComponent` mode-agnostic — it just asks the controller where the actor is aiming.

---

## 4. Data Flow

```
InputEvent / Input polling
         │
         ▼
ActorController._handle_controlled_input(delta)
         │
         ▼
current_mode.process_input(actor, camera, delta)
    ├── reads Input actions
    ├── calls movement_component.move(direction, delta)
    ├── calls movement_component.apply_gravity(delta)
    ├── calls movement_component.jump()
    └── updates actor facing / camera rig

PlayerInputComponent._unhandled_input(event)
    ├── detects attack / ability inputs
    └── calls current_controlled_actor.controller.get_aim_target()
              └── current_mode.get_aim_target(actor, camera)
                       → Vector3 world-space aim point
```

---

## 5. Camera System Integration

Each mode drives a different camera setup. The `CameraFollower` (or equivalent camera rig) needs to respond to `CameraConfig` updates on mode switch.

| Mode | Camera Behavior |
|------|----------------|
| Twin-Stick | Fixed overhead follow; `CameraFollower.set_target(actor)` unchanged |
| Third Person | Spring-arm follow; camera node reparented to actor or driven by controller |
| First Person | Camera attached to actor's head `Marker3D`; no independent movement |
| RTS | Free-floating camera; decoupled from actor entirely |

Mode switch calls `camera_config = current_mode.get_camera_config()` and dispatches a signal or direct call to reconfigure the camera rig.

---

## 6. File Structure

```
res://src/actors/ai/
├── ActorController.gd                    # updated: delegates to current_mode
├── controller_modes/
│   ├── ControllerModeBase.gd             # base resource (virtual methods)
│   ├── CameraConfig.gd                   # camera configuration resource
│   ├── TwinStickMode.gd                  # migrated from _handle_controlled_input
│   ├── ThirdPersonMode.gd
│   ├── FirstPersonMode.gd
│   └── RTSMode.gd
res://Components/Arena/
└── PlayerInputComponent.gd               # updated: _get_aim_target() passthrough
```

---

## 7. Code Reuse Analysis (Over-the-Shoulder First)

### Reusable as-is

| Component | What's reusable | Notes |
|-----------|----------------|-------|
| `MovementComponent` | `move()`, `apply_gravity()`, `jump()` | Fully mode-agnostic — takes a direction vector, handles all physics internally |
| WASD direction math | `ActorController._handle_controlled_input()` lines 38–64 | Camera-relative movement already works for third-person when the camera is behind the character. `cam_basis.z` projected onto XZ becomes character forward automatically |
| `PlayerInputComponent` action bindings | Attack keys, ability keys, Q/E/T/R/C, shift hold/tap | All mode-agnostic — they just need to call a different aim-target method |

### Needs small refactors (~40 lines total, low risk)

**1. Extract `_handle_controlled_input()` into `TwinStickMode`**

The controller body becomes a thin delegator:
```gdscript
func _handle_controlled_input(delta: float) -> void:
    if current_mode:
        current_mode.process_input(actor, get_viewport().get_camera_3d(), delta)
```
The existing WASD + jump + `C`-key polling logic moves verbatim into `TwinStickMode.process_input()`. Zero behavior change. The `C`-key fallback polling (lines 72–78 of the current `ActorController`) stays in `TwinStickMode` since it's arena-specific.

**2. `PlayerInputComponent._get_mouse_3d_position()` → `_get_aim_target()` passthrough**

The internal ground-plane raycast stays identical. The call site becomes:
```gdscript
func _get_aim_target() -> Vector3:
	if current_controlled_actor and current_controlled_actor.controller:
		return current_controlled_actor.controller.get_aim_target()
	return _get_mouse_3d_position()  # fallback
```
All attack/ability dispatch (`launch_projectile_at`, `secondary_attack_at`, etc.) calls `_get_aim_target()` instead of `_get_mouse_3d_position()`. For twin-stick the result is identical. For third-person, `get_aim_target()` returns a screen-center raycast instead.

### Needs new code (the actual third-person work)

**`CameraFollower.gd`** is the biggest gap. It uses a fixed offset vector (`Vector3(0, 30, 30)`) and `look_at()` — no concept of yaw/pitch angles or mouse orbit. Third-person requires:
- `_yaw` and `_pitch` floats that mouse motion accumulates into each frame
- Pitch clamped (e.g. −60° to +70°)
- Camera position computed from spherical coords: `target_pos + Basis.from_euler(Vector3(pitch, yaw, 0)) * Vector3(0, 0, arm_length)`
- `MOUSE_MODE_CAPTURED` while active

**Recommendation**: don't modify `CameraFollower`. Create a separate **`ThirdPersonCamera.gd`** node that `ThirdPersonMode.on_mode_entered()` activates (and `on_mode_exited()` deactivates). `CameraFollower` stays simple for twin-stick/RTS; third-person camera is self-contained. This also means steps 3 and 4 of the migration below can be built and tested independently before the full mode-switching infrastructure is wired up.

**`ControllerModeBase.gd`** and **`ThirdPersonMode.gd`** — new files, nothing to extract.

### Recommended implementation order

1. Extract `TwinStickMode` + wire `current_mode` into `ActorController` *(refactor, validate no regressions)*
2. Add `_get_aim_target()` passthrough in `PlayerInputComponent` *(confirm attacks still land on cursor)*
3. Build `ThirdPersonCamera.gd` as a standalone node *(can test in isolation)*
4. Implement `ThirdPersonMode.gd` using the extracted WASD math + new camera

Steps 1 and 2 are the only blockers. Steps 3 and 4 are independent once the base resource interface exists.

---

## 8. Migration Strategy

### Phase 1 — Extract Twin-Stick (no behavior change)
1. Create `ControllerModeBase.gd`
2. Create `TwinStickMode.gd` — copy existing `_handle_controlled_input()` logic verbatim
3. Update `ActorController` to hold `current_mode` and call `current_mode.process_input()`
4. Set default `current_mode = TwinStickMode.new()` so existing scenes are unaffected
5. Run arena, confirm no regressions

### Phase 2 — Aim target passthrough
1. Add `get_aim_target()` to `ControllerModeBase` and `TwinStickMode` (returns ground-plane raycast)
2. Update `PlayerInputComponent._get_aim_target()` to call through the controller
3. Confirm attacks/abilities still hit the cursor position correctly

### Phase 3 — Third Person
1. Implement `ThirdPersonMode.gd` and `CameraConfig.gd`
2. Update the camera rig to respond to `CameraConfig`
3. Wire a dev debug key to toggle between Twin-Stick and Third Person mid-session for testing

### Phase 4 — First Person
1. Implement `FirstPersonMode.gd`
2. Actor must expose a `head_marker: Marker3D` export or auto-create one at `head_offset`
3. Test with default humanoid actors

### Phase 5 — RTS
1. Implement `RTSMode.gd`
2. Requires `ActorTileNavigationComponent` to accept a click destination (already exists)
3. Build free-pan camera node or extend `CameraFollower` with a `FREE` mode

---

## 8. Main Menu Integration

> **TODO**: Add a **Control Mode** selector to the main menu before entering the arena.

The selected mode should be saved to `GameSettings` and read by `ActorController` during setup to set the initial `current_mode`. A simple `OptionButton` or radio group is sufficient — no need for a full settings screen at first.

Suggested placement: alongside the existing character/actor selection flow, as a secondary option below the actor designer. Label it **"Control Style"** with options: Top-Down, Over-the-Shoulder, First Person, RTS.

The selected value maps directly to the `ControlMode` enum and should persist between sessions.

---

## 9. Open Questions

1. **Mode persistence**: Should selected mode be saved to `GameSettings` and restored between sessions?
2. **Per-actor defaults**: Should actor types (e.g. `GoatActor`) override the default mode? A goat in first-person is unusual.
3. **Controller / gamepad support**: Twin-stick and third-person map naturally to a gamepad right stick — worth designing input abstraction for that now?
4. **Camera rig ownership**: Does `current_mode` directly manipulate the camera node, or does it return a target transform and a separate camera driver applies it? The latter is cleaner.
5. **RTS multi-select**: Does RTS mode ever need to command multiple actors simultaneously, or is it always single-actor?
6. **Third-person crosshair**: Use a UI crosshair element, or rely on the existing cursor?
