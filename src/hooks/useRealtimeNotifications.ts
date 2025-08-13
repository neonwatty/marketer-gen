import { useState, useEffect, useCallback, useRef } from 'react'
import { useWebSocket } from './useWebSocket'

export interface RealtimeNotification {
  id: string
  type: 'info' | 'success' | 'warning' | 'error' | 'approval' | 'mention' | 'system'
  title: string
  message: string
  timestamp: Date
  read: boolean
  actions?: NotificationAction[]
  metadata?: Record<string, any>
  priority: 'low' | 'medium' | 'high' | 'urgent'
  expires?: Date
  persistent?: boolean
  sound?: boolean
  desktop?: boolean
}

export interface NotificationAction {
  id: string
  label: string
  type: 'primary' | 'secondary' | 'danger'
  action: () => void
}

export interface NotificationSettings {
  enabled: boolean
  sound: boolean
  desktop: boolean
  types: {
    approval: boolean
    mention: boolean
    system: boolean
    collaboration: boolean
  }
  quiet_hours: {
    enabled: boolean
    start: string // HH:mm format
    end: string   // HH:mm format
  }
}

export interface UseRealtimeNotificationsOptions {
  maxNotifications?: number
  autoRemoveAfter?: number // milliseconds
  enableSound?: boolean
  enableDesktop?: boolean
  defaultSettings?: Partial<NotificationSettings>
}

export function useRealtimeNotifications(options: UseRealtimeNotificationsOptions = {}) {
  const {
    maxNotifications = 100,
    autoRemoveAfter = 300000, // 5 minutes
    enableSound = true,
    enableDesktop = true,
    defaultSettings = {}
  } = options

  const { isConnected, isAuthenticated, on, off, emit } = useWebSocket()

  const [notifications, setNotifications] = useState<RealtimeNotification[]>([])
  const [settings, setSettings] = useState<NotificationSettings>({
    enabled: true,
    sound: enableSound,
    desktop: enableDesktop,
    types: {
      approval: true,
      mention: true,
      system: true,
      collaboration: true
    },
    quiet_hours: {
      enabled: false,
      start: '22:00',
      end: '08:00'
    },
    ...defaultSettings
  })

  const [unreadCount, setUnreadCount] = useState(0)
  const [permissionStatus, setPermissionStatus] = useState<NotificationPermission>('default')
  
  // Refs for managing audio and cleanup
  const audioRef = useRef<HTMLAudioElement | null>(null)
  const timeoutRefs = useRef<Map<string, NodeJS.Timeout>>(new Map())

  // Initialize notification sounds
  useEffect(() => {
    if (enableSound && typeof window !== 'undefined') {
      audioRef.current = new Audio('/sounds/notification.mp3') // You'd need to add this file
      audioRef.current.volume = 0.5
    }
  }, [enableSound])

  // Request desktop notification permission
  const requestPermission = useCallback(async () => {
    if ('Notification' in window) {
      const permission = await Notification.requestPermission()
      setPermissionStatus(permission)
      return permission
    }
    return 'denied'
  }, [])

  // Check permission status on mount
  useEffect(() => {
    if ('Notification' in window) {
      setPermissionStatus(Notification.permission)
    }
  }, [])

  // Handle incoming notifications
  const handleNotification = useCallback((data: Omit<RealtimeNotification, 'id' | 'read'>) => {
    if (!settings.enabled) return

    // Check if notification type is enabled
    const typeKey = data.type === 'approval' ? 'approval' : 
                   data.type === 'mention' ? 'mention' :
                   data.type === 'system' ? 'system' : 'collaboration'
    
    if (!settings.types[typeKey]) return

    // Check quiet hours
    if (settings.quiet_hours.enabled && isInQuietHours()) {
      // Only allow urgent notifications during quiet hours
      if (data.priority !== 'urgent') return
    }

    const notification: RealtimeNotification = {
      ...data,
      id: `notif_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`,
      read: false,
      timestamp: new Date()
    }

    setNotifications(prev => {
      const newNotifications = [notification, ...prev]
      
      // Limit number of notifications
      if (newNotifications.length > maxNotifications) {
        newNotifications.splice(maxNotifications)
      }
      
      return newNotifications
    })

    setUnreadCount(prev => prev + 1)

    // Play sound if enabled
    if (settings.sound && audioRef.current && notification.sound !== false) {
      try {
        audioRef.current.currentTime = 0
        audioRef.current.play().catch(console.warn)
      } catch (error) {
        console.warn('Could not play notification sound:', error)
      }
    }

    // Show desktop notification if enabled
    if (settings.desktop && permissionStatus === 'granted' && notification.desktop !== false) {
      showDesktopNotification(notification)
    }

    // Auto-remove notification if not persistent
    if (!notification.persistent && autoRemoveAfter > 0) {
      const timeout = setTimeout(() => {
        removeNotification(notification.id)
      }, autoRemoveAfter)
      
      timeoutRefs.current.set(notification.id, timeout)
    }
  }, [settings, permissionStatus, maxNotifications, autoRemoveAfter])

  // Handle approval-specific notifications
  const handleApprovalUpdate = useCallback((data: {
    requestId: string
    action: string
    stageId: string
    approverId: string
    approverName: string
    comment?: string
    timestamp: Date
  }) => {
    const notification = {
      type: 'approval' as const,
      title: 'Approval Update',
      message: `${data.approverName} ${data.action}d your request`,
      priority: 'medium' as const,
      metadata: {
        requestId: data.requestId,
        action: data.action,
        stageId: data.stageId,
        approverId: data.approverId
      },
      actions: [
        {
          id: 'view',
          label: 'View Request',
          type: 'primary' as const,
          action: () => {
            // Navigate to approval request
            window.location.href = `/approvals/${data.requestId}`
          }
        }
      ]
    }

    handleNotification(notification)
  }, [handleNotification])

  // Handle mention notifications
  const handleMention = useCallback((data: {
    messageId: string
    roomId: string
    mentionedBy: string
    context: string
  }) => {
    const notification = {
      type: 'mention' as const,
      title: 'You were mentioned',
      message: `${data.mentionedBy} mentioned you: "${data.context.substring(0, 100)}..."`,
      priority: 'high' as const,
      metadata: {
        messageId: data.messageId,
        roomId: data.roomId
      },
      actions: [
        {
          id: 'reply',
          label: 'Reply',
          type: 'primary' as const,
          action: () => {
            // Navigate to message or open reply dialog
            console.log('Reply to mention')
          }
        }
      ]
    }

    handleNotification(notification)
  }, [handleNotification])

  // Handle system notifications
  const handleSystemMessage = useCallback((data: {
    type: string
    title: string
    message: string
    priority: 'low' | 'medium' | 'high' | 'urgent'
    actions?: any[]
  }) => {
    const notification = {
      type: 'system' as const,
      title: data.title,
      message: data.message,
      priority: data.priority,
      persistent: data.priority === 'urgent',
      actions: data.actions
    }

    handleNotification(notification)
  }, [handleNotification])

  // Notification management functions
  const addNotification = useCallback((notification: Omit<RealtimeNotification, 'id' | 'read' | 'timestamp'>) => {
    handleNotification(notification)
  }, [handleNotification])

  const removeNotification = useCallback((id: string) => {
    setNotifications(prev => prev.filter(n => n.id !== id))
    
    // Clear timeout if exists
    const timeout = timeoutRefs.current.get(id)
    if (timeout) {
      clearTimeout(timeout)
      timeoutRefs.current.delete(id)
    }
  }, [])

  const markAsRead = useCallback((id: string) => {
    setNotifications(prev => prev.map(n => 
      n.id === id ? { ...n, read: true } : n
    ))
    
    setUnreadCount(prev => Math.max(0, prev - 1))
  }, [])

  const markAllAsRead = useCallback(() => {
    setNotifications(prev => prev.map(n => ({ ...n, read: true })))
    setUnreadCount(0)
  }, [])

  const clearAll = useCallback(() => {
    setNotifications([])
    setUnreadCount(0)
    
    // Clear all timeouts
    timeoutRefs.current.forEach(timeout => clearTimeout(timeout))
    timeoutRefs.current.clear()
  }, [])

  const clearRead = useCallback(() => {
    setNotifications(prev => {
      const unreadNotifications = prev.filter(n => !n.read)
      
      // Clear timeouts for removed notifications
      prev.filter(n => n.read).forEach(n => {
        const timeout = timeoutRefs.current.get(n.id)
        if (timeout) {
          clearTimeout(timeout)
          timeoutRefs.current.delete(n.id)
        }
      })
      
      return unreadNotifications
    })
  }, [])

  // Settings management
  const updateSettings = useCallback((newSettings: Partial<NotificationSettings>) => {
    setSettings(prev => ({ ...prev, ...newSettings }))
    
    // Persist settings to localStorage
    if (typeof window !== 'undefined') {
      localStorage.setItem('notification-settings', JSON.stringify({ ...settings, ...newSettings }))
    }
  }, [settings])

  // Load settings from localStorage
  useEffect(() => {
    if (typeof window !== 'undefined') {
      const saved = localStorage.getItem('notification-settings')
      if (saved) {
        try {
          const parsedSettings = JSON.parse(saved)
          setSettings(prev => ({ ...prev, ...parsedSettings }))
        } catch (error) {
          console.warn('Could not parse notification settings:', error)
        }
      }
    }
  }, [])

  // Helper functions
  const isInQuietHours = useCallback(() => {
    if (!settings.quiet_hours.enabled) return false
    
    const now = new Date()
    const currentTime = `${now.getHours().toString().padStart(2, '0')}:${now.getMinutes().toString().padStart(2, '0')}`
    
    const start = settings.quiet_hours.start
    const end = settings.quiet_hours.end
    
    if (start <= end) {
      return currentTime >= start && currentTime <= end
    } else {
      // Overnight quiet hours
      return currentTime >= start || currentTime <= end
    }
  }, [settings.quiet_hours])

  const showDesktopNotification = useCallback((notification: RealtimeNotification) => {
    if (permissionStatus !== 'granted') return

    try {
      const desktopNotif = new Notification(notification.title, {
        body: notification.message,
        icon: '/icons/notification-icon.png', // You'd need to add this file
        tag: notification.id,
        requireInteraction: notification.priority === 'urgent'
      })

      desktopNotif.onclick = () => {
        window.focus()
        markAsRead(notification.id)
        desktopNotif.close()
        
        // Execute first action if available
        if (notification.actions && notification.actions.length > 0) {
          notification.actions[0].action()
        }
      }

      // Auto-close after 5 seconds for non-urgent notifications
      if (notification.priority !== 'urgent') {
        setTimeout(() => desktopNotif.close(), 5000)
      }
    } catch (error) {
      console.warn('Could not show desktop notification:', error)
    }
  }, [permissionStatus, markAsRead])

  // Set up WebSocket event listeners
  useEffect(() => {
    if (!isConnected) return

    const unsubscribers = [
      on('notification', handleNotification),
      on('approval_update', handleApprovalUpdate),
      on('mention', handleMention),
      on('system_message', handleSystemMessage)
    ]

    return () => {
      unsubscribers.forEach(unsub => unsub())
    }
  }, [isConnected, on, handleNotification, handleApprovalUpdate, handleMention, handleSystemMessage])

  // Cleanup timeouts on unmount
  useEffect(() => {
    return () => {
      timeoutRefs.current.forEach(timeout => clearTimeout(timeout))
    }
  }, [])

  return {
    // State
    notifications,
    unreadCount,
    settings,
    permissionStatus,
    isQuietHours: isInQuietHours(),
    
    // Actions
    addNotification,
    removeNotification,
    markAsRead,
    markAllAsRead,
    clearAll,
    clearRead,
    updateSettings,
    requestPermission,
    
    // Helpers
    getUnreadNotifications: () => notifications.filter(n => !n.read),
    getNotificationsByType: (type: string) => notifications.filter(n => n.type === type),
    hasUnread: unreadCount > 0,
    canShowDesktop: permissionStatus === 'granted'
  }
}

export default useRealtimeNotifications