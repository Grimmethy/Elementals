# Modular Character Controller

## Overview

The Modular Character Controller decouples **control scheme logic** from the `ActorController` base class. Each control style is a swappable **`ControllerMode`** resource that can be hot-swapped at runtime, allowing the same actor to be driven by any of four distinct control paradigms. Phases 1–3 (Twin-Stick extraction, aim-target passthrough, and Third-Person) are **complete and live**. First Person and RTS remain unimplemented.

The `PlayerInputComponent` (Arena action layer — attacks, abilities, cycling patterns) is intentionally kept separate. Controller modes handle **movement and orientation** only; `PlayerInputComponent` continues to handle **combat actions** and delegates aiming to the active mode's `get_aim_target()` method.

---

## 1. Architecture

### Strategy Pattern via GDScript Resources

Each mode is a `ControllerModeBase` resource. `ActorController` holds a reference to the active mode and delegates movement and orientation decisions to it. The mode is created lazily on the first physics tick by reading `GameSettings.selected_control_mode`.

```
ActorController
 ├── @export current_mode: ControllerModeBase   ← swap to change behavior
 ├── _mode_active: bool                          ← tracks lifecycle state
 ├── _handle_controlled_input(delta)
 │       └── calls current_mode.process_input(actor, camera, delta)
 ├── get_aim_target() → Vector3                  ← passthrough for PlayerInputComponent
 └── is_controlled: bool  ← unchanged gate

ControllerModeBase (Resource)
 ├── process_input(actor, camera, delta) → void   [virtual]
 ├── get_aim_target(actor, camera) → Vector3      [virtual]
 ├── on_mode_entered(actor, camera) → void        [virtual]
 └── on_mode_exited(actor, camera) → void         [virtual]

PlayerInputComponent
 └── _get_aim_target() → calls arena's active mode's get_aim_target()
```

### Mode Selection

Mode selection is handled at startup via `GameSettings.selected_control_mode` (an int). `ActorController._make_default_mode()` reads this value and creates the appropriate mode resource. Hot-swapping at runtime is possible via `ActorController.set_mode(new_mode)`.

```gdscript
# Selected mode int values
0 = Twin-Stick (top-down, default)
1 = Third Person (over-the-shoulder)
2 = First Person  (not yet implemented)
3 = RTS           (not yet implemented)
```

---

## 2. Control Modes

### 2.1 Twin-Stick (Overhead Top-Down) — *implemented*

**Camera**: Fixed overhead follow via `CameraFollower`. No changes to existing behavior.

**Movement**: WASD/arrows. Direction projected onto the XZ plane relative to camera forward.

**Orientation**: Actor faces the mouse cursor's world-space position on the ground plane via ground-plane raycast in `ActorVisualComponent._get_mouse_direction()`.

**Aim target**: Mouse ground-plane intersection (`ActorController.get_aim_target()` → `TwinStickMode.get_aim_target()` → raycast via `actor.get_world_3d()`).

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

### 2.2 Third Person (Over-the-Shoulder) — *implemented*

**Camera**: `ThirdPersonCamera` node added as a sibling of the actor in the scene tree. Orbits the actor using spherical coordinates (yaw + pitch). `CameraFollower` is disabled via `PROCESS_MODE_DISABLED` while this mode is active and re-enabled on exit.

**Movement**: WASD moves relative to the **camera's horizontal forward direction**. W = camera-forward, S = camera-back, A = camera-left, D = camera-right.

**Orientation**: Actor always faces the camera's horizontal forward direction. `ThirdPersonMode.process_input()` sets `ActorVisualComponent.facing_dir_override` to `-tp_cam.global_transform.basis.z` projected onto XZ each frame.

**Aim target**: Screen-centre raycast from `ThirdPersonCamera.get_aim_target_world()`. Falls back to `actor.global_position` if no collision is found.

**Mouse mode**: `MOUSE_MODE_CAPTURED` while active. Toggle with Escape.

| Input | Action |
|-------|--------|
| WASD | Move relative to camera facing |
| Mouse X | Orbit camera horizontally |
| Mouse Y | Tilt camera vertically (clamped) |
| Scroll Wheel | Zoom (arm length) |
| Left Click | Primary attack (screen-center aim) |
| Right Click | Secondary attack |
| Space | Jump |
| Escape | Release / recapture mouse cursor |

---

### 2.3 First Person (FPS) — *not yet implemented*

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
| Escape | Release cursor / pause |

---

### 2.4 RTS (Real-Time Strategy) — *not yet implemented*

**Camera**: Freely panning top-down camera, decoupled from the actor entirely. Pan via WASD or edge-scrolling. Zoom via scroll wheel.

**Movement**: Left-click on the ground issues a move command to the actor's `MovementComponent`.

**Orientation**: Actor faces its movement direction while moving; faces last-attack target when idle.

**Aim target**: World position of the left-click hit.

| Input | Action |
|-------|--------|
| WASD | Pan camera |
| Scroll Wheel | Zoom camera |
| Left Click (ground) | Move actor to position |
| Left Click (enemy) | Attack target |
| Right Click | Cancel / secondary |
| Tab | Cycle to next actor |

---

## 3. Component Breakdown

### 3.1 `ControllerModeBase` (Resource) — *implemented*

```
res://src/actors/ai/controller_modes/ControllerModeBase.gd
```

Base resource all modes extend. All methods are virtual (empty body).

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `sensitivity_x` | `float` | `0.3` | Horizontal mouse sensitivity |
| `sensitivity_y` | `float` | `0.3` | Vertical mouse sensitivity |
| `invert_x` | `bool` | `false` | Flip horizontal look axis |
| `invert_y` | `bool` | `false` | Flip vertical look axis |

| Method | Returns | Description |
|--------|---------|-------------|
| `process_input(actor, camera, delta)` | `void` | Drive movement and orientation each physics tick |
| `get_aim_target(actor, camera)` | `Vector3` | World-space point to aim attacks/abilities at |
| `on_mode_entered(actor, camera)` | `void` | Setup: capture mouse, activate camera, etc. |
| `on_mode_exited(actor, camera)` | `void` | Teardown: restore mouse mode, deactivate camera |

---

### 3.2 `TwinStickMode` (Resource) — *implemented*

```
res://src/actors/ai/controller_modes/TwinStickMode.gd
```

Lifted verbatim from `ActorController._handle_controlled_input()`. No behavior change from the original hardcoded logic.

- `process_input`: WASD camera-relative movement, gravity, jump, C-key net-close polling
- `get_aim_target`: Ground-plane raycast from mouse position via `actor.get_world_3d()`
- `on_mode_entered` / `on_mode_exited`: no-ops (mouse mode unchanged)

---

### 3.3 `ThirdPersonMode` (Resource) — *implemented*

```
res://src/actors/ai/controller_modes/ThirdPersonMode.gd
```

Thin mode resource — camera configuration properties live on `ThirdPersonCamera`, not here. This mode owns the lifecycle of the `ThirdPersonCamera` node.

| Property | Type | Description |
|----------|------|-------------|
| `sensitivity_x` | `float` | Forwarded to `ThirdPersonCamera.sensitivity_x` on mode enter |
| `sensitivity_y` | `float` | Forwarded to `ThirdPersonCamera.sensitivity_y` on mode enter |
| `invert_x` | `bool` | Forwarded to `ThirdPersonCamera.invert_x` on mode enter |
| `invert_y` | `bool` | Forwarded to `ThirdPersonCamera.invert_y` on mode enter |

**Lifecycle**:
- `on_mode_entered`: Stashes and disables `CameraFollower` via `PROCESS_MODE_DISABLED`. Finds or creates a `ThirdPersonCamera` sibling node. Forwards sensitivity/invert settings. Calls `tp_camera.activate(actor)`.
- `on_mode_exited`: Clears `ActorVisualComponent.facing_dir_override`. Calls `tp_camera.deactivate()`. Re-enables the stashed camera via `PROCESS_MODE_INHERIT` and calls `make_current()` on it.
- `process_input`: WASD camera-relative movement (same math as TwinStickMode, using `ThirdPersonCamera` basis). Sets `visual_component.facing_dir_override` to the camera's horizontal forward each frame.
- `get_aim_target`: Delegates to `ThirdPersonCamera.get_aim_target_world()`.

---

### 3.4 `ThirdPersonCamera` (Camera3D node) — *implemented*

```
res://Player/ThirdPersonCamera.gd
```

Orbit camera node. Activated/deactivated by `ThirdPersonMode`. Added as a **sibling of the actor** in the scene tree during `on_mode_entered`; reused if already present.

| Export | Type | Default | Description |
|--------|------|---------|-------------|
| `arm_length` | `float` | `4.0` | Initial spring-arm distance |
| `min_arm_length` | `float` | `1.5` | Minimum zoom distance |
| `max_arm_length` | `float` | `12.0` | Maximum zoom distance |
| `pitch_min` | `float` | `-10.0` | Minimum pitch in degrees |
| `pitch_max` | `float` | `75.0` | Maximum pitch in degrees |
| `zoom_speed` | `float` | `0.5` | Scroll wheel zoom speed |
| `pivot_height` | `float` | `1.0` | Vertical offset of orbit pivot above actor origin |

| Runtime var | Type | Description |
|-------------|------|-------------|
| `sensitivity_x` | `float` | Set by `ThirdPersonMode` from `ControllerModeBase` |
| `sensitivity_y` | `float` | Set by `ThirdPersonMode` from `ControllerModeBase` |
| `invert_x` | `bool` | Set by `ThirdPersonMode`; flips yaw direction |
| `invert_y` | `bool` | Set by `ThirdPersonMode`; flips pitch direction |

**Key methods**:
- `activate(target: Node3D)`: Sets `_target`, calls `Input.set_mouse_mode(MOUSE_MODE_CAPTURED)`, calls `make_current()`
- `deactivate()`: Clears `_target`, restores mouse mode
- `get_aim_target_world() -> Vector3`: Screen-centre raycast; excludes the actor from collision

**Camera math** (in `_process`):
```
pivot = target.global_position + Vector3(0, pivot_height, 0)
offset = Vector3(sin(yaw)*cos(pitch), sin(pitch), cos(yaw)*cos(pitch)) * arm_length
global_position = pivot + offset
look_at(pivot)
```

---

### 3.5 `FirstPersonMode` (Resource) — *not yet implemented*

```
res://src/actors/ai/controller_modes/FirstPersonMode.gd
```

Planned properties:

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `head_offset` | `Vector3` | `(0, 1.7, 0)` | Head position relative to actor origin |
| `pitch_min` | `float` | `-89.0` | Degrees |
| `pitch_max` | `float` | `89.0` | Degrees |
| `fov` | `float` | `75.0` | Camera field of view |

---

### 3.6 `RTSMode` (Resource) — *not yet implemented*

```
res://src/actors/ai/controller_modes/RTSMode.gd
```

Planned properties:

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `pan_speed` | `float` | `20.0` | Camera pan speed (units/sec) |
| `edge_scroll_margin` | `int` | `20` | Pixels from screen edge that trigger pan |
| `zoom_min` | `float` | `5.0` | Minimum camera height |
| `zoom_max` | `float` | `80.0` | Maximum camera height |
| `zoom_speed` | `float` | `5.0` | Scroll wheel zoom speed |

---

### 3.7 Updated `ActorController` — *implemented*

```
res://src/actors/ai/ActorController.gd
```

Key changes from the original:

- `current_mode: ControllerModeBase` — holds the active mode; lazy-created on first physics tick via `_make_default_mode()`
- `_mode_active: bool` — tracks whether `on_mode_entered` has been called; triggers lifecycle hooks on `is_controlled` transitions
- `_handle_controlled_input(delta)` — one-liner delegation to `current_mode.process_input()`
- `get_aim_target() -> Vector3` — passthrough to `current_mode.get_aim_target()`, used by `PlayerInputComponent`
- `set_mode(new_mode)` — hot-swaps the mode, calling exit/enter lifecycle hooks as needed
- `_make_default_mode()` — reads `GameSettings.selected_control_mode`; creates `ThirdPersonMode` (with invert flags) for index 1, falls back to `TwinStickMode`

---

### 3.8 Updated `PlayerInputComponent` — *implemented*

```
res://Components/Arena/PlayerInputComponent.gd
```

All attack/ability target lookups now call `_get_aim_target()`:

```gdscript
func _get_aim_target() -> Vector3:
    if is_instance_valid(current_controlled_actor) and current_controlled_actor.controller:
        return current_controlled_actor.controller.get_aim_target()
    return _get_mouse_3d_position()  # fallback
```

`_get_mouse_3d_position()` is retained internally as a fallback. The disengage-dash intentionally still uses `_get_mouse_3d_position()` directly (away-from-cursor logic).

---

### 3.9 Updated `ActorVisualComponent` — *implemented*

```
res://Components/ActorComponents/ActorVisualComponent.gd
```

Added `facing_dir_override` to support third-person (and future first-person) modes where `MOUSE_MODE_CAPTURED` makes the mouse raycast unreliable:

```gdscript
## Set by a controller mode to override the default mouse-facing logic.
## Vector3.ZERO means disabled (falls back to _get_mouse_direction).
var facing_dir_override: Vector3 = Vector3.ZERO
```

In `_update_model_rotation()`, the facing priority is:

1. **Attacking** (`weapon_component.is_on_cooldown()`) → `last_attack_dir`
2. **Player controlled + override set** → `facing_dir_override` (used by `ThirdPersonMode`)
3. **Player controlled + no override** → `_get_mouse_direction()` (used by `TwinStickMode`)
4. **Fallback** → horizontal velocity

`ThirdPersonMode.process_input()` sets `facing_dir_override` to the camera's horizontal forward direction each frame, and `on_mode_exited()` resets it to `Vector3.ZERO`.

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
	└── sets visual_component.facing_dir_override  ← ThirdPersonMode only

PlayerInputComponent._unhandled_input(event)
	├── detects attack / ability inputs
	└── calls current_controlled_actor.controller.get_aim_target()
			  └── current_mode.get_aim_target(actor, camera)
					   → Vector3 world-space aim point
```

---

## 5. Camera System Integration

Each mode manages its own camera setup directly. There is no shared `CameraConfig` resource.

| Mode | Camera Behavior |
|------|----------------|
| Twin-Stick | `CameraFollower` unchanged; overhead follow, unaffected by mode system |
| Third Person | `ThirdPersonCamera` node activated as sibling; `CameraFollower` disabled for duration |
| First Person | TBD — will attach a camera node to a head `Marker3D` on the actor |
| RTS | TBD — free-floating pan camera decoupled from the actor |

**Mode switch flow (Third Person)**:
1. `ThirdPersonMode.on_mode_entered()` stores a reference to the current `Camera3D` and sets it to `PROCESS_MODE_DISABLED`
2. Finds or creates `ThirdPersonCamera` as a sibling of the actor in the scene tree
3. Calls `ThirdPersonCamera.activate(actor)` → sets `make_current()` and `MOUSE_MODE_CAPTURED`
4. On exit: `ThirdPersonCamera.deactivate()` → `PROCESS_MODE_DISABLED`; stashed camera restored to `PROCESS_MODE_INHERIT` and `make_current()`

---

## 6. GameSettings Integration

Controller mode selection and invert preferences are persisted through `GameSettings` (autoload, `res://Core/GameSettings.gd`):

| Setting | Type | Default | Description |
|---------|------|---------|-------------|
| `selected_control_mode` | `int` | `0` | 0=Twin-Stick, 1=Third Person, 2=First Person, 3=RTS |
| `invert_look_x` | `bool` | `false` | Flip horizontal mouse look |
| `invert_look_y` | `bool` | `false` | Flip vertical mouse look |

All three are saved under the `"General"` section in `user://settings.cfg` and loaded with defaults on startup.

**Flow from menu to gameplay**:
1. Player selects mode and invert options in the **Controller Select** panel on the main menu
2. `MainMenu._on_mode_selected(index)` writes `gs.selected_control_mode`
3. `MainMenu._on_invert_changed(axis, on)` writes `gs.invert_look_x` / `gs.invert_look_y`
4. `MainMenu._on_play_button_pressed()` calls `gs.save_settings()` before scene change
5. `ActorController._make_default_mode()` reads these values on the first physics tick after entering the arena:
   - Index 1 → creates `ThirdPersonMode` and assigns `invert_x` / `invert_y` from settings
   - `ThirdPersonMode.on_mode_entered()` forwards these to `ThirdPersonCamera`

---

## 7. Main Menu — Controller Select Panel

A **Controller Select** panel was added to `res://UI/MainMenu.tscn`, toggled by the **Controller Select** button (between Character Selection and Weapon Selection).

**Contents**:
- **Mode buttons** (radio group via `ButtonGroup`): Top-Down, Over-the-Shoulder, First Person (disabled), RTS (disabled)
- **Invert Look X** checkbox
- **Invert Look Y** checkbox

The panel follows the same open/close pattern as all other menu panels — opening it closes any other open panel. State is restored from `GameSettings` on `_ready()` using `set_pressed_no_signal()` to avoid double-writing.

---

## 8. File Structure

```
res://src/actors/ai/
├── ActorController.gd                        # updated: mode delegation, lazy init, lifecycle hooks
└── controller_modes/
	├── ControllerModeBase.gd                 # base resource (virtual interface)
	├── TwinStickMode.gd                      # ✅ implemented
	├── ThirdPersonMode.gd                    # ✅ implemented
	├── FirstPersonMode.gd                    # 🔲 not yet implemented
	└── RTSMode.gd                            # 🔲 not yet implemented

res://Player/
└── ThirdPersonCamera.gd                      # ✅ implemented (orbit camera node)

res://Components/Arena/
└── PlayerInputComponent.gd                   # updated: _get_aim_target() passthrough

res://Components/ActorComponents/
└── ActorVisualComponent.gd                   # updated: facing_dir_override property

res://Core/
└── GameSettings.gd                           # updated: selected_control_mode, invert_look_x/y

res://UI/
├── MainMenu.tscn                             # updated: Controller Select panel added
└── MainMenu.gd                              # updated: mode/invert handlers, state restore
```

---

## 9. Code Reuse Summary (Completed)

### Reused as-is

| Component | What was reused |
|-----------|----------------|
| `MovementComponent` | `move()`, `apply_gravity()`, `jump()` — fully mode-agnostic |
| WASD direction math | Camera-relative XZ projection copied verbatim into both `TwinStickMode` and `ThirdPersonMode` |
| `PlayerInputComponent` action bindings | All attack/ability keys unchanged; only aim-target call site updated |

### Modified (low-risk refactors)

| Component | Change |
|-----------|--------|
| `ActorController` | Full rewrite: extracted movement logic into modes, added lifecycle hooks, lazy init |
| `PlayerInputComponent` | Added `_get_aim_target()` passthrough; all attack call sites updated |
| `ActorVisualComponent` | Added `facing_dir_override` property and priority check in `_update_model_rotation()` |
| `GameSettings` | Added three new persisted settings |

### New files

| File | Purpose |
|------|---------|
| `ControllerModeBase.gd` | Strategy interface |
| `TwinStickMode.gd` | Original behavior, extracted |
| `ThirdPersonMode.gd` | Over-the-shoulder mode |
| `ThirdPersonCamera.gd` | Orbit camera for third-person |

`CameraFollower.gd` was **not modified** — twin-stick uses it unchanged; third-person bypasses it entirely.

---

## 10. Migration Status

| Phase | Status | Description |
|-------|--------|-------------|
| Phase 1 — Extract Twin-Stick | ✅ Complete | `ControllerModeBase`, `TwinStickMode`, `ActorController` delegation |
| Phase 2 — Aim target passthrough | ✅ Complete | `PlayerInputComponent._get_aim_target()` wired through controller |
| Phase 3 — Third Person | ✅ Complete | `ThirdPersonMode`, `ThirdPersonCamera`, `facing_dir_override`, menu UI, GameSettings |
| Phase 4 — First Person | 🔲 Not started | Needs head `Marker3D` on actors |
| Phase 5 — RTS | 🔲 Not started | Needs free-pan camera and click-to-move destination |

---

## 11. Open Questions

1. **Per-actor mode defaults**: Should certain actor types (e.g. `GoatActor`) restrict or override the selectable modes? A goat in first-person is unusual.
2. **Controller / gamepad support**: Twin-stick and third-person map naturally to a gamepad right stick — input abstraction deferred.
3. **Third-person crosshair**: Currently relies on default cursor while mouse is captured. A screen-centre reticle UI element would improve usability.
4. **RTS multi-select**: Does RTS mode ever need to command multiple actors simultaneously, or always single-actor?
5. **`ThirdPersonCamera` collision**: No spring-arm collision avoidance currently — camera can clip into geometry. A raycast-based arm-length clamp would fix this.
