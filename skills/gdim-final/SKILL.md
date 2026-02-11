---
name: gdim-final
description: Use when GDIM workflow completes to generate final summary report
---

# Generate Final Report

**Purpose**: Summarize entire GDIM workflow when exit conditions are met.

## Usage

```
/gdim-final
```

## Prerequisites

Before generating Final Report, verify:
- ✅ Latest Gap Analysis shows no High Severity gaps
- ✅ Intent Coverage is 100%
- ✅ User confirmed work is complete

## Inputs

- `00-intent.md`
- All `03-gap-analysis.roundN.md` files
- All `05-execution-summary.roundN.md` files

## Output

`99-final-report.md`

## Template

```markdown
# Final Report

## Workflow Summary

- **Task**: [Task name]
- **Duration**: [Start date] to [End date]
- **Total Rounds**: [N]
- **Intent Coverage**: 100%

## Intent Achievement

| Intent Item | Status | Completed In |
|-------------|--------|--------------|
| Design Goal 1 | ✓ | R1 |
| Design Goal 2 | ✓ | R2 |
| Success Criteria 1 | ✓ | R2 |
| Success Criteria 2 | ✓ | R3 |

## Gap Summary

### Gaps Introduced and Closed

| Gap ID | Category | Severity | Introduced | Closed | Status |
|--------|----------|----------|------------|--------|--------|
| GAP-01 | G4 | High | R1 | R2 | Closed |
| GAP-02 | G5 | Medium | R1 | R2 | Closed |
| GAP-03 | G2 | Low | R2 | R3 | Closed |

### Accepted Gaps (if any)

| Gap ID | Category | Severity | Reason Accepted |
|--------|----------|----------|-----------------|
| GAP-04 | G5 | Low | Performance acceptable for current scale |

## Round-by-Round Summary

### Round 1
- **Scope**: [Brief description]
- **Outcome**: [What was delivered]
- **Gaps Found**: [Count and severity]

### Round 2
- **Scope**: [Brief description]
- **Outcome**: [What was delivered]
- **Gaps Found**: [Count and severity]

[Continue for all rounds]

## Deliverables

- [List of files created/modified]
- [Key components/modules]
- [Documentation produced]

## Termination Reason

**Successful Completion**: All Intent items achieved, no High Severity gaps remaining.

[OR if terminated early]

**Early Termination**: [Reason - user decision, blocked, scope change, etc.]

## Lessons Learned (Optional)

- [What worked well in this workflow]
- [What could be improved]
- [Patterns that emerged]
```

## Report Style

- **Factual and concise**
- **No evaluation** ("successful", "excellent")
- **Chronological** for round summaries
- **Tabular** for gap tracking

## Gap Summary Rules

### Closed Gaps
All gaps that were introduced and resolved during the workflow.

### Accepted Gaps
Gaps that exist but were explicitly accepted by user:
- Low severity gaps user chose not to address
- Known limitations documented and accepted
- Technical debt acknowledged and deferred

**Never mark gaps as "accepted" without user confirmation.**

## Termination Scenarios

### Normal Completion
- Intent 100% covered
- No High Severity gaps
- User confirmed completion

### Early Termination
- User decided to stop
- Blocked by external dependency
- Intent changed significantly (new Intent needed)
- Project cancelled

**Document the reason clearly.**

## Deliverables Section

List concrete outputs:
- Files created/modified (with paths)
- Components/modules built
- Tests written
- Documentation produced

**Be specific.** Not "authentication system" but:
- `src/auth/login.ts`
- `src/auth/session.ts`
- `src/components/LoginForm.tsx`
- `tests/auth.test.ts`

## Output Location

Write to: `.ai-workflows/YYYYMMDD-task-slug/99-final-report.md`

## After Final Report

GDIM workflow is complete. Workflow directory can be:
- Archived for reference
- Committed to git
- Used as documentation

If new work is needed on same topic:
- Create new workflow directory
- Reference this workflow in new Intent
