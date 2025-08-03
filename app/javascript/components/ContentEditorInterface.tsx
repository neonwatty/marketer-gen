import React, { useState, useEffect } from 'react'
import { RichTextEditor } from './RichTextEditor'
import { MarkdownPreview } from './MarkdownPreview'
import { LivePreviewSystem } from './LivePreviewSystem'
import { MediaManager } from './MediaManager'
import { ContentTemplates } from './ContentTemplates'

interface ContentEditorInterfaceProps {
  initialContent?: string
  contentType?: 'rich' | 'markdown' | 'plain'
  onSave?: (content: string, metadata?: any) => Promise<void>
  onAutoSave?: (content: string) => Promise<void>
  autoSaveEnabled?: boolean
  autoSaveDelay?: number
  showTemplates?: boolean
  showMediaManager?: boolean
  showLivePreview?: boolean
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
  onContentChange?: (content: string) => void
  maxLength?: number
  showCharacterCount?: boolean
  showWordCount?: boolean
  editorHeight?: string
  enableAccessibility?: boolean
}

export const ContentEditorInterface: React.FC<ContentEditorInterfaceProps> = ({
  initialContent = '',
  contentType = 'rich',
  onSave,
  onAutoSave,
  autoSaveEnabled = true,
  autoSaveDelay = 2000,
  showTemplates = true,
  showMediaManager = true,
  showLivePreview = true,
  collaborative = false,
  collaborators = [],
  brand,
  className = '',
  onContentChange,
  maxLength,
  showCharacterCount = false,
  showWordCount = true,
  editorHeight = '500px',
  enableAccessibility = true
}) => {
  const [content, setContent] = useState(initialContent)
  const [activeTab, setActiveTab] = useState<'editor' | 'templates' | 'media' | 'preview'>('editor')
  const [saving, setSaving] = useState(false)
  const [lastSaved, setLastSaved] = useState<Date | null>(null)
  const [hasUnsavedChanges, setHasUnsavedChanges] = useState(false)

  // Update content when prop changes
  useEffect(() => {
    setContent(initialContent)
  }, [initialContent])

  // Track unsaved changes
  useEffect(() => {
    setHasUnsavedChanges(content !== initialContent)
  }, [content, initialContent])

  // Notify parent of content changes
  useEffect(() => {
    onContentChange?.(content)
  }, [content, onContentChange])

  const handleContentChange = (newContent: string) => {
    setContent(newContent)
  }

  const handleSave = async () => {
    if (!onSave || saving) {return}

    setSaving(true)
    try {
      await onSave(content)
      setLastSaved(new Date())
      setHasUnsavedChanges(false)
    } catch (error) {
      console.error('Save failed:', error)
      // You might want to show a toast notification here
    } finally {
      setSaving(false)
    }
  }

  const handleAutoSave = async (content: string) => {
    if (!onAutoSave || saving) {return}

    try {
      await onAutoSave(content)
      setLastSaved(new Date())
    } catch (error) {
      console.error('Auto-save failed:', error)
    }
  }

  const handleTemplateSelect = (template: any, variables: Record<string, any>) => {
    let processedContent = template.content
    
    // Replace template variables
    Object.entries(variables).forEach(([key, value]) => {
      const regex = new RegExp(`{{${key}}}`, 'g')
      processedContent = processedContent.replace(regex, String(value))
    })

    setContent(processedContent)
    setActiveTab('editor')
  }

  const handleMediaSelect = (file: any) => {
    // Insert media into content based on content type
    let mediaInsert = ''
    
    if (file.type === 'image') {
      if (contentType === 'markdown') {
        mediaInsert = `![${file.name}](${file.url})`
      } else {
        mediaInsert = `<img src="${file.url}" alt="${file.name}" />`
      }
    } else if (file.type === 'video') {
      if (contentType === 'markdown') {
        mediaInsert = `[${file.name}](${file.url})`
      } else {
        mediaInsert = `<video src="${file.url}" controls></video>`
      }
    } else {
      mediaInsert = `[${file.name}](${file.url})`
    }

    setContent(prev => `${prev  }\n\n${  mediaInsert}`)
    setActiveTab('editor')
  }

  const getCharacterCount = () => {
    return content.length
  }

  const getWordCount = () => {
    return content.trim().split(/\s+/).filter(word => word.length > 0).length
  }

  const isOverLimit = maxLength ? getCharacterCount() > maxLength : false

  const TabButton: React.FC<{
    id: string
    label: string
    icon: React.ReactNode
    active: boolean
    onClick: () => void
    badge?: number
  }> = ({ id: _id, label, icon, active, onClick, badge }) => (
    <button
      onClick={onClick}
      className={`inline-flex items-center px-4 py-2 text-sm font-medium rounded-t-lg border-b-2 transition-colors ${
        active
          ? 'border-blue-500 text-blue-600 bg-blue-50'
          : 'border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300'
      }`}
      aria-selected={active}
      role="tab"
    >
      {icon}
      <span className="ml-2">{label}</span>
      {badge !== undefined && badge > 0 && (
        <span className="ml-2 inline-flex items-center justify-center px-2 py-1 text-xs font-bold leading-none text-white bg-red-600 rounded-full">
          {badge}
        </span>
      )}
    </button>
  )

  return (
    <div className={`content-editor-interface bg-white border border-gray-300 rounded-lg shadow-sm ${className}`}>
      {/* Header with Tabs */}
      <div className="border-b border-gray-200">
        <div className="flex items-center justify-between px-6 py-4">
          <div className="flex items-center space-x-1" role="tablist">
            <TabButton
              id="editor"
              label="Editor"
              icon={
                <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M11 5H6a2 2 0 00-2 2v11a2 2 0 002 2h11a2 2 0 002-2v-5m-1.414-9.414a2 2 0 112.828 2.828L11.828 15H9v-2.828l8.586-8.586z" />
                </svg>
              }
              active={activeTab === 'editor'}
              onClick={() => setActiveTab('editor')}
            />

            {showTemplates && (
              <TabButton
                id="templates"
                label="Templates"
                icon={
                  <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z" />
                  </svg>
                }
                active={activeTab === 'templates'}
                onClick={() => setActiveTab('templates')}
              />
            )}

            {showMediaManager && (
              <TabButton
                id="media"
                label="Media"
                icon={
                  <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M4 16l4.586-4.586a2 2 0 012.828 0L16 16m-2-2l1.586-1.586a2 2 0 012.828 0L20 14m-6-6h.01M6 20h12a2 2 0 002-2V6a2 2 0 00-2-2H6a2 2 0 00-2 2v12a2 2 0 002 2z" />
                  </svg>
                }
                active={activeTab === 'media'}
                onClick={() => setActiveTab('media')}
              />
            )}

            {showLivePreview && (
              <TabButton
                id="preview"
                label="Preview"
                icon={
                  <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M15 12a3 3 0 11-6 0 3 3 0 016 0z" />
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M2.458 12C3.732 7.943 7.523 5 12 5c4.478 0 8.268 2.943 9.542 7-1.274 4.057-5.064 7-9.542 7-4.477 0-8.268-2.943-9.542-7z" />
                  </svg>
                }
                active={activeTab === 'preview'}
                onClick={() => setActiveTab('preview')}
              />
            )}
          </div>

          {/* Actions */}
          <div className="flex items-center space-x-3">
            {/* Save Status */}
            <div className="flex items-center space-x-2 text-sm">
              {saving ? (
                <div className="flex items-center text-blue-600">
                  <div className="animate-spin rounded-full h-3 w-3 border-b-2 border-blue-600 mr-2" />
                  Saving...
                </div>
              ) : hasUnsavedChanges ? (
                <span className="text-orange-600">Unsaved changes</span>
              ) : lastSaved ? (
                <span className="text-green-600">
                  Saved {lastSaved.toLocaleTimeString()}
                </span>
              ) : null}
            </div>

            {/* Save Button */}
            {onSave && (
              <button
                onClick={handleSave}
                disabled={saving || !hasUnsavedChanges}
                className={`inline-flex items-center px-4 py-2 border border-transparent text-sm font-medium rounded-md transition-colors ${
                  saving || !hasUnsavedChanges
                    ? 'text-gray-400 bg-gray-100 cursor-not-allowed'
                    : 'text-white bg-blue-600 hover:bg-blue-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500'
                }`}
              >
                {saving ? (
                  <>
                    <div className="animate-spin rounded-full h-4 w-4 border-b-2 border-white mr-2" />
                    Saving...
                  </>
                ) : (
                  <>
                    <svg className="w-4 h-4 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M8 7H5a2 2 0 00-2 2v9a2 2 0 002 2h14a2 2 0 002-2V9a2 2 0 00-2-2h-3m-1 4l-3-3m0 0l-3 3m3-3v12" />
                    </svg>
                    Save
                  </>
                )}
              </button>
            )}
          </div>
        </div>
      </div>

      {/* Content Area */}
      <div className="min-h-96" role="tabpanel">
        {activeTab === 'editor' && (
          <div className="p-6">
            {contentType === 'rich' ? (
              <RichTextEditor
                content={content}
                onChange={handleContentChange}
                onSave={onSave ? handleSave : undefined}
                collaborative={collaborative}
                collaborators={collaborators}
                brand={brand}
                autoSave={autoSaveEnabled}
                autoSaveDelay={autoSaveDelay}
                onAutoSave={autoSaveEnabled ? handleAutoSave : undefined}
                showWordCount={showWordCount}
                showCharacterCount={showCharacterCount}
                maxLength={maxLength}
                minHeight={editorHeight}
                className="w-full"
              />
            ) : contentType === 'markdown' ? (
              <MarkdownPreview
                content={content}
                onChange={handleContentChange}
                className="w-full"
                syncScroll={true}
              />
            ) : (
              <div className="space-y-4">
                <textarea
                  value={content}
                  onChange={(e) => handleContentChange(e.target.value)}
                  className={`w-full p-4 border border-gray-300 rounded-lg resize-none focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-blue-500 ${
                    isOverLimit ? 'border-red-300 focus:ring-red-500 focus:border-red-500' : ''
                  }`}
                  style={{ height: editorHeight }}
                  placeholder="Start writing your content..."
                  aria-label="Content editor"
                />
                
                {/* Character/Word Count */}
                <div className="flex items-center justify-between text-sm text-gray-600">
                  <div className="flex items-center space-x-4">
                    {showWordCount && <span>Words: {getWordCount()}</span>}
                    {showCharacterCount && (
                      <span className={isOverLimit ? 'text-red-600' : ''}>
                        Characters: {getCharacterCount()}
                        {maxLength && ` / ${maxLength}`}
                      </span>
                    )}
                  </div>
                  
                  {autoSaveEnabled && lastSaved && (
                    <span className="text-green-600">
                      Auto-saved {lastSaved.toLocaleTimeString()}
                    </span>
                  )}
                </div>
              </div>
            )}
          </div>
        )}

        {activeTab === 'templates' && showTemplates && (
          <div className="p-6">
            <ContentTemplates
              onSelectTemplate={handleTemplateSelect}
              showFavorites={true}
              brandColors={brand?.colors}
              className="w-full"
            />
          </div>
        )}

        {activeTab === 'media' && showMediaManager && (
          <div className="p-6">
            <MediaManager
              onSelect={handleMediaSelect}
              allowedTypes={['image', 'video', 'document']}
              multiple={false}
              showBrandAssets={true}
              enableCropping={true}
              enableBatchUpload={true}
              className="w-full"
            />
          </div>
        )}

        {activeTab === 'preview' && showLivePreview && (
          <div className="p-6">
            <LivePreviewSystem
              content={content}
              contentType={contentType}
              onChange={handleContentChange}
              onSave={onSave ? handleSave : undefined}
              showDevicePreviews={true}
              showChannelPreviews={true}
              enableDarkMode={true}
              brand={brand}
              className="w-full"
            />
          </div>
        )}
      </div>

      {/* Accessibility Features */}
      {enableAccessibility && (
        <>
          {/* Screen Reader Status */}
          <div className="sr-only" aria-live="polite" aria-atomic="true">
            {saving && 'Saving content...'}
            {hasUnsavedChanges && !saving && 'Content has unsaved changes'}
            {!hasUnsavedChanges && lastSaved && 'Content saved successfully'}
          </div>

          {/* Keyboard Shortcuts Help */}
          <div className="sr-only">
            <h3>Keyboard Shortcuts:</h3>
            <ul>
              <li>Ctrl+S or Cmd+S: Save content</li>
              <li>Ctrl+1-4 or Cmd+1-4: Switch between tabs</li>
              <li>Tab: Navigate between form elements</li>
              <li>Escape: Close modals or return to main editor</li>
            </ul>
          </div>
        </>
      )}

      {/* Keyboard Shortcuts */}
      <div className="hidden">
        <button
          onClick={() => setActiveTab('editor')}
          accessKey="1"
          aria-label="Switch to editor tab (Alt+1)"
        />
        <button
          onClick={() => setActiveTab('templates')}
          accessKey="2"
          aria-label="Switch to templates tab (Alt+2)"
        />
        <button
          onClick={() => setActiveTab('media')}
          accessKey="3"
          aria-label="Switch to media tab (Alt+3)"
        />
        <button
          onClick={() => setActiveTab('preview')}
          accessKey="4"
          aria-label="Switch to preview tab (Alt+4)"
        />
      </div>
    </div>
  )
}

export default ContentEditorInterface