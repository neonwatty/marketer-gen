import React, { useCallback, useRef, useEffect } from 'react';
import ReactFlow, {
  Background,
  Controls,
  MiniMap,
  useNodesState,
  useEdgesState,
  Node,
  Edge,
  Connection,
  ConnectionMode,
  ReactFlowProvider,
  useReactFlow,
} from 'reactflow';
import 'reactflow/dist/style.css';

import { JourneyStepNode } from './nodes/JourneyStepNode';
import { useJourneyStore } from '../stores/journeyStore';
import type { JourneyStep, JourneyConnection, StepType } from '../types/journey';

const nodeTypes = {
  journeyStep: JourneyStepNode,
};

const stepTypes: StepType[] = [
  {
    id: 'email_sequence',
    name: 'Email Sequence',
    description: 'Send targeted emails',
    stage: 'consideration',
    icon: '📧',
    defaultData: { timing: 'immediate', subject: 'Welcome!' }
  },
  {
    id: 'blog_post',
    name: 'Blog Post',
    description: 'Educational content',
    stage: 'awareness',
    icon: '📝',
    defaultData: { timing: 'immediate' }
  },
  {
    id: 'social_media',
    name: 'Social Media',
    description: 'Social engagement',
    stage: 'awareness',
    icon: '📱',
    defaultData: { timing: 'immediate' }
  },
  {
    id: 'webinar',
    name: 'Webinar',
    description: 'Educational presentation',
    stage: 'consideration',
    icon: '🎥',
    defaultData: { timing: '1 week' }
  },
  {
    id: 'sales_call',
    name: 'Sales Call',
    description: 'Personal consultation',
    stage: 'conversion',
    icon: '📞',
    defaultData: { timing: '3 days' }
  },
  {
    id: 'demo',
    name: 'Product Demo',
    description: 'Show product features',
    stage: 'conversion',
    icon: '🖥️',
    defaultData: { timing: '1 day' }
  },
  {
    id: 'onboarding',
    name: 'Onboarding',
    description: 'User orientation',
    stage: 'retention',
    icon: '👋',
    defaultData: { timing: 'immediate' }
  },
  {
    id: 'newsletter',
    name: 'Newsletter',
    description: 'Regular updates',
    stage: 'retention',
    icon: '📰',
    defaultData: { timing: '1 week' }
  }
];

interface JourneyBuilderFlowProps {
  onSave?: () => void;
  onPreview?: () => void;
}

const JourneyBuilderFlowContent: React.FC<JourneyBuilderFlowProps> = ({
  onSave: _onSave,
  onPreview
}) => {
  const reactFlowWrapper = useRef<HTMLDivElement>(null);
  const [nodes, setNodes, onNodesChange] = useNodesState([]);
  const [edges, setEdges, onEdgesChange] = useEdgesState([]);
  const { screenToFlowPosition } = useReactFlow();

  const {
    journey,
    selectedStep,
    selectStep,
    addStep,
    deleteStep,
    moveStep,
    addConnection,
    undo,
    redo,
    hasUnsavedChanges,
    saveJourney,
    isLoading
  } = useJourneyStore();

  // Convert journey steps to React Flow nodes
  const convertStepsToNodes = useCallback((steps: JourneyStep[]): Node[] => {
    return steps.map(step => ({
      id: step.id,
      type: 'journeyStep',
      position: step.position,
      data: {
        ...step,
        isSelected: selectedStep === step.id,
        onSelect: selectStep,
        onDelete: deleteStep
      }
    }));
  }, [selectedStep, selectStep, deleteStep]);

  // Convert journey connections to React Flow edges
  const convertConnectionsToEdges = useCallback((connections: JourneyConnection[]): Edge[] => {
    return connections.map(conn => ({
      id: conn.id,
      source: conn.source,
      target: conn.target,
      type: 'smoothstep',
      animated: true,
      style: { stroke: '#6b7280' }
    }));
  }, []);

  // Update React Flow nodes/edges when journey changes
  useEffect(() => {
    setNodes(convertStepsToNodes(journey.steps));
    setEdges(convertConnectionsToEdges(journey.connections));
  }, [journey.steps, journey.connections, convertStepsToNodes, convertConnectionsToEdges, setNodes, setEdges]);

  // Handle node position changes
  const handleNodeDrag = useCallback((event: React.MouseEvent, node: Node) => {
    moveStep(node.id, node.position);
  }, [moveStep]);

  // Handle new connections
  const onConnect = useCallback((params: Connection) => {
    if (params.source && params.target) {
      addConnection(params.source, params.target);
    }
  }, [addConnection]);

  // Handle drop of new steps
  const onDrop = useCallback((event: React.DragEvent) => {
    event.preventDefault();

    const reactFlowBounds = reactFlowWrapper.current?.getBoundingClientRect();
    if (!reactFlowBounds) {return;}

    const stepTypeId = event.dataTransfer.getData('application/steptype');
    const stepType = stepTypes.find(type => type.id === stepTypeId);
    
    if (!stepType) {return;}

    const position = screenToFlowPosition({
      x: event.clientX - reactFlowBounds.left,
      y: event.clientY - reactFlowBounds.top,
    });

    addStep(stepType, position);
  }, [screenToFlowPosition, addStep]);

  const onDragOver = useCallback((event: React.DragEvent) => {
    event.preventDefault();
    event.dataTransfer.dropEffect = 'move';
  }, []);

  // Keyboard shortcuts
  useEffect(() => {
    const handleKeyPress = (event: KeyboardEvent) => {
      if (event.ctrlKey || event.metaKey) {
        switch (event.key) {
          case 'z':
            if (event.shiftKey) {
              redo();
            } else {
              undo();
            }
            event.preventDefault();
            break;
          case 's':
            saveJourney();
            event.preventDefault();
            break;
        }
      }
    };

    document.addEventListener('keydown', handleKeyPress);
    return () => document.removeEventListener('keydown', handleKeyPress);
  }, [undo, redo, saveJourney]);

  return (
    <div className="journey-builder-flow">
      {/* Toolbar */}
      <div className="toolbar">
        <div className="toolbar-left">
          <button
            onClick={undo}
            className="toolbar-button"
            title="Undo (Ctrl+Z)"
          >
            ↶
          </button>
          <button
            onClick={redo}
            className="toolbar-button"
            title="Redo (Ctrl+Shift+Z)"
          >
            ↷
          </button>
        </div>
        
        <div className="toolbar-center">
          <h2>{journey.name}</h2>
          {hasUnsavedChanges && <span className="unsaved-indicator">●</span>}
        </div>
        
        <div className="toolbar-right">
          <button onClick={onPreview} className="toolbar-button secondary">
            Preview
          </button>
          <button 
            onClick={saveJourney} 
            className="toolbar-button primary"
            disabled={isLoading}
          >
            {isLoading ? 'Saving...' : 'Save'}
          </button>
        </div>
      </div>

      {/* Step Palette */}
      <div className="step-palette">
        <h3>Journey Steps</h3>
        <div className="step-types">
          {stepTypes.map(stepType => (
            <div
              key={stepType.id}
              className={`step-type step-type-${stepType.stage}`}
              draggable
              onDragStart={(event) => {
                event.dataTransfer.setData('application/steptype', stepType.id);
                event.dataTransfer.effectAllowed = 'move';
              }}
            >
              <span className="step-icon">{stepType.icon}</span>
              <div className="step-info">
                <div className="step-name">{stepType.name}</div>
                <div className="step-description">{stepType.description}</div>
              </div>
            </div>
          ))}
        </div>
      </div>

      {/* Main Flow Canvas */}
      <div className="flow-container" ref={reactFlowWrapper}>
        <ReactFlow
          nodes={nodes}
          edges={edges}
          onNodesChange={onNodesChange}
          onEdgesChange={onEdgesChange}
          onConnect={onConnect}
          onNodeDrag={handleNodeDrag}
          onDrop={onDrop}
          onDragOver={onDragOver}
          nodeTypes={nodeTypes}
          connectionMode={ConnectionMode.Loose}
          fitView
          attributionPosition="bottom-left"
        >
          <Background variant="lines" gap={20} size={1} />
          <Controls />
          <MiniMap />
        </ReactFlow>
      </div>

      <style jsx>{`
        .journey-builder-flow {
          display: flex;
          flex-direction: column;
          height: 100vh;
          background: #f9fafb;
        }

        .toolbar {
          display: flex;
          justify-content: space-between;
          align-items: center;
          padding: 12px 24px;
          background: white;
          border-bottom: 1px solid #e5e7eb;
          z-index: 10;
        }

        .toolbar-left,
        .toolbar-right {
          display: flex;
          gap: 8px;
        }

        .toolbar-center {
          display: flex;
          align-items: center;
          gap: 8px;
        }

        .toolbar-center h2 {
          margin: 0;
          font-size: 18px;
          font-weight: 600;
          color: #1f2937;
        }

        .unsaved-indicator {
          color: #f59e0b;
          font-size: 20px;
        }

        .toolbar-button {
          padding: 8px 16px;
          border: 1px solid #d1d5db;
          border-radius: 6px;
          background: white;
          color: #374151;
          cursor: pointer;
          font-size: 14px;
          transition: all 0.2s ease;
        }

        .toolbar-button:hover {
          background: #f3f4f6;
        }

        .toolbar-button.primary {
          background: #3b82f6;
          color: white;
          border-color: #3b82f6;
        }

        .toolbar-button.primary:hover {
          background: #2563eb;
        }

        .toolbar-button:disabled {
          opacity: 0.5;
          cursor: not-allowed;
        }

        .step-palette {
          position: absolute;
          top: 80px;
          left: 16px;
          width: 280px;
          background: white;
          border: 1px solid #e5e7eb;
          border-radius: 8px;
          padding: 16px;
          z-index: 5;
          max-height: calc(100vh - 120px);
          overflow-y: auto;
        }

        .step-palette h3 {
          margin: 0 0 16px 0;
          font-size: 16px;
          font-weight: 600;
          color: #1f2937;
        }

        .step-types {
          display: flex;
          flex-direction: column;
          gap: 8px;
        }

        .step-type {
          display: flex;
          align-items: center;
          gap: 12px;
          padding: 12px;
          border: 1px solid #e5e7eb;
          border-radius: 6px;
          cursor: grab;
          transition: all 0.2s ease;
          user-select: none;
        }

        .step-type:hover {
          border-color: #3b82f6;
          background: #f8fafc;
        }

        .step-type:active {
          cursor: grabbing;
        }

        .step-type-awareness {
          border-left: 4px solid #3b82f6;
        }

        .step-type-consideration {
          border-left: 4px solid #10b981;
        }

        .step-type-conversion {
          border-left: 4px solid #f59e0b;
        }

        .step-type-retention {
          border-left: 4px solid #8b5cf6;
        }

        .step-icon {
          font-size: 24px;
        }

        .step-info {
          flex: 1;
        }

        .step-name {
          font-weight: 500;
          color: #1f2937;
          font-size: 14px;
        }

        .step-description {
          font-size: 12px;
          color: #6b7280;
          margin-top: 2px;
        }

        .flow-container {
          flex: 1;
          position: relative;
        }

        .react-flow__attribution {
          background: rgba(255, 255, 255, 0.8);
          padding: 4px 8px;
          border-radius: 4px;
        }
      `}</style>
    </div>
  );
};

export const JourneyBuilderFlow: React.FC<JourneyBuilderFlowProps> = (props) => {
  return (
    <ReactFlowProvider>
      <JourneyBuilderFlowContent {...props} />
    </ReactFlowProvider>
  );
};