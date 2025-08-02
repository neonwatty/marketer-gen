import React, { useState } from 'react';
import useAISuggestions from '../hooks/useAISuggestions';
import { useJourneyStore } from '../stores/journeyStore';
import type { AISuggestion } from '../types/journey';

const AISuggestionsPanel: React.FC = () => {
  const { journey, selectedStep, addStep } = useJourneyStore();
  const [activeTab, setActiveTab] = useState<'general' | 'stage' | 'step'>('general');
  const [selectedStage, setSelectedStage] = useState<string>('awareness');
  
  const {
    suggestions,
    isLoading,
    error,
    fetchSuggestionsForStage,
    fetchSuggestionsForStep,
    submitFeedback
  } = useAISuggestions();

  const currentStep = selectedStep 
    ? journey.steps.find(step => step.id === selectedStep)
    : null;

  const handleApplySuggestion = (suggestion: AISuggestion) => {
    if (suggestion.type === 'step' && suggestion.data) {
      // Find a good position for the new step
      const maxX = Math.max(...journey.steps.map(s => s.position.x), 0);
      const position = { x: maxX + 250, y: 100 };
      
      const stepType = {
        id: suggestion.data.step_type,
        name: suggestion.title,
        description: suggestion.description,
        stage: suggestion.data.stage,
        icon: getStepIcon(suggestion.data.step_type),
        defaultData: suggestion.data
      };
      
      addStep(stepType, position);
    }
  };

  const handleFeedback = async (suggestion: AISuggestion, isPositive: boolean) => {
    try {
      await submitFeedback(
        suggestion.id,
        isPositive ? 'positive' : 'negative',
        isPositive ? 5 : 1
      );
    } catch (error) {
      console.error('Failed to submit feedback:', error);
    }
  };

  const getStepIcon = (stepType: string): string => {
    const icons: Record<string, string> = {
      blog_post: '📝',
      email_sequence: '📧',
      social_media: '📱',
      webinar: '🎥',
      sales_call: '📞',
      lead_magnet: '🧲',
      case_study: '📊',
      demo: '🖥️',
      trial_offer: '🎁',
      onboarding: '👋',
      newsletter: '📰',
      feedback_survey: '📋'
    };
    return icons[stepType] || '🔄';
  };

  const getConfidenceColor = (confidence: number): string => {
    if (confidence >= 0.9) {return '#10b981';} // green
    if (confidence >= 0.8) {return '#f59e0b';} // amber
    return '#6b7280'; // gray
  };

  return (
    <div className="ai-suggestions-panel">
      <div className="panel-header">
        <h3>AI Suggestions</h3>
        <div className="suggestion-tabs">
          <button
            className={`tab ${activeTab === 'general' ? 'active' : ''}`}
            onClick={() => setActiveTab('general')}
          >
            General
          </button>
          <button
            className={`tab ${activeTab === 'stage' ? 'active' : ''}`}
            onClick={() => setActiveTab('stage')}
          >
            By Stage
          </button>
          {currentStep && (
            <button
              className={`tab ${activeTab === 'step' ? 'active' : ''}`}
              onClick={() => setActiveTab('step')}
            >
              For Step
            </button>
          )}
        </div>
      </div>

      <div className="panel-content">
        {activeTab === 'stage' && (
          <div className="stage-selector">
            <label htmlFor="stage-select">Select Stage:</label>
            <select
              id="stage-select"
              value={selectedStage}
              onChange={(e) => {
                setSelectedStage(e.target.value);
                fetchSuggestionsForStage(e.target.value);
              }}
            >
              <option value="awareness">Awareness</option>
              <option value="consideration">Consideration</option>
              <option value="conversion">Conversion</option>
              <option value="retention">Retention</option>
            </select>
          </div>
        )}

        {activeTab === 'step' && currentStep && (
          <div className="step-context">
            <div className="current-step-info">
              <span className="step-icon">{getStepIcon(currentStep.type)}</span>
              <span className="step-name">{currentStep.data.title}</span>
            </div>
            <button
              className="fetch-suggestions-btn"
              onClick={() => fetchSuggestionsForStep({
                type: currentStep.type,
                stage: currentStep.stage,
                previous_steps: journey.steps,
                journey_context: journey
              })}
            >
              Get Suggestions
            </button>
          </div>
        )}

        {isLoading && (
          <div className="loading-state">
            <div className="spinner">🔄</div>
            <p>Getting AI suggestions...</p>
          </div>
        )}

        {error && (
          <div className="error-state">
            <p>Failed to load suggestions: {error}</p>
            <button onClick={() => window.location.reload()}>Retry</button>
          </div>
        )}

        {!isLoading && !error && (
          <div className="suggestions-list">
            {suggestions.length === 0 ? (
              <div className="empty-state">
                <p>No suggestions available.</p>
                {activeTab === 'stage' && (
                  <button
                    onClick={() => fetchSuggestionsForStage(selectedStage)}
                    className="refresh-btn"
                  >
                    Refresh Suggestions
                  </button>
                )}
              </div>
            ) : (
              suggestions.map((suggestion) => (
                <div key={suggestion.id} className="suggestion-card">
                  <div className="suggestion-header">
                    <h4>{suggestion.title}</h4>
                    <div
                      className="confidence-badge"
                      style={{ backgroundColor: getConfidenceColor(suggestion.confidence) }}
                    >
                      {Math.round(suggestion.confidence * 100)}%
                    </div>
                  </div>
                  
                  <p className="suggestion-description">
                    {suggestion.description}
                  </p>

                  {suggestion.data && (
                    <div className="suggestion-details">
                      <div className="detail-item">
                        <span className="label">Stage:</span>
                        <span className="value">{suggestion.data.stage}</span>
                      </div>
                      <div className="detail-item">
                        <span className="label">Timing:</span>
                        <span className="value">{suggestion.data.timing}</span>
                      </div>
                    </div>
                  )}

                  <div className="suggestion-actions">
                    <button
                      className="apply-btn"
                      onClick={() => handleApplySuggestion(suggestion)}
                    >
                      Apply
                    </button>
                    <div className="feedback-buttons">
                      <button
                        className="feedback-btn positive"
                        onClick={() => handleFeedback(suggestion, true)}
                        title="Good suggestion"
                      >
                        👍
                      </button>
                      <button
                        className="feedback-btn negative"
                        onClick={() => handleFeedback(suggestion, false)}
                        title="Not helpful"
                      >
                        👎
                      </button>
                    </div>
                  </div>
                </div>
              ))
            )}
          </div>
        )}
      </div>

      <style jsx>{`
        .ai-suggestions-panel {
          width: 320px;
          background: white;
          border-left: 1px solid #e5e7eb;
          display: flex;
          flex-direction: column;
          height: 100vh;
        }

        .panel-header {
          padding: 20px 20px 16px 20px;
          border-bottom: 1px solid #f3f4f6;
        }

        .panel-header h3 {
          margin: 0 0 16px 0;
          font-size: 18px;
          font-weight: 600;
          color: #1f2937;
        }

        .suggestion-tabs {
          display: flex;
          gap: 4px;
        }

        .tab {
          padding: 6px 12px;
          background: #f9fafb;
          border: 1px solid #e5e7eb;
          border-radius: 6px;
          font-size: 12px;
          cursor: pointer;
          transition: all 0.2s ease;
        }

        .tab.active {
          background: #3b82f6;
          color: white;
          border-color: #3b82f6;
        }

        .tab:hover:not(.active) {
          background: #f3f4f6;
        }

        .panel-content {
          flex: 1;
          padding: 16px 20px;
          overflow-y: auto;
        }

        .stage-selector {
          margin-bottom: 20px;
        }

        .stage-selector label {
          display: block;
          margin-bottom: 6px;
          font-size: 14px;
          font-weight: 500;
          color: #374151;
        }

        .stage-selector select {
          width: 100%;
          padding: 8px 12px;
          border: 1px solid #d1d5db;
          border-radius: 6px;
          font-size: 14px;
        }

        .step-context {
          margin-bottom: 20px;
          padding: 12px;
          background: #f9fafb;
          border-radius: 6px;
        }

        .current-step-info {
          display: flex;
          align-items: center;
          gap: 8px;
          margin-bottom: 12px;
        }

        .step-icon {
          font-size: 16px;
        }

        .step-name {
          font-weight: 500;
          color: #1f2937;
        }

        .fetch-suggestions-btn {
          width: 100%;
          padding: 8px 16px;
          background: #3b82f6;
          color: white;
          border: none;
          border-radius: 6px;
          font-size: 14px;
          cursor: pointer;
        }

        .fetch-suggestions-btn:hover {
          background: #2563eb;
        }

        .loading-state,
        .error-state,
        .empty-state {
          text-align: center;
          padding: 40px 20px;
        }

        .spinner {
          font-size: 24px;
          animation: spin 1s linear infinite;
          margin-bottom: 12px;
        }

        @keyframes spin {
          from { transform: rotate(0deg); }
          to { transform: rotate(360deg); }
        }

        .error-state button,
        .refresh-btn {
          padding: 8px 16px;
          background: #6b7280;
          color: white;
          border: none;
          border-radius: 6px;
          font-size: 14px;
          cursor: pointer;
          margin-top: 12px;
        }

        .suggestions-list {
          display: flex;
          flex-direction: column;
          gap: 16px;
        }

        .suggestion-card {
          border: 1px solid #e5e7eb;
          border-radius: 8px;
          padding: 16px;
          background: white;
          transition: box-shadow 0.2s ease;
        }

        .suggestion-card:hover {
          box-shadow: 0 2px 8px rgba(0, 0, 0, 0.1);
        }

        .suggestion-header {
          display: flex;
          justify-content: space-between;
          align-items: flex-start;
          margin-bottom: 8px;
        }

        .suggestion-header h4 {
          margin: 0;
          font-size: 14px;
          font-weight: 600;
          color: #1f2937;
          flex: 1;
        }

        .confidence-badge {
          color: white;
          font-size: 11px;
          font-weight: 600;
          padding: 2px 6px;
          border-radius: 10px;
          margin-left: 8px;
        }

        .suggestion-description {
          font-size: 13px;
          color: #6b7280;
          margin: 0 0 12px 0;
          line-height: 1.4;
        }

        .suggestion-details {
          display: flex;
          flex-direction: column;
          gap: 4px;
          margin-bottom: 12px;
        }

        .detail-item {
          display: flex;
          justify-content: space-between;
          font-size: 12px;
        }

        .detail-item .label {
          font-weight: 500;
          color: #6b7280;
        }

        .detail-item .value {
          color: #1f2937;
          text-transform: capitalize;
        }

        .suggestion-actions {
          display: flex;
          justify-content: space-between;
          align-items: center;
        }

        .apply-btn {
          padding: 6px 12px;
          background: #10b981;
          color: white;
          border: none;
          border-radius: 4px;
          font-size: 12px;
          font-weight: 500;
          cursor: pointer;
        }

        .apply-btn:hover {
          background: #059669;
        }

        .feedback-buttons {
          display: flex;
          gap: 4px;
        }

        .feedback-btn {
          padding: 4px;
          background: none;
          border: 1px solid #e5e7eb;
          border-radius: 4px;
          cursor: pointer;
          font-size: 12px;
          transition: all 0.2s ease;
        }

        .feedback-btn:hover {
          background: #f9fafb;
        }

        .feedback-btn.positive:hover {
          background: #ecfdf5;
          border-color: #10b981;
        }

        .feedback-btn.negative:hover {
          background: #fef2f2;
          border-color: #ef4444;
        }
      `}</style>
    </div>
  );
};

export default AISuggestionsPanel;