import { useEffect, useRef, useState, useCallback } from 'react'
import { io, Socket } from 'socket.io-client'

export interface UseWebSocketOptions {
  autoConnect?: boolean
  reconnection?: boolean
  reconnectionAttempts?: number
  reconnectionDelay?: number
}

export interface WebSocketUser {
  userId: string
  username: string
  avatar?: string
  presence: 'online' | 'away' | 'busy' | 'invisible'
  lastActive: Date
}

export interface WebSocketMessage {
  id: string
  type: 'chat' | 'notification' | 'system' | 'approval' | 'collaboration'
  roomId: string
  senderId: string
  content: any
  timestamp: Date
  metadata?: Record<string, any>
}

export interface TypingUser {
  userId: string
  username: string
  roomId: string
  isTyping: boolean
}

export interface CursorUser {
  userId: string
  username: string
  x: number
  y: number
  color: string
  roomId: string
}

export interface RoomInfo {
  roomId: string
  participants: string[]
  recentMessages: WebSocketMessage[]
  roomInfo: any
}

export function useWebSocket(options: UseWebSocketOptions = {}) {
  const {
    autoConnect = true,
    reconnection = true,
    reconnectionAttempts = 5,
    reconnectionDelay = 1000
  } = options

  const socketRef = useRef<Socket | null>(null)
  const [isConnected, setIsConnected] = useState(false)
  const [isAuthenticated, setIsAuthenticated] = useState(false)
  const [connectionError, setConnectionError] = useState<string | null>(null)
  const [connectedUsers, setConnectedUsers] = useState<WebSocketUser[]>([])
  const [joinedRooms, setJoinedRooms] = useState<Set<string>>(new Set())

  // Event listeners storage
  const listenersRef = useRef<Map<string, Function[]>>(new Map())

  const connect = useCallback((serverUrl?: string) => {
    if (socketRef.current?.connected) {
      return socketRef.current
    }

    const url = serverUrl || process.env.NEXT_PUBLIC_WS_URL || window.location.origin
    
    socketRef.current = io(url, {
      transports: ['websocket', 'polling'],
      reconnection,
      reconnectionAttempts,
      reconnectionDelay,
      timeout: 5000
    })

    const socket = socketRef.current

    // Connection events
    socket.on('connect', () => {
      console.log('WebSocket connected')
      setIsConnected(true)
      setConnectionError(null)
    })

    socket.on('disconnect', (reason) => {
      console.log('WebSocket disconnected:', reason)
      setIsConnected(false)
      setIsAuthenticated(false)
      setJoinedRooms(new Set())
    })

    socket.on('connect_error', (error) => {
      console.error('WebSocket connection error:', error)
      setConnectionError(error.message)
    })

    // Authentication events
    socket.on('authenticated', (data) => {
      console.log('WebSocket authenticated')
      setIsAuthenticated(true)
      setConnectedUsers(data.connectedUsers || [])
    })

    socket.on('auth_error', (data) => {
      console.error('Authentication error:', data.message)
      setConnectionError(data.message)
    })

    // User events
    socket.on('user_connected', (user) => {
      setConnectedUsers(prev => {
        const filtered = prev.filter(u => u.userId !== user.userId)
        return [...filtered, user]
      })
    })

    socket.on('user_disconnected', (user) => {
      setConnectedUsers(prev => prev.filter(u => u.userId !== user.userId))
    })

    socket.on('presence_update', (data) => {
      setConnectedUsers(prev => prev.map(user => 
        user.userId === data.userId 
          ? { ...user, presence: data.presence, lastActive: data.lastActive }
          : user
      ))
    })

    // Error handling
    socket.on('error', (error) => {
      console.error('WebSocket error:', error)
      setConnectionError(error.message)
    })

    return socket
  }, [reconnection, reconnectionAttempts, reconnectionDelay])

  const disconnect = useCallback(() => {
    if (socketRef.current) {
      socketRef.current.disconnect()
      socketRef.current = null
      setIsConnected(false)
      setIsAuthenticated(false)
      setJoinedRooms(new Set())
    }
  }, [])

  const authenticate = useCallback((userData: {
    userId: string
    username: string
    avatar?: string
    role: string
    token?: string
  }) => {
    if (socketRef.current?.connected) {
      socketRef.current.emit('authenticate', userData)
    }
  }, [])

  const joinRoom = useCallback((roomData: {
    roomId: string
    roomType: string
    targetId?: string
  }) => {
    if (socketRef.current?.connected && isAuthenticated) {
      socketRef.current.emit('join_room', roomData)
      setJoinedRooms(prev => new Set(prev).add(roomData.roomId))
    }
  }, [isAuthenticated])

  const leaveRoom = useCallback((roomId: string) => {
    if (socketRef.current?.connected) {
      socketRef.current.emit('leave_room', roomId)
      setJoinedRooms(prev => {
        const newSet = new Set(prev)
        newSet.delete(roomId)
        return newSet
      })
    }
  }, [])

  const sendMessage = useCallback((data: {
    roomId: string
    type: string
    content: any
    metadata?: Record<string, any>
  }) => {
    if (socketRef.current?.connected && isAuthenticated) {
      socketRef.current.emit('send_message', data)
    }
  }, [isAuthenticated])

  const updatePresence = useCallback((presence: 'online' | 'away' | 'busy' | 'invisible') => {
    if (socketRef.current?.connected && isAuthenticated) {
      socketRef.current.emit('presence_update', presence)
    }
  }, [isAuthenticated])

  // Event listener management
  const on = useCallback((event: string, listener: Function) => {
    if (!listenersRef.current.has(event)) {
      listenersRef.current.set(event, [])
    }
    listenersRef.current.get(event)!.push(listener)

    if (socketRef.current) {
      socketRef.current.on(event, listener as any)
    }

    return () => {
      const listeners = listenersRef.current.get(event)
      if (listeners) {
        const index = listeners.indexOf(listener)
        if (index > -1) {
          listeners.splice(index, 1)
        }
      }
      if (socketRef.current) {
        socketRef.current.off(event, listener as any)
      }
    }
  }, [])

  const off = useCallback((event: string, listener?: Function) => {
    if (listener) {
      const listeners = listenersRef.current.get(event)
      if (listeners) {
        const index = listeners.indexOf(listener)
        if (index > -1) {
          listeners.splice(index, 1)
        }
      }
      if (socketRef.current) {
        socketRef.current.off(event, listener as any)
      }
    } else {
      listenersRef.current.delete(event)
      if (socketRef.current) {
        socketRef.current.removeAllListeners(event)
      }
    }
  }, [])

  const emit = useCallback((event: string, ...args: any[]) => {
    if (socketRef.current?.connected) {
      socketRef.current.emit(event, ...args)
    }
  }, [])

  // Auto-connect on mount
  useEffect(() => {
    if (autoConnect) {
      connect()
    }

    return () => {
      disconnect()
    }
  }, [autoConnect, connect, disconnect])

  // Re-attach listeners when socket reconnects
  useEffect(() => {
    if (socketRef.current && isConnected) {
      listenersRef.current.forEach((listeners, event) => {
        listeners.forEach(listener => {
          socketRef.current!.on(event, listener as any)
        })
      })
    }
  }, [isConnected])

  return {
    socket: socketRef.current,
    isConnected,
    isAuthenticated,
    connectionError,
    connectedUsers,
    joinedRooms: Array.from(joinedRooms),
    
    // Actions
    connect,
    disconnect,
    authenticate,
    joinRoom,
    leaveRoom,
    sendMessage,
    updatePresence,
    
    // Event handling
    on,
    off,
    emit
  }
}

export default useWebSocket