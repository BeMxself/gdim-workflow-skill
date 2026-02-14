---
name: gdim-scope
description: Use when starting a GDIM round to define strict work boundaries before design
---

# Define GDIM Scope

**Purpose**: Aggressively limit what this round will attempt. Scope is a **speed limiter**, not a todo list.

## Usage

```
gdim-scope <round_number>
```

## Automatic Round Detection

- **Round 1**: Scope from Intent only
- **Round 2+**: Scope from Intent + Gap Analysis

## Round 1 Rules (Baseline: Intent Only)

**Input**: `00-intent.md`

**Output**: `00-scope-definition.round1.md`

### Constraints (Anti-Overload)

Based on baseline testing, you WILL be tempted to include everything. Resist:

- ✅ In Scope ≤ 3 items
- ✅ Touch only 1 module/component
- ✅ Prefer static over interactive
- ✅ Prefer display over full workflow
- ❌ NO complete user flows in R1
- ❌ NO "and also..." additions
- ❌ NO "since we're doing X, might as well do Y"

### Template

```markdown
# Scope Definition — Round 1

## Scope Basis
- Intent: 00-intent.md

## In Scope
1. [Specific item from Intent]
2. [Another specific item]
3. [Maximum 3 items]

**Completion criteria**: [What "done" looks like]

## Out of Scope
- [Everything else from Intent]
- [Explicitly list major exclusions]

## Deferred Intent Mapping
| Intent Item | Status | Reason |
|-------------|--------|--------|
| [Item A] | ✓ In R1 | Core foundation |
| [Item B] | Deferred to R2+ | Depends on A |
| [Item C] | Deferred to R2+ | Lower priority |
```

## Round 2+ Rules (Gap-Driven)

**Input**:
- `00-intent.md`
- `03-gap-analysis.round(N-1).md`

**Output**: `00-scope-definition.roundN.md`

### Constraints

- ✅ New Scope = Uncompleted Intent + Gaps to close
- ✅ Add 1-2 items maximum
- ❌ NO new items not in Intent or Gap
- ❌ NO "improvements" without Gap
- ❌ NO "while we're at it" additions

### Template

```markdown
# Scope Definition — Round <round_number>

## Scope Basis
- Intent: 00-intent.md
- Gap Source: 03-gap-analysis.round{round_number-1}.md
- Gaps to Close: [GAP-01, GAP-02]

## In Scope
- [Uncompleted Intent item]
- [Gap-01 closure]
- [Gap-02 closure]

## Out of Scope
- [Other Intent items]
- [Lower priority gaps]

## Deferred Mapping
[Same as R1]
```

## Red Flags - STOP

From baseline testing, these rationalizations mean you're violating scope:

| Rationalization | Reality |
|-----------------|---------|
| "It's all one cohesive feature" | Features are always divisible. Divide them. |
| "These are interdependent" | Start with one piece. Dependencies can wait. |
| "Why split across rounds?" | Because R1 overload = high failure risk. |
| "This is a complete unit" | No such thing. Find the smallest slice. |
| "Efficiency demands we do it all" | Efficiency demands we do it right. Small scope = right. |
| "User expects full feature" | User expects working software. Incremental = working. |

**If you're thinking any of these → your scope is too large.**

## Scope Sizing Test

Ask yourself:
- Can this fail in interesting ways? (If no → scope too large)
- Could we discover gaps? (If no → scope too large)
- Is this 1-3 days of work? (If no → scope too large)

**R1 should produce gaps.** If R1 has zero gaps, your scope was too conservative or too large.

## Multiple Valid Scopes?

If you see 2+ reasonable ways to split scope, **ask the user**. Don't choose for them.

## Output Location

Write to: `.ai-workflows/YYYYMMDD-task-slug/00-scope-definition.round{round_number}.md`

## Next Step

After Scope is confirmed → `gdim-design <round_number>`
