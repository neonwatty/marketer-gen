import React, { useCallback, useState, useMemo, useEffect } from 'react'
import { useEditor, EditorContent, BubbleMenu, FloatingMenu } from '@tiptap/react'
import StarterKit from '@tiptap/starter-kit'
import Link from '@tiptap/extension-link'
import Image from '@tiptap/extension-image'
import Table from '@tiptap/extension-table'
import TableRow from '@tiptap/extension-table-row'
import TableCell from '@tiptap/extension-table-cell'
import TableHeader from '@tiptap/extension-table-header'
import Highlight from '@tiptap/extension-highlight'
import TextAlign from '@tiptap/extension-text-align'
import Color from '@tiptap/extension-color'
import TaskList from '@tiptap/extension-task-list'
import TaskItem from '@tiptap/extension-task-item'
import CodeBlock from '@tiptap/extension-code-block'
import Typography from '@tiptap/extension-typography'
import Placeholder from '@tiptap/extension-placeholder'
import { Toolbar } from './RichTextEditor/Toolbar'
import { EmojiPicker } from './RichTextEditor/EmojiPicker'
import { LinkModal } from './RichTextEditor/LinkModal'
import { ImageUploadModal } from './RichTextEditor/ImageUploadModal'
import { TableModal } from './RichTextEditor/TableModal'
import { CollaborationIndicator } from './RichTextEditor/CollaborationIndicator'

interface RichTextEditorProps {
  content?: string
  onChange?: (content: string) => void
  onSave?: (content: string) => void
  placeholder?: string
  editable?: boolean
  showWordCount?: boolean
  showCharacterCount?: boolean
  maxLength?: number
  minHeight?: string
  maxHeight?: string
  collaborative?: boolean
  collaborators?: Array<{
    id: string
    name: string
    avatar?: string
    color: string
  }>
  brand?: {
    colors: string[]
    fonts: string[]
  }
  className?: string
  autoSave?: boolean
  autoSaveDelay?: number
  onAutoSave?: (content: string) => void
}

export const RichTextEditor: React.FC<RichTextEditorProps> = ({
  content = '',
  onChange,
  onSave,
  placeholder = 'Start writing...',
  editable = true,
  showWordCount = true,
  showCharacterCount = false,
  maxLength,
  minHeight = '300px',
  maxHeight = '600px',
  collaborative = false,
  collaborators = [],
  brand,
  className = '',
  autoSave = false,
  autoSaveDelay = 2000,
  onAutoSave
}) => {
  const [showEmojiPicker, setShowEmojiPicker] = useState(false)
  const [showLinkModal, setShowLinkModal] = useState(false)
  const [showImageModal, setShowImageModal] = useState(false)
  const [showTableModal, setShowTableModal] = useState(false)
  const [lastSaved, setLastSaved] = useState<Date | null>(null)
  const [saving, setSaving] = useState(false)

  // Auto-save timeout
  const [autoSaveTimeout, setAutoSaveTimeout] = useState<NodeJS.Timeout | null>(null)

  const extensions = useMemo(() => [
    StarterKit.configure({
      bulletList: {
        keepMarks: true,
        keepAttributes: false,
      },
      orderedList: {
        keepMarks: true,
        keepAttributes: false,
      },
    }),
    Link.configure({
      openOnClick: false,
      HTMLAttributes: {
        class: 'text-blue-600 hover:text-blue-800 underline cursor-pointer',
      },
    }),
    Image.configure({
      HTMLAttributes: {
        class: 'max-w-full h-auto rounded-lg shadow-sm',
      },
    }),
    Table.configure({
      resizable: true,
    }),
    TableRow,
    TableHeader,
    TableCell,
    Highlight.configure({
      multicolor: true,
    }),
    TextAlign.configure({
      types: ['heading', 'paragraph'],
    }),
    Color.configure({
      types: ['textStyle'],
    }),
    TaskList,
    TaskItem.configure({
      nested: true,
    }),
    CodeBlock.configure({
      HTMLAttributes: {
        class: 'bg-gray-100 rounded-lg p-4 font-mono text-sm border',
      },
    }),
    Typography,
    Placeholder.configure({
      placeholder,
    }),
  ], [placeholder])

  const editor = useEditor({
    extensions,
    content,
    editable,
    onUpdate: ({ editor }) => {
      const newContent = editor.getHTML()
      onChange?.(newContent)

      // Auto-save functionality
      if (autoSave && onAutoSave) {
        if (autoSaveTimeout) {
          clearTimeout(autoSaveTimeout)
        }
        
        const timeout = setTimeout(async () => {
          setSaving(true)
          try {
            await onAutoSave(newContent)
            setLastSaved(new Date())
          } catch (error) {
            console.error('Auto-save failed:', error)
          } finally {
            setSaving(false)
          }
        }, autoSaveDelay)

        setAutoSaveTimeout(timeout)
      }
    },
    onSelectionUpdate: ({ editor }) => {
      // Handle selection updates for collaboration
      if (collaborative) {
        // This would be handled by the collaboration extension
      }
    },
  })

  // Clean up auto-save timeout on unmount
  useEffect(() => {
    return () => {
      if (autoSaveTimeout) {
        clearTimeout(autoSaveTimeout)
      }
    }
  }, [autoSaveTimeout])

  const handleEmojiSelect = useCallback((emoji: string) => {
    editor?.chain().focus().insertContent(emoji).run()
    setShowEmojiPicker(false)
  }, [editor])

  const handleSave = useCallback(() => {
    if (editor && onSave) {
      const content = editor.getHTML()
      onSave(content)
      setLastSaved(new Date())
    }
  }, [editor, onSave])

  const getWordCount = useCallback(() => {
    if (!editor) {return 0}
    const text = editor.getText()
    return text.trim().split(/\s+/).filter(word => word.length > 0).length
  }, [editor])

  const getCharacterCount = useCallback(() => {
    if (!editor) {return 0}
    return editor.getText().length
  }, [editor])

  if (!editor) {
    return (
      <div className="flex items-center justify-center p-8">
        <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-blue-600" />
        <span className="ml-3 text-gray-600">Loading editor...</span>
      </div>
    )
  }

  return (
    <div className={`rich-text-editor bg-white border border-gray-300 rounded-lg shadow-sm ${className}`}>
      {/* Collaboration Indicators */}
      {collaborative && collaborators.length > 0 && (
        <CollaborationIndicator collaborators={collaborators} />
      )}

      {/* Toolbar */}
      <Toolbar
        editor={editor}
        onEmojiClick={() => setShowEmojiPicker(!showEmojiPicker)}
        onLinkClick={() => setShowLinkModal(true)}
        onImageClick={() => setShowImageModal(true)}
        onTableClick={() => setShowTableModal(true)}
        onSave={onSave ? handleSave : undefined}
        brandColors={brand?.colors}
      />

      {/* Editor Content */}
      <div className="relative">
        <EditorContent
          editor={editor}
          className="prose prose-sm sm:prose lg:prose-lg xl:prose-xl max-w-none p-4 focus:outline-none"
          style={{
            minHeight,
            maxHeight,
            overflowY: 'auto'
          }}
        />

        {/* Bubble Menu for text selection */}
        {editor && (
          <BubbleMenu 
            editor={editor} 
            tippyOptions={{ duration: 100 }}
            className="bg-gray-900 text-white rounded-lg shadow-lg p-2 flex items-center space-x-1"
          >
            <button
              onClick={() => editor.chain().focus().toggleBold().run()}
              className={`p-2 rounded hover:bg-gray-700 ${
                editor.isActive('bold') ? 'bg-gray-700' : ''
              }`}
              title="Bold"
            >
              <svg className="w-4 h-4" fill="currentColor" viewBox="0 0 20 20">
                <path fillRule="evenodd" d="M3 4a1 1 0 011-1h6a4.5 4.5 0 013.054 7.759A4.5 4.5 0 0110 19H4a1 1 0 01-1-1V4zm2 1v12h5a2.5 2.5 0 000-5h-1a1 1 0 010-2h1a2.5 2.5 0 000-5H5z" clipRule="evenodd" />
              </svg>
            </button>
            <button
              onClick={() => editor.chain().focus().toggleItalic().run()}
              className={`p-2 rounded hover:bg-gray-700 ${
                editor.isActive('italic') ? 'bg-gray-700' : ''
              }`}
              title="Italic"
            >
              <svg className="w-4 h-4" fill="currentColor" viewBox="0 0 20 20">
                <path fillRule="evenodd" d="M8 1a1 1 0 011 1v12h3a1 1 0 110 2H6a1 1 0 110-2h3V3H6a1 1 0 010-2h2zm6 3a1 1 0 011-1h2a1 1 0 110 2h-2a1 1 0 01-1-1z" clipRule="evenodd" />
              </svg>
            </button>
            <button
              onClick={() => editor.chain().focus().toggleUnderline().run()}
              className={`p-2 rounded hover:bg-gray-700 ${
                editor.isActive('underline') ? 'bg-gray-700' : ''
              }`}
              title="Underline"
            >
              <svg className="w-4 h-4" fill="currentColor" viewBox="0 0 20 20">
                <path d="M4 15a1 1 0 011-1h10a1 1 0 110 2H5a1 1 0 01-1-1zM6 3a1 1 0 011-1h6a1 1 0 110 2v5a3 3 0 11-6 0V4a1 1 0 01-1-1z" />
              </svg>
            </button>
            <button
              onClick={() => setShowLinkModal(true)}
              className="p-2 rounded hover:bg-gray-700"
              title="Add Link"
            >
              <svg className="w-4 h-4" fill="currentColor" viewBox="0 0 20 20">
                <path fillRule="evenodd" d="M12.586 4.586a2 2 0 112.828 2.828l-3 3a2 2 0 01-2.828 0 1 1 0 00-1.414 1.414 4 4 0 005.656 0l3-3a4 4 0 00-5.656-5.656l-1.5 1.5a1 1 0 101.414 1.414l1.5-1.5zm-5 5a2 2 0 012.828 0 1 1 0 101.414-1.414 4 4 0 00-5.656 0l-3 3a4 4 0 105.656 5.656l1.5-1.5a1 1 0 10-1.414-1.414l-1.5 1.5a2 2 0 11-2.828-2.828l3-3z" clipRule="evenodd" />
              </svg>
            </button>
          </BubbleMenu>
        )}

        {/* Floating Menu for empty lines */}
        {editor && (
          <FloatingMenu 
            editor={editor} 
            tippyOptions={{ duration: 100 }}
            className="bg-white border border-gray-300 rounded-lg shadow-lg p-2 flex items-center space-x-1"
          >
            <button
              onClick={() => editor.chain().focus().toggleHeading({ level: 1 }).run()}
              className="p-2 rounded hover:bg-gray-100"
              title="Heading 1"
            >
              H1
            </button>
            <button
              onClick={() => editor.chain().focus().toggleHeading({ level: 2 }).run()}
              className="p-2 rounded hover:bg-gray-100"
              title="Heading 2"
            >
              H2
            </button>
            <button
              onClick={() => editor.chain().focus().toggleBulletList().run()}
              className="p-2 rounded hover:bg-gray-100"
              title="Bullet List"
            >
              <svg className="w-4 h-4" fill="currentColor" viewBox="0 0 20 20">
                <path fillRule="evenodd" d="M3 4a1 1 0 011-1h12a1 1 0 110 2H4a1 1 0 01-1-1zm0 4a1 1 0 011-1h12a1 1 0 110 2H4a1 1 0 01-1-1zm0 4a1 1 0 011-1h12a1 1 0 110 2H4a1 1 0 01-1-1z" clipRule="evenodd" />
              </svg>
            </button>
            <button
              onClick={() => setShowImageModal(true)}
              className="p-2 rounded hover:bg-gray-100"
              title="Insert Image"
            >
              <svg className="w-4 h-4" fill="currentColor" viewBox="0 0 20 20">
                <path fillRule="evenodd" d="M4 3a2 2 0 00-2 2v10a2 2 0 002 2h12a2 2 0 002-2V5a2 2 0 00-2-2H4zm12 12H4l4-8 3 6 2-4 3 6z" clipRule="evenodd" />
              </svg>
            </button>
          </FloatingMenu>
        )}
      </div>

      {/* Status Bar */}
      <div className="flex items-center justify-between px-4 py-2 bg-gray-50 border-t border-gray-200 rounded-b-lg text-sm text-gray-600">
        <div className="flex items-center space-x-4">
          {showWordCount && (
            <span>Words: {getWordCount()}</span>
          )}
          {showCharacterCount && (
            <span>Characters: {getCharacterCount()}</span>
          )}
          {maxLength && (
            <span className={getCharacterCount() > maxLength ? 'text-red-600' : ''}>
              {getCharacterCount()}/{maxLength}
            </span>
          )}
        </div>

        <div className="flex items-center space-x-4">
          {autoSave && (
            <div className="flex items-center space-x-2">
              {saving ? (
                <>
                  <div className="animate-spin rounded-full h-3 w-3 border-b-2 border-blue-600" />
                  <span>Saving...</span>
                </>
              ) : lastSaved ? (
                <span className="text-green-600">
                  Saved {lastSaved.toLocaleTimeString()}
                </span>
              ) : null}
            </div>
          )}
        </div>
      </div>

      {/* Modals */}
      {showEmojiPicker && (
        <EmojiPicker
          onSelect={handleEmojiSelect}
          onClose={() => setShowEmojiPicker(false)}
        />
      )}

      {showLinkModal && (
        <LinkModal
          editor={editor}
          onClose={() => setShowLinkModal(false)}
        />
      )}

      {showImageModal && (
        <ImageUploadModal
          editor={editor}
          onClose={() => setShowImageModal(false)}
        />
      )}

      {showTableModal && (
        <TableModal
          editor={editor}
          onClose={() => setShowTableModal(false)}
        />
      )}
    </div>
  )
}

export default RichTextEditor