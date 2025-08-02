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
    // Code quality rules (allow console in development)
    'no-console': 'off', // Disabled for development, should be 'warn' in production
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
    'no-nested-ternary': 'off', // Disabled for now, should be refactored for better readability
    'prefer-template': 'error',
    'object-shorthand': 'error',
    'no-duplicate-imports': 'error',
    
    // Stimulus controller conventions (overridden in TypeScript files)
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
        '@typescript-eslint/no-explicit-any': 'off', // Disabled for now, should be gradually replaced
        '@typescript-eslint/no-empty-function': 'warn',
        
        // React rules
        'react/react-in-jsx-scope': 'off', // React 17+ automatic JSX transform
        'react/prop-types': 'off', // Using TypeScript for type checking
        'react/display-name': 'off',
        'react/jsx-no-target-blank': ['error', { 'enforceDynamicLinks': 'always' }],
        'react/jsx-key': 'error',
        'react/no-array-index-key': 'warn',
        'react/no-unescaped-entities': 'error',
        'react/self-closing-comp': 'error',
        'react/jsx-fragments': ['error', 'syntax'],
        
        // React Hooks rules
        'react-hooks/rules-of-hooks': 'error',
        'react-hooks/exhaustive-deps': 'warn',
        
        // Rails/Stimulus integration patterns
        'camelcase': ['error', { 
          properties: 'never',
          allow: [
            '^connect$', '^disconnect$', '^initialize$', 
            '^.*Target$', '^.*Targets$', 
            '^.*Value$', '^.*Values$', 
            '^.*Class$', '^.*Classes$',
            '^.*Outlet$', '^.*Outlets$'  // Stimulus 3.0 outlets
          ]
        }],
      },
    },
  ],
};