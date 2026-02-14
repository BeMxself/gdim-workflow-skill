---
name: gdim-gap
description: Use after execution summary to identify deviations and determine if work continues
---

# Generate Gap Analysis

**Purpose**: Two-layer analysis to find deviations and decide if work continues.

## Usage

Claude Code (plugin):

```
/gdim-gap <round_number>
```

Codex (skills):

```
$gdim-gap <round_number>
```

## Inputs

- `00-intent.md`
- `01-design.round{round_number}.md`
- `05-execution-summary.round{round_number}.md`

## Output

`03-gap-analysis.round{round_number}.md`

## Two-Layer Structure

Gap Analysis has TWO distinct layers:

### Layer 1: Round Gap
**Compare**: This round's Scope/Design vs Execution Summary
**Question**: Did we do what we planned?

### Layer 2: Intent Coverage
**Compare**: Intent vs Cumulative completion (all rounds)
**Question**: Is the overall Intent complete?

## Gap Categories

| Code | Category | Description |
|------|----------|-------------|
| G1 | Requirement | Misunderstood Intent or requirements |
| G2 | Design | Design flaw or omission |
| G3 | Plan | Plan was unexecutable or wrong |
| G4 | Implementation | Implementation doesn't match design |
| G5 | Quality | Performance, security, maintainability issues |
| G6 | Constraint | Violated hard constraints |

## Severity Levels

- **High**: Blocks core functionality or violates hard constraints
- **Medium**: Degrades experience or creates technical debt
- **Low**: Minor issues or nice-to-haves

## Template

```markdown
# Gap Analysis — Round <round_number>

## 1. Round Gap (This Round's Deviations)

**Comparison**: Scope/Design vs Execution Summary

### GAP-01: [Title]
| Field | Content |
|-------|---------|
| Category | G4 (Implementation) |
| Expected | [From design/plan] |
| Actual | [From execution summary] |
| Severity | High/Medium/Low |
| Impact | [What this affects] |

### GAP-02: [Title]
[Same structure]

## 2. Intent Coverage (Overall Progress)

**Comparison**: Intent vs All completed work

| Intent Item | Status | Completed In | Notes |
|-------------|--------|--------------|-------|
| Design Goal 1 | ✓ Complete | R1 | |
| Design Goal 2 | ◐ Partial | R1-R2 | Missing error handling |
| Design Goal 3 | ○ Not Started | — | Deferred |
| Success Criteria 1 | ✓ Complete | R2 | |
| Success Criteria 2 | ○ Not Started | — | |

**Coverage**: X% (Y/Z items complete)

## 3. Closure Strategy

| Gap ID | Strategy | Target Round | Priority |
|--------|----------|--------------|----------|
| GAP-01 | Add error handling | R<round_number+1> | High |
| GAP-02 | Implement validation | R<round_number+1> | Medium |

## 4. Exit Decision

- [ ] No High Severity Gap in this round
- [ ] Intent fully covered (100%)

**Decision**: Continue to Round <round_number+1> / Generate Final Report

**Rationale**: [Why continuing or why stopping]
```

## Identifying Gaps

From baseline testing, common gap sources:

### From Execution Summary

- Deviations listed → potential gaps
- Discoveries listed → potential gaps
- Blockers → definite gaps

### From Code Review

- Missing error handling
- Unhandled edge cases
- Performance issues
- Security concerns

### From Testing

- Failing tests
- Uncovered scenarios
- Integration issues

## Red Flags - Common Mistakes

From baseline testing:

| Mistake | Example | Fix |
|---------|---------|-----|
| Ignoring user's new request | User mentions performance, you focus only on documented gaps | User feedback can reveal gaps |
| Not citing Gap IDs | "We should improve X" | Must map to specific Gap ID |
| Inventing improvements | "Would be nice to add Y" | No gap = no improvement |
| Downplaying High severity | "It's not that bad" | Severity based on impact, not opinion |

## Exit Condition Logic

**Exit to Final Report** ONLY if BOTH:
1. ✅ No High Severity Gap in current round
2. ✅ Intent 100% covered

**Otherwise**: Continue to next round.

### Edge Case: No Gaps but Intent Incomplete

If Round Gap is empty but Intent not fully covered:
- **This is normal** - means this round succeeded
- **Decision**: Continue to next round for remaining Intent
- **Rationale**: "Round <round_number> completed successfully. Continuing for uncompleted Intent items."

### Edge Case: No Gaps and Intent Complete

If Round Gap is empty AND Intent 100% covered:
- **Decision**: Generate Final Report
- **Rationale**: "All Intent items completed with no outstanding gaps."

### Edge Case: Only Low Severity Gaps

If only Low severity gaps exist and Intent complete:
- **Ask user**: Accept gaps and finish, or continue?
- **Don't decide unilaterally**

## User Feedback Integration

From baseline testing: User may mention issues not in Execution Summary.

**Correct handling**:
1. Treat user feedback as gap discovery
2. Categorize and add to Round Gap
3. Include in Closure Strategy

**Example**:
User: "The search is slow with many results"
→ Create GAP-XX: Performance issue with large result sets (G5, High)

## Output Location

Write to: `.ai-workflows/YYYYMMDD-task-slug/03-gap-analysis.round{round_number}.md`

## Next Steps

- If continuing → `/gdim-scope <round_number+1>` (Codex: `$gdim-scope <round_number+1>`)
- If complete → `/gdim-final` (Codex: `$gdim-final`)
