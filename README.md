# Hornbound: Monster Herd

<img width="1152" height="648" alt="image" src="https://github.com/user-attachments/assets/4e340b84-57d7-4a75-a1d4-c8f0fc56fdb0" />

**Hornbound: Monster Herd** is a roguelike monster-rancher. Capture wild creatures, cross-breed them into chimeric abominations, and lead a pack of 1 + 3 into procedurally generated dungeons. Each run is a permadeath 15-25 minute expedition. The ranch persists; the bonds you form persist; your weirdest creations persist.

You ARE one of your monsters. Possession lets you jump to a packmate when your lead falls. The pack you lead has bonds, traits inherited from captured wild monsters, and movesets blended from both parents' species.

See [`Markdowns/Plans/GameLoopIdea.md`](Markdowns/Plans/GameLoopIdea.md) for the full design spec.

---

## 🎮 Core Loop

1. **Pick a contract** at the hub. Hunt / Capture / Boss / Dungeon expedition.
2. **Build a squad** of 1 lead (the one you'll play as) + 3 AI pack companions from your 12 active herd slots.
3. **Run the dungeon** — 4 rooms: warm-up → branch → mid-boss → extract.
4. **At the extract point**, choose: **Leave** (bank loot), **Push** (one more room, bigger reward), or **Abandon** (lose loot, keep monsters).
5. **Return to the ranch**, hatch eggs, inspect captures, learn traits, breed weirder hybrids, refresh squad. Day advances.
6. **Climb the leaderboards** — Deepest Dive, Apex Bloodline, Trait Library Speed, Contract Chain, Highest-Rated Chimera. Daily seeded runs share a worldwide seed.

---

## ✨ What Makes It Different

- **Procedural creature generation** from the entire D&D 5e Monster Manual (~600 stat blocks). New monsters emerge naturally as you explore — no hand-authored content moat.
- **Universal cross-species breeding.** Any × any produces a kid whose body, palette, limbs, and moveset are blended from both parents. Frankenstein graft system makes hybrids visibly weird, not just stat-blended.
- **Permadeath with possession.** When your controlled monster falls, your consciousness jumps to the nearest packmate. The body stays on the field; you can recover it for breeding parts if you make it home.
- **Bonds.** Pairs of monsters that share runs build relationships. Bond level 2 unlocks species-specific combo moves. Losing a bonded packmate applies a Grief debuff to the survivor. Names start meaning something.
- **Traits ONLY come from capture.** Killing gives parts and gold. Capturing gives genes for breeding. No substitution — capture matters.
- **Leaderboards instead of a final boss.** Hand-authored endings age out; leaderboard ascension is forever.

---

## 🛠️ Technical Architecture

| System | Doc |
|--------|-----|
| Universal Procedural Body | [`Markdowns/Systems/UniversalProceduralBody.md`](Markdowns/Systems/UniversalProceduralBody.md) |
| Bond System | [`Markdowns/Systems/BondSystem.md`](Markdowns/Systems/BondSystem.md) |
| Run Structure | [`Markdowns/Systems/RunStructure.md`](Markdowns/Systems/RunStructure.md) |
| Leaderboards | [`Markdowns/Systems/Leaderboards.md`](Markdowns/Systems/Leaderboards.md) |
| Modular Creature Genome | [`Markdowns/Systems/ModularCreatureGenome.md`](Markdowns/Systems/ModularCreatureGenome.md) |
| Capture System | [`Markdowns/Systems/Capture.md`](Markdowns/Systems/Capture.md) |
| ActorTypeData (monster registry) | [`Markdowns/Reference/ActorTypeData.md`](Markdowns/Reference/ActorTypeData.md) |
| CharacterBuildComponent | [`Markdowns/Reference/CharacterBuildComponent.md`](Markdowns/Reference/CharacterBuildComponent.md) |
| Actor system | [`Markdowns/Reference/Actor.md`](Markdowns/Reference/Actor.md) |

- **Hex-grid arena** with tile state system (fire, water, grass, mud)
- **Component-based actors** — Health, Mana, AI, Movement, Detection, Status Effects, etc.
- **Centralized tick system** — `GameClockComponent` replaces per-actor Timer nodes
- **Tile signal triggers** for proximity / detection without per-frame distance math
- **Modular controller** — TwinStick / ThirdPerson swap via resource

---

## 🗺️ Roadmap

- **Universal procedural body across all 14 D&D categories** (Beast / Humanoid / Plant / Construct done; rest scaffolded with fallback)
- **Capture mini-puzzles** per archetype (weaken / break armor / kill lessers / counter charge)
- **Hub building progression** — Apothecary → Lab → Forge → Egg Incubator → Stable
- **Online leaderboards** (Steam or custom backend)
- **Map expansion** — multi-biome world with region transitions ([plan](Markdowns/World/MapExpansion.md))
- **Mounts** (rideable beasts as 5th pack slot)
- **Tournaments / Rival fights** (PvE bracketed events)

---

## 📁 Project Structure

```
res://
├── src/actors/
│   ├── base/Actor.gd
│   ├── body/                       ← NEW: universal procedural body
│   │   ├── ProceduralCreatureBody.gd
│   │   └── PartBuilders.gd
│   ├── ai/                         ← AI behaviors + controller modes
│   └── types/                      ← Goat / Goblin / Mimic / Mushroom etc.
├── Components/
│   ├── ActorComponents/
│   │   ├── ActorTypeData.gd        ← 600+ monster registry
│   │   ├── ActorTypes/             ← per-category data files
│   │   ├── ActorBodyPlanGenerator.gd  ← NEW: category templates
│   │   ├── CharacterBuildComponent.gd
│   │   └── AbilityComponents/
│   ├── BreedingComponents/
│   │   ├── HerdManager.gd          ← active/pension + loadouts
│   │   ├── BondManager.gd          ← NEW: pair bonds
│   │   ├── GoatData.gd / MimicData.gd / MushroomData.gd / GoblinData.gd
│   ├── Arena/
│   │   ├── ArenaSpawner.gd
│   │   ├── DungeonRunController.gd ← NEW: 4-room state machine
│   │   ├── RoomTemplates/          ← NEW: room template resources
│   │   ├── PlayerInputComponent.gd ← possession added
│   │   └── ...
├── Core/
│   ├── GameSettings.gd             ← brightness + global env
│   ├── TraitLibrary.gd             ← NEW: persistent trait collection
│   ├── LeaderboardManager.gd       ← NEW: 5 boards + daily seed
│   └── ...
├── UI/
│   ├── DisplayCard/ActorCard.gd
│   ├── CreaturePreview.gd
│   ├── ExtractScreen.tscn          ← NEW: leave/push/abandon UI
│   └── ...
└── Markdowns/                      ← all design docs, plans, references
```

---

## 🤖 Working with this project

If you're an AI agent reading this:
- See [`AGENTS.md`](AGENTS.md) for project conventions
- See [`Markdowns/Plans/GameLoopIdea.md`](Markdowns/Plans/GameLoopIdea.md) for the design north star
- See [`Markdowns/Plans/HornboundImplementationPlan.md`](Markdowns/Plans/HornboundImplementationPlan.md) for the in-flight implementation tracker
