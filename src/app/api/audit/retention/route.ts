import { NextRequest, NextResponse } from 'next/server'
import { PrismaClient } from '@prisma/client'
import AuditRetentionManager from '@/lib/audit/retention-manager'

const prisma = new PrismaClient()
const retentionManager = new AuditRetentionManager(prisma)

export async function GET(request: NextRequest) {
  try {
    const { searchParams } = new URL(request.url)
    const action = searchParams.get('action')
    const policyId = searchParams.get('policyId')

    switch (action) {
      case 'analyze':
        // Analyze what would happen if retention policies were executed
        const stats = await retentionManager.analyzeRetention(policyId || undefined)
        return NextResponse.json({ success: true, data: stats })

      case 'policies':
        // Get all retention policies
        const activeOnly = searchParams.get('activeOnly') === 'true'
        const policies = await retentionManager.getPolicies(activeOnly)
        return NextResponse.json({ success: true, data: policies })

      default:
        return NextResponse.json(
          { success: false, error: 'Invalid action parameter' },
          { status: 400 }
        )
    }
  } catch (error) {
    console.error('Error in retention GET:', error)
    return NextResponse.json(
      { success: false, error: 'Failed to process retention request' },
      { status: 500 }
    )
  }
}

export async function POST(request: NextRequest) {
  try {
    const body = await request.json()
    const { action, ...data } = body

    switch (action) {
      case 'create':
        // Create a new retention policy
        const policyId = await retentionManager.createPolicy(data)
        return NextResponse.json({ 
          success: true, 
          data: { id: policyId } 
        })

      case 'execute':
        // Execute retention policies
        const { policyId, dryRun = true, batchSize = 1000 } = data
        const results = await retentionManager.executeRetention(
          policyId || undefined,
          dryRun,
          batchSize
        )
        return NextResponse.json({ 
          success: true, 
          data: results 
        })

      case 'createDefaults':
        // Create default retention policies
        const defaultPolicyIds = await retentionManager.createDefaultPolicies()
        return NextResponse.json({ 
          success: true, 
          data: { policyIds: defaultPolicyIds } 
        })

      default:
        return NextResponse.json(
          { success: false, error: 'Invalid action parameter' },
          { status: 400 }
        )
    }
  } catch (error) {
    console.error('Error in retention POST:', error)
    return NextResponse.json(
      { success: false, error: 'Failed to process retention request' },
      { status: 500 }
    )
  }
}

export async function PUT(request: NextRequest) {
  try {
    const body = await request.json()
    const { id, ...updates } = body

    if (!id) {
      return NextResponse.json(
        { success: false, error: 'Policy ID is required' },
        { status: 400 }
      )
    }

    await retentionManager.updatePolicy(id, updates)
    return NextResponse.json({ 
      success: true, 
      message: 'Policy updated successfully' 
    })
  } catch (error) {
    console.error('Error updating retention policy:', error)
    return NextResponse.json(
      { success: false, error: 'Failed to update retention policy' },
      { status: 500 }
    )
  }
}

export async function DELETE(request: NextRequest) {
  try {
    const { searchParams } = new URL(request.url)
    const id = searchParams.get('id')

    if (!id) {
      return NextResponse.json(
        { success: false, error: 'Policy ID is required' },
        { status: 400 }
      )
    }

    await retentionManager.deletePolicy(id)
    return NextResponse.json({ 
      success: true, 
      message: 'Policy deleted successfully' 
    })
  } catch (error) {
    console.error('Error deleting retention policy:', error)
    return NextResponse.json(
      { success: false, error: 'Failed to delete retention policy' },
      { status: 500 }
    )
  }
}