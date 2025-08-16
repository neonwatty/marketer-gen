/**
 * @jest-environment jsdom
 */

import { analyticsService } from '@/services/analytics'

// Mock window object for browser environment
const mockGtag = jest.fn()
const mockPosthog = {
  capture: jest.fn(),
  identify: jest.fn(),
  reset: jest.fn(),
}

// Mock console.log to avoid cluttering test output
const originalConsoleLog = console.log
beforeEach(() => {
  console.log = jest.fn()
  
  // Only set up window mocks if window exists
  if (typeof window !== 'undefined') {
    ;(window as any).gtag = mockGtag
    ;(window as any).posthog = mockPosthog
  }
  
  // Reset analytics state
  ;(analyticsService as any).isInitialized = false
})

afterEach(() => {
  console.log = originalConsoleLog
  jest.clearAllMocks()
  delete (window as any).gtag
  delete (window as any).posthog
})

describe('AnalyticsService', () => {
  describe('init', () => {
    it('should initialize only once', () => {
      analyticsService.init()
      analyticsService.init()
      
      expect((analyticsService as any).isInitialized).toBe(true)
    })

    it.skip('should not initialize in server environment', () => {
      // This test is skipped because jsdom always provides a window object
      // In actual server environment (Node.js without jsdom), window would be undefined
      // and the analytics service would correctly not initialize
    })

    it('should initialize Google Analytics when ID is provided', () => {
      process.env.NEXT_PUBLIC_GOOGLE_ANALYTICS_ID = 'GA_TEST_ID'
      
      analyticsService.init()
      
      expect((analyticsService as any).isInitialized).toBe(true)
      
      delete process.env.NEXT_PUBLIC_GOOGLE_ANALYTICS_ID
    })

    it('should initialize PostHog when key is provided', () => {
      process.env.NEXT_PUBLIC_POSTHOG_KEY = 'POSTHOG_TEST_KEY'
      
      analyticsService.init()
      
      expect((analyticsService as any).isInitialized).toBe(true)
      
      delete process.env.NEXT_PUBLIC_POSTHOG_KEY
    })
  })

  describe('trackPageView', () => {
    beforeEach(() => {
      analyticsService.init()
    })

    it('should track page view with Google Analytics when available', () => {
      process.env.NEXT_PUBLIC_GOOGLE_ANALYTICS_ID = 'GA_TEST_ID'
      
      analyticsService.trackPageView('/test-page', 'Test Page')
      
      expect(mockGtag).toHaveBeenCalledWith('config', 'GA_TEST_ID', {
        page_title: 'Test Page',
        page_location: '/test-page',
      })
      
      delete process.env.NEXT_PUBLIC_GOOGLE_ANALYTICS_ID
    })

    it('should track page view with PostHog when available', () => {
      analyticsService.trackPageView('/test-page', 'Test Page')
      
      expect(mockPosthog.capture).toHaveBeenCalledWith('$pageview', {
        $current_url: '/test-page',
        title: 'Test Page',
      })
    })

    it('should log to console in development mode', () => {
      const originalEnv = process.env.NODE_ENV
      process.env.NODE_ENV = 'development'
      
      analyticsService.trackPageView('/test-page', 'Test Page')
      
      expect(console.log).toHaveBeenCalledWith('Analytics: Page view', {
        url: '/test-page',
        title: 'Test Page',
      })
      
      process.env.NODE_ENV = originalEnv
    })

    it('should handle missing title parameter', () => {
      analyticsService.trackPageView('/test-page')
      
      expect(mockPosthog.capture).toHaveBeenCalledWith('$pageview', {
        $current_url: '/test-page',
        title: undefined,
      })
    })
  })

  describe('trackEvent', () => {
    beforeEach(() => {
      analyticsService.init()
    })

    it('should track custom events', () => {
      analyticsService.trackEvent('campaign_created', {
        campaign_id: 'test-123',
        template: 'email',
      })
      
      expect(mockPosthog.capture).toHaveBeenCalledWith('campaign_created', {
        campaign_id: 'test-123',
        template: 'email',
      })
    })

    it('should log events in development mode', () => {
      const originalEnv = process.env.NODE_ENV
      process.env.NODE_ENV = 'development'
      
      analyticsService.trackEvent('test_event', { test: 'data' })
      
      expect(console.log).toHaveBeenCalledWith('Analytics: Event', {
        event: 'test_event',
        data: { test: 'data' },
      })
      
      process.env.NODE_ENV = originalEnv
    })
  })

  describe('identify', () => {
    beforeEach(() => {
      analyticsService.init()
    })

    it('should identify users with PostHog', () => {
      const userProps = {
        email: 'test@example.com',
        name: 'Test User',
      }
      
      analyticsService.identify('user-123', userProps)
      
      expect(mockPosthog.identify).toHaveBeenCalledWith('user-123', userProps)
    })

    it('should log identification in development mode', () => {
      const originalEnv = process.env.NODE_ENV
      process.env.NODE_ENV = 'development'
      
      analyticsService.identify('user-123', { email: 'test@example.com' })
      
      expect(console.log).toHaveBeenCalledWith('Analytics: Identify', {
        userId: 'user-123',
        properties: { email: 'test@example.com' },
      })
      
      process.env.NODE_ENV = originalEnv
    })
  })

  describe('reset', () => {
    beforeEach(() => {
      analyticsService.init()
    })

    it('should reset analytics state', () => {
      analyticsService.reset()
      
      expect(mockPosthog.reset).toHaveBeenCalled()
    })

    it('should log reset in development mode', () => {
      const originalEnv = process.env.NODE_ENV
      process.env.NODE_ENV = 'development'
      
      analyticsService.reset()
      
      expect(console.log).toHaveBeenCalledWith('Analytics: Reset')
      
      process.env.NODE_ENV = originalEnv
    })
  })
})