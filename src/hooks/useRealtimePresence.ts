import { useState, useEffect, useCallback } from 'react'
import { useWebSocket, WebSocketUser } from './useWebSocket'

export interface PresenceState {
  onlineUsers: WebSocketUser[]
  userPresence: Record<string, 'online' | 'away' | 'busy' | 'invisible'>
  roomParticipants: Record<string, WebSocketUser[]>
  typingUsers: Record<string, string[]> // roomId -> array of typing usernames
}

export interface UseRealtimePresenceOptions {
  trackTyping?: boolean
  typingTimeout?: number
  presenceHeartbeat?: number
}

export function useRealtimePresence(
  currentUser: { userId: string; username: string; avatar?: string; role: string },
  options: UseRealtimePresenceOptions = {}
) {
  const {
    trackTyping = true,
    typingTimeout = 3000,
    presenceHeartbeat = 30000
  } = options

  const { 
    isConnected, 
    isAuthenticated, 
    connectedUsers, 
    joinedRooms,
    on, 
    off, 
    emit,
    updatePresence: updateSocketPresence 
  } = useWebSocket()

  const [presenceState, setPresenceState] = useState<PresenceState>({
    onlineUsers: [],
    userPresence: {},
    roomParticipants: {},
    typingUsers: {}
  })

  const [currentPresence, setCurrentPresence] = useState<'online' | 'away' | 'busy' | 'invisible'>('online')
  const [typingTimeouts, setTypingTimeouts] = useState<Map<string, NodeJS.Timeout>>(new Map())

  // Update presence state when connected users change
  useEffect(() => {
    setPresenceState(prev => ({
      ...prev,
      onlineUsers: connectedUsers,
      userPresence: connectedUsers.reduce((acc, user) => {
        acc[user.userId] = user.presence
        return acc
      }, {} as Record<string, string>)
    }))
  }, [connectedUsers])

  // Handle room participants updates
  const handleRoomJoined = useCallback((data: {
    roomId: string
    participants: string[]
  }) => {
    const roomParticipants = data.participants
      .map(userId => connectedUsers.find(user => user.userId === userId))
      .filter(Boolean) as WebSocketUser[]

    setPresenceState(prev => ({
      ...prev,
      roomParticipants: {
        ...prev.roomParticipants,
        [data.roomId]: roomParticipants
      }
    }))
  }, [connectedUsers])

  const handleUserJoinedRoom = useCallback((data: {
    roomId: string
    userId: string
    username: string
    avatar?: string
  }) => {
    const user = connectedUsers.find(u => u.userId === data.userId)
    if (user) {
      setPresenceState(prev => ({
        ...prev,
        roomParticipants: {
          ...prev.roomParticipants,
          [data.roomId]: [...(prev.roomParticipants[data.roomId] || []), user]
        }
      }))
    }
  }, [connectedUsers])

  const handleUserLeftRoom = useCallback((data: {
    roomId: string
    userId: string
  }) => {
    setPresenceState(prev => ({
      ...prev,
      roomParticipants: {
        ...prev.roomParticipants,
        [data.roomId]: (prev.roomParticipants[data.roomId] || [])
          .filter(user => user.userId !== data.userId)
      }
    }))
  }, [])

  // Handle typing indicators
  const handleTypingIndicator = useCallback((data: {
    userId: string
    username: string
    roomId: string
    isTyping: boolean
  }) => {
    if (!trackTyping) return

    setPresenceState(prev => {
      const roomTypingUsers = prev.typingUsers[data.roomId] || []
      
      if (data.isTyping) {
        // Add user to typing list if not already there
        if (!roomTypingUsers.includes(data.username)) {
          return {
            ...prev,
            typingUsers: {
              ...prev.typingUsers,
              [data.roomId]: [...roomTypingUsers, data.username]
            }
          }
        }
      } else {
        // Remove user from typing list
        return {
          ...prev,
          typingUsers: {
            ...prev.typingUsers,
            [data.roomId]: roomTypingUsers.filter(username => username !== data.username)
          }
        }
      }
      
      return prev
    })
  }, [trackTyping])

  // Typing functionality
  const startTyping = useCallback((roomId: string) => {
    if (!trackTyping || !isAuthenticated) return

    emit('typing_start', { roomId })

    // Clear existing timeout for this room
    const existingTimeout = typingTimeouts.get(roomId)
    if (existingTimeout) {
      clearTimeout(existingTimeout)
    }

    // Set new timeout to stop typing
    const timeout = setTimeout(() => {
      stopTyping(roomId)
    }, typingTimeout)

    setTypingTimeouts(prev => new Map(prev.set(roomId, timeout)))
  }, [trackTyping, isAuthenticated, emit, typingTimeout, typingTimeouts])

  const stopTyping = useCallback((roomId: string) => {
    if (!trackTyping || !isAuthenticated) return

    emit('typing_stop', { roomId })

    // Clear timeout
    const timeout = typingTimeouts.get(roomId)
    if (timeout) {
      clearTimeout(timeout)
      setTypingTimeouts(prev => {
        const newMap = new Map(prev)
        newMap.delete(roomId)
        return newMap
      })
    }
  }, [trackTyping, isAuthenticated, emit, typingTimeouts])

  // Presence updates
  const updatePresence = useCallback((presence: 'online' | 'away' | 'busy' | 'invisible') => {
    setCurrentPresence(presence)
    updateSocketPresence(presence)
  }, [updateSocketPresence])

  // Auto presence detection
  useEffect(() => {
    let isIdle = false
    let idleTimer: NodeJS.Timeout

    const resetIdleTimer = () => {
      clearTimeout(idleTimer)
      
      if (isIdle && currentPresence !== 'away') {
        isIdle = false
        updatePresence('online')
      }

      idleTimer = setTimeout(() => {
        if (!isIdle && currentPresence === 'online') {
          isIdle = true
          updatePresence('away')
        }
      }, 5 * 60 * 1000) // 5 minutes of inactivity
    }

    const events = ['mousedown', 'mousemove', 'keypress', 'scroll', 'touchstart', 'click']
    
    events.forEach(event => {
      document.addEventListener(event, resetIdleTimer, true)
    })

    resetIdleTimer()

    return () => {
      clearTimeout(idleTimer)
      events.forEach(event => {
        document.removeEventListener(event, resetIdleTimer, true)
      })
    }
  }, [currentPresence, updatePresence])

  // Presence heartbeat
  useEffect(() => {
    if (!isAuthenticated) return

    const heartbeat = setInterval(() => {
      emit('ping')
    }, presenceHeartbeat)

    return () => clearInterval(heartbeat)
  }, [isAuthenticated, emit, presenceHeartbeat])

  // Set up event listeners
  useEffect(() => {
    if (!isConnected) return

    const unsubscribers = [
      on('room_joined', handleRoomJoined),
      on('user_joined_room', handleUserJoinedRoom),
      on('user_left_room', handleUserLeftRoom),
      on('typing_indicator', handleTypingIndicator)
    ]

    return () => {
      unsubscribers.forEach(unsub => unsub())
    }
  }, [isConnected, on, handleRoomJoined, handleUserJoinedRoom, handleUserLeftRoom, handleTypingIndicator])

  // Cleanup typing timeouts on unmount
  useEffect(() => {
    return () => {
      typingTimeouts.forEach(timeout => clearTimeout(timeout))
    }
  }, [typingTimeouts])

  // Helper functions
  const isUserOnline = useCallback((userId: string) => {
    return presenceState.userPresence[userId] === 'online'
  }, [presenceState.userPresence])

  const getUsersInRoom = useCallback((roomId: string) => {
    return presenceState.roomParticipants[roomId] || []
  }, [presenceState.roomParticipants])

  const getTypingUsersInRoom = useCallback((roomId: string) => {
    return presenceState.typingUsers[roomId] || []
  }, [presenceState.typingUsers])

  const getOnlineCount = useCallback(() => {
    return presenceState.onlineUsers.filter(user => user.presence === 'online').length
  }, [presenceState.onlineUsers])

  return {
    // State
    presenceState,
    currentPresence,
    isOnline: isConnected && isAuthenticated,
    
    // Actions
    updatePresence,
    startTyping,
    stopTyping,
    
    // Helpers
    isUserOnline,
    getUsersInRoom,
    getTypingUsersInRoom,
    getOnlineCount,
    
    // Raw data
    onlineUsers: presenceState.onlineUsers,
    roomParticipants: presenceState.roomParticipants,
    typingUsers: presenceState.typingUsers
  }
}

export default useRealtimePresence