# Agent 3 — Patch 2 Review (Breeding Generalization)

> Verification pass for the Patch 2 breeding generalization. All file
> inspections performed against the post-patch tree at HEAD `7c3b0b2`.
> All paths repo-relative.

---

## 1. Implementation Reviewed (file inspection list)

Files opened and read in full or in the relevant range:

- `Components/ActorComponents/ActorData.gd` (130 lines, full)
- `Components/BreedingComponents/GoatData.gd` (114 lines, full)
- `Components/BreedingComponents/HerdManager.gd` (109 lines, full)
- `Components/BreedingComponents/Ranch/Ranch.gd` (149 lines, full)
- `Components/BreedingComponents/GoblinData.gd` (96 lines, full — new)
- `Components/BreedingComponents/FarmerData.gd` (72 lines, full — new)
- `Components/BreedingComponents/ElementalData.gd` (95 lines, full — new)
- `UI/DisplayCard/ActorCard.gd` (230 lines, full)
- `UI/DisplayCard/DisplayCardBase.gd` (56 lines, full)
- `UI/GoatRenderer.gd` (46 lines, full)
- `src/actors/types/GoblinMinion.gd` (154 lines, full)
- `src/actors/types/FarmerActor.gd` (45 lines, full)
- `src/actors/types/FireActor.gd` (35 lines, full)
- `src/actors/types/WaterActor.gd` (69 lines, full)
- `src/actors/base/Actor.gd` (lines 1–230)
- `Core/Managers/SaveComponent.gd` (51 lines, full)
- `Core/GoatSaveData.gd` (7 lines, full)
- `Core/Managers/BreedingComponent.gd` (55 lines, full)
- `Core/Managers/HerdComponent.gd` (71 lines, full)
- `Core/Managers/ProgressionComponent.gd` (26 lines, full)
- `Markdowns/Actor.md`, `Markdowns/Breeding.md`, `Markdowns/UI.md` (header + relevant sections via grep)

Greps run:

- `Array\[GoblinData\]|Array\[FarmerData\]|Array\[ElementalData\]|Array\[MimicData\]` — zero live hits (only AGENT_1 spec doc mentions them).
- `ActorCardRenderer` — zero code hits, only in docs/spec.
- `GoatRenderer` — definition + 3 live `.tscn` refs + ActorCard.gd @onready, unchanged.
- `is_selected` in `GoatData.gd` — only a NOTE comment; field removed cleanly.

---

## 2. Documented Needs Addressed (vs Agent 1 §10 strict order + R1–R12)

| Step (Agent 1 §10) | Status | Notes |
|---|---|---|
| 1. Add `get_display_name() -> String` virtual to ActorData | PASS | `ActorData.gd:114-115`, default returns `get_actor_type()` |
| 2. Lift `is_selected` from GoatData → ActorData | PASS | `ActorData.gd:76-80`; `GoatData.gd:63-64` has explicit NOTE comment, no duplicate field |
| 3. Override `get_actor_type()` on GoatData → `"goat"` + add display virtuals | PASS | `GoatData.gd:75-91` |
| 4. Fix HerdManager.next_day B7 | PASS | `HerdManager.gd:99-102` — `for kid in new_kids: if kid: add_goat(kid)` |
| 5. Create GoblinData, FarmerData, ElementalData | PASS | All three exist, no `is_selected` re-declared, all override `create_offspring`/`get_actor_type`/`get_display_name`/`set_display_name` |
| 6. Wire non-goat actors to `*Data` via `_data` accessor + gate hardcoded blocks | PASS | GoblinMinion `goblin_data`, FarmerActor `farmer_data`, FireActor `fire_data`, WaterActor `water_data`; goblin + farmer stat blocks gated by `if _data == null:` |
| 7. Generalize ActorCard | PASS | `actor_data: ActorData` primary; `goat_data: GoatData` alias retained; renderer gated `if actor_data is GoatData`; virtuals used |
| 8. Generalize Ranch | PASS | `selected_doe/buck: ActorData`; sort via `get_display_name()`; signal handler renamed `_on_actor_selected`; assignments switched to `card.actor_data = ...`; cheat panel preserved |
| 9. GoatRenderer rename — SKIP | PASS | Filename, `class_name`, and `.tscn` references all intact |
| 10. Save round-trip smoke test | DEFERRED | Code-review only; in-editor verification required (see §3 below) |
| 11. Manual integration test (goblin in herd) | DEFERRED | Requires editor session — flagged for human |

| Risk | Status | Notes |
|---|---|---|
| R1 — `is_selected` lifted | RESOLVED | `ActorData.gd:76-80`; HerdComponent.toggle_selection unchanged + still works |
| R2 — ActorCard goat-only field reads | RESOLVED | All reads now via `get_display_name()` / `get_info_line()`; minor cosmetic regression (gender prefix gone from goat info line) — acceptable per spec |
| R3 — `is_exhausted` already on ActorData | N/A | No change required, confirmed |
| R4 — cheat panel preserved | RESOLVED | `Ranch.gd:134-148` unchanged; still mints `GoatData.new()` |
| R5 — `card.goat_data = goat` brittleness | RESOLVED | Three Ranch assignments switched to `card.actor_data = ...`; alias kept on ActorCard for legacy reads |
| R6 — OptionsMenu `gc.goat_data` | N/A | Agent 2 confirmed `gc` is GeneticComponent (not ActorCard); no touch needed |
| R7 — non-goat actor hardcoded stats clobber resource | RESOLVED | `if _data == null:` gates added in GoblinMinion (line 38) and FarmerActor (line 24); FireActor/WaterActor never had ability_scores hardcodes |
| R8 — GoatRenderer rename unsafe | RESPECTED | Rename deferred; documented in Breeding.md and Patch 2 log §10 |
| R9 — CHARACTER_EQUIPMENT duplicate | OUT OF SCOPE | Untouched, as required |
| R10 — save round-trip needs editor | OPEN | Code-only verdict in §3 |
| R11 — non-goat actor `die()` lacks herd-remove hook | DEFERRED | Documented as Patch 2 known gap in Breeding.md:821 |
| R12 — sell_goat returns 0 gold for non-goats | DEFERRED | Documented as Patch 2 known gap; unchanged in HerdManager.gd:84-89 |

---

## 3. Save Round-Trip Verification (independent take)

I traced `SaveComponent.gd` + `GoatSaveData.gd` independently of Agent 2's analysis. Findings:

- `GoatSaveData.herd: Array[ActorData]` (Core/GoatSaveData.gd:4) is the same generic typed array it was pre-patch. Patch 2 introduced zero schema changes.
- `_perform_save_deferred(herd: Array[ActorData], ...)` writes a fresh `GoatSaveData` via `ResourceSaver.save()`. Each entry serializes as a SubResource with a `script` pointer. The new `GoblinData`/`FarmerData`/`ElementalData` `class_name`s require `.gd.uid` files (auto-generated on first editor open) for the most portable on-disk form, but Godot will fall back to literal `res://` path persistence on the same machine if UIDs are absent.
- `load_game()` (SaveComponent.gd:25-50) filters `if actor is ActorData: converted_herd.append(actor)`. All five subclasses (Goat, Mimic, Goblin, Farmer, Elemental) pass this `is ActorData` check. **The filter is forgiving — but it silently drops entries whose script can't resolve.** If a save built on this branch is loaded on a branch missing one of the new `*Data` scripts, that subclass's entries vanish from the herd with no warning. This is pre-existing behavior, not a Patch 2 regression.
- **Verdict matches Agent 2's verdict.** Round-trip should work for both goat-only saves (no change from pre-patch) and mixed-subclass saves once Godot has indexed the three new `.gd.uid` files. Known Godot 4.6 "typed-subclass-array load wipe" bug is the only realistic failure mode and remains a flagged risk requiring in-editor verification.
- **No code change required in this patch** for the save path.

---

## 4. Goat-Only Regression Trace (step-by-step + verdict)

Traced the full goat breeding loop by code reading. Each step verified against current files.

1. **MainMenu → "goat" selection** — no breeding code touched; Patch 2 did not modify `UI/MainMenu.gd` or `ACTOR_SCENES`. PASS.
2. **Enter Arena → spawn GoatActor** — `GoatActor.goat_data: GoatData` accessor unchanged (out of scope, Agent 1 §7). `Actor._data` setter + `_on_data_changed()` flow unchanged. PASS.
3. **"Finish Day" → ArenaUIHandler** — out of scope, untouched. PASS.
4. **Enter Ranch.tscn → `_ready()`** — connects `GameEvents.herd_updated → refresh_ui`. PASS.
5. **`refresh_ui()` sort** — `sorted_herd.sort_custom(func(a,b): return a.get_display_name() < b.get_display_name())`. GoatData override returns `goat_name`; sort order identical to old `a.goat_name < b.goat_name`. PASS.
6. **Card construction** — `card.actor_data = actor` for each goat. `actor_data` setter calls `setup(v)` → `data_resource = v` (via super.setup). Renderer gate: `actor_data is GoatData == true` → `actor_renderer.goat_data = actor_data` succeeds (typed `GoatData` setter accepts GoatData input). PASS.
7. **Card display** — `name_edit.text = actor_data.get_display_name()` returns `goat_name`. `info_label.text = actor_data.get_info_line()` returns `"Lvl: %d - Age: %d" % [level, age_days]`. **Cosmetic difference vs pre-patch:** old format prepended `"Female - "` / `"Male - "`. Agent 2 acknowledged this in §9. Gender remains visible via doe/buck container split. ACCEPTABLE.
8. **Card selection** — `card.selected.emit(data_resource)` (DisplayCardBase.gd:44) carries a `Resource` parameter; Ranch's `_on_actor_selected(actor: ActorData)` receives it. Godot 4.x signal connection performs an implicit cast on the receiving end; since `data_resource` is always an `ActorData` subclass for these cards, this works. `selected_doe = actor` is a widening cast (ActorData ← GoatData), always safe. PASS.
9. **Breed** — `HerdManager.breed(selected_doe, selected_buck)` → `BreedingComponent.breed(parent_a, parent_b)`. Reads only `gender`, `is_exhausted` (both on ActorData). Sets `is_pregnant`, `pregnancy_timer`, `pregnancy_father` (all on ActorData). PASS.
10. **3 day_advanced ticks** — `HerdManager.next_day()` → `progression_manager.advance_day(herd)`. **For goat-only herd this still works** because every member has `age_days`/`stamina_current`/`stamina_max`. Then `breeding_manager.process_pregnancy(herd)` decrements `pregnancy_timer`, calls `actor.create_offspring(partner)` → GoatData kid. PASS.
11. **`for kid in new_kids: if kid: add_goat(kid)`** — was previously `var goat_kid = kid as GoatData; if goat_kid: add_goat(goat_kid)`. For a GoatData kid the behavior is identical (kid passes the truthiness check; `add_goat()` already takes ActorData). PASS.
12. **Save** — `GameEvents.herd_updated` → `HerdManager.save_game()` → `SaveComponent.save_game(herd, gold, day)`. Same Resource shape as before. PASS.
13. **Reload** — `ResourceLoader.load()` → `GoatSaveData.herd` deserialized → filter accepts all GoatData entries. PASS.

**Verdict: No goat-only regression found** except the documented cosmetic info-line gender-prefix drop. No BLOCKER.

---

## 5. Non-Goat Wiring Verification (`if _data == null` gate)

Critical gate check — Agent 1 R7 mitigation.

| File | Hardcoded stat block | `if _data == null:` gate | Verdict |
|---|---|---|---|
| `src/actors/types/GoblinMinion.gd:38-44` | strength=-1, dex=2.5, ... | YES (line 38) | PASS |
| `src/actors/types/FarmerActor.gd:24-30` | all zeros | YES (line 24) | PASS |
| `src/actors/types/FireActor.gd` | none (no ability_scores writes in `_ready()`) | N/A — no gate needed | PASS |
| `src/actors/types/WaterActor.gd` | none | N/A — no gate needed | PASS |

Verified that `Actor._ready()` (Actor.gd:186-194) calls `_setup_components()` BEFORE `_on_data_changed()`. So when a non-goat actor with `_data` assigned runs `super._ready()`: (1) components instantiated, (2) `_on_data_changed()` syncs ability scores from `_data`, (3) the gated block in the subclass `_ready()` is skipped because `_data != null`. When `_data == null`: `_on_data_changed()` returns early at `Actor.gd:196`, then the subclass `_ready()` runs its hardcoded block. **Both branches are coherent.** PASS.

Typed accessors verified on all four non-goat actors:

- `var goblin_data: GoblinData: get: return _data as GoblinData; set(v): _data = v` (GoblinMinion.gd:17-19)
- `var farmer_data: FarmerData: ...` (FarmerActor.gd:8-10)
- `var fire_data: ElementalData: ...` (FireActor.gd:10-12)
- `var water_data: ElementalData: ...` (WaterActor.gd:12-14)

All four mirror `GoatActor.goat_data` / `MimicActor.mimic_data`. PASS.

---

## 6. ActorCard + Ranch Compatibility

- **`actor_data: ActorData`** is the primary getter/setter on ActorCard (line 19-23). Setter calls `setup(v)`; getter casts `data_resource as ActorData`. PASS.
- **`goat_data: GoatData`** alias retained (line 32-34). Setter typed parameter is `GoatData` (inferred from var type — Godot annotation rule). Writing a non-goat ActorData through this setter would fail at runtime. **Ranch.gd does not use this path anymore** — all three Ranch assignments are `card.actor_data = ...` (lines 62, 98, 103). Defensive alias kept for legacy reads only. PASS.
- **`actor_resource: ActorData`** internal alias retained (line 38-40). Forwards to `actor_data` to keep older internal references compiling. PASS.
- **Renderer gating** — `if actor_data is GoatData: actor_renderer.goat_data = actor_data` (lines 108-112) prevents the typed `GoatRenderer.goat_data` setter from receiving a non-goat value. Non-goat cards hide the renderer. PASS.
- **Name-edit writes** — `actor_data.set_display_name(new_text)` (lines 220-229). `ActorData.set_display_name()` is a no-op default; GoatData/GoblinData/FarmerData/ElementalData all override. PASS.
- **Ranch typing** — `selected_doe: ActorData`, `selected_buck: ActorData` (lines 23-24). Widened from `GoatData`. PASS.
- **Sort** — uses `get_display_name()` polymorphic virtual. PASS.
- **Signal handler** — renamed `_on_actor_selected(actor: ActorData)`. `card.selected.connect(_on_actor_selected)` at line 63 — connection by method reference, no string-name lookup that could silently break. PASS.
- **Cheat panel** — `_on_max_level_goat_pressed()` (lines 134-148) untouched; still constructs `GoatData.new()` directly with `goat_name`, `level`, ability scores; calls `HerdManager.add_goat(max_goat)`. PASS (R4 preserved).

---

## 7. Save Schema Stability

- `Core/GoatSaveData.gd` schema unchanged: `herd: Array[ActorData]`, `gold: int`, `current_day: int`.
- No new `Array[GoblinData]` / `Array[FarmerData]` / `Array[ElementalData]` / `Array[MimicData]` typed arrays introduced anywhere. Verified by grep (zero live hits; only AGENT_1 spec doc warns against them).
- `_perform_save_deferred` and `load_game` signatures unchanged.
- Verdict: **save schema bit-stable**. Existing on-disk `user://herd_save.tres` files continue to load. PASS.

---

## 8. Doc Updates Verified (SYNC RULE)

- **`Markdowns/Actor.md`** — bumped to v1.2 (header line 18). New "Data Resources" section documents ActorData base, lifted `is_selected`, and the three virtuals (`get_display_name`, `get_info_line`, `set_display_name`). Version Log entry at line 610. PASS.
- **`Markdowns/Breeding.md`** — bumped to v1.2 (line 15). "Patch 2 Known Gaps" subsection present (line 821) listing the deferred ProgressionComponent / sell_goat / die() / GoatRenderer rename follow-ups. Phase 2 checklist items 797–802 marked complete; GoatRenderer rename remains unchecked with "deferred" note. PASS.
- **`Markdowns/UI.md`** — bumped to v1.2 (line 20). ActorCard section (line 276+) documents `actor_data` primary API, `goat_data`/`actor_resource` aliases, renderer gate, and the polymorphic virtuals route. PASS.

---

## 9. Performance / Resource Impact

- No new per-frame work. All changes are setup / signal-connected paths.
- Three new `Resource` subclasses (`GoblinData`, `FarmerData`, `ElementalData`) — each is a small `@export` data container; no runtime cost until instantiated.
- One additional `is GoatData` check per card refresh in `_update_resource_ui()` — negligible.
- Two new virtual dispatches per card refresh (`get_display_name`, `get_info_line`) — negligible.
- No new singletons, autoloads, or scene-tree nodes.

No measurable performance impact expected.

---

## 10. Tests Performed (by code reading)

- Independently re-derived the goat-only breeding loop trace (§4). No regression found.
- Verified `is_selected` is on ActorData only — no shadow in GoatData. (`Grep` on GoatData.gd returned only a NOTE comment.)
- Verified every new `*Data` subclass has a non-null-returning `create_offspring()`.
- Verified every non-goat actor with hardcoded stat writes has the `if _data == null:` gate.
- Verified no `card.goat_data = <non-goat-value>` remains in Ranch.gd (all three sites use `card.actor_data = ...`).
- Verified `ActorCardRenderer` class does not exist anywhere in code (only mentioned in planning docs as a future rename target).
- Verified `GoatRenderer` rename was correctly NOT performed (all 3 live `.tscn` references intact).
- Verified save schema (`GoatSaveData.herd: Array[ActorData]`) is bit-stable; no typed-subclass arrays added.
- Verified doc files (`Actor.md`, `Breeding.md`, `UI.md`) bumped to v1.2 with Patch 2 entries.

---

## 11. Tests Still Needed (Godot Editor)

These cannot be verified by code reading alone:

1. **Editor compile** — open the project in Godot 4.6, let it re-import. Watch for any parse errors against the three new `.gd` files. Watch for `.gd.uid` generation.
2. **Goat-only smoke test** — load an existing `user://herd_save.tres`, enter Ranch, pair two goats, breed, advance 3 days, verify a goat kid lands in the herd, save, restart editor, reload, verify kid persisted.
3. **Save round-trip with new subclasses** — add a `GoblinData` to the herd via a debug script, save, restart editor, reload. Verify the goblin is still in `HerdManager.herd` (not silently dropped). If the entire herd is empty, fall back per Agent 2 §9 to `Array[Resource]` typing in `GoatSaveData.gd`.
4. **ActorCard non-goat render** — push a `GoblinData` into an ActorCard via a debug script. Verify (a) no console errors from the `actor_renderer.goat_data = ...` line (the gate should prevent it), (b) name + info_label render via virtuals.
5. **Cheat panel regression** — open Ranch, press the "Max Level Goat" button. Verify the spawned goat appears in the herd with name "Mega Goat", level 20, max stats.
6. **Name-edit roundtrip** — focus a card's name edit, type a new name, press Enter. Verify the goat's `goat_name` updates (via `set_display_name`).

---

## 12. Final Recommendation

**SAFE TO CONTINUE.** No blockers found. Patch 2 implementation matches the spec, addresses R1–R12 as planned, and preserves the goat-only path with only one cosmetic regression (info-line gender prefix dropped — accepted by spec). The three new `*Data` subclasses are well-formed, non-goat actors are correctly gated, and the save schema is bit-stable.

The two real risks both require human-in-the-loop verification:

1. **Godot 4.6 typed-array load-wipe** (R10) — must be tested in the editor with a mixed-subclass herd; fallback is documented if observed.
2. **`ProgressionComponent.advance_day()` will crash on a non-goat herd member** because it reads GoatData-only `age_days` / `stamina_current` / `stamina_max` (`ProgressionComponent.gd:12-23`). This is a known gap (Agent 2 §3 NEW row + §10 Q2 + Breeding.md known-gaps) and is *latent* today — no UI path currently adds a non-goat to the herd. It MUST be fixed in Patch 3 before the new `*Data` classes are exercised end-to-end.

**Top 3 things a human must test in the editor:**

1. Open the project in Godot, let imports finish, verify no parse errors on `GoblinData.gd`, `FarmerData.gd`, `ElementalData.gd`. Confirm `.gd.uid` files are generated.
2. Run the goat-only regression: existing save → Ranch → pair two goats → breed → 3-day advance → confirm kid appears, save+reload survives, cheat panel still works.
3. Spawn each non-goat actor (Goblin, Farmer, Fire, Water) via the existing menu path with `_data == null` and verify the hardcoded fallback stats are applied unchanged. Optionally assign a new `*Data.tres` in the inspector and verify resource-driven stats win over the hardcoded block.

---

*End of Agent 3 Patch 2 Review.*
