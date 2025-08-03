import React, { useState, useEffect, useMemo } from 'react'
import { RichTextEditor } from './RichTextEditor'
import { MarkdownPreview } from './MarkdownPreview'

interface PreviewMode {
  id: string
  name: string
  width: number
  height: number
  icon: string
  className?: string
}

interface ChannelPreset {
  id: string
  name: string
  width: number
  height: number
  maxLength?: number
  format: 'text' | 'html' | 'markdown'
  guidelines?: string[]
  icon: string
}

interface LivePreviewSystemProps {
  content: string
  contentType?: 'rich' | 'markdown' | 'plain'
  onChange?: (content: string) => void
  onSave?: (content: string) => void
  className?: string
  showDevicePreviews?: boolean
  showChannelPreviews?: boolean
  enableDarkMode?: boolean
  brand?: {
    colors: string[]
    fonts: string[]
  }
}

export const LivePreviewSystem: React.FC<LivePreviewSystemProps> = ({
  content,
  contentType = 'rich',
  onChange,
  onSave,
  className = '',
  showDevicePreviews = true,
  showChannelPreviews = true,
  enableDarkMode = true,
  brand
}) => {
  const [currentContent, setCurrentContent] = useState(content)
  const [activeDevicePreview, setActiveDevicePreview] = useState('desktop')
  const [activeChannelPreview, setActiveChannelPreview] = useState('general')
  const [isDarkMode, setIsDarkMode] = useState(false)
  const [isPrintPreview, setIsPrintPreview] = useState(false)
  const [realTimeSync, setRealTimeSync] = useState(true)

  // Device preview modes
  const devicePreviews: PreviewMode[] = [
    {
      id: 'mobile',
      name: 'Mobile',
      width: 375,
      height: 667,
      icon: '📱',
      className: 'border-8 border-gray-800 rounded-3xl'
    },
    {
      id: 'tablet',
      name: 'Tablet',
      width: 768,
      height: 1024,
      icon: '📱',
      className: 'border-4 border-gray-600 rounded-2xl'
    },
    {
      id: 'desktop',
      name: 'Desktop',
      width: 1024,
      height: 768,
      icon: '🖥️',
      className: 'border-2 border-gray-400 rounded-lg'
    },
    {
      id: 'watch',
      name: 'Watch',
      width: 312,
      height: 390,
      icon: '⌚',
      className: 'border-6 border-gray-900 rounded-full'
    }
  ]

  // Channel-specific presets
  const channelPresets: ChannelPreset[] = [
    {
      id: 'instagram-post',
      name: 'Instagram Post',
      width: 400,
      height: 400,
      maxLength: 2200,
      format: 'text',
      guidelines: ['Use hashtags strategically', 'Include emojis for engagement', 'Keep it visual'],
      icon: '📸'
    },
    {
      id: 'instagram-story',
      name: 'Instagram Story',
      width: 375,
      height: 667,
      maxLength: 2200,
      format: 'text',
      guidelines: ['Short and impactful', 'Use stickers and polls', 'Add location tags'],
      icon: '📱'
    },
    {
      id: 'linkedin-post',
      name: 'LinkedIn Post',
      width: 500,
      height: 600,
      maxLength: 3000,
      format: 'text',
      guidelines: ['Professional tone', 'Include industry insights', 'Use relevant hashtags'],
      icon: '💼'
    },
    {
      id: 'twitter-post',
      name: 'Twitter Post',
      width: 500,
      height: 280,
      maxLength: 280,
      format: 'text',
      guidelines: ['Concise and engaging', 'Use trending hashtags', 'Include mentions'],
      icon: '🐦'
    },
    {
      id: 'facebook-post',
      name: 'Facebook Post',
      width: 500,
      height: 400,
      maxLength: 63206,
      format: 'text',
      guidelines: ['Encourage engagement', 'Use compelling visuals', 'Ask questions'],
      icon: '👥'
    },
    {
      id: 'email-subject',
      name: 'Email Subject',
      width: 400,
      height: 60,
      maxLength: 50,
      format: 'text',
      guidelines: ['Clear and compelling', 'Avoid spam words', 'Under 50 characters'],
      icon: '📧'
    },
    {
      id: 'email-preview',
      name: 'Email Preview',
      width: 400,
      height: 100,
      maxLength: 90,
      format: 'text',
      guidelines: ['Complement subject line', 'Create urgency', 'Under 90 characters'],
      icon: '👀'
    },
    {
      id: 'email-body',
      name: 'Email Body',
      width: 600,
      height: 800,
      format: 'html',
      guidelines: ['Mobile-friendly design', 'Clear CTA', 'Scannable content'],
      icon: '📩'
    },
    {
      id: 'general',
      name: 'General Content',
      width: 600,
      height: 400,
      format: 'html',
      guidelines: ['Follow brand guidelines', 'Maintain consistency', 'Optimize for readability'],
      icon: '📝'
    }
  ]

  const activeDevice = devicePreviews.find(d => d.id === activeDevicePreview)
  const activeChannel = channelPresets.find(c => c.id === activeChannelPreview)

  // Update content when prop changes
  useEffect(() => {
    setCurrentContent(content)
  }, [content])

  // Real-time sync
  useEffect(() => {
    if (realTimeSync) {
      onChange?.(currentContent)
    }
  }, [currentContent, realTimeSync, onChange])

  const handleContentChange = (newContent: string) => {
    setCurrentContent(newContent)
  }

  const handleSave = () => {
    onSave?.(currentContent)
  }

  const getPreviewContent = () => {
    if (!activeChannel) {return currentContent}

    switch (activeChannel.format) {
      case 'text':
        // Strip HTML tags for text-only platforms
        const textContent = currentContent.replace(/<[^>]*>/g, '')
        return activeChannel.maxLength 
          ? textContent.slice(0, activeChannel.maxLength)
          : textContent
      case 'markdown':
        return currentContent
      default:
        return currentContent
    }
  }

  const renderChannelSpecificPreview = () => {
    if (!activeChannel) {return null}

    const previewContent = getPreviewContent()
    const remainingChars = activeChannel.maxLength 
      ? activeChannel.maxLength - previewContent.length 
      : null

    return (
      <div className="space-y-4">
        {/* Channel Guidelines */}
        {activeChannel.guidelines && (
          <div className="bg-blue-50 border border-blue-200 rounded-lg p-3">
            <h4 className="text-sm font-medium text-blue-800 mb-2 flex items-center">
              <span className="mr-2">{activeChannel.icon}</span>
              {activeChannel.name} Guidelines
            </h4>
            <ul className="text-sm text-blue-700 space-y-1">
              {activeChannel.guidelines.map((guideline, index) => (
                <li key={index} className="flex items-start">
                  <span className="mr-2">•</span>
                  {guideline}
                </li>
              ))}
            </ul>
          </div>
        )}

        {/* Character Count */}
        {activeChannel.maxLength && (
          <div className="flex items-center justify-between text-sm">
            <span className="text-gray-600">Character count:</span>
            <span className={`font-medium ${
              remainingChars !== null && remainingChars < 0 
                ? 'text-red-600' 
                : remainingChars !== null && remainingChars < 20
                ? 'text-yellow-600'
                : 'text-gray-900'
            }`}>
              {previewContent.length}
              {activeChannel.maxLength && ` / ${activeChannel.maxLength}`}
              {remainingChars !== null && remainingChars < 0 && (
                <span className="text-red-600 ml-1">
                  ({Math.abs(remainingChars)} over)
                </span>
              )}
            </span>
          </div>
        )}

        {/* Preview Content */}
        <div
          className={`preview-content border rounded-lg p-4 overflow-auto ${
            isDarkMode ? 'bg-gray-800 text-white border-gray-600' : 'bg-white text-gray-900 border-gray-300'
          }`}
          style={{
            width: activeChannel.width,
            height: activeChannel.height,
            maxWidth: '100%'
          }}
        >
          {activeChannel.format === 'html' ? (
            <div dangerouslySetInnerHTML={{ __html: previewContent }} />
          ) : (
            <pre className="whitespace-pre-wrap font-sans">{previewContent}</pre>
          )}
        </div>
      </div>
    )
  }

  const renderDevicePreview = () => {
    if (!activeDevice) {return null}

    return (
      <div className="flex flex-col items-center space-y-4">
        <div className="text-center">
          <h4 className="text-sm font-medium text-gray-700 flex items-center justify-center">
            <span className="mr-2">{activeDevice.icon}</span>
            {activeDevice.name} Preview
          </h4>
          <p className="text-xs text-gray-500">
            {activeDevice.width} × {activeDevice.height}px
          </p>
        </div>

        <div
          className={`preview-device overflow-auto ${activeDevice.className} ${
            isDarkMode ? 'bg-gray-800' : 'bg-white'
          }`}
          style={{
            width: Math.min(activeDevice.width, 800),
            height: Math.min(activeDevice.height, 600),
          }}
        >
          <div className="p-4 h-full">
            {contentType === 'rich' ? (
              <div 
                className={`prose prose-sm max-w-none ${isDarkMode ? 'prose-invert' : ''}`}
                dangerouslySetInnerHTML={{ __html: currentContent }} 
              />
            ) : (
              <pre className="whitespace-pre-wrap text-sm">{currentContent}</pre>
            )}
          </div>
        </div>
      </div>
    )
  }

  return (
    <div className={`live-preview-system ${className}`}>
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6 h-full">
        {/* Editor Side */}
        <div className="space-y-4">
          <div className="flex items-center justify-between">
            <h3 className="text-lg font-semibold text-gray-900">Content Editor</h3>
            <div className="flex items-center space-x-2">
              <label className="flex items-center text-sm">
                <input
                  type="checkbox"
                  checked={realTimeSync}
                  onChange={(e) => setRealTimeSync(e.target.checked)}
                  className="mr-1 h-4 w-4 text-blue-600 focus:ring-blue-500 border-gray-300 rounded"
                />
                Real-time sync
              </label>
              {!realTimeSync && (
                <button
                  onClick={handleSave}
                  className="px-3 py-1 bg-blue-600 text-white text-sm rounded hover:bg-blue-700 transition-colors"
                >
                  Update Preview
                </button>
              )}
            </div>
          </div>

          {contentType === 'rich' ? (
            <RichTextEditor
              content={currentContent}
              onChange={handleContentChange}
              onSave={handleSave}
              brand={brand}
              autoSave={realTimeSync}
              onAutoSave={realTimeSync ? handleContentChange : undefined}
              className="h-96"
            />
          ) : contentType === 'markdown' ? (
            <MarkdownPreview
              content={currentContent}
              onChange={handleContentChange}
              className="h-96"
              theme={isDarkMode ? 'dark' : 'light'}
            />
          ) : (
            <textarea
              value={currentContent}
              onChange={(e) => handleContentChange(e.target.value)}
              className="w-full h-96 p-4 border border-gray-300 rounded-lg resize-none focus:outline-none focus:ring-2 focus:ring-blue-500"
              placeholder="Enter your content..."
            />
          )}
        </div>

        {/* Preview Side */}
        <div className="space-y-4">
          <div className="flex items-center justify-between">
            <h3 className="text-lg font-semibold text-gray-900">Live Preview</h3>
            <div className="flex items-center space-x-2">
              {enableDarkMode && (
                <button
                  onClick={() => setIsDarkMode(!isDarkMode)}
                  className={`p-2 rounded-lg transition-colors ${
                    isDarkMode 
                      ? 'bg-gray-800 text-yellow-400 hover:bg-gray-700' 
                      : 'bg-gray-100 text-gray-600 hover:bg-gray-200'
                  }`}
                  title={isDarkMode ? 'Switch to light mode' : 'Switch to dark mode'}
                >
                  {isDarkMode ? '☀️' : '🌙'}
                </button>
              )}
              <button
                onClick={() => setIsPrintPreview(!isPrintPreview)}
                className={`p-2 rounded-lg transition-colors ${
                  isPrintPreview 
                    ? 'bg-blue-100 text-blue-600 hover:bg-blue-200' 
                    : 'bg-gray-100 text-gray-600 hover:bg-gray-200'
                }`}
                title="Print preview"
              >
                🖨️
              </button>
            </div>
          </div>

          {/* Preview Mode Tabs */}
          <div className="border-b border-gray-200">
            <nav className="-mb-px flex space-x-8">
              {showDevicePreviews && (
                <button
                  onClick={() => setActiveChannelPreview('general')}
                  className={`py-2 px-1 border-b-2 font-medium text-sm ${
                    activeChannelPreview === 'general'
                      ? 'border-blue-500 text-blue-600'
                      : 'border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300'
                  }`}
                >
                  Device Preview
                </button>
              )}
              {showChannelPreviews && (
                <button
                  onClick={() => setActiveChannelPreview('instagram-post')}
                  className={`py-2 px-1 border-b-2 font-medium text-sm ${
                    activeChannelPreview !== 'general'
                      ? 'border-blue-500 text-blue-600'
                      : 'border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300'
                  }`}
                >
                  Channel Preview
                </button>
              )}
            </nav>
          </div>

          {/* Device Preview Controls */}
          {showDevicePreviews && activeChannelPreview === 'general' && (
            <div className="flex items-center space-x-2 overflow-x-auto pb-2">
              {devicePreviews.map((device) => (
                <button
                  key={device.id}
                  onClick={() => setActiveDevicePreview(device.id)}
                  className={`flex items-center space-x-2 px-3 py-2 rounded-lg text-sm font-medium whitespace-nowrap transition-colors ${
                    activeDevicePreview === device.id
                      ? 'bg-blue-100 text-blue-700 border border-blue-300'
                      : 'bg-gray-100 text-gray-700 hover:bg-gray-200'
                  }`}
                >
                  <span>{device.icon}</span>
                  <span>{device.name}</span>
                </button>
              ))}
            </div>
          )}

          {/* Channel Preview Controls */}
          {showChannelPreviews && activeChannelPreview !== 'general' && (
            <div className="space-y-2">
              <select
                value={activeChannelPreview}
                onChange={(e) => setActiveChannelPreview(e.target.value)}
                className="block w-full px-3 py-2 border border-gray-300 rounded-md shadow-sm focus:outline-none focus:ring-1 focus:ring-blue-500 focus:border-blue-500 sm:text-sm"
              >
                {channelPresets.map((preset) => (
                  <option key={preset.id} value={preset.id}>
                    {preset.icon} {preset.name}
                  </option>
                ))}
              </select>
            </div>
          )}

          {/* Preview Content */}
          <div className="preview-container border border-gray-300 rounded-lg p-4 bg-gray-50 overflow-auto">
            {isPrintPreview ? (
              <div className="bg-white p-8 shadow-lg max-w-2xl mx-auto print-preview">
                <div 
                  className="prose prose-sm max-w-none"
                  dangerouslySetInnerHTML={{ __html: currentContent }} 
                />
              </div>
            ) : activeChannelPreview === 'general' ? (
              renderDevicePreview()
            ) : (
              renderChannelSpecificPreview()
            )}
          </div>
        </div>
      </div>

      {/* Print Styles */}
      <style jsx>{`
        @media print {
          .print-preview {
            box-shadow: none !important;
            max-width: none !important;
          }
        }
      `}</style>
    </div>
  )
}

export default LivePreviewSystem