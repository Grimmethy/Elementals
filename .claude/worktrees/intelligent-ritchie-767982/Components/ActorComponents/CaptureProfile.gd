## Designer-authored capture parameters consumed by `CaptureComponent`.
##
## A `CaptureProfile` is attached to a capture tool (today: the Net) via
## `WeaponData.capture_profile_path`. When the tool hits an actor, the
## projectile lazily attaches a `CaptureComponent` to the target with this
## profile and runs save → stun → catch.
##
## This is the **minimum viable** capture profile. The full Capture patch
## (per Markdowns/Breeding.md §Capture System and Markdowns/Capture.md) will
## ADD fields — restraint rating, escape DC curve, taming loyalty curve,
## ActorState transitions — without removing any of the fields below. Field
## defaults intentionally mirror the D&D Net reference: DC 12 Dex save,
## Restrained-equivalent (here: stun) for a short duration, with a flat
## catch chance approximating a tier-2 net's reliability.
class_name CaptureProfile
extends Resource

## DC the target's d20 + modifier must beat to RESIST the capture attempt.
## Default 12 mirrors the D&D Net (8 + Dex 2 + proficiency 2).
@export var save_dc: int = 12

## Ability modifier used for the save roll. Read from
## `actor.ability_scores_component[save_ability]`. Default "dexterity"
## matches the Net's design (agility resists entanglement). Wisdom or
## Strength can be used by future restraint items.
@export var save_ability: StringName = &"dexterity"

## Seconds the target is stunned when the save FAILS but the catch attempt
## also fails (the "got tangled, broke free" outcome). The stun is applied
## via `Actor.stun(duration)` which routes through `StunComponent` — the
## game's existing centralized stun authority. Default 4s gives the player
## time to follow up with a second Net or close for melee.
@export var stun_duration: float = 4.0

## Probability (0.0-1.0) the actor is captured after failing the save.
## Default 0.4 — about a 40% catch chance per Net, so chaining multiple
## throws raises the effective catch rate. Designer-tunable per profile.
@export_range(0.0, 1.0, 0.05) var catch_chance: float = 0.4

## Optional allowlist of `ActorData.get_actor_type()` keys this profile
## can capture. Empty (default) means ANY actor with a `CaptureComponent`.
## Useful for designing specialized capture tools later (e.g. a
## "Beast Snare" that only catches "goat" / "boar" / etc.).
@export var allowed_actor_types: Array[StringName] = []
