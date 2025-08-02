import { create } from 'zustand';
import { persist, createJSONStorage } from 'zustand/middleware';
import { immer } from 'zustand/middleware/immer';
import { v4 as uuidv4 } from 'uuid';
import { 
  ConversationState, 
  ConversationThread, 
  Message, 
  CampaignContext, 
  Question,
  QuestionnaireFlow,
  SendMessageRequest,
  SendMessageResponse,
  ApiResponse
} from '../types/campaign-intake';

interface ConversationStore extends ConversationState {
  // Actions
  createThread: () => void;
  addMessage: (message: Omit<Message, 'id' | 'timestamp'>) => void;
  sendMessage: (request: SendMessageRequest) => Promise<void>;
  updateContext: (updates: Partial<CampaignContext>) => void;
  setCurrentQuestion: (question: Question | null) => void;
  loadQuestionnaire: (flow: QuestionnaireFlow) => void;
  setTyping: (isTyping: boolean) => void;
  setError: (error: string | null) => void;
  clearConversation: () => void;
  loadThread: (threadId: string) => Promise<void>;
  saveThreadToServer: () => Promise<void>;
  
  // Computed properties
  getProgress: () => number;
  canProceedToNext: () => boolean;
  getEstimatedTimeRemaining: () => number;
}

const initialContext: CampaignContext = {
  completedSteps: [],
  currentStep: 'welcome',
  progress: 0,
};

const createInitialThread = (): ConversationThread => ({
  id: uuidv4(),
  messages: [],
  status: 'active',
  context: initialContext,
  createdAt: new Date(),
  updatedAt: new Date(),
});

export const useConversationStore = create<ConversationStore>()(
  persist(
    immer((set, get) => ({
      // Initial state
      thread: null,
      isLoading: false,
      isTyping: false,
      error: null,
      questionnaire: null,
      currentQuestion: null,

      // Actions
      createThread: () => set((state) => {
        state.thread = createInitialThread();
        state.error = null;
      }),

      addMessage: (messageData) => set((state) => {
        if (!state.thread) {
          state.thread = createInitialThread();
        }
        
        const message: Message = {
          ...messageData,
          id: uuidv4(),
          timestamp: new Date(),
        };
        
        state.thread.messages.push(message);
        state.thread.updatedAt = new Date();
      }),

      sendMessage: async (request) => {
        const state = get();
        
        if (!state.thread) {
          set((draft) => {
            draft.thread = createInitialThread();
          });
        }

        // Add user message immediately
        const userMessage: Message = {
          id: uuidv4(),
          content: request.content,
          type: 'user',
          timestamp: new Date(),
          questionId: request.questionId,
          metadata: {
            isQuestionResponse: !!request.questionId,
          },
        };

        set((draft) => {
          draft.thread!.messages.push(userMessage);
          draft.isLoading = true;
          draft.error = null;
        });

        try {
          // Update context if provided
          if (request.context) {
            set((draft) => {
              Object.assign(draft.thread!.context, request.context);
            });
          }

          // Send to backend
          const response = await fetch('/api/v1/campaign-intake/message', {
            method: 'POST',
            headers: {
              'Content-Type': 'application/json',
              'X-CSRF-Token': document.querySelector<HTMLMetaElement>('meta[name="csrf-token"]')?.content || '',
            },
            body: JSON.stringify({
              ...request,
              threadId: state.thread!.id,
              context: state.thread!.context,
            }),
          });

          if (!response.ok) {
            throw new Error(`HTTP error! status: ${response.status}`);
          }

          const apiResponse: ApiResponse<SendMessageResponse> = await response.json();
          
          if (!apiResponse.success || !apiResponse.data) {
            throw new Error(apiResponse.error || 'Failed to send message');
          }

          const { message: assistantMessage, thread: updatedThread, nextQuestion, isComplete } = apiResponse.data;

          set((draft) => {
            // Add assistant response
            draft.thread!.messages.push(assistantMessage);
            
            // Update thread context
            draft.thread!.context = updatedThread.context;
            draft.thread!.currentQuestionId = nextQuestion?.id;
            draft.thread!.updatedAt = new Date();
            
            // Set next question
            draft.currentQuestion = nextQuestion || null;
            
            // Mark as completed if done
            if (isComplete) {
              draft.thread!.status = 'completed';
            }
            
            draft.isLoading = false;
          });

          // Auto-save to server
          await get().saveThreadToServer();

        } catch (error) {
          console.error('Error sending message:', error);
          set((draft) => {
            draft.error = error instanceof Error ? error.message : 'Failed to send message';
            draft.isLoading = false;
          });
        }
      },

      updateContext: (updates) => set((state) => {
        if (!state.thread) {return;}
        
        Object.assign(state.thread.context, updates);
        state.thread.updatedAt = new Date();
        
        // Recalculate progress
        const totalSteps = state.questionnaire?.questions.length || 10;
        const completedSteps = state.thread.context.completedSteps.length;
        state.thread.context.progress = Math.round((completedSteps / totalSteps) * 100);
      }),

      setCurrentQuestion: (question) => set((state) => {
        state.currentQuestion = question;
        if (state.thread && question) {
          state.thread.currentQuestionId = question.id;
        }
      }),

      loadQuestionnaire: (flow) => set((state) => {
        state.questionnaire = flow;
        if (flow.questions.length > 0) {
          state.currentQuestion = flow.questions[0];
        }
      }),

      setTyping: (isTyping) => set((state) => {
        state.isTyping = isTyping;
      }),

      setError: (error) => set((state) => {
        state.error = error;
      }),

      clearConversation: () => set((state) => {
        state.thread = null;
        state.currentQuestion = null;
        state.error = null;
        state.isLoading = false;
        state.isTyping = false;
      }),

      loadThread: async (threadId) => {
        set((draft) => {
          draft.isLoading = true;
          draft.error = null;
        });

        try {
          const response = await fetch(`/api/v1/campaign-intake/threads/${threadId}`, {
            headers: {
              'X-CSRF-Token': document.querySelector<HTMLMetaElement>('meta[name="csrf-token"]')?.content || '',
            },
          });

          if (!response.ok) {
            throw new Error(`HTTP error! status: ${response.status}`);
          }

          const apiResponse: ApiResponse<ConversationThread> = await response.json();
          
          if (!apiResponse.success || !apiResponse.data) {
            throw new Error(apiResponse.error || 'Failed to load thread');
          }

          set((draft) => {
            draft.thread = apiResponse.data!;
            draft.isLoading = false;
          });

        } catch (error) {
          console.error('Error loading thread:', error);
          set((draft) => {
            draft.error = error instanceof Error ? error.message : 'Failed to load conversation';
            draft.isLoading = false;
          });
        }
      },

      saveThreadToServer: async () => {
        const state = get();
        if (!state.thread) {return;}

        try {
          await fetch('/api/v1/campaign-intake/threads', {
            method: 'POST',
            headers: {
              'Content-Type': 'application/json',
              'X-CSRF-Token': document.querySelector<HTMLMetaElement>('meta[name="csrf-token"]')?.content || '',
            },
            body: JSON.stringify({ thread: state.thread }),
          });
        } catch (error) {
          console.error('Error saving thread:', error);
          // Don't throw here to avoid disrupting the UI flow
        }
      },

      // Computed properties
      getProgress: () => {
        const state = get();
        return state.thread?.context.progress || 0;
      },

      canProceedToNext: () => {
        const state = get();
        if (!state.currentQuestion || !state.thread) {return false;}
        
        // Check if current question is answered
        const lastMessage = state.thread.messages[state.thread.messages.length - 1];
        return lastMessage?.type === 'user' && lastMessage?.questionId === state.currentQuestion.id;
      },

      getEstimatedTimeRemaining: () => {
        const state = get();
        if (!state.questionnaire || !state.thread) {return 0;}
        
        const totalQuestions = state.questionnaire.questions.length;
        const completedQuestions = state.thread.context.completedSteps.length;
        const remainingQuestions = totalQuestions - completedQuestions;
        
        // Estimate 1-2 minutes per question
        return Math.max(remainingQuestions * 1.5, 0);
      },
    })),
    {
      name: 'campaign-conversation',
      storage: createJSONStorage(() => sessionStorage),
      partialize: (state) => ({
        thread: state.thread,
        questionnaire: state.questionnaire,
      }),
    }
  )
);