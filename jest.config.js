const nextJest = require('next/jest')

const createJestConfig = nextJest({
  // Provide the path to your Next.js app to load next.config.js and .env files
  dir: './',
})

// Add any custom config to be passed to Jest
const customJestConfig = {
  setupFilesAfterEnv: ['<rootDir>/jest.setup.js', '<rootDir>/jest.setup.prisma.js'],
  testEnvironment: 'jsdom',
  moduleDirectories: ['node_modules', '<rootDir>/'],
  testPathIgnorePatterns: ['<rootDir>/.next/', '<rootDir>/node_modules/', '<rootDir>/tests/', '<rootDir>/e2e/'],
  // Transform ES modules from Prisma and auth adapters
  transformIgnorePatterns: [
    'node_modules/(?!(.*\\.mjs$|@prisma/client|@auth/prisma-adapter|@auth/.*|oauth4webapi|next-auth|jose|openid-client))',
  ],
  extensionsToTreatAsEsm: ['.ts'],
  // Handle Prisma client imports
  moduleNameMapper: {
    '^@/(.*)$': '<rootDir>/src/$1',
  },
}

// createJestConfig is exported this way to ensure that next/jest can load the Next.js config which is async
module.exports = createJestConfig(customJestConfig)
