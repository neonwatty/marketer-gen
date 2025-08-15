import { PrismaClient } from '@prisma/client'

export async function GET() {
  const prisma = new PrismaClient()
  
  try {
    await prisma.$connect()
    return Response.json({ status: 'connected' })
  } catch {
    return Response.json(
      { error: 'Connection failed' }, 
      { status: 500 }
    )
  } finally {
    try {
      await prisma.$disconnect()
    } catch (disconnectError) {
      // Log disconnect errors but don't let them affect the response
      console.error('Error disconnecting from database:', disconnectError)
    }
  }
}