# GDIM Workflow — Claude Code Plugin

[English](README.en.md) | [中文](README.md)

A Claude Code plugin for the **Gap-Driven Iteration Model (GDIM)** — a disciplined workflow for AI-assisted software development.

## Installation

### Claude Code (Plugin)

Install in Claude Code by adding this GitHub repo as a plugin marketplace:

```text
/plugin marketplace add BeMxself/gdim-workflow-skill
```

Then install the plugin:

```text
/plugin install gdim-workflow@BeMxself-gdim-workflow-skill
```

After installation, all `/gdim-*` commands will be available.

### Codex (Skills)

Per Codex skills docs, Codex scans skill folders from:
- project-level `.agents/skills/` (from current directory up to repo root)
- user-level `$HOME/.agents/skills/`

Option A (Recommended): Install via `$skill-installer` inside Codex

In a Codex chat, you can ask the installer to pull these skills from GitHub (multiple paths in one run):

```text
$skill-installer Please install these skills from GitHub repo BeMxself/gdim-workflow-skill:
- skills/gdim
- skills/gdim-init
- skills/gdim-intent
- skills/gdim-scope
- skills/gdim-design
- skills/gdim-plan
- skills/gdim-execute
- skills/gdim-summary
- skills/gdim-gap
- skills/gdim-final
```

Restart Codex to pick up the new skills.

Option B: Manual install (rsync)

User-level installation:

```bash
mkdir -p ~/.agents/skills
rsync -a skills/ ~/.agents/skills/
```

Project-level installation (run in your target project):

```bash
mkdir -p .agents/skills
rsync -a /path/to/gdim-workflow-skill/skills/ .agents/skills/
```

To update later, re-run the corresponding `rsync` command.

Tip:
- In Codex app/IDE, matching skills can be invoked automatically.
- You can also ask Codex explicitly to use a skill by name (for example: `$gdim-scope`).
- Use `/skills` in Codex to view active skills.

### Kiro CLI (Skills)

Kiro CLI can load skills from `.kiro/skills/**/SKILL.md` (workspace) and use them via an agent profile.

1) Install skills into the current repo/workspace:

```bash
mkdir -p .kiro/skills
rsync -a skills/ .kiro/skills/
```

2) Create an agent that includes the skill resources (this opens an editor):

```bash
mkdir -p .kiro/agents
kiro-cli agent create --name "GDIM Agent" --directory .kiro/agents
```

3) In `.kiro/agents/gdim_agent.json`, add this resource entry:

```json
{ "resources": ["skill://.kiro/skills/**/SKILL.md"] }
```

4) Start a chat with that agent:

```bash
kiro-cli chat --agent "GDIM Agent"
```

## Relationship to GDIM Specification

These skills are **executable companions** to the GDIM specification documents:

- **Skills** (`skills/`): Quick-reference rules for active workflows, optimized for Claude Code
- **Portable reference** (`skills/gdim/references/gdim-portable-reference.md`): Bundled fallback for skills-only installations
- **Specification** ([`skills/gdim/references/docs/GDIM 规范.md`](skills/gdim/references/docs/GDIM%20规范.md)): Complete methodology, templates, and rationale
- **Quick Guide** ([`skills/gdim/references/docs/GDIM 实践快速指南.md`](skills/gdim/references/docs/GDIM%20实践快速指南.md)): Human-readable introduction
- **Prompt Templates** ([`skills/gdim/references/docs/GDIM 提示词模版.md`](skills/gdim/references/docs/GDIM%20提示词模版.md)): Detailed prompts for each stage
- **Frontend Templates** ([`skills/gdim/references/docs/GDIM 提示词模版（前端版）.md`](skills/gdim/references/docs/GDIM%20提示词模版（前端版）.md)): Frontend-specific constraints

**When to use what:**
- Working in Claude Code → Use these skills (`/gdim-*` commands)
- Learning GDIM → Read [`skills/gdim/references/docs/GDIM 实践快速指南.md`](skills/gdim/references/docs/GDIM%20实践快速指南.md)
- Need detailed templates → Reference [`skills/gdim/references/docs/GDIM 规范.md`](skills/gdim/references/docs/GDIM%20规范.md) or [`skills/gdim/references/docs/GDIM 提示词模版.md`](skills/gdim/references/docs/GDIM%20提示词模版.md)
- Frontend projects → Also see [`skills/gdim/references/docs/GDIM 提示词模版（前端版）.md`](skills/gdim/references/docs/GDIM%20提示词模版（前端版）.md)

## What is GDIM?

GDIM constrains AI execution through:
- **Explicit scope limiting** - Each round does a small, focused piece
- **Gap-driven iteration** - Deviations become explicit gaps that drive next rounds
- **Strict traceability** - Every design/plan must declare what drives it

**Core principle**: Small scopes → visible gaps → controlled iteration → reliable delivery

## Quick Start

### 1. Initialize a Workflow

```bash
/gdim-init user-authentication
```

Creates `.ai-workflows/YYYYMMDD-user-authentication/`

### 2. Define Intent

```bash
/gdim-intent
```

Creates `00-intent.md` through guided questions. Intent can come from:
- External documents (requirements, PRDs, design specs)
- Brainstorming session (use `/brainstorm` first)
- Direct user description

### 3. Run Rounds

Each round follows the same cycle:

```bash
/gdim-scope 1      # Define what THIS round will do (limited!)
/gdim-design 1     # Design only what's in scope
/gdim-plan 1       # Create executable plan
# Execute the plan (write code)
/gdim-execute 1    # Load execution discipline rules
/gdim-summary 1    # Document what actually happened
/gdim-gap 1        # Analyze deviations, decide if continuing
```

### 4. Iterate or Finish

- **If gaps exist or Intent incomplete** → `/gdim-scope 2` (next round)
- **If no High gaps and Intent 100% covered** → `/gdim-final`

## Available Skills

| Skill | Purpose | When to Use |
|-------|---------|-------------|
| `gdim` | Core rules (auto-loaded) | Background knowledge |
| `gdim-init` | Initialize workflow directory | Starting new GDIM task |
| `gdim-intent` | Generate Intent document | Defining goals from docs/brainstorming |
| `gdim-scope` | Define round scope | Starting each round |
| `gdim-design` | Generate design | After scope is defined |
| `gdim-plan` | Create execution plan | After design is confirmed |
| `gdim-execute` | Execution discipline | During code implementation |
| `gdim-summary` | Document execution results | After implementation |
| `gdim-gap` | Analyze deviations | After execution summary |
| `gdim-final` | Generate final report | When work is complete |

## Key Concepts

### Scope is a Speed Limiter

Scope's job is to **prevent overload**, not list todos. Round 1 should be small enough to fail in interesting ways.

**Good R1 scope**: Login form with email/password (no validation, no error handling)
**Bad R1 scope**: Complete authentication system with OAuth, 2FA, password reset, session management

### Gaps are the Engine

Gaps are **structural deviations** between expected and actual:
- Missing error handling → Gap
- Unhandled edge case → Gap
- Performance issue → Gap
- Better approach discovered → Gap

**No gap = no improvement.** R2+ can only work on documented gaps or uncompleted Intent.

### Exit Condition

Work continues until BOTH are true:
1. ✅ No High Severity Gap in current round
2. ✅ Intent 100% covered

## Common Pitfalls

### "It's All One Feature"

**Wrong**: "Authentication is one feature, let's do it all in R1"
**Right**: "R1: Login form. R2: Session management. R3: Password reset."

Features are always divisible. Divide them.

### "This is Obviously Necessary"

**Wrong**: Plan says "fetch user data", you add error handling because "obviously needed"
**Right**: Plan says "fetch user data", you fetch data. No error handling → becomes a Gap.

Obvious to you ≠ in scope. Record as Gap.

### "Following Best Practices"

**Wrong**: Plan doesn't mention TypeScript types, you add them because "best practice"
**Right**: Plan doesn't mention types, you don't add them. Missing types → Gap if it matters.

Best practices out of scope = record as Gap.

## Red Flags

If you're thinking any of these, STOP:

- "While I'm doing X, I should also do Y"
- "This will need Z eventually"
- "The plan didn't specify, so I'll..."
- "Any developer would add..."
- "It's incomplete without..."
- "I'm following the spirit of the plan"

**All of these mean: You're about to violate scope.**

## File Structure

```
.ai-workflows/YYYYMMDD-task-slug/
├── 00-intent.md                    # Goals (human-written)
├── 00-intent.changelog.md          # Intent changes (optional)
├── 00-scope-definition.round1.md   # R1 scope
├── 01-design.round1.md             # R1 design
├── 02-plan.round1.md               # R1 plan
├── 04-execution-log.round1.md      # R1 log (optional)
├── 05-execution-summary.round1.md  # R1 summary
├── 03-gap-analysis.round1.md       # R1 gaps
├── 00-scope-definition.round2.md   # R2 scope
├── ...                             # R2 files
└── 99-final-report.md              # Final summary
```

## Testing Status

**Core skills tested** (baseline behavior documented):
- ✅ `gdim-scope` - Tested against scope overload
- ✅ `gdim-gap` - Tested against ignoring documented gaps
- ✅ `gdim-execute` - Tested against "obvious improvements"

**Other skills**: Based on GDIM documentation and common patterns.

## Feedback Loop

These skills are designed to be iteratively improved:

1. Use the skills in real work
2. Note where they fail or are unclear
3. Report issues to skill maintainer
4. Skills get updated based on real rationalizations

**Your feedback makes these skills better.**

## References

- Full GDIM specification: [`skills/gdim/references/docs/GDIM 规范.md`](skills/gdim/references/docs/GDIM%20规范.md)
- Quick reference guide: [`skills/gdim/references/docs/GDIM 实践快速指南.md`](skills/gdim/references/docs/GDIM%20实践快速指南.md)
- Prompt templates: [`skills/gdim/references/docs/GDIM 提示词模版.md`](skills/gdim/references/docs/GDIM%20提示词模版.md)
- Frontend-specific: [`skills/gdim/references/docs/GDIM 提示词模版（前端版）.md`](skills/gdim/references/docs/GDIM%20提示词模版（前端版）.md)

## Version

**v1.1.0** - Claude Code plugin release based on GDIM v1.5 specification
