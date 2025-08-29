'use client'

import { useEffect } from 'react'

import { performanceMonitor } from './performance'

export function PerformanceScript() {
  useEffect(() => {
    if (typeof window !== 'undefined' && process.env.NODE_ENV === 'development') {
      // Initialize performance monitoring
      performanceMonitor.logCoreWebVitals()
      
      // Report metrics periodically in development
      const interval = setInterval(() => {
        performanceMonitor.reportPerformanceMetrics()
      }, 30000) // Every 30 seconds

      // Cleanup
      return () => clearInterval(interval)
    }
  }, [])

  return null // This component doesn't render anything
}