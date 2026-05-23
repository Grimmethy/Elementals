# Capture System Design Document

> **DESIGN STATUS:** the full multi-stage model below (restraint tiers, drag,
> taming, ActorState enum) is the **canonical long-term design** — see
> Markdowns/Breeding.md §Capture System for the same model cross-referenced
> from the breeding side.
>
> **IMPLEMENTATION STATUS (Patch 3 — Minimum Viable Net Catch):**
> the codebase ships a **three-primitive subset** of this design today,
> intentionally narrow so the full Capture patch can EXTEND it verbatim:
>
> - `Components/ActorComponents/CaptureComponent.gd` — `can_be_captured()`,
>   `roll_save()`, `roll_catch()`, `apply_stun()`, `apply_capture()`. Lazily
>   attached to the target by `BaseProjectile._on_body_entered` when a
>   capture-tool projectile lands. Wild actors do NOT carry this component
>   by default.
> - `Components/ActorComponents/CaptureProfile.gd` — designer-authored
>   `Resource` with `save_dc`, `save_ability`, `stun_duration`, `catch_chance`,
>   `allowed_actor_types`. Future fields (restraint rating, escape DC curve,
>   taming loyalty) will be ADDITIVE.
> - `Components/ActorComponents/CaptureProfiles/DefaultNet.tres` — the Net's
>   profile, attached via `WeaponData.capture_profile_path` (set in
>   `Core/ItemsAutoload.gd` after the Net's `_add` call).
> - Net hit flow: throw Net → projectile collides with Actor →
>   `BaseProjectile._on_body_entered` detects `source_weapon_data.is_capture_tool`,
>   lazy-attaches `CaptureComponent` with the Net's profile, runs
>   save → on fail: stun + catch → on catch: build matching `*Data` from
>   actor's live ability scores, push to `HerdManager.add_goat`, `queue_free`
>   the actor. All outcomes print `[Capture]` readouts to the Godot console
>   so the player can see the rolls until the Capture UI lands.
>
> What Patch 3 deliberately does NOT do (deferred to the full Capture patch):
> the `ActorState` enum, restraint stacking, drag mechanics, taming loyalty,
> per-tier escape DCs, ropes/chains/manacles/traps. Patch 3 ships **one
> capture tool** with **one stun-on-fail / catch-on-fail** outcome.

## Overview
Capture is a multi-stage loop: **encounter → restrain → drag → tame**. Wild actors can be subdued with nets, ropes, chains, manacles, and traps, then physically hauled back to a friendly base for taming/petting. Nets are already referenced in `ItemsAutoload`, so we build off that existing asset and its attack-style interaction.

> Net reference (adapted from D&D): When you take the Attack action you can throw a Net (range 15 feet). The target must make a Dexterity save (DC 8 + Dex modifier + proficiency) or become Restrained until it escapes. Huge+ creatures succeed automatically. Destroying the Net also frees the target instantly.

We translate this into a capture tool with short range (5/15), hit points (5 HP, AC 10), and a Restraint Rating that makes following steps possible.

## Restraint Tiers & Items

1. **Net (Tier 2)**: Launches the encounter. Grants Restraint Rating 2, base Escape DC 10 STR (Athletics). Creature stays Restrained (cannot move) but can escape with repeated checks.
2. **Ropes/snare/lasso (Tier 1)**: Soft binds. Add Restraint Rating +1 each when applied, raise escape DC, but easy to break. Useful when approaching restrained targets.
3. **Chains & Manacles (Tier 3-4)**: Applied while netted. Chains (iron, hemp, silk) raise Restraint Rating +2-4 and add penalties to escape. Manacles add +4-6, lock wrists, and may require keys or Thieves' Tools to remove.
4. **Traps (Tier 5)**: Pit traps, cages, bear traps, magical snares. They preemptively constrain a creature entering the trigger tile and stack with later bindings.

**Stacking rule:** Each restraint item contributes its Restraint Rating to a total. Escape DC = base DC + (Restraint Rating × 2) + size modifier + trait bonuses.

## Escape + Containment

Actors have an `ActorState`: WILD, RESTRAINED, CONFINED, TAMING, TAMED, FLED. While restrained they can spend their turn to roll Escape (d20 + modifiers) against Escape DC. Adding ropes/chains/manacles increases the DC dramatically, so nets alone are easy to break but high-tier bindings make escape rare.

Trait bonuses: high Strength, Escape Artist, amorphous forms, magical resistance. Exhausted or bound creatures take penalties.

## Dragging Back to Base

When Restraint Rating ≥ the creature's **Confinement Threshold** (base 2 + size modifier), the player can drag it. Dragging:
- Slows player movement (50% speed).
- Forces the actor to share the same tile (prevents enemy movement).
- Requires a base destination (stable, ranch pen, etc.).
- If the player is hit while dragging, they must pass a save (e.g., DC 10 CON) or drop the creature (it remains Restrained in place).
- Dragging continues until the creature reaches base or the player releases it.

At base the creature transitions to **CONFINED** state.

## Taming & Loyalty

Taming happens inside a safe zone once the creature is confined. The player spends taming sessions (time, items, food) to raise `loyalty` (0–1.0). Higher Restraint Rating increases loyalty gains, but enchanted manacles can block escape rolls entirely. If loyalty falls to 0 the creature may fight free again; reaching 1.0 makes it a herd member (`ActorState.TAMED`).

Taming sessions consume items and time, and the creature must stay confined long enough to finish the progress bar. Breaking the restraints gives it a chance to escape, so stacking ropes/chains/manacles/traps during this phase protects the effort.

## CaptureComponent Responsibilities

1. Track `ActorState` transitions and emit signals when a state changes.
2. Store applied restraint items and compute total Restraint Rating.
3. Provide escape checks (roll + modifiers vs escape DC) and notify the system when a creature breaks free.
4. Allow drag eligibility, taming progress, loyalty modifications, and taming session bookkeeping.
5. Integrate with `HerdManager` when a creature becomes TAMED or returns to WILD/FLED.

## Capture Flow Summary

1. **Encounter** wild actor in WILD state.
2. **Restrained** via Net, trap, or binding.
3. **Bind** with ropes/chains/manacles; stack rating.
4. **Drag** creature back to base once threshold reached.
5. **Tame** through sessions/items; loyalty → 1.0.
6. **Herd** the new member once TAMED, enabling breeding and arena use.

By planning the capture tools, stacking mechanic, escape formulas, drag mechanics, and taming progression we can implement the references to nets and expand to ropes, chains, manacles, and traps.
