import { execSync } from 'child_process'
import fs from 'fs'
import path from 'path'

describe('Prisma Schema Validation', () => {
  const schemaPath = path.join(process.cwd(), 'prisma', 'schema.prisma')

  it('should have valid schema file', () => {
    expect(fs.existsSync(schemaPath)).toBe(true)
  })

  it('should contain required schema elements', () => {
    const schemaContent = fs.readFileSync(schemaPath, 'utf-8')
    
    expect(schemaContent).toContain('generator client')
    expect(schemaContent).toContain('datasource db')
    expect(schemaContent).toContain('provider = "sqlite"')
    expect(schemaContent).toContain('provider = "prisma-client-js"')
  })

  it('should have correct output path for generated client', () => {
    const schemaContent = fs.readFileSync(schemaPath, 'utf-8')
    expect(schemaContent).toContain('output   = "../src/generated/prisma"')
  })

  it('should have DATABASE_URL environment variable configured', () => {
    const schemaContent = fs.readFileSync(schemaPath, 'utf-8')
    expect(schemaContent).toContain('url      = env("DATABASE_URL")')
  })

  it('should validate schema syntax', () => {
    try {
      // Use stdio: 'pipe' to suppress output in tests
      execSync('npx prisma validate', { stdio: 'pipe' })
    } catch (error) {
      // If prisma validate fails, the schema is invalid
      fail(`Prisma schema validation failed: ${error}`)
    }
  })
})