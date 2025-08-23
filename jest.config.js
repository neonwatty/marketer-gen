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
  // Transform ES modules from Prisma and auth adapters - more comprehensive pattern
  transformIgnorePatterns: [
    'node_modules/(?!(jose|openid-client|@auth|oauth4webapi|next-auth|@prisma/client|@ai-sdk|ai|eventsource-parser|@panva|@scure|@noble)/).*/',
  ],
  extensionsToTreatAsEsm: ['.ts'],
  // Handle Prisma client imports and mock problematic modules
  moduleNameMapper: {
    '^@/(.*)$': '<rootDir>/src/$1',
    '^jose$': '<rootDir>/jest.mocks/jose.js',
    '^openid-client$': '<rootDir>/jest.mocks/openid-client.js',
    '^@panva/hkdf$': '<rootDir>/jest.mocks/@panva/hkdf.js',
    '^../generated/prisma$': '<rootDir>/jest.mocks/prisma-client.js',
  },
}

// createJestConfig is exported this way to ensure that next/jest can load the Next.js config which is async
module.exports = createJestConfig(customJestConfig)
