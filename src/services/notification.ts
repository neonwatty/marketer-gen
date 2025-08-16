/**
 * Notification service for managing in-app notifications and push notifications
 */

interface NotificationOptions {
  title: string
  message: string
  type?: 'info' | 'success' | 'warning' | 'error'
  duration?: number
  persistent?: boolean
  actions?: Array<{
    label: string
    action: () => void
  }>
}

interface PushNotificationOptions {
  title: string
  body: string
  icon?: string
  badge?: string
  tag?: string
  data?: any
  actions?: Array<{
    action: string
    title: string
    icon?: string
  }>
}

class NotificationService {
  private notifications: Map<string, NotificationOptions & { id: string; timestamp: number }> =
    new Map()
  private subscribers: Array<(notifications: NotificationOptions[]) => void> = []
  private pushSubscription: PushSubscription | null = null

  /**
   * Show an in-app notification
   */
  show(options: NotificationOptions): string {
    const id = this.generateId()
    const notification = {
      ...options,
      id,
      timestamp: Date.now(),
      duration: options.duration ?? (options.type === 'error' ? 0 : 5000),
    }

    this.notifications.set(id, notification)
    this.notifySubscribers()

    // Auto-remove after duration (if not persistent)
    if (notification.duration > 0 && !options.persistent) {
      setTimeout(() => {
        this.dismiss(id)
      }, notification.duration)
    }

    return id
  }

  /**
   * Show success notification
   */
  success(message: string, title?: string): string {
    return this.show({
      title: title || 'Success',
      message,
      type: 'success',
    })
  }

  /**
   * Show error notification
   */
  error(message: string, title?: string): string {
    return this.show({
      title: title || 'Error',
      message,
      type: 'error',
      persistent: true,
    })
  }

  /**
   * Show warning notification
   */
  warning(message: string, title?: string): string {
    return this.show({
      title: title || 'Warning',
      message,
      type: 'warning',
    })
  }

  /**
   * Show info notification
   */
  info(message: string, title?: string): string {
    return this.show({
      title: title || 'Information',
      message,
      type: 'info',
    })
  }

  /**
   * Dismiss a notification
   */
  dismiss(id: string): void {
    if (this.notifications.has(id)) {
      this.notifications.delete(id)
      this.notifySubscribers()
    }
  }

  /**
   * Dismiss all notifications
   */
  dismissAll(): void {
    this.notifications.clear()
    this.notifySubscribers()
  }

  /**
   * Get all active notifications
   */
  getAll(): NotificationOptions[] {
    return Array.from(this.notifications.values())
  }

  /**
   * Subscribe to notification changes
   */
  subscribe(callback: (notifications: NotificationOptions[]) => void): () => void {
    this.subscribers.push(callback)

    // Return unsubscribe function
    return () => {
      const index = this.subscribers.indexOf(callback)
      if (index > -1) {
        this.subscribers.splice(index, 1)
      }
    }
  }

  /**
   * Show an in-app notification (alias for show method)
   */
  showNotification(options: NotificationOptions): string {
    // Log to console in development
    if (process.env.NODE_ENV === 'development' || process.env.NODE_ENV === 'test') {
      if (options.type === 'error') {
        console.error(`${options.title}: ${options.message}`)
      } else {
        console.log(`${options.title}: ${options.message}`)
      }
    }
    return this.show(options)
  }

  /**
   * Request permission for notifications
   */
  async requestPermission(): Promise<NotificationPermission> {
    if (!('Notification' in window)) {
      return 'denied'
    }

    if (Notification.permission === 'granted') {
      return 'granted'
    }

    return await Notification.requestPermission()
  }

  /**
   * Clear all notifications (alias for dismissAll)
   */
  clearAll(): void {
    if (process.env.NODE_ENV === 'development' || process.env.NODE_ENV === 'test') {
      console.log('Clearing all notifications')
    }
    this.dismissAll()
  }

  /**
   * Request permission for push notifications
   */
  async requestPushPermission(): Promise<boolean> {
    if (!('Notification' in window) || !('serviceWorker' in navigator)) {
      console.warn('Push notifications are not supported')
      return false
    }

    const permission = await Notification.requestPermission()
    return permission === 'granted'
  }

  /**
   * Subscribe to push notifications
   */
  async subscribeToPush(): Promise<PushSubscription | null> {
    if (!('serviceWorker' in navigator) || !('PushManager' in window)) {
      console.warn('Push messaging is not supported')
      return null
    }

    try {
      const registration = await navigator.serviceWorker.ready

      const subscription = await registration.pushManager.subscribe({
        userVisibleOnly: true,
        applicationServerKey: this.urlBase64ToUint8Array(
          process.env.NEXT_PUBLIC_VAPID_PUBLIC_KEY || ''
        ),
      })

      this.pushSubscription = subscription

      // Send subscription to server
      await this.sendSubscriptionToServer(subscription)

      return subscription
    } catch (error) {
      console.error('Failed to subscribe to push notifications:', error)
      return null
    }
  }

  /**
   * Unsubscribe from push notifications
   */
  async unsubscribeFromPush(): Promise<boolean> {
    if (!this.pushSubscription) {
      return true
    }

    try {
      await this.pushSubscription.unsubscribe()

      // Remove subscription from server
      await this.removeSubscriptionFromServer(this.pushSubscription)

      this.pushSubscription = null
      return true
    } catch (error) {
      console.error('Failed to unsubscribe from push notifications:', error)
      return false
    }
  }

  /**
   * Show browser push notification
   */
  showPushNotification(options: PushNotificationOptions): void {
    if (!('Notification' in window)) {
      console.warn('Notifications are not supported')
      return
    }

    if (Notification.permission !== 'granted') {
      console.warn('Notification permission not granted')
      return
    }

    new Notification(options.title, {
      body: options.body,
      icon: options.icon || '/icon-192x192.png',
      badge: options.badge || '/badge-72x72.png',
      tag: options.tag,
      data: options.data,
    })
  }

  /**
   * Check if push notifications are supported
   */
  isPushSupported(): boolean {
    return 'serviceWorker' in navigator && 'PushManager' in window
  }

  /**
   * Check current notification permission
   */
  getPermissionStatus(): NotificationPermission | 'unsupported' {
    if (!('Notification' in window)) {
      return 'unsupported'
    }
    return Notification.permission
  }

  /**
   * Send subscription to server
   */
  private async sendSubscriptionToServer(subscription: PushSubscription): Promise<void> {
    try {
      await fetch('/api/push/subscribe', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify(subscription),
      })
    } catch (error) {
      console.error('Failed to send subscription to server:', error)
    }
  }

  /**
   * Remove subscription from server
   */
  private async removeSubscriptionFromServer(subscription: PushSubscription): Promise<void> {
    try {
      await fetch('/api/push/unsubscribe', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify(subscription),
      })
    } catch (error) {
      console.error('Failed to remove subscription from server:', error)
    }
  }

  /**
   * Convert VAPID key to Uint8Array
   */
  private urlBase64ToUint8Array(base64String: string): ArrayBuffer {
    const padding = '='.repeat((4 - (base64String.length % 4)) % 4)
    const base64 = (base64String + padding).replace(/-/g, '+').replace(/_/g, '/')

    const rawData = window.atob(base64)
    const outputArray = new Uint8Array(rawData.length)

    for (let i = 0; i < rawData.length; ++i) {
      outputArray[i] = rawData.charCodeAt(i)
    }

    return outputArray.buffer
  }

  /**
   * Generate unique notification ID
   */
  private generateId(): string {
    return `notification_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`
  }

  /**
   * Notify all subscribers of notification changes
   */
  private notifySubscribers(): void {
    const notifications = this.getAll()
    this.subscribers.forEach(callback => callback(notifications))
  }
}

export const notificationService = new NotificationService()
