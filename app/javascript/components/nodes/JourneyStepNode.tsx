import React from 'react';
import { Handle, Position, NodeProps } from 'reactflow';
import type { JourneyStep } from '../../types/journey';

interface JourneyStepNodeData extends JourneyStep {
  isSelected?: boolean;
  onSelect?: (id: string) => void;
  onDelete?: (id: string) => void;
}

const stageColors = {
  awareness: { primary: '#3b82f6', bg: '#eff6ff', border: '#bfdbfe' },
  consideration: { primary: '#10b981', bg: '#ecfdf5', border: '#a7f3d0' },
  conversion: { primary: '#f59e0b', bg: '#fffbeb', border: '#fed7aa' },
  retention: { primary: '#8b5cf6', bg: '#f5f3ff', border: '#c4b5fd' }
};

const stepIcons: Record<string, string> = {
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

export const JourneyStepNode: React.FC<NodeProps<JourneyStepNodeData>> = ({ 
  data, 
  selected 
}) => {
  const colors = stageColors[data.stage] || stageColors.awareness;

  const handleClick = (e: React.MouseEvent) => {
    e.stopPropagation();
    data.onSelect?.(data.id);
  };

  const handleDelete = (e: React.MouseEvent) => {
    e.stopPropagation();
    data.onDelete?.(data.id);
  };

  return (
    <div 
      className={`journey-step-node ${selected ? 'selected' : ''}`}
      onClick={handleClick}
      style={{
        border: `2px solid ${selected ? colors.primary : colors.border}`,
        boxShadow: selected ? `0 0 0 3px ${colors.primary}40` : '0 2px 8px rgba(0,0,0,0.1)'
      }}
    >
      <Handle
        type="target"
        position={Position.Left}
        style={{ background: colors.primary, width: 8, height: 8 }}
      />
      
      <div className="node-content">
        {/* Header */}
        <div 
          className="node-header"
          style={{ backgroundColor: colors.primary }}
        >
          <div className="header-content">
            <span className="step-icon">{stepIcons[data.type] || '🔄'}</span>
            <span className="step-type">{data.type.replace('_', ' ')}</span>
          </div>
          <button 
            className="delete-button"
            onClick={handleDelete}
            title="Delete step"
          >
            ×
          </button>
        </div>

        {/* Body */}
        <div className="node-body" style={{ backgroundColor: colors.bg }}>
          <h4 className="step-title">{data.data.title}</h4>
          <p className="step-description">{data.data.description}</p>
          
          <div className="step-meta">
            <div className="timing">
              <span className="timing-icon">⏱️</span>
              <span className="timing-text">{data.data.timing}</span>
            </div>
            <div className="stage-badge" style={{ backgroundColor: colors.primary }}>
              {data.stage}
            </div>
          </div>
        </div>
      </div>

      <Handle
        type="source"
        position={Position.Right}
        style={{ background: colors.primary, width: 8, height: 8 }}
      />

      <style jsx>{`
        .journey-step-node {
          background: white;
          border-radius: 8px;
          min-width: 200px;
          cursor: pointer;
          transition: all 0.2s ease;
        }

        .journey-step-node:hover {
          transform: translateY(-2px);
          box-shadow: 0 4px 12px rgba(0,0,0,0.15);
        }

        .journey-step-node.selected {
          transform: translateY(-2px);
        }

        .node-content {
          position: relative;
        }

        .node-header {
          color: white;
          padding: 8px 12px;
          border-radius: 6px 6px 0 0;
          display: flex;
          justify-content: space-between;
          align-items: center;
          font-size: 12px;
          font-weight: 600;
        }

        .header-content {
          display: flex;
          align-items: center;
          gap: 6px;
        }

        .step-icon {
          font-size: 14px;
        }

        .step-type {
          text-transform: capitalize;
        }

        .delete-button {
          background: none;
          border: none;
          color: white;
          cursor: pointer;
          font-size: 16px;
          padding: 0;
          width: 20px;
          height: 20px;
          border-radius: 50%;
          display: flex;
          align-items: center;
          justify-content: center;
          opacity: 0.7;
          transition: opacity 0.2s ease;
        }

        .delete-button:hover {
          opacity: 1;
          background: rgba(255,255,255,0.2);
        }

        .node-body {
          padding: 12px;
          border-radius: 0 0 6px 6px;
        }

        .step-title {
          font-size: 14px;
          font-weight: 600;
          color: #1f2937;
          margin: 0 0 4px 0;
          line-height: 1.2;
        }

        .step-description {
          font-size: 12px;
          color: #6b7280;
          margin: 0 0 8px 0;
          line-height: 1.3;
        }

        .step-meta {
          display: flex;
          justify-content: space-between;
          align-items: center;
        }

        .timing {
          display: flex;
          align-items: center;
          gap: 4px;
          font-size: 11px;
          color: #9ca3af;
        }

        .timing-icon {
          font-size: 12px;
        }

        .stage-badge {
          color: white;
          font-size: 10px;
          font-weight: 500;
          padding: 2px 6px;
          border-radius: 10px;
          text-transform: capitalize;
        }

        .react-flow__handle {
          border: 2px solid white;
        }
      `}</style>
    </div>
  );
};