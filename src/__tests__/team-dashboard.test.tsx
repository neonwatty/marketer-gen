import React from 'react'
import { render, screen, fireEvent, waitFor } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import '@testing-library/jest-dom'

// Mock child components
jest.mock('@/components/team/pending-approvals-widget', () => ({
  PendingApprovalsWidget: ({ onApprovalAction }: any) => (
    <div data-testid="pending-approvals-widget">
      <button onClick={() => onApprovalAction('approve', 'item-1')}>Approve Item 1</button>
    </div>
  )
}))

jest.mock('@/components/team/assigned-tasks-overview', () => ({
  AssignedTasksOverview: ({ teamMember, onTaskAction }: any) => (
    <div data-testid="assigned-tasks-overview">
      {teamMember ? `Tasks for ${teamMember.name}` : 'All Tasks'}
      <button onClick={() => onTaskAction('complete', 'task-1')}>Complete Task</button>
    </div>
  )
}))

jest.mock('@/components/team/team-activity-feed', () => ({
  TeamActivityFeed: ({ activities }: any) => (
    <div data-testid="team-activity-feed">
      {activities?.map((activity: any) => (
        <div key={activity.id}>{activity.message}</div>
      ))}
    </div>
  )
}))

jest.mock('@/components/team/workload-visualization', () => ({
  WorkloadVisualization: ({ teamMembers, viewType }: any) => (
    <div data-testid="workload-visualization">
      View: {viewType}
      {teamMembers?.map((member: any) => (
        <div key={member.id}>{member.name}: {member.workload}%</div>
      ))}
    </div>
  )
}))

jest.mock('@/components/team/team-member-status', () => ({
  TeamMemberStatus: ({ members, onStatusChange }: any) => (
    <div data-testid="team-member-status">
      {members?.map((member: any) => (
        <div key={member.id}>
          {member.name} - {member.status}
          <button onClick={() => onStatusChange(member.id, 'busy')}>Set Busy</button>
        </div>
      ))}
    </div>
  )
}))

jest.mock('@/components/team/team-performance-metrics', () => ({
  TeamPerformanceMetrics: ({ metrics, timeRange }: any) => (
    <div data-testid="team-performance-metrics">
      Time Range: {timeRange}
      Efficiency: {metrics?.teamEfficiency}%
    </div>
  )
}))

jest.mock('@/components/team/task-assignment-interface', () => ({
  TaskAssignmentInterface: ({ onAssign, teamMembers }: any) => (
    <div data-testid="task-assignment-interface">
      <button onClick={() => onAssign('task-new', 'user-1')}>Assign Task</button>
      Members: {teamMembers?.length}
    </div>
  )
}))

import { TeamDashboard } from '@/components/team/team-dashboard'

// Mock data
const mockTeamMembers = [
  {
    id: '1',
    name: 'John Doe',
    avatar: 'https://example.com/avatar1.jpg',
    role: 'Marketing Manager',
    status: 'online' as const,
    workload: 85,
    tasksCompleted: 12,
    tasksInProgress: 5,
    tasksPending: 3
  },
  {
    id: '2',
    name: 'Sarah Wilson',
    avatar: 'https://example.com/avatar2.jpg',
    role: 'Content Creator',
    status: 'busy' as const,
    workload: 92,
    tasksCompleted: 8,
    tasksInProgress: 7,
    tasksPending: 2
  },
  {
    id: '3',
    name: 'Mike Johnson',
    role: 'Designer',
    status: 'online' as const,
    workload: 68,
    tasksCompleted: 15,
    tasksInProgress: 3,
    tasksPending: 1
  }
]

const mockTeamStats = {
  totalMembers: 3,
  activeMembers: 2,
  totalTasks: 56,
  completedTasks: 35,
  pendingApprovals: 8,
  overdueItems: 3,
  averageWorkload: 81.7,
  teamEfficiency: 78
}

const mockActivities = [
  {
    id: '1',
    type: 'task_completed',
    message: 'John Doe completed task "Create landing page"',
    timestamp: new Date('2024-01-15T10:30:00'),
    userId: '1'
  },
  {
    id: '2',
    type: 'approval_request',
    message: 'Sarah Wilson requested approval for campaign content',
    timestamp: new Date('2024-01-15T09:15:00'),
    userId: '2'
  }
]

describe('TeamDashboard Component', () => {
  const defaultProps = {
    teamMembers: mockTeamMembers,
    teamStats: mockTeamStats,
    activities: mockActivities,
    currentUserId: '1',
    userRole: 'manager' as const
  }

  describe('Rendering', () => {
    test('should render team dashboard with all main sections', () => {
      render(<TeamDashboard {...defaultProps} />)

      expect(screen.getByText('Team Dashboard')).toBeInTheDocument()
      expect(screen.getByRole('tablist')).toBeInTheDocument()
      
      // Check for main tabs
      expect(screen.getByRole('tab', { name: /overview/i })).toBeInTheDocument()
      expect(screen.getByRole('tab', { name: /tasks/i })).toBeInTheDocument()
      expect(screen.getByRole('tab', { name: /workload/i })).toBeInTheDocument()
      expect(screen.getByRole('tab', { name: /performance/i })).toBeInTheDocument()
    })

    test('should display team statistics correctly', () => {
      render(<TeamDashboard {...defaultProps} />)

      expect(screen.getByText('3')).toBeInTheDocument() // Total members
      expect(screen.getByText('2')).toBeInTheDocument() // Active members
      expect(screen.getByText('56')).toBeInTheDocument() // Total tasks
      expect(screen.getByText('35')).toBeInTheDocument() // Completed tasks
      expect(screen.getByText('8')).toBeInTheDocument() // Pending approvals
      expect(screen.getByText('3')).toBeInTheDocument() // Overdue items
    })

    test('should show team member cards with correct information', () => {
      render(<TeamDashboard {...defaultProps} />)

      expect(screen.getByText('John Doe')).toBeInTheDocument()
      expect(screen.getByText('Marketing Manager')).toBeInTheDocument()
      expect(screen.getByText('Sarah Wilson')).toBeInTheDocument()
      expect(screen.getByText('Content Creator')).toBeInTheDocument()
      expect(screen.getByText('Mike Johnson')).toBeInTheDocument()
      expect(screen.getByText('Designer')).toBeInTheDocument()
    })

    test('should display member workload with progress bars', () => {
      render(<TeamDashboard {...defaultProps} />)

      // Check for workload percentages
      expect(screen.getByText('85%')).toBeInTheDocument()
      expect(screen.getByText('92%')).toBeInTheDocument()
      expect(screen.getByText('68%')).toBeInTheDocument()

      // Check for progress bars
      const progressBars = screen.getAllByRole('progressbar')
      expect(progressBars.length).toBeGreaterThan(0)
    })

    test('should show online status indicators', () => {
      render(<TeamDashboard {...defaultProps} />)

      // Check for status badges
      const onlineStatuses = screen.getAllByText(/online|busy/i)
      expect(onlineStatuses.length).toBeGreaterThan(0)
    })
  })

  describe('Tab Navigation', () => {
    test('should switch between tabs correctly', async () => {
      const user = userEvent.setup()
      render(<TeamDashboard {...defaultProps} />)

      // Initially on overview tab
      expect(screen.getByTestId('pending-approvals-widget')).toBeInTheDocument()

      // Switch to tasks tab
      const tasksTab = screen.getByRole('tab', { name: /tasks/i })
      await user.click(tasksTab)

      expect(screen.getByTestId('assigned-tasks-overview')).toBeInTheDocument()

      // Switch to workload tab
      const workloadTab = screen.getByRole('tab', { name: /workload/i })
      await user.click(workloadTab)

      expect(screen.getByTestId('workload-visualization')).toBeInTheDocument()

      // Switch to performance tab
      const performanceTab = screen.getByRole('tab', { name: /performance/i })
      await user.click(performanceTab)

      expect(screen.getByTestId('team-performance-metrics')).toBeInTheDocument()
    })

    test('should maintain active tab state', async () => {
      const user = userEvent.setup()
      render(<TeamDashboard {...defaultProps} />)

      const tasksTab = screen.getByRole('tab', { name: /tasks/i })
      await user.click(tasksTab)

      expect(tasksTab).toHaveAttribute('data-state', 'active')
    })
  })

  describe('Dashboard Functionality', () => {
    test('should handle approval actions', async () => {
      const mockOnAction = jest.fn()
      const user = userEvent.setup()

      render(
        <TeamDashboard 
          {...defaultProps} 
          onApprovalAction={mockOnAction}
        />
      )

      const approveButton = screen.getByText('Approve Item 1')
      await user.click(approveButton)

      expect(mockOnAction).toHaveBeenCalledWith('approve', 'item-1')
    })

    test('should handle task actions', async () => {
      const mockOnTaskAction = jest.fn()
      const user = userEvent.setup()

      render(
        <TeamDashboard 
          {...defaultProps} 
          onTaskAction={mockOnTaskAction}
        />
      )

      // Switch to tasks tab
      const tasksTab = screen.getByRole('tab', { name: /tasks/i })
      await user.click(tasksTab)

      const completeButton = screen.getByText('Complete Task')
      await user.click(completeButton)

      expect(mockOnTaskAction).toHaveBeenCalledWith('complete', 'task-1')
    })

    test('should handle task assignment', async () => {
      const mockOnAssign = jest.fn()
      const user = userEvent.setup()

      render(
        <TeamDashboard 
          {...defaultProps} 
          onTaskAssign={mockOnAssign}
        />
      )

      // Switch to tasks tab
      const tasksTab = screen.getByRole('tab', { name: /tasks/i })
      await user.click(tasksTab)

      const assignButton = screen.getByText('Assign Task')
      await user.click(assignButton)

      expect(mockOnAssign).toHaveBeenCalledWith('task-new', 'user-1')
    })

    test('should handle member status changes', async () => {
      const mockOnStatusChange = jest.fn()
      const user = userEvent.setup()

      render(
        <TeamDashboard 
          {...defaultProps} 
          onMemberStatusChange={mockOnStatusChange}
        />
      )

      const setBusyButton = screen.getByText('Set Busy')
      await user.click(setBusyButton)

      expect(mockOnStatusChange).toHaveBeenCalledWith('1', 'busy')
    })
  })

  describe('Dashboard Controls', () => {
    test('should have refresh functionality', async () => {
      const mockOnRefresh = jest.fn()
      const user = userEvent.setup()

      render(
        <TeamDashboard 
          {...defaultProps} 
          onRefresh={mockOnRefresh}
        />
      )

      const refreshButton = screen.getByRole('button', { name: /refresh/i })
      await user.click(refreshButton)

      expect(mockOnRefresh).toHaveBeenCalled()
    })

    test('should support view type switching', async () => {
      const user = userEvent.setup()
      render(<TeamDashboard {...defaultProps} />)

      // Switch to workload tab
      const workloadTab = screen.getByRole('tab', { name: /workload/i })
      await user.click(workloadTab)

      // Should show view type controls (mocked in workload visualization)
      expect(screen.getByTestId('workload-visualization')).toBeInTheDocument()
    })

    test('should handle time range selection', async () => {
      const user = userEvent.setup()
      render(<TeamDashboard {...defaultProps} />)

      // Switch to performance tab
      const performanceTab = screen.getByRole('tab', { name: /performance/i })
      await user.click(performanceTab)

      // Should show performance metrics with time range
      expect(screen.getByTestId('team-performance-metrics')).toBeInTheDocument()
    })

    test('should show export options', () => {
      render(<TeamDashboard {...defaultProps} userRole="admin" />)

      const exportButton = screen.getByRole('button', { name: /export/i })
      expect(exportButton).toBeInTheDocument()
    })

    test('should show settings for authorized users', () => {
      render(<TeamDashboard {...defaultProps} userRole="admin" />)

      const settingsButton = screen.getByRole('button', { name: /settings/i })
      expect(settingsButton).toBeInTheDocument()
    })

    test('should not show admin controls for regular users', () => {
      render(<TeamDashboard {...defaultProps} userRole="member" />)

      expect(screen.queryByRole('button', { name: /settings/i })).not.toBeInTheDocument()
    })
  })

  describe('Data Handling', () => {
    test('should handle empty team members gracefully', () => {
      render(
        <TeamDashboard 
          {...defaultProps} 
          teamMembers={[]}
          teamStats={{ ...mockTeamStats, totalMembers: 0, activeMembers: 0 }}
        />
      )

      expect(screen.getByText('0')).toBeInTheDocument() // Total members
      expect(screen.getByText('Team Dashboard')).toBeInTheDocument()
    })

    test('should handle missing team stats', () => {
      const incompleteStats = {
        totalMembers: 3,
        activeMembers: 2,
        totalTasks: 0,
        completedTasks: 0,
        pendingApprovals: 0,
        overdueItems: 0,
        averageWorkload: 0,
        teamEfficiency: 0
      }

      render(
        <TeamDashboard 
          {...defaultProps} 
          teamStats={incompleteStats}
        />
      )

      expect(screen.getByText('Team Dashboard')).toBeInTheDocument()
    })

    test('should handle loading state', () => {
      render(
        <TeamDashboard 
          {...defaultProps} 
          isLoading={true}
        />
      )

      expect(screen.getByTestId('loading-spinner') || screen.getByText(/loading/i)).toBeInTheDocument()
    })

    test('should handle error state', () => {
      render(
        <TeamDashboard 
          {...defaultProps} 
          error="Failed to load team data"
        />
      )

      expect(screen.getByText(/failed to load/i)).toBeInTheDocument()
    })
  })

  describe('Responsive Behavior', () => {
    test('should adapt to mobile view', () => {
      // Mock mobile viewport
      Object.defineProperty(window, 'innerWidth', {
        writable: true,
        configurable: true,
        value: 375
      })

      render(<TeamDashboard {...defaultProps} />)

      // Should still render main components
      expect(screen.getByText('Team Dashboard')).toBeInTheDocument()
    })

    test('should show compact view for small screens', () => {
      render(<TeamDashboard {...defaultProps} compactView={true} />)

      expect(screen.getByText('Team Dashboard')).toBeInTheDocument()
      // Compact view should still show essential information
    })
  })

  describe('Real-time Updates', () => {
    test('should update when team member data changes', () => {
      const { rerender } = render(<TeamDashboard {...defaultProps} />)

      expect(screen.getByText('85%')).toBeInTheDocument() // John's workload

      const updatedMembers = [
        { ...mockTeamMembers[0], workload: 90 },
        ...mockTeamMembers.slice(1)
      ]

      rerender(
        <TeamDashboard 
          {...defaultProps} 
          teamMembers={updatedMembers}
        />
      )

      expect(screen.getByText('90%')).toBeInTheDocument()
    })

    test('should update when team stats change', () => {
      const { rerender } = render(<TeamDashboard {...defaultProps} />)

      expect(screen.getByText('8')).toBeInTheDocument() // Pending approvals

      const updatedStats = { ...mockTeamStats, pendingApprovals: 12 }

      rerender(
        <TeamDashboard 
          {...defaultProps} 
          teamStats={updatedStats}
        />
      )

      expect(screen.getByText('12')).toBeInTheDocument()
    })

    test('should handle new activities', () => {
      const { rerender } = render(<TeamDashboard {...defaultProps} />)

      const newActivity = {
        id: '3',
        type: 'task_assigned',
        message: 'New task assigned to Mike Johnson',
        timestamp: new Date(),
        userId: '3'
      }

      const updatedActivities = [...mockActivities, newActivity]

      rerender(
        <TeamDashboard 
          {...defaultProps} 
          activities={updatedActivities}
        />
      )

      expect(screen.getByText(newActivity.message)).toBeInTheDocument()
    })
  })

  describe('Performance', () => {
    test('should not re-render unnecessarily', () => {
      const { rerender } = render(<TeamDashboard {...defaultProps} />)

      // Re-render with same props
      rerender(<TeamDashboard {...defaultProps} />)

      // Should still work correctly
      expect(screen.getByText('Team Dashboard')).toBeInTheDocument()
    })

    test('should handle large team datasets efficiently', () => {
      const largeTeam = Array.from({ length: 100 }, (_, i) => ({
        id: `member-${i}`,
        name: `Member ${i}`,
        role: 'Team Member',
        status: 'online' as const,
        workload: Math.floor(Math.random() * 100),
        tasksCompleted: Math.floor(Math.random() * 20),
        tasksInProgress: Math.floor(Math.random() * 10),
        tasksPending: Math.floor(Math.random() * 5)
      }))

      const startTime = performance.now()
      render(
        <TeamDashboard 
          {...defaultProps} 
          teamMembers={largeTeam}
        />
      )
      const endTime = performance.now()

      expect(endTime - startTime).toBeLessThan(1000) // Should render quickly
      expect(screen.getByText('Team Dashboard')).toBeInTheDocument()
    })
  })

  describe('Accessibility', () => {
    test('should have proper ARIA labels', () => {
      render(<TeamDashboard {...defaultProps} />)

      const tablist = screen.getByRole('tablist')
      expect(tablist).toHaveAttribute('aria-label', 'Team dashboard sections')

      const tabs = screen.getAllByRole('tab')
      tabs.forEach(tab => {
        expect(tab).toHaveAttribute('aria-controls')
      })
    })

    test('should be keyboard navigable', async () => {
      const user = userEvent.setup()
      render(<TeamDashboard {...defaultProps} />)

      const firstTab = screen.getByRole('tab', { name: /overview/i })
      firstTab.focus()

      await user.keyboard('{ArrowRight}')
      
      const secondTab = screen.getByRole('tab', { name: /tasks/i })
      expect(secondTab).toHaveFocus()
    })

    test('should have proper heading hierarchy', () => {
      render(<TeamDashboard {...defaultProps} />)

      const mainHeading = screen.getByRole('heading', { level: 1 })
      expect(mainHeading).toHaveTextContent('Team Dashboard')

      const sectionHeadings = screen.getAllByRole('heading', { level: 2 })
      expect(sectionHeadings.length).toBeGreaterThan(0)
    })

    test('should provide screen reader announcements for status changes', async () => {
      const user = userEvent.setup()
      render(<TeamDashboard {...defaultProps} />)

      const setBusyButton = screen.getByText('Set Busy')
      await user.click(setBusyButton)

      // Should have aria-live region for status announcements
      const liveRegion = screen.getByRole('status')
      expect(liveRegion).toBeInTheDocument()
    })
  })

  describe('Integration with Child Components', () => {
    test('should pass correct props to child components', () => {
      render(<TeamDashboard {...defaultProps} />)

      // Check if child components receive correct data
      expect(screen.getByTestId('pending-approvals-widget')).toBeInTheDocument()
      expect(screen.getByTestId('team-member-status')).toBeInTheDocument()

      // Switch to tasks tab and check task components
      const tasksTab = screen.getByRole('tab', { name: /tasks/i })
      fireEvent.click(tasksTab)

      expect(screen.getByTestId('assigned-tasks-overview')).toBeInTheDocument()
      expect(screen.getByTestId('task-assignment-interface')).toBeInTheDocument()
    })

    test('should handle child component events correctly', async () => {
      const mockOnAction = jest.fn()
      const user = userEvent.setup()

      render(
        <TeamDashboard 
          {...defaultProps} 
          onApprovalAction={mockOnAction}
        />
      )

      // Child component should trigger parent handler
      const actionButton = screen.getByText('Approve Item 1')
      await user.click(actionButton)

      expect(mockOnAction).toHaveBeenCalled()
    })
  })
})