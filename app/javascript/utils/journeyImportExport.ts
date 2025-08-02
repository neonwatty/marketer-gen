import type { Journey } from '../types/journey';

export interface ExportOptions {
  format: 'json' | 'csv';
  includeMetadata?: boolean;
  includePositions?: boolean;
}

export interface ImportResult {
  success: boolean;
  journey?: Journey;
  errors?: string[];
}

/**
 * Export journey to various formats
 */
export const exportJourney = (journey: Journey, options: ExportOptions = { format: 'json' }): string => {
  switch (options.format) {
    case 'json':
      return exportToJSON(journey, options);
    case 'csv':
      return exportToCSV(journey, options);
    default:
      throw new Error(`Unsupported export format: ${options.format}`);
  }
};

/**
 * Import journey from JSON
 */
export const importJourney = (data: string, format: 'json' | 'csv' = 'json'): ImportResult => {
  try {
    switch (format) {
      case 'json':
        return importFromJSON(data);
      case 'csv':
        return importFromCSV(data);
      default:
        return {
          success: false,
          errors: [`Unsupported import format: ${format}`]
        };
    }
  } catch (error) {
    return {
      success: false,
      errors: [error instanceof Error ? error.message : 'Unknown import error']
    };
  }
};

/**
 * Download journey as file
 */
export const downloadJourney = (journey: Journey, options: ExportOptions = { format: 'json' }) => {
  const content = exportJourney(journey, options);
  const filename = `${sanitizeFilename(journey.name)}.${options.format}`;
  const mimeType = options.format === 'json' ? 'application/json' : 'text/csv';
  
  const blob = new Blob([content], { type: mimeType });
  const url = URL.createObjectURL(blob);
  
  const a = document.createElement('a');
  a.href = url;
  a.download = filename;
  document.body.appendChild(a);
  a.click();
  document.body.removeChild(a);
  URL.revokeObjectURL(url);
};

/**
 * Upload and import journey from file
 */
export const uploadJourney = (): Promise<ImportResult> => {
  return new Promise((resolve) => {
    const input = document.createElement('input');
    input.type = 'file';
    input.accept = '.json,.csv';
    
    input.onchange = async (event) => {
      const file = (event.target as HTMLInputElement).files?.[0];
      if (!file) {
        resolve({
          success: false,
          errors: ['No file selected']
        });
        return;
      }
      
      try {
        const content = await file.text();
        const format = file.name.endsWith('.csv') ? 'csv' : 'json';
        const result = importJourney(content, format);
        resolve(result);
      } catch (error) {
        resolve({
          success: false,
          errors: [error instanceof Error ? error.message : 'Failed to read file']
        });
      }
    };
    
    input.click();
  });
};

// Private helper functions

const exportToJSON = (journey: Journey, options: ExportOptions): string => {
  const exportData: any = {
    version: '1.0',
    exportedAt: new Date().toISOString(),
    journey: {
      name: journey.name,
      description: journey.description,
      status: journey.status,
      steps: journey.steps.map(step => ({
        id: step.id,
        type: step.type,
        title: step.title,
        description: step.description,
        stage: step.stage,
        timing: step.timing,
        data: step.data,
        ...(options.includePositions && { position: step.position })
      })),
      connections: journey.connections
    }
  };

  if (options.includeMetadata) {
    exportData.metadata = {
      createdAt: journey.createdAt,
      updatedAt: journey.updatedAt,
      stepCount: journey.steps.length,
      connectionCount: journey.connections.length,
      stagesCovered: [...new Set(journey.steps.map(s => s.stage))]
    };
  }

  return JSON.stringify(exportData, null, 2);
};

const exportToCSV = (journey: Journey, options: ExportOptions): string => {
  const headers = [
    'Step ID',
    'Title',
    'Type',
    'Stage',
    'Description',
    'Timing'
  ];

  if (options.includePositions) {
    headers.push('Position X', 'Position Y');
  }

  const rows = journey.steps.map(step => {
    const row = [
      step.id,
      escapeCSV(step.data.title),
      step.type,
      step.stage,
      escapeCSV(step.data.description),
      step.data.timing
    ];

    if (options.includePositions) {
      row.push(step.position.x.toString(), step.position.y.toString());
    }

    return row;
  });

  const csvContent = [headers.join(','), ...rows.map(row => row.join(','))].join('\n');

  // Add journey metadata as comments at the top
  const metadata = [
    `# Journey: ${journey.name}`,
    `# Description: ${journey.description || 'No description'}`,
    `# Status: ${journey.status}`,
    `# Steps: ${journey.steps.length}`,
    `# Connections: ${journey.connections.length}`,
    `# Exported: ${new Date().toISOString()}`,
    ''
  ].join('\n');

  return metadata + csvContent;
};

const importFromJSON = (data: string): ImportResult => {
  try {
    const parsed = JSON.parse(data);
    
    // Validate structure
    if (!parsed.journey) {
      return {
        success: false,
        errors: ['Invalid file format: missing journey data']
      };
    }

    const journeyData = parsed.journey;
    
    // Validate required fields
    if (!journeyData.name) {
      return {
        success: false,
        errors: ['Invalid journey: missing name']
      };
    }

    if (!Array.isArray(journeyData.steps)) {
      return {
        success: false,
        errors: ['Invalid journey: steps must be an array']
      };
    }

    if (!Array.isArray(journeyData.connections)) {
      return {
        success: false,
        errors: ['Invalid journey: connections must be an array']
      };
    }

    // Validate steps
    const errors: string[] = [];
    journeyData.steps.forEach((step: any, index: number) => {
      if (!step.id) {errors.push(`Step ${index + 1}: missing ID`);}
      if (!step.type) {errors.push(`Step ${index + 1}: missing type`);}
      if (!step.stage) {errors.push(`Step ${index + 1}: missing stage`);}
      if (!step.data) {errors.push(`Step ${index + 1}: missing data`);}
    });

    if (errors.length > 0) {
      return {
        success: false,
        errors
      };
    }

    // Create journey object
    const journey: Journey = {
      name: journeyData.name,
      description: journeyData.description || '',
      status: journeyData.status || 'draft',
      steps: journeyData.steps.map((step: any) => ({
        id: step.id,
        type: step.type,
        title: step.title || step.data.title,
        description: step.description || step.data.description,
        stage: step.stage,
        timing: step.timing || step.data.timing,
        position: step.position || { x: Math.random() * 400 + 100, y: Math.random() * 300 + 100 },
        data: step.data
      })),
      connections: journeyData.connections
    };

    return {
      success: true,
      journey
    };
  } catch (error) {
    return {
      success: false,
      errors: [error instanceof Error ? error.message : 'Failed to parse JSON']
    };
  }
};

const importFromCSV = (data: string): ImportResult => {
  try {
    const lines = data.split('\n').filter(line => !line.startsWith('#') && line.trim());
    
    if (lines.length < 2) {
      return {
        success: false,
        errors: ['CSV file must have at least a header row and one data row']
      };
    }

    const headers = lines[0].split(',').map(h => h.trim());
    const dataRows = lines.slice(1);

    // Find required column indices
    const idIndex = headers.findIndex(h => h.toLowerCase().includes('id'));
    const titleIndex = headers.findIndex(h => h.toLowerCase().includes('title'));
    const typeIndex = headers.findIndex(h => h.toLowerCase().includes('type'));
    const stageIndex = headers.findIndex(h => h.toLowerCase().includes('stage'));
    const descriptionIndex = headers.findIndex(h => h.toLowerCase().includes('description'));
    const timingIndex = headers.findIndex(h => h.toLowerCase().includes('timing'));

    if (idIndex === -1 || titleIndex === -1 || typeIndex === -1 || stageIndex === -1) {
      return {
        success: false,
        errors: ['CSV must have columns for ID, Title, Type, and Stage']
      };
    }

    const steps = dataRows.map((row, index) => {
      const cols = row.split(',').map(c => c.trim().replace(/^"|"$/g, ''));
      
      return {
        id: cols[idIndex] || `step-${index + 1}`,
        type: cols[typeIndex] || 'email_sequence',
        title: cols[titleIndex] || `Step ${index + 1}`,
        description: cols[descriptionIndex] || '',
        stage: cols[stageIndex] || 'awareness',
        timing: cols[timingIndex] || 'immediate',
        position: { x: (index % 4) * 250 + 100, y: Math.floor(index / 4) * 150 + 100 },
        data: {
          title: cols[titleIndex] || `Step ${index + 1}`,
          description: cols[descriptionIndex] || '',
          timing: cols[timingIndex] || 'immediate'
        }
      };
    });

    const journey: Journey = {
      name: 'Imported Journey',
      description: 'Journey imported from CSV',
      status: 'draft',
      steps,
      connections: []
    };

    return {
      success: true,
      journey
    };
  } catch (error) {
    return {
      success: false,
      errors: [error instanceof Error ? error.message : 'Failed to parse CSV']
    };
  }
};

const escapeCSV = (value: string): string => {
  if (value.includes(',') || value.includes('"') || value.includes('\n')) {
    return `"${value.replace(/"/g, '""')}"`;
  }
  return value;
};

const sanitizeFilename = (filename: string): string => {
  return filename
    .replace(/[^a-z0-9]/gi, '_')
    .replace(/_+/g, '_')
    .replace(/^_|_$/g, '')
    .toLowerCase() || 'journey';
};