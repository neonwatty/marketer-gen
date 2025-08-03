import React, { useState, useEffect, useMemo } from 'react'
import MarkdownIt from 'markdown-it'

interface MarkdownPreviewProps {
  content: string
  onChange?: (content: string) => void
  className?: string
  split?: boolean
  theme?: 'light' | 'dark'
  showToolbar?: boolean
  editable?: boolean
  placeholder?: string
  syncScroll?: boolean
}

export const MarkdownPreview: React.FC<MarkdownPreviewProps> = ({
  content,
  onChange,
  className = '',
  split = true,
  theme = 'light',
  showToolbar = true,
  editable = true,
  placeholder = 'Start writing in Markdown...',
  syncScroll = true
}) => {
  const [markdown, setMarkdown] = useState(content)
  const [activeTab, setActiveTab] = useState<'edit' | 'preview' | 'split'>('split')
  const [editorScrollTop, setEditorScrollTop] = useState(0)
  const [previewScrollTop, setPreviewScrollTop] = useState(0)
  const [isScrollingEditor, setIsScrollingEditor] = useState(false)
  const [isScrollingPreview, setIsScrollingPreview] = useState(false)

  // Initialize markdown parser
  const md = useMemo(() => {
    return new MarkdownIt({
      html: true,
      breaks: true,
      linkify: true,
      typographer: true
    })
  }, [])

  // Parse markdown to HTML
  const htmlContent = useMemo(() => {
    try {
      return md.render(markdown)
    } catch (error) {
      console.error('Markdown parsing error:', error)
      return '<p>Error parsing markdown</p>'
    }
  }, [markdown, md])

  // Update content when prop changes
  useEffect(() => {
    setMarkdown(content)
  }, [content])

  // Notify parent of changes
  useEffect(() => {
    onChange?.(markdown)
  }, [markdown, onChange])

  const handleEditorScroll = (e: React.UIEvent<HTMLTextAreaElement>) => {
    if (!syncScroll || isScrollingPreview) {return}
    
    setIsScrollingEditor(true)
    const scrollTop = e.currentTarget.scrollTop
    const scrollHeight = e.currentTarget.scrollHeight - e.currentTarget.clientHeight
    const scrollPercent = scrollHeight > 0 ? scrollTop / scrollHeight : 0
    
    setEditorScrollTop(scrollTop)
    
    // Sync preview scroll
    const previewElement = document.getElementById('markdown-preview')
    if (previewElement) {
      const previewScrollHeight = previewElement.scrollHeight - previewElement.clientHeight
      previewElement.scrollTop = previewScrollHeight * scrollPercent
    }
    
    setTimeout(() => setIsScrollingEditor(false), 150)
  }

  const handlePreviewScroll = (e: React.UIEvent<HTMLDivElement>) => {
    if (!syncScroll || isScrollingEditor) {return}
    
    setIsScrollingPreview(true)
    const scrollTop = e.currentTarget.scrollTop
    const scrollHeight = e.currentTarget.scrollHeight - e.currentTarget.clientHeight
    const scrollPercent = scrollHeight > 0 ? scrollTop / scrollHeight : 0
    
    setPreviewScrollTop(scrollTop)
    
    // Sync editor scroll
    const editorElement = document.getElementById('markdown-editor')
    if (editorElement) {
      const editorScrollHeight = editorElement.scrollHeight - editorElement.clientHeight
      editorElement.scrollTop = editorScrollHeight * scrollPercent
    }
    
    setTimeout(() => setIsScrollingPreview(false), 150)
  }

  const insertMarkdown = (before: string, after: string = '', placeholder: string = 'text') => {
    const textarea = document.getElementById('markdown-editor') as HTMLTextAreaElement
    if (!textarea) {return}

    const start = textarea.selectionStart
    const end = textarea.selectionEnd
    const selectedText = markdown.substring(start, end)
    const replacement = selectedText || placeholder
    
    const beforeText = markdown.substring(0, start)
    const afterText = markdown.substring(end)
    
    const newText = beforeText + before + replacement + after + afterText
    setMarkdown(newText)
    
    // Restore cursor position
    setTimeout(() => {
      const newCursorPos = start + before.length + replacement.length + after.length
      textarea.setSelectionRange(newCursorPos, newCursorPos)
      textarea.focus()
    }, 0)
  }

  const ToolbarButton: React.FC<{
    onClick: () => void
    title: string
    children: React.ReactNode
    disabled?: boolean
  }> = ({ onClick, title, children, disabled = false }) => (
    <button
      type="button"
      onClick={onClick}
      disabled={disabled}
      title={title}
      className={`p-2 rounded-md transition-colors duration-200 ${
        disabled
          ? 'text-gray-400 cursor-not-allowed'
          : 'text-gray-700 hover:bg-gray-100 hover:text-gray-900'
      }`}
    >
      {children}
    </button>
  )

  const themeClasses = theme === 'dark' 
    ? 'bg-gray-900 text-gray-100' 
    : 'bg-white text-gray-900'

  return (
    <div className={`markdown-preview-container border border-gray-300 rounded-lg ${themeClasses} ${className}`}>
      {/* Toolbar */}
      {showToolbar && (
        <div className="flex items-center justify-between px-4 py-2 border-b border-gray-200">
          <div className="flex items-center space-x-1">
            {/* Format Buttons */}
            <ToolbarButton
              onClick={() => insertMarkdown('**', '**', 'bold text')}
              title="Bold"
            >
              <svg className="w-4 h-4" fill="currentColor" viewBox="0 0 20 20">
                <path fillRule="evenodd" d="M3 4a1 1 0 011-1h6a4.5 4.5 0 013.054 7.759A4.5 4.5 0 0110 19H4a1 1 0 01-1-1V4zm2 1v12h5a2.5 2.5 0 000-5h-1a1 1 0 010-2h1a2.5 2.5 0 000-5H5z" clipRule="evenodd" />
              </svg>
            </ToolbarButton>

            <ToolbarButton
              onClick={() => insertMarkdown('*', '*', 'italic text')}
              title="Italic"
            >
              <svg className="w-4 h-4" fill="currentColor" viewBox="0 0 20 20">
                <path fillRule="evenodd" d="M8 1a1 1 0 011 1v12h3a1 1 0 110 2H6a1 1 0 110-2h3V3H6a1 1 0 010-2h2zm6 3a1 1 0 011-1h2a1 1 0 110 2h-2a1 1 0 01-1-1z" clipRule="evenodd" />
              </svg>
            </ToolbarButton>

            <ToolbarButton
              onClick={() => insertMarkdown('~~', '~~', 'strikethrough text')}
              title="Strikethrough"
            >
              <svg className="w-4 h-4" fill="currentColor" viewBox="0 0 20 20">
                <path fillRule="evenodd" d="M5 10a1 1 0 011-1h8a1 1 0 110 2H6a1 1 0 01-1-1zM3.464 4.464a1 1 0 011.414 0L10 9.586l5.122-5.122a1 1 0 111.414 1.414L11.414 11l5.122 5.122a1 1 0 11-1.414 1.414L10 12.414l-5.122 5.122a1 1 0 11-1.414-1.414L8.586 11 3.464 5.878a1 1 0 010-1.414z" clipRule="evenodd" />
              </svg>
            </ToolbarButton>

            <div className="w-px h-6 bg-gray-300 mx-1" />

            <ToolbarButton
              onClick={() => insertMarkdown('# ', '', 'Heading 1')}
              title="Heading 1"
            >
              H1
            </ToolbarButton>

            <ToolbarButton
              onClick={() => insertMarkdown('## ', '', 'Heading 2')}
              title="Heading 2"
            >
              H2
            </ToolbarButton>

            <ToolbarButton
              onClick={() => insertMarkdown('### ', '', 'Heading 3')}
              title="Heading 3"
            >
              H3
            </ToolbarButton>

            <div className="w-px h-6 bg-gray-300 mx-1" />

            <ToolbarButton
              onClick={() => insertMarkdown('- ', '', 'List item')}
              title="Bullet List"
            >
              <svg className="w-4 h-4" fill="currentColor" viewBox="0 0 20 20">
                <path fillRule="evenodd" d="M3 4a1 1 0 100 2 1 1 0 000-2zM6 4a1 1 0 011-1h9a1 1 0 110 2H7a1 1 0 01-1-1zm0 4a1 1 0 011-1h9a1 1 0 110 2H7a1 1 0 01-1-1zm0 4a1 1 0 011-1h9a1 1 0 110 2H7a1 1 0 01-1-1zm-3-4a1 1 0 100 2 1 1 0 000-2zm0 4a1 1 0 100 2 1 1 0 000-2z" clipRule="evenodd" />
              </svg>
            </ToolbarButton>

            <ToolbarButton
              onClick={() => insertMarkdown('1. ', '', 'List item')}
              title="Numbered List"
            >
              <svg className="w-4 h-4" fill="currentColor" viewBox="0 0 20 20">
                <path fillRule="evenodd" d="M3 3a1 1 0 000 2v8a2 2 0 002 2h2.586l-1.293 1.293a1 1 0 101.414 1.414L10 15.414l2.293 2.293a1 1 0 001.414-1.414L12.414 15H15a2 2 0 002-2V5a1 1 0 100-2H3zm11.707 4.707a1 1 0 00-1.414-1.414L10 9.586 8.707 8.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z" clipRule="evenodd" />
              </svg>
            </ToolbarButton>

            <ToolbarButton
              onClick={() => insertMarkdown('[', '](url)', 'link text')}
              title="Link"
            >
              <svg className="w-4 h-4" fill="currentColor" viewBox="0 0 20 20">
                <path fillRule="evenodd" d="M12.586 4.586a2 2 0 112.828 2.828l-3 3a2 2 0 01-2.828 0 1 1 0 00-1.414 1.414 4 4 0 005.656 0l3-3a4 4 0 00-5.656-5.656l-1.5 1.5a1 1 0 101.414 1.414l1.5-1.5zm-5 5a2 2 0 012.828 0 1 1 0 101.414-1.414 4 4 0 00-5.656 0l-3 3a4 4 0 105.656 5.656l1.5-1.5a1 1 0 10-1.414-1.414l-1.5 1.5a2 2 0 11-2.828-2.828l3-3z" clipRule="evenodd" />
              </svg>
            </ToolbarButton>

            <ToolbarButton
              onClick={() => insertMarkdown('![', '](image-url)', 'alt text')}
              title="Image"
            >
              <svg className="w-4 h-4" fill="currentColor" viewBox="0 0 20 20">
                <path fillRule="evenodd" d="M4 3a2 2 0 00-2 2v10a2 2 0 002 2h12a2 2 0 002-2V5a2 2 0 00-2-2H4zm12 12H4l4-8 3 6 2-4 3 6z" clipRule="evenodd" />
              </svg>
            </ToolbarButton>

            <ToolbarButton
              onClick={() => insertMarkdown('`', '`', 'code')}
              title="Inline Code"
            >
              <svg className="w-4 h-4" fill="currentColor" viewBox="0 0 20 20">
                <path fillRule="evenodd" d="M12.316 3.051a1 1 0 01.633 1.265l-4 12a1 1 0 11-1.898-.632l4-12a1 1 0 011.265-.633zM5.707 6.293a1 1 0 010 1.414L3.414 10l2.293 2.293a1 1 0 11-1.414 1.414l-3-3a1 1 0 010-1.414l3-3a1 1 0 011.414 0zm8.586 0a1 1 0 011.414 0l3 3a1 1 0 010 1.414l-3 3a1 1 0 11-1.414-1.414L16.586 10l-2.293-2.293a1 1 0 010-1.414z" clipRule="evenodd" />
              </svg>
            </ToolbarButton>

            <ToolbarButton
              onClick={() => insertMarkdown('```\n', '\n```', 'code block')}
              title="Code Block"
            >
              <svg className="w-4 h-4" fill="currentColor" viewBox="0 0 20 20">
                <path fillRule="evenodd" d="M3 4a1 1 0 011-1h12a1 1 0 110 2H4a1 1 0 01-1-1zm0 4a1 1 0 011-1h12a1 1 0 110 2H4a1 1 0 01-1-1zm0 4a1 1 0 011-1h12a1 1 0 110 2H4a1 1 0 01-1-1zm0 4a1 1 0 011-1h12a1 1 0 110 2H4a1 1 0 01-1-1z" clipRule="evenodd" />
              </svg>
            </ToolbarButton>
          </div>

          {/* View Mode Tabs */}
          <div className="flex items-center space-x-1 bg-gray-100 p-1 rounded-lg">
            <button
              onClick={() => setActiveTab('edit')}
              className={`px-3 py-1 text-sm font-medium rounded-md transition-colors ${
                activeTab === 'edit'
                  ? 'bg-white text-gray-900 shadow-sm'
                  : 'text-gray-600 hover:text-gray-800'
              }`}
            >
              Edit
            </button>
            <button
              onClick={() => setActiveTab('split')}
              className={`px-3 py-1 text-sm font-medium rounded-md transition-colors ${
                activeTab === 'split'
                  ? 'bg-white text-gray-900 shadow-sm'
                  : 'text-gray-600 hover:text-gray-800'
              }`}
            >
              Split
            </button>
            <button
              onClick={() => setActiveTab('preview')}
              className={`px-3 py-1 text-sm font-medium rounded-md transition-colors ${
                activeTab === 'preview'
                  ? 'bg-white text-gray-900 shadow-sm'
                  : 'text-gray-600 hover:text-gray-800'
              }`}
            >
              Preview
            </button>
          </div>
        </div>
      )}

      {/* Content Area */}
      <div className="flex h-96">
        {/* Editor */}
        {(activeTab === 'edit' || activeTab === 'split') && (
          <div className={`${activeTab === 'split' ? 'w-1/2 border-r border-gray-200' : 'w-full'}`}>
            <textarea
              id="markdown-editor"
              value={markdown}
              onChange={(e) => setMarkdown(e.target.value)}
              onScroll={handleEditorScroll}
              placeholder={placeholder}
              disabled={!editable}
              className={`w-full h-full p-4 resize-none focus:outline-none font-mono text-sm leading-relaxed ${
                theme === 'dark' 
                  ? 'bg-gray-800 text-gray-100 placeholder-gray-400' 
                  : 'bg-white text-gray-900 placeholder-gray-500'
              }`}
              style={{ minHeight: '384px' }}
            />
          </div>
        )}

        {/* Preview */}
        {(activeTab === 'preview' || activeTab === 'split') && (
          <div className={`${activeTab === 'split' ? 'w-1/2' : 'w-full'}`}>
            <div
              id="markdown-preview"
              onScroll={handlePreviewScroll}
              className={`h-full p-4 overflow-y-auto prose prose-sm max-w-none ${
                theme === 'dark' 
                  ? 'prose-invert' 
                  : ''
              }`}
              dangerouslySetInnerHTML={{ __html: htmlContent }}
            />
          </div>
        )}
      </div>

      {/* Status Bar */}
      <div className="flex items-center justify-between px-4 py-2 bg-gray-50 border-t border-gray-200 text-sm text-gray-600">
        <div className="flex items-center space-x-4">
          <span>Lines: {markdown.split('\n').length}</span>
          <span>Words: {markdown.trim().split(/\s+/).filter(word => word.length > 0).length}</span>
          <span>Characters: {markdown.length}</span>
        </div>
        
        <div className="flex items-center space-x-2">
          {syncScroll && activeTab === 'split' && (
            <span className="flex items-center text-xs">
              <svg className="w-3 h-3 mr-1" fill="currentColor" viewBox="0 0 20 20">
                <path fillRule="evenodd" d="M4 2a1 1 0 011 1v2.101a7.002 7.002 0 0111.601 2.566 1 1 0 11-1.885.666A5.002 5.002 0 005.999 7H9a1 1 0 010 2H4a1 1 0 01-1-1V3a1 1 0 011-1zm.008 9.057a1 1 0 011.276.61A5.002 5.002 0 0014.001 13H11a1 1 0 110-2h5a1 1 0 011 1v5a1 1 0 11-2 0v-2.101a7.002 7.002 0 01-11.601-2.566 1 1 0 01.61-1.276z" clipRule="evenodd" />
              </svg>
              Sync scroll
            </span>
          )}
          <span className="text-green-600">Markdown</span>
        </div>
      </div>
    </div>
  )
}

export default MarkdownPreview