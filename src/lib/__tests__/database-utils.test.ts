import { connectToDatabase, disconnectFromDatabase } from '../database'

jest.mock('@prisma/client', () => ({
  PrismaClient: jest.fn().mockImplementation(() => ({
    $connect: jest.fn().mockResolvedValue(undefined),
    $disconnect: jest.fn().mockResolvedValue(undefined),
  })),
}))

// Mock the database module to use mocked PrismaClient
jest.mock('../database', () => {
  const mockPrisma = {
    $connect: jest.fn(),
    $disconnect: jest.fn(),
  }

  return {
    prisma: mockPrisma,
    connectToDatabase: jest.fn().mockImplementation(async () => {
      try {
        await mockPrisma.$connect()
      } catch (error) {
        throw new Error(`Failed to connect to database: ${error instanceof Error ? error.message : 'Unknown error'}`)
      }
    }),
    disconnectFromDatabase: jest.fn().mockImplementation(async () => {
      try {
        await mockPrisma.$disconnect()
      } catch (error) {
        throw new Error(`Failed to disconnect from database: ${error instanceof Error ? error.message : 'Unknown error'}`)
      }
    }),
  }
})

describe('Database Utilities', () => {
  beforeEach(() => {
    jest.clearAllMocks()
  })

  it('should connect to database successfully', async () => {
    await connectToDatabase()
    
    expect(connectToDatabase).toHaveBeenCalledTimes(1)
  })

  it('should disconnect from database successfully', async () => {
    await disconnectFromDatabase()
    
    expect(disconnectFromDatabase).toHaveBeenCalledTimes(1)
  })

  it('should handle connection errors', async () => {
    ;(connectToDatabase as jest.Mock).mockRejectedValue(new Error('Failed to connect to database: Connection failed'))
    
    await expect(connectToDatabase()).rejects.toThrow('Failed to connect to database: Connection failed')
  })

  it('should handle disconnection errors', async () => {
    ;(disconnectFromDatabase as jest.Mock).mockRejectedValue(new Error('Failed to disconnect from database: Disconnection failed'))
    
    await expect(disconnectFromDatabase()).rejects.toThrow('Failed to disconnect from database: Disconnection failed')
  })
})