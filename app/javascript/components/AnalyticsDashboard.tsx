import React, { useState, useEffect, useCallback, useMemo } from 'react';
import { 
  LineChart, Line, BarChart, Bar, PieChart, Pie, Cell, 
  ResponsiveContainer, XAxis, YAxis, CartesianGrid, Tooltip, Legend,
  ReferenceLine, Area, AreaChart
} from 'recharts';
import { DateRange } from 'react-date-range';
import { format, subDays, subMonths, subYears } from 'date-fns';
import { createConsumer } from '@rails/actioncable';
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
  [key: string]: any;
}

interface DashboardProps {
  brandId: string;
  userId: string;
  initialMetrics?: any;
}

interface DateRangeState {
  startDate: Date;
  endDate: Date;
  key: string;
}

// Color schemes for charts
const COLORS = ['#0088FE', '#00C49F', '#FFBB28', '#FF8042', '#8884D8', '#82CA9D'];
const TREND_COLORS = {
  up: '#00C49F',
  down: '#FF8042',
  neutral: '#8884D8'
};

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
  userId, 
  initialMetrics 
}) => {
  // State management
  const [metrics, setMetrics] = useState<any>(initialMetrics || {});
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [selectedMetrics, setSelectedMetrics] = useState<string[]>(['all']);
  const [chartType, setChartType] = useState<'line' | 'bar' | 'area'>('line');
  const [showDatePicker, setShowDatePicker] = useState(false);
  const [customMetricBuilder, setCustomMetricBuilder] = useState(false);
  const [drillDownData, setDrillDownData] = useState<any>(null);
  
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
  const [channel, setChannel] = useState<any>(null);

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
  }, [brandId, cable]);

  // Handle real-time updates from ActionCable
  const handleRealtimeUpdate = useCallback((data: any) => {
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

  // Request initial metrics
  const requestInitialMetrics = useCallback(() => {
    if (!channel) {return;}
    
    setLoading(true);
    setError(null);
    
    channel.perform('request_metrics', {
      metric_type: 'all',
      time_range: getTimeRangeString(),
      brand_id: brandId
    });
  }, [channel, brandId, dateRange]);

  // Request specific metrics
  const requestMetrics = useCallback((metricType: string) => {
    if (!channel) {return;}
    
    setLoading(true);
    channel.perform('request_metrics', {
      metric_type: metricType,
      time_range: getTimeRangeString(),
      brand_id: brandId
    });
  }, [channel, brandId, dateRange]);

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
  const handleDateRangeChange = useCallback((ranges: any) => {
    setDateRange([ranges.selection]);
    setShowDatePicker(false);
    // Request new data with updated range
    setTimeout(() => requestInitialMetrics(), 100);
  }, [requestInitialMetrics]);

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

  // Build custom metric
  const buildCustomMetric = useCallback((config: any) => {
    if (!channel) {return;}
    
    channel.perform('build_custom_metric', {
      ...config,
      brand_id: brandId
    });
  }, [channel, brandId]);

  // Perform drill-down
  const performDrillDown = useCallback((source: string, metric: string, dimension: string, filters: any = {}) => {
    if (!channel) {return;}
    
    channel.perform('drill_down', {
      source,
      metric,
      dimension,
      filters,
      brand_id: brandId
    });
  }, [channel, brandId]);

  // Prepare chart data
  const chartData = useMemo(() => {
    const data: ChartData[] = [];
    
    // Combine data from all sources
    Object.entries(metrics).forEach(([source, sourceData]: [string, any]) => {
      if (sourceData && typeof sourceData === 'object') {
        if (sourceData.timeseries) {
          sourceData.timeseries.forEach((item: any) => {
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
    
    Object.entries(metrics).forEach(([source, sourceData]: [string, any]) => {
      if (sourceData && typeof sourceData === 'object') {
        if (sourceData.summary) {
          Object.entries(sourceData.summary).forEach(([metric, value]: [string, any]) => {
            summary.push({
              name: `${source}_${metric}`,
              value: typeof value === 'number' ? value : 0,
              trend: value > 0 ? 'up' : value < 0 ? 'down' : 'neutral'
            });
          });
        }
      }
    });
    
    return summary;
  }, [metrics]);

  // Export functionality
  const exportData = useCallback(async (format: 'csv' | 'pdf' | 'png') => {
    try {
      setLoading(true);
      
      switch (format) {
        case 'csv':
          const csvData = convertToCSV(chartData);
          downloadFile(csvData, 'analytics-data.csv', 'text/csv');
          break;
        case 'pdf':
          await exportToPDF();
          break;
        case 'png':
          await exportToPNG();
          break;
      }
    } catch (error) {
      console.error('Export failed:', error);
      setError('Export failed. Please try again.');
    } finally {
      setLoading(false);
    }
  }, [chartData]);

  // Helper functions
  const convertToCSV = (data: ChartData[]) => {
    const headers = Object.keys(data[0] || {}).join(',');
    const rows = data.map(row => Object.values(row).join(','));
    return [headers, ...rows].join('\\n');
  };

  const downloadFile = (content: string, filename: string, contentType: string) => {
    const blob = new Blob([content], { type: contentType });
    const url = URL.createObjectURL(blob);
    const link = document.createElement('a');
    link.href = url;
    link.download = filename;
    link.click();
    URL.revokeObjectURL(url);
  };

  const exportToPDF = async () => {
    // Implementation for PDF export using jsPDF
    const { jsPDF } = await import('jspdf');
    const pdf = new jsPDF();
    pdf.text('Analytics Dashboard', 20, 20);
    // Add charts and data to PDF
    pdf.save('analytics-dashboard.pdf');
  };

  const exportToPNG = async () => {
    // Implementation for PNG export using html2canvas
    const html2canvas = (await import('html2canvas')).default;
    const element = document.getElementById('analytics-dashboard');
    if (element) {
      const canvas = await html2canvas(element);
      const link = document.createElement('a');
      link.download = 'analytics-dashboard.png';
      link.href = canvas.toDataURL();
      link.click();
    }
  };

  // Custom Metric Builder Component
  const CustomMetricBuilder = () => {
    const [metricConfig, setMetricConfig] = useState({
      name: '',
      sources: [],
      aggregation: 'sum',
      filters: {}
    });

    return (
      <div className="bg-white p-6 rounded-lg shadow-md">
        <h3 className="text-lg font-semibold mb-4">Custom Metric Builder</h3>
        <div className="space-y-4">
          <input
            type="text"
            placeholder="Metric Name"
            value={metricConfig.name}
            onChange={(e) => setMetricConfig(prev => ({ ...prev, name: e.target.value }))}
            className="w-full p-2 border border-gray-300 rounded"
          />
          
          <div>
            <label className="block text-sm font-medium mb-2">Data Sources</label>
            <div className="space-y-2">
              {['social_media', 'email', 'google_analytics', 'crm'].map(source => (
                <label key={source} className="flex items-center">
                  <input
                    type="checkbox"
                    checked={metricConfig.sources.includes(source)}
                    onChange={(e) => {
                      if (e.target.checked) {
                        setMetricConfig(prev => ({ 
                          ...prev, 
                          sources: [...prev.sources, source] 
                        }));
                      } else {
                        setMetricConfig(prev => ({ 
                          ...prev, 
                          sources: prev.sources.filter(s => s !== source) 
                        }));
                      }
                    }}
                    className="mr-2"
                  />
                  {source.replace('_', ' ').toUpperCase()}
                </label>
              ))}
            </div>
          </div>
          
          <select
            value={metricConfig.aggregation}
            onChange={(e) => setMetricConfig(prev => ({ ...prev, aggregation: e.target.value }))}
            className="w-full p-2 border border-gray-300 rounded"
          >
            <option value="sum">Sum</option>
            <option value="average">Average</option>
            <option value="max">Maximum</option>
            <option value="min">Minimum</option>
          </select>
          
          <div className="flex space-x-2">
            <button
              onClick={() => buildCustomMetric(metricConfig)}
              className="bg-blue-600 text-white px-4 py-2 rounded hover:bg-blue-700"
            >
              Build Metric
            </button>
            <button
              onClick={() => setCustomMetricBuilder(false)}
              className="bg-gray-600 text-white px-4 py-2 rounded hover:bg-gray-700"
            >
              Cancel
            </button>
          </div>
        </div>
      </div>
    );
  };

  return (
    <div id="analytics-dashboard" className="p-6 max-w-7xl mx-auto">
      {/* Header */}
      <div className="mb-8">
        <h1 className="text-3xl font-bold text-gray-900 mb-4">Analytics Dashboard</h1>
        
        {/* Controls */}
        <div className="flex flex-wrap items-center gap-4 mb-6">
          {/* Date Range Presets */}
          <div className="flex space-x-2">
            {Object.entries(DATE_PRESETS).map(([key, preset]) => (
              <button
                key={key}
                onClick={() => handlePresetDateRange(key as keyof typeof DATE_PRESETS)}
                className="px-3 py-1 text-sm border border-gray-300 rounded hover:bg-gray-50"
              >
                {preset.label}
              </button>
            ))}
          </div>
          
          {/* Custom Date Range */}
          <button
            onClick={() => setShowDatePicker(!showDatePicker)}
            className="px-4 py-2 bg-blue-600 text-white rounded hover:bg-blue-700"
          >
            Custom Range
          </button>
          
          {/* Chart Type Selector */}
          <select
            value={chartType}
            onChange={(e) => setChartType(e.target.value as 'line' | 'bar' | 'area')}
            className="p-2 border border-gray-300 rounded"
          >
            <option value="line">Line Chart</option>
            <option value="bar">Bar Chart</option>
            <option value="area">Area Chart</option>
          </select>
          
          {/* Custom Metric Builder */}
          <button
            onClick={() => setCustomMetricBuilder(true)}
            className="px-4 py-2 bg-green-600 text-white rounded hover:bg-green-700"
          >
            Custom Metrics
          </button>
          
          {/* Export Options */}
          <div className="flex space-x-2">
            <button
              onClick={() => exportData('csv')}
              className="px-3 py-1 text-sm bg-gray-600 text-white rounded hover:bg-gray-700"
            >
              CSV
            </button>
            <button
              onClick={() => exportData('pdf')}
              className="px-3 py-1 text-sm bg-gray-600 text-white rounded hover:bg-gray-700"
            >
              PDF
            </button>
            <button
              onClick={() => exportData('png')}
              className="px-3 py-1 text-sm bg-gray-600 text-white rounded hover:bg-gray-700"
            >
              PNG
            </button>
          </div>
        </div>
        
        {/* Date Picker */}
        {showDatePicker && (
          <div className="absolute z-10 bg-white border border-gray-300 rounded-lg shadow-lg">
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
        <div className="flex items-center justify-center py-8">
          <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-blue-600" />
          <span className="ml-2">Loading analytics data...</span>
        </div>
      )}

      {/* Error State */}
      {error && (
        <div className="bg-red-100 border border-red-400 text-red-700 px-4 py-3 rounded mb-6">
          {error}
          <button
            onClick={() => setError(null)}
            className="float-right font-bold text-red-700 hover:text-red-900"
          >
            ×
          </button>
        </div>
      )}

      {/* Custom Metric Builder Modal */}
      {customMetricBuilder && (
        <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50">
          <div className="bg-white rounded-lg max-w-md w-full mx-4">
            <CustomMetricBuilder />
          </div>
        </div>
      )}

      {/* Summary Metrics */}
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6 mb-8">
        {summaryMetrics.slice(0, 8).map((metric, index) => (
          <div key={metric.name} className="bg-white p-6 rounded-lg shadow-md">
            <div className="flex items-center justify-between">
              <div>
                <p className="text-sm text-gray-600 mb-1">
                  {metric.name.replace(/_/g, ' ').toUpperCase()}
                </p>
                <p className="text-2xl font-bold text-gray-900">
                  {metric.value.toLocaleString()}
                </p>
              </div>
              <div className={`w-3 h-3 rounded-full bg-${TREND_COLORS[metric.trend || 'neutral']}`} />
            </div>
          </div>
        ))}
      </div>

      {/* Main Chart */}
      <div className="bg-white p-6 rounded-lg shadow-md mb-8">
        <h2 className="text-xl font-semibold mb-4">Trends Overview</h2>
        <div className="h-96">
          <ResponsiveContainer width="100%" height="100%">
            {chartType === 'line' && (
              <LineChart data={chartData}>
                <CartesianGrid strokeDasharray="3 3" />
                <XAxis dataKey="date" />
                <YAxis />
                <Tooltip />
                <Legend />
                <Line type="monotone" dataKey="value" stroke="#0088FE" strokeWidth={2} />
              </LineChart>
            )}
            {chartType === 'bar' && (
              <BarChart data={chartData}>
                <CartesianGrid strokeDasharray="3 3" />
                <XAxis dataKey="date" />
                <YAxis />
                <Tooltip />
                <Legend />
                <Bar dataKey="value" fill="#0088FE" />
              </BarChart>
            )}
            {chartType === 'area' && (
              <AreaChart data={chartData}>
                <CartesianGrid strokeDasharray="3 3" />
                <XAxis dataKey="date" />
                <YAxis />
                <Tooltip />
                <Legend />
                <Area type="monotone" dataKey="value" stroke="#0088FE" fill="#0088FE" fillOpacity={0.6} />
              </AreaChart>
            )}
          </ResponsiveContainer>
        </div>
      </div>

      {/* Source-specific Charts */}
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-8">
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
                    {(metrics.social_media.platforms || []).map((entry: any, index: number) => (
                      <Cell key={`cell-${index}`} fill={COLORS[index % COLORS.length]} />
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
    </div>
  );
};

export default AnalyticsDashboard;