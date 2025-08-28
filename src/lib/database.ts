import { PrismaClient, Prisma } from '@/generated/prisma'

declare global {
  var __prisma: PrismaClient | undefined
}

// Database configuration for optimization
const getDatabaseConfig = () => {
  const isProd = process.env.NODE_ENV === 'production'
  const isTest = process.env.NODE_ENV === 'test'
  
  return {
    log: isTest ? [] : isProd ? ['error' as Prisma.LogLevel] : ['query' as Prisma.LogLevel, 'info' as Prisma.LogLevel, 'warn' as Prisma.LogLevel, 'error' as Prisma.LogLevel],
    errorFormat: 'pretty' as const,
    datasources: {
      db: {
        url: process.env.DATABASE_URL,
      },
    },
  }
}

// Singleton pattern for Prisma Client to prevent multiple instances in development
export const prisma = globalThis.__prisma || new PrismaClient(getDatabaseConfig())

if (process.env.NODE_ENV === 'development') {
  globalThis.__prisma = prisma
}

// Connection health check
export const checkDatabaseHealth = async (): Promise<{
  status: 'healthy' | 'unhealthy'
  latency: number
  error?: string
}> => {
  const startTime = Date.now()
  try {
    await prisma.$queryRaw`SELECT 1`
    const latency = Date.now() - startTime
    return { status: 'healthy', latency }
  } catch (error) {
    const latency = Date.now() - startTime
    return { 
      status: 'unhealthy', 
      latency,
      error: error instanceof Error ? error.message : 'Unknown error' 
    }
  }
}

// Enhanced connection management
export const connectToDatabase = async (): Promise<void> => {
  try {
    await prisma.$connect()
    console.log('✅ Database connected successfully')
  } catch (error) {
    console.error('❌ Failed to connect to database:', error)
    throw new Error(`Failed to connect to database: ${error instanceof Error ? error.message : 'Unknown error'}`)
  }
}

export const disconnectFromDatabase = async (): Promise<void> => {
  try {
    await prisma.$disconnect()
    console.log('✅ Database disconnected successfully')
  } catch (error) {
    console.error('❌ Failed to disconnect from database:', error)
    throw new Error(`Failed to disconnect from database: ${error instanceof Error ? error.message : 'Unknown error'}`)
  }
}

// Query performance monitoring
export const withQueryMetrics = async <T>(
  operation: string,
  queryFn: () => Promise<T>
): Promise<T> => {
  const startTime = Date.now()
  try {
    const result = await queryFn()
    const duration = Date.now() - startTime
    
    if (duration > 1000) { // Log slow queries (>1s)
      console.warn(`⚠️ Slow query detected: ${operation} took ${duration}ms`)
    } else if (process.env.NODE_ENV === 'development') {
      console.log(`📊 Query ${operation} completed in ${duration}ms`)
    }
    
    return result
  } catch (error) {
    const duration = Date.now() - startTime
    console.error(`❌ Query ${operation} failed after ${duration}ms:`, error)
    throw error
  }
}

// Database transaction wrapper with retry logic
export const withTransaction = async <T>(
  fn: (tx: Omit<PrismaClient, '$connect' | '$disconnect' | '$on' | '$transaction' | '$use' | '$extends'>) => Promise<T>,
  maxRetries = 3
): Promise<T> => {
  let lastError: unknown
  
  for (let attempt = 1; attempt <= maxRetries; attempt++) {
    try {
      return await prisma.$transaction(fn, {
        maxWait: 5000, // 5 seconds
        timeout: 30000, // 30 seconds
      })
    } catch (error) {
      lastError = error
      
      // Don't retry on validation errors or business logic errors
      if (error && typeof error === 'object' && 'code' in error) {
        const prismaError = error as { code: string }
        if (prismaError.code === 'P2002' || prismaError.code === 'P2025') {
          throw error
        }
      }
      
      if (attempt === maxRetries) {
        console.error(`❌ Transaction failed after ${maxRetries} attempts:`, error)
        break
      }
      
      // Wait before retry with exponential backoff
      const delay = Math.min(1000 * Math.pow(2, attempt - 1), 5000)
      console.warn(`⚠️ Transaction attempt ${attempt} failed, retrying in ${delay}ms...`)
      await new Promise(resolve => setTimeout(resolve, delay))
    }
  }
  
  throw lastError
}

// Cleanup function for graceful shutdown
export const gracefulShutdown = async (): Promise<void> => {
  console.log('🔄 Initiating graceful database shutdown...')
  try {
    await disconnectFromDatabase()
    console.log('✅ Graceful shutdown completed')
  } catch (error) {
    console.error('❌ Error during graceful shutdown:', error)
    throw error
  }
}

// Initialize database connection on module load
const initializeDatabase = async () => {
  if (process.env.NODE_ENV !== 'test') {
    try {
      await connectToDatabase()
      const health = await checkDatabaseHealth()
      console.log(`📊 Database health: ${health.status} (${health.latency}ms latency)`)
    } catch (error) {
      console.error('❌ Failed to initialize database:', error)
    }
  }
}

// Initialize on import
initializeDatabase()

// Handle process termination
if (typeof process !== 'undefined') {
  process.on('beforeExit', gracefulShutdown)
  process.on('SIGINT', gracefulShutdown)
  process.on('SIGTERM', gracefulShutdown)
}