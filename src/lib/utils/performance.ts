export class PerformanceMonitor {
  private static instance: PerformanceMonitor
  private metrics: Map<string, number> = new Map()

  private constructor() {}

  static getInstance(): PerformanceMonitor {
    if (!PerformanceMonitor.instance) {
      PerformanceMonitor.instance = new PerformanceMonitor()
    }
    return PerformanceMonitor.instance
  }

  startTiming(label: string): void {
    this.metrics.set(`${label}_start`, performance.now())
  }

  endTiming(label: string): number | null {
    const startTime = this.metrics.get(`${label}_start`)
    if (startTime) {
      const duration = performance.now() - startTime
      this.metrics.set(label, duration)
      this.metrics.delete(`${label}_start`)
      return duration
    }
    return null
  }

  getMetric(label: string): number | undefined {
    return this.metrics.get(label)
  }

  getAllMetrics(): Record<string, number> {
    return Object.fromEntries(this.metrics)
  }

  clearMetrics(): void {
    this.metrics.clear()
  }

  logCoreWebVitals(): void {
    if (typeof window === 'undefined') return

    // Observe and log Core Web Vitals
    const observer = new PerformanceObserver((list) => {
      list.getEntries().forEach((entry) => {
        if (entry.entryType === 'navigation') {
          const navEntry = entry as PerformanceNavigationTiming
          console.log('Navigation Timing:', {
            domContentLoaded: navEntry.domContentLoadedEventEnd - navEntry.domContentLoadedEventStart,
            load: navEntry.loadEventEnd - navEntry.loadEventStart,
            firstPaint: navEntry.responseEnd - navEntry.requestStart,
          })
        }
        
        if (entry.entryType === 'paint') {
          console.log(`${entry.name}: ${entry.startTime}ms`)
        }
      })
    })

    observer.observe({ entryTypes: ['navigation', 'paint'] })

    // Monitor additional performance entries
    if ('PerformanceObserver' in window) {
      const vitalsObserver = new PerformanceObserver((list) => {
        list.getEntries().forEach((entry) => {
          if (entry.entryType === 'largest-contentful-paint') {
            console.log('LCP:', entry.startTime)
            this.metrics.set('lcp', entry.startTime)
          }
          if (entry.entryType === 'first-input') {
            const fidEntry = entry as PerformanceEventTiming
            console.log('FID:', fidEntry.processingStart - fidEntry.startTime)
            this.metrics.set('fid', fidEntry.processingStart - fidEntry.startTime)
          }
          if (entry.entryType === 'layout-shift' && !(entry as any).hadRecentInput) {
            console.log('CLS:', (entry as any).value)
            this.metrics.set('cls', (entry as any).value)
          }
        })
      })
      
      try {
        vitalsObserver.observe({ entryTypes: ['largest-contentful-paint', 'first-input', 'layout-shift'] })
      } catch (e) {
        console.log('Some performance metrics not supported')
      }
    }
  }

  reportPerformanceMetrics(): void {
    if (typeof window === 'undefined' || process.env.NODE_ENV === 'production') return

    const metrics = this.getAllMetrics()
    if (Object.keys(metrics).length > 0) {
      console.table(metrics)
    }
  }
}

export const performanceMonitor = PerformanceMonitor.getInstance()

// Hook for React components
export function usePerformanceMonitor() {
  return {
    startTiming: (label: string) => performanceMonitor.startTiming(label),
    endTiming: (label: string) => performanceMonitor.endTiming(label),
    getMetric: (label: string) => performanceMonitor.getMetric(label),
    reportMetrics: () => performanceMonitor.reportPerformanceMetrics(),
  }
}