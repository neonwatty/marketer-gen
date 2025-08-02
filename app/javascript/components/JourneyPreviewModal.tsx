import React, { useState } from 'react';
import type { Journey } from '../types/journey';

interface JourneyPreviewModalProps {
  isOpen: boolean;
  onClose: () => void;
  journey: Journey;
}

const JourneyPreviewModal: React.FC<JourneyPreviewModalProps> = ({
  isOpen,
  onClose,
  journey
}) => {
  const [currentStepIndex, setCurrentStepIndex] = useState(0);
  const [isSimulating, setIsSimulating] = useState(false);

  if (!isOpen) {return null;}

  const handleStartSimulation = () => {
    setIsSimulating(true);
    setCurrentStepIndex(0);
  };

  const handleNextStep = () => {
    if (currentStepIndex < journey.steps.length - 1) {
      setCurrentStepIndex(currentStepIndex + 1);
    }
  };

  const handlePreviousStep = () => {
    if (currentStepIndex > 0) {
      setCurrentStepIndex(currentStepIndex - 1);
    }
  };

  const handleStopSimulation = () => {
    setIsSimulating(false);
    setCurrentStepIndex(0);
  };

  const getStageColor = (stage: string) => {
    const colors = {
      awareness: '#3b82f6',
      consideration: '#10b981',
      conversion: '#f59e0b',
      retention: '#8b5cf6'
    };
    return colors[stage as keyof typeof colors] || '#6b7280';
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

  const currentStep = journey.steps[currentStepIndex];

  return (
    <div className="preview-modal-overlay">
      <div className="preview-modal">
        <div className="modal-header">
          <h2>Journey Preview: {journey.name}</h2>
          <button className="close-button" onClick={onClose}>
            ×
          </button>
        </div>

        <div className="modal-content">
          {!isSimulating ? (
            <div className="preview-overview">
              <div className="journey-stats">
                <div className="stat">
                  <span className="stat-label">Total Steps:</span>
                  <span className="stat-value">{journey.steps.length}</span>
                </div>
                <div className="stat">
                  <span className="stat-label">Stages:</span>
                  <span className="stat-value">
                    {[...new Set(journey.steps.map(s => s.stage))].length}
                  </span>
                </div>
                <div className="stat">
                  <span className="stat-label">Connections:</span>
                  <span className="stat-value">{journey.connections.length}</span>
                </div>
              </div>

              <div className="journey-overview">
                <h3>Journey Steps Overview</h3>
                <div className="steps-list">
                  {journey.steps.map((step, index) => (
                    <div key={step.id} className="step-overview">
                      <div className="step-number">{index + 1}</div>
                      <div className="step-content">
                        <div className="step-header">
                          <span className="step-icon">{getStepIcon(step.type)}</span>
                          <span className="step-title">{step.data.title}</span>
                          <span 
                            className="step-stage"
                            style={{ backgroundColor: getStageColor(step.stage) }}
                          >
                            {step.stage}
                          </span>
                        </div>
                        <p className="step-description">{step.data.description}</p>
                        <div className="step-timing">
                          Timing: {step.data.timing}
                        </div>
                      </div>
                    </div>
                  ))}
                </div>
              </div>

              <div className="simulation-controls">
                <button 
                  className="simulate-button"
                  onClick={handleStartSimulation}
                  disabled={journey.steps.length === 0}
                >
                  Start Journey Simulation
                </button>
              </div>
            </div>
          ) : (
            <div className="simulation-view">
              <div className="simulation-header">
                <h3>Journey Simulation</h3>
                <div className="simulation-progress">
                  Step {currentStepIndex + 1} of {journey.steps.length}
                </div>
              </div>

              <div className="progress-bar">
                <div 
                  className="progress-fill"
                  style={{
                    width: `${((currentStepIndex + 1) / journey.steps.length) * 100}%`
                  }}
                />
              </div>

              {currentStep && (
                <div className="current-step-simulation">
                  <div className="step-simulation-header">
                    <span className="step-icon-large">
                      {getStepIcon(currentStep.type)}
                    </span>
                    <div className="step-info">
                      <h4>{currentStep.data.title}</h4>
                      <div className="step-meta">
                        <span 
                          className="stage-badge"
                          style={{ backgroundColor: getStageColor(currentStep.stage) }}
                        >
                          {currentStep.stage}
                        </span>
                        <span className="timing-badge">
                          {currentStep.data.timing}
                        </span>
                      </div>
                    </div>
                  </div>

                  <div className="step-simulation-content">
                    <p className="step-description">{currentStep.data.description}</p>
                    
                    {currentStep.type === 'email_sequence' && currentStep.data.subject && (
                      <div className="email-preview">
                        <h5>Email Preview:</h5>
                        <div className="email-subject">
                          Subject: {currentStep.data.subject}
                        </div>
                      </div>
                    )}

                    {currentStep.data.conditions && currentStep.data.conditions.length > 0 && (
                      <div className="step-conditions">
                        <h5>Conditions:</h5>
                        <ul>
                          {currentStep.data.conditions.map((condition, i) => (
                            <li key={i}>{condition.replace('_', ' ')}</li>
                          ))}
                        </ul>
                      </div>
                    )}
                  </div>
                </div>
              )}

              <div className="simulation-controls">
                <button 
                  className="nav-button"
                  onClick={handlePreviousStep}
                  disabled={currentStepIndex === 0}
                >
                  ← Previous
                </button>
                
                <button 
                  className="stop-button"
                  onClick={handleStopSimulation}
                >
                  Stop Simulation
                </button>
                
                <button 
                  className="nav-button"
                  onClick={handleNextStep}
                  disabled={currentStepIndex === journey.steps.length - 1}
                >
                  Next →
                </button>
              </div>
            </div>
          )}
        </div>
      </div>

      <style jsx>{`
        .preview-modal-overlay {
          position: fixed;
          top: 0;
          left: 0;
          right: 0;
          bottom: 0;
          background: rgba(0, 0, 0, 0.5);
          display: flex;
          align-items: center;
          justify-content: center;
          z-index: 1000;
        }

        .preview-modal {
          background: white;
          border-radius: 12px;
          width: 90vw;
          max-width: 800px;
          max-height: 90vh;
          overflow: hidden;
          box-shadow: 0 25px 50px -12px rgba(0, 0, 0, 0.25);
        }

        .modal-header {
          display: flex;
          justify-content: space-between;
          align-items: center;
          padding: 24px;
          border-bottom: 1px solid #e5e7eb;
        }

        .modal-header h2 {
          margin: 0;
          font-size: 20px;
          font-weight: 600;
          color: #1f2937;
        }

        .close-button {
          background: none;
          border: none;
          font-size: 24px;
          cursor: pointer;
          color: #6b7280;
          padding: 4px;
          border-radius: 4px;
        }

        .close-button:hover {
          background: #f3f4f6;
          color: #1f2937;
        }

        .modal-content {
          padding: 24px;
          overflow-y: auto;
          max-height: calc(90vh - 120px);
        }

        .journey-stats {
          display: flex;
          gap: 24px;
          margin-bottom: 24px;
          padding: 16px;
          background: #f9fafb;
          border-radius: 8px;
        }

        .stat {
          display: flex;
          flex-direction: column;
          align-items: center;
        }

        .stat-label {
          font-size: 12px;
          color: #6b7280;
          margin-bottom: 4px;
        }

        .stat-value {
          font-size: 20px;
          font-weight: 600;
          color: #1f2937;
        }

        .journey-overview h3 {
          margin: 0 0 16px 0;
          font-size: 18px;
          font-weight: 600;
          color: #1f2937;
        }

        .steps-list {
          display: flex;
          flex-direction: column;
          gap: 12px;
          margin-bottom: 24px;
        }

        .step-overview {
          display: flex;
          gap: 12px;
          padding: 16px;
          border: 1px solid #e5e7eb;
          border-radius: 8px;
        }

        .step-number {
          width: 32px;
          height: 32px;
          background: #3b82f6;
          color: white;
          border-radius: 50%;
          display: flex;
          align-items: center;
          justify-content: center;
          font-weight: 600;
          font-size: 14px;
          flex-shrink: 0;
        }

        .step-content {
          flex: 1;
        }

        .step-header {
          display: flex;
          align-items: center;
          gap: 8px;
          margin-bottom: 8px;
        }

        .step-icon {
          font-size: 18px;
        }

        .step-title {
          font-weight: 600;
          color: #1f2937;
          flex: 1;
        }

        .step-stage {
          color: white;
          font-size: 11px;
          font-weight: 500;
          padding: 2px 8px;
          border-radius: 12px;
          text-transform: capitalize;
        }

        .step-description {
          font-size: 14px;
          color: #6b7280;
          margin: 0 0 8px 0;
        }

        .step-timing {
          font-size: 12px;
          color: #9ca3af;
        }

        .simulation-controls {
          display: flex;
          justify-content: center;
          gap: 12px;
        }

        .simulate-button {
          padding: 12px 24px;
          background: #3b82f6;
          color: white;
          border: none;
          border-radius: 8px;
          font-weight: 600;
          cursor: pointer;
          transition: background 0.2s ease;
        }

        .simulate-button:hover:not(:disabled) {
          background: #2563eb;
        }

        .simulate-button:disabled {
          background: #9ca3af;
          cursor: not-allowed;
        }

        .simulation-header {
          display: flex;
          justify-content: space-between;
          align-items: center;
          margin-bottom: 16px;
        }

        .simulation-header h3 {
          margin: 0;
          font-size: 18px;
          font-weight: 600;
          color: #1f2937;
        }

        .simulation-progress {
          font-size: 14px;
          color: #6b7280;
        }

        .progress-bar {
          width: 100%;
          height: 8px;
          background: #e5e7eb;
          border-radius: 4px;
          overflow: hidden;
          margin-bottom: 24px;
        }

        .progress-fill {
          height: 100%;
          background: #3b82f6;
          transition: width 0.3s ease;
        }

        .current-step-simulation {
          border: 1px solid #e5e7eb;
          border-radius: 12px;
          padding: 24px;
          margin-bottom: 24px;
        }

        .step-simulation-header {
          display: flex;
          gap: 16px;
          margin-bottom: 16px;
        }

        .step-icon-large {
          font-size: 48px;
        }

        .step-info h4 {
          margin: 0 0 8px 0;
          font-size: 20px;
          font-weight: 600;
          color: #1f2937;
        }

        .step-meta {
          display: flex;
          gap: 8px;
        }

        .stage-badge,
        .timing-badge {
          color: white;
          font-size: 12px;
          font-weight: 500;
          padding: 4px 8px;
          border-radius: 12px;
          text-transform: capitalize;
        }

        .timing-badge {
          background: #6b7280;
        }

        .step-simulation-content {
          margin-top: 16px;
        }

        .step-simulation-content .step-description {
          font-size: 16px;
          line-height: 1.5;
          margin-bottom: 16px;
        }

        .email-preview,
        .step-conditions {
          background: #f9fafb;
          padding: 12px;
          border-radius: 6px;
          margin-bottom: 12px;
        }

        .email-preview h5,
        .step-conditions h5 {
          margin: 0 0 8px 0;
          font-size: 14px;
          font-weight: 600;
          color: #374151;
        }

        .email-subject {
          font-family: monospace;
          background: white;
          padding: 8px;
          border-radius: 4px;
          border: 1px solid #e5e7eb;
        }

        .step-conditions ul {
          margin: 0;
          padding-left: 16px;
        }

        .step-conditions li {
          text-transform: capitalize;
          margin-bottom: 4px;
        }

        .nav-button,
        .stop-button {
          padding: 8px 16px;
          border: 1px solid #d1d5db;
          border-radius: 6px;
          background: white;
          cursor: pointer;
          font-weight: 500;
          transition: all 0.2s ease;
        }

        .nav-button:hover:not(:disabled) {
          background: #f3f4f6;
        }

        .nav-button:disabled {
          opacity: 0.5;
          cursor: not-allowed;
        }

        .stop-button {
          background: #ef4444;
          color: white;
          border-color: #ef4444;
        }

        .stop-button:hover {
          background: #dc2626;
        }
      `}</style>
    </div>
  );
};

export default JourneyPreviewModal;