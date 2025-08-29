import React from 'react'
import { render, screen, fireEvent, waitFor } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { axe } from 'jest-axe'
import { ApprovalWorkflow } from '@/components/features/content/ApprovalWorkflow'
import type { ContentApprovalWorkflow, ApprovalWorkflowTemplate } from '@/components/features/content/ApprovalWorkflow'
import { ContentType } from '@/generated/prisma'

// Mock dependencies
jest.mock('lucide-react', () => ({
  AlertCircle: () => <div data-testid="alert-circle-icon" />,
  CheckCircle: () => <div data-testid="check-circle-icon" />,
  Clock: () => <div data-testid="clock-icon" />,
  FileText: () => <div data-testid="file-text-icon" />,
  Plus: () => <div data-testid="plus-icon" />,
  Settings: () => <div data-testid="settings-icon" />,
  Users: () => <div data-testid="users-icon" />,
}))

// Mock Dialog components with proper state management
jest.mock('@/components/ui/dialog', () => {
  const MockDialog = ({ children, open, onOpenChange }: any) => {
    const [isOpen, setIsOpen] = React.useState(open || false)
    
    // Sync internal state with external open prop
    React.useEffect(() => {
      setIsOpen(open || false)
    }, [open])
    
    // Create a context to share dialog state with children
    const dialogContext = {
      isOpen,
      setIsOpen: (newOpen: boolean) => {
        setIsOpen(newOpen)
        onOpenChange?.(newOpen)
      }
    }
    
    return (
      <div data-testid="ui-dialog" data-open={isOpen}>
        {React.Children.map(children, (child) => {
          if (React.isValidElement(child)) {
            // Only pass __dialogContext to components that need it, not DOM elements
            const isComponent = typeof child.type === 'function' || 
                               (typeof child.type === 'string' && child.type.startsWith('Mock'))
            
            if (isComponent) {
              return React.cloneElement(child, { ...child.props, __dialogContext: dialogContext })
            } else {
              // For DOM elements, filter out internal props
              const { __dialogContext, ...cleanProps } = child.props
              return React.cloneElement(child, cleanProps)
            }
          }
          return child
        })}
      </div>
    )
  }
  
  const MockDialogTrigger = ({ asChild, children, __dialogContext, ...otherProps }: any) => {
    if (asChild && React.isValidElement(children)) {
      // Filter out internal props before cloning
      const { __dialogContext: _, ...cleanChildProps } = children.props
      return React.cloneElement(children, {
        ...cleanChildProps,
        onClick: (e: any) => {
          __dialogContext?.setIsOpen(true)
          children.props.onClick?.(e)
        }
      })
    }
    return (
      <button 
        data-testid="ui-dialog-trigger" 
        onClick={() => __dialogContext?.setIsOpen(true)}
        {...otherProps}
      >
        {children}
      </button>
    )
  }
  
  const MockDialogContent = ({ children, __dialogContext }: any) => {
    if (!__dialogContext?.isOpen) return null
    
    return (
      <div data-testid="ui-dialog-content">
        {React.Children.map(children, (child) => {
          if (React.isValidElement(child)) {
            // Only pass __dialogContext to components that need it, not DOM elements
            const isComponent = typeof child.type === 'function' || 
                               (typeof child.type === 'string' && child.type.startsWith('Mock'))
            
            if (isComponent) {
              return React.cloneElement(child, { ...child.props, __dialogContext })
            } else {
              // For DOM elements, filter out internal props
              const { __dialogContext: _, ...cleanProps } = child.props
              return React.cloneElement(child, cleanProps)
            }
          }
          return child
        })}
      </div>
    )
  }
  
  const MockDialogFooter = ({ children, __dialogContext }: any) => (
    <div data-testid="ui-dialog-footer">
      {React.Children.map(children, (child) => {
        if (React.isValidElement(child) && child.props.children === 'Cancel') {
          // Filter out internal props for DOM elements
          const { __dialogContext: _, ...cleanProps } = child.props
          return React.cloneElement(child, {
            ...cleanProps,
            onClick: (e: any) => {
              __dialogContext?.setIsOpen(false)
              child.props.onClick?.(e)
            }
          })
        }
        // Filter out internal props for all child elements
        if (React.isValidElement(child)) {
          const { __dialogContext: _, ...cleanProps } = child.props
          return React.cloneElement(child, cleanProps)
        }
        return child
      })}
    </div>
  )
  
  return {
    Dialog: MockDialog,
    DialogContent: MockDialogContent,
    DialogDescription: ({ children }: any) => <div data-testid="ui-dialog-description">{children}</div>,
    DialogFooter: MockDialogFooter,
    DialogHeader: ({ children }: any) => <div data-testid="ui-dialog-header">{children}</div>,
    DialogTitle: ({ children }: any) => <div data-testid="ui-dialog-title">{children}</div>,
    DialogTrigger: MockDialogTrigger,
  }
})

// Mock Select components
jest.mock('@/components/ui/select', () => {
  const MockSelect = ({ children, value, onValueChange }: any) => {
    return (
      <div data-testid="ui-select" data-value={value}>
        {React.Children.map(children, (child) => {
          if (React.isValidElement(child)) {
            return React.cloneElement(child, { ...child.props, onValueChange })
          }
          return child
        })}
      </div>
    )
  }

  const MockSelectTrigger = ({ children, onValueChange }: any) => (
    <button 
      role="combobox" 
      data-testid="ui-select-trigger"
      aria-expanded="false"
      aria-controls="select-content"
      aria-label="Select template"
      onClick={() => {
        // Simulate opening the dropdown - do nothing for now
      }}
    >
      {children}
    </button>
  )

  const MockSelectValue = ({ placeholder }: any) => (
    <span data-testid="ui-select-value">{placeholder || 'Select...'}</span>
  )

  const MockSelectContent = ({ children, onValueChange }: any) => (
    <div data-testid="ui-select-content">
      {React.Children.map(children, (child) => {
        if (React.isValidElement(child)) {
          return React.cloneElement(child, { ...child.props, onValueChange })
        }
        return child
      })}
    </div>
  )

  const MockSelectItem = ({ children, value, onValueChange }: any) => (
    <button
      data-testid="ui-select-item"
      data-value={value}
      onClick={() => onValueChange?.(value)}
    >
      {children}
    </button>
  )

  return {
    Select: MockSelect,
    SelectTrigger: MockSelectTrigger,
    SelectValue: MockSelectValue,
    SelectContent: MockSelectContent,
    SelectItem: MockSelectItem,
  }
})

const mockCurrentUserId = 'user-1'

const mockAvailableUsers = [
  { id: 'user-1', name: 'John Doe', avatar: '/avatar1.jpg' },
  { id: 'user-2', name: 'Jane Smith', avatar: '/avatar2.jpg' },
  { id: 'user-3', name: 'Bob Johnson' },
]

const mockTemplates: ApprovalWorkflowTemplate[] = [
  {
    id: 'template-1',
    name: 'Marketing Content Review',
    description: 'Standard review process for marketing materials',
    contentTypes: [ContentType.BLOG_POST, ContentType.EMAIL],
    steps: [
      {
        id: 'step-1',
        name: 'Content Review',
        description: 'Review content for accuracy',
        requiredApprovals: 1,
        assignedUsers: ['user-2'],
        isParallel: false,
        order: 1,
      },
      {
        id: 'step-2',
        name: 'Final Approval',
        description: 'Final sign-off',
        requiredApprovals: 1,
        assignedUsers: ['user-3'],
        isParallel: false,
        order: 2,
      },
    ],
    isDefault: true,
    createdBy: 'user-1',
    createdAt: new Date('2024-01-01'),
  },
]

const mockWorkflows: ContentApprovalWorkflow[] = [
  {
    id: 'workflow-1',
    contentId: 'content-1',
    contentTitle: 'Test Blog Post',
    contentType: ContentType.BLOG_POST,
    templateId: 'template-1',
    steps: [
      {
        id: 'step-1',
        name: 'Content Review',
        description: 'Review content for accuracy',
        requiredApprovals: 1,
        assignedUsers: ['user-1'],
        approvals: [],
        isParallel: false,
        order: 1,
        status: 'in_progress',
      },
      {
        id: 'step-2',
        name: 'Final Approval',
        description: 'Final sign-off',
        requiredApprovals: 1,
        assignedUsers: ['user-3'],
        approvals: [],
        isParallel: false,
        order: 2,
        status: 'pending',
      },
    ],
    currentStepIndex: 0,
    status: 'in_progress',
    submittedBy: 'user-2',
    submittedByName: 'Jane Smith',
    submittedAt: new Date('2024-01-15'),
    dueDate: new Date(Date.now() + 86400000), // 1 day from now
  },
]

const mockWorkflowWithUrgentDue: ContentApprovalWorkflow = {
  ...mockWorkflows[0],
  id: 'workflow-urgent',
  dueDate: new Date(Date.now() + 86400000), // 1 day from now (urgent)
}

const defaultProps = {
  workflows: mockWorkflows,
  templates: mockTemplates,
  currentUserId: mockCurrentUserId,
  onApprove: jest.fn(),
  onReject: jest.fn(),
  onRequestChanges: jest.fn(),
  onCreateTemplate: jest.fn(),
  onCreateWorkflow: jest.fn(),
  availableUsers: mockAvailableUsers,
}

describe('ApprovalWorkflow', () => {
  beforeEach(() => {
    jest.clearAllMocks()
  })

  describe('Loading State', () => {
    it('should render loading state when isLoading is true', () => {
      render(<ApprovalWorkflow {...defaultProps} isLoading={true} />)

      expect(screen.getByText('Loading approval workflows...')).toBeInTheDocument()
      expect(document.querySelector('.animate-spin')).toBeInTheDocument()
    })

    it('should have proper accessibility in loading state', async () => {
      const { container } = render(<ApprovalWorkflow {...defaultProps} isLoading={true} />)
      const results = await axe(container)
      expect(results).toHaveNoViolations()
    })
  })

  describe('Header and Actions', () => {
    it('should render header with title and description', () => {
      render(<ApprovalWorkflow {...defaultProps} />)

      expect(screen.getByText('Approval Workflows')).toBeInTheDocument()
      expect(screen.getByText('Manage content approval processes and collaboration workflows')).toBeInTheDocument()
    })

    it('should render action buttons', () => {
      render(<ApprovalWorkflow {...defaultProps} />)

      // Only trigger buttons should be visible when dialogs are closed
      expect(screen.getByText('Create Template')).toBeInTheDocument()
      expect(screen.getByText('Start Workflow')).toBeInTheDocument()
    })

    it('should have proper accessibility for action buttons', async () => {
      const { container } = render(<ApprovalWorkflow {...defaultProps} />)
      const results = await axe(container)
      expect(results).toHaveNoViolations()
    })
  })

  describe('Urgent Alerts', () => {
    it('should show urgent alert when workflows are due soon', () => {
      render(<ApprovalWorkflow {...defaultProps} workflows={[mockWorkflowWithUrgentDue]} />)

      expect(screen.getByText('Urgent Approvals Required')).toBeInTheDocument()
      expect(screen.getByText(/You have content awaiting your approval with due dates approaching/)).toBeInTheDocument()
    })

    it('should not show urgent alert when no urgent workflows exist', () => {
      const nonUrgentWorkflow = {
        ...mockWorkflows[0],
        dueDate: new Date(Date.now() + 7 * 86400000), // 7 days from now
      }
      render(<ApprovalWorkflow {...defaultProps} workflows={[nonUrgentWorkflow]} />)

      expect(screen.queryByText('Urgent Approvals Required')).not.toBeInTheDocument()
    })

    it('should have proper accessibility for urgent alerts', async () => {
      const { container } = render(<ApprovalWorkflow {...defaultProps} workflows={[mockWorkflowWithUrgentDue]} />)
      const results = await axe(container)
      expect(results).toHaveNoViolations()
    })
  })

  describe('Workflow Display', () => {
    it('should render workflow list when workflows exist', () => {
      render(<ApprovalWorkflow {...defaultProps} />)

      expect(screen.getByText('Active Workflows')).toBeInTheDocument()
      expect(screen.getAllByText('Test Blog Post')[0]).toBeInTheDocument()
      expect(screen.getByText('Current Step: Content Review')).toBeInTheDocument()
    })

    it('should show empty state when no workflows exist', () => {
      render(<ApprovalWorkflow {...defaultProps} workflows={[]} />)

      expect(screen.getByText('No active workflows')).toBeInTheDocument()
      expect(screen.getByText('Start a new approval workflow to get content reviewed and approved')).toBeInTheDocument()
    })

    it('should display workflow status badges correctly', () => {
      render(<ApprovalWorkflow {...defaultProps} />)

      expect(screen.getAllByText('In Progress')[0]).toBeInTheDocument()
    })

    it('should have proper accessibility for workflow cards', async () => {
      const { container } = render(<ApprovalWorkflow {...defaultProps} />)
      const results = await axe(container)
      expect(results).toHaveNoViolations()
    })
  })

  describe('Create Template Dialog', () => {
    it('should open create template dialog when button is clicked', async () => {
      const user = userEvent.setup()
      render(<ApprovalWorkflow {...defaultProps} />)

      // Get the create template button specifically from the trigger (not the one inside the dialog)
      const createTemplateButton = screen.getAllByRole('button', { name: /create template/i })[0]
      await user.click(createTemplateButton)

      expect(screen.getByText('Create Approval Template')).toBeInTheDocument()
      expect(screen.getByText('Define a reusable approval workflow template')).toBeInTheDocument()
      expect(screen.getByLabelText('Template Name')).toBeInTheDocument()
      expect(screen.getByLabelText('Description')).toBeInTheDocument()
    })

    it('should handle template creation form input', async () => {
      const user = userEvent.setup()
      render(<ApprovalWorkflow {...defaultProps} />)

      const createTemplateButton = screen.getAllByRole('button', { name: /create template/i })[0]
      await user.click(createTemplateButton)

      const nameInput = screen.getByLabelText('Template Name')
      const descriptionInput = screen.getByLabelText('Description')

      await user.type(nameInput, 'New Template')
      await user.type(descriptionInput, 'Template description')

      expect(nameInput).toHaveValue('New Template')
      expect(descriptionInput).toHaveValue('Template description')
    })

    it('should call onCreateTemplate when form is submitted', async () => {
      const user = userEvent.setup()
      render(<ApprovalWorkflow {...defaultProps} />)

      const createTemplateButton = screen.getAllByRole('button', { name: /create template/i })[0]
      await user.click(createTemplateButton)

      const nameInput = screen.getByLabelText('Template Name')
      await user.type(nameInput, 'New Template')

      const submitButton = screen.getAllByRole('button', { name: /create template/i })[1]
      await user.click(submitButton)

      expect(defaultProps.onCreateTemplate).toHaveBeenCalledWith({
        name: 'New Template',
        description: '',
        contentTypes: [],
        steps: [],
        isDefault: false,
      })
    })

    it('should disable submit button when template name is empty', async () => {
      const user = userEvent.setup()
      render(<ApprovalWorkflow {...defaultProps} />)

      const createTemplateButton = screen.getAllByRole('button', { name: /create template/i })[0]
      await user.click(createTemplateButton)

      const submitButton = screen.getAllByRole('button', { name: /create template/i })[1]
      expect(submitButton).toBeDisabled()
    })

    it('should have proper accessibility in template dialog', async () => {
      const user = userEvent.setup()
      const { container } = render(<ApprovalWorkflow {...defaultProps} />)

      const createTemplateButton = screen.getAllByRole('button', { name: /create template/i })[0]
      await user.click(createTemplateButton)

      const results = await axe(container)
      expect(results).toHaveNoViolations()
    })

    it('should close template dialog when cancelled', async () => {
      const user = userEvent.setup()
      render(<ApprovalWorkflow {...defaultProps} />)

      const createTemplateButton = screen.getAllByRole('button', { name: /create template/i })[0]
      await user.click(createTemplateButton)

      const cancelButtons = screen.getAllByRole('button', { name: /cancel/i })
      // Click the first Cancel button (should be the one in the create template dialog)
      await user.click(cancelButtons[0])

      expect(screen.queryByText('Create Approval Template')).not.toBeInTheDocument()
    })
  })

  describe('Start Workflow Dialog', () => {
    it('should open start workflow dialog when button is clicked', async () => {
      const user = userEvent.setup()
      render(<ApprovalWorkflow {...defaultProps} />)

      const startWorkflowButton = screen.getByRole('button', { name: /start workflow/i })
      await user.click(startWorkflowButton)

      expect(screen.getByText('Start Approval Workflow')).toBeInTheDocument()
      expect(screen.getByText('Create a new approval workflow for content')).toBeInTheDocument()
      expect(screen.getByLabelText('Content Title')).toBeInTheDocument()
      expect(screen.getByText('Approval Template')).toBeInTheDocument()
      expect(screen.getByLabelText('Due Date (Optional)')).toBeInTheDocument()
    })

    it('should handle workflow creation form input', async () => {
      const user = userEvent.setup()
      render(<ApprovalWorkflow {...defaultProps} />)

      const startWorkflowButton = screen.getByRole('button', { name: /start workflow/i })
      await user.click(startWorkflowButton)

      const titleInput = screen.getByLabelText('Content Title')
      await user.type(titleInput, 'New Content')

      const templateSelect = screen.getByRole('combobox')
      await user.click(templateSelect)
      await user.click(screen.getByText('Marketing Content Review'))

      const dueDateInput = screen.getByLabelText('Due Date (Optional)')
      await user.type(dueDateInput, '2024-12-31T12:00')

      expect(titleInput).toHaveValue('New Content')
      expect(dueDateInput).toHaveValue('2024-12-31T12:00')
    })

    it('should call onCreateWorkflow when form is submitted', async () => {
      const user = userEvent.setup()
      render(<ApprovalWorkflow {...defaultProps} />)

      const startWorkflowButton = screen.getByRole('button', { name: /start workflow/i })
      await user.click(startWorkflowButton)

      const titleInput = screen.getByLabelText('Content Title')
      await user.type(titleInput, 'New Content')

      const templateSelect = screen.getByRole('combobox')
      await user.click(templateSelect)
      await user.click(screen.getByText('Marketing Content Review'))

      const submitButtons = screen.getAllByRole('button', { name: /start workflow/i })
      const submitButton = submitButtons[1] // The submit button inside the dialog
      await user.click(submitButton)

      expect(defaultProps.onCreateWorkflow).toHaveBeenCalledWith('new-content', 'template-1', undefined)
    })

    it('should disable submit button when required fields are empty', async () => {
      const user = userEvent.setup()
      render(<ApprovalWorkflow {...defaultProps} />)

      const startWorkflowButton = screen.getByRole('button', { name: /start workflow/i })
      await user.click(startWorkflowButton)

      const submitButtons = screen.getAllByRole('button', { name: /start workflow/i })
      const submitButton = submitButtons[1] // The submit button inside the dialog
      expect(submitButton).toBeDisabled()
    })

    it('should have proper accessibility in workflow dialog', async () => {
      const user = userEvent.setup()
      const { container } = render(<ApprovalWorkflow {...defaultProps} />)

      const startWorkflowButton = screen.getByRole('button', { name: /start workflow/i })
      await user.click(startWorkflowButton)

      const results = await axe(container)
      expect(results).toHaveNoViolations()
    })
  })

  describe('Approval Actions', () => {
    it('should show action buttons for workflows requiring action', () => {
      render(<ApprovalWorkflow {...defaultProps} />)

      expect(screen.getByRole('button', { name: /approve/i })).toBeInTheDocument()
      expect(screen.getByRole('button', { name: /reject/i })).toBeInTheDocument()
      expect(screen.getByRole('button', { name: /request changes/i })).toBeInTheDocument()
    })

    it('should open approval dialog when approve button is clicked', async () => {
      const user = userEvent.setup()
      render(<ApprovalWorkflow {...defaultProps} />)

      const approveButton = screen.getByRole('button', { name: /approve/i })
      await user.click(approveButton)

      expect(screen.getByText('Approve Content')).toBeInTheDocument()
      expect(screen.getByPlaceholderText('Add comments about the approval...')).toBeInTheDocument()
    })

    it('should open rejection dialog when reject button is clicked', async () => {
      const user = userEvent.setup()
      render(<ApprovalWorkflow {...defaultProps} />)

      const rejectButton = screen.getByRole('button', { name: /reject/i })
      await user.click(rejectButton)

      expect(screen.getByText('Reject Content')).toBeInTheDocument()
      expect(screen.getByPlaceholderText('Explain the reasons for rejection...')).toBeInTheDocument()
    })

    it('should open request changes dialog when request changes button is clicked', async () => {
      const user = userEvent.setup()
      render(<ApprovalWorkflow {...defaultProps} />)

      const requestChangesButton = screen.getByRole('button', { name: /request changes/i })
      await user.click(requestChangesButton)

      expect(screen.getAllByText('Request Changes')[0]).toBeInTheDocument()
      expect(screen.getByPlaceholderText('Describe the required changes...')).toBeInTheDocument()
    })

    it('should call onApprove when approval is submitted', async () => {
      const user = userEvent.setup()
      render(<ApprovalWorkflow {...defaultProps} />)

      const approveButtons = screen.getAllByRole('button', { name: /approve/i })
      const approveButton = approveButtons[0] // First approve button (outside dialog)
      await user.click(approveButton)

      // Wait for dialog to open and find the submit button inside dialog
      await waitFor(() => {
        expect(screen.getByText('Approve Content')).toBeInTheDocument()
      })

      const submitButtons = screen.getAllByRole('button', { name: /approve/i })
      const submitButton = submitButtons.find(button => 
        button.className.includes('bg-green-600') && 
        button.closest('[data-testid="ui-dialog-content"]')
      ) || submitButtons[1] // Fallback to second button
      await user.click(submitButton)

      expect(defaultProps.onApprove).toHaveBeenCalledWith('workflow-1', 'step-1', undefined)
    })

    it('should call onReject when rejection is submitted with comment', async () => {
      const user = userEvent.setup()
      render(<ApprovalWorkflow {...defaultProps} />)

      const rejectButtons = screen.getAllByRole('button', { name: /reject/i })
      const rejectButton = rejectButtons[0] // First reject button (outside dialog)
      await user.click(rejectButton)

      await waitFor(() => {
        expect(screen.getByText('Reject Content')).toBeInTheDocument()
      })

      const commentTextarea = screen.getByPlaceholderText('Explain the reasons for rejection...')
      await user.type(commentTextarea, 'Content needs improvement')

      const submitButtons = screen.getAllByRole('button', { name: /reject/i })
      const submitButton = submitButtons.find(button => 
        button.className.includes('bg-red-600') && 
        button.closest('[data-testid="ui-dialog-content"]')
      ) || submitButtons[1] // Fallback to second button
      await user.click(submitButton)

      expect(defaultProps.onReject).toHaveBeenCalledWith('workflow-1', 'step-1', 'Content needs improvement')
    })

    it('should call onRequestChanges when changes are requested with comment', async () => {
      const user = userEvent.setup()
      render(<ApprovalWorkflow {...defaultProps} />)

      const requestChangesButtons = screen.getAllByRole('button', { name: /request changes/i })
      const requestChangesButton = requestChangesButtons[0] // First request changes button (outside dialog)
      await user.click(requestChangesButton)

      await waitFor(() => {
        expect(screen.getAllByText('Request Changes')[0]).toBeInTheDocument()
      })

      const commentTextarea = screen.getByPlaceholderText('Describe the required changes...')
      await user.type(commentTextarea, 'Please update the introduction')

      const submitButtons = screen.getAllByRole('button', { name: /request changes/i })
      const submitButton = submitButtons.find(button => 
        button.className.includes('bg-yellow-600') && 
        button.closest('[data-testid="ui-dialog-content"]')
      ) || submitButtons[1] // Fallback to second button
      await user.click(submitButton)

      expect(defaultProps.onRequestChanges).toHaveBeenCalledWith('workflow-1', 'step-1', 'Please update the introduction')
    })

    it('should require comments for reject and request changes actions', async () => {
      const user = userEvent.setup()
      render(<ApprovalWorkflow {...defaultProps} />)

      const rejectButtons = screen.getAllByRole('button', { name: /reject/i })
      const rejectButton = rejectButtons[0] // First reject button (outside dialog)
      await user.click(rejectButton)

      await waitFor(() => {
        expect(screen.getByText('Reject Content')).toBeInTheDocument()
      })

      const submitButtons = screen.getAllByRole('button', { name: /reject/i })
      const submitButton = submitButtons.find(button => 
        button.className.includes('bg-red-600') && 
        button.closest('[data-testid="ui-dialog-content"]')
      ) || submitButtons[1] // Fallback to second button
      
      expect(submitButton).toBeDisabled()

      const commentTextarea = screen.getByPlaceholderText('Explain the reasons for rejection...')
      await user.type(commentTextarea, 'Comment required')

      expect(submitButton).toBeEnabled()
    })

    it('should have proper accessibility for action dialogs', async () => {
      const user = userEvent.setup()
      const { container } = render(<ApprovalWorkflow {...defaultProps} />)

      const approveButton = screen.getByRole('button', { name: /approve/i })
      await user.click(approveButton)

      const results = await axe(container)
      expect(results).toHaveNoViolations()
    })
  })

  describe('Keyboard Navigation', () => {
    it('should support keyboard navigation through action buttons', async () => {
      const user = userEvent.setup()
      render(<ApprovalWorkflow {...defaultProps} />)

      // Tab to the first action button
      await user.tab()
      expect(document.activeElement?.tagName.toLowerCase()).toMatch(/button/)

      // Continue tabbing through action buttons
      await user.tab()
      expect(document.activeElement?.tagName.toLowerCase()).toMatch(/button/)
    })

    it('should support Enter key activation of buttons', async () => {
      const user = userEvent.setup()
      render(<ApprovalWorkflow {...defaultProps} />)

      const approveButton = screen.getByRole('button', { name: /approve/i })
      approveButton.focus()
      
      await user.keyboard('{Enter}')
      expect(screen.getByText('Approve Content')).toBeInTheDocument()
    })
  })

  describe('Edge Cases', () => {
    it('should handle workflows without due dates', () => {
      const workflowWithoutDueDate = {
        ...mockWorkflows[0],
        dueDate: undefined,
      }
      render(<ApprovalWorkflow {...defaultProps} workflows={[workflowWithoutDueDate]} />)

      expect(screen.getAllByText('Test Blog Post')[0]).toBeInTheDocument()
      expect(screen.queryByText('Urgent Approvals Required')).not.toBeInTheDocument()
    })

    it('should handle empty template list', () => {
      render(<ApprovalWorkflow {...defaultProps} templates={[]} />)

      expect(screen.getByRole('button', { name: /start workflow/i })).toBeInTheDocument()
    })

    it('should handle workflows with completed steps', () => {
      const completedWorkflow = {
        ...mockWorkflows[0],
        steps: mockWorkflows[0].steps.map(step => ({
          ...step,
          status: 'completed' as const,
        })),
        status: 'approved' as const,
      }

      render(<ApprovalWorkflow {...defaultProps} workflows={[completedWorkflow]} />)

      expect(screen.getByText('Approved')).toBeInTheDocument()
    })
  })

  describe('Overall Accessibility', () => {
    it('should meet accessibility standards for the full component', async () => {
      const { container } = render(<ApprovalWorkflow {...defaultProps} />)
      const results = await axe(container)
      expect(results).toHaveNoViolations()
    })

    it('should meet accessibility standards with empty state', async () => {
      const { container } = render(<ApprovalWorkflow {...defaultProps} workflows={[]} />)
      const results = await axe(container)
      expect(results).toHaveNoViolations()
    })

    it('should maintain accessibility with urgent alerts', async () => {
      const { container } = render(<ApprovalWorkflow {...defaultProps} workflows={[mockWorkflowWithUrgentDue]} />)
      const results = await axe(container)
      expect(results).toHaveNoViolations()
    })
  })
})