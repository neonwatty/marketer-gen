# Testing Guide

## Selective Parallel Testing

This project now supports selective parallel testing where model tests run in parallel for better performance, while controller, integration, and other tests run sequentially to avoid issues with shared state and dependencies.

## Available Test Commands

### Individual Test Types

- `rails test:models_parallel` - Run model tests in parallel (recommended)
- `rails test:controllers` - Run controller tests sequentially 
- `rails test:integration` - Run integration tests sequentially
- `rails test:system` - Run system tests sequentially
- `rails test:services` - Run service tests sequentially
- `rails test:jobs` - Run job tests sequentially
- `rails test:mailers` - Run mailer tests sequentially
- `rails test:helpers` - Run helper tests sequentially
- `rails test:policies` - Run policy tests sequentially

### Combined Commands

- `rails test` or `rails test:selective` - Run all tests with appropriate execution method
  - Models run in parallel
  - All other test types run sequentially

## Why This Setup?

### Model Tests (Parallel ✅)
- **Isolated**: Model tests typically don't share state between tests
- **Fast**: Parallel execution dramatically speeds up the test suite
- **Safe**: Database isolation prevents conflicts between parallel processes

**Example output:**
```
Running 847 tests in parallel using 10 processes
Finished in 6.304249s, 134.3538 runs/s, 509.6563 assertions/s.
```

### Controller & Integration Tests (Sequential ⏳)
- **Shared State**: May depend on session handling, authentication state
- **Complex Dependencies**: Integration tests span multiple layers
- **Mocha Compatibility**: Avoids issues with mocking libraries in parallel execution

**Example output:**
```
Finished in 76.309991s, 4.9797 runs/s, 17.2454 assertions/s.
```

## Performance Benefits

- **Model tests**: ~6x faster execution (6s vs ~36s sequentially)
- **Overall test suite**: Significant time savings on the largest test category
- **CI/CD**: Faster feedback loops and reduced build times

## Database Configuration

The database configuration now supports parallel testing with separate databases for each worker:

```yaml
test:
  database: storage/test<%= ENV['TEST_ENV_NUMBER'] %>.sqlite3
```

Rails automatically manages:
- Creating separate test databases (test.sqlite3, test-0.sqlite3, test-1.sqlite3, etc.)
- Database isolation between parallel processes
- Cleanup and setup for each worker

## Files Modified

- `test/parallel_test_helper.rb` - New helper for model tests with parallel execution
- `test/test_helper.rb` - Updated with clear documentation about sequential execution
- `config/database.yml` - Added support for parallel test databases
- `lib/tasks/parallel_testing.rake` - Custom Rake tasks for selective execution

## Troubleshooting

### If model tests fail in parallel but pass individually:
- Check for shared state between tests
- Ensure proper test isolation
- Verify database fixtures are properly isolated

### If you need to disable parallel execution temporarily:
```bash
# Run model tests sequentially
rails test test/models/**/*_test.rb
```

### To check test execution mode:
- Parallel tests show: "Running X tests in parallel using Y processes"
- Sequential tests show standard Rails test output without parallel indicators