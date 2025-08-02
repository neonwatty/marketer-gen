module.exports = {
  root: true,
  env: {
    browser: true,
    es2021: true,
    node: true,
  },
  globals: {
    NodeJS: 'readonly',
  },
  extends: [
    'eslint:recommended',
  ],
  parserOptions: {
    ecmaFeatures: {
      jsx: true,
    },
    ecmaVersion: 'latest',
    sourceType: 'module',
  },
  rules: {
    // Code quality rules
    'no-console': 'warn',
    'no-debugger': 'error',
    'no-unused-vars': ['error', { argsIgnorePattern: '^_' }],
    
    // Best practices
    'prefer-const': 'error',
    'no-var': 'error',
    'eqeqeq': ['error', 'always'],
    'curly': ['error', 'all'],
    'consistent-return': 'error',
    'no-eval': 'error',
    'no-implied-eval': 'error',
    'no-new-func': 'error',
    'no-new-wrappers': 'error',
    'no-throw-literal': 'error',
    'prefer-promise-reject-errors': 'error',
    
    // Performance and accessibility
    'no-nested-ternary': 'warn',
    'prefer-template': 'error',
    'object-shorthand': 'error',
    'no-duplicate-imports': 'error',
    
    // Stimulus controller conventions
    'camelcase': ['error', { 
      properties: 'never',
      allow: ['^connect$', '^disconnect$', '^initialize$', '^.*Target$', '^.*Targets$', '^.*Value$', '^.*Values$', '^.*Class$', '^.*Classes$']
    }],
  },
  ignorePatterns: [
    'node_modules/',
    'app/assets/builds/',
    'public/assets/',
    'vendor/',
    'tmp/',
    'coverage/',
    '*.min.js',
  ],
  overrides: [
    {
      files: ['*_controller.js'],
      rules: {
        // Stimulus controller specific rules
        'class-methods-use-this': 'off',
      },
    },
    {
      files: ['*.ts', '*.tsx'],
      parser: '@typescript-eslint/parser',
      plugins: ['@typescript-eslint', 'react', 'react-hooks'],
      settings: {
        react: {
          version: 'detect',
        },
      },
      rules: {
        // Basic TypeScript rules
        'no-unused-vars': 'off',
        '@typescript-eslint/no-unused-vars': ['error', { argsIgnorePattern: '^_' }],
        '@typescript-eslint/no-explicit-any': 'warn',
        '@typescript-eslint/no-empty-function': 'warn',
        
        // React rules
        'react/react-in-jsx-scope': 'off',
        'react/prop-types': 'off',
        'react/display-name': 'off',
        'react-hooks/rules-of-hooks': 'error',
        'react-hooks/exhaustive-deps': 'warn',
      },
    },
  ],
};