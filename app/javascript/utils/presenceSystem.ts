import type { UserPresence, User, CursorPosition } from '../types/collaboration';
import { getCollaborationWebSocket } from './collaborationWebSocket';

interface PresenceConfig {
  heartbeat_interval: number;
  idle_timeout: number;
  offline_timeout: number;
  cursor_throttle: number;
}

interface PresenceCallbacks {
  onUserJoined?: (presence: UserPresence) => void;
  onUserLeft?: (presence: UserPresence) => void;
  onUserStatusChanged?: (presence: UserPresence) => void;
  onCursorMoved?: (userId: number, position: CursorPosition) => void;
}

class PresenceSystem {
  private currentUser: User | null = null;
  private presenceData: Map<number, UserPresence> = new Map();
  private config: PresenceConfig;
  private callbacks: PresenceCallbacks = {};
  private heartbeatInterval: NodeJS.Timeout | null = null;
  private idleTimer: NodeJS.Timeout | null = null;
  private lastActivity: number = Date.now();
  private location: string = '';
  private websocket = getCollaborationWebSocket();

  constructor(config: Partial<PresenceConfig> = {}) {
    this.config = {
      heartbeat_interval: 30000, // 30 seconds
      idle_timeout: 300000,     // 5 minutes
      offline_timeout: 600000,  // 10 minutes
      cursor_throttle: 100,     // 100ms
      ...config
    };

    this.setupEventListeners();
    this.startHeartbeat();
    this.trackUserActivity();
  }

  public initialize(user: User, location: string): void {
    this.currentUser = user;
    this.location = location;
    
    // Create initial presence
    const presence: UserPresence = {
      user,
      status: 'online',
      last_seen: new Date().toISOString(),
      location
    };

    this.presenceData.set(user.id, presence);
    this.broadcastPresenceUpdate('user_joined', presence);
  }

  public updateLocation(location: string): void {
    this.location = location;
    if (this.currentUser) {
      const presence = this.presenceData.get(this.currentUser.id);
      if (presence) {
        presence.location = location;
        presence.last_seen = new Date().toISOString();
        this.presenceData.set(this.currentUser.id, presence);
        this.broadcastPresenceUpdate('user_status_changed', presence);
      }
    }
  }

  public updateCursorPosition(position: CursorPosition): void {
    if (!this.currentUser) {return;}

    const presence = this.presenceData.get(this.currentUser.id);
    if (presence) {
      presence.cursor_position = position;
      presence.last_seen = new Date().toISOString();
      this.presenceData.set(this.currentUser.id, presence);
      
      // Throttled cursor broadcasting
      this.throttledCursorBroadcast(position);
    }
  }

  private throttledCursorBroadcast = this.throttle((position: CursorPosition) => {
    if (this.currentUser) {
      this.websocket.sendMessage({
        id: this.generateMessageId(),
        type: 'cursor_move',
        channel: this.getChannelForLocation(),
        data: {
          user_id: this.currentUser.id,
          position
        },
        timestamp: new Date().toISOString(),
        retry_count: 0,
        max_retries: 1
      });
    }
  }, this.config.cursor_throttle);

  public setStatus(status: UserPresence['status']): void {
    if (!this.currentUser) {return;}

    const presence = this.presenceData.get(this.currentUser.id);
    if (presence && presence.status !== status) {
      presence.status = status;
      presence.last_seen = new Date().toISOString();
      this.presenceData.set(this.currentUser.id, presence);
      this.broadcastPresenceUpdate('user_status_changed', presence);
    }
  }

  public getPresenceData(): UserPresence[] {
    return Array.from(this.presenceData.values());
  }

  public getOnlineUsers(): UserPresence[] {
    return this.getPresenceData().filter(p => p.status === 'online');
  }

  public getUserPresence(userId: number): UserPresence | null {
    return this.presenceData.get(userId) || null;
  }

  public setCallbacks(callbacks: PresenceCallbacks): void {
    this.callbacks = { ...this.callbacks, ...callbacks };
  }

  private setupEventListeners(): void {
    this.websocket.on('user:joined', (data) => {
      const presence: UserPresence = {
        user: data.user,
        status: 'online',
        last_seen: data.timestamp,
        location: data.location
      };
      
      this.presenceData.set(data.user.id, presence);
      this.callbacks.onUserJoined?.(presence);
    });

    this.websocket.on('user:left', (data) => {
      const presence = this.presenceData.get(data.user.id);
      if (presence) {
        presence.status = 'offline';
        presence.last_seen = data.timestamp;
        this.presenceData.set(data.user.id, presence);
        this.callbacks.onUserLeft?.(presence);
      }
    });

    this.websocket.on('user:status_changed', (data) => {
      const presence = this.presenceData.get(data.user.id);
      if (presence) {
        presence.status = data.status;
        presence.last_seen = data.timestamp;
        presence.location = data.location;
        this.presenceData.set(data.user.id, presence);
        this.callbacks.onUserStatusChanged?.(presence);
      }
    });

    this.websocket.on('plan:cursor_moved', (data) => {
      if (data.user.id !== this.currentUser?.id) {
        this.callbacks.onCursorMoved?.(data.user.id, data.cursor_position);
      }
    });

    this.websocket.on('content:cursor_moved', (data) => {
      if (data.user.id !== this.currentUser?.id) {
        this.callbacks.onCursorMoved?.(data.user.id, data.cursor.position);
      }
    });
  }

  private startHeartbeat(): void {
    if (this.heartbeatInterval) {
      clearInterval(this.heartbeatInterval);
    }

    this.heartbeatInterval = setInterval(() => {
      this.sendHeartbeat();
      this.cleanupStalePresences();
      this.checkIdleStatus();
    }, this.config.heartbeat_interval);
  }

  private sendHeartbeat(): void {
    if (!this.currentUser) {return;}

    const presence = this.presenceData.get(this.currentUser.id);
    if (presence) {
      presence.last_seen = new Date().toISOString();
      this.presenceData.set(this.currentUser.id, presence);
      
      this.websocket.sendMessage({
        id: this.generateMessageId(),
        type: 'heartbeat',
        channel: this.getChannelForLocation(),
        data: {
          user: this.currentUser,
          status: presence.status,
          location: this.location,
          cursor_position: presence.cursor_position
        },
        timestamp: new Date().toISOString(),
        retry_count: 0,
        max_retries: 3
      });
    }
  }

  private cleanupStalePresences(): void {
    const now = Date.now();
    const staleUsers: number[] = [];

    this.presenceData.forEach((presence, userId) => {
      const lastSeen = new Date(presence.last_seen).getTime();
      const timeSinceLastSeen = now - lastSeen;

      if (timeSinceLastSeen > this.config.offline_timeout) {
        // Mark as offline and remove after additional time
        if (presence.status !== 'offline') {
          presence.status = 'offline';
          this.callbacks.onUserLeft?.(presence);
        }
        
        // Remove completely after double the offline timeout
        if (timeSinceLastSeen > this.config.offline_timeout * 2) {
          staleUsers.push(userId);
        }
      } else if (timeSinceLastSeen > this.config.idle_timeout && presence.status !== 'idle') {
        // Mark as idle
        presence.status = 'idle';
        this.callbacks.onUserStatusChanged?.(presence);
      }
    });

    // Remove stale users
    staleUsers.forEach(userId => {
      this.presenceData.delete(userId);
    });
  }

  private checkIdleStatus(): void {
    if (!this.currentUser) {return;}

    const now = Date.now();
    const timeSinceActivity = now - this.lastActivity;
    const presence = this.presenceData.get(this.currentUser.id);

    if (presence) {
      if (timeSinceActivity > this.config.idle_timeout && presence.status === 'online') {
        this.setStatus('idle');
      } else if (timeSinceActivity <= this.config.idle_timeout && presence.status === 'idle') {
        this.setStatus('online');
      }
    }
  }

  private trackUserActivity(): void {
    const events = ['mousedown', 'mousemove', 'keypress', 'scroll', 'touchstart'];
    
    const updateActivity = () => {
      this.lastActivity = Date.now();
      
      // If user was idle, mark as online
      if (this.currentUser) {
        const presence = this.presenceData.get(this.currentUser.id);
        if (presence && presence.status === 'idle') {
          this.setStatus('online');
        }
      }
    };

    events.forEach(event => {
      document.addEventListener(event, updateActivity, { passive: true });
    });
  }

  private broadcastPresenceUpdate(type: string, presence: UserPresence): void {
    this.websocket.sendMessage({
      id: this.generateMessageId(),
      type,
      channel: this.getChannelForLocation(),
      data: {
        user: presence.user,
        status: presence.status,
        location: presence.location,
        cursor_position: presence.cursor_position,
        timestamp: presence.last_seen
      },
      timestamp: new Date().toISOString(),
      retry_count: 0,
      max_retries: 2
    });
  }

  private getChannelForLocation(): string {
    // Determine channel based on current location
    if (this.location.includes('campaign_plan_')) {
      return 'campaign_collaboration';
    } else if (this.location.includes('content_')) {
      return 'content_collaboration';
    } else if (this.location.includes('ab_test_')) {
      return 'ab_test_monitoring';
    }
    return 'general';
  }

  private throttle<T extends (...args: any[]) => void>(
    func: T,
    delay: number
  ): T {
    let timeoutId: NodeJS.Timeout | null = null;
    let lastArgs: Parameters<T> | null = null;

    return ((...args: Parameters<T>) => {
      lastArgs = args;
      
      if (!timeoutId) {
        timeoutId = setTimeout(() => {
          if (lastArgs) {
            func(...lastArgs);
          }
          timeoutId = null;
          lastArgs = null;
        }, delay);
      }
    }) as T;
  }

  private generateMessageId(): string {
    return `presence_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;
  }

  public destroy(): void {
    if (this.heartbeatInterval) {
      clearInterval(this.heartbeatInterval);
    }
    
    if (this.idleTimer) {
      clearTimeout(this.idleTimer);
    }

    // Notify that user is leaving
    if (this.currentUser) {
      const presence = this.presenceData.get(this.currentUser.id);
      if (presence) {
        presence.status = 'offline';
        this.broadcastPresenceUpdate('user_left', presence);
      }
    }

    this.presenceData.clear();
  }
}

// Export singleton instance
let presenceSystem: PresenceSystem | null = null;

export const getPresenceSystem = (config?: Partial<PresenceConfig>): PresenceSystem => {
  if (!presenceSystem) {
    presenceSystem = new PresenceSystem(config);
  }
  return presenceSystem;
};

export const destroyPresenceSystem = (): void => {
  if (presenceSystem) {
    presenceSystem.destroy();
    presenceSystem = null;
  }
};

export default PresenceSystem;