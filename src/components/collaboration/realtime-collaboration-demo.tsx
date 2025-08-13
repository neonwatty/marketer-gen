'use client'

import React, { useState, useEffect, useRef } from 'react'
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Textarea } from '@/components/ui/textarea'
import { Badge } from '@/components/ui/badge'
import { Avatar, AvatarFallback, AvatarImage } from '@/components/ui/avatar'
import { Tabs, TabsContent, TabsList, TabsTrigger } from '@/components/ui/tabs'
import { useWebSocket } from '@/hooks/useWebSocket'
import { useRealtimePresence } from '@/hooks/useRealtimePresence'
import { useCollaborativeEditing } from '@/hooks/useCollaborativeEditing'
import { useRealtimeNotifications } from '@/hooks/useRealtimeNotifications'
import { 
  Users, 
  MessageCircle, 
  Bell, 
  Eye, 
  Edit3, 
  Wifi, 
  WifiOff,
  Volume2,
  VolumeX,
  Settings,
  Circle
} from 'lucide-react'

export interface RealtimeCollaborationDemoProps {
  currentUser: {
    userId: string
    username: string
    avatar?: string
    role: string
  }
  roomId?: string
  documentId?: string
}

export const RealtimeCollaborationDemo: React.FC<RealtimeCollaborationDemoProps> = ({
  currentUser,
  roomId = 'demo-room',
  documentId = 'demo-document'
}) => {
  const [message, setMessage] = useState('')
  const [connectionStatus, setConnectionStatus] = useState<'connecting' | 'connected' | 'disconnected'>('connecting')
  const messagesEndRef = useRef<HTMLDivElement>(null)

  // WebSocket connection
  const {
    isConnected,
    isAuthenticated,
    authenticate,
    joinRoom,
    sendMessage: sendSocketMessage,
    on,
    off
  } = useWebSocket()

  // Real-time presence
  const {
    onlineUsers,
    currentPresence,
    updatePresence,
    startTyping,
    stopTyping,
    getUsersInRoom,
    getTypingUsersInRoom
  } = useRealtimePresence(currentUser)

  // Collaborative editing
  const {
    documentState,
    insertText,
    updateCursorPosition,
    getCursorsInDocument,
    canEdit
  } = useCollaborativeEditing({
    documentId,
    roomId,
    enableCursors: true,
    enableSelections: true
  })

  // Real-time notifications
  const {
    notifications,
    unreadCount,
    settings,
    markAsRead,
    clearAll,
    updateSettings,
    requestPermission
  } = useRealtimeNotifications()

  const [messages, setMessages] = useState<Array<{
    id: string
    sender: string
    content: string
    timestamp: Date
    type: 'chat' | 'system'
  }>>([])

  // Connection management
  useEffect(() => {
    if (isConnected && !isAuthenticated) {
      authenticate(currentUser)
    }
  }, [isConnected, isAuthenticated, authenticate, currentUser])

  useEffect(() => {
    if (isAuthenticated) {
      joinRoom({
        roomId,
        roomType: 'collaboration',
        targetId: documentId
      })
      setConnectionStatus('connected')
    }
  }, [isAuthenticated, joinRoom, roomId, documentId])

  useEffect(() => {
    if (!isConnected) {
      setConnectionStatus('disconnected')
    }
  }, [isConnected])

  // Message handling
  useEffect(() => {
    const handleNewMessage = (data: any) => {
      if (data.type === 'chat') {
        setMessages(prev => [...prev, {
          id: data.id,
          sender: data.metadata?.senderName || 'Unknown',
          content: data.content,
          timestamp: new Date(data.timestamp),
          type: 'chat'
        }])
      }
    }

    const handleUserJoined = (data: any) => {
      setMessages(prev => [...prev, {
        id: `system-${Date.now()}`,
        sender: 'System',
        content: `${data.username} joined the room`,
        timestamp: new Date(),
        type: 'system'
      }])
    }

    const handleUserLeft = (data: any) => {
      setMessages(prev => [...prev, {
        id: `system-${Date.now()}`,
        sender: 'System',
        content: `${data.username} left the room`,
        timestamp: new Date(),
        type: 'system'
      }])
    }

    if (isConnected) {
      const unsubscribers = [
        on('new_message', handleNewMessage),
        on('user_joined_room', handleUserJoined),
        on('user_left_room', handleUserLeft)
      ]

      return () => {
        unsubscribers.forEach(unsub => unsub())
      }
    }
  }, [isConnected, on])

  // Auto-scroll messages
  useEffect(() => {
    messagesEndRef.current?.scrollIntoView({ behavior: 'smooth' })
  }, [messages])

  // Send chat message
  const handleSendMessage = () => {
    if (message.trim() && isAuthenticated) {
      sendSocketMessage({
        roomId,
        type: 'chat',
        content: message.trim()
      })
      setMessage('')
      stopTyping(roomId)
    }
  }

  // Handle typing
  const handleTypingStart = () => {
    startTyping(roomId)
  }

  const handleTypingStop = () => {
    stopTyping(roomId)
  }

  // Handle text input for collaborative editing
  const handleTextChange = (e: React.ChangeEvent<HTMLTextAreaElement>) => {
    const value = e.target.value
    const prevLength = documentState.content.length
    const newLength = value.length
    
    if (newLength > prevLength) {
      // Text was inserted
      const insertPos = e.target.selectionStart - (newLength - prevLength)
      const insertedText = value.slice(insertPos, e.target.selectionStart)
      insertText(insertPos, insertedText)
    }
    // Handle deletions and other changes...
  }

  // Handle cursor movement
  const handleCursorMove = (e: React.MouseEvent) => {
    const rect = e.currentTarget.getBoundingClientRect()
    const x = e.clientX - rect.left
    const y = e.clientY - rect.top
    updateCursorPosition(x, y)
  }

  const roomParticipants = getUsersInRoom(roomId)
  const typingUsers = getTypingUsersInRoom(roomId)
  const cursors = getCursorsInDocument()

  const getPresenceColor = (presence: string) => {
    switch (presence) {
      case 'online': return 'bg-green-500'
      case 'away': return 'bg-yellow-500'
      case 'busy': return 'bg-red-500'
      default: return 'bg-gray-500'
    }
  }

  return (
    <div className="space-y-6">
      {/* Header */}
      <Card>
        <CardHeader>
          <div className="flex items-center justify-between">
            <div>
              <CardTitle className="flex items-center gap-2">
                <Users className="h-5 w-5" />
                Real-Time Collaboration Demo
              </CardTitle>
              <CardDescription>
                Experience live presence, messaging, and collaborative editing
              </CardDescription>
            </div>
            
            <div className="flex items-center gap-2">
              <Badge variant={connectionStatus === 'connected' ? 'default' : 'destructive'}>
                {connectionStatus === 'connected' ? (
                  <>
                    <Wifi className="h-3 w-3 mr-1" />
                    Connected
                  </>
                ) : (
                  <>
                    <WifiOff className="h-3 w-3 mr-1" />
                    {connectionStatus}
                  </>
                )}
              </Badge>
              
              {unreadCount > 0 && (
                <Badge variant="destructive">
                  <Bell className="h-3 w-3 mr-1" />
                  {unreadCount}
                </Badge>
              )}
            </div>
          </div>
        </CardHeader>
      </Card>

      <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
        {/* Main Collaboration Area */}
        <div className="lg:col-span-2 space-y-6">
          <Tabs defaultValue="editing" className="w-full">
            <TabsList>
              <TabsTrigger value="editing">Collaborative Editing</TabsTrigger>
              <TabsTrigger value="chat">Team Chat</TabsTrigger>
            </TabsList>

            <TabsContent value="editing" className="space-y-4">
              <Card>
                <CardHeader>
                  <CardTitle className="flex items-center gap-2">
                    <Edit3 className="h-4 w-4" />
                    Shared Document
                    <Badge variant="outline">{documentState.version} edits</Badge>
                  </CardTitle>
                  <CardDescription>
                    Multiple users can edit simultaneously with real-time sync
                  </CardDescription>
                </CardHeader>
                <CardContent>
                  <div className="relative">
                    <Textarea
                      value={documentState.content}
                      onChange={handleTextChange}
                      onMouseMove={handleCursorMove}
                      placeholder="Start typing to see collaborative editing in action..."
                      className="min-h-[300px] font-mono"
                      disabled={!canEdit}
                    />
                    
                    {/* Live cursors */}
                    {cursors.map(cursor => (
                      <div
                        key={cursor.userId}
                        className="absolute pointer-events-none"
                        style={{
                          left: cursor.x,
                          top: cursor.y,
                          transform: 'translate(-50%, -50%)'
                        }}
                      >
                        <div 
                          className="w-2 h-2 rounded-full"
                          style={{ backgroundColor: cursor.color }}
                        />
                        <div 
                          className="absolute top-2 left-2 text-xs px-1 py-0.5 rounded text-white whitespace-nowrap"
                          style={{ backgroundColor: cursor.color }}
                        >
                          {cursor.username}
                        </div>
                      </div>
                    ))}
                  </div>
                  
                  {!canEdit && (
                    <p className="text-sm text-muted-foreground mt-2">
                      Connect to enable collaborative editing
                    </p>
                  )}
                </CardContent>
              </Card>
            </TabsContent>

            <TabsContent value="chat" className="space-y-4">
              <Card>
                <CardHeader>
                  <CardTitle className="flex items-center gap-2">
                    <MessageCircle className="h-4 w-4" />
                    Team Chat
                  </CardTitle>
                </CardHeader>
                <CardContent>
                  {/* Messages */}
                  <div className="border rounded-lg p-4 h-[300px] overflow-y-auto mb-4 space-y-2">
                    {messages.map((msg) => (
                      <div 
                        key={msg.id} 
                        className={`flex gap-2 ${msg.type === 'system' ? 'justify-center' : ''}`}
                      >
                        {msg.type === 'chat' && (
                          <Avatar className="h-6 w-6">
                            <AvatarFallback className="text-xs">
                              {msg.sender.charAt(0)}
                            </AvatarFallback>
                          </Avatar>
                        )}
                        <div className={msg.type === 'system' ? 'text-center' : ''}>
                          <div className={`text-sm ${msg.type === 'system' ? 'text-muted-foreground italic' : ''}`}>
                            {msg.type === 'chat' && (
                              <span className="font-medium">{msg.sender}: </span>
                            )}
                            {msg.content}
                          </div>
                          <div className="text-xs text-muted-foreground">
                            {msg.timestamp.toLocaleTimeString()}
                          </div>
                        </div>
                      </div>
                    ))}
                    
                    {/* Typing indicators */}
                    {typingUsers.length > 0 && (
                      <div className="flex items-center gap-2 text-sm text-muted-foreground italic">
                        <div className="flex space-x-1">
                          <Circle className="h-2 w-2 animate-bounce" />
                          <Circle className="h-2 w-2 animate-bounce" style={{ animationDelay: '0.1s' }} />
                          <Circle className="h-2 w-2 animate-bounce" style={{ animationDelay: '0.2s' }} />
                        </div>
                        {typingUsers.join(', ')} {typingUsers.length === 1 ? 'is' : 'are'} typing...
                      </div>
                    )}
                    
                    <div ref={messagesEndRef} />
                  </div>

                  {/* Message input */}
                  <div className="flex gap-2">
                    <Input
                      value={message}
                      onChange={(e) => setMessage(e.target.value)}
                      onKeyDown={(e) => {
                        if (e.key === 'Enter' && !e.shiftKey) {
                          e.preventDefault()
                          handleSendMessage()
                        } else if (e.key === 'Backspace' && message === '') {
                          handleTypingStop()
                        } else {
                          handleTypingStart()
                        }
                      }}
                      placeholder="Type a message..."
                      disabled={!isAuthenticated}
                    />
                    <Button 
                      onClick={handleSendMessage}
                      disabled={!message.trim() || !isAuthenticated}
                    >
                      Send
                    </Button>
                  </div>
                </CardContent>
              </Card>
            </TabsContent>
          </Tabs>
        </div>

        {/* Sidebar */}
        <div className="space-y-6">
          {/* Online Users */}
          <Card>
            <CardHeader>
              <CardTitle className="flex items-center gap-2">
                <Users className="h-4 w-4" />
                Online Users ({onlineUsers.length})
              </CardTitle>
            </CardHeader>
            <CardContent>
              <div className="space-y-2">
                {onlineUsers.map((user) => (
                  <div key={user.userId} className="flex items-center gap-2 p-2 rounded border">
                    <div className="relative">
                      <Avatar className="h-8 w-8">
                        <AvatarImage src={user.avatar} />
                        <AvatarFallback>{user.username.charAt(0)}</AvatarFallback>
                      </Avatar>
                      <div 
                        className={`absolute -bottom-1 -right-1 w-3 h-3 rounded-full border-2 border-white ${getPresenceColor(user.presence)}`}
                      />
                    </div>
                    <div className="flex-1">
                      <div className="text-sm font-medium">{user.username}</div>
                      <div className="text-xs text-muted-foreground capitalize">
                        {user.presence}
                      </div>
                    </div>
                  </div>
                ))}
                
                {onlineUsers.length === 0 && (
                  <p className="text-sm text-muted-foreground text-center py-4">
                    No users online
                  </p>
                )}
              </div>
            </CardContent>
          </Card>

          {/* Presence Controls */}
          <Card>
            <CardHeader>
              <CardTitle className="flex items-center gap-2">
                <Eye className="h-4 w-4" />
                Your Presence
              </CardTitle>
            </CardHeader>
            <CardContent>
              <div className="space-y-2">
                {(['online', 'away', 'busy', 'invisible'] as const).map((status) => (
                  <Button
                    key={status}
                    variant={currentPresence === status ? 'default' : 'outline'}
                    size="sm"
                    onClick={() => updatePresence(status)}
                    className="w-full justify-start"
                  >
                    <div className={`w-2 h-2 rounded-full mr-2 ${getPresenceColor(status)}`} />
                    {status.charAt(0).toUpperCase() + status.slice(1)}
                  </Button>
                ))}
              </div>
            </CardContent>
          </Card>

          {/* Notifications */}
          <Card>
            <CardHeader>
              <CardTitle className="flex items-center justify-between">
                <div className="flex items-center gap-2">
                  <Bell className="h-4 w-4" />
                  Notifications
                </div>
                {unreadCount > 0 && (
                  <Badge variant="destructive">{unreadCount}</Badge>
                )}
              </CardTitle>
            </CardHeader>
            <CardContent>
              <div className="space-y-2">
                {notifications.slice(0, 5).map((notification) => (
                  <div 
                    key={notification.id}
                    className={`p-2 rounded border text-sm ${
                      notification.read ? 'opacity-60' : 'border-primary'
                    }`}
                    onClick={() => markAsRead(notification.id)}
                  >
                    <div className="font-medium">{notification.title}</div>
                    <div className="text-muted-foreground">{notification.message}</div>
                    <div className="text-xs text-muted-foreground mt-1">
                      {notification.timestamp.toLocaleTimeString()}
                    </div>
                  </div>
                ))}
                
                {notifications.length === 0 && (
                  <p className="text-sm text-muted-foreground text-center py-4">
                    No notifications
                  </p>
                )}
                
                {notifications.length > 0 && (
                  <div className="flex gap-2 pt-2">
                    <Button size="sm" variant="outline" onClick={clearAll}>
                      Clear All
                    </Button>
                    <Button 
                      size="sm" 
                      variant="outline" 
                      onClick={requestPermission}
                    >
                      <Settings className="h-3 w-3 mr-1" />
                      Enable Desktop
                    </Button>
                  </div>
                )}
              </div>
            </CardContent>
          </Card>
        </div>
      </div>
    </div>
  )
}

export default RealtimeCollaborationDemo