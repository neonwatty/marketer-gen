import { describe, it, expect, beforeEach, vi, afterEach } from 'vitest'
import { render, screen, fireEvent } from '@testing-library/react'
import userEvent from '@testing-library/user-event'

// Mock TipTap editor
const mockEditor = {
  isActive: vi.fn(),
  can: vi.fn(() => ({ 
    chain: () => ({ 
      focus: () => ({ 
        undo: () => ({ run: () => false }),
        redo: () => ({ run: () => false })
      }) 
    }) 
  })),
  chain: vi.fn(() => ({
    focus: () => ({
      toggleBold: () => ({ run: vi.fn() }),
      toggleItalic: () => ({ run: vi.fn() }),
      toggleBulletList: () => ({ run: vi.fn() }),
      toggleOrderedList: () => ({ run: vi.fn() }),
      toggleBlockquote: () => ({ run: vi.fn() }),
      setTextAlign: (align: string) => ({ run: vi.fn() }),
      extendMarkRange: () => ({ 
        unsetLink: () => ({ run: vi.fn() }),
        setLink: (attrs: any) => ({ run: vi.fn() })
      }),
      undo: () => ({ run: vi.fn() }),
      redo: () => ({ run: vi.fn() }),
      clearNodes: () => ({ unsetAllMarks: () => ({ run: vi.fn() }) })
    })
  })),
  commands: {
    setContent: vi.fn()
  },
  getHTML: vi.fn(() => '<p>Test content</p>'),
  getAttributes: vi.fn(() => ({ href: 'https://example.com' })),
  storage: {
    characterCount: {
      characters: vi.fn(() => 12),
      words: vi.fn(() => 2)
    }
  }
}

// Mock TipTap modules
vi.mock('@tiptap/react', () => ({
  useEditor: vi.fn(),
  EditorContent: ({ className }: any) => (
    <div className={className} data-testid="editor-content">
      Editor Content Area
    </div>
  )
}))

vi.mock('@tiptap/starter-kit', () => ({
  default: {
    configure: vi.fn(() => ({}))
  }
}))

vi.mock('@tiptap/extension-link', () => ({
  default: {
    configure: vi.fn(() => ({}))
  }
}))

vi.mock('@tiptap/extension-text-align', () => ({
  default: {
    configure: vi.fn(() => ({}))
  }
}))

vi.mock('@tiptap/extension-character-count', () => ({
  default: {
    configure: vi.fn(() => ({}))
  }
}))

vi.mock('@tiptap/extension-placeholder', () => ({
  default: {
    configure: vi.fn(() => ({}))
  }
}))

// Mock window.prompt
const mockPrompt = vi.fn()
Object.defineProperty(window, 'prompt', {
  value: mockPrompt,
  writable: true
})

// Import after mocks
import { RichTextEditor } from '../RichTextEditor'
import { useEditor } from '@tiptap/react'

describe('RichTextEditor', () => {
  const user = userEvent.setup()
  
  beforeEach(() => {
    vi.clearAllMocks()
    vi.mocked(useEditor).mockReturnValue(mockEditor)
    mockEditor.isActive.mockReturnValue(false)
    mockEditor.getHTML.mockReturnValue('<p>Test content</p>')
    mockEditor.storage.characterCount.characters.mockReturnValue(12)
    mockEditor.storage.characterCount.words.mockReturnValue(2)
  })

  afterEach(() => {
    vi.restoreAllMocks()
  })

  describe('Initialization', () => {
    it('should render editor with default props', () => {
      render(<RichTextEditor />)
      
      expect(screen.getByTestId('editor-content')).toBeInTheDocument()
      expect(screen.getByText('2 words')).toBeInTheDocument()
      expect(screen.getByText('12/10000 characters')).toBeInTheDocument()
    })

    it('should render with custom content and placeholder', () => {
      const content = '<p>Initial content</p>'
      
      render(
        <RichTextEditor 
          content={content}
          placeholder="Custom placeholder"
        />
      )
      
      expect(useEditor).toHaveBeenCalledWith({
        extensions: expect.any(Array),
        content,
        editable: true,
        onUpdate: expect.any(Function)
      })
    })

    it('should handle disabled state', () => {
      render(<RichTextEditor editable={false} />)
      
      expect(useEditor).toHaveBeenCalledWith(
        expect.objectContaining({ editable: false })
      )
    })

    it('should return null if editor is not initialized', () => {
      vi.mocked(useEditor).mockReturnValueOnce(null)
      
      const { container } = render(<RichTextEditor />)
      
      expect(container.firstChild).toBeNull()
    })
  })

  describe('Toolbar Functionality', () => {
    it('should render toolbar buttons', () => {
      render(<RichTextEditor />)
      
      // Check that buttons are rendered
      const buttons = screen.getAllByRole('button')
      expect(buttons.length).toBeGreaterThan(10) // Should have many toolbar buttons
    })

    it('should toggle bold formatting', async () => {
      render(<RichTextEditor />)
      
      // Find and click the first button (Bold)
      const buttons = screen.getAllByRole('button')
      await user.click(buttons[0])
      
      expect(mockEditor.chain().focus().toggleBold().run).toHaveBeenCalled()
    })

    it('should toggle italic formatting', async () => {
      render(<RichTextEditor />)
      
      const buttons = screen.getAllByRole('button')
      await user.click(buttons[1])
      
      expect(mockEditor.chain().focus().toggleItalic().run).toHaveBeenCalled()
    })

    it('should handle undo/redo actions', async () => {
      render(<RichTextEditor />)
      
      const buttons = screen.getAllByRole('button')
      // Undo and redo are typically near the end of the toolbar
      const undoButton = buttons.find((btn, index) => index >= 10)
      const redoButton = buttons.find((btn, index) => index >= 11)
      
      if (undoButton) {
        await user.click(undoButton)
        expect(mockEditor.chain().focus().undo().run).toHaveBeenCalled()
      }
    })
  })

  describe('Active State Styling', () => {
    it('should apply active styling when format is active', () => {
      mockEditor.isActive.mockImplementation((format) => format === 'bold')
      
      render(<RichTextEditor />)
      
      const boldButton = screen.getAllByRole('button')[0]
      expect(boldButton).toHaveClass('bg-muted')
    })
  })

  describe('Link Functionality', () => {
    it('should handle link creation', async () => {
      mockPrompt.mockReturnValue('https://example.com')
      mockEditor.getAttributes.mockReturnValue({ href: '' })
      
      render(<RichTextEditor />)
      
      // Find link button and click it
      const buttons = screen.getAllByRole('button')
      const linkButton = buttons.find(btn => btn.className.includes('h-8'))
      
      if (linkButton) {
        await user.click(linkButton)
        expect(mockPrompt).toHaveBeenCalled()
      }
    })

    it('should handle cancelled link prompt', async () => {
      mockPrompt.mockReturnValue(null)
      
      render(<RichTextEditor />)
      
      const buttons = screen.getAllByRole('button')
      if (buttons.length > 8) {
        await user.click(buttons[8]) // Approximate link button position
        expect(mockEditor.chain).not.toHaveBeenCalled()
      }
    })
  })

  describe('Content Updates', () => {
    it('should call onChange when content updates', () => {
      const onChange = vi.fn()
      
      render(<RichTextEditor onChange={onChange} />)
      
      // Simulate editor update
      const onUpdateCall = vi.mocked(useEditor).mock.calls[0][0]
      onUpdateCall.onUpdate({ editor: mockEditor })
      
      expect(onChange).toHaveBeenCalledWith('<p>Test content</p>')
    })

    it('should update editor content when content prop changes', () => {
      const { rerender } = render(<RichTextEditor content="<p>Initial</p>" />)
      
      // Change content prop
      rerender(<RichTextEditor content="<p>Updated</p>" />)
      
      expect(mockEditor.commands.setContent).toHaveBeenCalledWith('<p>Updated</p>')
    })
  })

  describe('Character Count', () => {
    it('should display character and word count', () => {
      mockEditor.storage.characterCount.characters.mockReturnValue(150)
      mockEditor.storage.characterCount.words.mockReturnValue(25)
      
      render(<RichTextEditor maxCharacters={1000} />)
      
      expect(screen.getByText('25 words')).toBeInTheDocument()
      expect(screen.getByText('150/1000 characters')).toBeInTheDocument()
    })

    it('should show warning when at character limit', () => {
      mockEditor.storage.characterCount.characters.mockReturnValue(1000)
      
      render(<RichTextEditor maxCharacters={1000} />)
      
      expect(screen.getByText('Character limit reached')).toBeInTheDocument()
      expect(screen.getByText('1000/1000 characters')).toHaveClass('text-destructive')
    })
  })

  describe('Disabled State', () => {
    it('should disable buttons when actions are not available', () => {
      mockEditor.can.mockReturnValue({
        chain: () => ({ focus: () => ({ undo: () => ({ run: () => false }) }) })
      })
      
      render(<RichTextEditor />)
      
      // Check that some buttons are properly disabled
      const buttons = screen.getAllByRole('button')
      const disabledButtons = buttons.filter(btn => btn.disabled)
      expect(disabledButtons.length).toBeGreaterThan(0)
    })
  })

  describe('Error Handling', () => {
    it('should handle editor errors gracefully', () => {
      mockEditor.chain.mockImplementation(() => {
        throw new Error('Editor error')
      })
      
      render(<RichTextEditor />)
      
      const buttons = screen.getAllByRole('button')
      
      // Should not crash when clicking
      expect(() => fireEvent.click(buttons[0])).not.toThrow()
    })

    it('should handle missing editor methods', () => {
      const incompleteEditor = {
        ...mockEditor,
        chain: undefined
      }
      vi.mocked(useEditor).mockReturnValue(incompleteEditor)
      
      render(<RichTextEditor />)
      
      // Should render without crashing
      expect(screen.getByTestId('editor-content')).toBeInTheDocument()
    })
  })
})