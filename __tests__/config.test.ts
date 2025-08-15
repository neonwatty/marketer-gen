describe('Project Configuration', () => {
  it('should have valid package.json', () => {
    const packageJson = require('../package.json')
    expect(packageJson.name).toBe('marketer-gen-nextjs')
    expect(packageJson.scripts.dev).toContain('next dev')
    expect(packageJson.scripts.build).toBe('next build')
    expect(packageJson.scripts.test).toBe('jest')
  })

  it('should have required dependencies', () => {
    const packageJson = require('../package.json')
    expect(packageJson.dependencies).toHaveProperty('next')
    expect(packageJson.dependencies).toHaveProperty('react')
    expect(packageJson.dependencies).toHaveProperty('react-dom')
    expect(packageJson.devDependencies).toHaveProperty('typescript')
  })

  it('should have testing dependencies', () => {
    const packageJson = require('../package.json')
    expect(packageJson.devDependencies).toHaveProperty('@testing-library/react')
    expect(packageJson.devDependencies).toHaveProperty('@testing-library/jest-dom')
    expect(packageJson.devDependencies).toHaveProperty('jest')
  })
})
