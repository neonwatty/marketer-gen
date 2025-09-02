import { NextRequest, NextResponse } from 'next/server'
import { getServerSession } from 'next-auth/next'

import { authOptions } from '@/lib/auth'

export async function GET(request: NextRequest) {
  try {
    const session = await getServerSession(authOptions)
    
    return NextResponse.json({
      session,
      hasSession: !!session,
      userId: session?.user?.id,
      email: session?.user?.email,
      name: session?.user?.name
    })
  } catch (error) {
    return NextResponse.json({
      error: 'Failed to get session',
      details: error instanceof Error ? error.message : String(error)
    }, { status: 500 })
  }
}