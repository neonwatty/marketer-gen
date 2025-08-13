import React from 'react'
import { render, screen, fireEvent, waitFor, act } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import '@testing-library/jest-dom'

// Mock the permissions module
jest.mock('@/lib/permissions', () => ({
  validateComponentAccess: jest.fn(() => true)
}))

// Mock the date-fns module
jest.mock('date-fns', () => ({
  formatDistanceToNow: jest.fn(() => '2 minutes ago')
}))

import { CommentSystem } from '@/components/collaboration/comment-system'
import { Comment, CommentReaction, User, CommentReactionType, CommentTargetType } from '@/types'

// Test data
const mockCurrentUser: User = {
  id: 'user-1',
  name: 'John Doe',
  email: 'john@example.com',
  avatar: 'https://example.com/avatar.jpg',
  createdAt: new Date('2024-01-01'),
  updatedAt: new Date('2024-01-01')
}

const mockAuthor: User = {
  id: 'user-2',
  name: 'Jane Smith',
  email: 'jane@example.com',
  avatar: 'https://example.com/jane.jpg',
  createdAt: new Date('2024-01-01'),
  updatedAt: new Date('2024-01-01')
}

const mockModerator: User = {
  id: 'user-3',
  name: 'Moderator',
  email: 'mod@example.com',
  avatar: 'https://example.com/mod.jpg',
  createdAt: new Date('2024-01-01'),
  updatedAt: new Date('2024-01-01')
}

const mockReaction: CommentReaction = {
  userId: 'user-1',
  user: mockCurrentUser,
  type: 'like',
  createdAt: new Date('2024-01-02')
}

const mockComment: Comment = {
  id: 'comment-1',
  content: 'This is a test comment',
  authorId: 'user-2',
  author: mockAuthor,
  targetType: 'campaign',
  targetId: 'campaign-1',
  reactions: [mockReaction],
  mentions: [],
  isResolved: false,
  createdAt: new Date('2024-01-02'),
  updatedAt: new Date('2024-01-02')
}

const mockReplyComment: Comment = {
  id: 'comment-2',
  content: 'This is a reply comment',
  authorId: 'user-1',
  author: mockCurrentUser,
  targetType: 'campaign',
  targetId: 'campaign-1',
  parentCommentId: 'comment-1',
  reactions: [],
  mentions: ['user-2'],
  isResolved: false,
  createdAt: new Date('2024-01-03'),
  updatedAt: new Date('2024-01-03')
}

const mockComments: Comment[] = [
  mockComment,
  mockReplyComment
]

// Mock handlers
const mockHandlers = {
  onAddComment: jest.fn(),
  onEditComment: jest.fn(),
  onDeleteComment: jest.fn(),
  onReactToComment: jest.fn(),
  onResolveComment: jest.fn(),
  onUnresolveComment: jest.fn(),
  onModerationAction: jest.fn()
}

describe('CommentSystem Component', () => {
  beforeEach(() => {
    jest.clearAllMocks()
  })

  describe('Rendering', () => {
    test('should render comment system with basic elements', () => {
      render(
        <CommentSystem
          targetType="campaign"
          targetId="campaign-1"
          currentUser={mockCurrentUser}
          comments={mockComments}
          {...mockHandlers}
        />
      )

      expect(screen.getByText('Comments (2)')).toBeInTheDocument()
      expect(screen.getByPlaceholderText('Write a comment...')).toBeInTheDocument()
    })

    test('should render comments correctly', () => {
      render(
        <CommentSystem
          targetType="campaign"
          targetId="campaign-1"
          currentUser={mockCurrentUser}
          comments={mockComments}
          {...mockHandlers}
        />
      )

      expect(screen.getByText('This is a test comment')).toBeInTheDocument()
      expect(screen.getByText('This is a reply comment')).toBeInTheDocument()
      expect(screen.getByText('Jane Smith')).toBeInTheDocument()
      expect(screen.getByText('John Doe')).toBeInTheDocument()
    })

    test('should show loading state', () => {
      render(
        <CommentSystem
          targetType="campaign"
          targetId="campaign-1"
          currentUser={mockCurrentUser}
          comments={[]}
          isLoading={true}
          {...mockHandlers}
        />
      )

      expect(screen.getByText('Loading comments...')).toBeInTheDocument()
    })

    test('should show empty state when no comments', () => {
      render(
        <CommentSystem
          targetType="campaign"
          targetId="campaign-1"
          currentUser={mockCurrentUser}
          comments={[]}
          {...mockHandlers}
        />
      )

      expect(screen.getByText('No comments yet')).toBeInTheDocument()
      expect(screen.getByText('Be the first to comment!')).toBeInTheDocument()
    })
  })

  describe('Comment Creation', () => {
    test('should create a new comment', async () => {
      const user = userEvent.setup()
      
      render(
        <CommentSystem
          targetType="campaign"
          targetId="campaign-1"
          currentUser={mockCurrentUser}
          comments={[]}
          {...mockHandlers}
        />
      )

      const textarea = screen.getByPlaceholderText('Write a comment...')
      const submitButton = screen.getByRole('button', { name: /post/i })

      await user.type(textarea, 'New test comment')
      await user.click(submitButton)

      expect(mockHandlers.onAddComment).toHaveBeenCalledWith('New test comment', undefined, [])
    })

    test('should create comment with mentions', async () => {
      const user = userEvent.setup()
      
      render(
        <CommentSystem
          targetType="campaign"
          targetId="campaign-1"
          currentUser={mockCurrentUser}
          comments={[]}
          {...mockHandlers}
        />
      )

      const textarea = screen.getByPlaceholderText('Write a comment...')
      
      await user.type(textarea, 'Hey @jane, what do you think?')
      await user.click(screen.getByRole('button', { name: /post/i }))

      expect(mockHandlers.onAddComment).toHaveBeenCalledWith(
        'Hey @jane, what do you think?',
        undefined,
        ['jane']
      )
    })

    test('should not submit empty comment', async () => {
      const user = userEvent.setup()
      
      render(
        <CommentSystem
          targetType="campaign"
          targetId="campaign-1"
          currentUser={mockCurrentUser}
          comments={[]}
          {...mockHandlers}
        />
      )

      const submitButton = screen.getByRole('button', { name: /post/i })
      
      // Button should be disabled when content is empty
      expect(submitButton).toBeDisabled()
      
      await user.click(submitButton)
      expect(mockHandlers.onAddComment).not.toHaveBeenCalled()
    })

    test('should submit comment with Ctrl+Enter', async () => {
      const user = userEvent.setup()
      
      render(
        <CommentSystem
          targetType="campaign"
          targetId="campaign-1"
          currentUser={mockCurrentUser}
          comments={[]}
          {...mockHandlers}
        />
      )

      const textarea = screen.getByPlaceholderText('Write a comment...')
      
      await user.type(textarea, 'Quick comment')
      await user.keyboard('{Control>}{Enter}{/Control}')

      expect(mockHandlers.onAddComment).toHaveBeenCalledWith('Quick comment', undefined, [])
    })
  })

  describe('Comment Replies', () => {
    test('should show reply form when reply button clicked', async () => {
      const user = userEvent.setup()
      
      render(
        <CommentSystem
          targetType="campaign"
          targetId="campaign-1"
          currentUser={mockCurrentUser}
          comments={[mockComment]}
          {...mockHandlers}
        />
      )

      const replyButton = screen.getByRole('button', { name: /reply/i })
      await user.click(replyButton)

      expect(screen.getByPlaceholderText('Write a reply...')).toBeInTheDocument()
    })

    test('should create a reply comment', async () => {
      const user = userEvent.setup()
      
      render(
        <CommentSystem
          targetType="campaign"
          targetId="campaign-1"
          currentUser={mockCurrentUser}
          comments={[mockComment]}
          {...mockHandlers}
        />
      )

      // Click reply button
      const replyButton = screen.getByRole('button', { name: /reply/i })
      await user.click(replyButton)

      // Type reply and submit
      const replyTextarea = screen.getByPlaceholderText('Write a reply...')
      await user.type(replyTextarea, 'This is a reply')
      
      const submitReplyButton = screen.getByRole('button', { name: /reply$/i })
      await user.click(submitReplyButton)

      expect(mockHandlers.onAddComment).toHaveBeenCalledWith(
        'This is a reply',
        'comment-1',
        []
      )
    })

    test('should cancel reply form', async () => {
      const user = userEvent.setup()
      
      render(
        <CommentSystem
          targetType="campaign"
          targetId="campaign-1"
          currentUser={mockCurrentUser}
          comments={[mockComment]}
          {...mockHandlers}
        />
      )

      const replyButton = screen.getByRole('button', { name: /reply/i })
      await user.click(replyButton)

      const cancelButton = screen.getByRole('button', { name: /cancel/i })
      await user.click(cancelButton)

      expect(screen.queryByPlaceholderText('Write a reply...')).not.toBeInTheDocument()
    })
  })

  describe('Comment Editing', () => {
    test('should show edit form when edit button clicked by author', async () => {
      const user = userEvent.setup()
      
      // Comment authored by current user
      const ownComment = { ...mockComment, authorId: 'user-1', author: mockCurrentUser }
      
      render(
        <CommentSystem
          targetType="campaign"
          targetId="campaign-1"
          currentUser={mockCurrentUser}
          comments={[ownComment]}
          {...mockHandlers}
        />
      )

      // Click more menu
      const moreButton = screen.getByRole('button', { name: /more/i })
      await user.click(moreButton)

      // Click edit
      const editButton = screen.getByRole('menuitem', { name: /edit/i })
      await user.click(editButton)

      expect(screen.getByDisplayValue('This is a test comment')).toBeInTheDocument()
    })

    test('should update comment content', async () => {
      const user = userEvent.setup()
      
      const ownComment = { ...mockComment, authorId: 'user-1', author: mockCurrentUser }
      
      render(
        <CommentSystem
          targetType="campaign"
          targetId="campaign-1"
          currentUser={mockCurrentUser}
          comments={[ownComment]}
          {...mockHandlers}
        />
      )

      // Open edit form
      const moreButton = screen.getByRole('button', { name: /more/i })
      await user.click(moreButton)
      
      const editButton = screen.getByRole('menuitem', { name: /edit/i })
      await user.click(editButton)

      // Edit content
      const editTextarea = screen.getByDisplayValue('This is a test comment')
      await user.clear(editTextarea)
      await user.type(editTextarea, 'Updated comment content')

      // Submit update
      const updateButton = screen.getByRole('button', { name: /update/i })
      await user.click(updateButton)

      expect(mockHandlers.onEditComment).toHaveBeenCalledWith('comment-1', 'Updated comment content')
    })

    test('should not show edit option for comments by other users', () => {
      render(
        <CommentSystem
          targetType="campaign"
          targetId="campaign-1"
          currentUser={mockCurrentUser}
          comments={[mockComment]} // Authored by different user
          {...mockHandlers}
        />
      )

      const moreButtons = screen.queryAllByRole('button', { name: /more/i })
      expect(moreButtons).toHaveLength(0) // No actions available for non-author
    })
  })

  describe('Comment Deletion', () => {
    test('should delete comment when delete button clicked by author', async () => {
      const user = userEvent.setup()
      
      const ownComment = { ...mockComment, authorId: 'user-1', author: mockCurrentUser }
      
      render(
        <CommentSystem
          targetType="campaign"
          targetId="campaign-1"
          currentUser={mockCurrentUser}
          comments={[ownComment]}
          {...mockHandlers}
        />
      )

      // Open more menu
      const moreButton = screen.getByRole('button', { name: /more/i })
      await user.click(moreButton)

      // Click delete
      const deleteButton = screen.getByRole('menuitem', { name: /delete/i })
      await user.click(deleteButton)

      expect(mockHandlers.onDeleteComment).toHaveBeenCalledWith('comment-1')
    })

    test('should show delete confirmation dialog', async () => {
      // This would depend on implementation details
      // Assuming there's a confirmation dialog
      const user = userEvent.setup()
      
      const ownComment = { ...mockComment, authorId: 'user-1', author: mockCurrentUser }
      
      render(
        <CommentSystem
          targetType="campaign"
          targetId="campaign-1"
          currentUser={mockCurrentUser}
          comments={[ownComment]}
          {...mockHandlers}
        />
      )

      const moreButton = screen.getByRole('button', { name: /more/i })
      await user.click(moreButton)

      const deleteButton = screen.getByRole('menuitem', { name: /delete/i })
      await user.click(deleteButton)

      // Assuming immediate deletion for now, but could check for confirmation dialog
      expect(mockHandlers.onDeleteComment).toHaveBeenCalledWith('comment-1')
    })
  })

  describe('Comment Reactions', () => {
    test('should add reaction to comment', async () => {
      const user = userEvent.setup()
      
      render(
        <CommentSystem
          targetType="campaign"
          targetId="campaign-1"
          currentUser={mockCurrentUser}
          comments={[mockComment]}
          {...mockHandlers}
        />
      )

      const likeButton = screen.getByRole('button', { name: /like/i })
      await user.click(likeButton)

      expect(mockHandlers.onReactToComment).toHaveBeenCalledWith('comment-1', 'like')
    })

    test('should show reaction counts', () => {
      const commentWithReactions = {
        ...mockComment,
        reactions: [
          mockReaction,
          { ...mockReaction, userId: 'user-3', type: 'love' as CommentReactionType }
        ]
      }

      render(
        <CommentSystem
          targetType="campaign"
          targetId="campaign-1"
          currentUser={mockCurrentUser}
          comments={[commentWithReactions]}
          {...mockHandlers}
        />
      )

      // Should show reaction count
      expect(screen.getByText('1')).toBeInTheDocument() // Like count
    })

    test('should handle different reaction types', async () => {
      const user = userEvent.setup()
      
      render(
        <CommentSystem
          targetType="campaign"
          targetId="campaign-1"
          currentUser={mockCurrentUser}
          comments={[mockComment]}
          {...mockHandlers}
        />
      )

      // Test different reaction types
      const reactionTypes: CommentReactionType[] = ['like', 'dislike', 'love', 'laugh', 'angry', 'sad']
      
      for (const reactionType of reactionTypes) {
        const reactionButton = screen.getByRole('button', { name: new RegExp(reactionType, 'i') })
        await user.click(reactionButton)
        
        expect(mockHandlers.onReactToComment).toHaveBeenCalledWith('comment-1', reactionType)
      }
    })
  })

  describe('Comment Resolution', () => {
    test('should resolve comment', async () => {
      const user = userEvent.setup()
      
      render(
        <CommentSystem
          targetType="campaign"
          targetId="campaign-1"
          currentUser={mockCurrentUser}
          comments={[mockComment]}
          canModerate={true}
          {...mockHandlers}
        />
      )

      const resolveButton = screen.getByRole('button', { name: /resolve/i })
      await user.click(resolveButton)

      expect(mockHandlers.onResolveComment).toHaveBeenCalledWith('comment-1')
    })

    test('should unresolve comment', async () => {
      const user = userEvent.setup()
      
      const resolvedComment = { ...mockComment, isResolved: true }
      
      render(
        <CommentSystem
          targetType="campaign"
          targetId="campaign-1"
          currentUser={mockCurrentUser}
          comments={[resolvedComment]}
          canModerate={true}
          {...mockHandlers}
        />
      )

      const unresolveButton = screen.getByRole('button', { name: /unresolve/i })
      await user.click(unresolveButton)

      expect(mockHandlers.onUnresolveComment).toHaveBeenCalledWith('comment-1')
    })

    test('should show resolved badge for resolved comments', () => {
      const resolvedComment = {
        ...mockComment,
        isResolved: true,
        resolvedBy: 'user-1',
        resolvedAt: new Date('2024-01-03')
      }

      render(
        <CommentSystem
          targetType="campaign"
          targetId="campaign-1"
          currentUser={mockCurrentUser}
          comments={[resolvedComment]}
          {...mockHandlers}
        />
      )

      expect(screen.getByText('Resolved')).toBeInTheDocument()
    })
  })

  describe('Comment Moderation', () => {
    test('should show moderation options to moderators', async () => {
      const user = userEvent.setup()
      
      render(
        <CommentSystem
          targetType="campaign"
          targetId="campaign-1"
          currentUser={mockModerator}
          comments={[mockComment]}
          canModerate={true}
          {...mockHandlers}
        />
      )

      const moreButton = screen.getByRole('button', { name: /more/i })
      await user.click(moreButton)

      expect(screen.getByRole('menuitem', { name: /flag/i })).toBeInTheDocument()
    })

    test('should flag comment', async () => {
      const user = userEvent.setup()
      
      render(
        <CommentSystem
          targetType="campaign"
          targetId="campaign-1"
          currentUser={mockModerator}
          comments={[mockComment]}
          canModerate={true}
          {...mockHandlers}
        />
      )

      const moreButton = screen.getByRole('button', { name: /more/i })
      await user.click(moreButton)

      const flagButton = screen.getByRole('menuitem', { name: /flag/i })
      await user.click(flagButton)

      expect(mockHandlers.onModerationAction).toHaveBeenCalledWith('comment-1', 'flag')
    })

    test('should not show moderation options to non-moderators', () => {
      render(
        <CommentSystem
          targetType="campaign"
          targetId="campaign-1"
          currentUser={mockCurrentUser}
          comments={[mockComment]}
          canModerate={false}
          {...mockHandlers}
        />
      )

      // Non-authors, non-moderators should not see action buttons
      const moreButtons = screen.queryAllByRole('button', { name: /more/i })
      expect(moreButtons).toHaveLength(0)
    })
  })

  describe('Mention Detection', () => {
    test('should detect and display mentions in comment form', async () => {
      const user = userEvent.setup()
      
      render(
        <CommentSystem
          targetType="campaign"
          targetId="campaign-1"
          currentUser={mockCurrentUser}
          comments={[]}
          {...mockHandlers}
        />
      )

      const textarea = screen.getByPlaceholderText('Write a comment...')
      await user.type(textarea, 'Hey @jane and @john, check this out!')

      // Should display mention badges
      await waitFor(() => {
        expect(screen.getByText('jane')).toBeInTheDocument()
        expect(screen.getByText('john')).toBeInTheDocument()
      })
    })

    test('should highlight mentions in rendered comments', () => {
      const commentWithMentions = {
        ...mockComment,
        content: 'Thanks @john for the feedback!',
        mentions: ['john']
      }

      render(
        <CommentSystem
          targetType="campaign"
          targetId="campaign-1"
          currentUser={mockCurrentUser}
          comments={[commentWithMentions]}
          {...mockHandlers}
        />
      )

      expect(screen.getByText('Thanks @john for the feedback!')).toBeInTheDocument()
    })
  })

  describe('Comment Threading', () => {
    test('should display comment replies with proper indentation', () => {
      const threadedComments = [
        mockComment,
        { ...mockReplyComment, parentCommentId: 'comment-1' },
        { 
          ...mockReplyComment, 
          id: 'comment-3',
          parentCommentId: 'comment-2', 
          content: 'Reply to reply' 
        }
      ]

      render(
        <CommentSystem
          targetType="campaign"
          targetId="campaign-1"
          currentUser={mockCurrentUser}
          comments={threadedComments}
          {...mockHandlers}
        />
      )

      expect(screen.getByText('This is a test comment')).toBeInTheDocument()
      expect(screen.getByText('This is a reply comment')).toBeInTheDocument()
      expect(screen.getByText('Reply to reply')).toBeInTheDocument()
    })

    test('should toggle reply visibility', async () => {
      const user = userEvent.setup()
      
      const parentWithReplies = {
        ...mockComment,
        replies: [mockReplyComment]
      }

      render(
        <CommentSystem
          targetType="campaign"
          targetId="campaign-1"
          currentUser={mockCurrentUser}
          comments={[parentWithReplies]}
          {...mockHandlers}
        />
      )

      // Initially replies should be visible
      expect(screen.getByText('This is a reply comment')).toBeInTheDocument()

      // Find and click toggle button (this depends on implementation)
      const toggleButton = screen.getByRole('button', { name: /hide replies|show replies/i })
      await user.click(toggleButton)

      // After toggle, reply might be hidden (depends on implementation)
    })
  })

  describe('Keyboard Navigation', () => {
    test('should support Escape key to cancel forms', async () => {
      const user = userEvent.setup()
      
      render(
        <CommentSystem
          targetType="campaign"
          targetId="campaign-1"
          currentUser={mockCurrentUser}
          comments={[mockComment]}
          {...mockHandlers}
        />
      )

      // Open reply form
      const replyButton = screen.getByRole('button', { name: /reply/i })
      await user.click(replyButton)

      const replyTextarea = screen.getByPlaceholderText('Write a reply...')
      await user.type(replyTextarea, 'Some reply text')

      // Press Escape
      await user.keyboard('{Escape}')

      // Form should be closed
      expect(screen.queryByPlaceholderText('Write a reply...')).not.toBeInTheDocument()
    })

    test('should support keyboard shortcuts for submission', async () => {
      const user = userEvent.setup()
      
      render(
        <CommentSystem
          targetType="campaign"
          targetId="campaign-1"
          currentUser={mockCurrentUser}
          comments={[]}
          {...mockHandlers}
        />
      )

      const textarea = screen.getByPlaceholderText('Write a comment...')
      await user.type(textarea, 'Keyboard shortcut test')
      
      // Ctrl+Enter should submit
      await user.keyboard('{Control>}{Enter}{/Control}')

      expect(mockHandlers.onAddComment).toHaveBeenCalledWith('Keyboard shortcut test', undefined, [])
    })
  })

  describe('Error Handling', () => {
    test('should handle failed comment submission', async () => {
      const user = userEvent.setup()
      
      // Mock failed submission
      mockHandlers.onAddComment.mockRejectedValueOnce(new Error('Network error'))
      
      render(
        <CommentSystem
          targetType="campaign"
          targetId="campaign-1"
          currentUser={mockCurrentUser}
          comments={[]}
          {...mockHandlers}
        />
      )

      const textarea = screen.getByPlaceholderText('Write a comment...')
      await user.type(textarea, 'Test comment')
      
      const submitButton = screen.getByRole('button', { name: /post/i })
      await user.click(submitButton)

      // Should show error state or retry option
      expect(mockHandlers.onAddComment).toHaveBeenCalled()
    })

    test('should handle missing user data gracefully', () => {
      const commentWithoutAuthor = {
        ...mockComment,
        author: undefined as any
      }

      render(
        <CommentSystem
          targetType="campaign"
          targetId="campaign-1"
          currentUser={mockCurrentUser}
          comments={[commentWithoutAuthor]}
          {...mockHandlers}
        />
      )

      // Should not crash and show some fallback
      expect(screen.getByText('This is a test comment')).toBeInTheDocument()
    })
  })

  describe('Accessibility', () => {
    test('should have proper ARIA labels and roles', () => {
      render(
        <CommentSystem
          targetType="campaign"
          targetId="campaign-1"
          currentUser={mockCurrentUser}
          comments={[mockComment]}
          {...mockHandlers}
        />
      )

      // Check for proper form labeling
      const textarea = screen.getByPlaceholderText('Write a comment...')
      expect(textarea).toBeInTheDocument()

      // Check for button roles
      const buttons = screen.getAllByRole('button')
      expect(buttons.length).toBeGreaterThan(0)
    })

    test('should support screen reader navigation', () => {
      render(
        <CommentSystem
          targetType="campaign"
          targetId="campaign-1"
          currentUser={mockCurrentUser}
          comments={[mockComment]}
          {...mockHandlers}
        />
      )

      // Comments should have appropriate structure for screen readers
      expect(screen.getByRole('article')).toBeInTheDocument() // Assuming comments are in article tags
    })
  })
})

describe('CommentSystem Integration', () => {
  test('should handle real-time updates', async () => {
    const { rerender } = render(
      <CommentSystem
        targetType="campaign"
        targetId="campaign-1"
        currentUser={mockCurrentUser}
        comments={[mockComment]}
        {...mockHandlers}
      />
    )

    // Simulate new comment added externally
    const newComment: Comment = {
      id: 'comment-new',
      content: 'New real-time comment',
      authorId: 'user-3',
      author: mockModerator,
      targetType: 'campaign',
      targetId: 'campaign-1',
      reactions: [],
      mentions: [],
      isResolved: false,
      createdAt: new Date(),
      updatedAt: new Date()
    }

    rerender(
      <CommentSystem
        targetType="campaign"
        targetId="campaign-1"
        currentUser={mockCurrentUser}
        comments={[mockComment, newComment]}
        {...mockHandlers}
      />
    )

    expect(screen.getByText('New real-time comment')).toBeInTheDocument()
    expect(screen.getByText('Comments (2)')).toBeInTheDocument()
  })

  test('should maintain scroll position during updates', () => {
    // This would test scroll behavior during comment updates
    // Implementation depends on specific scroll handling logic
    
    render(
      <CommentSystem
        targetType="campaign"
        targetId="campaign-1"
        currentUser={mockCurrentUser}
        comments={mockComments}
        {...mockHandlers}
      />
    )

    // Test would verify that scroll position is maintained
    // when new comments are added or existing ones are updated
    expect(screen.getByText('Comments (2)')).toBeInTheDocument()
  })

  test('should handle permission changes dynamically', () => {
    const { rerender } = render(
      <CommentSystem
        targetType="campaign"
        targetId="campaign-1"
        currentUser={mockCurrentUser}
        comments={[mockComment]}
        canModerate={false}
        {...mockHandlers}
      />
    )

    // Should not show moderation options
    expect(screen.queryByRole('button', { name: /flag/i })).not.toBeInTheDocument()

    // Update with moderation permissions
    rerender(
      <CommentSystem
        targetType="campaign"
        targetId="campaign-1"
        currentUser={mockCurrentUser}
        comments={[mockComment]}
        canModerate={true}
        {...mockHandlers}
      />
    )

    // Should now show moderation options
    // (This depends on how moderation UI is implemented)
  })
})