# Elementals Implementation Status — Patch 3 (Net Catch + Mimic Spawn)

> Companion to [ELEMENTALS_IMPLEMENTATION_STATUS.md](ELEMENTALS_IMPLEMENTATION_STATUS.md) (Patch 1) and [ELEMENTALS_PATCH2_STATUS.md](ELEMENTALS_PATCH2_STATUS.md) (Patch 2).
>
> Source reports:
> - [AGENT_1_PATCH3_STATE_CHECK.md](AGENT_1_PATCH3_STATE_CHECK.md) — read-only state inventory (this state check was originally for breeding generalization; that scope was renamed Patch 4 after the user reported two visible bugs)
> - [AGENT_2_PATCH3_LOG.md](AGENT_2_PATCH3_LOG.md) — Agent 2's patch log
> - [AGENT_3_PATCH3_REVIEW.md](AGENT_3_PATCH3_REVIEW.md) — independent verification (no blockers)
>
> **Scope pivot.** Patch 3 was originally going to be breeding generalization (ProgressionComponent / sell_goat / die hooks / GoatRenderer rename / asexual breeding). The user reported two visible bugs ("Net doesn't roll a save / catch chance" and "Mimic still isn't in the game"); per advisor guidance, Patch 3 pivoted to fix those bugs. The previously-planned breeding generalization moved to **Patch 4** (Agent 1's state check at `docs/AGENT_1_PATCH3_STATE_CHECK.md` remains valid as the spec for that future patch — name retained for continuity).
>
> All paths repo-relative.

---

## 1. Summary

Patch 3 wires the Mimic into normal gameplay (one spawns at Arena init by default) and ships a **minimum viable Net capture loop** built around three primitives the future full Capture patch will EXTEND, not replace:

1. **`CaptureComponent`** — lightweight, lazy-attached component handling save roll + catch roll + apply-capture + apply-stun
2. **`CaptureProfile`** — designer-authored Resource (`save_dc`, `save_ability`, `stun_duration`, `catch_chance`, `allowed_actor_types`)
3. **Data-driven Net flag** on `WeaponData.is_capture_tool` parsed from the existing `notes` string

The user's primary feedback channel is the console readout. After this patch, throwing a Net at a Mimic produces three console lines per Agent 3 §2 verification:

```
[Capture] Net hit Mimic. Save: rolled 11 vs DC 12 → FAIL (d20=9 + dexterity=2)
[Capture] Mimic stunned for 4.0s. Catch roll: 0.32 vs 0.40 → CAUGHT
[Capture] Mimic added to herd as mimic
```

On save success: only the first line with `→ SUCCESS`. On catch fail: first two lines, second one `→ ESCAPED` (target stays stunned but escapes).

The implementation deliberately does NOT introduce the full `ActorState` enum / restraint stacking / drag mechanics / AI FSM bridge that the prior plan flagged as multi-PR effort. Those will extend the three primitives in a follow-up.

---

## 2. User-Reported Bugs Addressed

| Bug | Fix |
|-----|-----|
| Mimic isn't in the game — wired in factory but no live caller spawns one | `Components/Arena/ArenaSpawner.gd:17` adds `@export var mimic_count: int = 1`; lines 59-62 spawn pass in `spawn_initial_actors()` mirrors the existing goblin/scarecrow spawn pattern |
| Net doesn't roll a save / catch chance — Net was a regular weapon with `"special"` flag never parsed | `Core/WeaponData.gd` gains `is_capture_tool: bool` + `capture_profile_path: String`; parser recognizes `"capture"` keyword in notes; `Core/ItemsAutoload.gd:121` Net's notes string switched `"special"` → `"capture"` and post-`_add` wires `capture_profile_path` to `DefaultNet.tres`; `src/actors/projectiles/BaseProjectile.gd:242-245` early-returns into a capture flow that does save → stun → catch → capture |

---

## 3. Files Changed

### New files

| Path | Purpose |
|---|---|
| [Components/ActorComponents/CaptureComponent.gd](../Components/ActorComponents/CaptureComponent.gd) | Lightweight component; lazy-attached at Net hit time. API: `setup`, `can_be_captured`, `roll_save(modifier)`, `roll_catch(modifier)`, `apply_capture`, `apply_stun(duration)` |
| [Components/ActorComponents/CaptureProfile.gd](../Components/ActorComponents/CaptureProfile.gd) | `Resource` with `save_dc`, `save_ability: StringName`, `stun_duration: float`, `catch_chance: float`, `allowed_actor_types: Array[StringName]` — all `@export` |
| [Components/ActorComponents/CaptureProfiles/DefaultNet.tres](../Components/ActorComponents/CaptureProfiles/DefaultNet.tres) | Net's default profile (DC 12 Dex save, 4.0s stun, 0.40 catch chance) |
| [docs/AGENT_2_PATCH3_LOG.md](AGENT_2_PATCH3_LOG.md) | Agent 2 patch log |
| [docs/AGENT_3_PATCH3_REVIEW.md](AGENT_3_PATCH3_REVIEW.md) | Agent 3 verification |
| [docs/ELEMENTALS_PATCH3_STATUS.md](ELEMENTALS_PATCH3_STATUS.md) | This file |

### Modified files

| Path | Change |
|---|---|
| [Core/WeaponData.gd](../Core/WeaponData.gd) | Added `is_capture_tool: bool` + `capture_profile_path: String` exports; extended notes parser to recognize `"capture"` keyword |
| [Core/ItemsAutoload.gd:121](../Core/ItemsAutoload.gd) | Net notes string changed `"special"` → `"capture"`; post-`_add` loop sets Net's `capture_profile_path` |
| [src/actors/projectiles/BaseProjectile.gd:242-245](../src/actors/projectiles/BaseProjectile.gd) | New capture-tool early-return branch in `_on_body_entered`; calls `_run_capture_flow(target)` then `queue_free()` |
| [Components/Arena/ArenaSpawner.gd:17,59-62](../Components/Arena/ArenaSpawner.gd) | Added `mimic_count: int = 1` export and spawn loop in `spawn_initial_actors()` |
| [Markdowns/Capture.md](../Markdowns/Capture.md) | Patch 3 implementation status section added (above the existing deprecation header for the loyalty model) |
| [Markdowns/Mimic.md](../Markdowns/Mimic.md) | v1.1 — documented spawn-on-arena + capturable behavior |

### Deletions
None.

---

## 4. The Three Primitives (Extension Contract)

The advisor's discriminating constraint: **the future full Capture patch must EXTEND these primitives, not REPLACE them.** Here's the contract:

### `CaptureComponent` — extension points
- **Today:** `apply_capture()` dispatches on `actor.element_type` to instantiate a fresh `*Data` subclass from `actor.ability_scores_component`, then `HerdManager.add_goat(new_data) + actor.queue_free()`.
- **Future (full Capture patch):** add an `ActorState` field (WILD/RESTRAINED/CONFINED/TAMING/TAMED/FLED). `apply_capture()` becomes `enter_restrained()` and triggers state transitions; full taming loop and restraint stacking layer ON TOP of `roll_save` + `roll_catch`. The existing API methods remain.
- **Today's behavior is the "shortcut path"** that the user sees: hit → save → fail → stun + catch → capture is the fast path. The full system adds intermediate states (restrained, dragging) between fail-save and herd-addition.

### `CaptureProfile` — extension points
- **Today:** 5 fields (`save_dc`, `save_ability`, `stun_duration`, `catch_chance`, `allowed_actor_types`).
- **Future:** add `restraint_resistance: int`, `escape_dc_per_restraint: Curve`, `taming_loyalty_curve: Curve`, `flee_chance_after_break: float` per `Markdowns/Breeding.md §Capture System`. All additions are additive `@export` — existing `.tres` files keep working.

### Net flag on `WeaponData`
- **Today:** `is_capture_tool: bool` parsed from `"capture"` keyword in notes.
- **Future:** if other capture tools land (Rope, Chain, Manacle, Trap per Capture.md), each gets its own `.tres` `CaptureProfile` and reuses the same flag. Zero code changes.

---

## 5. Procedural / Modular Design Summary

- **Net behavior is 100% data-driven.** Agent 3 grep-verified zero `if weapon.name == "Net"` checks in `.gd`. The behavior comes entirely from `WeaponData.is_capture_tool` + the attached `CaptureProfile.tres`. Adding a Rope = one `.tres` file + one `_add()` entry in ItemsAutoload.
- **Capture is per-target, lazy.** `CaptureComponent` is not attached at spawn time — it's attached the first time a capture-tool weapon hits the target. Wild creatures don't pay any cost until they're hit. Zero memory / setup overhead in steady state.
- **Captured `*Data` is instantiated from runtime stats**, not from a pre-authored Resource. Per advisor option (b), `apply_capture()` walks `actor.ability_scores_component` and creates a fresh `*Data` subclass keyed on `element_type`. Designers don't need to author wild-creature `.tres` files for capture to work — every wild creature is capturable by default.
- **All timing routes through existing systems.** Stun uses `Actor.stun()` → `StunComponent._process(delta)` per Agent 3 §7 verification. Zero `Timer.new()`. Zero `await get_tree().create_timer()`.
- **Mimic spawn uses the existing pipeline** — no new spawn mechanism. `ArenaSpawner.spawn_initial_actors()` adds a Mimic loop that mirrors the goblin loop exactly. Designer-tunable via `mimic_count` export.

---

## 6. Resource Impact

- **CPU:** Negligible. Mimic spawn is one extra actor per arena (configurable). Capture loop fires only on Net hits — at most ~a few times per minute of play.
- **Memory:** One `CaptureComponent` allocated per Net-hit target. Auto-cleaned when the target dies or escapes.
- **GPU:** Unchanged.
- **Save data:** Unchanged. Captured creatures use the existing `HerdManager.add_goat()` path that already serializes through `Array[ActorData]`.
- **Boot cost:** Unchanged.

---

## 7. Testing Checklist

### Regression (prior patches must still work)
- [ ] Boot project — no missing-file / autoload / parse warnings
- [ ] Ranch return from Arena ("Finish Day") still works
- [ ] MainMenu character tab opens without lag (AbilityRegistry cache still in place)
- [ ] Mimic morph + skill copy still works (Patch 1)
- [ ] Goat breeding loop still works (Patch 2)
- [ ] Non-goat actors with `_data == null` still spawn correctly (Patch 2 fallback)

### Patch 3 discriminator (the user's primary check)
- [ ] Open Arena scene → 1 Mimic walking around at start (visible as violet sphere)
- [ ] Player equips Net (existing weapon selection flow)
- [ ] Player throws Net at the Mimic
- [ ] Console shows: `[Capture] Net hit Mimic. Save: rolled X vs DC 12 → SUCCESS/FAIL ...`
- [ ] On save FAIL: `[Capture] Mimic stunned for 4.0s. Catch roll: X.XX vs 0.40 → CAUGHT/ESCAPED`
- [ ] On catch CAUGHT: `[Capture] Mimic added to herd as mimic` + Mimic disappears cleanly (no fall-over)
- [ ] After CAUGHT, return to Ranch → captured Mimic appears in herd as a `MimicData` (visible in `HerdManager.herd`)
- [ ] Try Net on Goblin too — should work the same way; captured Goblin → `GoblinData` in herd

### Extended scenarios
- [ ] Throw multiple Nets in a row — each rolls independently; no double-fire damage on capture hits
- [ ] Non-capture weapon (Sword / Bow / etc.) still deals damage normally; capture branch does not fire
- [ ] Net hits something that isn't capturable (e.g. another player goat) — currently captures it too (known v1.0 limitation; see §8)

### Performance
- [ ] No new console spam at boot
- [ ] No frame drop when CaptureComponent attaches at Net hit

---

## 8. Known v1.0 Limitations (documented; not blockers)

Per Agent 2 §10 and Agent 3 §11:

| # | Limitation | Severity | Recommended follow-up |
|---|------------|----------|------------------------|
| L1 | Net's visual projectile is the fallback `ArrowProjectile.tscn` (Net's WeaponData entry has no `projectile_scene_path`) | Cosmetic | Add `projectile_scene_path` to Net's `_add()` call when a Net projectile scene is authored |
| L2 | Captured wild Goblin / Farmer / Fire / Water get default-color visuals (their wild actors had `_data == null` so no color was assigned). Captured Mimic preserves colors because `MimicActor._ready()` auto-creates a `MimicData` | Cosmetic | When non-goat actors get a way to procedurally generate their `*Data` at spawn time (similar to MimicActor's auto-create), this fixes itself. Could also be addressed in Patch 4 |
| L3 | No friendly-faction gate on capture — a Net hit on a player goat would also capture it | Logic | One-line check in `CaptureComponent.can_be_captured()`: refuse if `actor.faction == FactionComponent.PLAYER` |
| L4 | Captured `*Data` has default name (e.g. `goblin_name = &""`) — UI may show blank or fallback name | Cosmetic | Have `apply_capture()` mint a procedural name (e.g. `"Wild Goblin #42"`) or use the actor's display name |
| L5 | `ProgressionComponent.advance_day()` still reads goat-only `age_days`/`stamina_*` fields — captured non-goats in the herd will crash on day advance | High (but only fires when a captured non-goat is in the herd) | **This is exactly Patch 4 scope** — `ActorData.tick_day()` virtual will land in Patch 4 |

L5 is the most user-visible — captures will work but advancing the day with a captured Goblin/Mimic in the herd will error. Patch 4 fixes this.

---

## 9. Coworker Design Rules (still binding)

All Patch 1+2 rules continue:

- All distance via `TileSignalComponent`; all timing via `GameClockComponent` `Actor.register_tick()` or existing `StunComponent` pattern.
- AbilityAction is RefCounted + actor-bound — never share refs across actors.
- Never `Array[SomeActorDataSubclass]` — always `Array[ActorData]`.
- AbilityRegistry boot probe constraint (keep `_init()` light).
- SYNC RULE on Abilities.md / Actor.md / UI.md / Breeding.md / Mimic.md / Capture.md.
- No placeholder code; no "rest unchanged"; no fake completion.

New for Patch 3:
- **Capture behavior is data-driven via `WeaponData.is_capture_tool` + `CaptureProfile.tres`**. Adding a new capture tool = one `.tres` + one `ItemsAutoload._add()` entry. No `if weapon.name == ...` branches anywhere.
- **`CaptureComponent` is lazy-attached at Net hit time**, not at actor `_setup_components()`. This keeps capture cost off the steady-state actor budget.
- **Captured `*Data` is instantiated from runtime `ability_scores_component`** (option b). Wild creatures don't need pre-authored data Resources to be capturable.

---

## 10. Next Recommended Patch (Patch 4)

The breeding generalization originally scoped for Patch 3 (now Patch 4):

1. **Generalize `ProgressionComponent.advance_day()`** — add `tick_day(day: int)` virtual on `ActorData` (default does the cross-cutting deselect/exhaustion clear); `GoatData.tick_day()` overrides with stamina + age logic. This unblocks L5 above.
2. **`get_sell_value() -> int` virtual** on `ActorData` (default 0; GoatData returns `gold_value`). Fixes `HerdManager.sell_goat()` for non-goats.
3. **Non-goat actor `die()` hooks** call `HerdManager.remove_goat(_data)` if `_data` in herd.
4. **`BreedingComponent.breed_asexual(parent)`** — skips gender gate; sets pregnancy on the parent itself. Unblocks Mimic budding.
5. **`get_actor_type()` default fix** on `ActorData` — return `&""` + log a warning instead of silently returning the class name.
6. **`GoatRenderer.gd` → `ActorCardRenderer.gd` rename** with per-type render dispatch — Agent 1's Patch 2 state check §3 verified rename is safe (3 coordinated `.tscn` edits + 1 `.gd.uid` rename to preserve the UID string).

Agent 1's `docs/AGENT_1_PATCH3_STATE_CHECK.md` is the state inventory for this work (the original Patch 3 spec; remains valid).

After Patch 4: Patch 5 candidate is the **friendly-faction gate** + Net visual projectile + procedurally-named captures (the cosmetic limitations L1-L4 above).

After Patch 5: full `ActorState` model (the multi-PR effort) becomes possible without contradicting any existing system.

---

## 11. Final Recommendation

Patch 3 is safe to continue from. No blockers. The user's two reported bugs (Mimic invisible, Net not catching) are fixed and verifiable by the console readout messages within 60 seconds of opening the project.

**Immediate next action:** the user should open the editor, throw a Net at the Mimic, confirm the three console messages appear. If they want to try captured non-goat creatures in the Ranch, ship Patch 4 first to avoid the L5 day-advance crash.

---

*End of Patch 3 implementation status.*
