describe('ESLint Configuration', () => {
  it('should have Next.js ESLint config', () => {
    const packageJson = require('../package.json')
    expect(packageJson.devDependencies).toHaveProperty('eslint-config-next')
    expect(packageJson.dependencies).toHaveProperty('eslint')
  })

  it('should have lint script in package.json', () => {
    const packageJson = require('../package.json')
    expect(packageJson.scripts.lint).toBe('next lint')
  })

  it('should have ESLint configuration file', () => {
    const fs = require('fs')
    const path = require('path')
    
    // Check for eslint config file
    const eslintConfigPath = path.join(process.cwd(), 'eslint.config.mjs')
    expect(fs.existsSync(eslintConfigPath)).toBe(true)
  })
})