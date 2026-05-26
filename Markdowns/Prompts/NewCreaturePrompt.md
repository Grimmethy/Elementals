# Prompt — Generate a New Creature Entry

Paste this prompt into Claude (or any reasoning model) along with your creature description. It produces a drop-in entry for `Components/ActorComponents/ActorTypes/<Category>Data.gd` plus an optional hint for `CreatureSignatures.gd`.

---

## The Prompt

> You're authoring a new creature for Hornbound: Monster Herd, a Godot 4.6 monster-rancher built on the existing universal procedural body + breeding system in `ActorBodyPlanGenerator.gd` + `PartBuilders.gd`. Output a single creature entry that drops cleanly into `Components/ActorComponents/ActorTypes/<Category>Data.gd` and (if needed) a one-line hint for `CreatureSignatures.SUB_TEMPLATE_HINTS`.
>
> **Creature concept:** `<DESCRIBE YOUR CREATURE HERE — appearance, size, behavior, lore>`
>
> ### Output requirements
>
> Produce exactly two code blocks:
>
> **1. The ActorTypeData entry** (paste into the appropriate `<Category>Data.gd` between two existing entries). Required fields:
> - `max_health`, `armor_class`, `damage_amount`, `element_type` ("none" | "fire" | "ice" | "storm" | "shadow")
> - Six ability score modifiers (`strength`, `dexterity`, `constitution`, `intelligence`, `wisdom`, `charisma`) as floats, 0.0 = baseline, range −5.0 to +8.0
> - `gold_value` (int), `weapons` (Array[String]), `abilities` (Array[String]), `armor` (Array[String])
> - `capture_archetype`: one of `"weaken"` | `"break_armor"` | `"kill_lessers"` | `"counter_charge"`
> - `body_plan_modifiers`: a Dictionary with these keys (all optional — include only what's distinctive):
>   - `"base.scale"`: float (Tiny=0.45, Small=0.75, Medium=1.0, Large=1.55, Huge=2.30, Gargantuan=3.40 — multiply if mixing size class)
>   - `"palette.primary"`: Color(r, g, b) — main body color
>   - `"palette.secondary"`: Color(r, g, b) — shadow / underbelly
>   - `"palette.accent"`: Color(r, g, b) — highlights / claws / horns / belly
>   - `"palette.eye"`: Color(r, g, b)
>   - `"face.eye_count"`: int (default 2)
>   - `"face.eye_radius"`: float (default 0.045)
>   - `"face.eye_glow"`: bool
>   - `"face.mouth_style"`: one of `"none"` | `"single"` | `"teeth_ring"` | `"maw_horizontal"` | `"maw_vertical"`
>   - `"ornaments.tags"`: Array of any subset of: `"mane"`, `"halo"`, `"wings"`, `"horns"`, `"tail"`, `"tentacles"`, `"bone_protrusion"`, `"tattered_cloth"`, `"metallic_plate"`, `"flowering_accents"`, `"crystal_growth"`, `"spike_ridge"`, `"chitin_plate"`
>   - `"limbs.has_legs"` / `"limbs.has_arms"` / `"limbs.leg_count"`: override if non-standard
> - Optional: `"combo_pool"` — Dictionary mapping partner species names to combo move strings (for the bond system).
>
> **2. The CreatureSignatures hint** (only if the creature's anatomy isn't covered by the heuristic — e.g. it's a small_animal in Beast category, or a wyrmling in Dragon). Format:
> ```gdscript
> "<Creature Name>": "<sub_template_key>",
> ```
> Valid sub-template keys: `wolf_like`, `bear_like`, `small_animal`, `small_quadruped`, `dinosaur_like`, `lizard_like`, `bird_like`, `serpent_like`, `insect_like`, `small_humanoid`, `warrior_humanoid`, `brute_humanoid`, `caster_humanoid`, `wyrmling`, `young_dragon`, `adult_dragon`, `ancient_dragon`, `wyvern`, `skeleton`, `zombie`, `ghoul_crouch`, `wraith_floating`, `tiny_undead`, `tiny_floating`, `tiny_fey`, `satyr_humanoid`, `centaur`, `plant_humanoid`, `tiny_winged_fiend`, `tiny_fiend`, `blob_fiend`, `small_fiend`, `winged_huge`, `serpent_humanoid`, `golem_large`, `elemental_humanoid`, `floating_eye`, `tentacled_humanoid`, `tentacled_fish`, `tentacled_blob`, `cube_ooze`, `blob`, `mushroom_cap`, `treant`.
>
> ### Constraints
>
> - Stats should match the creature's D&D 5e canon if it's an established monster (Wolf has Pack Tactics + Keen Smell, Dragons have Breath Weapon + Fly + Frightful Presence, etc.). For original creations, scale ability scores against `max_health` — a 100-HP boss should have +5 in its dominant stat.
> - Palette colors are the most important visual signal. Pick canonical colors (Red Dragon = crimson, White Dragon = frost-blue-tinged white, Bear = brown, etc.). Use sRGB floats 0.0–1.0.
> - Ornaments should match silhouette description, not just be decoration. Wings imply flight, horns imply combat, halo implies divine/undead lich-style.
> - Eye glow = true for any creature with magical / undead / fiend / aberration / elemental / fey lineage. Mundane beasts mostly don't glow.
> - Capture archetype guidance:
>   - `weaken` (default) — straight HP attrition
>   - `break_armor` — armored / metal-plated / dragon-scaled creatures
>   - `kill_lessers` — pack alpha / surrounded by minions / boss-type
>   - `counter_charge` — chargers (boars, rhinos, mammoths, minotaurs)
> - Comments above the entry should describe the canonical appearance in one sentence (matches existing entry style).
>
> ### Output format
>
> Just the two code blocks. No preamble. The first block is the dict entry; the second block is the SUB_TEMPLATE_HINTS line (or omit if no hint needed).

---

## Example (Lion as if generated by the prompt)

**Input:** *"A great tawny-gold lion with a thick dark mane, amber eyes, a Medium-sized apex predator. Pack tactics in combat."*

**Output:**

```gdscript
"Lion": {
    "max_health": 26, "armor_class": 12, "damage_amount": 2.0, "element_type": "none",
    "strength": 3.0, "dexterity": 3.0, "constitution": 2.0, "intelligence": -4.0, "wisdom": 1.0, "charisma": -1.0,
    "gold_value": 60,
    "weapons": ["Claw", "Bite"],
    "abilities": ["Pack Tactics", "Pounce", "Keen Smell"],
    "armor": ["Natural Armor"],
    # Hornbound — tawny gold body, dark mane around the head, amber eyes.
    "capture_archetype": "weaken",
    "body_plan_modifiers": {
        "base.scale": 1.30,
        "palette.primary": Color(0.78, 0.62, 0.32),
        "palette.secondary": Color(0.55, 0.42, 0.20),
        "palette.accent": Color(0.42, 0.25, 0.10),
        "palette.eye": Color(0.92, 0.65, 0.18),
        "ornaments.tags": ["tail", "mane"],
    },
},
```

```gdscript
"Lion": "wolf_like",
```

---

## How to use the result

1. **Paste the first code block** into `Components/ActorComponents/ActorTypes/<Category>Data.gd` between two existing entries. Match the indentation (tabs).
2. **Paste the second code block** (if present) into `Components/ActorComponents/CreatureSignatures.gd` inside `SUB_TEMPLATE_HINTS` under the matching category section.
3. **Add the creature's name** to `ActorTypeData.gd`'s `CATEGORY_MAP[<Category>]` array (one place, alphabetical-ish or thematic-ish — doesn't matter functionally).
4. Open the Hub → Dev: Summon Monster → filter to the category → page through to your new creature. The procedural body will reflect the modifiers immediately.

Breeding works the moment the creature is in the herd — `ActorData.universal_crossover_breed` reads `shared_body_plan` regardless of how it was authored.
