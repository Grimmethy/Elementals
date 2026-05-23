# Balance-Check Skill

**Invocation**: `/balance-check [combat|economy|progression|loot|custom] [optional: file path for custom]`

Analyzes game balance data across multiple systems. Reads data files, compares them against design documents, and flags problems with structured output.

---

## Core Workflow (6 Phases)

1. **Domain Identification** — Determine which system to check from user input
2. **Data Loading** — Read relevant files from `assets/data/` and `design/balance/`
3. **Design Baseline** — Pull intended targets from the GDD
4. **Analysis** — Run domain-specific checks:
   - Combat: DPS calculations, TTK, outlier damage values
   - Economy: resource flow rates, sink/source balance
   - Progression: XP curves, power delta per tier
   - Loot: drop rate distributions, value outliers
5. **Reporting** — Output structured report with outliers, degenerate strategies, and recommendations
6. **Fix Cycle** — Guide iterative adjustments and re-verification

---

## Report Output

```
HEALTH: HEALTHY / CONCERNS / CRITICAL

Outliers Table        — Actual vs. expected values
Degenerate Strategies — Dominant or exploitable builds/strategies
Progression Graph     — Power curve analysis
Recommendations Table — Prioritized fixes with impact assessment
```

---

## After Report: User Options

- **(A)** Fix issues step-by-step with agent guidance
- **(B)** Save report to `design/balance/balance-check-[system]-[date].md`
- **(C)** Review manually and re-run later

Always remind user to propagate design changes if tuning knobs affect multiple GDDs.
