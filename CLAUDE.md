# Claude Code Instructions

## Project Overview
This is a Rails 8 marketing campaign platform that enables users to create, manage, and track marketing campaigns. The application uses:
- Rails 8 with Vite for JavaScript packaging
- Tailwind CSS for styling  
- Stimulus for JavaScript interactions
- SQLite for data persistence

Key features include campaign creation, template management, performance analytics, and user management.

## Context7 MCP Documentation Lookup
For all specialized tasks involving external libraries, frameworks, or APIs, use Context7 MCP to fetch current documentation:
- Use `mcp__context7__resolve-library-id` to find the correct library ID
- Use `mcp__context7__get-library-docs` to fetch up-to-date documentation
- Always check documentation before implementing features with unfamiliar libraries
- Examples: Rails 8 features, Stimulus patterns, Tailwind utilities, Vite configuration

## Playwright MCP Testing
Use Playwright MCP for browser-based testing and UI validation:
- Use `mcp__playwright__browser_navigate` to visit application pages
- Use `mcp__playwright__browser_snapshot` to capture page state for analysis
- Use `mcp__playwright__browser_click`, `mcp__playwright__browser_type` for interactions
- Use `mcp__playwright__browser_take_screenshot` for visual verification
- Always start with `mcp__playwright__browser_navigate` to the local Rails server
- Use snapshots before interactions to understand page structure

## Task Master AI Instructions
**Import Task Master's development workflow commands and guidelines, treat as if import is in the main CLAUDE.md file.**
@./.taskmaster/CLAUDE.md
