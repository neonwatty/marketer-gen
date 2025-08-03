/** @type {import('jest').Config} */
module.exports = {
  // Test environment
  testEnvironment: 'jsdom',
  
  // Supported file extensions
  moduleFileExtensions: ['ts', 'tsx', 'js', 'jsx', 'json'],
  
  // Transform files with this regex
  transform: {
    '^.+\\.(ts|tsx)$': ['ts-jest', {
      useESM: true,
    }],
    '^.+\\.(js|jsx)$': ['babel-jest'],
  },
  
  // Module name mapping for aliases and assets
  moduleNameMapper: {
    '^@/(.*)$': '<rootDir>/app/javascript/$1',
    '^@components/(.*)$': '<rootDir>/app/javascript/components/$1',
    '^@controllers/(.*)$': '<rootDir>/app/javascript/controllers/$1',
    '^@utils/(.*)$': '<rootDir>/app/javascript/utils/$1',
    '^@stores/(.*)$': '<rootDir>/app/javascript/stores/$1',
    '^@types/(.*)$': '<rootDir>/app/javascript/types/$1',
    '\\.(css|scss|sass)$': 'identity-obj-proxy',
    '\\.(jpg|jpeg|png|gif|eot|otf|webp|svg|ttf|woff|woff2|mp4|webm|wav|mp3|m4a|aac|oga)$': 'jest-transform-stub',
  },
  
  // Setup files
  setupFilesAfterEnv: [
    '<rootDir>/test/javascript/setup.ts'
  ],
  
  // Test patterns
  testMatch: [
    '<rootDir>/test/javascript/**/*.(test|spec).(ts|tsx|js|jsx)',
    '<rootDir>/app/javascript/**/__tests__/**/*.(ts|tsx|js|jsx)',
    '<rootDir>/app/javascript/**/*.(test|spec).(ts|tsx|js|jsx)'
  ],
  
  // Coverage configuration
  collectCoverage: true,
  collectCoverageFrom: [
    'app/javascript/**/*.{ts,tsx,js,jsx}',
    '!app/javascript/**/*.d.ts',
    '!app/javascript/**/*.stories.{ts,tsx,js,jsx}',
    '!app/javascript/**/__tests__/**',
    '!app/javascript/**/*.test.{ts,tsx,js,jsx}',
    '!app/javascript/**/*.spec.{ts,tsx,js,jsx}',
  ],
  
  // Coverage thresholds (80% minimum as specified)
  coverageThreshold: {
    global: {
      branches: 80,
      functions: 80,
      lines: 80,
      statements: 80
    }
  },
  
  // Coverage reporters
  coverageReporters: ['text', 'lcov', 'html', 'json'],
  
  // Test timeout
  testTimeout: 10000,
  
  // Clear mocks between tests
  clearMocks: true,
  
  // Restore mocks after each test
  restoreMocks: true,
  
  // Module directories
  moduleDirectories: ['node_modules', '<rootDir>/app/javascript'],
  
  // Ignore patterns
  testPathIgnorePatterns: [
    '<rootDir>/node_modules/',
    '<rootDir>/app/assets/',
    '<rootDir>/public/',
  ],
  
  // Global setup for tests
  globalSetup: '<rootDir>/test/javascript/globalSetup.ts',
  globalTeardown: '<rootDir>/test/javascript/globalTeardown.ts',
};