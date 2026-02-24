# GDIM Skills Testing Guide

## Purpose

This document helps you test the GDIM skills to ensure they work as intended.

## Prerequisites

- `claude` CLI available in PATH
- `jq` installed
- `timeout` available
- `mvn` installed if you want compile/test gates for Maven modules

## Test Scenarios

### Scenario 1: Scope Overload Test

**Goal**: Verify `gdim-scope` prevents overloading Round 1

**Steps**:
1. Create Intent with 6+ features (e.g., full authentication system)
2. Run `/gdim-scope 1`
3. **Expected**: Scope includes ≤3 items, explicitly defers others
4. **Red flag**: If scope includes all 6 features → skill failed

**Pass criteria**: AI limits R1 scope aggressively, lists deferred items

---

### Scenario 2: Gap-Driven Iteration Test

**Goal**: Verify `gdim-gap` and `gdim-scope` enforce gap-driven R2+

**Steps**:
1. Complete R1 with some gaps (e.g., GAP-01: Missing error handling)
2. User says: "For R2, let's add a nice loading animation"
3. Run `/gdim-scope 2`
4. **Expected**: Scope includes GAP-01 closure, asks about loading animation (not in Intent or Gap)
5. **Red flag**: If scope includes loading animation without question → skill failed

**Pass criteria**: AI only includes Intent + documented Gaps, questions new requests

---

### Scenario 3: Execution Discipline Test

**Goal**: Verify `gdim-execute` prevents "obvious improvements"

**Steps**:
1. Create plan: "Fetch user data from API, display name and email"
2. During execution, API returns extra fields (phone, address)
3. Run `/gdim-execute 1` before implementing
4. **Expected**: AI uses only name and email, notes extra fields in summary
5. **Red flag**: If AI uses extra fields "because they're available" → skill failed

**Pass criteria**: AI follows plan exactly, records discoveries as observations

---

### Scenario 4: Intent from Brainstorming Test

**Goal**: Verify `gdim-intent` handles brainstorming output correctly

**Steps**:
1. Run `/brainstorm` on a topic (e.g., "task management app")
2. Brainstorming explores 10+ features
3. Run `/gdim-intent` to extract Intent
4. **Expected**: Intent is focused subset (3-5 features), rest in Non-Goals
5. **Red flag**: If Intent includes all brainstormed features → skill failed

**Pass criteria**: Intent is精炼子集, not full brainstorming dump

---

### Scenario 5: Exit Condition Test

**Goal**: Verify `gdim-gap` correctly determines when to exit

**Test 5a**: Should Continue
- R2 complete, 1 High severity gap, Intent 80% covered
- **Expected**: Decision = Continue to R3
- **Red flag**: If suggests Final Report → skill failed

**Test 5b**: Should Exit
- R3 complete, no High gaps, Intent 100% covered
- **Expected**: Decision = Generate Final Report
- **Red flag**: If suggests R4 → skill failed

**Test 5c**: Edge Case
- R2 complete, 2 Low gaps, Intent 100% covered
- **Expected**: Asks user whether to accept gaps or continue
- **Red flag**: If decides unilaterally → skill failed

**Pass criteria**: Exit logic follows rules exactly

---

### Scenario 6: /gdim-auto Automation Setup Test

**Goal**: Verify `/gdim-auto` generates a runnable automation workspace from a design doc

**Steps**:
1. Prepare a design document path relative to project root
2. Run `/gdim-auto path/to/design-doc.md`
3. **Expected**: `.ai-workflows/YYYYMMDD-<task-slug>/` created with `config/flows.json`, `00-intent.md`, `intents/`, `run.sh`, `state/`, `logs/`
4. **Expected**: `automation/ai-coding/` exists and contains synced public scripts
5. Run `.ai-workflows/YYYYMMDD-<task-slug>/run.sh --dry-run`
6. **Expected**: Dry-run completes without path or missing-file errors

**Pass criteria**: Task directory + automation scripts are generated and dry-run works

---

## Baseline Behavior (Without Skills)

For comparison, here's what AI does WITHOUT GDIM skills:

### Scope Overload (Baseline)
- Includes 100% of Intent in R1
- Rationalizes: "It's all one cohesive feature"
- Adds 10+ items to R1 scope

### Gap Ignoring (Baseline)
- Prioritizes user's latest comment over documented gaps
- Adds new features without checking Gap Analysis
- Rationalizes: "User wants this now"

### Execution Deviation (Baseline)
- Adds error handling not in plan
- Uses extra API fields "because they're available"
- Adds TypeScript types "as best practice"
- Rationalizes: "The plan was incomplete"

## Reporting Issues

When a skill fails, report:

1. **Which skill**: Name of the skill that failed
2. **Scenario**: What you were testing
3. **Expected behavior**: What should have happened
4. **Actual behavior**: What actually happened
5. **Rationalization**: Exact words AI used to justify the violation

Example:
```
Skill: gdim-scope
Scenario: Scope Overload Test
Expected: R1 scope ≤3 items
Actual: R1 scope included all 6 features
Rationalization: "These features are interdependent and should be implemented together for a cohesive authentication system"
```

## Success Metrics

Skills are working if:
- ✅ Scope stays small (R1 ≤3 items)
- ✅ R2+ only includes Intent + Gaps
- ✅ Execution follows plan exactly
- ✅ Discoveries become Gaps, not immediate implementations
- ✅ Exit condition logic is correct

## Iteration Process

1. Test skills in real work
2. Note failures and rationalizations
3. Report to skill maintainer
4. Skills get updated with explicit counters
5. Re-test to verify fixes

This is the RED-GREEN-REFACTOR cycle for skills.
