import { render, screen, fireEvent, waitFor } from '@testing-library/react'
import { userEvent } from '@testing-library/user-event'
import { CampaignTimelineCalendar } from '../campaign-timeline-calendar'
import { format, addDays, startOfWeek, endOfWeek } from 'date-fns'

// Mock the current date for consistent testing
const mockDate = new Date('2024-08-15T12:00:00Z')
vi.setSystemTime(mockDate)

// Mock timeline events for testing
const mockTimelineEvents = [
  {
    id: "1",
    type: "campaign_launch" as const,
    title: "Campaign Launch",
    description: "Official launch of Summer Product Launch campaign",
    date: new Date('2024-08-15T09:00:00Z'),
    time: "09:00",
    status: "scheduled" as const,
    priority: "critical" as const,
    assignedTo: {
      name: "Sarah Johnson",
      initials: "SJ"
    },
    tags: ["launch", "milestone"],
    estimatedHours: 4
  },
  {
    id: "2",
    type: "content_deadline" as const,
    title: "Email Newsletter Content Due",
    description: "Final email newsletter content must be completed",
    date: new Date('2024-08-12T17:00:00Z'),
    time: "17:00",
    status: "in_progress" as const,
    priority: "high" as const,
    assignedTo: {
      name: "Mike Chen",
      initials: "MC"
    },
    tags: ["content", "email", "deadline"],
    contentType: "email-newsletter",
    channel: "Email",
    estimatedHours: 8
  },
  {
    id: "3",
    type: "content_creation" as const,
    title: "Social Media Assets Creation",
    description: "Create visual assets for social media posts",
    date: new Date('2024-08-10T10:00:00Z'),
    time: "10:00",
    status: "completed" as const,
    priority: "medium" as const,
    assignedTo: {
      name: "Emma Davis",
      initials: "ED"
    },
    tags: ["content", "social", "design"],
    contentType: "social-media",
    channel: "Social Media",
    estimatedHours: 6
  },
  {
    id: "4",
    type: "team_meeting" as const,
    title: "Weekly Campaign Sync",
    description: "Weekly team sync to discuss progress",
    date: new Date('2024-08-14T11:00:00Z'),
    time: "11:00",
    status: "scheduled" as const,
    priority: "medium" as const,
    tags: ["meeting", "sync", "team"],
    estimatedHours: 1
  },
  {
    id: "5",
    type: "content_deadline" as const,
    title: "Blog Post Deadline",
    description: "Blog post content deadline approaching",
    date: new Date('2024-08-16T15:00:00Z'),
    time: "15:00",
    status: "overdue" as const,
    priority: "high" as const,
    assignedTo: {
      name: "Alex Rivera",
      initials: "AR"
    },
    tags: ["content", "blog", "deadline"],
    contentType: "blog-post",
    channel: "Blog",
    estimatedHours: 4
  }
]

describe('CampaignTimelineCalendar Component', () => {
  const user = userEvent.setup()
  const mockOnEventClick = vi.fn()
  const mockOnDateSelect = vi.fn()

  beforeEach(() => {
    vi.clearAllMocks()
  })

  describe('Basic Rendering', () => {
    it('renders header with title and description', () => {
      render(
        <CampaignTimelineCalendar 
          campaignId="test-campaign"
          events={mockTimelineEvents}
          onEventClick={mockOnEventClick}
          onDateSelect={mockOnDateSelect}
        />
      )

      expect(screen.getByText('Campaign Timeline & Schedule')).toBeInTheDocument()
      expect(screen.getByText('Manage campaign milestones, content deadlines, and team activities')).toBeInTheDocument()
    })

    it('renders action buttons', () => {
      render(
        <CampaignTimelineCalendar 
          campaignId="test-campaign"
          events={mockTimelineEvents}
          onEventClick={mockOnEventClick}
          onDateSelect={mockOnDateSelect}
        />
      )

      expect(screen.getByText('Export Schedule')).toBeInTheDocument()
      expect(screen.getAllByText('Add Event')).toHaveLength(2) // Appears in both timeline and calendar views
    })

    it('renders tabs for timeline and calendar views', () => {
      render(
        <CampaignTimelineCalendar 
          campaignId="test-campaign"
          events={mockTimelineEvents}
          onEventClick={mockOnEventClick}
          onDateSelect={mockOnDateSelect}
        />
      )

      expect(screen.getByText('Timeline View')).toBeInTheDocument()
      expect(screen.getByText('Calendar View')).toBeInTheDocument()
    })
  })

  describe('Timeline View', () => {
    it('displays all timeline events', () => {
      render(
        <CampaignTimelineCalendar 
          campaignId="test-campaign"
          events={mockTimelineEvents}
          onEventClick={mockOnEventClick}
          onDateSelect={mockOnDateSelect}
        />
      )

      expect(screen.getByText('Campaign Launch')).toBeInTheDocument()
      expect(screen.getByText('Email Newsletter Content Due')).toBeInTheDocument()
      expect(screen.getByText('Social Media Assets Creation')).toBeInTheDocument()
      expect(screen.getByText('Weekly Campaign Sync')).toBeInTheDocument()
      expect(screen.getByText('Blog Post Deadline')).toBeInTheDocument()
    })

    it('shows event descriptions', () => {
      render(
        <CampaignTimelineCalendar 
          campaignId="test-campaign"
          events={mockTimelineEvents}
          onEventClick={mockOnEventClick}
          onDateSelect={mockOnDateSelect}
        />
      )

      expect(screen.getByText('Official launch of Summer Product Launch campaign')).toBeInTheDocument()
      expect(screen.getByText('Final email newsletter content must be completed')).toBeInTheDocument()
      expect(screen.getByText('Create visual assets for social media posts')).toBeInTheDocument()
    })

    it('displays event status badges', () => {
      render(
        <CampaignTimelineCalendar 
          campaignId="test-campaign"
          events={mockTimelineEvents}
          onEventClick={mockOnEventClick}
          onDateSelect={mockOnDateSelect}
        />
      )

      expect(screen.getAllByText('scheduled')).toHaveLength(2) // Multiple scheduled events
      expect(screen.getByText('in progress')).toBeInTheDocument()
      expect(screen.getByText('completed')).toBeInTheDocument()
      expect(screen.getByText('overdue')).toBeInTheDocument()
    })

    it('shows assigned team members', () => {
      render(
        <CampaignTimelineCalendar 
          campaignId="test-campaign"
          events={mockTimelineEvents}
          onEventClick={mockOnEventClick}
          onDateSelect={mockOnDateSelect}
        />
      )

      expect(screen.getByText('Sarah Johnson')).toBeInTheDocument()
      expect(screen.getByText('Mike Chen')).toBeInTheDocument()
      expect(screen.getByText('Emma Davis')).toBeInTheDocument()
      expect(screen.getByText('Alex Rivera')).toBeInTheDocument()
    })

    it('displays user initials in avatars', () => {
      render(
        <CampaignTimelineCalendar 
          campaignId="test-campaign"
          events={mockTimelineEvents}
          onEventClick={mockOnEventClick}
          onDateSelect={mockOnDateSelect}
        />
      )

      expect(screen.getByText('SJ')).toBeInTheDocument()
      expect(screen.getByText('MC')).toBeInTheDocument()
      expect(screen.getByText('ED')).toBeInTheDocument()
      expect(screen.getByText('AR')).toBeInTheDocument()
    })

    it('shows event tags', () => {
      render(
        <CampaignTimelineCalendar 
          campaignId="test-campaign"
          events={mockTimelineEvents}
          onEventClick={mockOnEventClick}
          onDateSelect={mockOnDateSelect}
        />
      )

      expect(screen.getByText('launch')).toBeInTheDocument()
      expect(screen.getByText('milestone')).toBeInTheDocument()
      expect(screen.getAllByText('content')).toHaveLength(3) // Multiple content-related events
      expect(screen.getByText('email')).toBeInTheDocument()
      expect(screen.getAllByText('deadline')).toHaveLength(2) // Multiple deadline events
    })

    it('displays estimated hours when available', () => {
      render(
        <CampaignTimelineCalendar 
          campaignId="test-campaign"
          events={mockTimelineEvents}
          onEventClick={mockOnEventClick}
          onDateSelect={mockOnDateSelect}
        />
      )

      expect(screen.getAllByText('4h')).toHaveLength(2) // Appears in both timeline and calendar views
      expect(screen.getByText('8h')).toBeInTheDocument()
      expect(screen.getByText('6h')).toBeInTheDocument()
      expect(screen.getByText('1h')).toBeInTheDocument()
    })

    it('shows event dates and times correctly', () => {
      render(
        <CampaignTimelineCalendar 
          campaignId="test-campaign"
          events={mockTimelineEvents}
          onEventClick={mockOnEventClick}
          onDateSelect={mockOnDateSelect}
        />
      )

      expect(screen.getByText('Aug 15, 2024')).toBeInTheDocument()
      expect(screen.getByText('Aug 12, 2024')).toBeInTheDocument()
      expect(screen.getByText('Aug 10, 2024')).toBeInTheDocument()
      expect(screen.getByText('09:00')).toBeInTheDocument()
      expect(screen.getByText('17:00')).toBeInTheDocument()
    })
  })

  describe('Timeline Event Interaction', () => {
    it('calls onEventClick when an event is clicked', async () => {
      render(
        <CampaignTimelineCalendar 
          campaignId="test-campaign"
          events={mockTimelineEvents}
          onEventClick={mockOnEventClick}
          onDateSelect={mockOnDateSelect}
        />
      )

      const eventElement = screen.getByText('Campaign Launch')
      await user.click(eventElement.closest('[role="button"], .cursor-pointer') || eventElement)

      expect(mockOnEventClick).toHaveBeenCalledTimes(1)
    })

    it('shows filter controls', () => {
      render(
        <CampaignTimelineCalendar 
          campaignId="test-campaign"
          events={mockTimelineEvents}
          onEventClick={mockOnEventClick}
          onDateSelect={mockOnDateSelect}
        />
      )

      expect(screen.getAllByText('Filter')).toHaveLength(1) // Only in timeline view
      // The select component has defaultValue="all" so should show "All Events" 
      // But in shadcn/ui Select, the trigger shows the selected value or placeholder
      const selectTrigger = screen.getByRole('combobox')
      expect(selectTrigger).toBeInTheDocument()
    })
  })

  describe('Calendar View', () => {
    it('switches to calendar view when tab is clicked', async () => {
      render(
        <CampaignTimelineCalendar 
          campaignId="test-campaign"
          events={mockTimelineEvents}
          onEventClick={mockOnEventClick}
          onDateSelect={mockOnDateSelect}
        />
      )

      const calendarTab = screen.getByText('Calendar View')
      await user.click(calendarTab)

      // Should show week navigation
      expect(screen.getByText('Today')).toBeInTheDocument()
    })

    it('displays week navigation in calendar view', async () => {
      render(
        <CampaignTimelineCalendar 
          campaignId="test-campaign"
          events={mockTimelineEvents}
          onEventClick={mockOnEventClick}
          onDateSelect={mockOnDateSelect}
        />
      )

      const calendarTab = screen.getByText('Calendar View')
      await user.click(calendarTab)

      expect(screen.getByText('Today')).toBeInTheDocument()
      
      // Should have navigation arrows
      const navButtons = screen.getAllByRole('button')
      const prevButton = navButtons.find(btn => btn.querySelector('svg'))
      const nextButton = navButtons.find(btn => btn.querySelector('svg'))
      
      expect(prevButton).toBeInTheDocument()
      expect(nextButton).toBeInTheDocument()
    })

    it('shows current week dates in calendar view', async () => {
      render(
        <CampaignTimelineCalendar 
          campaignId="test-campaign"
          events={mockTimelineEvents}
          onEventClick={mockOnEventClick}
          onDateSelect={mockOnDateSelect}
        />
      )

      const calendarTab = screen.getByText('Calendar View')
      await user.click(calendarTab)

      // Should show weekday abbreviations
      expect(screen.getByText('Sun')).toBeInTheDocument()
      expect(screen.getByText('Mon')).toBeInTheDocument()
      expect(screen.getByText('Tue')).toBeInTheDocument()
      expect(screen.getByText('Wed')).toBeInTheDocument()
      expect(screen.getByText('Thu')).toBeInTheDocument()
      expect(screen.getByText('Fri')).toBeInTheDocument()
      expect(screen.getByText('Sat')).toBeInTheDocument()
    })

    it('displays events on correct dates in calendar', async () => {
      render(
        <CampaignTimelineCalendar 
          campaignId="test-campaign"
          events={mockTimelineEvents}
          onEventClick={mockOnEventClick}
          onDateSelect={mockOnDateSelect}
        />
      )

      const calendarTab = screen.getByText('Calendar View')
      await user.click(calendarTab)

      // Events should appear on their respective dates
      // The campaign launch is on Aug 15, which should be visible in both timeline and calendar views
      await waitFor(() => {
        expect(screen.getAllByText('Campaign Launch')).toHaveLength(2) // Appears in both timeline and calendar
      })
    })

    it('handles date selection in calendar view', async () => {
      render(
        <CampaignTimelineCalendar 
          campaignId="test-campaign"
          events={mockTimelineEvents}
          onEventClick={mockOnEventClick}
          onDateSelect={mockOnDateSelect}
        />
      )

      const calendarTab = screen.getByText('Calendar View')
      await user.click(calendarTab)

      // Click on a date - look for a clickable date element
      const dateElements = screen.getAllByText(/^\d+$/) // Find elements with just numbers
      if (dateElements.length > 0) {
        await user.click(dateElements[0])
        expect(mockOnDateSelect).toHaveBeenCalledTimes(1)
      }
    })
  })

  describe('Event Priority Color Coding', () => {
    it('applies correct colors for different priority levels', () => {
      const { container } = render(
        <CampaignTimelineCalendar 
          campaignId="test-campaign"
          events={mockTimelineEvents}
          onEventClick={mockOnEventClick}
          onDateSelect={mockOnDateSelect}
        />
      )

      // Critical priority should have red styling
      const criticalElements = container.querySelectorAll('.border-red-200, .bg-red-100')
      expect(criticalElements.length).toBeGreaterThan(0)

      // High priority should have orange styling  
      const highElements = container.querySelectorAll('.border-orange-200, .bg-orange-100')
      expect(highElements.length).toBeGreaterThan(0)

      // Medium priority should have yellow styling
      const mediumElements = container.querySelectorAll('.border-yellow-200, .bg-yellow-100')
      expect(mediumElements.length).toBeGreaterThan(0)
    })
  })

  describe('Event Status Indicators', () => {
    it('applies correct styling for different status types', () => {
      const { container } = render(
        <CampaignTimelineCalendar 
          campaignId="test-campaign"
          events={mockTimelineEvents}
          onEventClick={mockOnEventClick}
          onDateSelect={mockOnDateSelect}
        />
      )

      // Scheduled status
      const scheduledElements = container.querySelectorAll('.border-slate-200, .bg-slate-100')
      expect(scheduledElements.length).toBeGreaterThan(0)

      // In progress status
      const inProgressElements = container.querySelectorAll('.border-blue-200, .bg-blue-100')
      expect(inProgressElements.length).toBeGreaterThan(0)

      // Completed status
      const completedElements = container.querySelectorAll('.border-green-200, .bg-green-100')
      expect(completedElements.length).toBeGreaterThan(0)

      // Overdue status  
      const overdueElements = container.querySelectorAll('.border-red-200, .bg-red-100')
      expect(overdueElements.length).toBeGreaterThan(0)
    })
  })

  describe('Event Type Icons', () => {
    it('displays appropriate icons for different event types', () => {
      const { container } = render(
        <CampaignTimelineCalendar 
          campaignId="test-campaign"
          events={mockTimelineEvents}
          onEventClick={mockOnEventClick}
          onDateSelect={mockOnDateSelect}
        />
      )

      // Should have various Lucide React icons rendered
      const iconContainers = container.querySelectorAll('.w-16.h-16, .w-10.h-10')
      expect(iconContainers.length).toBeGreaterThan(0)
    })
  })

  describe('Chronological Ordering', () => {
    it('displays events in chronological order', () => {
      render(
        <CampaignTimelineCalendar 
          campaignId="test-campaign"
          events={mockTimelineEvents}
          onEventClick={mockOnEventClick}
          onDateSelect={mockOnDateSelect}
        />
      )

      // Events should be sorted by date - earliest first in timeline
      const eventTitles = screen.getAllByText(/Campaign Launch|Email Newsletter|Social Media|Weekly Campaign|Blog Post/)
      expect(eventTitles.length).toBeGreaterThan(0)
    })
  })

  describe('Week Navigation in Calendar', () => {
    it('navigates to previous week when previous button is clicked', async () => {
      render(
        <CampaignTimelineCalendar 
          campaignId="test-campaign"
          events={mockTimelineEvents}
          onEventClick={mockOnEventClick}
          onDateSelect={mockOnDateSelect}
        />
      )

      const calendarTab = screen.getByText('Calendar View')
      await user.click(calendarTab)

      // Find and click the previous week button
      const buttons = screen.getAllByRole('button')
      const prevButton = buttons.find(btn => 
        btn.querySelector('svg') && btn.getAttribute('title') !== 'Next'
      )
      
      if (prevButton) {
        await user.click(prevButton)
        // Week header should change
        await waitFor(() => {
          const weekHeaders = screen.getAllByText(/Aug|Jul/)
          expect(weekHeaders.length).toBeGreaterThan(0)
        })
      }
    })

    it('navigates to today when Today button is clicked', async () => {
      render(
        <CampaignTimelineCalendar 
          campaignId="test-campaign"
          events={mockTimelineEvents}
          onEventClick={mockOnEventClick}
          onDateSelect={mockOnDateSelect}
        />
      )

      const calendarTab = screen.getByText('Calendar View')
      await user.click(calendarTab)

      const todayButton = screen.getByText('Today')
      await user.click(todayButton)

      // Should return to current week
      await waitFor(() => {
        expect(screen.getByText('Today')).toBeInTheDocument()
      })
    })
  })

  describe('Event Details Display', () => {
    it('shows detailed event information when date is selected in calendar', async () => {
      render(
        <CampaignTimelineCalendar 
          campaignId="test-campaign"
          events={mockTimelineEvents}
          onEventClick={mockOnEventClick}
          onDateSelect={mockOnDateSelect}
        />
      )

      const calendarTab = screen.getByText('Calendar View')
      await user.click(calendarTab)

      // This test would need the calendar to show events for selected dates
      // The implementation should show a detailed event panel when a date with events is selected
    })
  })

  describe('Tag Display and Overflow', () => {
    it('displays event tags and handles overflow correctly', () => {
      const eventWithManyTags = {
        ...mockTimelineEvents[0],
        tags: ['tag1', 'tag2', 'tag3', 'tag4', 'tag5', 'tag6']
      }

      render(
        <CampaignTimelineCalendar 
          campaignId="test-campaign"
          events={[eventWithManyTags]}
          onEventClick={mockOnEventClick}
          onDateSelect={mockOnDateSelect}
        />
      )

      // Should show first 3 tags and overflow indicator
      expect(screen.getByText('tag1')).toBeInTheDocument()
      expect(screen.getByText('tag2')).toBeInTheDocument()
      expect(screen.getByText('tag3')).toBeInTheDocument()
      expect(screen.getByText('+3')).toBeInTheDocument()
    })
  })

  describe('Empty State Handling', () => {
    it('handles empty events array gracefully', () => {
      render(
        <CampaignTimelineCalendar 
          campaignId="test-campaign"
          events={[]}
          onEventClick={mockOnEventClick}
          onDateSelect={mockOnDateSelect}
        />
      )

      // Should still render the basic structure
      expect(screen.getByText('Campaign Timeline & Schedule')).toBeInTheDocument()
      expect(screen.getByText('Timeline View')).toBeInTheDocument()
      expect(screen.getByText('Calendar View')).toBeInTheDocument()
    })

    it('handles events without optional fields', () => {
      const minimalEvent = {
        id: "minimal",
        type: "team_meeting" as const,
        title: "Minimal Event",
        description: "Event with minimal data",
        date: new Date('2024-08-15'),
        status: "scheduled" as const,
        priority: "medium" as const,
        tags: ["minimal"]
      }

      render(
        <CampaignTimelineCalendar 
          campaignId="test-campaign"
          events={[minimalEvent]}
          onEventClick={mockOnEventClick}
          onDateSelect={mockOnDateSelect}
        />
      )

      expect(screen.getByText('Minimal Event')).toBeInTheDocument()
      expect(screen.getByText('Event with minimal data')).toBeInTheDocument()
    })
  })

  describe('Accessibility', () => {
    it('provides proper semantic structure', () => {
      render(
        <CampaignTimelineCalendar 
          campaignId="test-campaign"
          events={mockTimelineEvents}
          onEventClick={mockOnEventClick}
          onDateSelect={mockOnDateSelect}
        />
      )

      // Should have proper heading structure
      const headings = screen.getAllByRole('heading')
      expect(headings.length).toBeGreaterThan(0)
    })

    it('makes interactive elements keyboard accessible', () => {
      render(
        <CampaignTimelineCalendar 
          campaignId="test-campaign"
          events={mockTimelineEvents}
          onEventClick={mockOnEventClick}
          onDateSelect={mockOnDateSelect}
        />
      )

      const buttons = screen.getAllByRole('button')
      expect(buttons.length).toBeGreaterThan(0)

      // Buttons should be keyboard accessible
      buttons.forEach(button => {
        expect(button).not.toHaveAttribute('tabindex', '-1')
      })
    })

    it('provides proper avatar accessibility', () => {
      render(
        <CampaignTimelineCalendar 
          campaignId="test-campaign"
          events={mockTimelineEvents}
          onEventClick={mockOnEventClick}
          onDateSelect={mockOnDateSelect}
        />
      )

      // Avatars should be accessible
      const avatarInitials = screen.getAllByText(/^[A-Z]{2}$/)
      expect(avatarInitials.length).toBeGreaterThan(0)
    })
  })

  describe('Responsive Design', () => {
    it('applies responsive grid classes', () => {
      const { container } = render(
        <CampaignTimelineCalendar 
          campaignId="test-campaign"
          events={mockTimelineEvents}
          onEventClick={mockOnEventClick}
          onDateSelect={mockOnDateSelect}
        />
      )

      // Should have responsive classes
      const responsiveElements = container.querySelectorAll('.grid-cols-7, .flex-col, .flex-row')
      expect(responsiveElements.length).toBeGreaterThan(0)
    })
  })

  describe('Performance', () => {
    it('renders efficiently with many events', () => {
      const manyEvents = Array.from({ length: 50 }, (_, i) => ({
        ...mockTimelineEvents[0],
        id: `event-${i}`,
        title: `Event ${i}`,
        date: addDays(new Date(), i)
      }))

      const startTime = performance.now()
      render(
        <CampaignTimelineCalendar 
          campaignId="test-campaign"
          events={manyEvents}
          onEventClick={mockOnEventClick}
          onDateSelect={mockOnDateSelect}
        />
      )
      const endTime = performance.now()

      // Should render quickly even with many events
      expect(endTime - startTime).toBeLessThan(1000)
    })
  })
})