import { createConsumer } from '@rails/actioncable';
import type {
  ConnectionConfig,
  ConnectionState,
  MessageQueue,
  WebSocketMessage,
  RateLimitConfig,
  CollaborationError,
  ErrorHandler,
  CollaborationEvents,
  ChannelSubscription
} from '../types/collaboration';

class CollaborationWebSocket {
  private consumer: ReturnType<typeof createConsumer>;
  private subscriptions: Map<string, ChannelSubscription> = new Map();
  private connectionState: ConnectionState;
  private messageQueue: MessageQueue;
  private rateLimits: RateLimitConfig;
  private eventListeners: Map<keyof CollaborationEvents, Function[]> = new Map();
  private heartbeatInterval: NodeJS.Timeout | null = null;
  private errorHandler: ErrorHandler | null = null;

  constructor(
    private config: ConnectionConfig = {
      url: '/cable',
      reconnect_attempts: 10,
      reconnect_interval: 5000,
      heartbeat_interval: 30000,
      message_queue_size: 100
    }
  ) {
    this.connectionState = {
      status: 'disconnected',
      last_connected: null,
      reconnect_count: 0
    };

    this.messageQueue = {
      pending: [],
      failed: [],
      max_size: config.message_queue_size
    };

    this.rateLimits = {
      presence_updates: { max_requests: 30, window_ms: 60000, current_count: 0, reset_time: Date.now() + 60000 },
      content_updates: { max_requests: 100, window_ms: 60000, current_count: 0, reset_time: Date.now() + 60000 },
      cursor_movements: { max_requests: 60, window_ms: 60000, current_count: 0, reset_time: Date.now() + 60000 },
      comments: { max_requests: 20, window_ms: 60000, current_count: 0, reset_time: Date.now() + 60000 }
    };

    this.initializeConnection();
  }

  private initializeConnection(): void {
    try {
      this.consumer = createConsumer(this.config.url);
      this.setupConnectionCallbacks();
      this.startHeartbeat();
    } catch (error) {
      this.handleError({
        code: 'CONNECTION_INIT_FAILED',
        message: 'Failed to initialize WebSocket connection',
        details: error,
        recoverable: true,
        timestamp: new Date().toISOString()
      });
    }
  }

  private setupConnectionCallbacks(): void {
    // ActionCable doesn't expose connection events directly, 
    // so we'll track status through subscription callbacks
    this.updateConnectionState('connecting');
  }

  private startHeartbeat(): void {
    if (this.heartbeatInterval) {
      clearInterval(this.heartbeatInterval);
    }

    this.heartbeatInterval = setInterval(() => {
      if (this.connectionState.status === 'connected') {
        this.sendMessage({
          id: this.generateMessageId(),
          type: 'heartbeat',
          channel: 'system',
          data: { timestamp: new Date().toISOString() },
          timestamp: new Date().toISOString(),
          retry_count: 0,
          max_retries: 0
        });
      }
    }, this.config.heartbeat_interval);
  }

  private updateConnectionState(status: ConnectionState['status'], error?: string): void {
    const previousStatus = this.connectionState.status;
    
    this.connectionState = {
      ...this.connectionState,
      status,
      error_message: error,
      last_connected: status === 'connected' ? new Date().toISOString() : this.connectionState.last_connected
    };

    if (status === 'connected' && previousStatus !== 'connected') {
      this.processPendingMessages();
    }

    this.emit('connection:status_changed', this.connectionState);
  }

  public subscribe(channel: string, params: Record<string, unknown> = {}): ChannelSubscription {
    const identifier = JSON.stringify({ channel, ...params });
    
    if (this.subscriptions.has(identifier)) {
      return this.subscriptions.get(identifier)!;
    }

    const actionCableSubscription = this.consumer.subscriptions.create(
      { channel, ...params },
      {
        connected: () => {
          const sub = this.subscriptions.get(identifier)!;
          sub.connected = true;
          this.updateConnectionState('connected');
        },
        
        disconnected: () => {
          const sub = this.subscriptions.get(identifier);
          if (sub) {
            sub.connected = false;
          }
          this.updateConnectionState('disconnected');
        },
        
        received: (data: Record<string, unknown>) => {
          this.handleReceivedMessage(identifier, data);
        }
      }
    );

    const channelSubscription: ChannelSubscription = {
      channel,
      identifier,
      connected: false,
      subscription_id: this.generateMessageId(),
      actionCableSubscription,
      callbacks: new Map()
    };

    this.subscriptions.set(identifier, channelSubscription);
    return channelSubscription;
  }

  public unsubscribe(identifier: string): void {
    const subscription = this.subscriptions.get(identifier);
    if (subscription) {
      this.consumer.subscriptions.remove(subscription);
      this.subscriptions.delete(identifier);
    }
  }

  private handleReceivedMessage(identifier: string, data: Record<string, unknown>): void {
    const subscription = this.subscriptions.get(identifier);
    if (!subscription) {return;}

    // Route message to appropriate event listeners
    if (data.type && this.eventListeners.has(data.type as keyof CollaborationEvents)) {
      const listeners = this.eventListeners.get(data.type as keyof CollaborationEvents) || [];
      listeners.forEach(listener => {
        try {
          listener(data);
        } catch (error) {
          this.handleError({
            code: 'MESSAGE_HANDLER_ERROR',
            message: 'Error in message handler',
            details: { data, error },
            recoverable: true,
            timestamp: new Date().toISOString()
          });
        }
      });
    }

    // Execute channel-specific callbacks
    const callbacks = subscription.callbacks.get(data.type) || [];
    callbacks.forEach(callback => {
      try {
        callback(data);
      } catch (error) {
        this.handleError({
          code: 'CALLBACK_ERROR',
          message: 'Error in subscription callback',
          details: { data, error },
          recoverable: true,
          timestamp: new Date().toISOString()
        });
      }
    });
  }

  public sendMessage(message: WebSocketMessage): Promise<void> {
    return new Promise((resolve, reject) => {
      // Check rate limits
      if (!this.checkRateLimit(message.type)) {
        reject(new Error('Rate limit exceeded'));
        return;
      }

      // Add to queue if not connected
      if (this.connectionState.status !== 'connected') {
        this.queueMessage(message);
        resolve();
        return;
      }

      try {
        const subscription = Array.from(this.subscriptions.values())
          .find(sub => sub.channel === message.channel);
        
        if (subscription) {
          this.consumer.subscriptions.subscriptions.forEach((sub: Record<string, unknown>) => {
            if (sub.identifier === subscription.identifier) {
              sub.perform('receive_message', message.data);
            }
          });
        }
        
        resolve();
      } catch (error) {
        this.queueMessage({ ...message, retry_count: message.retry_count + 1 });
        reject(error);
      }
    });
  }

  private checkRateLimit(messageType: string): boolean {
    const now = Date.now();
    let limitKey: keyof RateLimitConfig;

    // Map message types to rate limit categories
    switch (messageType) {
      case 'presence_update':
      case 'user_status':
        limitKey = 'presence_updates';
        break;
      case 'content_update':
      case 'operational_transform':
        limitKey = 'content_updates';
        break;
      case 'cursor_move':
      case 'selection_change':
        limitKey = 'cursor_movements';
        break;
      case 'comment_added':
        limitKey = 'comments';
        break;
      default:
        return true; // Allow unknown types
    }

    const limit = this.rateLimits[limitKey];
    
    // Reset counter if window has passed
    if (now >= limit.reset_time) {
      limit.current_count = 0;
      limit.reset_time = now + limit.window_ms;
    }

    // Check if under limit
    if (limit.current_count >= limit.max_requests) {
      return false;
    }

    limit.current_count++;
    return true;
  }

  private queueMessage(message: WebSocketMessage): void {
    if (this.messageQueue.pending.length >= this.messageQueue.max_size) {
      // Remove oldest message
      this.messageQueue.pending.shift();
    }

    this.messageQueue.pending.push(message);
  }

  private processPendingMessages(): void {
    const messages = [...this.messageQueue.pending];
    this.messageQueue.pending = [];

    messages.forEach(async (message) => {
      if (message.retry_count < message.max_retries) {
        try {
          await this.sendMessage(message);
        } catch {
          this.messageQueue.failed.push(message);
        }
      } else {
        this.messageQueue.failed.push(message);
      }
    });
  }

  public on<K extends keyof CollaborationEvents>(
    event: K,
    listener: (data: CollaborationEvents[K]) => void
  ): void {
    if (!this.eventListeners.has(event)) {
      this.eventListeners.set(event, []);
    }
    this.eventListeners.get(event)!.push(listener);
  }

  public off<K extends keyof CollaborationEvents>(
    event: K,
    listener: (data: CollaborationEvents[K]) => void
  ): void {
    const listeners = this.eventListeners.get(event);
    if (listeners) {
      const index = listeners.indexOf(listener);
      if (index > -1) {
        listeners.splice(index, 1);
      }
    }
  }

  private emit<K extends keyof CollaborationEvents>(
    event: K,
    data: CollaborationEvents[K]
  ): void {
    const listeners = this.eventListeners.get(event) || [];
    listeners.forEach(listener => {
      try {
        listener(data);
      } catch (error) {
        this.handleError({
          code: 'EVENT_LISTENER_ERROR',
          message: `Error in ${event} event listener`,
          details: { event, data, error },
          recoverable: true,
          timestamp: new Date().toISOString()
        });
      }
    });
  }

  private handleError(error: CollaborationError): void {
    console.error('CollaborationWebSocket Error:', error);
    
    if (this.errorHandler) {
      this.errorHandler(error);
    }

    // Auto-recovery for recoverable errors
    if (error.recoverable) {
      switch (error.code) {
        case 'CONNECTION_INIT_FAILED':
          setTimeout(() => this.initializeConnection(), this.config.reconnect_interval);
          break;
      }
    }
  }

  public setErrorHandler(handler: ErrorHandler): void {
    this.errorHandler = handler;
  }

  public getConnectionState(): ConnectionState {
    return { ...this.connectionState };
  }

  public getMessageQueue(): MessageQueue {
    return {
      pending: [...this.messageQueue.pending],
      failed: [...this.messageQueue.failed],
      max_size: this.messageQueue.max_size
    };
  }

  private generateMessageId(): string {
    return `msg_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;
  }

  public disconnect(): void {
    if (this.heartbeatInterval) {
      clearInterval(this.heartbeatInterval);
    }

    this.subscriptions.forEach((_, identifier) => {
      this.unsubscribe(identifier);
    });

    if (this.consumer) {
      this.consumer.disconnect();
    }

    this.updateConnectionState('disconnected');
  }

  public reconnect(): void {
    this.disconnect();
    setTimeout(() => {
      this.connectionState.reconnect_count++;
      this.initializeConnection();
    }, this.config.reconnect_interval);
  }
}

// Singleton instance
let collaborationWebSocket: CollaborationWebSocket | null = null;

export const getCollaborationWebSocket = (config?: ConnectionConfig): CollaborationWebSocket => {
  if (!collaborationWebSocket) {
    collaborationWebSocket = new CollaborationWebSocket(config);
  }
  return collaborationWebSocket;
};

export const disconnectCollaborationWebSocket = (): void => {
  if (collaborationWebSocket) {
    collaborationWebSocket.disconnect();
    collaborationWebSocket = null;
  }
};

export default CollaborationWebSocket;