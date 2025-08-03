import React, { useState, useEffect, useRef } from 'react'
import { Editor } from '@tiptap/react'

interface LinkModalProps {
  editor: Editor
  onClose: () => void
}

export const LinkModal: React.FC<LinkModalProps> = ({ editor, onClose }) => {
  const [url, setUrl] = useState('')
  const [text, setText] = useState('')
  const [openInNewTab, setOpenInNewTab] = useState(true)
  const [isEditing, setIsEditing] = useState(false)
  const modalRef = useRef<HTMLDivElement>(null)
  const urlInputRef = useRef<HTMLInputElement>(null)

  useEffect(() => {
    // Check if we're editing an existing link
    const selection = editor.state.selection
    const node = editor.state.doc.nodeAt(selection.from)
    
    if (editor.isActive('link')) {
      const linkAttrs = editor.getAttributes('link')
      setUrl(linkAttrs.href || '')
      setOpenInNewTab(linkAttrs.target === '_blank')
      setIsEditing(true)
      
      // Get selected text
      const selectedText = editor.state.doc.textBetween(selection.from, selection.to)
      setText(selectedText)
    } else {
      // Get selected text for new link
      const selectedText = editor.state.doc.textBetween(selection.from, selection.to)
      setText(selectedText)
    }

    // Focus URL input
    setTimeout(() => {
      urlInputRef.current?.focus()
    }, 100)
  }, [editor])

  // Close modal when clicking outside
  useEffect(() => {
    const handleClickOutside = (event: MouseEvent) => {
      if (modalRef.current && !modalRef.current.contains(event.target as Node)) {
        onClose()
      }
    }

    document.addEventListener('mousedown', handleClickOutside)
    return () => {
      document.removeEventListener('mousedown', handleClickOutside)
    }
  }, [onClose])

  // Close modal on Escape key
  useEffect(() => {
    const handleKeyDown = (event: KeyboardEvent) => {
      if (event.key === 'Escape') {
        onClose()
      }
    }

    document.addEventListener('keydown', handleKeyDown)
    return () => {
      document.removeEventListener('keydown', handleKeyDown)
    }
  }, [onClose])

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault()

    if (!url.trim()) {
      return
    }

    let finalUrl = url.trim()
    
    // Add protocol if missing
    if (!finalUrl.startsWith('http://') && !finalUrl.startsWith('https://') && !finalUrl.startsWith('mailto:')) {
      finalUrl = `https://${finalUrl}`
    }

    const linkAttributes = {
      href: finalUrl,
      target: openInNewTab ? '_blank' : '_self',
      rel: openInNewTab ? 'noopener noreferrer' : undefined,
    }

    if (isEditing) {
      // Update existing link
      editor.chain().focus().extendMarkRange('link').setLink(linkAttributes).run()
    } else {
      // Create new link
      if (text.trim() && !editor.state.selection.empty) {
        // Use selected text
        editor.chain().focus().setLink(linkAttributes).run()
      } else if (text.trim()) {
        // Insert new text with link
        editor.chain().focus().insertContent(`<a href="${finalUrl}" target="${linkAttributes.target}" ${linkAttributes.rel ? `rel="${linkAttributes.rel}"` : ''}>${text}</a>`).run()
      } else {
        // Insert URL as both text and link
        editor.chain().focus().insertContent(`<a href="${finalUrl}" target="${linkAttributes.target}" ${linkAttributes.rel ? `rel="${linkAttributes.rel}"` : ''}>${finalUrl}</a>`).run()
      }
    }

    onClose()
  }

  const handleRemoveLink = () => {
    editor.chain().focus().unsetLink().run()
    onClose()
  }

  const validateUrl = (url: string) => {
    try {
      // Allow relative URLs and common protocols
      if (url.startsWith('/') || url.startsWith('#')) {
        return true
      }

      const urlPattern = /^(https?:\/\/)?([\da-z\.-]+)\.([a-z\.]{2,6})([\/\w \.-]*)*\/?$/
      const emailPattern = /^mailto:[^\s@]+@[^\s@]+\.[^\s@]+$/
      
      return urlPattern.test(url) || emailPattern.test(url) || url.includes('.')
    } catch {
      return false
    }
  }

  const isValidUrl = validateUrl(url)

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black bg-opacity-50">
      <div
        ref={modalRef}
        className="bg-white rounded-lg shadow-xl border border-gray-200 p-6 max-w-md w-full mx-4"
      >
        {/* Header */}
        <div className="flex items-center justify-between mb-4">
          <h3 className="text-lg font-semibold text-gray-900">
            {isEditing ? 'Edit Link' : 'Add Link'}
          </h3>
          <button
            onClick={onClose}
            className="text-gray-400 hover:text-gray-600 transition-colors"
            title="Close"
          >
            <svg className="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M6 18L18 6M6 6l12 12" />
            </svg>
          </button>
        </div>

        {/* Form */}
        <form onSubmit={handleSubmit} className="space-y-4">
          {/* URL Input */}
          <div>
            <label htmlFor="url" className="block text-sm font-medium text-gray-700 mb-1">
              URL
            </label>
            <input
              ref={urlInputRef}
              type="text"
              id="url"
              value={url}
              onChange={(e) => setUrl(e.target.value)}
              placeholder="https://example.com or mailto:email@example.com"
              className={`block w-full px-3 py-2 border rounded-md shadow-sm focus:outline-none focus:ring-1 sm:text-sm ${
                url && !isValidUrl
                  ? 'border-red-300 focus:ring-red-500 focus:border-red-500'
                  : 'border-gray-300 focus:ring-blue-500 focus:border-blue-500'
              }`}
              required
            />
            {url && !isValidUrl && (
              <p className="mt-1 text-sm text-red-600">Please enter a valid URL</p>
            )}
          </div>

          {/* Text Input */}
          <div>
            <label htmlFor="text" className="block text-sm font-medium text-gray-700 mb-1">
              Link Text
            </label>
            <input
              type="text"
              id="text"
              value={text}
              onChange={(e) => setText(e.target.value)}
              placeholder="Link text (optional)"
              className="block w-full px-3 py-2 border border-gray-300 rounded-md shadow-sm focus:outline-none focus:ring-1 focus:ring-blue-500 focus:border-blue-500 sm:text-sm"
            />
            <p className="mt-1 text-xs text-gray-500">
              Leave empty to use the URL as link text
            </p>
          </div>

          {/* Options */}
          <div className="flex items-center">
            <input
              type="checkbox"
              id="newTab"
              checked={openInNewTab}
              onChange={(e) => setOpenInNewTab(e.target.checked)}
              className="h-4 w-4 text-blue-600 focus:ring-blue-500 border-gray-300 rounded"
            />
            <label htmlFor="newTab" className="ml-2 block text-sm text-gray-700">
              Open in new tab
            </label>
          </div>

          {/* Buttons */}
          <div className="flex justify-between pt-4">
            <div>
              {isEditing && (
                <button
                  type="button"
                  onClick={handleRemoveLink}
                  className="inline-flex items-center px-3 py-2 border border-red-300 text-sm font-medium rounded-md text-red-700 bg-red-50 hover:bg-red-100 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-red-500 transition-colors"
                >
                  <svg className="w-4 h-4 mr-1" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16" />
                  </svg>
                  Remove Link
                </button>
              )}
            </div>

            <div className="flex space-x-3">
              <button
                type="button"
                onClick={onClose}
                className="inline-flex items-center px-4 py-2 border border-gray-300 text-sm font-medium rounded-md text-gray-700 bg-white hover:bg-gray-50 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500 transition-colors"
              >
                Cancel
              </button>
              <button
                type="submit"
                disabled={!url.trim() || !isValidUrl}
                className="inline-flex items-center px-4 py-2 border border-transparent text-sm font-medium rounded-md text-white bg-blue-600 hover:bg-blue-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500 disabled:opacity-50 disabled:cursor-not-allowed transition-colors"
              >
                <svg className="w-4 h-4 mr-1" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M13.828 10.172a4 4 0 00-5.656 0l-4 4a4 4 0 105.656 5.656l1.102-1.101m-.758-4.899a4 4 0 005.656 0l4-4a4 4 0 00-5.656-5.656l-1.1 1.1" />
                </svg>
                {isEditing ? 'Update Link' : 'Add Link'}
              </button>
            </div>
          </div>
        </form>

        {/* Quick Links */}
        <div className="mt-6 pt-4 border-t border-gray-200">
          <h4 className="text-sm font-medium text-gray-700 mb-2">Quick Links</h4>
          <div className="grid grid-cols-2 gap-2 text-sm">
            <button
              type="button"
              onClick={() => setUrl('mailto:')}
              className="p-2 text-left border border-gray-200 rounded hover:bg-gray-50 transition-colors"
            >
              📧 Email Address
            </button>
            <button
              type="button"
              onClick={() => setUrl('tel:')}
              className="p-2 text-left border border-gray-200 rounded hover:bg-gray-50 transition-colors"
            >
              📞 Phone Number
            </button>
            <button
              type="button"
              onClick={() => setUrl('#')}
              className="p-2 text-left border border-gray-200 rounded hover:bg-gray-50 transition-colors"
            >
              🔗 Page Anchor
            </button>
            <button
              type="button"
              onClick={() => setUrl('/')}
              className="p-2 text-left border border-gray-200 rounded hover:bg-gray-50 transition-colors"
            >
              🏠 Internal Page
            </button>
          </div>
        </div>
      </div>
    </div>
  )
}

export default LinkModal