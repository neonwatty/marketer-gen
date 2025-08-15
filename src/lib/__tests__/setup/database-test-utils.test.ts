import {
  createMockPrismaClient,
  getTestDatabaseUrl,
  isTestEnvironment,
  mockDatabaseResponses,
} from '../../test-utils/database-test-utils'

describe('Database Test Utils', () => {
  it('should create mock Prisma client', () => {
    const mockPrisma = createMockPrismaClient()
    
    expect(mockPrisma.$connect).toBeDefined()
    expect(mockPrisma.$disconnect).toBeDefined()
    expect(mockPrisma.$queryRaw).toBeDefined()
    expect(mockPrisma.$executeRaw).toBeDefined()
    expect(mockPrisma.$transaction).toBeDefined()
  })

  it('should provide mock database responses', () => {
    expect(mockDatabaseResponses.user).toHaveProperty('id')
    expect(mockDatabaseResponses.user).toHaveProperty('email')
    expect(mockDatabaseResponses.users).toHaveLength(2)
  })

  it('should return test database URL', () => {
    const url = getTestDatabaseUrl()
    expect(url).toMatch(/^file:.*\.db$/)
  })

  it('should detect test environment', () => {
    const originalEnv = process.env.NODE_ENV
    process.env.NODE_ENV = 'test'
    
    expect(isTestEnvironment()).toBe(true)
    
    process.env.NODE_ENV = 'development'
    expect(isTestEnvironment()).toBe(false)
    
    process.env.NODE_ENV = originalEnv
  })
})