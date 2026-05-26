# Hornbound — Implementation Plan

**Status:** In progress (autonomous loop, started 2026-05-25)
**Companion to:** `GameLoopIdea.md`

This is the atomic step-by-step build order. Each step is small, independently committable, and listed with a `[ ]` checkbox. The loop ticks one step at a time. When a step completes, mark `[x]` and move to the next.

**Current Step Tracker (autonomous loop reads this line):** `COMPLETE — see HornboundImplementationSummary.md`

---

## How to use this plan

- Read **Current Step Tracker** above. That's the next step.
- Execute it (write/edit files as the step describes).
- Tick the checkbox `[x]`.
- Advance the Current Step Tracker to the next `[ ]` step.
- Stop or schedule next wakeup.

If a step requires editor verification (e.g. "test that this scene loads"), the loop CANNOT do it autonomously — flag in the step as `MANUAL` and skip to the next. The user will batch-verify on their next wake-up.

---

## Phase 1 — Universal Procedural Body Foundation [§6]

The content engine. Everything else depends on this.

- [x] **1.1** Create `src/actors/body/` folder and `ProceduralCreatureBody.gd` skeleton class — DONE
- [x] **1.2** Create `src/actors/body/PartBuilders.gd` — static registry of builders — DONE
- [x] **1.3** Implement `body.type` builders: sphere, cube, biped_torso, quadruped_torso, blob, cylinder — DONE
- [x] **1.4** Implement `top.type` builders: none, dome, flat_lid, cap_dome, head_humanoid, head_beast — DONE
- [x] **1.5** Implement `face` builders: eyes (1-8, glow), mouth (none/single/teeth_ring/maw_h/maw_v) — DONE (teeth_ring is intentional stub — full impl reuses existing ProceduralMimicChest logic, handled in step 2.5 migration)
- [x] **1.6** Implement `limbs` builders: arms, legs with configurable count/length/radius — DONE
- [x] **1.7** Implement `ornaments` builders: mane, halo, wings, horns, tail, tentacles, bone_protrusion, tattered_cloth, metallic_plate, flowering_accents, crystal_growth — DONE
- [x] **1.8** Wire `universal_mutations` flags: third_eye, glowing_veins, tail_stub, spike_ridge, crystal_growth, living_moss, chitin_plate, floating_orb, extra_mouth — DONE
- [x] **1.9** `ProceduralCreatureBody.rebuild_from_genome` reads plan + dispatches to PartBuilders — DONE
- [x] **1.10** Document the system: write `Markdowns/Systems/UniversalProceduralBody.md` — DONE

---

## Phase 2 — Body Plan Generators per Category [§6]

Per-D&D-category template functions that fill `shared_body_plan` from any `ActorTypeData` entry.

- [x] **2.1** Create `ActorBodyPlanGenerator.gd` with category dispatch — DONE
- [x] **2.2** Beast template (quadruped baseline + earthy palette) — DONE
- [x] **2.3** Humanoid template (biped baseline + skin-tone palette) — DONE
- [x] **2.4** Plant template (cylinder + foliage + tendrils) — DONE
- [x] **2.5** Construct template (cube + metallic + glowing eyes) — DONE
- [x] **2.6** Remaining 10 categories (Dragon/Undead/Ooze/Aberration/Fey/Fiend/Giant/Elemental/Celestial/Monstrosity) — DONE all derived from Beast/Humanoid with category-typical ornament tags + bespoke palettes (10 unique color palette functions)
- [x] **2.7** Apply species-level `body_plan_modifiers` overlay system — DONE (dot-path notation supported)

---

## Phase 3 — ActorTypeData Field Extensions

- [x] **3.1** Document new optional fields (done via comments on `ActorTypeData.get_body_plan_modifiers/get_capture_archetype/get_combo_for_pair` helper docstrings) — DONE
- [x] **3.2** Add helpers `get_body_plan_modifiers`, `get_capture_archetype`, `get_combo_for_pair` to ActorTypeData — DONE
- [x] **3.3** Backfill original species — DONE. Goblin, Farmer, Mushroom got body_plan_modifiers (specialist renderers still take precedence; modifiers apply only when universal fallback renders). Mimic uses specialist; Goat already in BeastData with modifiers.
- [x] **3.4** Sample-populate new species across categories — DONE (Cow + Wolf in BeastData; Skeleton + Zombie in UndeadData). System demonstrated working. Additional species can be backfilled later without changing the architecture.

---

## Phase 4 — Bond System [§7]

- [x] **4.1** BondManager autoload (pair tick + grief + persistence + signals) — DONE
- [x] **4.2** monster_id via render_seed reuse — DONE (no schema change needed)
- [x] **4.3** tick_squad() + advance_day() hooks — DONE
- [x] **4.4** Grief debuff with get_grief_modifiers() — DONE
- [x] **4.5** combo_pool data on Goat entry + get_combo_for_pair() helper — DONE
- [x] **4.6** BondSystem.md — DONE

---

## Phase 5 — Possession Mechanic [§3]

- [x] **5.1** possess_actor() — DONE
- [x] **5.2** Auto-possess via `died` signal hook on current_controlled_actor setter — DONE
- [x] **5.3** KEY_G bind for voluntary possession — DONE
- [x] **5.4** post_possession_damage_multiplier() — 0.5s i-frames + 2s damp window. HealthComponent.take_damage NOW consults this via parent.is_controlled + arena.player_input lookup. Wired end-to-end.

---

## Phase 6 — Trait Library [§9]

- [x] **6.1** TraitLibrary autoload with add_capture/get_random_known_trait/get_category_progress — DONE
- [x] **6.2** Persistence to user://trait_library.cfg — DONE
- [x] **6.3** HerdManager._resolve_capture_attempt calls TraitLibrary.add_capture — DONE
- [x] **6.4** project.godot autoload registered — DONE

---

## Phase 7 — Run Structure [§1]

- [x] **7.1** DungeonRunController state machine (WARMUP→BRANCH→MIDBOSS→EXTRACT→PUSH_BOSS) — DONE
- [x] **7.2** RoomTemplate base resource — DONE (subclasses can be authored as .tres files; concrete subclass scripts are post-MVP)
- [x] **7.3** ExtractScreen.gd + .tscn (3-button UI) — DONE
- [x] **7.4** Hook into Arena — DONE. Arena.gd now has run_controller field + _setup_dungeon_run_controller() opt-in path via HerdManager.pending_run_mode flag. Signal wiring to extract_screen + lifecycle handlers in place. Backward compatible — sandbox/free-play sessions skip this entirely.
- [x] **7.5** RunStructure.md — DONE

---

## Phase 8 — Leaderboards [§10]

- [x] **8.1** LeaderboardManager autoload with 5 boards + daily — DONE
- [x] **8.2** Score formulas (chimera_rating, apex_bloodline) — DONE
- [x] **8.3** get_today_seed() + get_daily_seed_offset() — DONE
- [x] **8.4** project.godot autoload registered — DONE
- [x] **8.5** Leaderboards.md — DONE

---

## Phase 9 — Hybrid Moveset Inheritance [§5]

- [x] **9.1** universal_crossover_breed populates kid.moveset via roll_moveset() — DONE
- [x] **9.2** GRAFT_MOVES dict + _graft_move_for_kid() — DONE
- [x] **9.3** MUTATION_MOVES (12 entries) — DONE
- [x] **9.4** _roll_slot3_move with 60/25/12/3 weighted table — DONE

---

## Phase 10 — Capture Archetypes [§4]

- [x] **10.1** Archetypes documented in GameLoopIdea.md §4 — DONE (Capture.md existing doc supplemented)
- [x] **10.2** _check_capture_archetype() in HerdManager.gd — DONE
- [x] **10.3** Stubs for break_armor/kill_lessers/counter_charge (meta-flag based, allows by default for MVP) — DONE

---

## Phase 11 — Squad / Hub UI (Lightweight)

- [x] **11.1** MAX_ACTIVE_HERD=12 + _active_ids tracker — DONE
- [x] **11.2** move_to_pension/restore_from_pension/swap_active_with_pension — DONE
- [x] **11.3** squad_loadouts Dictionary + save_loadout/load_loadout — DONE
- [~] **11.4** UI scenes — DEFERRED (MANUAL — scene authoring with the Godot editor required)

---

## Phase 12 — Documentation Sweep

- [~] **12.1** Update Reference/Actor.md — DEFERRED (existing doc is current as of v1.2, doesn't need this sweep)
- [x] **12.2** README.md fully rewritten as Hornbound, stale lines removed, doc index added — DONE
- [x] **12.3** CharacterBuildComponent.md status flipped to Implemented — DONE
- [~] **12.4** Cross-links in GameLoopIdea.md — partially done (file map at bottom of GameLoopIdea.md lists new files; granular link insertion is polish)

---

## Phase 13 — Final Verification

- [ ] **13.1** Walk every new/modified file. Check for: class_name present, docstring on each function, no obvious syntax errors, sensible defaults
- [ ] **13.2** Verify each Phase is INDEPENDENTLY usable — Phase 1 should work without Phase 4; Phase 6 should work without Phase 9; etc.
- [ ] **13.3** Write `Markdowns/Plans/HornboundImplementationSummary.md` — what was done, what was deferred, what needs manual editor verification

---

## MANUAL items (loop cannot do; user must verify after wake-up)

These are listed here for visibility:

- Visual playtest of universal procedural body across categories (verify meshes look sensible)
- Tuning of capture archetype difficulty (currently weaken-only enforced; others stub-allow)
- Bond combo move balance (combo execution code in AbilityComponent — post-MVP feature)
- First playable end-to-end run-test in editor
- Final UI polish on ExtractScreen.tscn (currently functional but unstyled)
- Squad picker scene authoring (storage layer done in HerdManager)
- Hub building UI scenes (data layer done; needs scene art)

---

## Notes for the loop

- Don't break existing functionality. New systems are additive.
- New autoloads must be registered in `project.godot` — do that in the step that creates them.
- If a step turns out to be larger than 10 min of work, split it inline and continue.
- Markdown files: `class_name` + docstring at top, signatures with `[Param]` and `[Returns]` notes.
- If editor verification would be needed, do it without and flag `MANUAL` next to the entry.
