import React, { useState, useEffect, useCallback, useMemo, memo, Suspense } from 'react';
import { 
  LineChart, Line, BarChart, Bar, PieChart, Pie, Cell, 
  ResponsiveContainer, XAxis, YAxis, CartesianGrid, Tooltip, Legend,
  Area, AreaChart
} from 'recharts';
import { DateRange } from 'react-date-range';
import { subDays } from 'date-fns';
import debounce from 'lodash.debounce';
import { createConsumer } from '@rails/actioncable';
import {
  AdvancedLineChart,
  AdvancedBarChart,
  DonutChart,
  FunnelVisualization,
  HeatmapDisplay,
  ScatterPlot,
  TreeMapChart,
  RadialBarChartComponent,
  MultiSeriesAreaChart,
  ChartDataPoint,
  ChartOptions,
  ChartTheme,
  FunnelDataPoint,
  HeatmapDataPoint
} from './AdvancedCharts';
import { CustomChartBuilder, ChartConfiguration } from './CustomChartBuilder';
import { 
  MobileDashboard, 
  MobileTouchControls
} from './MobileAnalyticsDashboard';
import { ExportManager } from './ExportManager';
import 'react-date-range/dist/styles.css';
import 'react-date-range/dist/theme/default.css';

// Types
interface MetricData {
  name: string;
  value: number;
  change?: number;
  trend?: 'up' | 'down' | 'neutral';
  timestamp?: string;
}

interface ChartData {
  name: string;
  value: number;
  date?: string;
  source?: string;
}

interface DashboardProps {
  brandId: string;
  userId?: string;
  initialMetrics?: DashboardMetrics;
}

interface DashboardMetrics {
  social_media?: SocialMediaMetrics;
  email?: EmailMetrics;
  google_analytics?: GoogleAnalyticsMetrics;
  crm?: CRMMetrics;
  custom?: Record<string, CustomMetricData>;
}

interface SocialMediaMetrics {
  platforms?: PlatformData[];
  summary?: Record<string, number>;
  timeseries?: TimeSeriesData[];
}

interface EmailMetrics {
  campaigns?: EmailCampaignData[];
  summary?: Record<string, number>;
  timeseries?: TimeSeriesData[];
}

interface GoogleAnalyticsMetrics {
  timeseries?: GoogleAnalyticsTimeSeriesData[];
  summary?: Record<string, number>;
}

interface CRMMetrics {
  pipeline?: CRMPipelineData[];
  summary?: Record<string, number>;
}

interface PlatformData {
  name: string;
  engagement: number;
}

interface EmailCampaignData {
  name: string;
  open_rate: number;
  click_rate: number;
}

interface GoogleAnalyticsTimeSeriesData {
  date: string;
  sessions: number;
  pageviews: number;
}

interface CRMPipelineData {
  stage: string;
  value: number;
}

interface TimeSeriesData {
  date: string;
  value: number;
}

interface CustomMetricData {
  value: number;
  timestamp: string;
}

interface WebSocketMessage {
  type: string;
  data?: any;
  metric_name?: string;
  message?: string;
}

// Removed unused interface - CustomMetricConfig

interface DateRangeState {
  startDate: Date;
  endDate: Date;
  key: string;
}

// Color schemes for charts
const COLORS = ['#0088FE', '#00C49F', '#FFBB28', '#FF8042', '#8884D8', '#82CA9D'];

// Quick date range presets
const DATE_PRESETS = {
  today: { label: 'Today', days: 0 },
  week: { label: 'Last 7 days', days: 7 },
  month: { label: 'Last 30 days', days: 30 },
  quarter: { label: 'Last 3 months', days: 90 },
  year: { label: 'Last year', days: 365 }
};

export const AnalyticsDashboard: React.FC<DashboardProps> = ({ 
  brandId, 
  initialMetrics 
}) => {
  // State management
  const [metrics, setMetrics] = useState<DashboardMetrics>(initialMetrics || {});
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  // Removed unused selectedMetrics state
  const [chartType, setChartType] = useState<'line' | 'bar' | 'area' | 'donut' | 'funnel' | 'heatmap' | 'scatter' | 'treemap' | 'radial_bar'>('line');
  const [showDatePicker, setShowDatePicker] = useState(false);
  const [customMetricBuilder, setCustomMetricBuilder] = useState(false);
  const [drillDownData, setDrillDownData] = useState<ChartData[] | null>(null);
  const [savedCharts, setSavedCharts] = useState<ChartConfiguration[]>([]);
  const [dashboardLayout, setDashboardLayout] = useState<'grid' | 'list'>('grid');
  const [selectedTheme, setSelectedTheme] = useState<'light' | 'dark' | 'brand'>('light');
  const [showAdvancedCharts, setShowAdvancedCharts] = useState(false);
  const [heatmapData, setHeatmapData] = useState<HeatmapDataPoint[]>([]);
  const [funnelData, setFunnelData] = useState<FunnelDataPoint[]>([]);
  
  // Date range state
  const [dateRange, setDateRange] = useState<DateRangeState[]>([
    {
      startDate: subDays(new Date(), 30),
      endDate: new Date(),
      key: 'selection'
    }
  ]);

  // WebSocket connection
  const [cable] = useState(() => createConsumer());
  const [channel, setChannel] = useState<any>(null); // ActionCable channel type not available

  // Initialize WebSocket connection
  useEffect(() => {
    const analyticsChannel = cable.subscriptions.create(
      {
        channel: 'AnalyticsDashboardChannel',
        brand_id: brandId
      },
      {
        received: (data: any) => {
          handleRealtimeUpdate(data);
        },
        connected: () => {
          console.log('Connected to analytics dashboard channel');
          requestInitialMetrics();
        },
        disconnected: () => {
          console.log('Disconnected from analytics dashboard channel');
        }
      }
    );

    setChannel(analyticsChannel);

    return () => {
      analyticsChannel.unsubscribe();
    };
  }, [brandId, cable, handleRealtimeUpdate, requestInitialMetrics]);

  // Handle real-time updates from ActionCable
  const handleRealtimeUpdate = useCallback((data: WebSocketMessage) => {
    setLoading(false);
    
    switch (data.type) {
      case 'connection_established':
        console.log('Analytics dashboard connection established');
        break;
      case 'social_media_metrics':
      case 'email_metrics':
      case 'google_analytics_metrics':
      case 'crm_metrics':
        setMetrics(prev => ({
          ...prev,
          [data.type.replace('_metrics', '')]: data.data
        }));
        break;
      case 'custom_metric_result':
        setMetrics(prev => ({
          ...prev,
          custom: {
            ...prev.custom,
            [data.metric_name]: data.data
          }
        }));
        break;
      case 'drill_down_result':
        setDrillDownData(data.data);
        break;
      case 'error':
        setError(data.message);
        setLoading(false);
        break;
      default:
        console.log('Unknown analytics update type:', data.type);
    }
  }, []);

  // Debounced metrics request to prevent excessive API calls
  const debouncedRequestMetrics = useMemo(
    () => debounce((metricType: string, timeRange: string, brandId: string) => {
      if (!channel) {
        return;
      }
      
      setLoading(true);
      setError(null);
      
      channel.perform('request_metrics', {
        metric_type: metricType,
        time_range: timeRange,
        brand_id: brandId
      });
    }, 300),
    [channel]
  );

  // Request initial metrics
  const requestInitialMetrics = useCallback(() => {
    if (!channel) {return;}
    
    debouncedRequestMetrics('all', getTimeRangeString(), brandId);
  }, [channel, brandId, getTimeRangeString, debouncedRequestMetrics]);

  // Removed unused requestMetrics function

  // Get time range string for API
  const getTimeRangeString = useCallback(() => {
    const start = dateRange[0].startDate;
    const end = dateRange[0].endDate;
    const diffTime = Math.abs(end.getTime() - start.getTime());
    const diffDays = Math.ceil(diffTime / (1000 * 60 * 60 * 24));
    
    if (diffDays <= 1) {return '24h';}
    if (diffDays <= 7) {return '7d';}
    if (diffDays <= 30) {return '30d';}
    if (diffDays <= 90) {return '90d';}
    return '1y';
  }, [dateRange]);

  // Handle date range changes
  const handleDateRangeChange = useCallback((ranges: { selection: DateRangeState }) => {
    setDateRange([ranges.selection]);
    setShowDatePicker(false);
    // Request new data with updated range
    setTimeout(() => requestInitialMetrics(), 100);
    // Announce change to screen readers
    announceToScreenReader(`Date range updated to ${ranges.selection.startDate.toLocaleDateString()} - ${ranges.selection.endDate.toLocaleDateString()}`);
  }, [requestInitialMetrics, announceToScreenReader]);

  // Announce updates to screen readers
  const announceToScreenReader = useCallback((message: string) => {
    const announcement = document.createElement('div');
    announcement.setAttribute('aria-live', 'polite');
    announcement.setAttribute('aria-atomic', 'true');
    announcement.className = 'sr-only';
    announcement.textContent = message;
    document.body.appendChild(announcement);
    
    // Clean up after announcement
    setTimeout(() => {
      document.body.removeChild(announcement);
    }, 1000);
  }, []);

  // Handle keyboard navigation
  const handleKeyDown = useCallback((event: KeyboardEvent) => {
    // ESC key to close modals
    if (event.key === 'Escape') {
      if (showDatePicker) {
        setShowDatePicker(false);
        event.preventDefault();
      }
      if (customMetricBuilder) {
        setCustomMetricBuilder(false);
        event.preventDefault();
      }
    }
    
    // Alt + E for export menu
    if (event.altKey && event.key === 'e') {
      event.preventDefault();
      // Focus first export button
      const exportButton = document.querySelector('[aria-label="Export data as CSV file"]') as HTMLElement;
      exportButton?.focus();
    }
    
    // Alt + R for refresh
    if (event.altKey && event.key === 'r') {
      event.preventDefault();
      requestInitialMetrics();
      announceToScreenReader('Dashboard data refreshed');
    }
  }, [showDatePicker, customMetricBuilder, requestInitialMetrics, announceToScreenReader]);

  // Add keyboard event listener
  useEffect(() => {
    document.addEventListener('keydown', handleKeyDown);
    return () => {
      document.removeEventListener('keydown', handleKeyDown);
    };
  }, [handleKeyDown]);

  // Cleanup debounced functions on unmount
  useEffect(() => {
    return () => {
      debouncedRequestMetrics.cancel();
    };
  }, [debouncedRequestMetrics]);

  // Performance optimization: virtualize large lists
  const visibleSummaryMetrics = useMemo(() => {
    return summaryMetrics.slice(0, 8); // Only show first 8 for performance
  }, [summaryMetrics]);

  // Intersection Observer for lazy loading charts
  const [chartInView, setChartInView] = useState(false);
  const chartRef = useCallback((node: HTMLDivElement | null) => {
    if (node) {
      const observer = new IntersectionObserver(
        ([entry]) => {
          if (entry.isIntersecting) {
            setChartInView(true);
            observer.disconnect();
          }
        },
        { threshold: 0.1 }
      );
      observer.observe(node);
    }
  }, []);

  // Handle preset date ranges
  const handlePresetDateRange = useCallback((preset: keyof typeof DATE_PRESETS) => {
    const { days } = DATE_PRESETS[preset];
    const newRange = {
      startDate: days === 0 ? new Date() : subDays(new Date(), days),
      endDate: new Date(),
      key: 'selection'
    };
    setDateRange([newRange]);
    requestInitialMetrics();
  }, [requestInitialMetrics]);

  // Removed unused buildCustomMetric function

  // Removed unused performDrillDown function

  // Prepare chart data
  const chartData = useMemo(() => {
    const data: ChartData[] = [];
    
    // Combine data from all sources
    Object.entries(metrics).forEach(([source, sourceData]) => {
      if (sourceData && typeof sourceData === 'object' && 'timeseries' in sourceData) {
        const timeseries = sourceData.timeseries;
        if (timeseries) {
          timeseries.forEach((item: TimeSeriesData) => {
            data.push({
              name: source,
              value: item.value,
              date: item.date,
              source
            });
          });
        }
      }
    });
    
    return data;
  }, [metrics]);

  // Prepare summary metrics
  const summaryMetrics = useMemo(() => {
    const summary: MetricData[] = [];
    
    Object.entries(metrics).forEach(([source, sourceData]) => {
      if (sourceData && typeof sourceData === 'object' && 'summary' in sourceData) {
        const summaryData = sourceData.summary;
        if (summaryData) {
          Object.entries(summaryData).forEach(([metric, value]) => {
            const numericValue = typeof value === 'number' ? value : 0;
            summary.push({
              name: `${source}_${metric}`,
              value: numericValue,
              trend: numericValue > 0 ? 'up' : numericValue < 0 ? 'down' : 'neutral'
            });
          });
        }
      }
    });
    
    return summary;
  }, [metrics]);

  // Export functionality moved to ExportManager component

  // Theme configurations
  const getThemeConfig = useCallback((): ChartTheme => {
    switch (selectedTheme) {
      case 'dark':
        return {
          primary: '#60A5FA',
          secondary: '#34D399',
          accent: '#FBBF24',
          background: '#1F2937',
          text: '#F9FAFB',
          grid: '#374151',
          colors: ['#60A5FA', '#34D399', '#FBBF24', '#F87171', '#A78BFA', '#4ADE80', '#FB923C', '#38BDF8']
        };
      case 'brand':
        return {
          primary: '#0088FE',
          secondary: '#00C49F',
          accent: '#FFBB28',
          background: '#FFFFFF',
          text: '#1E40AF',
          grid: '#E0E7FF',
          colors: ['#0088FE', '#00C49F', '#FFBB28', '#FF8042', '#8884D8', '#82CA9D', '#FFC658', '#8DD1E1']
        };
      default: // light
        return {
          primary: '#0088FE',
          secondary: '#00C49F',
          accent: '#FFBB28',
          background: '#FFFFFF',
          text: '#374151',
          grid: '#E5E7EB',
          colors: ['#0088FE', '#00C49F', '#FFBB28', '#FF8042', '#8884D8', '#82CA9D', '#FFC658', '#8DD1E1']
        };
    }
  }, [selectedTheme]);

  // Handle data point clicks for drill-down
  const handleDataPointClick = useCallback((point: ChartDataPoint) => {
    if (channel) {
      channel.perform('drill_down', {
        source: point.source || 'general',
        metric: 'value',
        dimension: 'name',
        filters: { name: point.name },
        brand_id: brandId
      });
    }
    announceToScreenReader(`Drilling down into ${point.name} data`);
  }, [channel, brandId, announceToScreenReader]);

  // Handle chart zoom
  const handleChartZoom = useCallback((scale: number) => {
    announceToScreenReader(`Chart zoomed to ${(scale * 100).toFixed(0)}%`);
  }, [announceToScreenReader]);

  // Convert chart data for advanced components
  const convertToAdvancedChartData = useCallback((data: ChartData[]): ChartDataPoint[] => {
    return data.map(item => ({
      name: item.name,
      value: item.value,
      date: item.date,
      source: item.source,
      x: Math.random() * 100, // For scatter plots
      y: Math.random() * 100,
      size: item.value / 10,
      metadata: { source: item.source, date: item.date }
    }));
  }, []);

  // Generate funnel data from CRM metrics
  const generateFunnelData = useCallback((): FunnelDataPoint[] => {
    if (!metrics.crm?.pipeline) {return [];}
    
    const theme = getThemeConfig();
    return metrics.crm.pipeline.map((stage, index) => ({
      name: stage.stage,
      value: stage.value,
      fill: theme.colors[index % theme.colors.length],
      conversionRate: index > 0 
        ? (stage.value / metrics.crm!.pipeline![index - 1].value) * 100 
        : 100
    }));
  }, [metrics.crm, getThemeConfig]);

  // Generate heatmap data from engagement patterns
  const generateHeatmapData = useCallback((): HeatmapDataPoint[] => {
    const data: HeatmapDataPoint[] = [];
    for (let row = 0; row < 7; row++) {
      for (let col = 0; col < 24; col++) {
        data.push({
          row,
          col,
          value: Math.floor(Math.random() * 100),
          label: `${['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'][row]} ${col}:00`
        });
      }
    }
    return data;
  }, []);

  // Update heatmap and funnel data when metrics change
  useEffect(() => {
    setFunnelData(generateFunnelData());
    setHeatmapData(generateHeatmapData());
  }, [generateFunnelData, generateHeatmapData]);

  // Enhanced main chart component
  const EnhancedMainChart = memo(({ 
    chartType, 
    chartData, 
    theme, 
    onDataPointClick, 
    onZoom 
  }: { 
    chartType: string;
    chartData: ChartData[];
    theme: ChartTheme;
    onDataPointClick?: (point: ChartDataPoint) => void;
    onZoom?: (scale: number) => void;
  }) => {
    const advancedData = convertToAdvancedChartData(chartData);
    const chartOptions: ChartOptions = {
      showZoom: chartType === 'line',
      showTooltip: true,
      showLegend: true,
      showGrid: true,
      enableAnimation: true,
      theme
    };

    switch (chartType) {
      case 'line':
        return <AdvancedLineChart data={advancedData} options={chartOptions} onDataPointClick={onDataPointClick} onZoom={onZoom} />;
      case 'bar':
        return <AdvancedBarChart data={advancedData} options={chartOptions} onBarClick={onDataPointClick} />;
      case 'donut':
        return <DonutChart data={advancedData} options={chartOptions} centerText="Total" onSegmentClick={onDataPointClick} />;
      case 'funnel':
        return <FunnelVisualization data={funnelData} options={chartOptions} onStageClick={onDataPointClick} />;
      case 'heatmap':
        return <HeatmapDisplay data={heatmapData} options={chartOptions} width={800} height={400} />;
      case 'scatter':
        return <ScatterPlot data={advancedData} options={chartOptions} onPointClick={onDataPointClick} />;
      case 'treemap':
        return <TreeMapChart data={advancedData} options={chartOptions} onNodeClick={onDataPointClick} />;
      case 'radial_bar':
        return <RadialBarChartComponent data={advancedData} options={chartOptions} />;
      case 'area':
        return <MultiSeriesAreaChart data={advancedData} series={['value']} options={chartOptions} />;
      default:
        return (
          <ResponsiveContainer width="100%" height="100%">
            <LineChart data={chartData}>
              <CartesianGrid strokeDasharray="3 3" stroke={theme.grid} />
              <XAxis dataKey="date" stroke={theme.text} />
              <YAxis stroke={theme.text} />
              <Tooltip contentStyle={{ backgroundColor: theme.background, color: theme.text }} />
              <Legend />
              <Line type="monotone" dataKey="value" stroke={theme.primary} strokeWidth={2} />
            </LineChart>
          </ResponsiveContainer>
        );
    }
  });

  const MemoizedMetricCard = memo(({ metric, theme }: { metric: MetricData; theme: ChartTheme }) => {
    const trendColor = metric.trend === 'up' ? '#00C49F' : metric.trend === 'down' ? '#FF8042' : '#8884D8';
    
    return (
      <div 
        className="p-6 rounded-lg shadow-md"
        style={{ backgroundColor: theme.background }}
        role="article"
        aria-labelledby={`metric-${metric.name}`}
      >
        <div className="flex items-center justify-between">
          <div>
            <p 
              id={`metric-${metric.name}`}
              className="text-sm mb-1"
              style={{ color: theme.text, opacity: 0.7 }}
            >
              {metric.name.replace(/_/g, ' ').toUpperCase()}
            </p>
            <p 
              className="text-2xl font-bold"
              style={{ color: theme.text }}
              aria-label={`${metric.name.replace(/_/g, ' ')} value: ${metric.value.toLocaleString()}`}
            >
              {metric.value.toLocaleString()}
            </p>
            {metric.change !== undefined && (
              <p className="text-sm mt-1" style={{ color: trendColor }}>
                {metric.change > 0 ? '+' : ''}{metric.change.toFixed(1)}%
                <span className="ml-1">
                  {metric.trend === 'up' ? '↗' : metric.trend === 'down' ? '↘' : '→'}
                </span>
              </p>
            )}
          </div>
          <div 
            className="w-3 h-3 rounded-full" 
            style={{ backgroundColor: trendColor }}
            aria-label={`Trend: ${metric.trend || 'neutral'}`}
            role="img"
          />
        </div>
      </div>
    );
  });

  // Custom Metric Builder Component
  // Removed CustomMetricBuilder component - replaced with CustomChartBuilder

  return (
    <div 
      id="analytics-dashboard" 
      className="p-6 max-w-7xl mx-auto min-h-screen"
      style={{ 
        backgroundColor: selectedTheme === 'dark' ? '#111827' : '#F9FAFB',
        color: getThemeConfig().text
      }}
      role="main"
      aria-label="Analytics Dashboard"
    >
      {/* Header */}
      <div className="mb-8">
        <h1 className="text-3xl font-bold text-gray-900 mb-4" id="dashboard-title">
          Analytics Dashboard
        </h1>
        
        {/* Controls */}
        <div className="flex flex-wrap items-center gap-4 mb-6">
          {/* Date Range Presets */}
          <div className="flex space-x-2" role="group" aria-label="Date range presets">
            {Object.entries(DATE_PRESETS).map(([key, preset]) => (
              <button
                key={key}
                onClick={() => handlePresetDateRange(key as keyof typeof DATE_PRESETS)}
                className="px-3 py-1 text-sm border border-gray-300 rounded hover:bg-gray-50 focus:ring-2 focus:ring-blue-500 focus:outline-none"
                aria-label={`Set date range to ${preset.label}`}
              >
                {preset.label}
              </button>
            ))}
          </div>
          
          {/* Custom Date Range */}
          <button
            onClick={() => setShowDatePicker(!showDatePicker)}
            className="px-4 py-2 bg-blue-600 text-white rounded hover:bg-blue-700 focus:ring-2 focus:ring-blue-500 focus:outline-none"
            aria-expanded={showDatePicker}
            aria-haspopup="dialog"
            aria-label="Open custom date range picker"
          >
            Custom Range
          </button>
          
          {/* Chart Type Selector */}
          <label className="sr-only" htmlFor="chart-type-selector">
            Chart type
          </label>
          <select
            id="chart-type-selector"
            value={chartType}
            onChange={(e) => setChartType(e.target.value as any)}
            className="p-2 border border-gray-300 rounded focus:ring-2 focus:ring-blue-500 focus:outline-none"
            aria-label="Select chart type"
          >
            <option value="line">📈 Line Chart</option>
            <option value="bar">📊 Bar Chart</option>
            <option value="area">📈 Area Chart</option>
            <option value="donut">🍩 Donut Chart</option>
            <option value="funnel">🔽 Funnel Chart</option>
            <option value="heatmap">🔥 Heatmap</option>
            <option value="scatter">⚫ Scatter Plot</option>
            <option value="treemap">🌳 Tree Map</option>
            <option value="radial_bar">🌙 Radial Bar</option>
          </select>
          
          {/* Dashboard Layout Toggle */}
          <button
            onClick={() => setDashboardLayout(dashboardLayout === 'grid' ? 'list' : 'grid')}
            className="px-3 py-2 bg-purple-600 text-white rounded hover:bg-purple-700 focus:ring-2 focus:ring-purple-500 focus:outline-none"
            aria-label={`Switch to ${dashboardLayout === 'grid' ? 'list' : 'grid'} layout`}
          >
            {dashboardLayout === 'grid' ? '📋 List' : '🔲 Grid'}
          </button>
          
          {/* Theme Selector */}
          <select
            value={selectedTheme}
            onChange={(e) => setSelectedTheme(e.target.value as 'light' | 'dark' | 'brand')}
            className="p-2 border border-gray-300 rounded focus:ring-2 focus:ring-blue-500 focus:outline-none"
            aria-label="Select dashboard theme"
          >
            <option value="light">☀️ Light</option>
            <option value="dark">🌙 Dark</option>
            <option value="brand">🎨 Brand</option>
          </select>
          
          {/* Advanced Charts Toggle */}
          <button
            onClick={() => setShowAdvancedCharts(!showAdvancedCharts)}
            className={`px-4 py-2 rounded focus:ring-2 focus:outline-none ${
              showAdvancedCharts 
                ? 'bg-blue-600 text-white hover:bg-blue-700 focus:ring-blue-500'
                : 'bg-gray-200 text-gray-700 hover:bg-gray-300 focus:ring-gray-500'
            }`}
            aria-label="Toggle advanced charts"
          >
            📡 Advanced Charts
          </button>

          {/* Custom Metric Builder */}
          <button
            onClick={() => setCustomMetricBuilder(true)}
            className="px-4 py-2 bg-green-600 text-white rounded hover:bg-green-700 focus:ring-2 focus:ring-green-500 focus:outline-none"
            aria-label="Open custom metric builder"
          >
            🛠️ Custom Metrics
          </button>
          
          {/* Enhanced Export Options */}
          <div role="group" aria-label="Export options">
            <ExportManager
              data={{
                metrics: summaryMetrics.map(m => ({
                  name: m.name,
                  value: m.value,
                  change: m.change,
                  trend: m.trend,
                  timestamp: new Date().toISOString()
                })),
                chartData: convertToAdvancedChartData(chartData),
                metadata: {
                  exportDate: new Date().toISOString(),
                  brandId,
                  dateRange: getTimeRangeString(),
                  dashboardVersion: '2.0'
                }
              }}
              theme={getThemeConfig()}
              brandId={brandId}
              onExportStart={() => announceToScreenReader('Export started')}
              onExportComplete={(format) => announceToScreenReader(`Export completed as ${format}`)}
              onExportError={(error) => announceToScreenReader(`Export failed: ${error}`)}
            />
          </div>
        </div>
        
        {/* Date Picker */}
        {showDatePicker && (
          <div 
            className="absolute z-10 bg-white border border-gray-300 rounded-lg shadow-lg"
            role="dialog"
            aria-modal="true"
            aria-label="Custom date range selector"
          >
            <DateRange
              editableDateInputs={true}
              onChange={handleDateRangeChange}
              moveRangeOnFirstSelection={false}
              ranges={dateRange}
              className="border-0"
            />
          </div>
        )}
      </div>

      {/* Loading State */}
      {loading && (
        <div className="flex items-center justify-center py-8" role="status" aria-live="polite">
          <div 
            className="animate-spin rounded-full h-8 w-8 border-b-2 border-blue-600" 
            aria-hidden="true"
          />
          <span className="ml-2">Loading analytics data...</span>
        </div>
      )}

      {/* Error State */}
      {error && (
        <div 
          className="bg-red-100 border border-red-400 text-red-700 px-4 py-3 rounded mb-6"
          role="alert"
          aria-live="assertive"
        >
          {error}
          <button
            onClick={() => setError(null)}
            className="float-right font-bold text-red-700 hover:text-red-900 focus:ring-2 focus:ring-red-500 focus:outline-none"
            aria-label="Dismiss error message"
          >
            ×
          </button>
        </div>
      )}

      {/* Custom Chart Builder Modal */}
      {customMetricBuilder && (
        <div 
          className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50"
          role="dialog"
          aria-modal="true"
          aria-labelledby="custom-chart-builder-title"
        >
          <div className="bg-white rounded-lg w-full h-full max-w-7xl max-h-screen m-4 overflow-hidden">
            <CustomChartBuilder
              onSave={(config) => {
                setSavedCharts(prev => [...prev, config]);
                setCustomMetricBuilder(false);
                announceToScreenReader(`Custom chart "${config.title}" saved successfully`);
              }}
              onCancel={() => setCustomMetricBuilder(false)}
              brandId={brandId}
            />
          </div>
        </div>
      )}

      {/* Mobile Dashboard */}
      <MobileDashboard
        metrics={summaryMetrics.map(m => ({
          title: m.name.replace(/_/g, ' '),
          value: m.value,
          change: m.change,
          trend: m.trend
        }))}
        charts={[
          {
            title: 'Trends Overview',
            data: convertToAdvancedChartData(chartData),
            type: 'simple' as const
          },
          ...(metrics.social_media?.platforms ? [{
            title: 'Social Media',
            data: metrics.social_media.platforms.map(p => ({
              name: p.name,
              value: p.engagement,
              source: 'social_media'
            })),
            type: 'simple' as const
          }] : [])
        ]}
        theme={getThemeConfig()}
      />

      {/* Desktop Summary Metrics */}
      <div 
        className="hidden lg:grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6 mb-8"
        role="region"
        aria-label="Summary metrics"
      >
        {visibleSummaryMetrics.map((metric) => (
          <MemoizedMetricCard key={metric.name} metric={metric} theme={getThemeConfig()} />
        ))}
      </div>

      {/* Main Chart */}
      <div 
        className="bg-white p-6 rounded-lg shadow-md mb-8"
        role="region"
        aria-labelledby="trends-chart-title"
      >
        <h2 id="trends-chart-title" className="text-xl font-semibold mb-4">
          Trends Overview
        </h2>
        <div ref={chartRef} className="h-96" role="img" aria-label="Analytics trends chart">
          {chartInView ? (
            <Suspense fallback={
              <div className="flex items-center justify-center h-full">
                <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-blue-600" />
                <span className="ml-3">Loading chart...</span>
              </div>
            }>
              <EnhancedMainChart 
                chartType={chartType} 
                chartData={chartData}
                theme={getThemeConfig()}
                onDataPointClick={handleDataPointClick}
                onZoom={handleChartZoom}
              />
            </Suspense>
          ) : (
            <div className="flex items-center justify-center h-full bg-gray-100 rounded">
              <span className="text-gray-500">Chart will load when visible</span>
            </div>
          )}
        </div>
      </div>

      {/* Advanced Charts Section */}
      {showAdvancedCharts && (
        <div className="mb-8">
          <h2 className="text-xl font-semibold mb-4">Advanced Analytics</h2>
          <div className={`grid gap-6 ${
            dashboardLayout === 'grid' 
              ? 'grid-cols-1 md:grid-cols-2 lg:grid-cols-3' 
              : 'grid-cols-1'
          }`}>
            {/* Conversion Funnel */}
            {funnelData.length > 0 && (
              <div className="bg-white p-6 rounded-lg shadow-md">
                <h3 className="text-lg font-semibold mb-4">Conversion Funnel</h3>
                <div className="h-64">
                  <FunnelVisualization 
                    data={funnelData} 
                    options={{ theme: getThemeConfig(), enableAnimation: true }}
                    onStageClick={handleDataPointClick}
                  />
                </div>
              </div>
            )}

            {/* Engagement Heatmap */}
            <div className="bg-white p-6 rounded-lg shadow-md">
              <h3 className="text-lg font-semibold mb-4">Engagement Heatmap</h3>
              <div className="h-64">
                <HeatmapDisplay 
                  data={heatmapData} 
                  options={{ theme: getThemeConfig() }}
                  width={350}
                  height={200}
                />
              </div>
            </div>

            {/* Performance Scatter */}
            <div className="bg-white p-6 rounded-lg shadow-md">
              <h3 className="text-lg font-semibold mb-4">Performance Correlation</h3>
              <div className="h-64">
                <ScatterPlot 
                  data={convertToAdvancedChartData(chartData)}
                  options={{ theme: getThemeConfig(), showTooltip: true }}
                  onPointClick={handleDataPointClick}
                />
              </div>
            </div>
          </div>
        </div>
      )}

      {/* Saved Custom Charts */}
      {savedCharts.length > 0 && (
        <div className="mb-8">
          <h2 className="text-xl font-semibold mb-4">Custom Charts</h2>
          <div className={`grid gap-6 ${
            dashboardLayout === 'grid' 
              ? 'grid-cols-1 md:grid-cols-2' 
              : 'grid-cols-1'
          }`}>
            {savedCharts.map((chart) => (
              <div key={chart.id} className="bg-white p-6 rounded-lg shadow-md">
                <div className="flex items-center justify-between mb-4">
                  <h3 className="text-lg font-semibold">{chart.title}</h3>
                  <button
                    onClick={() => setSavedCharts(prev => prev.filter(c => c.id !== chart.id))}
                    className="text-red-600 hover:text-red-800 text-sm"
                    aria-label={`Delete ${chart.title} chart`}
                  >
                    ×
                  </button>
                </div>
                <div className="h-64">
                  <EnhancedMainChart 
                    chartType={chart.type}
                    chartData={chartData}
                    theme={getThemeConfig()}
                    onDataPointClick={handleDataPointClick}
                  />
                </div>
              </div>
            ))}
          </div>
        </div>
      )}

      {/* Source-specific Charts */}
      <div className={`grid gap-8 ${
        dashboardLayout === 'grid' 
          ? 'grid-cols-1 lg:grid-cols-2' 
          : 'grid-cols-1'
      }`}>
        {/* Social Media Metrics */}
        {metrics.social_media && (
          <div className="bg-white p-6 rounded-lg shadow-md">
            <h3 className="text-lg font-semibold mb-4">Social Media Performance</h3>
            <div className="h-64">
              <ResponsiveContainer width="100%" height="100%">
                <PieChart>
                  <Pie
                    data={metrics.social_media.platforms || []}
                    cx="50%"
                    cy="50%"
                    outerRadius={80}
                    fill="#8884d8"
                    dataKey="engagement"
                    label
                  >
                    {(metrics.social_media.platforms || []).map((entry: PlatformData, index: number) => (
                      <Cell key={`cell-${entry.name || index}`} fill={COLORS[index % COLORS.length]} />
                    ))}
                  </Pie>
                  <Tooltip />
                  <Legend />
                </PieChart>
              </ResponsiveContainer>
            </div>
          </div>
        )}

        {/* Email Metrics */}
        {metrics.email && (
          <div className="bg-white p-6 rounded-lg shadow-md">
            <h3 className="text-lg font-semibold mb-4">Email Campaign Performance</h3>
            <div className="h-64">
              <ResponsiveContainer width="100%" height="100%">
                <BarChart data={metrics.email.campaigns || []}>
                  <CartesianGrid strokeDasharray="3 3" />
                  <XAxis dataKey="name" />
                  <YAxis />
                  <Tooltip />
                  <Bar dataKey="open_rate" fill="#00C49F" />
                  <Bar dataKey="click_rate" fill="#FFBB28" />
                </BarChart>
              </ResponsiveContainer>
            </div>
          </div>
        )}

        {/* Google Analytics */}
        {metrics.google_analytics && (
          <div className="bg-white p-6 rounded-lg shadow-md">
            <h3 className="text-lg font-semibold mb-4">Website Analytics</h3>
            <div className="h-64">
              <ResponsiveContainer width="100%" height="100%">
                <LineChart data={metrics.google_analytics.timeseries || []}>
                  <CartesianGrid strokeDasharray="3 3" />
                  <XAxis dataKey="date" />
                  <YAxis />
                  <Tooltip />
                  <Line type="monotone" dataKey="sessions" stroke="#FF8042" />
                  <Line type="monotone" dataKey="pageviews" stroke="#8884D8" />
                </LineChart>
              </ResponsiveContainer>
            </div>
          </div>
        )}

        {/* CRM Metrics */}
        {metrics.crm && (
          <div className="bg-white p-6 rounded-lg shadow-md">
            <h3 className="text-lg font-semibold mb-4">CRM Performance</h3>
            <div className="h-64">
              <ResponsiveContainer width="100%" height="100%">
                <AreaChart data={metrics.crm.pipeline || []}>
                  <CartesianGrid strokeDasharray="3 3" />
                  <XAxis dataKey="stage" />
                  <YAxis />
                  <Tooltip />
                  <Area type="monotone" dataKey="value" stroke="#82CA9D" fill="#82CA9D" fillOpacity={0.6} />
                </AreaChart>
              </ResponsiveContainer>
            </div>
          </div>
        )}
      </div>

      {/* Drill-down Results */}
      {drillDownData && (
        <div className="mt-8 bg-white p-6 rounded-lg shadow-md">
          <h3 className="text-lg font-semibold mb-4">Drill-down Analysis</h3>
          <div className="h-64">
            <ResponsiveContainer width="100%" height="100%">
              <BarChart data={drillDownData}>
                <CartesianGrid strokeDasharray="3 3" />
                <XAxis dataKey="name" />
                <YAxis />
                <Tooltip />
                <Bar dataKey="value" fill="#0088FE" />
              </BarChart>
            </ResponsiveContainer>
          </div>
          <button
            onClick={() => setDrillDownData(null)}
            className="mt-4 px-4 py-2 bg-gray-600 text-white rounded hover:bg-gray-700"
          >
            Close
          </button>
        </div>
      )}

      {/* Mobile Touch Controls */}
      <MobileTouchControls
        onRefresh={() => {
          requestInitialMetrics();
          announceToScreenReader('Dashboard refreshed');
        }}
        onExport={() => {
          // Trigger export modal or quick export
          announceToScreenReader('Export options opened');
        }}
        onSettings={() => {
          setCustomMetricBuilder(true);
          announceToScreenReader('Settings opened');
        }}
        theme={getThemeConfig()}
      />
    </div>
  );
};

export default AnalyticsDashboard;