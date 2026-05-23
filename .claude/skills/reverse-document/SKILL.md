# Reverse-Document Skill

**Invocation**: `/reverse-document [design|architecture|concept] [code path]`

Generates design or architecture documentation by analyzing existing implementation rather than planning ahead. Designed for scenarios where code exists but documentation doesn't — including retrofitting docs onto already-built systems.

---

## Core Workflow (8 Phases)

1. **Parse Arguments** — User specifies document type (`design`, `architecture`, or `concept`) and the code path to analyze
2. **Analyze Implementation** — Extract mechanics, formulas, patterns, and dependencies from the codebase
3. **Ask Clarifying Questions** — Investigate the *intent* behind design decisions rather than assuming
4. **Present Findings** — Show discovered elements and flag unclear areas before drafting
5. **Draft Document** — Use appropriate template based on document type
6. **Request Approval** — Display draft sections and ask permission before writing
7. **Write with Metadata** — Include status markers noting reverse-engineered source
8. **Flag Follow-Up Work** — Suggest related tasks without auto-executing them

---

## Document Types

- **design** — For gameplay mechanics, rules, and systems
- **architecture** — For technical patterns and core systems
- **concept** — For prototype analysis and feasibility studies

---

## Key Principle

Emphasize clarifying **why** code exists rather than just describing **what** it does. Treat user clarification as essential before documentation to avoid accidentally codifying bugs or unintended behaviors.

User always maintains control over intent interpretation throughout the process.

---

## When to Use This

- A system was built iteratively and has no GDD
- You want to bring an existing Godot system into the documentation structure
- Auditing what a system actually does vs. what was originally intended
- Generating a baseline doc to then refine with `/design-system`
