import React, { useState, useMemo, useCallback, memo } from 'react';
import {
  ResponsiveContainer,
  LineChart,
  Line,
  BarChart,
  Bar,
  PieChart,
  Pie,
  Cell,
  AreaChart,
  Area,
  XAxis,
  YAxis,
  CartesianGrid,
  Tooltip,
  Legend,
  Funnel,
  FunnelChart,
  Treemap,
  ScatterChart,
  Scatter,
  RadialBarChart,
  RadialBar
} from 'recharts';
import { Group } from '@visx/group';
import { HeatmapRect } from '@visx/heatmap';
import { scaleLinear } from '@visx/scale';
import { Zoom } from '@visx/zoom';
import throttle from 'lodash.throttle';
// Import removed - not used in current implementation

// Advanced Chart Types
export interface ChartDataPoint {
  name: string;
  value: number;
  date?: string;
  category?: string;
  source?: string;
  x?: number;
  y?: number;
  size?: number;
  color?: string;
  metadata?: Record<string, any>;
}

export interface FunnelDataPoint {
  name: string;
  value: number;
  fill?: string;
  conversionRate?: number;
}

export interface HeatmapDataPoint {
  row: number;
  col: number;
  value: number;
  label?: string;
}

export interface ChartTheme {
  primary: string;
  secondary: string;
  accent: string;
  background: string;
  text: string;
  grid: string;
  colors: string[];
}

export interface ChartOptions {
  showZoom?: boolean;
  showTooltip?: boolean;
  showLegend?: boolean;
  showGrid?: boolean;
  enableBrush?: boolean;
  enableAnimation?: boolean;
  theme?: ChartTheme;
  responsive?: boolean;
  exportable?: boolean;
}

// Default theme matching brand guidelines
export const DEFAULT_THEME: ChartTheme = {
  primary: '#0088FE',
  secondary: '#00C49F',
  accent: '#FFBB28',
  background: '#FFFFFF',
  text: '#374151',
  grid: '#E5E7EB',
  colors: ['#0088FE', '#00C49F', '#FFBB28', '#FF8042', '#8884D8', '#82CA9D', '#FFC658', '#8DD1E1']
};

// Advanced Line Chart with Zoom and Pan
export const AdvancedLineChart = memo(({ 
  data, 
  options = {}, 
  onDataPointClick,
  onZoom 
}: {
  data: ChartDataPoint[];
  options?: ChartOptions;
  onDataPointClick?: (point: ChartDataPoint) => void;
  onZoom?: (scale: number) => void;
}) => {
  const [zoomLevel, setZoomLevel] = useState(1);
  const theme = options.theme || DEFAULT_THEME;

  const handleZoom = useCallback((scale: number) => {
    setZoomLevel(scale);
    onZoom?.(scale);
  }, [onZoom]);

  const throttledZoom = useMemo(
    () => throttle(handleZoom, 100),
    [handleZoom]
  );

  if (options.showZoom) {
    return (
      <div className="relative w-full h-full">
        <Zoom
          width={800}
          height={400}
          scaleXMin={1}
          scaleXMax={10}
          scaleYMin={1}
          scaleYMax={10}
          onZoom={throttledZoom}
        >
          {() => (
            <ResponsiveContainer width="100%" height="100%">
              <LineChart
                data={data}
                margin={{ top: 20, right: 30, left: 20, bottom: 20 }}
              >
                <CartesianGrid 
                  strokeDasharray="3 3" 
                  stroke={theme.grid}
                  opacity={options.showGrid !== false ? 1 : 0}
                />
                <XAxis 
                  dataKey="name" 
                  stroke={theme.text}
                  fontSize={12}
                />
                <YAxis 
                  stroke={theme.text}
                  fontSize={12}
                />
                {options.showTooltip !== false && (
                  <Tooltip
                    contentStyle={{
                      backgroundColor: theme.background,
                      border: `1px solid ${theme.grid}`,
                      borderRadius: '8px',
                      color: theme.text
                    }}
                  />
                )}
                {options.showLegend !== false && (
                  <Legend />
                )}
                <Line
                  type="monotone"
                  dataKey="value"
                  stroke={theme.primary}
                  strokeWidth={2}
                  dot={{ fill: theme.primary, strokeWidth: 2, r: 4 }}
                  activeDot={{ 
                    r: 6, 
                    onClick: (_, payload) => onDataPointClick?.(payload.payload)
                  }}
                  animationDuration={options.enableAnimation !== false ? 750 : 0}
                />
              </LineChart>
            </ResponsiveContainer>
          )}
        </Zoom>
        <div className="absolute top-2 right-2 bg-white bg-opacity-90 px-2 py-1 rounded text-xs">
          Zoom: {(zoomLevel * 100).toFixed(0)}%
        </div>
      </div>
    );
  }

  return (
    <ResponsiveContainer width="100%" height="100%">
      <LineChart
        data={data}
        margin={{ top: 20, right: 30, left: 20, bottom: 20 }}
      >
        <CartesianGrid 
          strokeDasharray="3 3" 
          stroke={theme.grid}
          opacity={options.showGrid !== false ? 1 : 0}
        />
        <XAxis 
          dataKey="name" 
          stroke={theme.text}
          fontSize={12}
        />
        <YAxis 
          stroke={theme.text}
          fontSize={12}
        />
        {options.showTooltip !== false && (
          <Tooltip
            contentStyle={{
              backgroundColor: theme.background,
              border: `1px solid ${theme.grid}`,
              borderRadius: '8px',
              color: theme.text
            }}
          />
        )}
        {options.showLegend !== false && (
          <Legend />
        )}
        <Line
          type="monotone"
          dataKey="value"
          stroke={theme.primary}
          strokeWidth={2}
          dot={{ fill: theme.primary, strokeWidth: 2, r: 4 }}
          activeDot={{ 
            r: 6, 
            onClick: (_, payload) => onDataPointClick?.(payload.payload)
          }}
          animationDuration={options.enableAnimation !== false ? 750 : 0}
        />
      </LineChart>
    </ResponsiveContainer>
  );
});

// Advanced Bar Chart with Hover Details
export const AdvancedBarChart = memo(({ 
  data, 
  options = {}, 
  onBarClick,
  onBarHover 
}: {
  data: ChartDataPoint[];
  options?: ChartOptions;
  onBarClick?: (bar: ChartDataPoint) => void;
  onBarHover?: (bar: ChartDataPoint | null) => void;
}) => {
  const theme = options.theme || DEFAULT_THEME;

  const handleBarClick = useCallback((data: any, _index: number) => {
    onBarClick?.(data);
  }, [onBarClick]);

  const handleBarHover = useCallback((data: any) => {
    onBarHover?.(data);
  }, [onBarHover]);

  const handleBarLeave = useCallback(() => {
    onBarHover?.(null);
  }, [onBarHover]);

  return (
    <ResponsiveContainer width="100%" height="100%">
      <BarChart
        data={data}
        margin={{ top: 20, right: 30, left: 20, bottom: 20 }}
      >
        <CartesianGrid 
          strokeDasharray="3 3" 
          stroke={theme.grid}
          opacity={options.showGrid !== false ? 1 : 0}
        />
        <XAxis 
          dataKey="name" 
          stroke={theme.text}
          fontSize={12}
          angle={-45}
          textAnchor="end"
          height={60}
        />
        <YAxis 
          stroke={theme.text}
          fontSize={12}
        />
        {options.showTooltip !== false && (
          <Tooltip
            contentStyle={{
              backgroundColor: theme.background,
              border: `1px solid ${theme.grid}`,
              borderRadius: '8px',
              color: theme.text
            }}
            formatter={(value: any, name: string, props: any) => [
              `${value.toLocaleString()}`,
              name,
              {
                style: {
                  color: props.color
                }
              }
            ]}
          />
        )}
        {options.showLegend !== false && (
          <Legend />
        )}
        <Bar
          dataKey="value"
          fill={theme.primary}
          onClick={handleBarClick}
          onMouseEnter={handleBarHover}
          onMouseLeave={handleBarLeave}
          animationDuration={options.enableAnimation !== false ? 750 : 0}
        />
      </BarChart>
    </ResponsiveContainer>
  );
});

// Funnel Visualization for Conversion Tracking
export const FunnelVisualization = memo(({ 
  data, 
  options = {}, 
  onStageClick 
}: {
  data: FunnelDataPoint[];
  options?: ChartOptions;
  onStageClick?: (stage: FunnelDataPoint) => void;
}) => {
  const theme = options.theme || DEFAULT_THEME;

  return (
    <ResponsiveContainer width="100%" height="100%">
      <FunnelChart>
        <Tooltip
          contentStyle={{
            backgroundColor: theme.background,
            border: `1px solid ${theme.grid}`,
            borderRadius: '8px',
            color: theme.text
          }}
          formatter={(value: any, name: string) => [
            `${value.toLocaleString()} (${name})`,
            'Value'
          ]}
        />
        <Funnel
          dataKey="value"
          data={data}
          isAnimationActive={options.enableAnimation !== false}
          onClick={(data) => onStageClick?.(data)}
        />
      </FunnelChart>
    </ResponsiveContainer>
  );
});

// Heatmap Display for Engagement Patterns
export const HeatmapDisplay = memo(({ 
  data, 
  width = 800, 
  height = 400, 
  options = {} 
}: {
  data: HeatmapDataPoint[];
  width?: number;
  height?: number;
  options?: ChartOptions;
}) => {
  const theme = options.theme || DEFAULT_THEME;
  
  const colorScale = scaleLinear<string>({
    range: [theme.secondary, theme.primary],
    domain: [0, Math.max(...data.map(d => d.value))]
  });

  const maxRow = Math.max(...data.map(d => d.row));
  const maxCol = Math.max(...data.map(d => d.col));
  
  const cellWidth = width / (maxCol + 1);
  const cellHeight = height / (maxRow + 1);

  return (
    <div className="relative">
      <svg width={width} height={height}>
        <Group>
          <HeatmapRect
            data={data}
            xScale={(d) => d.col * cellWidth}
            yScale={(d) => d.row * cellHeight}
            colorScale={colorScale}
            binWidth={cellWidth}
            binHeight={cellHeight}
          />
        </Group>
      </svg>
    </div>
  );
});

// Donut Chart with Center Text
export const DonutChart = memo(({ 
  data, 
  options = {}, 
  centerText,
  onSegmentClick 
}: {
  data: ChartDataPoint[];
  options?: ChartOptions;
  centerText?: string;
  onSegmentClick?: (segment: ChartDataPoint) => void;
}) => {
  const theme = options.theme || DEFAULT_THEME;

  const renderCustomLabel = (entry: any) => {
    const percent = ((entry.value / data.reduce((sum, item) => sum + item.value, 0)) * 100).toFixed(1);
    return `${entry.name}: ${percent}%`;
  };

  return (
    <div className="relative">
      <ResponsiveContainer width="100%" height="100%">
        <PieChart>
          <Pie
            data={data}
            cx="50%"
            cy="50%"
            labelLine={false}
            label={renderCustomLabel}
            outerRadius={80}
            innerRadius={40}
            fill="#8884d8"
            dataKey="value"
            onClick={(data) => onSegmentClick?.(data)}
            animationDuration={options.enableAnimation !== false ? 750 : 0}
          >
            {data.map((entry, index) => (
              <Cell 
                key={`cell-${entry.name}-${index}`} 
                fill={theme.colors[index % theme.colors.length]} 
              />
            ))}
          </Pie>
          {options.showTooltip !== false && (
            <Tooltip
              contentStyle={{
                backgroundColor: theme.background,
                border: `1px solid ${theme.grid}`,
                borderRadius: '8px',
                color: theme.text
              }}
            />
          )}
          {options.showLegend !== false && (
            <Legend />
          )}
        </PieChart>
      </ResponsiveContainer>
      {centerText && (
        <div className="absolute inset-0 flex items-center justify-center pointer-events-none">
          <div className="text-center">
            <div className="text-2xl font-bold text-gray-900">{centerText}</div>
          </div>
        </div>
      )}
    </div>
  );
});

// Scatter Plot for Correlation Analysis
export const ScatterPlot = memo(({ 
  data, 
  options = {}, 
  onPointClick 
}: {
  data: ChartDataPoint[];
  options?: ChartOptions;
  onPointClick?: (point: ChartDataPoint) => void;
}) => {
  const theme = options.theme || DEFAULT_THEME;

  return (
    <ResponsiveContainer width="100%" height="100%">
      <ScatterChart
        margin={{ top: 20, right: 20, bottom: 20, left: 20 }}
      >
        <CartesianGrid stroke={theme.grid} />
        <XAxis 
          type="number" 
          dataKey="x" 
          stroke={theme.text}
          name="X Axis"
        />
        <YAxis 
          type="number" 
          dataKey="y" 
          stroke={theme.text}
          name="Y Axis"
        />
        {options.showTooltip !== false && (
          <Tooltip 
            cursor={{ strokeDasharray: '3 3' }}
            contentStyle={{
              backgroundColor: theme.background,
              border: `1px solid ${theme.grid}`,
              borderRadius: '8px',
              color: theme.text
            }}
          />
        )}
        <Scatter 
          name="Data Points" 
          data={data} 
          fill={theme.primary}
          onClick={(data) => onPointClick?.(data)}
        />
      </ScatterChart>
    </ResponsiveContainer>
  );
});

// Tree Map for Hierarchical Data
export const TreeMapChart = memo(({ 
  data, 
  options = {}, 
  onNodeClick 
}: {
  data: ChartDataPoint[];
  options?: ChartOptions;
  onNodeClick?: (node: ChartDataPoint) => void;
}) => {
  const theme = options.theme || DEFAULT_THEME;

  return (
    <ResponsiveContainer width="100%" height="100%">
      <Treemap
        data={data}
        dataKey="value"
        ratio={4/3}
        stroke={theme.background}
        fill={theme.primary}
        onClick={(data) => onNodeClick?.(data)}
        animationDuration={options.enableAnimation !== false ? 750 : 0}
      />
    </ResponsiveContainer>
  );
});

// Radial Bar Chart for Circular Metrics
export const RadialBarChartComponent = memo(({ 
  data, 
  options = {} 
}: {
  data: ChartDataPoint[];
  options?: ChartOptions;
}) => {
  const theme = options.theme || DEFAULT_THEME;

  return (
    <ResponsiveContainer width="100%" height="100%">
      <RadialBarChart 
        cx="50%" 
        cy="50%" 
        innerRadius="10%" 
        outerRadius="80%" 
        barSize={10} 
        data={data}
      >
        <RadialBar 
          minAngle={15} 
          label={{ position: 'insideStart', fill: '#fff' }} 
          background 
          clockWise 
          dataKey="value" 
          fill={theme.primary}
        />
        {options.showLegend !== false && (
          <Legend 
            iconSize={10} 
            layout="vertical" 
            verticalAlign="middle" 
            wrapperStyle={{
              color: theme.text,
              fontSize: '12px',
              lineHeight: '40px'
            }} 
          />
        )}
      </RadialBarChart>
    </ResponsiveContainer>
  );
});

// Multi-series Area Chart
export const MultiSeriesAreaChart = memo(({ 
  data, 
  series, 
  options = {} 
}: {
  data: ChartDataPoint[];
  series: string[];
  options?: ChartOptions;
}) => {
  const theme = options.theme || DEFAULT_THEME;

  return (
    <ResponsiveContainer width="100%" height="100%">
      <AreaChart
        data={data}
        margin={{ top: 20, right: 30, left: 20, bottom: 20 }}
      >
        <CartesianGrid strokeDasharray="3 3" stroke={theme.grid} />
        <XAxis dataKey="name" stroke={theme.text} />
        <YAxis stroke={theme.text} />
        {options.showTooltip !== false && (
          <Tooltip
            contentStyle={{
              backgroundColor: theme.background,
              border: `1px solid ${theme.grid}`,
              borderRadius: '8px',
              color: theme.text
            }}
          />
        )}
        {options.showLegend !== false && (
          <Legend />
        )}
        {series.map((seriesName, index) => (
          <Area
            key={seriesName}
            type="monotone"
            dataKey={seriesName}
            stackId="1"
            stroke={theme.colors[index % theme.colors.length]}
            fill={theme.colors[index % theme.colors.length]}
            fillOpacity={0.6}
            animationDuration={options.enableAnimation !== false ? 750 : 0}
          />
        ))}
      </AreaChart>
    </ResponsiveContainer>
  );
});

AdvancedLineChart.displayName = 'AdvancedLineChart';
AdvancedBarChart.displayName = 'AdvancedBarChart';
FunnelVisualization.displayName = 'FunnelVisualization';
HeatmapDisplay.displayName = 'HeatmapDisplay';
DonutChart.displayName = 'DonutChart';
ScatterPlot.displayName = 'ScatterPlot';
TreeMapChart.displayName = 'TreeMapChart';
RadialBarChartComponent.displayName = 'RadialBarChartComponent';
MultiSeriesAreaChart.displayName = 'MultiSeriesAreaChart';