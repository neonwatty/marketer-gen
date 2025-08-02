// Campaign Intake Types
export interface Message {
  id: string;
  content: string;
  type: 'user' | 'assistant' | 'system';
  timestamp: Date;
  questionId?: string;
  metadata?: {
    isQuestionResponse?: boolean;
    validationState?: 'valid' | 'invalid' | 'pending';
    suggestions?: string[];
  };
}

export interface ConversationThread {
  id: string;
  messages: Message[];
  currentQuestionId?: string;
  status: 'active' | 'completed' | 'paused';
  context: CampaignContext;
  createdAt: Date;
  updatedAt: Date;
}

export interface CampaignContext {
  campaignName?: string;
  campaignType?: string;
  industry?: string;
  targetAudience?: string;
  goals?: string[];
  budget?: number;
  timeline?: {
    startDate?: string;
    endDate?: string;
  };
  persona?: {
    id?: string;
    name?: string;
  };
  completedSteps: string[];
  currentStep: string;
  progress: number; // 0-100
}

export interface Question {
  id: string;
  text: string;
  type: 'text' | 'select' | 'multiselect' | 'number' | 'date' | 'textarea';
  required: boolean;
  options?: string[];
  validation?: {
    pattern?: string;
    min?: number;
    max?: number;
    minLength?: number;
    maxLength?: number;
  };
  contextKey: keyof CampaignContext;
  conditional?: {
    dependsOn: string;
    condition: (value: any) => boolean;
  };
  suggestions?: (context: CampaignContext) => string[];
  followUp?: string[];
}

export interface QuestionnaireFlow {
  id: string;
  name: string;
  description: string;
  questions: Question[];
  completionEstimate: number; // minutes
}

export interface ConversationState {
  thread: ConversationThread | null;
  isLoading: boolean;
  isTyping: boolean;
  error: string | null;
  questionnaire: QuestionnaireFlow | null;
  currentQuestion: Question | null;
}

export interface CampaignIntakeSession {
  id: string;
  userId: string;
  threadId: string;
  context: CampaignContext;
  status: 'in_progress' | 'completed' | 'abandoned';
  startedAt: Date;
  completedAt?: Date;
  estimatedCompletionTime: number;
  actualCompletionTime?: number;
}

// API Response Types
export interface ApiResponse<T> {
  success: boolean;
  data?: T;
  error?: string;
  message?: string;
}

export interface SendMessageRequest {
  content: string;
  threadId?: string;
  questionId?: string;
  context?: Partial<CampaignContext>;
}

export interface SendMessageResponse {
  message: Message;
  thread: ConversationThread;
  nextQuestion?: Question;
  suggestions?: string[];
  isComplete?: boolean;
}

// WebSocket Event Types
export interface WebSocketMessage {
  type: 'message' | 'typing' | 'question' | 'context_update' | 'completion';
  payload: any;
  threadId: string;
  timestamp: Date;
}

// UI State Types
export interface ChatUIState {
  isExpanded: boolean;
  showSuggestions: boolean;
  inputValue: string;
  selectedSuggestion: string | null;
  scrollToBottom: boolean;
}

export interface ProgressIndicator {
  currentStep: number;
  totalSteps: number;
  stepNames: string[];
  estimatedTimeRemaining: number;
}

// Campaign Types from existing system
export type CampaignType = 
  | 'product_launch'
  | 'brand_awareness' 
  | 'lead_generation'
  | 'customer_retention'
  | 'seasonal_promotion'
  | 'content_marketing'
  | 'email_nurture'
  | 'social_media'
  | 'event_promotion'
  | 'customer_onboarding'
  | 're_engagement'
  | 'cross_sell'
  | 'upsell'
  | 'referral'
  | 'awareness'
  | 'consideration'
  | 'conversion'
  | 'advocacy'
  | 'b2b_lead_generation';

export type CampaignStatus = 'draft' | 'active' | 'paused' | 'completed' | 'archived';