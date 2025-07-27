# Claude Code Instructions

## Task Master AI Instructions
**Import Task Master's development workflow commands and guidelines, treat as if import is in the main CLAUDE.md file.**
@./.taskmaster/CLAUDE.md

## Development Workflow Guidelines

### Testing Priority
- **Always write tests first or immediately after implementing a feature**
- Prioritize both unit tests and integration tests for all new functionality
- Run tests frequently during development to catch issues early
- Ensure all tests pass before moving to the next feature
- Test coverage should include:
  - Model validations and business logic (unit tests)
  - Controller actions and responses (controller tests)
  - Complete user workflows (integration tests)
  - Edge cases and error handling

### Git Workflow
- **Commit code frequently** - after each meaningful step or feature completion
- Use clear, descriptive commit messages that explain what was changed
- Push code to remote repository regularly to ensure work is backed up
- Typical workflow:
  1. Implement a small feature or fix
  2. Write/update tests for that feature
  3. Run tests to ensure everything passes
  4. Commit with a descriptive message
  5. Push to remote repository
  6. Move to next task

### Example Commit Pattern
```bash
# After creating models
git add -A && git commit -m "Add User and Session models with authentication"
git push

# After implementing controllers
git add -A && git commit -m "Implement registration and session controllers"
git push

# After adding tests
git add -A && git commit -m "Add comprehensive tests for authentication flow"
git push
```

### Rails-Specific Testing Commands
```bash
# Run all tests
rails test

# Run specific test file
rails test test/models/user_test.rb

# Run specific test
rails test test/models/user_test.rb:15

# Run tests with verbose output
rails test -v
```

## Specialized Agents

Claude Code has access to specialized agents in the `.claude/agents` directory that can be invoked using the Task tool. These agents are experts in specific domains and should be used proactively when their expertise matches the task at hand.

### Available Agents

#### error-debugger
- **When to use**: Encountering any errors, test failures, unexpected behavior, or debugging needs
- **Expertise**: Build failures, runtime errors, failing tests, performance issues
- **Usage**: Should be used proactively whenever issues arise during development

#### test-runner-fixer
- **When to use**: Need to run tests and automatically fix any failures
- **Expertise**: Writing tests, fixing test failures, test coverage improvements
- **Usage**: After implementing features or when tests are failing

#### ruby-rails-expert
- **When to use**: Working with Ruby language or Rails framework
- **Expertise**: Rails 8, ActiveRecord, Action Cable, Hotwire/Turbo, Rails testing, deployment
- **Usage**: For Rails-specific implementations, debugging Rails apps, or architectural decisions

#### javascript-package-expert
- **When to use**: Managing JavaScript packages and dependencies
- **Expertise**: npm/yarn/pnpm, package.json configuration, dependency resolution, security audits
- **Usage**: When dealing with JS dependencies, bundle optimization, or package conflicts

#### tailwind-css-expert
- **When to use**: Writing or debugging Tailwind CSS
- **Expertise**: Utility classes, responsive design, dark mode, custom configurations
- **Usage**: For styling components, creating layouts, or migrating to Tailwind

#### git-auto-commit
- **When to use**: Need to commit and push code changes
- **Expertise**: Analyzing changes, creating detailed commit messages, pushing to remote
- **Usage**: After code modifications are complete and tested

#### project-orchestrator
- **When to use**: Need high-level project coordination or planning
- **Expertise**: Breaking down complex projects, coordinating multiple tasks, strategic planning
- **Usage**: For complex projects requiring coordination between different development aspects

### How to Use Agents

Agents are invoked using the Task tool with the appropriate `subagent_type` parameter:

```javascript
// Example: Using the error-debugger agent
Task(
  description="Debug test failure",
  prompt="The user authentication test is failing with a nil error",
  subagent_type="error-debugger"
)

// Example: Using multiple agents for a complex task
Task(
  description="Plan feature implementation",
  prompt="Plan the implementation of a new user dashboard with real-time updates",
  subagent_type="project-orchestrator"
)
```

### Best Practices for Agent Usage

1. **Use agents proactively** - Don't wait for the user to ask; if you encounter an error, use error-debugger immediately
2. **Delegate to specialists** - Let agents handle their domains of expertise rather than trying to do everything yourself
3. **Chain agents when needed** - Use project-orchestrator to plan, then specific agents to implement
4. **Trust agent outputs** - Agents are specialized and their recommendations should generally be followed
5. **Batch when possible** - Launch multiple agents concurrently for independent tasks to maximize efficiency
