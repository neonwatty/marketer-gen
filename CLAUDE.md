# Claude Code Instructions

## Project Overview: Marketer Gen Next.js App

This is a marketing content generation application built with Next.js. The app allows marketers to:

- Generate marketing copy and content using AI
- Create and manage marketing campaigns
- Customize content templates and styles
- Export content in various formats
- Track content performance and metrics

### Tech Stack
- **Framework**: Next.js (React)
- **Styling**: Tailwind CSS + shadcn/ui components
- **Backend**: Next.js API routes
- **Database**: SQLite with better-sqlite3
- **AI Integration**: OpenAI API or similar for content generation

## MCP Server Usage Instructions

### Context7 MCP - Documentation Lookup
For any specialized technical tasks requiring documentation:
```bash
# Resolve library name to get proper ID first
mcp__context7__resolve-library-id <library-name>
# Then fetch documentation
mcp__context7__get-library-docs <context7-compatible-id>
```
Use this for Next.js, React, Tailwind, or any other library documentation needs.

### shadcn/ui MCP - UI Components
For UX and component implementation tasks:
```bash
# List all available components
mcp__shadcn-ui__list_components
# Get component source code
mcp__shadcn-ui__get_component <component-name>
# Get component usage examples
mcp__shadcn-ui__get_component_demo <component-name>
# Get pre-built UI blocks
mcp__shadcn-ui__list_blocks
mcp__shadcn-ui__get_block <block-name>
```
Use for implementing forms, buttons, modals, layouts, and other UI elements.

### Playwright MCP - Testing
For automated testing and browser interactions:
```bash
# Take screenshots and analyze pages
mcp__playwright__browser_take_screenshot
# Navigate and interact with the app
mcp__playwright__browser_navigate <url>
mcp__playwright__browser_click
# Capture page snapshots for testing
mcp__playwright__browser_snapshot
```
Use for end-to-end testing, UI testing, and automated browser workflows.

## Task Master AI Instructions
**Import Task Master's development workflow commands and guidelines, treat as if import is in the main CLAUDE.md file.**
@./.taskmaster/CLAUDE.md
