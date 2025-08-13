import { Server as HTTPServer } from 'http'
import { Server as SocketIOServer, Socket } from 'socket.io'
import { PrismaClient } from '@prisma/client'

const prisma = new PrismaClient()

export interface ConnectedUser {
  userId: string
  socketId: string
  username: string
  avatar?: string
  role: string
  connectedAt: Date
  lastActive: Date
  rooms: Set<string>
  presence: 'online' | 'away' | 'busy' | 'invisible'
  isTyping: Record<string, boolean> // roomId -> isTyping
  cursor?: {
    x: number
    y: number
    roomId: string
  }
}

export interface RoomInfo {
  id: string
  type: 'campaign' | 'journey' | 'content' | 'workspace' | 'approval'
  targetId?: string
  participants: Set<string>
  createdAt: Date
  lastActivity: Date
  metadata?: Record<string, any>
}

export interface RealtimeMessage {
  id: string
  type: 'chat' | 'notification' | 'system' | 'approval' | 'collaboration'
  roomId: string
  senderId: string
  content: any
  timestamp: Date
  metadata?: Record<string, any>
}

export interface TypingIndicator {
  userId: string
  username: string
  roomId: string
  isTyping: boolean
  timestamp: Date
}

export interface CursorPosition {
  userId: string
  username: string
  x: number
  y: number
  roomId: string
  color: string
  timestamp: Date
}

export class WebSocketServer {
  private io: SocketIOServer
  private connectedUsers: Map<string, ConnectedUser> = new Map()
  private userSocketMap: Map<string, string> = new Map() // userId -> socketId
  private rooms: Map<string, RoomInfo> = new Map()
  private messageHistory: Map<string, RealtimeMessage[]> = new Map()

  constructor(httpServer: HTTPServer) {
    this.io = new SocketIOServer(httpServer, {
      cors: {
        origin: process.env.NEXT_PUBLIC_APP_URL || "http://localhost:3000",
        methods: ["GET", "POST"],
        credentials: true
      },
      transports: ['websocket', 'polling']
    })

    this.setupEventHandlers()
    this.setupPeriodicCleanup()
  }

  private setupEventHandlers() {
    this.io.on('connection', (socket: Socket) => {
      console.log(`Socket connected: ${socket.id}`)

      // Authentication and user setup
      socket.on('authenticate', (data: {
        userId: string
        username: string
        avatar?: string
        role: string
        token?: string
      }) => {
        this.handleAuthentication(socket, data)
      })

      // Room management
      socket.on('join_room', (data: {
        roomId: string
        roomType: string
        targetId?: string
      }) => {
        this.handleJoinRoom(socket, data)
      })

      socket.on('leave_room', (roomId: string) => {
        this.handleLeaveRoom(socket, roomId)
      })

      // Real-time messaging
      socket.on('send_message', (data: {
        roomId: string
        type: string
        content: any
        metadata?: Record<string, any>
      }) => {
        this.handleSendMessage(socket, data)
      })

      // Typing indicators
      socket.on('typing_start', (data: { roomId: string }) => {
        this.handleTypingStart(socket, data.roomId)
      })

      socket.on('typing_stop', (data: { roomId: string }) => {
        this.handleTypingStop(socket, data.roomId)
      })

      // Cursor tracking
      socket.on('cursor_move', (data: {
        roomId: string
        x: number
        y: number
      }) => {
        this.handleCursorMove(socket, data)
      })

      // Presence updates
      socket.on('presence_update', (presence: string) => {
        this.handlePresenceUpdate(socket, presence)
      })

      // Approval workflow events
      socket.on('approval_action', (data: {
        requestId: string
        action: string
        stageId: string
        comment?: string
      }) => {
        this.handleApprovalAction(socket, data)
      })

      // Collaboration events
      socket.on('document_change', (data: {
        roomId: string
        documentId: string
        changes: any
        version: number
      }) => {
        this.handleDocumentChange(socket, data)
      })

      // Disconnect handling
      socket.on('disconnect', (reason) => {
        this.handleDisconnect(socket, reason)
      })

      // Heartbeat for connection health
      socket.on('ping', () => {
        socket.emit('pong')
        this.updateUserActivity(socket.id)
      })
    })
  }

  private handleAuthentication(socket: Socket, data: {
    userId: string
    username: string
    avatar?: string
    role: string
    token?: string
  }) {
    try {
      // TODO: Validate authentication token
      // For now, we'll accept the provided user data

      // Remove any existing connection for this user
      const existingSocketId = this.userSocketMap.get(data.userId)
      if (existingSocketId) {
        this.connectedUsers.delete(existingSocketId)
      }

      // Create new user connection
      const user: ConnectedUser = {
        userId: data.userId,
        socketId: socket.id,
        username: data.username,
        avatar: data.avatar,
        role: data.role,
        connectedAt: new Date(),
        lastActive: new Date(),
        rooms: new Set(),
        presence: 'online',
        isTyping: {},
        cursor: undefined
      }

      this.connectedUsers.set(socket.id, user)
      this.userSocketMap.set(data.userId, socket.id)

      // Join user-specific room for private messages
      socket.join(`user:${data.userId}`)

      // Emit successful authentication
      socket.emit('authenticated', {
        userId: data.userId,
        connectedUsers: this.getConnectedUsersList(),
        activeRooms: Array.from(this.rooms.keys())
      })

      // Broadcast user online status
      socket.broadcast.emit('user_connected', {
        userId: data.userId,
        username: data.username,
        avatar: data.avatar,
        presence: 'online'
      })

      console.log(`User authenticated: ${data.username} (${data.userId})`)
    } catch (error) {
      console.error('Authentication error:', error)
      socket.emit('auth_error', { message: 'Authentication failed' })
    }
  }

  private handleJoinRoom(socket: Socket, data: {
    roomId: string
    roomType: string
    targetId?: string
  }) {
    const user = this.connectedUsers.get(socket.id)
    if (!user) {
      socket.emit('error', { message: 'User not authenticated' })
      return
    }

    // Create room if it doesn't exist
    if (!this.rooms.has(data.roomId)) {
      this.rooms.set(data.roomId, {
        id: data.roomId,
        type: data.roomType as any,
        targetId: data.targetId,
        participants: new Set(),
        createdAt: new Date(),
        lastActivity: new Date(),
        metadata: {}
      })
      this.messageHistory.set(data.roomId, [])
    }

    const room = this.rooms.get(data.roomId)!
    
    // Join socket room
    socket.join(data.roomId)
    user.rooms.add(data.roomId)
    room.participants.add(user.userId)
    room.lastActivity = new Date()

    // Send room info and recent messages
    const recentMessages = this.messageHistory.get(data.roomId)?.slice(-50) || []
    socket.emit('room_joined', {
      roomId: data.roomId,
      participants: Array.from(room.participants),
      recentMessages,
      roomInfo: room
    })

    // Notify other participants
    socket.to(data.roomId).emit('user_joined_room', {
      roomId: data.roomId,
      userId: user.userId,
      username: user.username,
      avatar: user.avatar
    })

    console.log(`User ${user.username} joined room: ${data.roomId}`)
  }

  private handleLeaveRoom(socket: Socket, roomId: string) {
    const user = this.connectedUsers.get(socket.id)
    if (!user) return

    socket.leave(roomId)
    user.rooms.delete(roomId)

    const room = this.rooms.get(roomId)
    if (room) {
      room.participants.delete(user.userId)
      
      // Notify other participants
      socket.to(roomId).emit('user_left_room', {
        roomId,
        userId: user.userId,
        username: user.username
      })

      // Clean up empty rooms (except persistent ones)
      if (room.participants.size === 0 && room.type !== 'workspace') {
        this.rooms.delete(roomId)
        this.messageHistory.delete(roomId)
      }
    }
  }

  private handleSendMessage(socket: Socket, data: {
    roomId: string
    type: string
    content: any
    metadata?: Record<string, any>
  }) {
    const user = this.connectedUsers.get(socket.id)
    if (!user || !user.rooms.has(data.roomId)) {
      socket.emit('error', { message: 'Not authorized to send message to this room' })
      return
    }

    const message: RealtimeMessage = {
      id: `msg_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`,
      type: data.type as any,
      roomId: data.roomId,
      senderId: user.userId,
      content: data.content,
      timestamp: new Date(),
      metadata: {
        senderName: user.username,
        senderAvatar: user.avatar,
        ...data.metadata
      }
    }

    // Store message in history
    const roomHistory = this.messageHistory.get(data.roomId) || []
    roomHistory.push(message)
    
    // Keep only last 1000 messages per room
    if (roomHistory.length > 1000) {
      roomHistory.splice(0, roomHistory.length - 1000)
    }
    this.messageHistory.set(data.roomId, roomHistory)

    // Broadcast message to room
    this.io.to(data.roomId).emit('new_message', message)

    // Update room activity
    const room = this.rooms.get(data.roomId)
    if (room) {
      room.lastActivity = new Date()
    }
  }

  private handleTypingStart(socket: Socket, roomId: string) {
    const user = this.connectedUsers.get(socket.id)
    if (!user || !user.rooms.has(roomId)) return

    user.isTyping[roomId] = true

    const typingIndicator: TypingIndicator = {
      userId: user.userId,
      username: user.username,
      roomId,
      isTyping: true,
      timestamp: new Date()
    }

    socket.to(roomId).emit('typing_indicator', typingIndicator)
  }

  private handleTypingStop(socket: Socket, roomId: string) {
    const user = this.connectedUsers.get(socket.id)
    if (!user) return

    user.isTyping[roomId] = false

    const typingIndicator: TypingIndicator = {
      userId: user.userId,
      username: user.username,
      roomId,
      isTyping: false,
      timestamp: new Date()
    }

    socket.to(roomId).emit('typing_indicator', typingIndicator)
  }

  private handleCursorMove(socket: Socket, data: {
    roomId: string
    x: number
    y: number
  }) {
    const user = this.connectedUsers.get(socket.id)
    if (!user || !user.rooms.has(data.roomId)) return

    user.cursor = {
      x: data.x,
      y: data.y,
      roomId: data.roomId
    }

    const cursorPosition: CursorPosition = {
      userId: user.userId,
      username: user.username,
      x: data.x,
      y: data.y,
      roomId: data.roomId,
      color: this.getUserCursorColor(user.userId),
      timestamp: new Date()
    }

    socket.to(data.roomId).emit('cursor_move', cursorPosition)
  }

  private handlePresenceUpdate(socket: Socket, presence: string) {
    const user = this.connectedUsers.get(socket.id)
    if (!user) return

    user.presence = presence as any
    user.lastActive = new Date()

    // Broadcast presence update to all user's rooms
    user.rooms.forEach(roomId => {
      socket.to(roomId).emit('presence_update', {
        userId: user.userId,
        presence: user.presence,
        lastActive: user.lastActive
      })
    })
  }

  private handleApprovalAction(socket: Socket, data: {
    requestId: string
    action: string
    stageId: string
    comment?: string
  }) {
    const user = this.connectedUsers.get(socket.id)
    if (!user) return

    // Broadcast approval action to relevant room
    const approvalRoomId = `approval:${data.requestId}`
    
    this.io.to(approvalRoomId).emit('approval_update', {
      requestId: data.requestId,
      action: data.action,
      stageId: data.stageId,
      approverId: user.userId,
      approverName: user.username,
      comment: data.comment,
      timestamp: new Date()
    })

    // TODO: Integrate with approval workflow engine
    // This would trigger the actual approval processing
    console.log(`Approval action: ${data.action} by ${user.username} for request ${data.requestId}`)
  }

  private handleDocumentChange(socket: Socket, data: {
    roomId: string
    documentId: string
    changes: any
    version: number
  }) {
    const user = this.connectedUsers.get(socket.id)
    if (!user || !user.rooms.has(data.roomId)) return

    // Broadcast document changes to other collaborators
    socket.to(data.roomId).emit('document_update', {
      documentId: data.documentId,
      changes: data.changes,
      version: data.version,
      userId: user.userId,
      username: user.username,
      timestamp: new Date()
    })
  }

  private handleDisconnect(socket: Socket, reason: string) {
    const user = this.connectedUsers.get(socket.id)
    if (!user) return

    console.log(`User disconnected: ${user.username} (${reason})`)

    // Remove from all rooms
    user.rooms.forEach(roomId => {
      const room = this.rooms.get(roomId)
      if (room) {
        room.participants.delete(user.userId)
        
        socket.to(roomId).emit('user_left_room', {
          roomId,
          userId: user.userId,
          username: user.username
        })
      }
    })

    // Broadcast user offline status
    socket.broadcast.emit('user_disconnected', {
      userId: user.userId,
      username: user.username
    })

    // Clean up user data
    this.connectedUsers.delete(socket.id)
    this.userSocketMap.delete(user.userId)
  }

  private updateUserActivity(socketId: string) {
    const user = this.connectedUsers.get(socketId)
    if (user) {
      user.lastActive = new Date()
    }
  }

  private getUserCursorColor(userId: string): string {
    // Generate consistent color for user
    const colors = [
      '#FF6B6B', '#4ECDC4', '#45B7D1', '#96CEB4', '#FFEAA7',
      '#DDA0DD', '#98D8C8', '#F7DC6F', '#BB8FCE', '#85C1E9'
    ]
    const index = parseInt(userId.slice(-2), 16) % colors.length
    return colors[index]
  }

  private getConnectedUsersList() {
    return Array.from(this.connectedUsers.values()).map(user => ({
      userId: user.userId,
      username: user.username,
      avatar: user.avatar,
      presence: user.presence,
      lastActive: user.lastActive
    }))
  }

  private setupPeriodicCleanup() {
    // Clean up inactive connections every 5 minutes
    setInterval(() => {
      const now = new Date()
      const thirtyMinutesAgo = new Date(now.getTime() - 30 * 60 * 1000)

      this.connectedUsers.forEach((user, socketId) => {
        if (user.lastActive < thirtyMinutesAgo) {
          const socket = this.io.sockets.sockets.get(socketId)
          if (socket) {
            socket.disconnect(true)
          }
          this.connectedUsers.delete(socketId)
          this.userSocketMap.delete(user.userId)
        }
      })
    }, 5 * 60 * 1000)
  }

  // Public methods for external integration
  public sendNotificationToUser(userId: string, notification: any) {
    const socketId = this.userSocketMap.get(userId)
    if (socketId) {
      this.io.to(`user:${userId}`).emit('notification', notification)
    }
  }

  public sendNotificationToRoom(roomId: string, notification: any) {
    this.io.to(roomId).emit('notification', notification)
  }

  public broadcastSystemMessage(message: any) {
    this.io.emit('system_message', message)
  }

  public getRoomParticipants(roomId: string): string[] {
    const room = this.rooms.get(roomId)
    return room ? Array.from(room.participants) : []
  }

  public getConnectedUsers(): ConnectedUser[] {
    return Array.from(this.connectedUsers.values())
  }

  public isUserConnected(userId: string): boolean {
    return this.userSocketMap.has(userId)
  }
}

let webSocketServer: WebSocketServer | null = null

export function initializeWebSocketServer(httpServer: HTTPServer): WebSocketServer {
  if (!webSocketServer) {
    webSocketServer = new WebSocketServer(httpServer)
  }
  return webSocketServer
}

export function getWebSocketServer(): WebSocketServer | null {
  return webSocketServer
}

export default WebSocketServer