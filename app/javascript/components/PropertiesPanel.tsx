import React, { useEffect, useState } from 'react';
import { useJourneyStore } from '../stores/journeyStore';
import type { JourneyStep } from '../types/journey';

const PropertiesPanel: React.FC = () => {
  const { journey, selectedStep, updateStep } = useJourneyStore();
  const [formData, setFormData] = useState<Partial<JourneyStep>>({});

  const currentStep = selectedStep 
    ? journey.steps.find(step => step.id === selectedStep)
    : null;

  // Update form data when selected step changes
  useEffect(() => {
    if (currentStep) {
      setFormData(currentStep);
    } else {
      setFormData({});
    }
  }, [currentStep]);

  const handleInputChange = (field: string, value: string | number | boolean) => {
    setFormData(prev => ({
      ...prev,
      [field]: value
    }));

    // Update step immediately for real-time preview
    if (selectedStep) {
      if (field.startsWith('data.')) {
        const dataField = field.replace('data.', '');
        updateStep(selectedStep, {
          data: {
            ...currentStep?.data,
            [dataField]: value
          }
        });
      } else {
        updateStep(selectedStep, { [field]: value });
      }
    }
  };

  const handleDataChange = (field: string, value: string | number | boolean | Record<string, unknown>) => {
    const newData = {
      ...currentStep?.data,
      [field]: value
    };
    
    setFormData(prev => ({
      ...prev,
      data: newData
    }));

    if (selectedStep) {
      updateStep(selectedStep, { data: newData });
    }
  };

  if (!currentStep) {
    return (
      <div className="properties-panel">
        <div className="no-selection">
          <div className="icon">🎯</div>
          <h3>No step selected</h3>
          <p>Select a journey step to edit its properties</p>
        </div>

        <style jsx>{`
          .properties-panel {
            width: 320px;
            background: white;
            border-left: 1px solid #e5e7eb;
            padding: 24px;
            overflow-y: auto;
            height: 100vh;
          }

          .no-selection {
            text-align: center;
            margin-top: 100px;
          }

          .no-selection .icon {
            font-size: 48px;
            margin-bottom: 16px;
          }

          .no-selection h3 {
            margin: 0 0 8px 0;
            color: #1f2937;
            font-weight: 600;
          }

          .no-selection p {
            margin: 0;
            color: #6b7280;
            font-size: 14px;
          }
        `}</style>
      </div>
    );
  }

  const stageOptions = [
    { value: 'awareness', label: 'Awareness' },
    { value: 'consideration', label: 'Consideration' },
    { value: 'conversion', label: 'Conversion' },
    { value: 'retention', label: 'Retention' }
  ];

  const timingOptions = [
    { value: 'immediate', label: 'Immediate' },
    { value: '1_hour', label: '1 Hour Later' },
    { value: '1_day', label: '1 Day Later' },
    { value: '3_days', label: '3 Days Later' },
    { value: '1_week', label: '1 Week Later' },
    { value: '2_weeks', label: '2 Weeks Later' },
    { value: '1_month', label: '1 Month Later' },
    { value: 'custom', label: 'Custom Delay' }
  ];

  return (
    <div className="properties-panel">
      <div className="panel-header">
        <h3>Step Properties</h3>
        <div className="step-type-badge">{currentStep.type.replace('_', ' ')}</div>
      </div>

      <form className="properties-form">
        {/* Basic Information */}
        <div className="form-section">
          <h4>Basic Information</h4>
          
          <div className="form-group">
            <label htmlFor="step-title">Title</label>
            <input
              id="step-title"
              type="text"
              value={formData.data?.title || ''}
              onChange={(e) => handleDataChange('title', e.target.value)}
              placeholder="Step title"
            />
          </div>

          <div className="form-group">
            <label htmlFor="step-description">Description</label>
            <textarea
              id="step-description"
              value={formData.data?.description || ''}
              onChange={(e) => handleDataChange('description', e.target.value)}
              placeholder="Describe this step's purpose"
              rows={3}
            />
          </div>

          <div className="form-group">
            <label htmlFor="step-stage">Journey Stage</label>
            <select
              id="step-stage"
              value={formData.stage || ''}
              onChange={(e) => handleInputChange('stage', e.target.value)}
            >
              {stageOptions.map(option => (
                <option key={option.value} value={option.value}>
                  {option.label}
                </option>
              ))}
            </select>
          </div>

          <div className="form-group">
            <label htmlFor="step-timing">Timing</label>
            <select
              id="step-timing"
              value={formData.data?.timing || ''}
              onChange={(e) => handleDataChange('timing', e.target.value)}
            >
              {timingOptions.map(option => (
                <option key={option.value} value={option.value}>
                  {option.label}
                </option>
              ))}
            </select>
          </div>
        </div>

        {/* Content Settings */}
        <div className="form-section">
          <h4>Content Settings</h4>
          
          {(currentStep.type === 'email_sequence' || currentStep.type === 'newsletter') && (
            <>
              <div className="form-group">
                <label htmlFor="email-subject">Email Subject</label>
                <input
                  id="email-subject"
                  type="text"
                  value={formData.data?.subject || ''}
                  onChange={(e) => handleDataChange('subject', e.target.value)}
                  placeholder="Enter email subject line"
                />
              </div>

              <div className="form-group">
                <label htmlFor="email-template">Template</label>
                <select
                  id="email-template"
                  value={formData.data?.template || ''}
                  onChange={(e) => handleDataChange('template', e.target.value)}
                >
                  <option value="">Choose template...</option>
                  <option value="welcome">Welcome Email</option>
                  <option value="newsletter">Newsletter</option>
                  <option value="promotional">Promotional</option>
                  <option value="educational">Educational</option>
                  <option value="transactional">Transactional</option>
                </select>
              </div>
            </>
          )}

          {currentStep.type === 'social_media' && (
            <div className="form-group">
              <label htmlFor="social-channel">Social Channel</label>
              <select
                id="social-channel"
                value={formData.data?.channel || ''}
                onChange={(e) => handleDataChange('channel', e.target.value)}
              >
                <option value="">Choose channel...</option>
                <option value="facebook">Facebook</option>
                <option value="twitter">Twitter</option>
                <option value="linkedin">LinkedIn</option>
                <option value="instagram">Instagram</option>
                <option value="youtube">YouTube</option>
              </select>
            </div>
          )}

          {(currentStep.type === 'webinar' || currentStep.type === 'demo') && (
            <div className="form-group">
              <label htmlFor="session-duration">Duration (minutes)</label>
              <input
                id="session-duration"
                type="number"
                value={formData.data?.duration || ''}
                onChange={(e) => handleDataChange('duration', parseInt(e.target.value))}
                placeholder="60"
                min="15"
                max="240"
              />
            </div>
          )}
        </div>

        {/* Conditions */}
        <div className="form-section">
          <h4>Conditions</h4>
          
          <div className="form-group">
            <label className="checkbox-label">
              <input
                type="checkbox"
                checked={formData.data?.conditions?.includes('email_opened') || false}
                onChange={(e) => {
                  const conditions = formData.data?.conditions || [];
                  const newConditions = e.target.checked
                    ? [...conditions, 'email_opened']
                    : conditions.filter(c => c !== 'email_opened');
                  handleDataChange('conditions', newConditions);
                }}
              />
              Only if previous email was opened
            </label>
          </div>

          <div className="form-group">
            <label className="checkbox-label">
              <input
                type="checkbox"
                checked={formData.data?.conditions?.includes('email_clicked') || false}
                onChange={(e) => {
                  const conditions = formData.data?.conditions || [];
                  const newConditions = e.target.checked
                    ? [...conditions, 'email_clicked']
                    : conditions.filter(c => c !== 'email_clicked');
                  handleDataChange('conditions', newConditions);
                }}
              />
              Only if previous email was clicked
            </label>
          </div>

          <div className="form-group">
            <label className="checkbox-label">
              <input
                type="checkbox"
                checked={formData.data?.conditions?.includes('page_visited') || false}
                onChange={(e) => {
                  const conditions = formData.data?.conditions || [];
                  const newConditions = e.target.checked
                    ? [...conditions, 'page_visited']
                    : conditions.filter(c => c !== 'page_visited');
                  handleDataChange('conditions', newConditions);
                }}
              />
              Only if specific page was visited
            </label>
          </div>
        </div>
      </form>

      <style jsx>{`
        .properties-panel {
          width: 320px;
          background: white;
          border-left: 1px solid #e5e7eb;
          padding: 0;
          overflow-y: auto;
          height: 100vh;
        }

        .panel-header {
          padding: 24px 24px 16px 24px;
          border-bottom: 1px solid #f3f4f6;
          display: flex;
          justify-content: space-between;
          align-items: center;
        }

        .panel-header h3 {
          margin: 0;
          font-size: 18px;
          font-weight: 600;
          color: #1f2937;
        }

        .step-type-badge {
          background: #f3f4f6;
          color: #6b7280;
          padding: 4px 8px;
          border-radius: 4px;
          font-size: 12px;
          font-weight: 500;
          text-transform: capitalize;
        }

        .properties-form {
          padding: 16px 24px 24px 24px;
        }

        .form-section {
          margin-bottom: 32px;
        }

        .form-section h4 {
          margin: 0 0 16px 0;
          font-size: 14px;
          font-weight: 600;
          color: #374151;
          text-transform: uppercase;
          letter-spacing: 0.5px;
        }

        .form-group {
          margin-bottom: 16px;
        }

        .form-group label {
          display: block;
          margin-bottom: 6px;
          font-size: 14px;
          font-weight: 500;
          color: #374151;
        }

        .checkbox-label {
          display: flex !important;
          align-items: center;
          gap: 8px;
          cursor: pointer;
          margin-bottom: 0 !important;
          font-weight: 400 !important;
        }

        .form-group input[type="text"],
        .form-group input[type="number"],
        .form-group textarea,
        .form-group select {
          width: 100%;
          padding: 8px 12px;
          border: 1px solid #d1d5db;
          border-radius: 6px;
          font-size: 14px;
          transition: border-color 0.2s ease;
        }

        .form-group input[type="text"]:focus,
        .form-group input[type="number"]:focus,
        .form-group textarea:focus,
        .form-group select:focus {
          outline: none;
          border-color: #3b82f6;
          box-shadow: 0 0 0 3px rgba(59, 130, 246, 0.1);
        }

        .form-group input[type="checkbox"] {
          width: 16px;
          height: 16px;
          margin: 0;
        }

        .form-group textarea {
          resize: vertical;
          min-height: 60px;
        }

        .form-group input::placeholder,
        .form-group textarea::placeholder {
          color: #9ca3af;
        }
      `}</style>
    </div>
  );
};

export default PropertiesPanel;