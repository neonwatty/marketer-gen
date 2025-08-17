import { PrismaClient } from '@/generated/prisma'

declare global {
  var __prisma: PrismaClient | undefined
}

// Singleton pattern for Prisma Client to prevent multiple instances in development
export const prisma = globalThis.__prisma || new PrismaClient()

if (process.env.NODE_ENV === 'development') {
  globalThis.__prisma = prisma
}

export const connectToDatabase = async (): Promise<void> => {
  try {
    await prisma.$connect()
  } catch (error) {
    throw new Error(`Failed to connect to database: ${error instanceof Error ? error.message : 'Unknown error'}`)
  }
}

export const disconnectFromDatabase = async (): Promise<void> => {
  try {
    await prisma.$disconnect()
  } catch (error) {
    throw new Error(`Failed to disconnect from database: ${error instanceof Error ? error.message : 'Unknown error'}`)
  }
}