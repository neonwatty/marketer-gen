'use client'

import React, { useState, useEffect, useRef } from 'react'
import { User } from '@/types'
import { Avatar, AvatarFallback, AvatarImage } from '@/components/ui/avatar'
import { Badge } from '@/components/ui/badge'
import { Command, CommandEmpty, CommandGroup, CommandInput, CommandItem, CommandList } from '@/components/ui/command'
import { Popover, PopoverContent, PopoverTrigger } from '@/components/ui/popover'
import { AtSign, X } from 'lucide-react'

export interface MentionUser {
  id: string
  name: string
  email: string
  avatar?: string
}

export interface CommentMentionsProps {
  users: MentionUser[]
  onMentionSelect: (user: MentionUser) => void
  onMentionRemove: (userId: string) => void
  selectedMentions: string[]
  children: React.ReactNode
  className?: string
}

export interface MentionInputProps {
  value: string
  onChange: (value: string) => void
  onMentionTrigger: (position: number, query: string) => void
  onMentionCancel: () => void
  placeholder?: string
  className?: string
  rows?: number
}

interface MentionSuggestion {
  position: number
  query: string
  users: MentionUser[]
}

export const MentionInput: React.FC<MentionInputProps> = ({
  value,
  onChange,
  onMentionTrigger,
  onMentionCancel,
  placeholder = 'Type @ to mention someone...',
  className = '',
  rows = 3
}) => {
  const textareaRef = useRef<HTMLTextAreaElement>(null)
  const [cursorPosition, setCursorPosition] = useState(0)
  const [mentionTrigger, setMentionTrigger] = useState<{ position: number; query: string } | null>(null)

  const handleChange = (e: React.ChangeEvent<HTMLTextAreaElement>) => {
    const newValue = e.target.value
    const cursorPos = e.target.selectionStart
    
    onChange(newValue)
    setCursorPosition(cursorPos)
    
    // Check for mention trigger
    const textBeforeCursor = newValue.slice(0, cursorPos)
    const mentionMatch = textBeforeCursor.match(/@(\w*)$/)
    
    if (mentionMatch) {
      const mentionStart = cursorPos - mentionMatch[0].length
      const query = mentionMatch[1]
      
      setMentionTrigger({ position: mentionStart, query })
      onMentionTrigger(mentionStart, query)
    } else {
      setMentionTrigger(null)
      onMentionCancel()
    }
  }

  const handleKeyDown = (e: React.KeyboardEvent) => {
    if (e.key === 'Escape' && mentionTrigger) {
      setMentionTrigger(null)
      onMentionCancel()
    }
  }

  const insertMention = (user: MentionUser) => {
    if (!mentionTrigger || !textareaRef.current) return

    const textarea = textareaRef.current
    const beforeMention = value.slice(0, mentionTrigger.position)
    const afterMention = value.slice(cursorPosition)
    const mentionText = `@${user.name} `
    
    const newValue = beforeMention + mentionText + afterMention
    const newCursorPos = mentionTrigger.position + mentionText.length
    
    onChange(newValue)
    setMentionTrigger(null)
    onMentionCancel()
    
    // Set cursor position after the mention
    setTimeout(() => {
      textarea.setSelectionRange(newCursorPos, newCursorPos)
      textarea.focus()
    }, 0)
  }

  useEffect(() => {
    if (textareaRef.current) {
      textareaRef.current.setSelectionRange(cursorPosition, cursorPosition)
    }
  }, [value])

  return (
    <div className="relative">
      <textarea
        ref={textareaRef}
        value={value}
        onChange={handleChange}
        onKeyDown={handleKeyDown}
        placeholder={placeholder}
        className={`w-full rounded-md border border-input bg-background px-3 py-2 text-sm ring-offset-background placeholder:text-muted-foreground focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring focus-visible:ring-offset-2 disabled:cursor-not-allowed disabled:opacity-50 resize-none ${className}`}
        rows={rows}
      />
    </div>
  )
}

export const MentionSuggestions: React.FC<{
  users: MentionUser[]
  onSelect: (user: MentionUser) => void
  onClose: () => void
  query: string
  isOpen: boolean
}> = ({
  users,
  onSelect,
  onClose,
  query,
  isOpen
}) => {
  const filteredUsers = users.filter(user =>
    user.name.toLowerCase().includes(query.toLowerCase()) ||
    user.email.toLowerCase().includes(query.toLowerCase())
  )

  if (!isOpen || filteredUsers.length === 0) {
    return null
  }

  return (
    <div className="absolute z-50 w-full mt-1 bg-popover border rounded-md shadow-md">
      <Command>
        <CommandList>
          <CommandEmpty>No users found.</CommandEmpty>
          <CommandGroup>
            {filteredUsers.slice(0, 5).map((user) => (
              <CommandItem
                key={user.id}
                onSelect={() => onSelect(user)}
                className="flex items-center gap-2 p-2 cursor-pointer"
              >
                <Avatar className="h-6 w-6">
                  <AvatarImage src={user.avatar} />
                  <AvatarFallback className="text-xs">
                    {user.name.split(' ').map(n => n[0]).join('')}
                  </AvatarFallback>
                </Avatar>
                <div className="flex-1 min-w-0">
                  <div className="text-sm font-medium truncate">{user.name}</div>
                  <div className="text-xs text-muted-foreground truncate">{user.email}</div>
                </div>
              </CommandItem>
            ))}
          </CommandGroup>
        </CommandList>
      </Command>
    </div>
  )
}

export const MentionBadges: React.FC<{
  mentions: string[]
  users: MentionUser[]
  onRemove: (userId: string) => void
  className?: string
}> = ({
  mentions,
  users,
  onRemove,
  className = ''
}) => {
  const mentionedUsers = users.filter(user => mentions.includes(user.id))

  if (mentionedUsers.length === 0) {
    return null
  }

  return (
    <div className={`flex flex-wrap gap-1 ${className}`}>
      {mentionedUsers.map((user) => (
        <Badge key={user.id} variant="secondary" className="text-xs px-2 py-1">
          <AtSign className="h-3 w-3 mr-1" />
          {user.name}
          <button
            onClick={() => onRemove(user.id)}
            className="ml-1 hover:text-destructive"
          >
            <X className="h-3 w-3" />
          </button>
        </Badge>
      ))}
    </div>
  )
}

export const CommentMentions: React.FC<CommentMentionsProps> = ({
  users,
  onMentionSelect,
  onMentionRemove,
  selectedMentions,
  children,
  className = ''
}) => {
  return (
    <div className={`space-y-2 ${className}`}>
      {children}
      
      {selectedMentions.length > 0 && (
        <MentionBadges
          mentions={selectedMentions}
          users={users}
          onRemove={onMentionRemove}
        />
      )}
    </div>
  )
}

// Utility function to extract mentions from text
export const extractMentions = (text: string): string[] => {
  const mentionMatches = text.match(/@(\w+)/g) || []
  return mentionMatches.map(match => match.slice(1))
}

// Utility function to replace mentions with clickable links
export const renderMentions = (text: string, users: MentionUser[]): React.ReactNode => {
  const mentionRegex = /@(\w+)/g
  const parts = text.split(mentionRegex)
  
  return parts.map((part, index) => {
    if (index % 2 === 1) {
      // This is a mention
      const user = users.find(u => u.name === part)
      if (user) {
        return (
          <Badge key={index} variant="secondary" className="mx-1">
            <AtSign className="h-3 w-3 mr-1" />
            {user.name}
          </Badge>
        )
      }
      return `@${part}`
    }
    return part
  })
}

export default CommentMentions