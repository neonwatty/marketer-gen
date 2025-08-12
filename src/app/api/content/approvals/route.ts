import { NextRequest, NextResponse } from 'next/server';
import { approvalActions } from '@/lib/approval-actions';

// Get all content pending approval
export async function GET(request: NextRequest) {
  try {
    const searchParams = request.nextUrl.searchParams;
    const userRole = searchParams.get('userRole') || undefined;
    const status = searchParams.get('status');

    let pendingContent = await approvalActions.getContentPendingApproval(userRole);

    // Filter by specific status if requested
    if (status) {
      pendingContent = pendingContent.filter(content => content.status === status);
    }

    return NextResponse.json({
      content: pendingContent,
      total: pendingContent.length,
      byStatus: pendingContent.reduce((acc, item) => {
        acc[item.status] = (acc[item.status] || 0) + 1;
        return acc;
      }, {} as Record<string, number>)
    });

  } catch (error) {
    console.error('Error getting pending approvals:', error);
    return NextResponse.json(
      { error: 'Internal server error' },
      { status: 500 }
    );
  }
}

// Bulk approval operations
export async function POST(request: NextRequest) {
  try {
    const body = await request.json();
    const { action, contentIds, comment, userId, userRole, userName } = body;

    if (!action || !contentIds || !Array.isArray(contentIds)) {
      return NextResponse.json(
        { error: 'Action and contentIds array are required' },
        { status: 400 }
      );
    }

    if (action === 'bulk_approve') {
      const results = await approvalActions.bulkApprove(contentIds, {
        contentId: '',
        userId,
        userRole,
        comment,
        metadata: {
          userName,
          bulkAction: true,
          timestamp: new Date(),
          userAgent: request.headers.get('user-agent') || undefined
        }
      });

      return NextResponse.json({
        success: true,
        results: {
          approved: results.success,
          failed: results.failed.length,
          errors: results.failed
        }
      });
    }

    return NextResponse.json(
      { error: 'Invalid bulk action' },
      { status: 400 }
    );

  } catch (error) {
    console.error('Error in bulk approval:', error);
    return NextResponse.json(
      { error: 'Internal server error' },
      { status: 500 }
    );
  }
}