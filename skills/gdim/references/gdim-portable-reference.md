# GDIM Portable Reference

This reference is bundled inside the `gdim` skill as a compact fallback when you do not need the full docs set under `references/docs/`.

## Core Loop

`Intent -> Scope -> Design -> Plan -> Execute -> Summary -> Gap -> (next round or Final)`

Exit only when both are true:
- No High severity gap in current round
- Intent coverage is 100%

## Round Rules

### Round 1
- Scope source: `00-intent.md` only
- Keep scope small (1 to 3 items)
- Prefer one module/component

### Round 2+
- Scope source: `00-intent.md` plus prior gap analysis
- New scope must map to uncompleted intent items or explicit gap IDs
- No new improvements without intent/gap traceability

## Required Files

- `00-intent.md`
- `00-scope-definition.roundN.md`
- `01-design.roundN.md`
- `02-plan.roundN.md`
- `05-execution-summary.roundN.md`
- `03-gap-analysis.roundN.md`
- `99-final-report.md` (only at completion)

## Minimal Templates

### Intent (`00-intent.md`)

```markdown
# Intent & Baseline

## External References
- [source docs or notes]

## 1. Design Goal
[what to build and why]

## 2. Non-Goals
- [explicit exclusions]

## 3. Success Criteria
- [ ] [measurable condition]

## 4. Hard Constraints
- Technology stack:
- Performance:
- Security:
- Compatibility:

## 5. Assumptions
- [assumption]
```

### Scope (`00-scope-definition.roundN.md`)

```markdown
# Scope Definition - Round N

## Scope Basis
- Intent: 00-intent.md
- Gap Source: 03-gap-analysis.roundN-1.md (Round 2+ only)

## In Scope
1. [item]

## Out of Scope
- [item]

## Deferred Mapping
| Intent Item | Status | Reason |
|-------------|--------|--------|
| [item] | Deferred | [reason] |
```

### Design (`01-design.roundN.md`)

```markdown
---
round: N
driven_by: Intent
# or driven_by: [GAP-01, GAP-02]
scope: 00-scope-definition.roundN.md
---

# Design - Round N
## Overview
## Components/Modules
## Interfaces
## Data Flow
## Out of Scope Boundaries
```

### Plan (`02-plan.roundN.md`)

```markdown
---
round: N
design: 01-design.roundN.md
---

# Plan - Round N

## Implementation Steps
### 1. [specific action]
- File:
- Action:
- Verification:
```

### Execution Summary (`05-execution-summary.roundN.md`)

```markdown
# Execution Summary - Round N
## Completed
## Deviations from Plan
## Discoveries
## Temporary Decisions
## Blockers
## Files Changed
```

### Gap Analysis (`03-gap-analysis.roundN.md`)

```markdown
# Gap Analysis - Round N
## 1. Round Gap
## 2. Intent Coverage
## 3. Closure Strategy
## 4. Exit Decision
```

### Final Report (`99-final-report.md`)

```markdown
# Final Report
## Workflow Summary
## Intent Achievement
## Gap Summary
## Round-by-Round Summary
## Deliverables
## Termination Reason
```

## Gap Categories

- `G1` Requirement
- `G2` Design
- `G3` Plan
- `G4` Implementation
- `G5` Quality
- `G6` Constraint

## Severity

- High: blocks core function or violates hard constraints
- Medium: user impact or meaningful technical debt
- Low: minor limitation or cosmetic issue

## Red Flags

- Scope includes items not from intent/gaps
- Design/plan changes without `driven_by` traceability
- "Quick improvements" during execution
- Missing info handled by guessing instead of gaps/questions
