---
name: gdim-init
description: Use when starting a new GDIM workflow to initialize directory structure
---

# Initialize GDIM Workflow

Creates the `.ai-workflows/` directory structure for a new GDIM task.

## Usage

```
/gdim-init <task-slug>
```

Example: `/gdim-init user-authentication`

## What It Does

Creates directory: `.ai-workflows/YYYYMMDD-<task-slug>/`

The user will create `00-intent.md` manually or using `/gdim-intent`.

## Implementation

```bash
# Get task slug from argument
TASK_SLUG="$0"

# Validate task slug
if [ -z "$TASK_SLUG" ]; then
  echo "Error: Task slug required"
  echo "Usage: /gdim-init <task-slug>"
  exit 1
fi

# Create directory with date prefix
DATE=$(date +%Y%m%d)
WORKFLOW_DIR=".ai-workflows/${DATE}-${TASK_SLUG}"

if [ -d "$WORKFLOW_DIR" ]; then
  echo "Error: Workflow directory already exists: $WORKFLOW_DIR"
  exit 1
fi

mkdir -p "$WORKFLOW_DIR"
echo "Created GDIM workflow directory: $WORKFLOW_DIR"
echo ""
echo "Next steps:"
echo "1. Create Intent: /gdim-intent"
echo "2. Or manually create: $WORKFLOW_DIR/00-intent.md"
```

## Next Steps

After initialization:
1. Use `/gdim-intent` to generate Intent through guided questions
2. Or manually create `00-intent.md` if you have clear requirements
3. Then use `/gdim-scope 1` to start Round 1
