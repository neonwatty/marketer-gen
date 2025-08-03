import React, { Suspense, lazy, useEffect, useState, useCallback } from 'react';
import { LoadingSpinner, Skeleton } from './LoadingStates';

// Performance monitoring utilities
export interface PerformanceMetrics {
  loadTime: number;
  firstContentfulPaint: number;
  largestContentfulPaint: number;
  cumulativeLayoutShift: number;
  firstInputDelay: number;
  timeToInteractive: number;
}

export interface BundleStats {
  totalSize: number;
  chunkSizes: Record<string, number>;
  unusedCode: number;
  duplicateModules: string[];
}

// Code Splitting Utilities
export const createLazyComponent = <T extends React.ComponentType<any>>(
  importFn: () => Promise<{ default: T }>,
  fallbackComponent?: React.ComponentType
) => {
  return lazy(() => 
    importFn().catch((error) => {
      console.error('Failed to load component:', error);
      // Return a fallback component if import fails
      return { 
        default: fallbackComponent || (() => (
          <div className="p-4 text-center text-red-600">
            Failed to load component. Please refresh the page.
          </div>
        )) as T
      };
    })
  );
};

// Lazy loaded components with error boundaries
export const LazyWrapper: React.FC<{
  children: React.ReactNode;
  fallback?: React.ReactNode;
  errorFallback?: React.ReactNode;
}> = ({ 
  children, 
  fallback = <LoadingSpinner size="lg" label="Loading component..." />,
  errorFallback = <div className="p-4 text-center text-red-600">Failed to load component</div>
}) => {
  return (
    <Suspense fallback={fallback}>
      <ErrorBoundary fallback={errorFallback}>
        {children}
      </ErrorBoundary>
    </Suspense>
  );
};

// Simple error boundary for lazy components
class ErrorBoundary extends React.Component<
  { children: React.ReactNode; fallback: React.ReactNode },
  { hasError: boolean }
> {
  constructor(props: any) {
    super(props);
    this.state = { hasError: false };
  }

  static getDerivedStateFromError() {
    return { hasError: true };
  }

  componentDidCatch(error: Error, errorInfo: React.ErrorInfo) {
    console.error('Component error:', error, errorInfo);
  }

  render() {
    if (this.state.hasError) {
      return this.props.fallback;
    }
    return this.props.children;
  }
}

// Image Optimization Component
export const OptimizedImage: React.FC<{
  src: string;
  alt: string;
  width?: number;
  height?: number;
  className?: string;
  loading?: 'lazy' | 'eager';
  priority?: boolean;
  placeholder?: 'blur' | 'empty';
  blurDataURL?: string;
  sizes?: string;
}> = ({
  src,
  alt,
  width,
  height,
  className = '',
  loading = 'lazy',
  priority = false,
  placeholder = 'empty',
  blurDataURL,
  sizes
}) => {
  const [imageSrc, setImageSrc] = useState<string>(blurDataURL || '');
  const [imageLoading, setImageLoading] = useState(true);
  const [imageError, setImageError] = useState(false);

  // Generate WebP and fallback sources
  const getOptimizedSrc = useCallback((originalSrc: string, format: 'webp' | 'original' = 'original') => {
    if (originalSrc.startsWith('data:') || originalSrc.startsWith('blob:')) {
      return originalSrc;
    }
    
    const url = new URL(originalSrc, window.location.origin);
    if (format === 'webp') {
      url.searchParams.set('format', 'webp');
    }
    if (width) {url.searchParams.set('w', width.toString());}
    if (height) {url.searchParams.set('h', height.toString());}
    
    return url.toString();
  }, [width, height]);

  useEffect(() => {
    if (!blurDataURL) {
      setImageSrc(src);
    }
  }, [src, blurDataURL]);

  const handleLoad = () => {
    setImageLoading(false);
    if (blurDataURL) {
      setImageSrc(src);
    }
  };

  const handleError = () => {
    setImageError(true);
    setImageLoading(false);
  };

  if (imageError) {
    return (
      <div 
        className={`bg-gray-200 dark:bg-gray-700 flex items-center justify-center ${className}`}
        style={{ width, height }}
      >
        <svg className="w-8 h-8 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M4 16l4.586-4.586a2 2 0 012.828 0L16 16m-2-2l1.586-1.586a2 2 0 012.828 0L20 14m-6-6h.01M6 20h12a2 2 0 002-2V6a2 2 0 00-2-2H6a2 2 0 00-2 2v12a2 2 0 002 2z" />
        </svg>
      </div>
    );
  }

  return (
    <picture className={className}>
      <source 
        srcSet={getOptimizedSrc(src, 'webp')} 
        type="image/webp"
        sizes={sizes}
      />
      <img
        src={imageSrc}
        alt={alt}
        width={width}
        height={height}
        loading={priority ? 'eager' : loading}
        className={`transition-opacity duration-300 ${imageLoading ? 'opacity-0' : 'opacity-100'}`}
        onLoad={handleLoad}
        onError={handleError}
        style={{
          filter: placeholder === 'blur' && imageLoading ? 'blur(8px)' : 'none',
        }}
      />
      {imageLoading && placeholder === 'empty' && (
        <div 
          className="absolute inset-0 bg-gray-200 dark:bg-gray-700 animate-pulse"
          style={{ width, height }}
        />
      )}
    </picture>
  );
};

// Virtual Scrolling Component for Large Lists
export const VirtualizedList: React.FC<{
  items: any[];
  itemHeight: number;
  containerHeight: number;
  renderItem: (item: any, index: number) => React.ReactNode;
  overscan?: number;
  className?: string;
}> = ({
  items,
  itemHeight,
  containerHeight,
  renderItem,
  overscan = 5,
  className = ''
}) => {
  const [scrollTop, setScrollTop] = useState(0);
  const [containerRef, setContainerRef] = useState<HTMLDivElement | null>(null);

  const totalHeight = items.length * itemHeight;
  const viewportHeight = containerHeight;
  
  const startIndex = Math.max(0, Math.floor(scrollTop / itemHeight) - overscan);
  const endIndex = Math.min(
    items.length - 1,
    Math.floor((scrollTop + viewportHeight) / itemHeight) + overscan
  );

  const visibleItems = items.slice(startIndex, endIndex + 1);

  const handleScroll = useCallback((e: React.UIEvent<HTMLDivElement>) => {
    setScrollTop(e.currentTarget.scrollTop);
  }, []);

  return (
    <div
      ref={setContainerRef}
      className={`overflow-auto ${className}`}
      style={{ height: containerHeight }}
      onScroll={handleScroll}
    >
      <div style={{ height: totalHeight, position: 'relative' }}>
        <div
          style={{
            transform: `translateY(${startIndex * itemHeight}px)`,
            position: 'absolute',
            top: 0,
            left: 0,
            right: 0,
          }}
        >
          {visibleItems.map((item, index) => (
            <div
              key={startIndex + index}
              style={{ height: itemHeight }}
            >
              {renderItem(item, startIndex + index)}
            </div>
          ))}
        </div>
      </div>
    </div>
  );
};

// Bundle Analysis Component
export const BundleAnalyzer: React.FC<{
  onAnalysisComplete?: (stats: BundleStats) => void;
}> = ({ onAnalysisComplete }) => {
  const [analysis, setAnalysis] = useState<BundleStats | null>(null);
  const [loading, setLoading] = useState(false);

  const analyzeBundles = useCallback(async () => {
    setLoading(true);
    try {
      // This would integrate with webpack-bundle-analyzer or similar
      const response = await fetch('/api/bundle-analysis');
      const stats = await response.json();
      setAnalysis(stats);
      onAnalysisComplete?.(stats);
    } catch (error) {
      console.error('Bundle analysis failed:', error);
    } finally {
      setLoading(false);
    }
  }, [onAnalysisComplete]);

  if (loading) {
    return <LoadingSpinner label="Analyzing bundles..." />;
  }

  if (!analysis) {
    return (
      <div className="p-4 border border-gray-200 dark:border-gray-700 rounded-lg">
        <h3 className="text-lg font-semibold mb-4">Bundle Analysis</h3>
        <button
          onClick={analyzeBundles}
          className="px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700"
        >
          Analyze Bundle Size
        </button>
      </div>
    );
  }

  return (
    <div className="p-4 border border-gray-200 dark:border-gray-700 rounded-lg space-y-4">
      <h3 className="text-lg font-semibold">Bundle Analysis Results</h3>
      
      <div className="grid grid-cols-2 gap-4">
        <div className="bg-blue-50 dark:bg-blue-900/20 p-3 rounded">
          <div className="text-sm text-blue-600 dark:text-blue-400">Total Size</div>
          <div className="text-xl font-bold">{(analysis.totalSize / 1024).toFixed(1)} KB</div>
        </div>
        
        <div className="bg-yellow-50 dark:bg-yellow-900/20 p-3 rounded">
          <div className="text-sm text-yellow-600 dark:text-yellow-400">Unused Code</div>
          <div className="text-xl font-bold">{(analysis.unusedCode / 1024).toFixed(1)} KB</div>
        </div>
      </div>

      <div>
        <h4 className="font-medium mb-2">Chunk Sizes</h4>
        <div className="space-y-1">
          {Object.entries(analysis.chunkSizes).map(([chunk, size]) => (
            <div key={chunk} className="flex justify-between text-sm">
              <span>{chunk}</span>
              <span>{(size / 1024).toFixed(1)} KB</span>
            </div>
          ))}
        </div>
      </div>

      {analysis.duplicateModules.length > 0 && (
        <div>
          <h4 className="font-medium mb-2 text-red-600">Duplicate Modules</h4>
          <ul className="text-sm space-y-1">
            {analysis.duplicateModules.map((module, index) => (
              <li key={index} className="text-red-500">{module}</li>
            ))}
          </ul>
        </div>
      )}
    </div>
  );
};

// Performance Monitoring Hook
export const usePerformanceMetrics = () => {
  const [metrics, setMetrics] = useState<PerformanceMetrics | null>(null);

  useEffect(() => {
    const observer = new PerformanceObserver((list) => {
      const entries = list.getEntries();
      
      entries.forEach((entry) => {
        if (entry.entryType === 'navigation') {
          const navEntry = entry as PerformanceNavigationTiming;
          setMetrics(prev => ({
            ...prev,
            loadTime: navEntry.loadEventEnd - navEntry.loadEventStart,
            firstContentfulPaint: 0, // Will be updated by paint entries
            largestContentfulPaint: 0, // Will be updated by LCP entries
            cumulativeLayoutShift: 0, // Will be updated by layout-shift entries
            firstInputDelay: 0, // Will be updated by first-input entries
            timeToInteractive: navEntry.domInteractive - navEntry.navigationStart
          } as PerformanceMetrics));
        }
        
        if (entry.entryType === 'paint' && entry.name === 'first-contentful-paint') {
          setMetrics(prev => prev ? { ...prev, firstContentfulPaint: entry.startTime } : null);
        }
        
        if (entry.entryType === 'largest-contentful-paint') {
          setMetrics(prev => prev ? { ...prev, largestContentfulPaint: entry.startTime } : null);
        }
        
        if (entry.entryType === 'layout-shift' && !(entry as any).hadRecentInput) {
          setMetrics(prev => prev ? { 
            ...prev, 
            cumulativeLayoutShift: prev.cumulativeLayoutShift + (entry as any).value 
          } : null);
        }
        
        if (entry.entryType === 'first-input') {
          setMetrics(prev => prev ? { 
            ...prev, 
            firstInputDelay: (entry as any).processingStart - entry.startTime 
          } : null);
        }
      });
    });

    observer.observe({ 
      entryTypes: ['navigation', 'paint', 'largest-contentful-paint', 'layout-shift', 'first-input'] 
    });

    return () => observer.disconnect();
  }, []);

  return metrics;
};

// Cache Management Utilities
export class CacheManager {
  private static instance: CacheManager;
  private cache: Map<string, { data: any; timestamp: number; ttl: number }> = new Map();

  static getInstance(): CacheManager {
    if (!CacheManager.instance) {
      CacheManager.instance = new CacheManager();
    }
    return CacheManager.instance;
  }

  set(key: string, data: any, ttl: number = 5 * 60 * 1000): void {
    this.cache.set(key, {
      data,
      timestamp: Date.now(),
      ttl
    });
  }

  get(key: string): any | null {
    const item = this.cache.get(key);
    if (!item) {return null;}

    if (Date.now() - item.timestamp > item.ttl) {
      this.cache.delete(key);
      return null;
    }

    return item.data;
  }

  clear(): void {
    this.cache.clear();
  }

  size(): number {
    return this.cache.size;
  }

  cleanup(): void {
    const now = Date.now();
    for (const [key, item] of this.cache.entries()) {
      if (now - item.timestamp > item.ttl) {
        this.cache.delete(key);
      }
    }
  }
}

// Resource Preloader
export class ResourcePreloader {
  private static loadedResources = new Set<string>();
  private static pendingResources = new Map<string, Promise<void>>();

  static preloadImage(src: string): Promise<void> {
    if (this.loadedResources.has(src)) {
      return Promise.resolve();
    }

    if (this.pendingResources.has(src)) {
      return this.pendingResources.get(src)!;
    }

    const promise = new Promise<void>((resolve, reject) => {
      const img = new Image();
      img.onload = () => {
        this.loadedResources.add(src);
        this.pendingResources.delete(src);
        resolve();
      };
      img.onerror = () => {
        this.pendingResources.delete(src);
        reject(new Error(`Failed to preload image: ${src}`));
      };
      img.src = src;
    });

    this.pendingResources.set(src, promise);
    return promise;
  }

  static preloadScript(src: string): Promise<void> {
    if (this.loadedResources.has(src)) {
      return Promise.resolve();
    }

    if (this.pendingResources.has(src)) {
      return this.pendingResources.get(src)!;
    }

    const promise = new Promise<void>((resolve, reject) => {
      const script = document.createElement('script');
      script.onload = () => {
        this.loadedResources.add(src);
        this.pendingResources.delete(src);
        resolve();
      };
      script.onerror = () => {
        this.pendingResources.delete(src);
        reject(new Error(`Failed to preload script: ${src}`));
      };
      script.src = src;
      document.head.appendChild(script);
    });

    this.pendingResources.set(src, promise);
    return promise;
  }

  static preloadFont(family: string, src: string, descriptors?: FontFaceDescriptors): Promise<void> {
    const key = `font-${family}`;
    
    if (this.loadedResources.has(key)) {
      return Promise.resolve();
    }

    if (this.pendingResources.has(key)) {
      return this.pendingResources.get(key)!;
    }

    const promise = new Promise<void>((resolve, reject) => {
      const font = new FontFace(family, `url(${src})`, descriptors);
      
      font.load().then(() => {
        document.fonts.add(font);
        this.loadedResources.add(key);
        this.pendingResources.delete(key);
        resolve();
      }).catch((error) => {
        this.pendingResources.delete(key);
        reject(error);
      });
    });

    this.pendingResources.set(key, promise);
    return promise;
  }
}

// Performance Metrics Display Component
export const PerformanceMetricsDisplay: React.FC = () => {
  const metrics = usePerformanceMetrics();

  if (!metrics) {
    return <Skeleton className="h-32" />;
  }

  const getScoreColor = (value: number, thresholds: { good: number; fair: number }) => {
    if (value <= thresholds.good) {return 'text-green-600';}
    if (value <= thresholds.fair) {return 'text-yellow-600';}
    return 'text-red-600';
  };

  return (
    <div className="grid grid-cols-2 md:grid-cols-3 gap-4 p-4">
      <div className="bg-white dark:bg-gray-800 p-3 rounded-lg border">
        <div className="text-sm text-gray-600 dark:text-gray-400">Load Time</div>
        <div className={`text-lg font-bold ${getScoreColor(metrics.loadTime, { good: 1500, fair: 3000 })}`}>
          {metrics.loadTime.toFixed(0)}ms
        </div>
      </div>

      <div className="bg-white dark:bg-gray-800 p-3 rounded-lg border">
        <div className="text-sm text-gray-600 dark:text-gray-400">FCP</div>
        <div className={`text-lg font-bold ${getScoreColor(metrics.firstContentfulPaint, { good: 1800, fair: 3000 })}`}>
          {metrics.firstContentfulPaint.toFixed(0)}ms
        </div>
      </div>

      <div className="bg-white dark:bg-gray-800 p-3 rounded-lg border">
        <div className="text-sm text-gray-600 dark:text-gray-400">LCP</div>
        <div className={`text-lg font-bold ${getScoreColor(metrics.largestContentfulPaint, { good: 2500, fair: 4000 })}`}>
          {metrics.largestContentfulPaint.toFixed(0)}ms
        </div>
      </div>

      <div className="bg-white dark:bg-gray-800 p-3 rounded-lg border">
        <div className="text-sm text-gray-600 dark:text-gray-400">CLS</div>
        <div className={`text-lg font-bold ${getScoreColor(metrics.cumulativeLayoutShift, { good: 0.1, fair: 0.25 })}`}>
          {metrics.cumulativeLayoutShift.toFixed(3)}
        </div>
      </div>

      <div className="bg-white dark:bg-gray-800 p-3 rounded-lg border">
        <div className="text-sm text-gray-600 dark:text-gray-400">FID</div>
        <div className={`text-lg font-bold ${getScoreColor(metrics.firstInputDelay, { good: 100, fair: 300 })}`}>
          {metrics.firstInputDelay.toFixed(0)}ms
        </div>
      </div>

      <div className="bg-white dark:bg-gray-800 p-3 rounded-lg border">
        <div className="text-sm text-gray-600 dark:text-gray-400">TTI</div>
        <div className={`text-lg font-bold ${getScoreColor(metrics.timeToInteractive, { good: 3800, fair: 7300 })}`}>
          {metrics.timeToInteractive.toFixed(0)}ms
        </div>
      </div>
    </div>
  );
};