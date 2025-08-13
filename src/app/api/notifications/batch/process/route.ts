import { NextRequest, NextResponse } from 'next/server'
import { PrismaClient } from '@prisma/client'
import { getNotificationService } from '@/lib/notifications/notification-service'

const prisma = new PrismaClient()

export async function POST(request: NextRequest) {
  try {
    const notificationService = getNotificationService(prisma)
    await notificationService.processPendingBatches()

    return NextResponse.json({ 
      success: true,
      message: 'Pending batches processed successfully' 
    })
  } catch (error) {
    console.error('Error processing notification batches:', error)
    return NextResponse.json(
      { error: 'Failed to process notification batches' },
      { status: 500 }
    )
  }
}