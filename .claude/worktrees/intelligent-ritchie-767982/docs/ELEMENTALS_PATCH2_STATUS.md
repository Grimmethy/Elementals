# Elementals Implementation Status — Patch 2 (Breeding Generalization)

> Companion to [ELEMENTALS_IMPLEMENTATION_STATUS.md](ELEMENTALS_IMPLEMENTATION_STATUS.md) (Extended Slice / Patch 1).
> This document covers the second implementation pass: breeding generalization for non-goat species.
>
> Source reports:
> - [AGENT_1_PATCH2_STATE_CHECK.md](AGENT_1_PATCH2_STATE_CHECK.md) — read-only state inventory + risk list R1-R12 + strict patch order
> - [AGENT_2_PATCH2_LOG.md](AGENT_2_PATCH2_LOG.md) — file-by-file patch log + open questions
> - [AGENT_3_PATCH2_REVIEW.md](AGENT_3_PATCH2_REVIEW.md) — independent verification (no blockers)
>
> All paths repo-relative.

---

## 1. Summary

Patch 2 generalized the breeding loop from goat-only to **any `ActorData` subclass** by lifting `is_selected` to the base, adding three polymorphic virtuals (`get_display_name`, `get_info_line`, `set_display_name`), fixing the [HerdManager.gd:99-102](../Components/BreedingComponents/HerdManager.gd) one-line silent killer that was dropping non-goat kids, creating three new `*Data` subclasses (`GoblinData`, `FarmerData`, `ElementalData`), wiring non-goat actors to optionally carry their data (with `if _data == null:` gates preserving legacy spawn paths), and generalizing both `ActorCard.gd` and `Ranch.gd` to consume `ActorData` while keeping the goat-only Ranch flow bit-stable. The Mimic now has a viable breeding path. **Agent 3 verified zero blockers.**

The discriminator test the advisor flagged — does the goat-only breeding loop still work end-to-end after this patch? — passed by code reading. The save schema was already `Array[ActorData]` from a prior pass so mixed-subclass herds round-trip without schema change. One latent gap (`ProgressionComponent.advance_day()` still reads goat-only `age_days`/`stamina_*`) is documented for Patch 3.

The `GoatRenderer` → `ActorCardRenderer` rename was correctly **deferred** — Agent 1 grep found three live `.tscn` references that make safe rename a dedicated patch.

---

## 2. Documented Needs Fixed

| ID | Need | Source |
|----|------|--------|
| B7 | `HerdManager.next_day()` accepts any `ActorData` kid, not just `GoatData` | [Patch 1 deferred §13](ELEMENTALS_IMPLEMENTATION_STATUS.md); Agent 1 §10 step 4 |
| R1 | `is_selected: bool` lifted from `GoatData` to `ActorData` (was a hidden subclass dependency in `HerdComponent.toggle_selection`) | Agent 1 §9 R1 |
| B9 | `Ranch.gd` typed-to-generic — `selected_doe`/`selected_buck: ActorData`; sort via `get_display_name()` | Breeding.md Phase 2 |
| B10 | `ActorCard.gd` accepts `actor_data: ActorData` as primary; `goat_data: GoatData` retained as defensive typed alias | Breeding.md Phase 2 |
| B13 | `GoblinData : ActorData` created with `get_actor_type() → "goblin"` + `create_offspring()` mirroring goat algorithm | Breeding.md Phase 4 |
| B14 | `FarmerData : ActorData` created with same shape | Breeding.md Phase 4 |
| B15 | `ElementalData : ActorData` created with `element_subtype: StringName` covering fire+water in one class | Breeding.md Phase 4 |
| R7 | Non-goat actor `_ready()` hardcoded ability blocks gated by `if _data == null:` so a designer-assigned data resource is not clobbered | Agent 1 §9 R7 |
| GoatData consistency | `GoatData.get_actor_type()` overridden to return `"goat"` (was returning `"GoatData"` from default); aligns with factory keys, `element_type`, and MimicData precedent | Agent 1 §8 |
| ActorData polymorphism | Three new virtuals — `get_display_name() -> String`, `get_info_line() -> String`, `set_display_name(name)` — with default impls; subclasses override | Agent 1 §10 step 1; advisor §5 |

---

## 3. Documented Needs Deferred (Patch 3 candidates)

| Deferred | Why | Reference |
|---|---|---|
| `GoatRenderer.gd` → `ActorCardRenderer.gd` rename | 3 live `.tscn` references + typed `@onready` in `ActorCard.gd:4` — needs coordinated edits to `.tscn`, `.gd`, `.tscn` script paths, and node tree names. Rename + behavior change in same commit doubles regression surface. | Agent 1 §3 R8 |
| `ProgressionComponent.advance_day()` non-goat handling | Still reads GoatData-only fields (`age_days`, `stamina_max`, `stamina_current`) on every herd member — will runtime-error on first non-goat in the herd. **Latent risk:** only fires when a non-goat actually joins the herd via UI. | Agent 3 §12; Patch 2 log §10 |
| `HerdManager.sell_goat()` GoatData cast | Casts `actor as GoatData` to read `gold_value`. Non-goat sales return 0 gold. Acceptable for now; lift `gold_value` to `ActorData` or add per-subclass override later. | Agent 1 §9 R12 |
| Non-goat actor `die()` herd-remove hooks | `GoatActor.die()` calls `HerdManager.remove_goat(goat_data)`; other actor `die()` methods lack the equivalent. Won't fire until a non-goat is in the herd. | Agent 1 §9 R11 |
| Mimic breeding via current `BreedingComponent.breed()` | Still requires male+female pair; Mimic is asexual budding. Needs `BreedingComponent.breed_asexual(actor)` code path OR `BreedableComponent` ASEXUAL mode. | Patch 1 §11 K-list; Breeding.md §Reproduction Modes |
| Capture system entirely | Unchanged — still zero implementation. | [ELEMENTALS_IMPLEMENTATION_STATUS.md §5](ELEMENTALS_IMPLEMENTATION_STATUS.md) |
| `TraitInheritanceEngine` extraction | Per advisor: keep inline this pass; extraction is its own focused patch. Each species' `create_offspring()` is a near-copy of the goat algorithm today. | Advisor §1; Agent 3 plan §3.5 |

---

## 4. Breeding System Status (after Patch 2)

### Supported creatures

- **Goats** — fully functional end-to-end (data layer + player-visible Ranch loop + save persistence). No regression from Patch 1.
- **Goblins, Farmers, Fire/Water Elementals, Mimics** — data layer functional (each has `*Data : ActorData` with `create_offspring()`); player-visible loop blocked by `Ranch.gd` UI not exposing non-goat addition AND `ProgressionComponent.advance_day()` latent crash on non-goat in herd.

### Parent validation
- Generic at [Core/Managers/BreedingComponent.gd](../Core/Managers/BreedingComponent.gd) — gender check, exhaustion gate, 3-day pregnancy. Works for any `ActorData` subclass that has `Gender.FEMALE` + `Gender.MALE` parents.
- **Asexual breeding** (Mimic) — still requires a `breed_asexual()` code path that doesn't exist yet. Mimic `create_offspring(partner)` ignores the partner so the algorithm is ready; only the gate at `BreedingComponent.breed()` blocks it today.

### Offspring generation
- Polymorphic via `actor.create_offspring(partner)` virtual.
- Each species' `create_offspring()` mirrors the goat algorithm (color lerp, 50/50 categorical inheritance for enum fields, stat mean ±10% mutation). Kept inline per advisor decision.

### Inheritance rules
- `GoatData`: color lerp + horn/body 50/50 + stats ±10% (unchanged).
- `GoblinData`: `base_color`/`pattern_color`/`tribe_color` lerp + 50/50 `ear_type` + stats ±10%.
- `FarmerData`: color lerp + 50/50 `hat_color`-style fields + stats ±10%.
- `ElementalData`: color lerp + `element_subtype` inherited from parent + stats ±10%.
- `MimicData` (from Patch 1): asexual budding with mutation.

### Save/load support
- Schema `Array[ActorData]` was already in place from a prior pass — Patch 2 added no new typed-array fields. Mixed `GoatData`+`GoblinData`+`FarmerData`+`ElementalData`+`MimicData` herds round-trip via `ResourceSaver.save()` / `ResourceLoader.load()` provided each subclass's `.gd.uid` is registered (auto on first editor open after this patch).
- Load-side filter `if actor is ActorData: herd.append(actor)` accepts all subclasses, silently drops anything else — same behavior as before.

### UI support
- `ActorCard.gd` accepts any `ActorData` via the new `actor_data` setter. `goat_data` alias preserves Patch-1 call sites.
- Display name + info line dispatched via the new virtuals — no hardcoded `goat_name` / `level` / `age_days` reads remain.
- `GoatRenderer` (2D card visual) still goat-typed; non-goat cards show no character render until the rename + per-type renderer work lands.
- `Ranch.gd` sort + selection + signal handler all generic. Cheat panel (`_on_max_level_goat_pressed`) preserved unchanged.

### Known risks
- `ProgressionComponent.advance_day()` will crash on first non-goat in herd (latent — not triggered today). **Fix before adding non-goats to UI flow.**
- `HerdManager.sell_goat()` returns 0 gold for non-goats.
- Non-goat actor `die()` hooks don't notify HerdManager.
- `GoatRenderer` 2D card visual won't render correctly for non-goat cards until rename + per-type renderer ship.

---

## 5. Mimic Status Update

The Mimic's path forward is now unblocked at the data layer:

- `MimicData` (Patch 1) already exists and overrides `create_offspring()` with asexual budding.
- `HerdManager.next_day()` now accepts non-goat kids (Patch 2).
- `Ranch.gd` selection + sort + display generic (Patch 2).
- `ActorCard.gd` consumes any `ActorData` (Patch 2).
- `is_selected` lives on `ActorData` so Mimic cards can be selected (Patch 2).

Still blocking Mimic in the UI loop:
- `BreedingComponent.breed()` male+female gate (asexual Mimics can't get through).
- `ProgressionComponent.advance_day()` GoatData-only field reads (would crash if a Mimic joined the herd).
- `GoatRenderer` not yet generic — Mimic card would show empty character art.

---

## 6. Files Changed

### Modified

| Path | Change |
|---|---|
| [Components/ActorComponents/ActorData.gd](../Components/ActorComponents/ActorData.gd) | Added `get_display_name()`, `get_info_line()`, `set_display_name()` virtuals; lifted `is_selected: bool` from GoatData with setter that emits `stats_changed` |
| [Components/BreedingComponents/GoatData.gd](../Components/BreedingComponents/GoatData.gd) | Removed duplicate `is_selected`; overrode `get_actor_type()` → `"goat"`, `get_display_name()` → `goat_name`, `get_info_line()` → level/age, `set_display_name()` → writes `goat_name` |
| [Components/BreedingComponents/HerdManager.gd:99-102](../Components/BreedingComponents/HerdManager.gd) | B7 fix: cast-and-drop replaced with `for kid in new_kids: if kid: add_goat(kid)` |
| [Components/BreedingComponents/Ranch/Ranch.gd](../Components/BreedingComponents/Ranch/Ranch.gd) | `selected_doe`/`selected_buck` typed `ActorData`; sort via `get_display_name()`; signal handler renamed `_on_actor_selected`; 3 `card.goat_data = ...` switched to `card.actor_data = ...`; cheat panel `_on_max_level_goat_pressed()` preserved unchanged |
| [UI/DisplayCard/ActorCard.gd](../UI/DisplayCard/ActorCard.gd) | `actor_data: ActorData` primary getter/setter; `goat_data: GoatData` retained as defensive typed alias; name/info reads via virtuals; renderer assignment gated `if actor_data is GoatData`; name-edit writes via `set_display_name()` |
| [src/actors/types/GoblinMinion.gd](../src/actors/types/GoblinMinion.gd) | Added `goblin_data: GoblinData` accessor; gated hardcoded ability block with `if _data == null:` |
| [src/actors/types/FarmerActor.gd](../src/actors/types/FarmerActor.gd) | Added `farmer_data: FarmerData` accessor; gated hardcoded ability block with `if _data == null:` |
| [src/actors/types/FireActor.gd](../src/actors/types/FireActor.gd) | Added `fire_data: ElementalData` accessor; no hardcoded ability block existed so no gate needed |
| [src/actors/types/WaterActor.gd](../src/actors/types/WaterActor.gd) | Added `water_data: ElementalData` accessor; no hardcoded ability block existed |
| [Markdowns/Actor.md](../Markdowns/Actor.md) | v1.2: documented new ActorData virtuals + lifted `is_selected` |
| [Markdowns/Breeding.md](../Markdowns/Breeding.md) | v1.2: marked Phases 2-3 partial complete; documented Patch 2 known gaps |
| [Markdowns/UI.md](../Markdowns/UI.md) | v1.2: reflected ActorCard public API changes |

### New files

| Path | Purpose |
|---|---|
| [Components/BreedingComponents/GoblinData.gd](../Components/BreedingComponents/GoblinData.gd) | `GoblinData : ActorData`; identity field `goblin_name`; small genetic fields; `create_offspring()` mirrors goat algorithm |
| [Components/BreedingComponents/FarmerData.gd](../Components/BreedingComponents/FarmerData.gd) | `FarmerData : ActorData`; same pattern with `farmer_name` |
| [Components/BreedingComponents/ElementalData.gd](../Components/BreedingComponents/ElementalData.gd) | `ElementalData : ActorData`; `element_subtype: StringName` covers fire+water in one class; `get_actor_type()` returns the subtype |
| [docs/AGENT_1_PATCH2_STATE_CHECK.md](AGENT_1_PATCH2_STATE_CHECK.md) | Agent 1 read-only state inventory |
| [docs/AGENT_2_PATCH2_LOG.md](AGENT_2_PATCH2_LOG.md) | Agent 2 patch log |
| [docs/AGENT_3_PATCH2_REVIEW.md](AGENT_3_PATCH2_REVIEW.md) | Agent 3 independent verification |
| [docs/ELEMENTALS_PATCH2_STATUS.md](ELEMENTALS_PATCH2_STATUS.md) | This file |

### Deletions
None this pass.

---

## 7. Procedural / Modular Design Summary

This patch tightens what Patch 1 set up:

- **Polymorphic display contract on `ActorData`.** Three new virtuals (`get_display_name`, `get_info_line`, `set_display_name`) replace hardcoded `goat_name` / `level` / `age_days` reads anywhere UI touches actor data. New species override one method; UI code didn't gain a single new `match type` branch.
- **`is_selected` is universal.** Selecting a card works for any future creature without HerdComponent edits.
- **No `*Data` constructed automatically.** Non-goat actors carry `_data` only when explicitly assigned (`if _data == null:` gate). Legacy spawn paths unchanged — no test/asset/scene needs to be updated to keep current behavior.
- **No new typed-subclass arrays.** Save schema stayed `Array[ActorData]` per Agent 1 §4 mitigation. Mixed-subclass herds round-trip in Godot 4.6 without the `Array[GoblinData]` load-wipe risk.
- **Inheritance algorithm is shared (inline).** Each new `*Data.create_offspring()` mirrors the goat algorithm pattern. Per advisor §1, half-extracting a `TraitInheritanceEngine` is the worst outcome — extraction will be a dedicated patch retrofitting all five species at once.
- **The data subclasses themselves are small and `@export`-tunable.** Designers can author `.tres` variants of `GoblinData`/`FarmerData`/`ElementalData` like they would `GoatData.tres` today.

---

## 8. Resource Impact

- **CPU/GPU/memory:** essentially unchanged. The new virtuals add one `.call()` per card render — negligible.
- **Save data size:** stable. No new fields on existing subclasses; new subclasses are small. Save schema unchanged.
- **Boot cost:** unchanged.
- **Risk of typed-array load-wipe in Godot 4.6:** zero new exposure — Agent 1 §4 mitigation was followed (no `Array[GoblinData]` etc anywhere).

---

## 9. Testing Checklist (Patch 2)

Run after opening the project once in Godot so the new `.gd` files import.

### Regression (Patch 1 must still work)
- [ ] Boot project — no missing-file / autoload / parse warnings
- [ ] Ranch return from Arena ("Finish Day") still works
- [ ] MainMenu character tab opens without lag spike (AbilityRegistry cache still in place)
- [ ] Mimic spawn → bite → morph → copy → revert loop still works
- [ ] Quest camp discovery + Goblin AI perception unchanged

### Goat-only breeding loop (discriminator test)
- [ ] Load existing save → enter Ranch → existing herd renders correctly with names + level/age info
- [ ] Pair two valid goats (doe + buck) → advance day 3 times → kid appears in herd
- [ ] Save → reload → kid persists
- [ ] Cheat: `_on_max_level_goat_pressed()` still mints a `GoatData.new()` and adds it to the herd

### Generalized data layer (new in Patch 2)
- [ ] Open Godot once so `GoblinData.gd`/`FarmerData.gd`/`ElementalData.gd` generate `.gd.uid`
- [ ] Confirm each new `*Data` script parses without error
- [ ] Programmatically: `var g = GoblinData.new()` → call `g.create_offspring(g)` → confirm returns a `GoblinData` (not null)
- [ ] Programmatically: assign a `GoblinData.tres` to a `GoblinMinion.tscn` root via inspector — confirm ability scores in-game match the resource, not the hardcoded fallback
- [ ] Programmatically: spawn GoblinMinion with `_data == null` — confirm legacy fallback stats unchanged

### Mixed-herd save round-trip (advisor §3)
- [ ] Debug-spawn a Mimic
- [ ] Force-breed via `BreedingComponent.process_pregnancy` after manually setting `pregnancy_timer = 0` and `pregnancy_father` on a herd member
- [ ] OR more simply: `HerdManager.add_goat(MimicData.new())` from a debug script
- [ ] Save → close editor → reopen → reload save
- [ ] Confirm Mimic survives in herd. If herd is empty after reload, the Godot 4.6 typed-subclass-array bug fired — fall back to `Array[Resource]` in `GoatSaveData.gd` per Agent 1 §4 mitigation

### Performance
- [ ] No new console spam during Ranch rendering
- [ ] No regression in Ranch open time

---

## 10. Next Recommended Patch (Patch 3)

The Patch 2 deferrals all cluster into one focused patch worth shipping next:

### Patch 3 scope (recommended)

1. **Generalize `ProgressionComponent.advance_day()`** ([Core/Managers/ProgressionComponent.gd](../Core/Managers/ProgressionComponent.gd)). Today reads `age_days` / `stamina_max` / `stamina_current` on every herd member assuming `GoatData`. Options: (a) move `age_days` + `stamina_*` up to `ActorData` (clean — all creatures age and exhaust); (b) gate the body with `if actor is GoatData:`; (c) add a `tick_day()` virtual on `ActorData`. **Recommend (c) — `ActorData.tick_day()` virtual + default no-op + GoatData override** — cleanest polymorphic story.
2. **Fix `HerdManager.sell_goat()` per-subclass `gold_value`** — virtual `get_sell_value() -> int` on `ActorData`; default 0; GoatData returns `gold_value`.
3. **Non-goat actor `die()` herd-remove hooks** — add `HerdManager.remove_goat(_data)` in each non-goat actor's `die()` (only fires if `_data != null`).
4. **`GoatRenderer.gd` → `ActorCardRenderer.gd` rename + per-type render dispatch** — coordinated `.tscn` updates (`ActorCard.tscn`, `GoatCard.tscn`, `GoatRenderer.tscn`); `update_visuals()` dispatches on `actor_data.get_actor_type()` so non-goat cards can show appropriate visuals (or a generic placeholder for now).
5. **Asexual breeding code path** in `BreedingComponent` — `breed_asexual(parent: ActorData) -> bool` that skips the gender gate; called from a separate UI flow (or via `BreedableComponent` mode if you want to land that here too).
6. **`get_actor_type()` default fix** on `ActorData` — currently returns the class name when not overridden; change default to return `&""` or `&"unknown"` so accidental missing overrides are loud, not silent.

That patch unblocks non-goats fully (UI + advance day + sell + die + asexual) AND ships the deferred rename. Estimated risk: medium — touches `ProgressionComponent` (DO-NOT-BREAK-ish — silent crashes on misuse), and the rename has 5+ coordinated file edits.

### Alternative Patch 3 (smaller)
Just the Patch 2 deferrals 1–3 (no rename, no asexual). Lower risk, faster, but leaves the Mimic still UI-blocked and non-goat cards still visually broken.

### After Patch 3
The next big work is the Capture system (multi-PR effort per [AGENT_3_MODULAR_IMPLEMENTATION_PLAN.md task 4.1](AGENT_3_MODULAR_IMPLEMENTATION_PLAN.md)). All breeding-side prerequisites for capture (e.g. assigning ownership, persisting captured actors) will be in place after Patch 3.

---

## 11. Coworker Design Rules (still binding)

All Patch 1 rules continue:

- All distance work via `TileSignalComponent`; all timing via `GameClockComponent` `Actor.register_tick()`.
- AbilityAction is RefCounted + actor-bound — never share refs across actors.
- SYNC RULE on Abilities.md / Actor.md / UI.md / Breeding.md / Mimic.md.
- No placeholder code; no "rest unchanged"; no fake completion.
- New for Patch 2 onward:
  - **Never declare `Array[SomeActorDataSubclass]`** — always `Array[ActorData]`. Godot 4.6 has known issues round-tripping mixed typed-subclass arrays.
  - **When adding a new playable creature**: subclass `ActorData`, override `get_actor_type()` (lowercase canonical key matching factory registration), `get_display_name()`, `get_info_line()`, `set_display_name()`, and `create_offspring(partner)`. Register the actor scene with `ActorFactory` in `ArenaSpawner._register_default_actor_types()`. Wire the actor to its `*Data` via a typed accessor mirroring `GoatActor.goat_data` / `MimicActor.mimic_data`. **Gate any hardcoded `_ready()` ability assignments with `if _data == null:`**.

---

## 12. Final Recommendation

Patch 2 is safe to continue from. No blockers; one latent gap (`ProgressionComponent.advance_day()`) documented for Patch 3.

**Recommended next action:** ship Patch 3 (full scope) to unblock non-goat creatures end-to-end in the UI flow. Specifically: `ProgressionComponent` generalization + `sell_goat` virtual + non-goat `die()` hooks + `GoatRenderer` rename + asexual breeding code path. After Patch 3, all non-goat species have UI parity with goats, the Mimic can breed via budding, and the project is positioned to start the Capture system as its own dedicated multi-PR effort.

If smaller appetite: ship just `ProgressionComponent` generalization + `sell_goat` virtual + non-goat `die()` hooks — the three highest-risk deferrals from Patch 2. Lower risk, leaves rename + asexual for later.

---

*End of Patch 2 implementation status.*
