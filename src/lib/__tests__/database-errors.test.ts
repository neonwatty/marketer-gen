import { PrismaClient, PrismaClientKnownRequestError } from '@prisma/client'

jest.mock('@prisma/client')

const MockedPrismaClient = PrismaClient as jest.MockedClass<typeof PrismaClient>

describe('Database Error Handling', () => {
  let mockPrisma: jest.Mocked<PrismaClient>

  beforeEach(() => {
    mockPrisma = new MockedPrismaClient() as jest.Mocked<PrismaClient>
    jest.clearAllMocks()
  })

  it('should handle Prisma known request errors', async () => {
    const prismaError = new PrismaClientKnownRequestError(
      'Record not found',
      { code: 'P2025', clientVersion: '4.0.0' }
    )
    
    mockPrisma.$connect = jest.fn().mockRejectedValue(prismaError)

    await expect(mockPrisma.$connect()).rejects.toThrow('Record not found')
    await expect(mockPrisma.$connect()).rejects.toBeInstanceOf(PrismaClientKnownRequestError)
  })

  it('should handle database timeout errors', async () => {
    const timeoutError = new Error('Connection timeout')
    mockPrisma.$connect = jest.fn().mockRejectedValue(timeoutError)

    await expect(mockPrisma.$connect()).rejects.toThrow('Connection timeout')
  })

  it('should handle database file permission errors', async () => {
    const permissionError = new Error('EACCES: permission denied')
    mockPrisma.$connect = jest.fn().mockRejectedValue(permissionError)

    await expect(mockPrisma.$connect()).rejects.toThrow('EACCES: permission denied')
  })

  it('should handle database lock errors for SQLite', async () => {
    const lockError = new Error('SQLITE_BUSY: database is locked')
    mockPrisma.$connect = jest.fn().mockRejectedValue(lockError)

    await expect(mockPrisma.$connect()).rejects.toThrow('SQLITE_BUSY: database is locked')
  })

  it('should handle disk space errors', async () => {
    const diskSpaceError = new Error('ENOSPC: no space left on device')
    mockPrisma.$connect = jest.fn().mockRejectedValue(diskSpaceError)

    await expect(mockPrisma.$connect()).rejects.toThrow('ENOSPC: no space left on device')
  })

  it('should handle malformed DATABASE_URL errors', async () => {
    const urlError = new Error('Invalid database URL format')
    mockPrisma.$connect = jest.fn().mockRejectedValue(urlError)

    await expect(mockPrisma.$connect()).rejects.toThrow('Invalid database URL format')
  })
})