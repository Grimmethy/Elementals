# Brainstorm Skill

**Invocation**: `/brainstorm [genre/theme hint or 'open'] [--review full|lean|solo]`

A collaborative game concept ideation skill that guides you from zero to a structured game concept document using professional studio techniques, player psychology frameworks, and structured creative exploration.

---

## Core Process (6 Phases)

### Phase 1: Creative Discovery
Understand the creator first, not the game. Explore emotional anchors (memorable game moments), taste profile (favorite games and genres), and practical constraints.

**Deliverable**: A 3–5 sentence Creative Brief summarizing emotional goals, taste, and constraints.

### Phase 2: Concept Generation
Generate **3 distinct concepts** using three ideation techniques:
- **Verb-First Design** — start with the core player action
- **Mashup Method** — combine unexpected elements
- **Experience-First Design** — reverse-engineer from desired emotion

Each concept includes: title, elevator pitch, core verb, core fantasy, unique hook, MDA aesthetic, scope estimate, market fit, and biggest risk.

**Deliverable**: Three fully articulated concepts; user selects one, requests combinations, or asks for fresh directions.

### Phase 3: Core Loop Design
Build the beating heart of the game through four nested loops:

- **30-Second Loop**: Primary action feel and key design dimension
- **5-Minute Loop**: Short-term goal structure and "one more turn" psychology
- **Session Loop**: Complete play session arc (30–120 minutes)
- **Progression Loop**: Long-term growth and completion condition

Apply **Self-Determination Theory** to validate autonomy, competence, and relatedness.

### Phase 4: Pillars and Boundaries
Define **3–5 game pillars** (each with a one-sentence definition and design test). Define **3+ anti-pillars** to prevent scope creep.

**Review Mode**:
- **Solo**: Skip creative-director and art-director gates
- **Lean**: Skip both gates; proceed to Phase 5
- **Full**: Spawn creative-director (CD-PILLARS gate) and art-director (AD-CONCEPT-VISUAL gate) in parallel

Lock in a **Visual Identity Anchor** (selected direction + one-line rule + supporting principles).

### Phase 5: Player Type Validation
Identify primary player type (Achievers, Explorers, Socializers, Competitors, Creators, Storytellers), secondary appeal, exclusions, and market precedents using Bartle taxonomy and Quantic Foundry frameworks.

### Phase 6: Scope and Feasibility
- Target platform, engine choice, art pipeline complexity, content scope, MVP definition, technical risks
- Define **scope tiers** (full vision vs. fallback)

**Review Mode** (before writing):
- **Solo/Lean**: Skip producer gate; write document
- **Full**: Spawn producer (PR-SCOPE gate) to validate timeline

---

## Document Output

Write game concept to `design/gdd/game-concept.md` using the project's GDD template. Always ask for write approval before committing. Repeat revision cycle until ready.

---

## Post-Brainstorm Next Steps

**Path A — Design-First** (recommended for well-defined concepts):
1. `/art-bible` — establish visual identity
2. `/design-review` — validate concept completeness
3. `/map-systems` — decompose into systems with dependencies
4. `/design-system` — author per-system GDDs

**Path B — Prototype-First** (for unproven mechanics):
1. `/prototype` — validate core mechanic (1–3 day throwaway)
2. If PROCEED → continue Path A; if PIVOT → return to `/brainstorm`

---

## Key Design Principles

- **Collaborative, not replacement** — AI facilitates, user drives vision
- **Withhold judgment** — all early ideas are valid
- **Constraints fuel creativity** — limitations produce focused concepts
- **Time-box phases** — maintain momentum
- No hardcoded checklists — question options derive from the concept itself

## Context Management

If token usage reaches 70% during any phase, save concept to `design/gdd/game-concept.md` and suggest opening a fresh session to continue.
