import React, { useState, useCallback, memo } from 'react';
import { saveAs } from 'file-saver';
import html2canvas from 'html2canvas';
import { jsPDF } from 'jspdf';
import { ChartDataPoint, ChartTheme } from './AdvancedCharts';

// Export types
export type ExportFormat = 'csv' | 'json' | 'pdf' | 'png' | 'svg' | 'xlsx';

export interface ExportOptions {
  format: ExportFormat;
  includeCharts: boolean;
  includeMetrics: boolean;
  dateRange: string;
  fileName?: string;
  quality?: number; // For image exports
  orientation?: 'portrait' | 'landscape'; // For PDF
}

export interface ExportData {
  metrics: Array<{
    name: string;
    value: number;
    change?: number;
    trend?: string;
    timestamp: string;
  }>;
  chartData: ChartDataPoint[];
  metadata: {
    exportDate: string;
    brandId: string;
    dateRange: string;
    dashboardVersion: string;
  };
}

// Enhanced Export Manager Component
export const ExportManager = memo(({ 
  data, 
  theme, 
  brandId,
  onExportStart,
  onExportComplete,
  onExportError 
}: {
  data: ExportData;
  theme: ChartTheme;
  brandId: string;
  onExportStart?: () => void;
  onExportComplete?: (format: ExportFormat) => void;
  onExportError?: (error: string) => void;
}) => {
  const [isExporting, setIsExporting] = useState(false);
  const [exportOptions, setExportOptions] = useState<ExportOptions>({
    format: 'csv',
    includeCharts: true,
    includeMetrics: true,
    dateRange: 'current',
    quality: 1.0,
    orientation: 'landscape'
  });
  const [showExportModal, setShowExportModal] = useState(false);

  // CSV Export
  const exportToCSV = useCallback(async (options: ExportOptions) => {
    try {
      const csvData = convertToCSV(data, options);
      const blob = new Blob([csvData], { type: 'text/csv;charset=utf-8;' });
      const fileName = options.fileName || `analytics-${data.metadata.brandId}-${new Date().toISOString().split('T')[0]}.csv`;
      saveAs(blob, fileName);
      return true;
    } catch (error) {
      throw new Error(`CSV export failed: ${error}`);
    }
  }, [data]);

  // JSON Export
  const exportToJSON = useCallback(async (options: ExportOptions) => {
    try {
      const jsonData = JSON.stringify(data, null, 2);
      const blob = new Blob([jsonData], { type: 'application/json;charset=utf-8;' });
      const fileName = options.fileName || `analytics-${data.metadata.brandId}-${new Date().toISOString().split('T')[0]}.json`;
      saveAs(blob, fileName);
      return true;
    } catch (error) {
      throw new Error(`JSON export failed: ${error}`);
    }
  }, [data]);

  // PDF Export
  const exportToPDF = useCallback(async (options: ExportOptions) => {
    try {
      const pdf = new jsPDF({
        orientation: options.orientation || 'landscape',
        unit: 'mm',
        format: 'a4'
      });

      // Add title
      pdf.setFontSize(20);
      pdf.text('Analytics Dashboard Report', 20, 30);
      
      // Add metadata
      pdf.setFontSize(12);
      pdf.text(`Brand ID: ${data.metadata.brandId}`, 20, 45);
      pdf.text(`Export Date: ${data.metadata.exportDate}`, 20, 55);
      pdf.text(`Date Range: ${data.metadata.dateRange}`, 20, 65);

      let yPosition = 80;

      // Add metrics if included
      if (options.includeMetrics && data.metrics.length > 0) {
        pdf.setFontSize(16);
        pdf.text('Key Metrics', 20, yPosition);
        yPosition += 15;

        pdf.setFontSize(10);
        data.metrics.forEach((metric, _index) => {
          if (yPosition > 270) { // New page if needed
            pdf.addPage();
            yPosition = 20;
          }
          
          pdf.text(`${metric.name}: ${metric.value.toLocaleString()}`, 20, yPosition);
          if (metric.change !== undefined) {
            const changeText = `(${metric.change > 0 ? '+' : ''}${metric.change.toFixed(1)}%)`;
            pdf.text(changeText, 100, yPosition);
          }
          yPosition += 8;
        });

        yPosition += 10;
      }

      // Add charts if included
      if (options.includeCharts) {
        const dashboardElement = document.getElementById('analytics-dashboard');
        if (dashboardElement) {
          const canvas = await html2canvas(dashboardElement, {
            scale: options.quality || 1.0,
            backgroundColor: theme.background
          });
          
          const imgData = canvas.toDataURL('image/png');
          const imgWidth = 270; // A4 width in mm minus margins
          const imgHeight = (canvas.height * imgWidth) / canvas.width;
          
          if (yPosition + imgHeight > 290) {
            pdf.addPage();
            yPosition = 20;
          }
          
          pdf.addImage(imgData, 'PNG', 20, yPosition, imgWidth, imgHeight);
        }
      }

      const fileName = options.fileName || `analytics-${data.metadata.brandId}-${new Date().toISOString().split('T')[0]}.pdf`;
      pdf.save(fileName);
      return true;
    } catch (error) {
      throw new Error(`PDF export failed: ${error}`);
    }
  }, [data, theme]);

  // PNG Export
  const exportToPNG = useCallback(async (options: ExportOptions) => {
    try {
      const dashboardElement = document.getElementById('analytics-dashboard');
      if (!dashboardElement) {
        throw new Error('Dashboard element not found');
      }

      const canvas = await html2canvas(dashboardElement, {
        scale: options.quality || 1.0,
        backgroundColor: theme.background,
        useCORS: true,
        allowTaint: true
      });

      canvas.toBlob((blob) => {
        if (blob) {
          const fileName = options.fileName || `analytics-${data.metadata.brandId}-${new Date().toISOString().split('T')[0]}.png`;
          saveAs(blob, fileName);
        }
      }, 'image/png');
      
      return true;
    } catch (error) {
      throw new Error(`PNG export failed: ${error}`);
    }
  }, [data, theme]);

  // SVG Export (simplified)
  const exportToSVG = useCallback(async (options: ExportOptions) => {
    try {
      // Create a simple SVG representation of the data
      const svgContent = generateSVGChart(data.chartData, theme);
      const blob = new Blob([svgContent], { type: 'image/svg+xml;charset=utf-8;' });
      const fileName = options.fileName || `analytics-${data.metadata.brandId}-${new Date().toISOString().split('T')[0]}.svg`;
      saveAs(blob, fileName);
      return true;
    } catch (error) {
      throw new Error(`SVG export failed: ${error}`);
    }
  }, [data, theme]);

  // Main export function
  const handleExport = useCallback(async (options: ExportOptions) => {
    setIsExporting(true);
    onExportStart?.();

    try {
      let success = false;

      switch (options.format) {
        case 'csv':
          success = await exportToCSV(options);
          break;
        case 'json':
          success = await exportToJSON(options);
          break;
        case 'pdf':
          success = await exportToPDF(options);
          break;
        case 'png':
          success = await exportToPNG(options);
          break;
        case 'svg':
          success = await exportToSVG(options);
          break;
        default:
          throw new Error(`Unsupported export format: ${options.format}`);
      }

      if (success) {
        onExportComplete?.(options.format);
        setShowExportModal(false);
      }
    } catch (error) {
      const errorMessage = error instanceof Error ? error.message : 'Export failed';
      onExportError?.(errorMessage);
    } finally {
      setIsExporting(false);
    }
  }, [exportToCSV, exportToJSON, exportToPDF, exportToPNG, exportToSVG, onExportStart, onExportComplete, onExportError]);

  // Quick export buttons
  const QuickExportButtons = memo(() => (
    <div className="flex space-x-2">
      {(['csv', 'pdf', 'png'] as ExportFormat[]).map((format) => (
        <button
          key={format}
          onClick={() => handleExport({ ...exportOptions, format })}
          disabled={isExporting}
          className={`px-3 py-1 text-sm rounded ${
            isExporting ? 'opacity-50 cursor-not-allowed' : 'hover:opacity-80'
          }`}
          style={{
            backgroundColor: theme.primary,
            color: theme.background
          }}
          aria-label={`Export as ${format.toUpperCase()}`}
        >
          {format.toUpperCase()}
        </button>
      ))}
      <button
        onClick={() => setShowExportModal(true)}
        className="px-3 py-1 text-sm rounded border"
        style={{
          borderColor: theme.primary,
          color: theme.primary,
          backgroundColor: 'transparent'
        }}
        aria-label="More export options"
      >
        More...
      </button>
    </div>
  ));

  // Export modal
  const ExportModal = memo(() => (
    <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50">
      <div 
        className="rounded-lg p-6 max-w-md w-full mx-4 max-h-screen overflow-y-auto"
        style={{ backgroundColor: theme.background, color: theme.text }}
      >
        <div className="flex items-center justify-between mb-4">
          <h3 className="text-lg font-semibold">Export Options</h3>
          <button
            onClick={() => setShowExportModal(false)}
            className="text-xl hover:opacity-70"
            aria-label="Close export options"
          >
            ×
          </button>
        </div>

        <div className="space-y-4">
          {/* Format Selection */}
          <div>
            <label className="block text-sm font-medium mb-2">Export Format</label>
            <select
              value={exportOptions.format}
              onChange={(e) => setExportOptions(prev => ({ ...prev, format: e.target.value as ExportFormat }))}
              className="w-full p-2 border rounded"
              style={{ backgroundColor: theme.background, borderColor: theme.grid }}
            >
              <option value="csv">CSV - Comma Separated Values</option>
              <option value="json">JSON - JavaScript Object Notation</option>
              <option value="pdf">PDF - Portable Document Format</option>
              <option value="png">PNG - Portable Network Graphics</option>
              <option value="svg">SVG - Scalable Vector Graphics</option>
            </select>
          </div>

          {/* Content Options */}
          <div>
            <label className="block text-sm font-medium mb-2">Include Content</label>
            <div className="space-y-2">
              <label className="flex items-center">
                <input
                  type="checkbox"
                  checked={exportOptions.includeMetrics}
                  onChange={(e) => setExportOptions(prev => ({ ...prev, includeMetrics: e.target.checked }))}
                  className="mr-2"
                />
                Include Metrics
              </label>
              <label className="flex items-center">
                <input
                  type="checkbox"
                  checked={exportOptions.includeCharts}
                  onChange={(e) => setExportOptions(prev => ({ ...prev, includeCharts: e.target.checked }))}
                  className="mr-2"
                />
                Include Charts
              </label>
            </div>
          </div>

          {/* PDF Options */}
          {exportOptions.format === 'pdf' && (
            <div>
              <label className="block text-sm font-medium mb-2">PDF Orientation</label>
              <select
                value={exportOptions.orientation}
                onChange={(e) => setExportOptions(prev => ({ ...prev, orientation: e.target.value as 'portrait' | 'landscape' }))}
                className="w-full p-2 border rounded"
                style={{ backgroundColor: theme.background, borderColor: theme.grid }}
              >
                <option value="landscape">Landscape</option>
                <option value="portrait">Portrait</option>
              </select>
            </div>
          )}

          {/* Image Quality */}
          {(exportOptions.format === 'png' || exportOptions.format === 'pdf') && (
            <div>
              <label className="block text-sm font-medium mb-2">
                Image Quality: {Math.round((exportOptions.quality || 1.0) * 100)}%
              </label>
              <input
                type="range"
                min="0.5"
                max="2.0"
                step="0.1"
                value={exportOptions.quality || 1.0}
                onChange={(e) => setExportOptions(prev => ({ ...prev, quality: parseFloat(e.target.value) }))}
                className="w-full"
              />
            </div>
          )}

          {/* File Name */}
          <div>
            <label className="block text-sm font-medium mb-2">File Name (optional)</label>
            <input
              type="text"
              value={exportOptions.fileName || ''}
              onChange={(e) => setExportOptions(prev => ({ ...prev, fileName: e.target.value }))}
              placeholder={`analytics-${brandId}-${new Date().toISOString().split('T')[0]}`}
              className="w-full p-2 border rounded"
              style={{ backgroundColor: theme.background, borderColor: theme.grid }}
            />
          </div>

          {/* Action Buttons */}
          <div className="flex space-x-2 pt-4">
            <button
              onClick={() => handleExport(exportOptions)}
              disabled={isExporting}
              className={`flex-1 py-2 px-4 rounded ${
                isExporting ? 'opacity-50 cursor-not-allowed' : 'hover:opacity-90'
              }`}
              style={{
                backgroundColor: theme.primary,
                color: theme.background
              }}
            >
              {isExporting ? 'Exporting...' : 'Export'}
            </button>
            <button
              onClick={() => setShowExportModal(false)}
              className="flex-1 py-2 px-4 rounded border"
              style={{
                borderColor: theme.grid,
                color: theme.text
              }}
            >
              Cancel
            </button>
          </div>
        </div>
      </div>
    </div>
  ));

  return (
    <>
      <QuickExportButtons />
      {showExportModal && <ExportModal />}
    </>
  );
});

// Helper Functions
const convertToCSV = (data: ExportData, options: ExportOptions): string => {
  const rows: string[] = [];
  
  // Add header
  rows.push(`# Analytics Dashboard Export`);
  rows.push(`# Brand ID: ${data.metadata.brandId}`);
  rows.push(`# Export Date: ${data.metadata.exportDate}`);
  rows.push(`# Date Range: ${data.metadata.dateRange}`);
  rows.push('');

  if (options.includeMetrics && data.metrics.length > 0) {
    rows.push('## Metrics');
    rows.push('Name,Value,Change,Trend,Timestamp');
    
    data.metrics.forEach(metric => {
      rows.push([
        metric.name,
        metric.value,
        metric.change || '',
        metric.trend || '',
        metric.timestamp
      ].join(','));
    });
    
    rows.push('');
  }

  if (options.includeCharts && data.chartData.length > 0) {
    rows.push('## Chart Data');
    rows.push('Name,Value,Date,Source,Category');
    
    data.chartData.forEach(point => {
      rows.push([
        point.name,
        point.value,
        point.date || '',
        point.source || '',
        point.category || ''
      ].join(','));
    });
  }

  return rows.join('\\n');
};

const generateSVGChart = (data: ChartDataPoint[], theme: ChartTheme): string => {
  const width = 800;
  const height = 400;
  const padding = 60;
  
  const maxValue = Math.max(...data.map(d => d.value));
  const minValue = Math.min(...data.map(d => d.value));
  
  const xScale = (width - 2 * padding) / (data.length - 1);
  const yScale = (height - 2 * padding) / (maxValue - minValue);
  
  let pathData = '';
  data.forEach((point, index) => {
    const x = padding + index * xScale;
    const y = height - padding - (point.value - minValue) * yScale;
    pathData += `${index === 0 ? 'M' : 'L'} ${x} ${y}`;
  });

  return `
    <svg width="${width}" height="${height}" xmlns="http://www.w3.org/2000/svg">
      <style>
        .chart-line { fill: none; stroke: ${theme.primary}; stroke-width: 2; }
        .chart-text { font-family: Arial, sans-serif; font-size: 12px; fill: ${theme.text}; }
        .chart-grid { stroke: ${theme.grid}; stroke-width: 1; }
      </style>
      
      <!-- Grid lines -->
      ${[0, 1, 2, 3, 4].map(i => {
        const y = padding + (i * (height - 2 * padding) / 4);
        return `<line x1="${padding}" y1="${y}" x2="${width - padding}" y2="${y}" class="chart-grid" />`;
      }).join('')}
      
      <!-- Chart line -->
      <path d="${pathData}" class="chart-line" />
      
      <!-- Data points -->
      ${data.map((point, index) => {
        const x = padding + index * xScale;
        const y = height - padding - (point.value - minValue) * yScale;
        return `<circle cx="${x}" cy="${y}" r="3" fill="${theme.primary}" />`;
      }).join('')}
      
      <!-- Labels -->
      <text x="${width / 2}" y="30" text-anchor="middle" class="chart-text" font-size="16" font-weight="bold">
        Analytics Chart Export
      </text>
    </svg>
  `.trim();
};

ExportManager.displayName = 'ExportManager';