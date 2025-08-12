import { NextRequest, NextResponse } from 'next/server';
import { approvalActions } from '@/lib/approval-actions';
import { ApprovalAction } from '@/lib/approval-workflow';

export async function POST(
  request: NextRequest,
  { params }: { params: { id: string } }
) {
  try {
    const body = await request.json();
    const { action, comment, userId, userRole, userName } = body;

    if (!action) {
      return NextResponse.json(
        { error: 'Action is required' },
        { status: 400 }
      );
    }

    const result = await approvalActions.executeWorkflowAction(
      params.id,
      action as ApprovalAction,
      {
        contentId: params.id,
        userId,
        userRole,
        comment,
        metadata: {
          userName,
          timestamp: new Date(),
          userAgent: request.headers.get('user-agent') || undefined
        }
      }
    );

    if (!result.success) {
      return NextResponse.json(
        { 
          error: result.error,
          requiresPermission: result.requiresPermission 
        },
        { status: result.requiresPermission ? 403 : 400 }
      );
    }

    // Get updated content data
    const updatedContent = await approvalActions.getContentApprovalData(params.id, userRole);

    return NextResponse.json({
      success: true,
      newState: result.newState,
      newApprovalStatus: result.newApprovalStatus,
      content: updatedContent
    });

  } catch (error) {
    console.error('Error in approval workflow:', error);
    return NextResponse.json(
      { error: 'Internal server error' },
      { status: 500 }
    );
  }
}

export async function GET(
  request: NextRequest,
  { params }: { params: { id: string } }
) {
  try {
    const searchParams = request.nextUrl.searchParams;
    const userRole = searchParams.get('userRole') || undefined;

    const approvalData = await approvalActions.getContentApprovalData(params.id, userRole);

    if (!approvalData) {
      return NextResponse.json(
        { error: 'Content not found' },
        { status: 404 }
      );
    }

    return NextResponse.json(approvalData);

  } catch (error) {
    console.error('Error getting approval data:', error);
    return NextResponse.json(
      { error: 'Internal server error' },
      { status: 500 }
    );
  }
}