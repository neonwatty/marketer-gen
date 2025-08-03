import React, { useState, useCallback, useMemo, memo, useEffect } from 'react';
import { DndProvider, useDrag, useDrop } from 'react-dnd';
import { HTML5Backend } from 'react-dnd-html5-backend';
import { 
  ChartDataPoint, 
  ChartOptions, 
  DEFAULT_THEME,
  AdvancedLineChart,
  AdvancedBarChart,
  DonutChart,
  FunnelVisualization,
  HeatmapDisplay,
  ScatterPlot,
  TreeMapChart,
  RadialBarChartComponent
} from './AdvancedCharts';

// Chart Builder Types
export interface ChartConfiguration {
  id: string;
  type: ChartType;
  title: string;
  dataSource: string;
  metrics: string[];
  dimensions: string[];
  filters: ChartFilter[];
  options: ChartOptions;
  position: { x: number; y: number };
  size: { width: number; height: number };
}

export interface ChartFilter {
  field: string;
  operator: 'equals' | 'contains' | 'greater_than' | 'less_than' | 'between';
  value: any;
}

export interface DataSource {
  id: string;
  name: string;
  fields: DataField[];
  type: 'social_media' | 'email' | 'google_analytics' | 'crm' | 'custom';
}

export interface DataField {
  name: string;
  type: 'string' | 'number' | 'date' | 'boolean';
  label: string;
}

export type ChartType = 
  | 'line' 
  | 'bar' 
  | 'area' 
  | 'pie' 
  | 'donut' 
  | 'funnel' 
  | 'heatmap' 
  | 'scatter' 
  | 'treemap' 
  | 'radial_bar';

// Available data sources
const AVAILABLE_DATA_SOURCES: DataSource[] = [
  {
    id: 'social_media',
    name: 'Social Media',
    type: 'social_media',
    fields: [
      { name: 'platform', type: 'string', label: 'Platform' },
      { name: 'engagement', type: 'number', label: 'Engagement' },
      { name: 'followers', type: 'number', label: 'Followers' },
      { name: 'reach', type: 'number', label: 'Reach' },
      { name: 'impressions', type: 'number', label: 'Impressions' },
      { name: 'date', type: 'date', label: 'Date' }
    ]
  },
  {
    id: 'email',
    name: 'Email Marketing',
    type: 'email',
    fields: [
      { name: 'campaign_name', type: 'string', label: 'Campaign' },
      { name: 'open_rate', type: 'number', label: 'Open Rate' },
      { name: 'click_rate', type: 'number', label: 'Click Rate' },
      { name: 'bounce_rate', type: 'number', label: 'Bounce Rate' },
      { name: 'unsubscribe_rate', type: 'number', label: 'Unsubscribe Rate' },
      { name: 'sent_date', type: 'date', label: 'Sent Date' }
    ]
  },
  {
    id: 'google_analytics',
    name: 'Google Analytics',
    type: 'google_analytics',
    fields: [
      { name: 'page_path', type: 'string', label: 'Page Path' },
      { name: 'sessions', type: 'number', label: 'Sessions' },
      { name: 'pageviews', type: 'number', label: 'Pageviews' },
      { name: 'bounce_rate', type: 'number', label: 'Bounce Rate' },
      { name: 'conversion_rate', type: 'number', label: 'Conversion Rate' },
      { name: 'date', type: 'date', label: 'Date' }
    ]
  },
  {
    id: 'crm',
    name: 'CRM Data',
    type: 'crm',
    fields: [
      { name: 'stage', type: 'string', label: 'Pipeline Stage' },
      { name: 'value', type: 'number', label: 'Opportunity Value' },
      { name: 'probability', type: 'number', label: 'Win Probability' },
      { name: 'lead_source', type: 'string', label: 'Lead Source' },
      { name: 'created_date', type: 'date', label: 'Created Date' }
    ]
  }
];

// Chart type configurations
const CHART_TYPE_CONFIGS = {
  line: { 
    name: 'Line Chart', 
    icon: '📈', 
    description: 'Show trends over time',
    requiresTimeDimension: true,
    maxMetrics: 5
  },
  bar: { 
    name: 'Bar Chart', 
    icon: '📊', 
    description: 'Compare categories',
    requiresTimeDimension: false,
    maxMetrics: 3
  },
  area: { 
    name: 'Area Chart', 
    icon: '📈', 
    description: 'Show cumulative values',
    requiresTimeDimension: true,
    maxMetrics: 5
  },
  pie: { 
    name: 'Pie Chart', 
    icon: '🥧', 
    description: 'Show proportions',
    requiresTimeDimension: false,
    maxMetrics: 1
  },
  donut: { 
    name: 'Donut Chart', 
    icon: '🍩', 
    description: 'Show proportions with center text',
    requiresTimeDimension: false,
    maxMetrics: 1
  },
  funnel: { 
    name: 'Funnel Chart', 
    icon: '🔽', 
    description: 'Show conversion process',
    requiresTimeDimension: false,
    maxMetrics: 1
  },
  heatmap: { 
    name: 'Heatmap', 
    icon: '🔥', 
    description: 'Show data density patterns',
    requiresTimeDimension: false,
    maxMetrics: 1
  },
  scatter: { 
    name: 'Scatter Plot', 
    icon: '⚫', 
    description: 'Show correlations',
    requiresTimeDimension: false,
    maxMetrics: 2
  },
  treemap: { 
    name: 'Tree Map', 
    icon: '🌳', 
    description: 'Show hierarchical data',
    requiresTimeDimension: false,
    maxMetrics: 1
  },
  radial_bar: { 
    name: 'Radial Bar', 
    icon: '🌙', 
    description: 'Show circular metrics',
    requiresTimeDimension: false,
    maxMetrics: 3
  }
};

// Drag and Drop Types
const DND_TYPES = {
  METRIC: 'metric',
  DIMENSION: 'dimension',
  CHART: 'chart'
};

// Draggable Field Component
const DraggableField = memo(({ field, type }: { field: DataField; type: 'metric' | 'dimension' }) => {
  const [{ isDragging }, drag] = useDrag(() => ({
    type: type === 'metric' ? DND_TYPES.METRIC : DND_TYPES.DIMENSION,
    item: { field, type },
    collect: (monitor) => ({
      isDragging: !!monitor.isDragging(),
    }),
  }));

  return (
    <div
      ref={drag}
      className={`p-2 bg-white border border-gray-200 rounded cursor-move text-sm ${
        isDragging ? 'opacity-50' : ''
      } ${type === 'metric' ? 'border-l-4 border-l-blue-500' : 'border-l-4 border-l-green-500'}`}
    >
      <div className="flex items-center">
        <span className="mr-2">
          {type === 'metric' ? '📊' : '🏷️'}
        </span>
        <span className="font-medium">{field.label}</span>
        <span className="ml-auto text-xs text-gray-500">{field.type}</span>
      </div>
    </div>
  );
});

// Drop Zone Component
const DropZone = memo(({ 
  onDrop, 
  children, 
  acceptedType, 
  className,
  placeholder 
}: {
  onDrop: (item: any) => void;
  children: React.ReactNode;
  acceptedType: string;
  className?: string;
  placeholder?: string;
}) => {
  const [{ isOver, canDrop }, drop] = useDrop(() => ({
    accept: acceptedType,
    drop: onDrop,
    collect: (monitor) => ({
      isOver: !!monitor.isOver(),
      canDrop: !!monitor.canDrop(),
    }),
  }));

  return (
    <div
      ref={drop}
      className={`
        ${className || ''}
        ${isOver && canDrop ? 'bg-blue-50 border-blue-300' : ''}
        ${canDrop ? 'border-dashed' : 'border-solid'}
      `}
    >
      {React.Children.count(children) === 0 && placeholder && (
        <div className="text-gray-500 text-sm p-4 text-center">{placeholder}</div>
      )}
      {children}
    </div>
  );
});

// Chart Preview Component
const ChartPreview = memo(({ 
  config, 
  sampleData 
}: { 
  config: ChartConfiguration; 
  sampleData: ChartDataPoint[];
}) => {
  const renderChart = useCallback(() => {
    const commonProps = {
      data: sampleData,
      options: config.options
    };

    switch (config.type) {
      case 'line':
        return <AdvancedLineChart {...commonProps} />;
      case 'bar':
        return <AdvancedBarChart {...commonProps} />;
      case 'donut':
        return <DonutChart {...commonProps} centerText="Preview" />;
      case 'funnel':
        return <FunnelVisualization {...commonProps} />;
      case 'heatmap':
        return <HeatmapDisplay {...commonProps} width={300} height={200} />;
      case 'scatter':
        return <ScatterPlot {...commonProps} />;
      case 'treemap':
        return <TreeMapChart {...commonProps} />;
      case 'radial_bar':
        return <RadialBarChartComponent {...commonProps} />;
      default:
        return <div className="text-gray-500 text-center p-8">Select a chart type</div>;
    }
  }, [config, sampleData]);

  return (
    <div className="h-64 bg-gray-50 border border-gray-200 rounded">
      {renderChart()}
    </div>
  );
});

// Main Custom Chart Builder Component
export const CustomChartBuilder = memo(({ 
  onSave, 
  onCancel, 
  initialConfig,
  brandId: _brandId 
}: {
  onSave: (config: ChartConfiguration) => void;
  onCancel: () => void;
  initialConfig?: ChartConfiguration;
  brandId: string;
}) => {
  const [config, setConfig] = useState<ChartConfiguration>(
    initialConfig || {
      id: '',
      type: 'line',
      title: 'New Chart',
      dataSource: '',
      metrics: [],
      dimensions: [],
      filters: [],
      options: {
        showTooltip: true,
        showLegend: true,
        showGrid: true,
        enableAnimation: true,
        theme: DEFAULT_THEME
      },
      position: { x: 0, y: 0 },
      size: { width: 400, height: 300 }
    }
  );

  const [selectedDataSource, setSelectedDataSource] = useState<DataSource | null>(
    AVAILABLE_DATA_SOURCES.find(ds => ds.id === config.dataSource) || null
  );

  const [previewData, setPreviewData] = useState<ChartDataPoint[]>([]);

  // Generate sample data for preview
  const generateSampleData = useCallback(() => {
    if (!selectedDataSource || config.metrics.length === 0) {
      return [];
    }

    const sampleSize = 10;
    const data: ChartDataPoint[] = [];

    for (let i = 0; i < sampleSize; i++) {
      const point: ChartDataPoint = {
        name: `Sample ${i + 1}`,
        value: Math.floor(Math.random() * 1000) + 100,
        date: new Date(Date.now() - (sampleSize - i) * 24 * 60 * 60 * 1000).toISOString().split('T')[0]
      };

      if (config.type === 'scatter') {
        point.x = Math.floor(Math.random() * 100);
        point.y = Math.floor(Math.random() * 100);
      }

      data.push(point);
    }

    return data;
  }, [selectedDataSource, config.metrics, config.type]);

  useEffect(() => {
    setPreviewData(generateSampleData());
  }, [generateSampleData]);

  // Handle data source selection
  const handleDataSourceChange = useCallback((dataSourceId: string) => {
    const dataSource = AVAILABLE_DATA_SOURCES.find(ds => ds.id === dataSourceId);
    setSelectedDataSource(dataSource || null);
    setConfig(prev => ({
      ...prev,
      dataSource: dataSourceId,
      metrics: [],
      dimensions: []
    }));
  }, []);

  // Handle chart type change
  const handleChartTypeChange = useCallback((chartType: ChartType) => {
    setConfig(prev => ({
      ...prev,
      type: chartType,
      metrics: [], // Reset metrics when chart type changes
      dimensions: []
    }));
  }, []);

  // Handle metric drop
  const handleMetricDrop = useCallback((item: { field: DataField; type: string }) => {
    if (item.type !== 'metric') {return;}
    
    const chartConfig = CHART_TYPE_CONFIGS[config.type];
    if (config.metrics.length >= chartConfig.maxMetrics) {
      alert(`This chart type supports maximum ${chartConfig.maxMetrics} metrics`);
      return;
    }

    setConfig(prev => ({
      ...prev,
      metrics: [...prev.metrics, item.field.name]
    }));
  }, [config.type, config.metrics.length]);

  // Handle dimension drop
  const handleDimensionDrop = useCallback((item: { field: DataField; type: string }) => {
    if (item.type !== 'dimension') {return;}

    setConfig(prev => ({
      ...prev,
      dimensions: [...prev.dimensions, item.field.name]
    }));
  }, []);

  // Remove metric
  const removeMetric = useCallback((metricName: string) => {
    setConfig(prev => ({
      ...prev,
      metrics: prev.metrics.filter(m => m !== metricName)
    }));
  }, []);

  // Remove dimension
  const removeDimension = useCallback((dimensionName: string) => {
    setConfig(prev => ({
      ...prev,
      dimensions: prev.dimensions.filter(d => d !== dimensionName)
    }));
  }, []);

  // Update chart options
  const updateOptions = useCallback((updates: Partial<ChartOptions>) => {
    setConfig(prev => ({
      ...prev,
      options: {
        ...prev.options,
        ...updates
      }
    }));
  }, []);

  // Add filter
  const addFilter = useCallback(() => {
    const newFilter: ChartFilter = {
      field: selectedDataSource?.fields[0]?.name || '',
      operator: 'equals',
      value: ''
    };

    setConfig(prev => ({
      ...prev,
      filters: [...prev.filters, newFilter]
    }));
  }, [selectedDataSource]);

  // Remove filter
  const removeFilter = useCallback((index: number) => {
    setConfig(prev => ({
      ...prev,
      filters: prev.filters.filter((_, i) => i !== index)
    }));
  }, []);

  // Update filter
  const updateFilter = useCallback((index: number, updates: Partial<ChartFilter>) => {
    setConfig(prev => ({
      ...prev,
      filters: prev.filters.map((filter, i) => 
        i === index ? { ...filter, ...updates } : filter
      )
    }));
  }, []);

  // Save configuration
  const handleSave = useCallback(() => {
    if (!config.title.trim()) {
      alert('Please enter a chart title');
      return;
    }

    if (!selectedDataSource) {
      alert('Please select a data source');
      return;
    }

    if (config.metrics.length === 0) {
      alert('Please add at least one metric');
      return;
    }

    const finalConfig: ChartConfiguration = {
      ...config,
      id: initialConfig?.id || `chart_${Date.now()}`
    };

    onSave(finalConfig);
  }, [config, selectedDataSource, initialConfig, onSave]);

  const availableMetrics = useMemo(() => 
    selectedDataSource?.fields.filter(f => f.type === 'number') || [], 
    [selectedDataSource]
  );

  const availableDimensions = useMemo(() => 
    selectedDataSource?.fields.filter(f => f.type === 'string' || f.type === 'date') || [], 
    [selectedDataSource]
  );

  return (
    <DndProvider backend={HTML5Backend}>
      <div className="flex h-screen bg-gray-100">
        {/* Left Panel - Configuration */}
        <div className="w-1/3 bg-white border-r border-gray-200 overflow-y-auto">
          <div className="p-6">
            <h2 className="text-xl font-bold mb-6">Chart Builder</h2>
            
            {/* Chart Title */}
            <div className="mb-6">
              <label className="block text-sm font-medium mb-2">Chart Title</label>
              <input
                type="text"
                value={config.title}
                onChange={(e) => setConfig(prev => ({ ...prev, title: e.target.value }))}
                className="w-full p-2 border border-gray-300 rounded focus:ring-2 focus:ring-blue-500 focus:outline-none"
                placeholder="Enter chart title..."
              />
            </div>

            {/* Data Source Selection */}
            <div className="mb-6">
              <label className="block text-sm font-medium mb-2">Data Source</label>
              <select
                value={config.dataSource}
                onChange={(e) => handleDataSourceChange(e.target.value)}
                className="w-full p-2 border border-gray-300 rounded focus:ring-2 focus:ring-blue-500 focus:outline-none"
              >
                <option value="">Select a data source...</option>
                {AVAILABLE_DATA_SOURCES.map(ds => (
                  <option key={ds.id} value={ds.id}>{ds.name}</option>
                ))}
              </select>
            </div>

            {/* Chart Type Selection */}
            <div className="mb-6">
              <label className="block text-sm font-medium mb-2">Chart Type</label>
              <div className="grid grid-cols-2 gap-2">
                {Object.entries(CHART_TYPE_CONFIGS).map(([type, typeConfig]) => (
                  <button
                    key={type}
                    onClick={() => handleChartTypeChange(type as ChartType)}
                    className={`p-3 border rounded text-left text-sm ${
                      config.type === type
                        ? 'border-blue-500 bg-blue-50 text-blue-700'
                        : 'border-gray-300 hover:border-gray-400'
                    }`}
                  >
                    <div className="text-lg mb-1">{typeConfig.icon}</div>
                    <div className="font-medium">{typeConfig.name}</div>
                    <div className="text-xs text-gray-500">{typeConfig.description}</div>
                  </button>
                ))}
              </div>
            </div>

            {/* Chart Options */}
            <div className="mb-6">
              <label className="block text-sm font-medium mb-2">Chart Options</label>
              <div className="space-y-2">
                <label className="flex items-center">
                  <input
                    type="checkbox"
                    checked={config.options.showTooltip !== false}
                    onChange={(e) => updateOptions({ showTooltip: e.target.checked })}
                    className="mr-2"
                  />
                  Show Tooltip
                </label>
                <label className="flex items-center">
                  <input
                    type="checkbox"
                    checked={config.options.showLegend !== false}
                    onChange={(e) => updateOptions({ showLegend: e.target.checked })}
                    className="mr-2"
                  />
                  Show Legend
                </label>
                <label className="flex items-center">
                  <input
                    type="checkbox"
                    checked={config.options.showGrid !== false}
                    onChange={(e) => updateOptions({ showGrid: e.target.checked })}
                    className="mr-2"
                  />
                  Show Grid
                </label>
                <label className="flex items-center">
                  <input
                    type="checkbox"
                    checked={config.options.enableAnimation !== false}
                    onChange={(e) => updateOptions({ enableAnimation: e.target.checked })}
                    className="mr-2"
                  />
                  Enable Animation
                </label>
              </div>
            </div>

            {/* Filters */}
            <div className="mb-6">
              <div className="flex items-center justify-between mb-2">
                <label className="block text-sm font-medium">Filters</label>
                <button
                  onClick={addFilter}
                  className="text-sm text-blue-600 hover:text-blue-800"
                  disabled={!selectedDataSource}
                >
                  + Add Filter
                </button>
              </div>
              <div className="space-y-2">
                {config.filters.map((filter, index) => (
                  <div key={`filter-${filter.field}-${index}`} className="flex items-center space-x-2 p-2 bg-gray-50 rounded">
                    <select
                      value={filter.field}
                      onChange={(e) => updateFilter(index, { field: e.target.value })}
                      className="flex-1 p-1 border border-gray-300 rounded text-sm"
                    >
                      {selectedDataSource?.fields.map(field => (
                        <option key={field.name} value={field.name}>
                          {field.label}
                        </option>
                      ))}
                    </select>
                    <select
                      value={filter.operator}
                      onChange={(e) => updateFilter(index, { operator: e.target.value as any })}
                      className="p-1 border border-gray-300 rounded text-sm"
                    >
                      <option value="equals">Equals</option>
                      <option value="contains">Contains</option>
                      <option value="greater_than">Greater Than</option>
                      <option value="less_than">Less Than</option>
                      <option value="between">Between</option>
                    </select>
                    <input
                      type="text"
                      value={filter.value}
                      onChange={(e) => updateFilter(index, { value: e.target.value })}
                      className="flex-1 p-1 border border-gray-300 rounded text-sm"
                      placeholder="Value..."
                    />
                    <button
                      onClick={() => removeFilter(index)}
                      className="text-red-600 hover:text-red-800 text-sm"
                    >
                      ×
                    </button>
                  </div>
                ))}
              </div>
            </div>

            {/* Action Buttons */}
            <div className="flex space-x-2">
              <button
                onClick={handleSave}
                className="flex-1 bg-blue-600 text-white py-2 px-4 rounded hover:bg-blue-700 focus:ring-2 focus:ring-blue-500 focus:outline-none"
              >
                Save Chart
              </button>
              <button
                onClick={onCancel}
                className="flex-1 bg-gray-600 text-white py-2 px-4 rounded hover:bg-gray-700 focus:ring-2 focus:ring-gray-500 focus:outline-none"
              >
                Cancel
              </button>
            </div>
          </div>
        </div>

        {/* Middle Panel - Field Selection */}
        <div className="w-1/3 bg-white border-r border-gray-200 overflow-y-auto">
          <div className="p-6">
            <h3 className="text-lg font-semibold mb-4">Available Fields</h3>
            
            {selectedDataSource ? (
              <>
                {/* Metrics */}
                <div className="mb-6">
                  <h4 className="text-sm font-medium mb-2 text-blue-600">📊 Metrics (Numbers)</h4>
                  <div className="space-y-2">
                    {availableMetrics.map(field => (
                      <DraggableField key={field.name} field={field} type="metric" />
                    ))}
                  </div>
                </div>

                {/* Dimensions */}
                <div className="mb-6">
                  <h4 className="text-sm font-medium mb-2 text-green-600">🏷️ Dimensions (Categories)</h4>
                  <div className="space-y-2">
                    {availableDimensions.map(field => (
                      <DraggableField key={field.name} field={field} type="dimension" />
                    ))}
                  </div>
                </div>
              </>
            ) : (
              <div className="text-gray-500 text-center py-8">
                Select a data source to see available fields
              </div>
            )}

            {/* Selected Fields */}
            <div className="mt-8">
              <h4 className="text-sm font-medium mb-2">Selected Fields</h4>
              
              {/* Selected Metrics */}
              <div className="mb-4">
                <h5 className="text-xs font-medium text-blue-600 mb-2">Metrics</h5>
                <DropZone
                  acceptedType={DND_TYPES.METRIC}
                  onDrop={handleMetricDrop}
                  className="min-h-[60px] border-2 border-gray-200 rounded p-2"
                  placeholder="Drag metrics here..."
                >
                  {config.metrics.map(metric => (
                    <div key={metric} className="flex items-center justify-between p-2 bg-blue-50 border border-blue-200 rounded mb-2">
                      <span className="text-sm">{availableMetrics.find(f => f.name === metric)?.label || metric}</span>
                      <button
                        onClick={() => removeMetric(metric)}
                        className="text-red-600 hover:text-red-800 text-sm"
                      >
                        ×
                      </button>
                    </div>
                  ))}
                </DropZone>
              </div>

              {/* Selected Dimensions */}
              <div>
                <h5 className="text-xs font-medium text-green-600 mb-2">Dimensions</h5>
                <DropZone
                  acceptedType={DND_TYPES.DIMENSION}
                  onDrop={handleDimensionDrop}
                  className="min-h-[60px] border-2 border-gray-200 rounded p-2"
                  placeholder="Drag dimensions here..."
                >
                  {config.dimensions.map(dimension => (
                    <div key={dimension} className="flex items-center justify-between p-2 bg-green-50 border border-green-200 rounded mb-2">
                      <span className="text-sm">{availableDimensions.find(f => f.name === dimension)?.label || dimension}</span>
                      <button
                        onClick={() => removeDimension(dimension)}
                        className="text-red-600 hover:text-red-800 text-sm"
                      >
                        ×
                      </button>
                    </div>
                  ))}
                </DropZone>
              </div>
            </div>
          </div>
        </div>

        {/* Right Panel - Preview */}
        <div className="w-1/3 bg-gray-50 overflow-y-auto">
          <div className="p-6">
            <h3 className="text-lg font-semibold mb-4">Preview</h3>
            <div className="bg-white p-4 rounded-lg shadow">
              <h4 className="text-md font-medium mb-4">{config.title}</h4>
              <ChartPreview config={config} sampleData={previewData} />
            </div>
            
            {/* Configuration Summary */}
            <div className="mt-6 bg-white p-4 rounded-lg shadow">
              <h4 className="text-md font-medium mb-2">Configuration Summary</h4>
              <div className="text-sm space-y-1">
                <div><strong>Type:</strong> {CHART_TYPE_CONFIGS[config.type]?.name}</div>
                <div><strong>Data Source:</strong> {selectedDataSource?.name || 'None'}</div>
                <div><strong>Metrics:</strong> {config.metrics.length} selected</div>
                <div><strong>Dimensions:</strong> {config.dimensions.length} selected</div>
                <div><strong>Filters:</strong> {config.filters.length} applied</div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </DndProvider>
  );
});

DraggableField.displayName = 'DraggableField';
DropZone.displayName = 'DropZone';
ChartPreview.displayName = 'ChartPreview';
CustomChartBuilder.displayName = 'CustomChartBuilder';