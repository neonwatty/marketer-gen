// Journey Builder Types
export interface JourneyStep {
  id: string;
  type: string;
  title: string;
  description: string;
  stage: 'awareness' | 'consideration' | 'conversion' | 'retention';
  timing: string;
  position: { x: number; y: number };
  data: {
    title: string;
    description: string;
    timing: string;
    subject?: string;
    template?: string;
    channel?: string;
    conditions?: string[];
    config?: Record<string, any>;
  };
}

export interface JourneyConnection {
  id: string;
  source: string;
  target: string;
  sourceHandle?: string;
  targetHandle?: string;
  type?: string;
  data?: {
    condition?: string;
    label?: string;
  };
}

export interface Journey {
  id?: string;
  name: string;
  description: string;
  steps: JourneyStep[];
  connections: JourneyConnection[];
  status: 'draft' | 'published' | 'archived';
  createdAt?: string;
  updatedAt?: string;
}

export interface JourneyTemplate {
  id: string;
  name: string;
  description: string;
  category: string;
  campaignType: string;
  steps: JourneyStep[];
  connections: JourneyConnection[];
  version: string;
  isPublished: boolean;
}

export interface StepType {
  id: string;
  name: string;
  description: string;
  stage: string;
  icon: string;
  defaultData: Partial<JourneyStep['data']>;
}

export interface JourneyBuilderState {
  journey: Journey;
  selectedStep: string | null;
  draggedStepType: StepType | null;
  isLoading: boolean;
  hasUnsavedChanges: boolean;
  undoStack: Journey[];
  redoStack: Journey[];
}

export interface AISuggestion {
  id: string;
  type: 'step' | 'connection' | 'optimization';
  title: string;
  description: string;
  confidence: number;
  data: any;
}