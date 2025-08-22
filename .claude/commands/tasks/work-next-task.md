# Rule: Work Next Task

## Context

- Task number to work on: "$ARGUMENT"

## Goal
Help developers work on tasks with auto-fetched documentation context and implementation guidance.

## Usage
```
/next-task [optional-task-number]
```

## Process

1. **Task Discovery & Validation**
   - If $ARGUMENT provided: Validate argument format and find specified task
   - Else: Search for task files in `.taskmaster/tasks/`, `tasks/`, `.claude/tasks/` directories
   - If no task file found or invalid argument, return clear error message with available options

2. **TodoWrite Initialization (Single-Threaded Execution)**
   - Create initial TodoWrite with task discovery, context extraction, implementation steps
   - Mark ONLY the first todo as `in_progress` (enforce one active task at a time)
   - Include error handling todos for potential failure points

3. **Context & Implementation**
   - Extract task context and documentation references
   - Use WebSearch to fetch relevant documentation context
   - Mark current todo as `completed`, update next todo to `in_progress`
   - Carefully expand the task into implementation steps and update TodoWrite list
   - Complete each step individually, updating TodoWrite status immediately

4. **Testing & Validation Pipeline**
   - Determine proper unit and integration tests for implemented task
   - Run project-specific testing commands (check CLAUDE.md for test commands)
   - Run linting/typecheck validation if available
   - Handle test failures by creating recovery todos, keep original task `in_progress`

5. **Quality Assurance**
   - Spawn validation agent via Task tool to independently review
   - If validation fails: Create specific fix todos, maintain task as `in_progress`
   - If validation succeeds: Mark all todos `completed`, mark task complete in task file
   - Commit changes with descriptive message following project git workflow

6. **Error Recovery**
   - On any failure: Preserve current state, create specific recovery todos
   - Never mark task complete unless all validation passes
   - Provide clear next steps for manual intervention if needed
