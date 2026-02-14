---
name: gdim-intent
description: Use when defining Intent for a GDIM workflow from external docs, brainstorming, or user requirements
---

# Generate GDIM Intent

Helps create `00-intent.md` through iterative refinement.

## Intent Sources

Intent can come from:
1. **External documents** - Requirements, PRDs, design specs, bug reports
2. **Brainstorming** - Use the `brainstorming` skill first, then extract Intent
3. **User description** - Direct conversation with user

## Process

**This is iterative, not one-shot.** Goal: refine until user confirms Intent is ready.

### Each Iteration

1. **Clarify ambiguities** - Ask about unclear requirements
2. **Identify conflicts** - Point out contradictions
3. **Extract subset** - Intent is a **focused subset** of input, not full copy
4. **Propose Intent draft** - Show what you understood
5. **Wait for confirmation** - User decides when Intent is final

### Rules

- Don't enter design/implementation discussion
- Don't assume infrastructure exists
- Don't propose solutions
- Intent is **精炼子集**, not full requirements dump
- If using brainstorming output, extract only the agreed-upon goals

## Intent Template

```markdown
# Intent & Baseline

## External References
- [Source document path or "From brainstorming session YYYY-MM-DD"]

## 1. Design Goal
[What are we building and why?]

## 2. Non-Goals
- [What we explicitly won't do]

## 3. Success Criteria
- [ ] [Measurable condition 1]
- [ ] [Measurable condition 2]

## 4. Hard Constraints
- Technology stack: [if specified]
- Performance: [if specified]
- Security: [if specified]
- Compatibility: [if specified]

## 5. Assumptions
- [What we're assuming is true]
```

## Example: From Brainstorming

If user ran `brainstorming` and you explored "user authentication system":

**Brainstorming output** (100 lines of exploration):
- OAuth, password, 2FA, SSO discussed
- Performance concerns raised
- Security requirements explored
- UI mockups considered

**Intent** (focused subset):
```markdown
## External References
- From brainstorming session 2026-02-10

## 1. Design Goal
Implement secure user authentication with email/password login and session management.

## 2. Non-Goals
- OAuth integration (deferred)
- 2FA (deferred)
- SSO (out of scope)

## 3. Success Criteria
- [ ] Users can register with email/password
- [ ] Users can login and logout
- [ ] Sessions persist across page refreshes
- [ ] Passwords are securely hashed

## 4. Hard Constraints
- Must use bcrypt for password hashing
- Session tokens must expire after 24h
- Must work with existing PostgreSQL database

## 5. Assumptions
- Email service for verification is available
- HTTPS is configured in production
```

Notice: Intent is **much smaller** than brainstorming output. It extracts the agreed-upon scope.

## Common Mistakes

| Mistake | Fix |
|---------|-----|
| Copying entire requirements doc | Extract focused subset |
| Including implementation details | Keep at goal level |
| Vague success criteria | Make measurable |
| Assuming infrastructure | List as assumption or constraint |
| Skipping Non-Goals | Explicitly state what's excluded |

## Output

Write to: `.ai-workflows/YYYYMMDD-task-slug/00-intent.md`

After Intent is confirmed, user proceeds to `/gdim-scope 1` (Codex: `$gdim-scope 1`).
