import { Server as HTTPServer } from 'http'
import { Server as SocketIOServer } from 'socket.io'
import { Client } from 'socket.io-client'
import { PrismaClient } from '@prisma/client'
import { vi } from 'vitest'
import { 
  SocketServer,
  ConnectedUser,
  RoomInfo,
  RealtimeMessage,
  TypingIndicator 
} from '@/lib/websocket/socket-server'

// Mock Prisma Client
const mockPrismaClient = {
  realtimeSession: {
    create: vi.fn(),
    update: vi.fn(),
    delete: vi.fn(),
    findMany: vi.fn()
  },
  realtimeMessage: {
    create: vi.fn(),
    findMany: vi.fn()
  },
  notification: {
    create: vi.fn(),
    findMany: vi.fn(),
    update: vi.fn()
  }
} as unknown as PrismaClient

// Mock Socket.IO Server
const mockSocketIOServer = {
  on: vi.fn(),
  emit: vi.fn(),
  to: vi.fn(() => mockSocketIOServer),
  in: vi.fn(() => mockSocketIOServer),
  sockets: {
    sockets: new Map()
  },
  close: vi.fn()
} as unknown as SocketIOServer

// Mock Socket
const createMockSocket = (id: string, userId?: string) => ({
  id,
  userId,
  username: `user-${userId}`,
  emit: vi.fn(),
  on: vi.fn(),
  join: vi.fn(),
  leave: vi.fn(),
  disconnect: vi.fn(),
  handshake: {
    auth: { userId, token: 'mock-token' },
    address: '127.0.0.1'
  },
  rooms: new Set()
})

describe('SocketServer', () => {
  let socketServer: SocketServer
  let httpServer: HTTPServer

  beforeEach(() => {
    vi.clearAllMocks()
    httpServer = new HTTPServer()
    socketServer = new SocketServer(httpServer, mockPrismaClient)
  })

  afterEach(async () => {
    if (socketServer) {
      await socketServer.close()
    }
  })

  describe('Initialization', () => {
    test('should initialize socket server with HTTP server', () => {
      expect(socketServer).toBeInstanceOf(SocketServer)
    })

    test('should setup socket event handlers', () => {
      const server = new SocketServer(httpServer, mockPrismaClient)
      expect(server).toBeInstanceOf(SocketServer)
    })

    test('should configure CORS and middleware', () => {
      const corsOptions = {
        origin: ['https://app.example.com', 'https://admin.example.com'],
        credentials: true
      }

      const server = new SocketServer(httpServer, mockPrismaClient, {
        cors: corsOptions,
        enableAuth: true
      })

      expect(server).toBeInstanceOf(SocketServer)
    })
  })

  describe('Connection Management', () => {
    test('should handle user connection', async () => {
      const socket = createMockSocket('socket-123', 'user-456')
      
      await socketServer.handleConnection(socket as any)

      expect(mockPrismaClient.realtimeSession.create).toHaveBeenCalledWith({
        data: {
          userId: 'user-456',
          socketId: 'socket-123',
          connectedAt: expect.any(Date),
          ipAddress: '127.0.0.1',
          userAgent: undefined
        }
      })

      // Should add user to connected users
      const connectedUsers = socketServer.getConnectedUsers()
      expect(connectedUsers).toHaveLength(1)
      expect(connectedUsers[0].userId).toBe('user-456')
    })

    test('should handle user authentication', async () => {
      const socket = createMockSocket('socket-123', 'user-456')
      socket.handshake.auth.token = 'valid-jwt-token'

      const isAuthenticated = await socketServer.authenticateSocket(socket as any)

      expect(isAuthenticated).toBe(true)
    })

    test('should reject invalid authentication', async () => {
      const socket = createMockSocket('socket-123', 'user-456')
      socket.handshake.auth.token = 'invalid-token'

      const isAuthenticated = await socketServer.authenticateSocket(socket as any)

      expect(isAuthenticated).toBe(false)
    })

    test('should handle user disconnection', async () => {
      const socket = createMockSocket('socket-123', 'user-456')
      
      // First connect
      await socketServer.handleConnection(socket as any)
      expect(socketServer.getConnectedUsers()).toHaveLength(1)

      // Then disconnect
      await socketServer.handleDisconnection(socket as any, 'client disconnect')

      expect(mockPrismaClient.realtimeSession.delete).toHaveBeenCalledWith({
        where: { socketId: 'socket-123' }
      })

      expect(socketServer.getConnectedUsers()).toHaveLength(0)
    })

    test('should handle multiple connections from same user', async () => {
      const socket1 = createMockSocket('socket-123', 'user-456')
      const socket2 = createMockSocket('socket-456', 'user-456')

      await socketServer.handleConnection(socket1 as any)
      await socketServer.handleConnection(socket2 as any)

      const connectedUsers = socketServer.getConnectedUsers()
      expect(connectedUsers).toHaveLength(2)
      
      // Both should be same user but different sockets
      expect(connectedUsers.every(u => u.userId === 'user-456')).toBe(true)
      expect(connectedUsers[0].socketId).not.toBe(connectedUsers[1].socketId)
    })

    test('should track user presence status', async () => {
      const socket = createMockSocket('socket-123', 'user-456')
      
      await socketServer.handleConnection(socket as any)
      await socketServer.updateUserPresence('user-456', 'busy')

      const user = socketServer.getConnectedUser('user-456')
      expect(user?.presence).toBe('busy')

      // Should notify other users in shared rooms
      expect(socket.emit).toHaveBeenCalledWith('presence_changed', {
        userId: 'user-456',
        presence: 'busy',
        timestamp: expect.any(Date)
      })
    })
  })

  describe('Room Management', () => {
    test('should create and join rooms', async () => {
      const socket = createMockSocket('socket-123', 'user-456')
      await socketServer.handleConnection(socket as any)

      const roomId = 'campaign-789'
      await socketServer.joinRoom(socket as any, {
        roomId,
        roomType: 'campaign',
        targetId: 'campaign-789'
      })

      expect(socket.join).toHaveBeenCalledWith(roomId)

      const room = socketServer.getRoomInfo(roomId)
      expect(room).toMatchObject({
        id: roomId,
        type: 'campaign',
        targetId: 'campaign-789'
      })
      expect(room?.participants.has('user-456')).toBe(true)
    })

    test('should leave rooms', async () => {
      const socket = createMockSocket('socket-123', 'user-456')
      await socketServer.handleConnection(socket as any)

      const roomId = 'campaign-789'
      await socketServer.joinRoom(socket as any, { roomId, roomType: 'campaign' })
      
      // Verify user is in room
      expect(socketServer.getRoomInfo(roomId)?.participants.has('user-456')).toBe(true)

      await socketServer.leaveRoom(socket as any, roomId)

      expect(socket.leave).toHaveBeenCalledWith(roomId)
      expect(socketServer.getRoomInfo(roomId)?.participants.has('user-456')).toBe(false)
    })

    test('should auto-join users to relevant rooms based on permissions', async () => {
      const socket = createMockSocket('socket-123', 'user-456')
      socket.userRole = 'admin'

      await socketServer.handleConnection(socket as any)

      // Admin should auto-join system room
      const systemRooms = socketServer.getUserRooms('user-456')
      expect(systemRooms.some(room => room.type === 'workspace')).toBe(true)
    })

    test('should handle room capacity limits', async () => {
      const roomId = 'limited-room'
      
      // Create room with capacity limit
      await socketServer.createRoom({
        id: roomId,
        type: 'content',
        maxParticipants: 2
      })

      const socket1 = createMockSocket('socket-1', 'user-1')
      const socket2 = createMockSocket('socket-2', 'user-2')
      const socket3 = createMockSocket('socket-3', 'user-3')

      await socketServer.handleConnection(socket1 as any)
      await socketServer.handleConnection(socket2 as any)
      await socketServer.handleConnection(socket3 as any)

      // First two should join successfully
      await socketServer.joinRoom(socket1 as any, { roomId, roomType: 'content' })
      await socketServer.joinRoom(socket2 as any, { roomId, roomType: 'content' })

      // Third should be rejected
      const result = await socketServer.joinRoom(socket3 as any, { roomId, roomType: 'content' })

      expect(result.success).toBe(false)
      expect(result.error).toContain('capacity')
    })

    test('should clean up empty rooms', async () => {
      const socket = createMockSocket('socket-123', 'user-456')
      await socketServer.handleConnection(socket as any)

      const roomId = 'temp-room'
      await socketServer.joinRoom(socket as any, { roomId, roomType: 'content' })

      // Verify room exists
      expect(socketServer.getRoomInfo(roomId)).toBeDefined()

      // Leave room
      await socketServer.leaveRoom(socket as any, roomId)

      // Room should be cleaned up after delay
      setTimeout(() => {
        expect(socketServer.getRoomInfo(roomId)).toBeUndefined()
      }, 1000)
    })
  })

  describe('Message Handling', () => {
    test('should broadcast messages to room participants', async () => {
      const socket1 = createMockSocket('socket-1', 'user-1')
      const socket2 = createMockSocket('socket-2', 'user-2')

      await socketServer.handleConnection(socket1 as any)
      await socketServer.handleConnection(socket2 as any)

      const roomId = 'chat-room'
      await socketServer.joinRoom(socket1 as any, { roomId, roomType: 'content' })
      await socketServer.joinRoom(socket2 as any, { roomId, roomType: 'content' })

      const message: RealtimeMessage = {
        id: 'msg-123',
        type: 'chat',
        roomId,
        senderId: 'user-1',
        content: { text: 'Hello everyone!' },
        timestamp: new Date()
      }

      await socketServer.broadcastMessage(message)

      expect(mockPrismaClient.realtimeMessage.create).toHaveBeenCalledWith({
        data: {
          id: 'msg-123',
          type: 'chat',
          roomId,
          senderId: 'user-1',
          content: JSON.stringify({ text: 'Hello everyone!' }),
          timestamp: expect.any(Date)
        }
      })

      // Should emit to room participants
      expect(mockSocketIOServer.to).toHaveBeenCalledWith(roomId)
      expect(mockSocketIOServer.emit).toHaveBeenCalledWith('message', message)
    })

    test('should handle private messages', async () => {
      const socket1 = createMockSocket('socket-1', 'user-1')
      const socket2 = createMockSocket('socket-2', 'user-2')

      await socketServer.handleConnection(socket1 as any)
      await socketServer.handleConnection(socket2 as any)

      const privateMessage = {
        type: 'private',
        recipientId: 'user-2',
        content: { text: 'Private message' }
      }

      await socketServer.sendPrivateMessage('user-1', privateMessage)

      expect(socket2.emit).toHaveBeenCalledWith('private_message', {
        senderId: 'user-1',
        content: privateMessage.content,
        timestamp: expect.any(Date)
      })
    })

    test('should validate message content and sanitize', async () => {
      const maliciousMessage = {
        id: 'msg-malicious',
        type: 'chat',
        roomId: 'safe-room',
        senderId: 'user-hacker',
        content: { 
          text: '<script>alert("XSS")</script>',
          html: '<img src="x" onerror="alert(1)">'
        },
        timestamp: new Date()
      }

      const sanitized = await socketServer.sanitizeMessage(maliciousMessage)

      expect(sanitized.content.text).toBe('alert("XSS")')
      expect(sanitized.content.html).not.toContain('onerror')
    })

    test('should rate limit message sending', async () => {
      const socket = createMockSocket('socket-123', 'user-spammer')
      await socketServer.handleConnection(socket as any)

      const roomId = 'rate-limited-room'
      await socketServer.joinRoom(socket as any, { roomId, roomType: 'content' })

      // Send messages rapidly
      const promises = []
      for (let i = 0; i < 20; i++) {
        promises.push(socketServer.sendMessage(socket as any, {
          type: 'chat',
          roomId,
          content: { text: `Message ${i}` }
        }))
      }

      const results = await Promise.all(promises)

      // Some messages should be rate limited
      const rateLimited = results.filter(r => r.rateLimited)
      expect(rateLimited.length).toBeGreaterThan(0)

      expect(socket.emit).toHaveBeenCalledWith('rate_limit_exceeded', {
        retryAfter: expect.any(Number)
      })
    })

    test('should handle message history and pagination', async () => {
      const roomId = 'history-room'
      
      mockPrismaClient.realtimeMessage.findMany.mockResolvedValueOnce([
        { id: 'msg-1', content: '{"text":"Message 1"}', timestamp: new Date() },
        { id: 'msg-2', content: '{"text":"Message 2"}', timestamp: new Date() }
      ])

      const history = await socketServer.getMessageHistory(roomId, {
        limit: 10,
        before: new Date()
      })

      expect(history.messages).toHaveLength(2)
      expect(mockPrismaClient.realtimeMessage.findMany).toHaveBeenCalledWith({
        where: {
          roomId,
          timestamp: { lt: expect.any(Date) }
        },
        orderBy: { timestamp: 'desc' },
        take: 10,
        include: { sender: true }
      })
    })
  })

  describe('Typing Indicators', () => {
    test('should broadcast typing indicators', async () => {
      const socket = createMockSocket('socket-123', 'user-456')
      await socketServer.handleConnection(socket as any)

      const roomId = 'typing-room'
      await socketServer.joinRoom(socket as any, { roomId, roomType: 'content' })

      await socketServer.handleTyping(socket as any, {
        roomId,
        isTyping: true
      })

      expect(mockSocketIOServer.to).toHaveBeenCalledWith(roomId)
      expect(mockSocketIOServer.emit).toHaveBeenCalledWith('user_typing', {
        userId: 'user-456',
        username: 'user-user-456',
        roomId,
        isTyping: true,
        timestamp: expect.any(Date)
      })
    })

    test('should automatically clear typing indicators after timeout', async () => {
      const socket = createMockSocket('socket-123', 'user-456')
      await socketServer.handleConnection(socket as any)

      const roomId = 'typing-timeout-room'
      await socketServer.joinRoom(socket as any, { roomId, roomType: 'content' })

      await socketServer.handleTyping(socket as any, {
        roomId,
        isTyping: true
      })

      // Wait for typing timeout
      await new Promise(resolve => setTimeout(resolve, 3100)) // 3.1 seconds

      expect(mockSocketIOServer.emit).toHaveBeenCalledWith('user_typing', {
        userId: 'user-456',
        username: 'user-user-456',
        roomId,
        isTyping: false,
        timestamp: expect.any(Date)
      })
    })

    test('should handle multiple users typing in same room', async () => {
      const socket1 = createMockSocket('socket-1', 'user-1')
      const socket2 = createMockSocket('socket-2', 'user-2')

      await socketServer.handleConnection(socket1 as any)
      await socketServer.handleConnection(socket2 as any)

      const roomId = 'multi-typing-room'
      await socketServer.joinRoom(socket1 as any, { roomId, roomType: 'content' })
      await socketServer.joinRoom(socket2 as any, { roomId, roomType: 'content' })

      await socketServer.handleTyping(socket1 as any, { roomId, isTyping: true })
      await socketServer.handleTyping(socket2 as any, { roomId, isTyping: true })

      const typingUsers = socketServer.getTypingUsers(roomId)
      expect(typingUsers).toHaveLength(2)
      expect(typingUsers.map(u => u.userId)).toEqual(['user-1', 'user-2'])
    })
  })

  describe('Collaboration Features', () => {
    test('should sync cursor positions', async () => {
      const socket1 = createMockSocket('socket-1', 'user-1')
      const socket2 = createMockSocket('socket-2', 'user-2')

      await socketServer.handleConnection(socket1 as any)
      await socketServer.handleConnection(socket2 as any)

      const roomId = 'cursor-room'
      await socketServer.joinRoom(socket1 as any, { roomId, roomType: 'content' })
      await socketServer.joinRoom(socket2 as any, { roomId, roomType: 'content' })

      await socketServer.updateCursor(socket1 as any, {
        roomId,
        x: 100,
        y: 200,
        elementId: 'text-editor-1'
      })

      expect(mockSocketIOServer.to).toHaveBeenCalledWith(roomId)
      expect(mockSocketIOServer.emit).toHaveBeenCalledWith('cursor_update', {
        userId: 'user-1',
        username: 'user-user-1',
        cursor: {
          x: 100,
          y: 200,
          elementId: 'text-editor-1',
          roomId
        },
        timestamp: expect.any(Date)
      })
    })

    test('should handle collaborative document editing', async () => {
      const socket1 = createMockSocket('socket-1', 'user-1')
      const socket2 = createMockSocket('socket-2', 'user-2')

      await socketServer.handleConnection(socket1 as any)
      await socketServer.handleConnection(socket2 as any)

      const roomId = 'doc-edit-room'
      await socketServer.joinRoom(socket1 as any, { roomId, roomType: 'content' })
      await socketServer.joinRoom(socket2 as any, { roomId, roomType: 'content' })

      const operation = {
        type: 'text_insert',
        position: 45,
        content: 'Hello World',
        documentId: 'doc-123',
        version: 5
      }

      await socketServer.handleDocumentOperation(socket1 as any, {
        roomId,
        operation
      })

      expect(mockSocketIOServer.to).toHaveBeenCalledWith(roomId)
      expect(mockSocketIOServer.emit).toHaveBeenCalledWith('document_operation', {
        userId: 'user-1',
        operation,
        timestamp: expect.any(Date)
      })
    })

    test('should resolve operation conflicts using operational transform', async () => {
      const conflictingOperations = [
        {
          userId: 'user-1',
          type: 'text_insert',
          position: 10,
          content: 'Hello',
          version: 1
        },
        {
          userId: 'user-2', 
          type: 'text_delete',
          position: 8,
          length: 5,
          version: 1
        }
      ]

      const resolved = await socketServer.resolveOperationConflicts(
        'doc-123',
        conflictingOperations
      )

      expect(resolved).toHaveLength(2)
      expect(resolved[0].position).not.toBe(10) // Position should be transformed
      expect(resolved[1].position).not.toBe(8)  // Position should be transformed
    })

    test('should handle document locking and unlock', async () => {
      const socket = createMockSocket('socket-123', 'user-456')
      await socketServer.handleConnection(socket as any)

      const documentId = 'doc-lock-test'

      // Lock document
      const lockResult = await socketServer.lockDocument(socket as any, {
        documentId,
        lockType: 'exclusive'
      })

      expect(lockResult.success).toBe(true)
      expect(lockResult.lockId).toBeDefined()

      // Try to lock same document with different user - should fail
      const socket2 = createMockSocket('socket-456', 'user-789')
      await socketServer.handleConnection(socket2 as any)

      const lockResult2 = await socketServer.lockDocument(socket2 as any, {
        documentId,
        lockType: 'exclusive'
      })

      expect(lockResult2.success).toBe(false)
      expect(lockResult2.error).toContain('already locked')

      // Unlock document
      await socketServer.unlockDocument(socket as any, {
        documentId,
        lockId: lockResult.lockId
      })

      // Now second user should be able to lock
      const lockResult3 = await socketServer.lockDocument(socket2 as any, {
        documentId,
        lockType: 'exclusive'
      })

      expect(lockResult3.success).toBe(true)
    })
  })

  describe('Notification Integration', () => {
    test('should deliver real-time notifications', async () => {
      const socket = createMockSocket('socket-123', 'user-456')
      await socketServer.handleConnection(socket as any)

      const notification = {
        id: 'notif-123',
        type: 'approval_request',
        title: 'New Approval Required',
        message: 'Please approve the campaign',
        recipientId: 'user-456',
        priority: 'high'
      }

      await socketServer.deliverNotification(notification)

      expect(socket.emit).toHaveBeenCalledWith('notification', {
        ...notification,
        deliveredAt: expect.any(Date)
      })

      // Should also update notification status in database
      expect(mockPrismaClient.notification.update).toHaveBeenCalledWith({
        where: { id: 'notif-123' },
        data: {
          deliveredViaSocket: true,
          deliveredAt: expect.any(Date)
        }
      })
    })

    test('should queue notifications for offline users', async () => {
      const notification = {
        id: 'notif-offline-123',
        recipientId: 'offline-user',
        type: 'comment',
        title: 'New Comment',
        message: 'Someone commented on your post'
      }

      await socketServer.deliverNotification(notification)

      // Should queue for offline user
      const queue = socketServer.getOfflineNotificationQueue('offline-user')
      expect(queue).toContainEqual(
        expect.objectContaining({
          id: 'notif-offline-123'
        })
      )
    })

    test('should deliver queued notifications when user comes online', async () => {
      // Queue some notifications for offline user
      const notifications = [
        { id: 'notif-1', recipientId: 'user-coming-online', title: 'Notification 1' },
        { id: 'notif-2', recipientId: 'user-coming-online', title: 'Notification 2' }
      ]

      for (const notif of notifications) {
        await socketServer.deliverNotification(notif)
      }

      // User comes online
      const socket = createMockSocket('socket-123', 'user-coming-online')
      await socketServer.handleConnection(socket as any)

      // Should deliver all queued notifications
      expect(socket.emit).toHaveBeenCalledWith('notification', 
        expect.objectContaining({ id: 'notif-1' })
      )
      expect(socket.emit).toHaveBeenCalledWith('notification',
        expect.objectContaining({ id: 'notif-2' })
      )

      // Queue should be cleared
      const queue = socketServer.getOfflineNotificationQueue('user-coming-online')
      expect(queue).toHaveLength(0)
    })
  })

  describe('Performance and Scalability', () => {
    test('should handle high concurrent connections', async () => {
      const connections = []
      const startTime = Date.now()

      // Create 1000 concurrent connections
      for (let i = 0; i < 1000; i++) {
        const socket = createMockSocket(`socket-${i}`, `user-${i}`)
        connections.push(socketServer.handleConnection(socket as any))
      }

      await Promise.all(connections)
      const endTime = Date.now()

      expect(endTime - startTime).toBeLessThan(5000) // Should handle in under 5 seconds
      expect(socketServer.getConnectedUsers()).toHaveLength(1000)
    })

    test('should efficiently broadcast to large rooms', async () => {
      const roomId = 'large-broadcast-room'
      const userCount = 500

      // Connect many users to same room
      const sockets = []
      for (let i = 0; i < userCount; i++) {
        const socket = createMockSocket(`socket-${i}`, `user-${i}`)
        await socketServer.handleConnection(socket as any)
        await socketServer.joinRoom(socket as any, { roomId, roomType: 'workspace' })
        sockets.push(socket)
      }

      const startTime = Date.now()
      
      await socketServer.broadcastMessage({
        id: 'broadcast-msg',
        type: 'system',
        roomId,
        senderId: 'system',
        content: { text: 'System announcement' },
        timestamp: new Date()
      })

      const endTime = Date.now()

      expect(endTime - startTime).toBeLessThan(1000) // Should broadcast quickly
      expect(mockSocketIOServer.to).toHaveBeenCalledWith(roomId)
    })

    test('should handle memory cleanup for disconnected users', async () => {
      // Connect users
      const sockets = []
      for (let i = 0; i < 100; i++) {
        const socket = createMockSocket(`socket-${i}`, `user-${i}`)
        await socketServer.handleConnection(socket as any)
        sockets.push(socket)
      }

      expect(socketServer.getConnectedUsers()).toHaveLength(100)

      // Disconnect all users
      for (const socket of sockets) {
        await socketServer.handleDisconnection(socket as any, 'client disconnect')
      }

      // Run cleanup
      await socketServer.runCleanupTasks()

      expect(socketServer.getConnectedUsers()).toHaveLength(0)
      expect(socketServer.getActiveRooms()).toHaveLength(0)
    })

    test('should implement connection throttling', async () => {
      const ipAddress = '192.168.1.100'
      
      // Attempt many connections from same IP rapidly
      const connectionAttempts = []
      for (let i = 0; i < 50; i++) {
        const socket = createMockSocket(`socket-spam-${i}`, `user-spam-${i}`)
        socket.handshake.address = ipAddress
        
        connectionAttempts.push(socketServer.handleConnection(socket as any))
      }

      const results = await Promise.allSettled(connectionAttempts)
      const rejected = results.filter(r => r.status === 'rejected')
      
      expect(rejected.length).toBeGreaterThan(0) // Some should be throttled
    })
  })

  describe('Error Handling and Edge Cases', () => {
    test('should handle malformed socket messages', async () => {
      const socket = createMockSocket('socket-123', 'user-456')
      await socketServer.handleConnection(socket as any)

      const malformedMessages = [
        null,
        undefined,
        '',
        { /* missing required fields */ },
        { type: 'invalid-type' },
        { roomId: 'non-existent-room' }
      ]

      for (const message of malformedMessages) {
        const result = await socketServer.handleIncomingMessage(socket as any, message)
        expect(result.success).toBe(false)
        expect(result.error).toBeDefined()
      }

      expect(socket.emit).toHaveBeenCalledWith('error', expect.any(Object))
    })

    test('should handle database connection failures', async () => {
      mockPrismaClient.realtimeSession.create.mockRejectedValueOnce(
        new Error('Database connection failed')
      )

      const socket = createMockSocket('socket-123', 'user-456')
      
      await socketServer.handleConnection(socket as any)

      // Should still allow connection even if DB fails
      expect(socketServer.getConnectedUser('user-456')).toBeDefined()
      
      // Should log error
      expect(socket.emit).toHaveBeenCalledWith('warning', {
        message: 'Session not persisted due to database error'
      })
    })

    test('should handle socket disconnection edge cases', async () => {
      const socket = createMockSocket('socket-123', 'user-456')
      socket.disconnect = vi.fn().mockImplementation(() => {
        throw new Error('Disconnect failed')
      })

      await socketServer.handleConnection(socket as any)

      // Should handle disconnect error gracefully
      await expect(
        socketServer.handleDisconnection(socket as any, 'transport error')
      ).not.toThrow()

      // User should still be cleaned up from memory
      expect(socketServer.getConnectedUser('user-456')).toBeUndefined()
    })

    test('should handle room operation failures', async () => {
      const socket = createMockSocket('socket-123', 'user-456')
      await socketServer.handleConnection(socket as any)

      // Mock room join failure
      socket.join = vi.fn().mockImplementation(() => {
        throw new Error('Failed to join room')
      })

      const result = await socketServer.joinRoom(socket as any, {
        roomId: 'failing-room',
        roomType: 'content'
      })

      expect(result.success).toBe(false)
      expect(result.error).toContain('Failed to join room')
    })

    test('should handle memory pressure and cleanup', async () => {
      // Simulate memory pressure
      const originalMemoryUsage = process.memoryUsage
      process.memoryUsage = vi.fn().mockReturnValue({
        heapUsed: 1024 * 1024 * 1024 * 1.5, // 1.5GB
        heapTotal: 1024 * 1024 * 1024 * 2,   // 2GB
        external: 0,
        arrayBuffers: 0,
        rss: 0
      })

      await socketServer.checkMemoryPressure()

      // Should trigger cleanup
      expect(socketServer.getMessageHistoryCache().size).toBeLessThan(100)

      // Restore
      process.memoryUsage = originalMemoryUsage
    })
  })

  describe('Security', () => {
    test('should validate user permissions for room access', async () => {
      const socket = createMockSocket('socket-123', 'user-viewer')
      socket.userRole = 'viewer'
      await socketServer.handleConnection(socket as any)

      // Try to join admin-only room
      const result = await socketServer.joinRoom(socket as any, {
        roomId: 'admin-only-room',
        roomType: 'workspace'
      })

      expect(result.success).toBe(false)
      expect(result.error).toContain('permission')
    })

    test('should sanitize and validate message content', async () => {
      const socket = createMockSocket('socket-123', 'user-456')
      await socketServer.handleConnection(socket as any)

      const roomId = 'secure-room'
      await socketServer.joinRoom(socket as any, { roomId, roomType: 'content' })

      const dangerousMessage = {
        type: 'chat',
        roomId,
        content: {
          text: '<script>alert("XSS")</script>',
          html: '<img src="x" onerror="steal_cookies()">',
          data: { secretKey: 'should-be-filtered' }
        }
      }

      const result = await socketServer.sendMessage(socket as any, dangerousMessage)

      expect(result.success).toBe(true)
      expect(result.sanitizedContent.text).not.toContain('<script>')
      expect(result.sanitizedContent.html).not.toContain('onerror')
    })

    test('should prevent message injection attacks', async () => {
      const socket = createMockSocket('socket-123', 'user-attacker')
      await socketServer.handleConnection(socket as any)

      const roomId = 'target-room'
      await socketServer.joinRoom(socket as any, { roomId, roomType: 'content' })

      const injectionMessage = {
        type: 'chat',
        roomId,
        senderId: 'impersonated-user', // Trying to impersonate
        content: { text: 'I am someone else' }
      }

      const result = await socketServer.sendMessage(socket as any, injectionMessage)

      expect(result.message.senderId).toBe('user-attacker') // Should use actual socket user
    })

    test('should implement message size limits', async () => {
      const socket = createMockSocket('socket-123', 'user-456')
      await socketServer.handleConnection(socket as any)

      const roomId = 'size-limited-room'
      await socketServer.joinRoom(socket as any, { roomId, roomType: 'content' })

      const oversizedMessage = {
        type: 'chat',
        roomId,
        content: {
          text: 'x'.repeat(10000) // 10KB message
        }
      }

      const result = await socketServer.sendMessage(socket as any, oversizedMessage)

      expect(result.success).toBe(false)
      expect(result.error).toContain('size limit')
    })
  })
})