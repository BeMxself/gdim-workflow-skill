---
name: gdim
description: Background knowledge for Gap-Driven Iteration Model - loaded automatically when working on GDIM workflows
---

# GDIM Core Rules

**Gap-Driven Iteration Model (GDIM)** constrains AI execution through explicit scope limiting and deviation tracking.

**Portable reference**: Use `references/gdim-portable-reference.md` for templates and extended rules in any installation mode.
For the full long-form specification, read `references/docs/GDIM 规范.md`.

## The Iron Laws

1. **Intent is human territory** - AI cannot modify Intent without explicit approval
2. **R1 Scope from Intent only; R2+ from Intent + Gap** - No other sources allowed
3. **Every design/plan declares `driven_by`** - R1: Intent; R2+: Gap IDs
4. **Missing info → Gap, not guess** - Uncertainty must be explicit
5. **Out-of-scope discoveries → Gap** - Record, don't implement
6. **No implementation without Plan** - Design → Plan → Execute, always
7. **One file per request** - Don't batch multiple stages
8. **Uncertain → ask user** - Don't rationalize, don't assume

## Exit Condition

**Only exit when BOTH are true:**
- No High Severity Gap in current round
- Intent fully covered

Otherwise → next round.

## Workflow Files

All work happens in `.ai-workflows/YYYYMMDD-task-slug/`:
- `00-intent.md` - Design goal (human-written)
- `00-scope-definition.roundN.md` - This round's limits
- `01-design.roundN.md` - Design for this round
- `02-plan.roundN.md` - Execution plan
- `05-execution-summary.roundN.md` - What actually happened
- `03-gap-analysis.roundN.md` - Deviations found
- `99-final-report.md` - Final summary

## Reference Resolution (Cross-Platform)

Use this order so the skill works in Claude plugin, Codex skills-only installs, and workspace-local installs:

1. `references/gdim-portable-reference.md` (bundled with this skill)
2. `references/docs/GDIM 规范.md` (bundled with this skill)
3. This file + stage skills (`gdim-init` ... `gdim-final`) if neither reference file is available

## Red Flags - STOP Immediately

- Scope includes content not in Intent or Gap
- R2+ design without `driven_by: [GAP-XX]`
- "I'll just quickly add..." during execution
- "This is obviously needed" for out-of-scope items
- "The plan didn't specify, so I'll..."
- Skipping stages to "save time"
- Combining multiple stages in one response

**All of these mean: Stop. Follow the process.**

## Common Rationalizations

| Excuse | Reality |
|--------|---------|
| "It's all one feature" | Features are always divisible. Divide them. |
| "These are interdependent" | Dependencies can wait. Start with one piece. |
| "This is obviously necessary" | Obvious to you ≠ in scope. Record as Gap. |
| "The plan was incomplete" | Incomplete plan = update plan first, then execute. |
| "Just filling in gaps" | Gaps in plan = stop and ask, don't fill. |
| "Following best practices" | Best practices out of scope = record as Gap. |
| "User will want this anyway" | User decides scope, not you. |

## Quick Reference

| Stage | Input | Output | Key Rule |
|-------|-------|--------|----------|
| Intent | External docs / brainstorming | `00-intent.md` | Human writes/approves |
| Scope | Intent (R1) or Intent+Gap (R2+) | `00-scope-definition.roundN.md` | Limit aggressively |
| Design | Scope | `01-design.roundN.md` | Declare `driven_by` |
| Plan | Design | `02-plan.roundN.md` | Executable steps only |
| Execute | Plan | Code changes | Follow plan exactly |
| Summary | Execution results | `05-execution-summary.roundN.md` | Facts, no judgment |
| Gap | Summary + Design | `03-gap-analysis.roundN.md` | Two layers: Round + Intent |

Use specific GDIM stage skills for detailed guidance (Claude Code: `/gdim-*`, Codex: `$gdim-*`).
