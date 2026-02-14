---
name: gdim-summary
description: Use after implementation to document execution results factually without judgment
---

# Generate Execution Summary

**Purpose**: Document what actually happened during execution. Facts only, no evaluation.

## Usage

Claude Code (plugin):

```
/gdim-summary <round_number>
```

Codex (skills):

```
$gdim-summary <round_number>
```

## Inputs

- `01-design.round{round_number}.md`
- `02-plan.round{round_number}.md`
- Actual code changes
- `04-execution-log.round{round_number}.md` (if exists)

## Output

`05-execution-summary.round{round_number}.md`

## Summary Requirements

### This is NOT

- ❌ Evaluation ("good", "successful", "works well")
- ❌ Justification ("because X, I did Y")
- ❌ Improvement suggestions
- ❌ Gap analysis (that comes next)

### This IS

- ✅ Factual record of what was implemented
- ✅ Deviations from plan (with no judgment)
- ✅ Discoveries made during execution
- ✅ Temporary decisions made
- ✅ Blockers encountered

## Template

```markdown
# Execution Summary — Round <round_number>

## Completed

### [Design Element 1]
- Implemented: [What was actually built]
- Files: [Paths to changed files]
- Matches plan: Yes/Partial/No

### [Design Element 2]
[Same structure]

## Deviations from Plan

| Plan Step | What Happened | Reason |
|-----------|---------------|--------|
| Step 3: Add error handling | No error handling added | Not specified in plan details |
| Step 5: Display avatar | Used placeholder for missing avatars | Plan didn't specify null handling |

## Discoveries

- API returns additional fields: phone, address, preferences (not used)
- API returns 500 on invalid user ID (not handled)
- Loading state not implemented (not in plan)
- No validation on user input (not in plan)

## Temporary Decisions

- Used `useState` for local state (plan didn't specify state management)
- Named component `ProfilePage` (plan said "profile component")
- Placed in `src/components/` (plan didn't specify directory)

## Blockers

[None / or list blockers that stopped execution]

## Files Changed

- `src/components/ProfilePage.tsx` (created)
- `src/App.tsx` (modified - added route)
```

## Writing Style

**Neutral, factual, past tense:**

✅ Good:
- "Implemented login form with email and password fields"
- "Error handling was not added"
- "API returned extra fields which were not used"

❌ Bad:
- "Successfully implemented a robust login form"
- "Decided to skip error handling for simplicity"
- "Wisely ignored extra API fields to maintain focus"

## Deviations Section

**Every deviation must be listed**, even small ones:
- Plan said X, did Y
- Plan didn't specify X, did Y
- Plan said X, didn't do it

**No justification needed.** Just state the fact.

## Discoveries Section

List everything you noticed that wasn't in the plan:
- API behavior
- Missing error cases
- Edge cases
- Performance issues
- Integration problems
- Better approaches

**Don't evaluate** whether these are problems. Just list them.

## Common Mistakes

| Mistake | Example | Fix |
|---------|---------|-----|
| Evaluation | "The implementation works well" | "The implementation matches plan steps 1-5" |
| Justification | "I added error handling because it's necessary" | "Added error handling (not in plan)" |
| Hiding deviations | Omitting "small" changes | List ALL deviations |
| Premature gap analysis | "This needs improvement" | Save for Gap Analysis |

## Verification

Before finalizing summary, check:
- [ ] No evaluative language ("good", "bad", "successful")
- [ ] No justifications ("because", "in order to")
- [ ] All deviations listed
- [ ] All discoveries listed
- [ ] Factual tone throughout

## Output Location

Write to: `.ai-workflows/YYYYMMDD-task-slug/05-execution-summary.round{round_number}.md`

## Next Step

After summary is confirmed → `/gdim-gap <round_number>` (Codex: `$gdim-gap <round_number>`) for Gap Analysis
