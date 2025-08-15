# Database and Prisma Tests

This directory contains comprehensive tests for the Prisma ORM integration with SQLite database.

## Test Structure

### Core Tests
- `prisma.test.ts` - Basic Prisma Client configuration and connection tests
- `database-config.test.ts` - Environment variable and database configuration tests
- `database-utils.test.ts` - Database utility functions and connection management
- `schema-validation.test.ts` - Prisma schema file validation and syntax checking
- `database-errors.test.ts` - Error handling for various database failure scenarios
- `prisma-client-generation.test.ts` - Generated Prisma client validation and configuration

### API Tests
- `../app/api/__tests__/database-connection.test.ts` - API route tests with Prisma integration

### Test Utilities
- `../test-utils/database-test-utils.ts` - Shared utilities for database testing, mocking, and setup
- `setup/database-test-utils.test.ts` - Tests for the database test utilities themselves

## Running Tests

```bash
# Run all Prisma/database related tests
npm run test:prisma

# Run all API tests
npm run test:api

# Run all tests
npm test

# Run tests with coverage
npm run test:coverage

# Watch mode for development
npm run test:watch
```

## Test Configuration

- **Jest Setup**: `jest.setup.prisma.js` provides global Prisma mocking
- **Mock Strategy**: Tests use Jest mocks to avoid actual database connections
- **Environment**: Tests run with `NODE_ENV=test` and `DATABASE_URL=file:./test.db`

## Key Testing Patterns

### 1. Prisma Client Mocking
```typescript
jest.mock('@prisma/client', () => ({
  PrismaClient: jest.fn().mockImplementation(() => ({
    $connect: jest.fn(),
    $disconnect: jest.fn(),
  })),
}))
```

### 2. Error Testing
```typescript
mockPrisma.$connect.mockRejectedValue(new Error('Connection failed'))
await expect(prisma.$connect()).rejects.toThrow('Connection failed')
```

### 3. API Route Testing
```typescript
const response = await GET()
const data = await response.json()
expect(response.status).toBe(200)
```

## Test Coverage Areas

- ✅ Prisma Client instantiation and configuration
- ✅ Database connection and disconnection
- ✅ Environment variable validation
- ✅ Schema file structure and syntax
- ✅ Error handling (connection failures, permissions, etc.)
- ✅ API route integration
- ✅ Generated client validation
- ✅ Git ignore configuration

## Prerequisites

1. **Prisma Setup**: Ensure Prisma is installed and configured
2. **Schema File**: Valid `prisma/schema.prisma` file must exist
3. **Environment**: `DATABASE_URL` environment variable configured
4. **Generated Client**: Run `npx prisma generate` for some tests

## Future Enhancements

When adding database models to your schema:

1. **Model Tests**: Add tests for specific model operations (CRUD)
2. **Relationship Tests**: Test model relationships and constraints
3. **Migration Tests**: Test schema migrations and data integrity
4. **Seed Tests**: Test database seeding functionality
5. **Performance Tests**: Add query performance benchmarks

## Troubleshooting

- **Import Errors**: Ensure `npx prisma generate` has been run
- **Type Errors**: Check that Prisma client types are available
- **Mock Issues**: Verify Jest mocks are properly configured in setup files