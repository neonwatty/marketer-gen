import React, { useState, useEffect, useRef } from 'react'
import EmojiPicker, { EmojiClickData } from 'emoji-picker-react'

interface EmojiPickerProps {
  onSelect: (emoji: string) => void
  onClose: () => void
}

export const EmojiPickerComponent: React.FC<EmojiPickerProps> = ({
  onSelect,
  onClose
}) => {
  const [searchValue, setSearchValue] = useState('')
  const pickerRef = useRef<HTMLDivElement>(null)

  // Close picker when clicking outside
  useEffect(() => {
    const handleClickOutside = (event: MouseEvent) => {
      if (pickerRef.current && !pickerRef.current.contains(event.target as Node)) {
        onClose()
      }
    }

    document.addEventListener('mousedown', handleClickOutside)
    return () => {
      document.removeEventListener('mousedown', handleClickOutside)
    }
  }, [onClose])

  // Close picker on Escape key
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

  const handleEmojiClick = (emojiData: EmojiClickData) => {
    onSelect(emojiData.emoji)
  }

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black bg-opacity-50">
      <div
        ref={pickerRef}
        className="bg-white rounded-lg shadow-xl border border-gray-200 p-4 max-w-md w-full mx-4"
      >
        {/* Header */}
        <div className="flex items-center justify-between mb-4">
          <h3 className="text-lg font-semibold text-gray-900">Select Emoji</h3>
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

        {/* Search Input */}
        <div className="mb-4">
          <div className="relative">
            <div className="absolute inset-y-0 left-0 pl-3 flex items-center pointer-events-none">
              <svg className="h-5 w-5 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z" />
              </svg>
            </div>
            <input
              type="text"
              placeholder="Search emojis..."
              value={searchValue}
              onChange={(e) => setSearchValue(e.target.value)}
              className="block w-full pl-10 pr-3 py-2 border border-gray-300 rounded-md leading-5 bg-white placeholder-gray-500 focus:outline-none focus:placeholder-gray-400 focus:ring-1 focus:ring-blue-500 focus:border-blue-500 sm:text-sm"
            />
          </div>
        </div>

        {/* Emoji Picker */}
        <div className="emoji-picker-container">
          <EmojiPicker
            onEmojiClick={handleEmojiClick}
            searchValue={searchValue}
            width="100%"
            height={350}
            previewConfig={{
              showPreview: false
            }}
            skinTonesDisabled={false}
            searchPlaceHolder="Search emojis..."
            lazyLoadEmojis={true}
          />
        </div>

        {/* Popular Emojis Quick Access */}
        <div className="mt-4 pt-4 border-t border-gray-200">
          <h4 className="text-sm font-medium text-gray-700 mb-2">Frequently Used</h4>
          <div className="grid grid-cols-8 gap-2">
            {[
              '😀', '😃', '😄', '😁', '😆', '😅', '🤣', '😂',
              '🙂', '🙃', '😉', '😊', '😇', '🥰', '😍', '🤩',
              '😘', '😗', '😚', '😙', '😋', '😛', '😜', '🤪',
              '👍', '👎', '👌', '✌️', '🤞', '🤟', '🤘', '🤙',
              '❤️', '🧡', '💛', '💚', '💙', '💜', '🖤', '🤍',
              '💯', '💢', '💥', '💫', '💦', '💨', '🕳️', '💣',
              '💬', '👁️‍🗨️', '🗨️', '🗯️', '💭', '💤', '👋', '🤚'
            ].map((emoji, index) => (
              <button
                key={index}
                onClick={() => onSelect(emoji)}
                className="w-8 h-8 flex items-center justify-center text-lg hover:bg-gray-100 rounded transition-colors"
                title={`Insert ${emoji}`}
              >
                {emoji}
              </button>
            ))}
          </div>
        </div>

        {/* Footer */}
        <div className="mt-4 pt-4 border-t border-gray-200 text-center">
          <p className="text-xs text-gray-500">
            Click an emoji to insert it into your content
          </p>
        </div>
      </div>
    </div>
  )
}

// Wrapper component for better naming
export { EmojiPickerComponent as EmojiPicker }