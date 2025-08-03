import React, { useState, useEffect, useRef } from 'react';
import { useConversationStore } from '../stores/conversationStore';
import { Message } from '../types/campaign-intake';
import MessageBubble from './chat/MessageBubble';
import MessageInput from './chat/MessageInput';
import ProgressIndicator from './chat/ProgressIndicator';
import QuestionCard from './chat/QuestionCard';
import SuggestionsPanel from './chat/SuggestionsPanel';
import TypingIndicator from './chat/TypingIndicator';
import { toast } from 'react-hot-toast';

interface CampaignIntakeChatProps {
  isExpanded?: boolean;
  onToggle?: () => void;
  className?: string;
}

const CampaignIntakeChat: React.FC<CampaignIntakeChatProps> = ({
  isExpanded = true,
  onToggle,
  className = '',
}) => {
  const {
    thread,
    isLoading,
    isTyping,
    error,
    currentQuestion,
    createThread,
    sendMessage,
    setError,
    getProgress,
    getEstimatedTimeRemaining,
  } = useConversationStore();

  const [inputValue, setInputValue] = useState('');
  const [showSuggestions, setShowSuggestions] = useState(false);
  const messagesEndRef = useRef<HTMLDivElement>(null);
  const chatContainerRef = useRef<HTMLDivElement>(null);

  // Initialize thread on mount
  useEffect(() => {
    if (!thread) {
      createThread();
    }
  }, [thread, createThread]);

  // Auto-scroll to bottom when new messages arrive
  useEffect(() => {
    if (messagesEndRef.current) {
      messagesEndRef.current.scrollIntoView({ behavior: 'smooth' });
    }
  }, [thread?.messages.length, isTyping]);

  // Show error notifications
  useEffect(() => {
    if (error) {
      toast.error(error);
      setError(null);
    }
  }, [error, setError]);

  // Send initial welcome message
  useEffect(() => {
    if (thread && thread.messages.length === 0) {
      const welcomeMessage: Message = {
        id: 'welcome',
        content: "Hi! I'm here to help you create your marketing campaign. Let's start by learning about your goals and target audience. What kind of campaign are you looking to create?",
        type: 'assistant',
        timestamp: new Date(),
        metadata: {
          suggestions: [
            'Product launch campaign',
            'Brand awareness campaign', 
            'Lead generation campaign',
            'Customer retention campaign',
          ]
        }
      };

      // Add welcome message directly to store
      useConversationStore.getState().addMessage(welcomeMessage);
    }
  }, [thread]);

  const handleSendMessage = async (content: string) => {
    if (!content.trim() || isLoading) {return;}

    try {
      await sendMessage({
        content: content.trim(),
        questionId: currentQuestion?.id,
      });
      setInputValue('');
      setShowSuggestions(false);
    } catch (error) {
      // eslint-disable-next-line no-console
      console.error('Error sending message:', error);
    }
  };

  const handleQuestionResponse = async (response: string | number | string[]) => {
    if (isLoading) {return;}

    const content = typeof response === 'string' ? response : JSON.stringify(response);
    
    try {
      await sendMessage({
        content,
        questionId: currentQuestion?.id,
        context: currentQuestion ? { [currentQuestion.contextKey]: response } : undefined,
      });
      setShowSuggestions(false);
    } catch (error) {
      // eslint-disable-next-line no-console
      console.error('Error sending question response:', error);
    }
  };

  const handleSuggestionClick = (suggestion: string) => {
    setInputValue(suggestion);
    setShowSuggestions(false);
  };

  const progress = getProgress();
  const estimatedTimeRemaining = getEstimatedTimeRemaining();

  if (!isExpanded) {
    return (
      <div className={`fixed bottom-4 right-4 z-50 ${className}`}>
        <button
          onClick={onToggle}
          className="bg-blue-600 hover:bg-blue-700 text-white rounded-full p-4 shadow-lg transition-colors"
          aria-label="Open campaign chat"
        >
          <svg className="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M8 12h.01M12 12h.01M16 12h.01M21 12c0 4.418-4.03 8-9 8a9.003 9.003 0 01-5.83-2.18L3 21l3.17-3.17c-.49-.87-.82-1.82-.98-2.83C5.01 14.47 5 13.74 5 13v-1c0-4.97 4.03-9 9-9s9 4.03 9 9z" />
          </svg>
        </button>
      </div>
    );
  }

  return (
    <div className={`flex flex-col h-full bg-white rounded-lg shadow-xl ${className}`}>
      {/* Header */}
      <div className="flex items-center justify-between p-4 border-b border-gray-200 bg-gradient-to-r from-blue-600 to-purple-600 text-white rounded-t-lg">
        <div>
          <h2 className="text-lg font-semibold">Campaign Assistant</h2>
          <p className="text-sm opacity-90">
            Let&apos;s create your marketing campaign together
          </p>
        </div>
        {onToggle && (
          <button
            onClick={onToggle}
            className="p-2 hover:bg-white/10 rounded-lg transition-colors"
            aria-label="Minimize chat"
          >
            <svg className="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M6 18L18 6M6 6l12 12" />
            </svg>
          </button>
        )}
      </div>

      {/* Progress Indicator */}
      {progress > 0 && (
        <ProgressIndicator 
          progress={progress}
          estimatedTimeRemaining={estimatedTimeRemaining}
          currentStep={thread?.context.currentStep || ''}
        />
      )}

      {/* Messages Container */}
      <div 
        ref={chatContainerRef}
        className="flex-1 overflow-y-auto p-4 space-y-4 min-h-0"
      >
        {thread?.messages.map((message) => (
          <MessageBubble key={message.id} message={message} />
        ))}
        
        {isTyping && <TypingIndicator />}
        
        <div ref={messagesEndRef} />
      </div>

      {/* Current Question Card */}
      {currentQuestion && (
        <QuestionCard
          question={currentQuestion}
          onResponse={handleQuestionResponse}
          isLoading={isLoading}
        />
      )}

      {/* Suggestions Panel */}
      {showSuggestions && thread?.messages.length > 0 && (
        <SuggestionsPanel
          suggestions={thread.messages[thread.messages.length - 1]?.metadata?.suggestions || []}
          onSuggestionClick={handleSuggestionClick}
          onClose={() => setShowSuggestions(false)}
        />
      )}

      {/* Input Area */}
      <div className="border-t border-gray-200 p-4 bg-gray-50">
        <MessageInput
          value={inputValue}
          onChange={setInputValue}
          onSend={handleSendMessage}
          onShowSuggestions={() => setShowSuggestions(!showSuggestions)}
          isLoading={isLoading}
          placeholder={
            currentQuestion 
              ? "Type your response here..." 
              : "Ask me anything about your campaign..."
          }
          showSuggestionsButton={
            thread?.messages[thread.messages.length - 1]?.metadata?.suggestions?.length > 0
          }
        />
      </div>
    </div>
  );
};

export default CampaignIntakeChat;