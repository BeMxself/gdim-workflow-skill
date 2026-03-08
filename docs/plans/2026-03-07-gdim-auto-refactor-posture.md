# GDIM Auto Refactor Posture Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add task-level and flow-level `refactor_posture` support to `gdim-auto` so prompt discipline and closure criteria can distinguish `conservative`, `balanced`, and `aggressive` workflows.

**Architecture:** Parse posture from `flows.json` with flow-level override over task-level default, thread the effective posture into stage prompt construction, and extend gap/final semantics with machine-readable posture/fracture markers. Keep runner-side enforcement minimal and focused on posture-aware closure safety, especially when an `aggressive` flow reports unresolved fractures.

**Tech Stack:** Bash automation scripts, Markdown stage templates, shell-based regression tests.

---

### Task 1: Add failing posture coverage tests

**Files:**
- Modify: `skills/gdim-auto/automation-ref/tests/test-stage-prompts-inject-required-files.sh`
- Create: `skills/gdim-auto/automation-ref/tests/test-refactor-posture-flow-override.sh`
- Create: `skills/gdim-auto/automation-ref/tests/test-gap-fracture-status-blocks-needs-decision-final.sh`

**Step 1: Write failing tests**
- Assert task-level `refactor_posture` defaults to `balanced` in prompts.
- Assert flow-level `refactor_posture` overrides task-level posture in prompts.
- Assert `aggressive + GDIM_FRACTURE_STATUS: NEEDS_DECISION` blocks final closure even if gap says `FINAL_REPORT`.

**Step 2: Run targeted tests to verify failure**
- Run the new/updated shell tests individually.

### Task 2: Parse and propagate posture

**Files:**
- Modify: `skills/gdim-auto/automation-ref/run-gdim-flows.sh`
- Modify: `skills/gdim-auto/automation-ref/run-gdim-round.sh`
- Modify: `skills/gdim-auto/automation-ref/lib/prompt-builder.sh`

**Step 1: Resolve effective posture from config**
- Add task-level default parsing from `config/flows.json`.
- Add flow-level override parsing.
- Pass effective posture into round execution.

**Step 2: Inject posture into prompt builder**
- Add posture parameter to `build_prompt`.
- Generate a reusable posture discipline block for templates.

### Task 3: Apply posture discipline to stage templates

**Files:**
- Modify: `skills/gdim-auto/automation-ref/templates/stages/design.md.tpl`
- Modify: `skills/gdim-auto/automation-ref/templates/stages/plan.md.tpl`
- Modify: `skills/gdim-auto/automation-ref/templates/stages/execute.md.tpl`
- Modify: `skills/gdim-auto/automation-ref/templates/stages/gap.md.tpl`

**Step 1: Add posture context and rules**
- Show effective posture in current context.
- Add a dedicated discipline section covering compatibility vs consistency priorities.

**Step 2: Add machine-readable closure markers**
- Require `GDIM_REFACTOR_POSTURE` and `GDIM_FRACTURE_STATUS` in gap output.

### Task 4: Enforce minimal posture-aware closure safety

**Files:**
- Modify: `skills/gdim-auto/automation-ref/lib/validate.sh`
- Modify: `skills/gdim-auto/automation-ref/run-gdim-round.sh`

**Step 1: Parse new gap markers**
- Add helpers for `GDIM_REFACTOR_POSTURE` and `GDIM_FRACTURE_STATUS`.

**Step 2: Block unsafe aggressive closure**
- Prevent final closure when an aggressive flow reports `NEEDS_DECISION`.

### Task 5: Update skill documentation and verify

**Files:**
- Modify: `skills/gdim-auto/SKILL.md`

**Step 1: Document new config fields and semantics**
- Describe task default + flow override behavior.

**Step 2: Run focused shell tests**
- Run the updated posture-related tests.
