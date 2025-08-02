import type { Journey, JourneyStep, JourneyConnection } from '../types/journey';

export interface ValidationError {
  id: string;
  type: 'error' | 'warning';
  message: string;
  stepId?: string;
  connectionId?: string;
}

export interface ValidationResult {
  isValid: boolean;
  errors: ValidationError[];
  warnings: ValidationError[];
}

export const validateJourney = (journey: Journey): ValidationResult => {
  const errors: ValidationError[] = [];
  const warnings: ValidationError[] = [];

  // Validate journey has steps
  if (journey.steps.length === 0) {
    errors.push({
      id: 'no-steps',
      type: 'error',
      message: 'Journey must have at least one step'
    });
    return { isValid: false, errors, warnings };
  }

  // Validate journey has a name
  if (!journey.name || journey.name.trim() === '') {
    errors.push({
      id: 'no-name',
      type: 'error',
      message: 'Journey must have a name'
    });
  }

  // Validate each step
  journey.steps.forEach(step => {
    const stepErrors = validateStep(step, journey);
    errors.push(...stepErrors.filter(e => e.type === 'error'));
    warnings.push(...stepErrors.filter(e => e.type === 'warning'));
  });

  // Validate connections
  journey.connections.forEach(connection => {
    const connectionErrors = validateConnection(connection, journey);
    errors.push(...connectionErrors.filter(e => e.type === 'error'));
    warnings.push(...connectionErrors.filter(e => e.type === 'warning'));
  });

  // Check for orphaned steps (no connections in or out)
  const connectedStepIds = new Set([
    ...journey.connections.map(c => c.source),
    ...journey.connections.map(c => c.target)
  ]);

  journey.steps.forEach(step => {
    if (journey.steps.length > 1 && !connectedStepIds.has(step.id)) {
      warnings.push({
        id: `orphaned-step-${step.id}`,
        type: 'warning',
        message: `Step "${step.data.title}" is not connected to any other steps`,
        stepId: step.id
      });
    }
  });

  // Check for circular dependencies
  const circularDependencies = findCircularDependencies(journey);
  if (circularDependencies.length > 0) {
    errors.push({
      id: 'circular-dependencies',
      type: 'error',
      message: `Circular dependencies detected: ${circularDependencies.join(' → ')}`
    });
  }

  // Validate journey flow progression
  const flowErrors = validateJourneyFlow(journey);
  errors.push(...flowErrors.filter(e => e.type === 'error'));
  warnings.push(...flowErrors.filter(e => e.type === 'warning'));

  return {
    isValid: errors.length === 0,
    errors,
    warnings
  };
};

const validateStep = (step: JourneyStep, journey: Journey): ValidationError[] => {
  const errors: ValidationError[] = [];

  // Validate step has title
  if (!step.data.title || step.data.title.trim() === '') {
    errors.push({
      id: `step-no-title-${step.id}`,
      type: 'error',
      message: 'Step must have a title',
      stepId: step.id
    });
  }

  // Validate step has description
  if (!step.data.description || step.data.description.trim() === '') {
    errors.push({
      id: `step-no-description-${step.id}`,
      type: 'warning',
      message: 'Step should have a description',
      stepId: step.id
    });
  }

  // Validate step timing
  if (!step.data.timing) {
    errors.push({
      id: `step-no-timing-${step.id}`,
      type: 'warning',
      message: 'Step should specify timing',
      stepId: step.id
    });
  }

  // Validate step stage
  const validStages = ['awareness', 'consideration', 'conversion', 'retention'];
  if (!validStages.includes(step.stage)) {
    errors.push({
      id: `step-invalid-stage-${step.id}`,
      type: 'error',
      message: `Step has invalid stage: ${step.stage}`,
      stepId: step.id
    });
  }

  // Validate step type specific requirements
  switch (step.type) {
    case 'email_sequence':
    case 'newsletter':
      if (!step.data.subject || step.data.subject.trim() === '') {
        errors.push({
          id: `step-no-email-subject-${step.id}`,
          type: 'warning',
          message: 'Email step should have a subject line',
          stepId: step.id
        });
      }
      break;
    
    case 'social_media':
      if (!step.data.channel) {
        errors.push({
          id: `step-no-social-channel-${step.id}`,
          type: 'warning',
          message: 'Social media step should specify a channel',
          stepId: step.id
        });
      }
      break;
      
    case 'webinar':
    case 'demo':
      if (!step.data.duration || step.data.duration <= 0) {
        errors.push({
          id: `step-no-duration-${step.id}`,
          type: 'warning',
          message: 'Webinar/Demo step should specify duration',
          stepId: step.id
        });
      }
      break;
  }

  // Validate position
  if (!step.position || typeof step.position.x !== 'number' || typeof step.position.y !== 'number') {
    errors.push({
      id: `step-invalid-position-${step.id}`,
      type: 'error',
      message: 'Step has invalid position',
      stepId: step.id
    });
  }

  return errors;
};

const validateConnection = (connection: JourneyConnection, journey: Journey): ValidationError[] => {
  const errors: ValidationError[] = [];

  // Validate source and target exist
  const sourceStep = journey.steps.find(s => s.id === connection.source);
  const targetStep = journey.steps.find(s => s.id === connection.target);

  if (!sourceStep) {
    errors.push({
      id: `connection-invalid-source-${connection.id}`,
      type: 'error',
      message: 'Connection references non-existent source step',
      connectionId: connection.id
    });
  }

  if (!targetStep) {
    errors.push({
      id: `connection-invalid-target-${connection.id}`,
      type: 'error',
      message: 'Connection references non-existent target step',
      connectionId: connection.id
    });
  }

  // Validate connection doesn't connect step to itself
  if (connection.source === connection.target) {
    errors.push({
      id: `connection-self-reference-${connection.id}`,
      type: 'error',
      message: 'Step cannot connect to itself',
      connectionId: connection.id
    });
  }

  return errors;
};

const findCircularDependencies = (journey: Journey): string[] => {
  const graph = new Map<string, string[]>();
  
  // Build adjacency list
  journey.connections.forEach(connection => {
    if (!graph.has(connection.source)) {
      graph.set(connection.source, []);
    }
    graph.get(connection.source)!.push(connection.target);
  });

  // DFS to detect cycles
  const visited = new Set<string>();
  const recursionStack = new Set<string>();
  const cycle: string[] = [];

  const dfs = (stepId: string, path: string[]): boolean => {
    if (recursionStack.has(stepId)) {
      // Found cycle, extract it
      const cycleStart = path.indexOf(stepId);
      cycle.push(...path.slice(cycleStart), stepId);
      return true;
    }

    if (visited.has(stepId)) {
      return false;
    }

    visited.add(stepId);
    recursionStack.add(stepId);

    const neighbors = graph.get(stepId) || [];
    for (const neighbor of neighbors) {
      if (dfs(neighbor, [...path, stepId])) {
        return true;
      }
    }

    recursionStack.delete(stepId);
    return false;
  };

  // Check all steps
  for (const step of journey.steps) {
    if (!visited.has(step.id)) {
      if (dfs(step.id, [])) {
        break;
      }
    }
  }

  return cycle;
};

const validateJourneyFlow = (journey: Journey): ValidationError[] => {
  const errors: ValidationError[] = [];

  // Check for logical stage progression
  const stageOrder = ['awareness', 'consideration', 'conversion', 'retention'];
  const stepsByStage = journey.steps.reduce((acc, step) => {
    if (!acc[step.stage]) {acc[step.stage] = [];}
    acc[step.stage].push(step);
    return acc;
  }, {} as Record<string, JourneyStep[]>);

  // Warn if stages are skipped
  const presentStages = Object.keys(stepsByStage);
  const stageIndices = presentStages.map(stage => stageOrder.indexOf(stage)).filter(i => i !== -1);
  
  for (let i = 1; i < stageIndices.length; i++) {
    if (stageIndices[i] - stageIndices[i-1] > 1) {
      const skippedStages = stageOrder.slice(stageIndices[i-1] + 1, stageIndices[i]);
      errors.push({
        id: 'skipped-stages',
        type: 'warning',
        message: `Journey skips stages: ${skippedStages.join(', ')}`
      });
    }
  }

  // Check for backwards flow (later stage connecting to earlier stage)
  journey.connections.forEach(connection => {
    const sourceStep = journey.steps.find(s => s.id === connection.source);
    const targetStep = journey.steps.find(s => s.id === connection.target);
    
    if (sourceStep && targetStep) {
      const sourceStageIndex = stageOrder.indexOf(sourceStep.stage);
      const targetStageIndex = stageOrder.indexOf(targetStep.stage);
      
      if (sourceStageIndex > targetStageIndex && sourceStageIndex !== -1 && targetStageIndex !== -1) {
        errors.push({
          id: `backwards-flow-${connection.id}`,
          type: 'warning',
          message: `${sourceStep.stage} step connects backwards to ${targetStep.stage} step`,
          connectionId: connection.id
        });
      }
    }
  });

  return errors;
};

export const getStepValidationErrors = (stepId: string, journey: Journey): ValidationError[] => {
  const validation = validateJourney(journey);
  return validation.errors.concat(validation.warnings).filter(error => error.stepId === stepId);
};

export const getConnectionValidationErrors = (connectionId: string, journey: Journey): ValidationError[] => {
  const validation = validateJourney(journey);
  return validation.errors.concat(validation.warnings).filter(error => error.connectionId === connectionId);
};