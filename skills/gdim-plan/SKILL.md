---
name: gdim-plan
description: Use when creating executable implementation plans from GDIM design documents
---

# Generate GDIM Plan

Converts design into step-by-step executable plan.

## Usage

```
gdim-plan <round_number>
```

## Input

`01-design.round{round_number}.md`

## Output

`02-plan.round{round_number}.md`

## Plan Requirements

### Header

```yaml
---
round: <round_number>
design: 01-design.round{round_number}.md
---
```

### Content

Each step must be:
- **Specific**: File paths, function names, exact changes
- **Executable**: Clear enough to follow mechanically
- **Ordered**: Dependencies respected
- **Testable**: Know when step is complete

### Template

```markdown
# Plan — Round <round_number>

## Design Mapping

| Design Element | Plan Steps |
|----------------|------------|
| [Component A] | Steps 1-3 |
| [Interface B] | Steps 4-5 |

## Implementation Steps

### 1. [Specific action]
- File: `path/to/file.ts`
- Action: [Create/Modify/Delete]
- Details: [Exact change]
- Verification: [How to confirm it worked]

### 2. [Next specific action]
[Same structure]

## Dependencies

- Step X depends on Step Y
- External dependency: [if any]

## Out of Scope Reminders

[Explicitly list what this plan does NOT do, from design]
```

## Common Mistakes

From baseline testing, plans often fail by being too vague:

| Bad Plan Step | Good Plan Step |
|---------------|----------------|
| "Implement user profile" | "Create ProfilePage.tsx with name, email, avatar display" |
| "Add error handling" | "Wrap fetch in try-catch, set error state, display error message" |
| "Set up authentication" | "Install bcrypt, create hashPassword function in auth.ts, add to user registration endpoint" |
| "Handle edge cases" | "Add null check for user.avatar, show placeholder if missing" |

**Test**: Could another developer follow this plan without asking questions? If no → too vague.

## Scope Boundaries in Plan

Plan must respect design boundaries. If plan includes steps for out-of-scope items:
- **Stop**
- **Remove those steps**
- **Or update design first** (if genuinely needed)

## Uncertainty in Plan

If you can't write specific steps because information is missing:
1. **Don't write vague steps**
2. **Note the blocker** in plan
3. **Ask user for clarification**

Example:
```markdown
### BLOCKED: Step 3 - API Integration
Cannot plan this step without knowing:
- API endpoint URL
- Authentication method
- Response format

**Action needed**: User must provide API specification.
```

## Output Location

Write to: `.ai-workflows/YYYYMMDD-task-slug/02-plan.round{round_number}.md`

## Next Step

After plan is confirmed → Execute the plan (or `gdim-execute <round_number>` for execution guidance)
