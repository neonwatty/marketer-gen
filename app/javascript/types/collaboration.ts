// TypeScript definitions for real-time collaboration features

export interface User {
  id: number;
  name: string;
  email: string;
  avatar_url?: string;
}

export interface UserPresence {
  user: User;
  status: 'online' | 'offline' | 'idle';
  last_seen: string;
  location?: string; // Current page/section they're viewing
  cursor_position?: CursorPosition;
}

export interface CursorPosition {
  x: number;
  y: number;
  element_id?: string;
  selection_start?: number;
  selection_end?: number;
}

// Campaign Collaboration Types
export interface CampaignCollaborationMessage {
  type: 'plan_update' | 'comment_added' | 'status_change' | 'user_joined' | 'user_left' | 'cursor_move';
  user: User;
  campaign_plan_id: number;
  data: PlanUpdate | PlanComment | CursorPosition | Record<string, unknown>;
  timestamp: string;
  message_id: string;
}

export interface PlanUpdate {
  field: string;
  old_value: string | number | boolean | null;
  new_value: string | number | boolean | null;
  version: number;
  conflict_resolution?: 'accept' | 'reject' | 'merge';
}

export interface PlanComment {
  id: number;
  user: User;
  content: string;
  created_at: string;
  field_reference?: string;
  resolved: boolean;
}

// Content Editor Collaboration Types
export interface ContentCollaborationMessage {
  type: 'content_update' | 'cursor_move' | 'selection_change' | 'user_joined' | 'user_left';
  user: User;
  content_id: number;
  data: OperationalTransform | EditorCursor | EditorSelection | Record<string, unknown>;
  timestamp: string;
  message_id: string;
}

export interface OperationalTransform {
  operation: 'insert' | 'delete' | 'retain';
  position: number;
  content?: string;
  length?: number;
  author_id: number;
  timestamp: string;
  version: number;
}

export interface ContentVersion {
  id: number;
  version_number: number;
  content: string;
  operations: OperationalTransform[];
  author: User;
  created_at: string;
}

export interface EditorSelection {
  start: number;
  end: number;
  direction: 'forward' | 'backward' | 'none';
}

export interface EditorCursor {
  user: User;
  position: number;
  selection?: EditorSelection;
  color: string;
}

// A/B Test Monitoring Types
export interface AbTestMessage {
  type: 'metric_update' | 'status_change' | 'winner_declared' | 'traffic_update' | 'alert';
  ab_test_id: number;
  data: MetricUpdate | TrafficUpdate | TestAlert | Record<string, unknown>;
  timestamp: string;
  message_id: string;
}

export interface MetricUpdate {
  variant_id: number;
  metric_type: string;
  current_value: number;
  previous_value: number;
  change_percentage: number;
  confidence_level?: number;
}

export interface TrafficUpdate {
  variant_id: number;
  current_traffic: number;
  total_visitors: number;
  conversions: number;
  conversion_rate: number;
}

export interface TestAlert {
  level: 'info' | 'warning' | 'error' | 'success';
  message: string;
  variant_id?: number;
  metric_type?: string;
  action_required?: boolean;
}

// WebSocket Connection Types
export interface ConnectionConfig {
  url: string;
  reconnect_attempts: number;
  reconnect_interval: number;
  heartbeat_interval: number;
  message_queue_size: number;
}

export interface ConnectionState {
  status: 'connecting' | 'connected' | 'disconnected' | 'reconnecting' | 'error';
  last_connected: string | null;
  reconnect_count: number;
  error_message?: string;
}

export interface MessageQueue {
  pending: WebSocketMessage[];
  failed: WebSocketMessage[];
  max_size: number;
}

export interface WebSocketMessage {
  id: string;
  type: string;
  channel: string;
  data: Record<string, unknown>;
  timestamp: string;
  retry_count: number;
  max_retries: number;
}

// Rate Limiting Types
export interface RateLimit {
  max_requests: number;
  window_ms: number;
  current_count: number;
  reset_time: number;
}

export interface RateLimitConfig {
  presence_updates: RateLimit;
  content_updates: RateLimit;
  cursor_movements: RateLimit;
  comments: RateLimit;
}

// Optimistic UI Types
export interface OptimisticUpdate<T = any> {
  id: string;
  type: string;
  original_data: T;
  optimistic_data: T;
  timestamp: string;
  confirmed: boolean;
  failed: boolean;
  error_message?: string;
}

export interface OptimisticQueue<T = any> {
  updates: Map<string, OptimisticUpdate<T>>;
  rollback(update_id: string): void;
  confirm(update_id: string): void;
  fail(update_id: string, error: string): void;
}

// Channel Subscription Types
export interface ChannelSubscription {
  channel: string;
  identifier: string;
  connected: boolean;
  subscription_id: string;
  callbacks: Map<string, Function[]>;
  actionCableSubscription?: any; // ActionCable subscription object
}

// Conflict Resolution Types
export interface ConflictResolution {
  conflict_id: string;
  field: string;
  local_value: string | number | boolean | null;
  remote_value: string | number | boolean | null;
  resolution_strategy: 'local_wins' | 'remote_wins' | 'merge' | 'manual';
  resolved_value?: string | number | boolean | null;
  timestamp: string;
}

// Event Types for type-safe event handling
export interface CollaborationEvents {
  'user:joined': UserPresence;
  'user:left': UserPresence;
  'user:status_changed': UserPresence;
  'plan:updated': PlanUpdate;
  'plan:comment_added': PlanComment;
  'content:updated': OperationalTransform;
  'content:cursor_moved': EditorCursor;
  'test:metric_updated': MetricUpdate;
  'test:status_changed': AbTestMessage;
  'test:alert': TestAlert;
  'connection:status_changed': ConnectionState;
  'conflict:detected': ConflictResolution;
  'optimistic:confirmed': OptimisticUpdate;
  'optimistic:failed': OptimisticUpdate;
}

// Error Types
export interface CollaborationError {
  code: string;
  message: string;
  details?: Record<string, unknown>;
  recoverable: boolean;
  timestamp: string;
}

export interface ErrorHandler {
  (error: CollaborationError): void;
}