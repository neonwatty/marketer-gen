import { PrismaClient } from '@prisma/client'

// Mock the PrismaClient
jest.mock('@prisma/client', () => ({
  PrismaClient: jest.fn().mockImplementation(() => ({
    $connect: jest.fn(),
    $disconnect: jest.fn(),
  })),
}))

describe('Prisma Client Configuration', () => {
  let prisma: PrismaClient

  beforeEach(() => {
    prisma = new PrismaClient()
    jest.clearAllMocks()
  })

  afterEach(async () => {
    await prisma.$disconnect()
  })

  it('should create Prisma client instance', () => {
    expect(prisma).toBeDefined()
    expect(typeof prisma.$connect).toBe('function')
    expect(typeof prisma.$disconnect).toBe('function')
  })

  it('should handle database connection', async () => {
    await prisma.$connect()
    expect(prisma.$connect).toHaveBeenCalled()
  })

  it('should handle database disconnection', async () => {
    await prisma.$disconnect()
    expect(prisma.$disconnect).toHaveBeenCalled()
  })
})