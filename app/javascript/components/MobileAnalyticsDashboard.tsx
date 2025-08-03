import React, { useState, useCallback, memo } from 'react';
import { FixedSizeList as List } from 'react-window';
import AutoSizer from 'react-virtualized-auto-sizer';
import { ChartDataPoint, ChartOptions, ChartTheme } from './AdvancedCharts';

// Mobile-optimized chart component
export interface MobileChartProps {
  data: ChartDataPoint[];
  title: string;
  type: 'line' | 'bar' | 'donut' | 'simple';
  theme: ChartTheme;
  onExpand?: () => void;
}

// Simplified mobile chart component
export const MobileChart = memo(({ data, title, type, theme, onExpand }: MobileChartProps) => {
  const [expanded, setExpanded] = useState(false);

  const handleExpand = useCallback(() => {
    setExpanded(!expanded);
    onExpand?.();
  }, [expanded, onExpand]);

  // Simple bar chart for mobile
  const renderSimpleChart = () => {
    const maxValue = Math.max(...data.map(d => d.value));
    
    return (
      <div className="space-y-2">
        {data.slice(0, expanded ? data.length : 5).map((item, index) => (
          <div key={index} className="flex items-center space-x-2">
            <div 
              className="text-xs truncate flex-shrink-0 w-16"
              style={{ color: theme.text }}
            >
              {item.name}
            </div>
            <div className="flex-1 bg-gray-200 rounded-full h-2">
              <div
                className="h-2 rounded-full transition-all duration-300"
                style={{
                  backgroundColor: theme.primary,
                  width: `${(item.value / maxValue) * 100}%`
                }}
              />
            </div>
            <div 
              className="text-xs font-medium flex-shrink-0 w-12 text-right"
              style={{ color: theme.text }}
            >
              {item.value.toLocaleString()}
            </div>
          </div>
        ))}
      </div>
    );
  };

  return (
    <div 
      className="rounded-lg shadow-md p-4 mb-4"
      style={{ backgroundColor: theme.background }}
    >
      <div className="flex items-center justify-between mb-3">
        <h3 
          className="text-sm font-semibold truncate"
          style={{ color: theme.text }}
        >
          {title}
        </h3>
        <button
          onClick={handleExpand}
          className="text-xs px-2 py-1 rounded"
          style={{ 
            backgroundColor: theme.primary, 
            color: theme.background 
          }}
          aria-label={expanded ? 'Collapse chart' : 'Expand chart'}
        >
          {expanded ? '−' : '+'}
        </button>
      </div>
      
      <div className={expanded ? 'h-64' : 'h-32'}>
        {renderSimpleChart()}
      </div>
      
      {data.length > 5 && !expanded && (
        <div className="text-center mt-2">
          <button
            onClick={handleExpand}
            className="text-xs"
            style={{ color: theme.primary }}
          >
            +{data.length - 5} more items
          </button>
        </div>
      )}
    </div>
  );
});

// Mobile-optimized metric card
export interface MobileMetricCardProps {
  title: string;
  value: number;
  change?: number;
  trend?: 'up' | 'down' | 'neutral';
  theme: ChartTheme;
}

export const MobileMetricCard = memo(({ title, value, change, trend, theme }: MobileMetricCardProps) => {
  const trendColor = trend === 'up' ? '#00C49F' : trend === 'down' ? '#FF8042' : '#8884D8';
  
  return (
    <div 
      className="rounded-lg shadow-md p-4 flex-shrink-0 w-32"
      style={{ backgroundColor: theme.background }}
    >
      <div className="text-center">
        <p 
          className="text-xs mb-1 truncate"
          style={{ color: theme.text, opacity: 0.7 }}
        >
          {title}
        </p>
        <p 
          className="text-lg font-bold"
          style={{ color: theme.text }}
        >
          {value.toLocaleString()}
        </p>
        {change !== undefined && (
          <p className="text-xs mt-1" style={{ color: trendColor }}>
            {change > 0 ? '+' : ''}{change.toFixed(1)}%
            <span className="ml-1">
              {trend === 'up' ? '↗' : trend === 'down' ? '↘' : '→'}
            </span>
          </p>
        )}
      </div>
    </div>
  );
});

// Mobile dashboard layout
export interface MobileDashboardProps {
  metrics: Array<{
    title: string;
    value: number;
    change?: number;
    trend?: 'up' | 'down' | 'neutral';
  }>;
  charts: Array<{
    title: string;
    data: ChartDataPoint[];
    type: 'line' | 'bar' | 'donut' | 'simple';
  }>;
  theme: ChartTheme;
}

export const MobileDashboard = memo(({ metrics, charts, theme }: MobileDashboardProps) => {
  const [activeTab, setActiveTab] = useState<'overview' | 'charts'>('overview');

  return (
    <div className="lg:hidden">
      {/* Mobile Navigation */}
      <div className="flex mb-4 sticky top-0 z-10">
        <button
          onClick={() => setActiveTab('overview')}
          className={`flex-1 py-2 px-4 text-sm font-medium rounded-l ${
            activeTab === 'overview'
              ? 'text-white'
              : 'opacity-70'
          }`}
          style={{ 
            backgroundColor: activeTab === 'overview' ? theme.primary : theme.background,
            color: activeTab === 'overview' ? theme.background : theme.text
          }}
        >
          📊 Overview
        </button>
        <button
          onClick={() => setActiveTab('charts')}
          className={`flex-1 py-2 px-4 text-sm font-medium rounded-r ${
            activeTab === 'charts'
              ? 'text-white'
              : 'opacity-70'
          }`}
          style={{ 
            backgroundColor: activeTab === 'charts' ? theme.primary : theme.background,
            color: activeTab === 'charts' ? theme.background : theme.text
          }}
        >
          📈 Charts
        </button>
      </div>

      {/* Mobile Content */}
      {activeTab === 'overview' && (
        <div>
          {/* Horizontal scrolling metrics */}
          <div className="flex space-x-3 overflow-x-auto pb-4 mb-6">
            {metrics.map((metric, index) => (
              <MobileMetricCard
                key={index}
                title={metric.title}
                value={metric.value}
                change={metric.change}
                trend={metric.trend}
                theme={theme}
              />
            ))}
          </div>
          
          {/* Key insights */}
          <div 
            className="rounded-lg shadow-md p-4 mb-4"
            style={{ backgroundColor: theme.background }}
          >
            <h3 
              className="text-sm font-semibold mb-2"
              style={{ color: theme.text }}
            >
              📝 Key Insights
            </h3>
            <ul className="space-y-1 text-xs" style={{ color: theme.text }}>
              <li>• Traffic increased by 15% this week</li>
              <li>• Email campaign performance above average</li>
              <li>• Social media engagement up 8%</li>
            </ul>
          </div>
        </div>
      )}

      {activeTab === 'charts' && (
        <div>
          {charts.map((chart, index) => (
            <MobileChart
              key={index}
              data={chart.data}
              title={chart.title}
              type={chart.type}
              theme={theme}
            />
          ))}
        </div>
      )}
    </div>
  );
});

// Touch-friendly controls
export const MobileTouchControls = memo(({ 
  onRefresh, 
  onExport, 
  onSettings,
  theme 
}: {
  onRefresh: () => void;
  onExport: () => void;
  onSettings: () => void;
  theme: ChartTheme;
}) => {
  return (
    <div className="lg:hidden fixed bottom-4 right-4 flex flex-col space-y-2">
      <button
        onClick={onRefresh}
        className="w-12 h-12 rounded-full shadow-lg flex items-center justify-center"
        style={{ backgroundColor: theme.primary, color: theme.background }}
        aria-label="Refresh data"
      >
        🔄
      </button>
      <button
        onClick={onExport}
        className="w-12 h-12 rounded-full shadow-lg flex items-center justify-center"
        style={{ backgroundColor: theme.secondary, color: theme.background }}
        aria-label="Export data"
      >
        📤
      </button>
      <button
        onClick={onSettings}
        className="w-12 h-12 rounded-full shadow-lg flex items-center justify-center"
        style={{ backgroundColor: theme.accent, color: theme.background }}
        aria-label="Settings"
      >
        ⚙️
      </button>
    </div>
  );
});

// Swipe gesture handler for mobile navigation
export const useSwipeGesture = (
  onSwipeLeft?: () => void,
  onSwipeRight?: () => void
) => {
  const [touchStart, setTouchStart] = useState<{ x: number; y: number } | null>(null);
  const [touchEnd, setTouchEnd] = useState<{ x: number; y: number } | null>(null);

  const minSwipeDistance = 50;

  const onTouchStart = useCallback((e: React.TouchEvent) => {
    setTouchEnd(null);
    setTouchStart({
      x: e.targetTouches[0].clientX,
      y: e.targetTouches[0].clientY
    });
  }, []);

  const onTouchMove = useCallback((e: React.TouchEvent) => {
    setTouchEnd({
      x: e.targetTouches[0].clientX,
      y: e.targetTouches[0].clientY
    });
  }, []);

  const onTouchEnd = useCallback(() => {
    if (!touchStart || !touchEnd) {return;}
    
    const distance = touchStart.x - touchEnd.x;
    const isLeftSwipe = distance > minSwipeDistance;
    const isRightSwipe = distance < -minSwipeDistance;

    if (isLeftSwipe && onSwipeLeft) {
      onSwipeLeft();
    }
    if (isRightSwipe && onSwipeRight) {
      onSwipeRight();
    }
  }, [touchStart, touchEnd, onSwipeLeft, onSwipeRight, minSwipeDistance]);

  return {
    onTouchStart,
    onTouchMove,
    onTouchEnd
  };
};

MobileChart.displayName = 'MobileChart';
MobileMetricCard.displayName = 'MobileMetricCard';
MobileDashboard.displayName = 'MobileDashboard';
MobileTouchControls.displayName = 'MobileTouchControls';