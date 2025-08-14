import fs from 'fs'
import path from 'path'

describe('Build Process', () => {
  it('should have TypeScript configuration', () => {
    const tsconfigPath = path.join(process.cwd(), 'tsconfig.json')
    expect(fs.existsSync(tsconfigPath)).toBe(true)
    
    const tsconfig = JSON.parse(fs.readFileSync(tsconfigPath, 'utf8'))
    expect(tsconfig.compilerOptions).toBeDefined()
    expect(tsconfig.include).toContain('**/*.ts')
  })

  it('should have Next.js configuration', () => {
    const nextConfigPath = path.join(process.cwd(), 'next.config.ts')
    expect(fs.existsSync(nextConfigPath)).toBe(true)
  })

  it('should have build script in package.json', () => {
    const packageJson = require('../package.json')
    expect(packageJson.scripts.build).toBe('next build')
  })
})