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
