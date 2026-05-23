# Design-System Skill

**Invocation**: `/design-system [system name] [--review full|lean|solo]`

A structured, collaborative workflow for authoring Game Design Documents (GDDs) for individual game systems. Implements an eight-phase methodology combining context gathering, incremental section-by-section design, specialist agent delegation, and rigorous cross-system validation.

---

## Core Workflow

**Question → Options → Decision → Draft → Approval → Write** cycle for each section.

### Phase 1: Parse & Validate
Resolve review mode (full/lean/solo), identify the target system, detect retrofit mode for updating existing GDDs without overwriting completed sections.

### Phase 2: Gather Context
Read game concept, systems index, entity registry, dependency GDDs, and technical constraints before any design work begins. Present a context summary highlighting locked cross-system facts and past failure patterns.

### Phase 3: Skeleton
Create the GDD file structure with empty section headers, establishing a persistent write target for incremental updates.

### Phase 4: Section Design
Walk through eight required sections with domain-specific guidance:
1. **Overview** — system purpose and player-facing value
2. **Player Fantasy** — what the player feels/imagines while engaging
3. **Detailed Design** — mechanics, rules, interactions
4. **Formulas** — mathematical models with variable tables (vague entries unacceptable)
5. **Edge Cases** — exact conditions and resolutions
6. **Dependencies** — other systems this relies on or affects
7. **Tuning Knobs** — exposed parameters for balancing
8. **Acceptance Criteria** — Given-When-Then format

Optional sections: Visual/Audio, UI, Open Questions.

### Phase 5: Validation
Self-check completed content, coordinate creative director pillar alignment review, update entity registry, propose design review in a fresh session.

---

## Review Modes

- **Full**: All specialist agents and creative director review gates
- **Lean**: Skip agents except for high-risk sections (Formulas, Acceptance Criteria)
- **Solo**: Draft without specialist input; note for manual review before production

## Specialist Routing

| System Category | Agents |
|---|---|
| Combat/damage | game-designer, systems-designer, ai-programmer |
| Economy/loot | economy-designer, systems-designer |
| Dialogue/quests | game-designer, narrative-director, writer |
| UI systems | game-designer, ux-designer, ui-programmer |
| Progression | game-designer, systems-designer, economy-designer |

---

## Recovery & Persistence

Session state tracking in `production/session-state/active.md` records current system and completed sections. If interrupted, resume from the next incomplete section — never re-discuss approved content.

---

## Key Principles

- Every section requires explicit user approval before writing
- Each approved section is written immediately to file (survives session interruptions)
- Every section validates against dependency GDDs and game pillars — conflicts surface immediately
- Formulas require variable tables; edge cases require exact conditions; acceptance criteria use Given-When-Then
