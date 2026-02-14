---
name: gdim-design
description: Use when creating design documents for a GDIM round after scope is defined
---

# Generate GDIM Design

Creates design document for current round, strictly within scope boundaries.

## Usage

Claude Code (plugin):

```
/gdim-design <round_number>
```

Codex (skills):

```
$gdim-design <round_number>
```

## Inputs

- `00-scope-definition.round{round_number}.md`
- `00-intent.md`
- `03-gap-analysis.round{round_number-1}.md` (if Round 2+)
- External reference docs (if specified in Intent)

## Output

`01-design.round{round_number}.md`

## Design Requirements

### Header (YAML Frontmatter)

```yaml
---
round: <round_number>
driven_by: Intent  # R1
# OR
driven_by: [GAP-01, GAP-02]  # R2+
scope: 00-scope-definition.round{round_number}.md
external_refs:  # Optional
  - docs/api-spec.md
  - docs/design-system.md
---
```

### Content Focus

**Design ONLY what's In Scope. Nothing else.**

- Component/module structure
- Interface definitions
- Data flow
- Responsibilities and boundaries
- Integration points

**Avoid**:
- Implementation details (unless core algorithm)
- Out of Scope items
- "Future-proofing" for later rounds
- Placeholder structures

## Scope Violation = Design Violation

From baseline testing: You will be tempted to design "complete" systems. Resist.

| Violation | Example | Fix |
|-----------|---------|-----|
| Designing out-of-scope features | Scope: login UI. Design: login + registration + password reset | Remove registration and password reset |
| "Preparing for" future rounds | Adding hooks/interfaces for features not in scope | Delete preparation code |
| "Obvious" extensions | Scope: display list. Design: list + sorting + filtering | Remove sorting and filtering |

**Rule**: If it's not in "In Scope" section, don't design it.

## Round-Specific Rules

### Round 1

```markdown
# Design — Round 1

[YAML frontmatter with driven_by: Intent]

## Overview
[What this round builds]

## Components/Modules
[Only those needed for In Scope items]

## Interfaces
[Only those needed for In Scope items]

## Data Flow
[Only for In Scope functionality]

## Dependencies
[What this round depends on]

## Out of Scope Boundaries
[Explicitly state what this design does NOT cover]
```

### Round 2+

```markdown
# Design — Round <round_number>

[YAML frontmatter with driven_by: [GAP-XX, GAP-YY]]

## Gap-Driven Changes
| Gap ID | Design Change |
|--------|---------------|
| GAP-01 | [Specific design modification] |
| GAP-02 | [Specific design modification] |

## [Rest same as R1]
```

**Every design element must map to a Gap ID.** If you can't cite the Gap, don't design it.

## Red Flags - STOP

| Thought | What It Means |
|---------|---------------|
| "While designing X, I should also design Y" | Y is out of scope. Stop. |
| "This will need Z eventually" | Eventually ≠ now. Don't design Z. |
| "Let me add this interface for flexibility" | Flexibility for what? If not in scope, delete it. |
| "This is incomplete without..." | Incomplete is fine. That's what rounds are for. |

## External References

You MAY reference external docs (API specs, design systems) as design basis. Cite them in `external_refs`.

## Uncertainty Handling

If design requires information you don't have:
1. **Don't guess**
2. **Don't design around the gap**
3. **Ask the user**
4. **Or note as assumption** in design

## Output Location

Write to: `.ai-workflows/YYYYMMDD-task-slug/01-design.round{round_number}.md`

## Next Step

After design is confirmed → `/gdim-plan <round_number>` (Codex: `$gdim-plan <round_number>`)
