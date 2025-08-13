import { NextRequest, NextResponse } from 'next/server'
import { PrismaClient } from '@prisma/client'
import { getNotificationService } from '@/lib/notifications/notification-service'

const prisma = new PrismaClient()

export async function POST(request: NextRequest) {
  try {
    const { olderThanDays = 90 } = await request.json()

    const notificationService = getNotificationService(prisma)
    const deletedCount = await notificationService.cleanupOldNotifications(olderThanDays)

    return NextResponse.json({ 
      success: true,
      deletedCount,
      message: `Cleaned up ${deletedCount} old notifications`
    })
  } catch (error) {
    console.error('Error cleaning up notifications:', error)
    return NextResponse.json(
      { error: 'Failed to cleanup notifications' },
      { status: 500 }
    )
  }
}