import { useState, useEffect, useCallback, useRef } from 'react'
import { useWebSocket } from './useWebSocket'

export interface CursorPosition {
  userId: string
  username: string
  x: number
  y: number
  color: string
  timestamp: Date
}

export interface DocumentChange {
  id: string
  type: 'insert' | 'delete' | 'replace' | 'format'
  position: number
  content?: string
  length?: number
  attributes?: Record<string, any>
  userId: string
  username: string
  timestamp: Date
}

export interface DocumentState {
  content: string
  version: number
  changes: DocumentChange[]
  cursors: Record<string, CursorPosition>
  selections: Record<string, { start: number; end: number; userId: string }>
}

export interface UseCollaborativeEditingOptions {
  documentId: string
  roomId: string
  debounceMs?: number
  maxHistorySize?: number
  enableCursors?: boolean
  enableSelections?: boolean
}

export function useCollaborativeEditing(options: UseCollaborativeEditingOptions) {
  const {
    documentId,
    roomId,
    debounceMs = 300,
    maxHistorySize = 1000,
    enableCursors = true,
    enableSelections = true
  } = options

  const { isConnected, isAuthenticated, on, off, emit } = useWebSocket()

  const [documentState, setDocumentState] = useState<DocumentState>({
    content: '',
    version: 0,
    changes: [],
    cursors: {},
    selections: {}
  })

  const [isEditing, setIsEditing] = useState(false)
  const [conflictResolution, setConflictResolution] = useState<'manual' | 'auto'>('auto')
  
  // Refs for managing state
  const pendingChangesRef = useRef<DocumentChange[]>([])
  const debounceTimerRef = useRef<NodeJS.Timeout | null>(null)
  const lastSyncVersionRef = useRef(0)
  const editorRef = useRef<HTMLElement | null>(null)

  // Document change handlers
  const handleDocumentUpdate = useCallback((data: {
    documentId: string
    changes: DocumentChange[]
    version: number
    userId: string
    username: string
    timestamp: Date
  }) => {
    if (data.documentId !== documentId) return

    setDocumentState(prev => {
      // Apply operational transformation if needed
      const transformedChanges = transformChanges(data.changes, pendingChangesRef.current)
      
      let newContent = prev.content
      let newVersion = Math.max(prev.version, data.version)

      // Apply changes to content
      transformedChanges.forEach(change => {
        newContent = applyChange(newContent, change)
      })

      // Update change history
      const newChanges = [...prev.changes, ...transformedChanges]
      if (newChanges.length > maxHistorySize) {
        newChanges.splice(0, newChanges.length - maxHistorySize)
      }

      return {
        ...prev,
        content: newContent,
        version: newVersion,
        changes: newChanges
      }
    })

    lastSyncVersionRef.current = data.version
  }, [documentId, maxHistorySize])

  // Cursor tracking
  const handleCursorMove = useCallback((data: CursorPosition) => {
    if (!enableCursors) return

    setDocumentState(prev => ({
      ...prev,
      cursors: {
        ...prev.cursors,
        [data.userId]: data
      }
    }))

    // Remove cursor after 10 seconds of inactivity
    setTimeout(() => {
      setDocumentState(prev => {
        const newCursors = { ...prev.cursors }
        if (newCursors[data.userId]?.timestamp === data.timestamp) {
          delete newCursors[data.userId]
        }
        return { ...prev, cursors: newCursors }
      })
    }, 10000)
  }, [enableCursors])

  // Selection tracking
  const handleSelectionChange = useCallback((data: {
    userId: string
    username: string
    start: number
    end: number
    documentId: string
  }) => {
    if (!enableSelections || data.documentId !== documentId) return

    setDocumentState(prev => ({
      ...prev,
      selections: {
        ...prev.selections,
        [data.userId]: {
          start: data.start,
          end: data.end,
          userId: data.userId
        }
      }
    }))
  }, [enableSelections, documentId])

  // Document editing functions
  const insertText = useCallback((position: number, text: string, attributes?: Record<string, any>) => {
    if (!isAuthenticated) return

    const change: DocumentChange = {
      id: `change_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`,
      type: 'insert',
      position,
      content: text,
      attributes,
      userId: 'current-user', // Would be from auth context
      username: 'Current User', // Would be from auth context
      timestamp: new Date()
    }

    // Apply change locally first for responsiveness
    setDocumentState(prev => ({
      ...prev,
      content: applyChange(prev.content, change),
      version: prev.version + 1,
      changes: [...prev.changes, change].slice(-maxHistorySize)
    }))

    // Queue for sending to server
    pendingChangesRef.current.push(change)
    debouncedSendChanges()
  }, [isAuthenticated, maxHistorySize])

  const deleteText = useCallback((position: number, length: number) => {
    if (!isAuthenticated) return

    const change: DocumentChange = {
      id: `change_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`,
      type: 'delete',
      position,
      length,
      userId: 'current-user', // Would be from auth context
      username: 'Current User', // Would be from auth context
      timestamp: new Date()
    }

    // Apply change locally first
    setDocumentState(prev => ({
      ...prev,
      content: applyChange(prev.content, change),
      version: prev.version + 1,
      changes: [...prev.changes, change].slice(-maxHistorySize)
    }))

    // Queue for sending to server
    pendingChangesRef.current.push(change)
    debouncedSendChanges()
  }, [isAuthenticated, maxHistorySize])

  const replaceText = useCallback((position: number, length: number, newText: string, attributes?: Record<string, any>) => {
    if (!isAuthenticated) return

    const change: DocumentChange = {
      id: `change_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`,
      type: 'replace',
      position,
      length,
      content: newText,
      attributes,
      userId: 'current-user', // Would be from auth context
      username: 'Current User', // Would be from auth context
      timestamp: new Date()
    }

    // Apply change locally first
    setDocumentState(prev => ({
      ...prev,
      content: applyChange(prev.content, change),
      version: prev.version + 1,
      changes: [...prev.changes, change].slice(-maxHistorySize)
    }))

    // Queue for sending to server
    pendingChangesRef.current.push(change)
    debouncedSendChanges()
  }, [isAuthenticated, maxHistorySize])

  // Debounced change sending
  const debouncedSendChanges = useCallback(() => {
    if (debounceTimerRef.current) {
      clearTimeout(debounceTimerRef.current)
    }

    debounceTimerRef.current = setTimeout(() => {
      if (pendingChangesRef.current.length > 0) {
        const changesToSend = [...pendingChangesRef.current]
        pendingChangesRef.current = []

        emit('document_change', {
          roomId,
          documentId,
          changes: changesToSend,
          version: documentState.version
        })
      }
    }, debounceMs)
  }, [emit, roomId, documentId, documentState.version, debounceMs])

  // Cursor position tracking
  const updateCursorPosition = useCallback((x: number, y: number) => {
    if (!enableCursors || !isAuthenticated) return

    emit('cursor_move', { roomId, x, y })
  }, [enableCursors, isAuthenticated, emit, roomId])

  // Selection tracking
  const updateSelection = useCallback((start: number, end: number) => {
    if (!enableSelections || !isAuthenticated) return

    emit('selection_change', {
      roomId,
      documentId,
      start,
      end
    })
  }, [enableSelections, isAuthenticated, emit, roomId, documentId])

  // Document synchronization
  const syncDocument = useCallback(() => {
    if (!isAuthenticated) return

    emit('sync_document', {
      roomId,
      documentId,
      version: documentState.version
    })
  }, [isAuthenticated, emit, roomId, documentId, documentState.version])

  // Conflict resolution
  const resolveConflict = useCallback((resolution: 'accept_remote' | 'accept_local' | 'merge') => {
    // Implementation would depend on the specific conflict resolution strategy
    console.log('Resolving conflict with strategy:', resolution)
    
    if (resolution === 'accept_remote') {
      // Re-sync with server version
      syncDocument()
    } else if (resolution === 'merge') {
      // Implement three-way merge
      // This is complex and would require operational transformation
    }
  }, [syncDocument])

  // Set up event listeners
  useEffect(() => {
    if (!isConnected) return

    const unsubscribers = [
      on('document_update', handleDocumentUpdate),
      on('cursor_move', handleCursorMove),
      on('selection_change', handleSelectionChange)
    ]

    return () => {
      unsubscribers.forEach(unsub => unsub())
    }
  }, [isConnected, on, handleDocumentUpdate, handleCursorMove, handleSelectionChange])

  // Cleanup timers on unmount
  useEffect(() => {
    return () => {
      if (debounceTimerRef.current) {
        clearTimeout(debounceTimerRef.current)
      }
    }
  }, [])

  // Auto-sync when reconnected
  useEffect(() => {
    if (isConnected && isAuthenticated) {
      syncDocument()
    }
  }, [isConnected, isAuthenticated, syncDocument])

  return {
    // State
    documentState,
    isEditing,
    conflictResolution,
    
    // Actions
    insertText,
    deleteText,
    replaceText,
    updateCursorPosition,
    updateSelection,
    syncDocument,
    resolveConflict,
    setIsEditing,
    setConflictResolution,
    
    // Editor reference
    editorRef,
    
    // Helpers
    getCursorsInDocument: () => Object.values(documentState.cursors),
    getSelectionsInDocument: () => Object.values(documentState.selections),
    getChangeHistory: () => documentState.changes,
    canEdit: isConnected && isAuthenticated
  }
}

// Helper functions for operational transformation
function transformChanges(remoteChanges: DocumentChange[], localChanges: DocumentChange[]): DocumentChange[] {
  // Simplified operational transformation
  // In a real implementation, this would be much more complex
  
  if (localChanges.length === 0) {
    return remoteChanges
  }

  // For now, just return remote changes as-is
  // Real implementation would transform based on local changes
  return remoteChanges
}

function applyChange(content: string, change: DocumentChange): string {
  switch (change.type) {
    case 'insert':
      return content.slice(0, change.position) + 
             (change.content || '') + 
             content.slice(change.position)
    
    case 'delete':
      return content.slice(0, change.position) + 
             content.slice(change.position + (change.length || 0))
    
    case 'replace':
      return content.slice(0, change.position) + 
             (change.content || '') + 
             content.slice(change.position + (change.length || 0))
    
    default:
      return content
  }
}

export default useCollaborativeEditing