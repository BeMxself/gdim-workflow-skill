---
name: gdim-execute
description: Use during code implementation to maintain discipline and avoid scope creep
---

# GDIM Execution Discipline

**Purpose**: Keep implementation aligned with plan. Resist "obvious improvements."

## Usage

```
gdim-execute <round_number>
```

Loads execution rules for current round.

## The Core Rule

**Follow the plan exactly. Deviations = stop and update plan first.**

## Input

`02-plan.round{round_number}.md`

## During Execution

### What You MUST Do

1. **Follow plan steps in order**
2. **Implement only what's specified**
3. **Track deviations** (even small ones)
4. **Stop if blocked** - don't work around

### What You MUST NOT Do

❌ Add error handling not in plan
❌ Add loading states not in plan
❌ Use extra API fields not in plan
❌ Add TypeScript types not in plan
❌ Handle edge cases not in plan
❌ Apply "best practices" not in plan
❌ "Fix" things you notice
❌ "Improve" the design

## Red Flags - STOP Immediately

From baseline testing, these thoughts mean you're about to violate scope:

| Thought | What It Means | What To Do |
|---------|---------------|------------|
| "The plan didn't specify error handling" | Plan is incomplete | Stop. Ask user or update plan. |
| "I should add loading state" | Out of scope addition | Stop. Record as potential Gap. |
| "This API returns extra fields, I'll use them" | Scope creep | Stop. Use only planned fields. |
| "Without X, this won't work in production" | "Production-ready" rationalization | Stop. X is out of scope. |
| "Any developer would add Y" | "Best practices" rationalization | Stop. Y not in plan = out of scope. |
| "This is obviously necessary" | Most dangerous rationalization | Stop. Obvious ≠ in scope. |

**All of these mean: STOP. Don't implement. Record as observation.**

## Handling Discoveries

During execution, you WILL discover:
- Missing error handling
- Unhandled edge cases
- API inconsistencies
- Design gaps
- Better approaches

### Correct Response

1. **Note the discovery**
2. **Continue with plan as-is**
3. **Record in execution summary**
4. **It becomes a Gap** in Gap Analysis

### Incorrect Response

❌ "I'll just quickly add..."
❌ "This will only take a minute..."
❌ "The plan implied this..."
❌ "I'm following the spirit of the plan..."

**No.** Plan says X, you do X. Discoveries → Gaps → Next round.

## Blocked During Execution?

If you can't complete a plan step:

1. **Stop immediately**
2. **Don't work around it**
3. **Don't try alternative approaches**
4. **Document the blocker**
5. **Ask user**

Example:
```markdown
## Execution Blocked

**Step 3**: "Fetch user data from /api/user/:id"

**Blocker**: API endpoint returns 404. Endpoint may not exist or URL is incorrect.

**Action needed**: User must verify API endpoint.

**Work completed**: Steps 1-2 only.
```

## Temporary Decisions

Sometimes you must make small decisions not specified in plan:
- Variable names
- Code organization
- Comment style

These are fine IF they don't change behavior or scope.

**Not fine**:
- Choosing error handling strategy
- Deciding which fields to display
- Adding validation logic
- Choosing loading behavior

## Execution Log (Optional)

For complex rounds, maintain `04-execution-log.round{round_number}.md`:

```markdown
# Execution Log — Round <round_number>

## Step 1: Create ProfilePage component
- ✓ Created src/components/ProfilePage.tsx
- ✓ Added basic structure

## Step 2: Fetch user data
- ✓ Added fetch call
- ⚠️ Discovered: API returns 500 on invalid ID
- ⚠️ Plan doesn't specify error handling
- ✓ Continued without error handling (as per plan)

## Step 3: Display user info
- ✓ Display name, email, avatar
- ⚠️ Discovered: API also returns phone, address
- ✓ Did NOT display extra fields (not in plan)
```

## Common Rationalizations

| Excuse | Reality |
|--------|---------|
| "Plan was incomplete" | Incomplete plan = stop and ask, not fill gaps. |
| "This is standard practice" | Standard ≠ in scope. Record as Gap. |
| "User will expect this" | User expects plan execution. Extras = scope creep. |
| "It's just defensive coding" | Defensive coding out of plan = out of scope. |
| "The plan implied it" | Implied ≠ explicit. Don't assume. |
| "I'm making it production-ready" | Production-ready = many rounds. This round = plan only. |

## After Execution

→ `gdim-summary <round_number>` to document what actually happened
