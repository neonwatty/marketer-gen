import { create } from 'zustand';
import { immer } from 'zustand/middleware/immer';
import { subscribeWithSelector } from 'zustand/middleware';
import { v4 as uuidv4 } from 'uuid';
import debounce from 'lodash.debounce';
import type { Journey, JourneyStep, JourneyConnection, JourneyBuilderState, StepType } from '../types/journey';

interface JourneyStoreActions {
  // Journey management
  loadJourney: (journey: Journey) => void;
  saveJourney: () => Promise<void>;
  resetJourney: () => void;
  
  // Step management
  addStep: (stepType: StepType, position: { x: number; y: number }) => void;
  updateStep: (stepId: string, updates: Partial<JourneyStep>) => void;
  deleteStep: (stepId: string) => void;
  selectStep: (stepId: string | null) => void;
  moveStep: (stepId: string, position: { x: number; y: number }) => void;
  
  // Connection management
  addConnection: (source: string, target: string) => void;
  deleteConnection: (connectionId: string) => void;
  
  // Undo/Redo
  undo: () => void;
  redo: () => void;
  pushToHistory: () => void;
  
  // Drag and drop
  setDraggedStepType: (stepType: StepType | null) => void;
  
  // Auto-save
  enableAutoSave: () => void;
  disableAutoSave: () => void;
}

type JourneyStore = JourneyBuilderState & JourneyStoreActions;

const initialJourney: Journey = {
  name: 'New Journey',
  description: '',
  steps: [],
  connections: [],
  status: 'draft'
};

export const useJourneyStore = create<JourneyStore>()(
  subscribeWithSelector(
    immer((set, get) => ({
      // Initial state
      journey: initialJourney,
      selectedStep: null,
      draggedStepType: null,
      isLoading: false,
      hasUnsavedChanges: false,
      undoStack: [],
      redoStack: [],

      // Journey management
      loadJourney: (journey: Journey) => set((state) => {
        state.journey = journey;
        state.hasUnsavedChanges = false;
        state.undoStack = [];
        state.redoStack = [];
      }),

      saveJourney: async () => {
        const state = get();
        set((draft) => {
          draft.isLoading = true;
        });

        try {
          const response = await fetch('/journey_templates', {
            method: 'POST',
            headers: {
              'Content-Type': 'application/json',
              'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]')?.getAttribute('content') || ''
            },
            body: JSON.stringify({
              journey_template: {
                name: state.journey.name,
                description: state.journey.description,
                steps_data: state.journey.steps,
                connections_data: state.journey.connections,
                status: state.journey.status
              }
            })
          });

          if (response.ok) {
            const savedJourney = await response.json();
            set((draft) => {
              draft.journey.id = savedJourney.id;
              draft.hasUnsavedChanges = false;
              draft.isLoading = false;
            });
          } else {
            throw new Error('Failed to save journey');
          }
        } catch (error) {
          console.error('Error saving journey:', error);
          set((draft) => {
            draft.isLoading = false;
          });
        }
      },

      resetJourney: () => set((state) => {
        state.journey = { ...initialJourney };
        state.selectedStep = null;
        state.hasUnsavedChanges = false;
        state.undoStack = [];
        state.redoStack = [];
      }),

      // Step management
      addStep: (stepType: StepType, position: { x: number; y: number }) => set((state) => {
        const newStep: JourneyStep = {
          id: uuidv4(),
          type: stepType.id,
          title: stepType.name,
          description: stepType.description,
          stage: stepType.stage as any,
          timing: 'immediate',
          position,
          data: {
            title: stepType.name,
            description: stepType.description,
            timing: 'immediate',
            ...stepType.defaultData
          }
        };

        state.journey.steps.push(newStep);
        state.selectedStep = newStep.id;
        state.hasUnsavedChanges = true;
      }),

      updateStep: (stepId: string, updates: Partial<JourneyStep>) => set((state) => {
        const stepIndex = state.journey.steps.findIndex(step => step.id === stepId);
        if (stepIndex !== -1) {
          Object.assign(state.journey.steps[stepIndex], updates);
          state.hasUnsavedChanges = true;
        }
      }),

      deleteStep: (stepId: string) => set((state) => {
        state.journey.steps = state.journey.steps.filter(step => step.id !== stepId);
        state.journey.connections = state.journey.connections.filter(
          conn => conn.source !== stepId && conn.target !== stepId
        );
        if (state.selectedStep === stepId) {
          state.selectedStep = null;
        }
        state.hasUnsavedChanges = true;
      }),

      selectStep: (stepId: string | null) => set((state) => {
        state.selectedStep = stepId;
      }),

      moveStep: (stepId: string, position: { x: number; y: number }) => set((state) => {
        const step = state.journey.steps.find(step => step.id === stepId);
        if (step) {
          step.position = position;
          state.hasUnsavedChanges = true;
        }
      }),

      // Connection management
      addConnection: (source: string, target: string) => set((state) => {
        // Check if connection already exists
        const exists = state.journey.connections.some(
          conn => conn.source === source && conn.target === target
        );
        
        if (!exists) {
          const newConnection: JourneyConnection = {
            id: uuidv4(),
            source,
            target,
            type: 'default'
          };
          state.journey.connections.push(newConnection);
          state.hasUnsavedChanges = true;
        }
      }),

      deleteConnection: (connectionId: string) => set((state) => {
        state.journey.connections = state.journey.connections.filter(
          conn => conn.id !== connectionId
        );
        state.hasUnsavedChanges = true;
      }),

      // Undo/Redo
      pushToHistory: () => set((state) => {
        // Clone current journey state to history
        const currentState = JSON.parse(JSON.stringify(state.journey));
        state.undoStack.push(currentState);
        
        // Limit undo stack size
        if (state.undoStack.length > 50) {
          state.undoStack.shift();
        }
        
        // Clear redo stack when new action is performed
        state.redoStack = [];
      }),

      undo: () => set((state) => {
        if (state.undoStack.length > 0) {
          const currentState = JSON.parse(JSON.stringify(state.journey));
          state.redoStack.push(currentState);
          
          const previousState = state.undoStack.pop()!;
          state.journey = previousState;
          state.hasUnsavedChanges = true;
        }
      }),

      redo: () => set((state) => {
        if (state.redoStack.length > 0) {
          const currentState = JSON.parse(JSON.stringify(state.journey));
          state.undoStack.push(currentState);
          
          const nextState = state.redoStack.pop()!;
          state.journey = nextState;
          state.hasUnsavedChanges = true;
        }
      }),

      // Drag and drop
      setDraggedStepType: (stepType: StepType | null) => set((state) => {
        state.draggedStepType = stepType;
      }),

      // Auto-save (placeholder methods)
      enableAutoSave: () => {
        // Will implement auto-save with debounced function
      },

      disableAutoSave: () => {
        // Will implement auto-save cleanup
      }
    }))
  )
);

// Auto-save functionality
const debouncedSave = debounce(() => {
  const store = useJourneyStore.getState();
  if (store.hasUnsavedChanges && !store.isLoading) {
    store.saveJourney();
  }
}, 2000);

// Subscribe to changes for auto-save
useJourneyStore.subscribe(
  (state) => state.hasUnsavedChanges,
  (hasUnsavedChanges) => {
    if (hasUnsavedChanges) {
      debouncedSave();
    }
  }
);

// Subscribe to step/connection changes for history
useJourneyStore.subscribe(
  (state) => ({ steps: state.journey.steps, connections: state.journey.connections }),
  () => {
    const store = useJourneyStore.getState();
    store.pushToHistory();
  }
);