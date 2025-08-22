# Rule: Show Next Task

## Context

- Task number to show: "$ARGUMENT"

## Goal
Display the next task from the task list for user review without taking any implementation action.

## Usage
```
/see-next-task [optional-task-number]
```

## Process

1. **Task Discovery**
   - If $ARGUMENT provided: Find and display the specified task
   - Else: Search for task files in `tasks/`, `.claude/tasks/`, `.taskmaster/tasks/` directories
   - If no task file found or invalid argument, return clear error message with available options

2. **Task Display**
   - Extract the next uncompleted task from the task list
   - Show task details including:
     - Task number and title
     - Task description and requirements
     - Related documentation links
     - Dependencies (if any)
     - Estimated complexity or notes

3. **Context Information**
   - Display relevant files that would be involved
   - Show any prerequisites or dependencies
   - Provide documentation references for the task

4. **No Implementation**
   - This command is read-only - do not start working on the task
   - Do not create todos or begin implementation
   - Simply present the task information for user review

## Output Format
```
## Next Task: [Task Number and Title]

**Description:** [Task details]

**Files Involved:**
- [List of relevant files]

**Documentation References:**
- [Relevant docs and guides]

**Status:** [Current status - typically "pending"]

**Dependencies:** [Any prerequisite tasks]
```

## Error Handling
- If no uncompleted tasks found: "All tasks completed!"
- If task file not found: "No task file found. Available locations: tasks/, .claude/tasks/, .taskmaster/tasks/"
- If invalid task number: "Task [number] not found. Available tasks: [list]"