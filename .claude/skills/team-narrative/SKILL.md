# Team-Narrative Skill

**Invocation**: `/team-narrative [content description] [--review full|lean|solo]`

Orchestrates a multi-agent pipeline for cohesive story content creation. Coordinates six specialized roles to produce narrative, lore, dialogue, and level design in alignment.

**Example**: `/team-narrative boss encounter cutscene`

---

## Review Modes

- **full** — All director gates active
- **lean** — Phase gates only
- **solo** — No director gates; run independently

---

## Five-Phase Pipeline

### Phase 1: Narrative Direction
Define story purpose, character arcs, emotional tone, and lore dependencies.
- Agent: narrative-director

### Phase 2: World Foundation (Parallel)
- **world-builder** — Create lore, establish world facts
- **writer** — Draft dialogue (max 120 characters per line for UI fit)
- **art-director** — Define visual mood, environmental cues

### Phase 3: Level Integration
- **level-designer** — Environmental storytelling, narrative triggers, pacing
- Ensure story beats map to physical space

### Phase 4: Review & Consistency
- Verify character voice consistency
- Verify lore coherence (no contradictions)
- Document lingering mysteries for future payoff

### Phase 5: Polish
- Final dialogue review for tone and length
- i18n compliance check (no hardcoded strings)
- Canon finalization — lock facts into world-bible

---

## Error Handling

If any agent blocks, surface the blocker immediately and offer choices:
- Skip this agent and continue
- Retry with narrower scope
- Resolve blocker first

Always produce partial reports — never discard completed work.

---

## File Protocol

All file writes delegate to sub-agents. This orchestrator never writes files directly.

**Verdict types**: COMPLETE (delivered) or BLOCKED (with reason and recovery path).
