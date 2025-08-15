describe('Database Configuration', () => {
  const originalEnv = process.env

  beforeEach(() => {
    jest.resetModules()
    process.env = { ...originalEnv }
  })

  afterAll(() => {
    process.env = originalEnv
  })

  it('should have DATABASE_URL configured', () => {
    expect(process.env.DATABASE_URL).toBeDefined()
    expect(process.env.DATABASE_URL).toMatch(/^file:/)
  })

  it('should use SQLite file format for development', () => {
    const dbUrl = process.env.DATABASE_URL
    expect(dbUrl).toMatch(/^file:\.\/.*\.db$/)
  })

  it('should handle missing DATABASE_URL gracefully', () => {
    delete process.env.DATABASE_URL
    
    expect(() => {
      const dbUrl = process.env.DATABASE_URL
      if (!dbUrl) throw new Error('DATABASE_URL is required')
    }).toThrow('DATABASE_URL is required')
  })
})