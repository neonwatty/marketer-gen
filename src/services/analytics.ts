/**
 * Analytics service for tracking user interactions and events
 */
class AnalyticsService {
  private isInitialized = false
  
  private get isDevelopment(): boolean {
    return process.env.NODE_ENV === 'development'
  }

  /**
   * Initialize analytics service
   */
  init(): void {
    if (typeof window === 'undefined' || !window) return
    if (this.isInitialized) return

    // Initialize analytics providers here (Google Analytics, PostHog, etc.)
    if (process.env.NEXT_PUBLIC_GOOGLE_ANALYTICS_ID) {
      this.initGoogleAnalytics()
    }

    if (process.env.NEXT_PUBLIC_POSTHOG_KEY) {
      this.initPostHog()
    }

    this.isInitialized = true
  }

  /**
   * Track page view
   */
  trackPageView(url: string, title?: string): void {
    if (this.isDevelopment) {
      console.log('Analytics: Page view', { url, title })
    }
    
    if (!this.isInitialized) {
      return
    }

    // Google Analytics
    if (typeof window !== 'undefined' && (window as any).gtag) {
      ;(window as any).gtag('config', process.env.NEXT_PUBLIC_GOOGLE_ANALYTICS_ID, {
        page_title: title,
        page_location: url,
      })
    }

    // PostHog
    if (typeof window !== 'undefined' && (window as any).posthog) {
      ;(window as any).posthog.capture('$pageview', {
        $current_url: url,
        title,
      })
    }
  }

  /**
   * Track custom event
   */
  trackEvent(
    eventName: string,
    properties?: Record<string, any>,
    options?: { category?: string; label?: string; value?: number }
  ): void {
    if (this.isDevelopment) {
      console.log('Analytics: Event', { event: eventName, data: properties })
    }
    
    if (!this.isInitialized) {
      return
    }

    // Google Analytics
    if (typeof window !== 'undefined' && (window as any).gtag) {
      ;(window as any).gtag('event', eventName, {
        event_category: options?.category,
        event_label: options?.label,
        value: options?.value,
        custom_parameters: properties,
      })
    }

    // PostHog
    if (typeof window !== 'undefined' && (window as any).posthog) {
      ;(window as any).posthog.capture(eventName, properties)
    }
  }

  /**
   * Track user identification
   */
  identifyUser(userId: string, userProperties?: Record<string, any>): void {
    if (this.isDevelopment) {
      console.log('Analytics: Identify', { userId, properties: userProperties })
    }
    
    if (!this.isInitialized) {
      return
    }

    // Google Analytics
    if (typeof window !== 'undefined' && (window as any).gtag) {
      ;(window as any).gtag('config', process.env.NEXT_PUBLIC_GOOGLE_ANALYTICS_ID, {
        user_id: userId,
        custom_map: userProperties,
      })
    }

    // PostHog
    if (typeof window !== 'undefined' && (window as any).posthog) {
      ;(window as any).posthog.identify(userId, userProperties)
    }
  }

  /**
   * Alias for identifyUser for compatibility
   */
  identify(userId: string, userProperties?: Record<string, any>): void {
    return this.identifyUser(userId, userProperties)
  }

  /**
   * Track conversion/goal
   */
  trackConversion(goalId: string, value?: number): void {
    if (!this.isInitialized || this.isDevelopment) {
      console.log('Analytics: Conversion', { goalId, value })
      return
    }

    // Google Analytics
    if (typeof window !== 'undefined' && (window as any).gtag) {
      ;(window as any).gtag('event', 'conversion', {
        send_to: goalId,
        value,
        currency: 'USD',
      })
    }

    // PostHog
    if (typeof window !== 'undefined' && (window as any).posthog) {
      ;(window as any).posthog.capture('conversion', {
        goal_id: goalId,
        value,
      })
    }
  }

  /**
   * Track error
   */
  trackError(error: Error, context?: Record<string, any>): void {
    if (!this.isInitialized || this.isDevelopment) {
      console.log('Analytics: Error', { error: error.message, context })
      return
    }

    // Google Analytics
    if (typeof window !== 'undefined' && (window as any).gtag) {
      ;(window as any).gtag('event', 'exception', {
        description: error.message,
        fatal: false,
        custom_parameters: context,
      })
    }

    // PostHog
    if (typeof window !== 'undefined' && (window as any).posthog) {
      ;(window as any).posthog.capture('error', {
        error_message: error.message,
        error_stack: error.stack,
        ...context,
      })
    }
  }

  /**
   * Track timing
   */
  trackTiming(category: string, variable: string, value: number, label?: string): void {
    if (!this.isInitialized || this.isDevelopment) {
      console.log('Analytics: Timing', { category, variable, value, label })
      return
    }

    // Google Analytics
    if (typeof window !== 'undefined' && (window as any).gtag) {
      ;(window as any).gtag('event', 'timing_complete', {
        name: variable,
        value: value,
        event_category: category,
        event_label: label,
      })
    }

    // PostHog
    if (typeof window !== 'undefined' && (window as any).posthog) {
      ;(window as any).posthog.capture('timing', {
        category,
        variable,
        value,
        label,
      })
    }
  }

  /**
   * Initialize Google Analytics
   */
  private initGoogleAnalytics(): void {
    if (typeof window === 'undefined') return

    // Load Google Analytics script
    const script = document.createElement('script')
    script.async = true
    script.src = `https://www.googletagmanager.com/gtag/js?id=${process.env.NEXT_PUBLIC_GOOGLE_ANALYTICS_ID}`
    document.head.appendChild(script)

    // Initialize gtag
    ;(window as any).dataLayer = (window as any).dataLayer || []
    ;(window as any).gtag = function (...args: any[]) {
      ;(window as any).dataLayer.push(args)
    }
    ;(window as any).gtag('js', new Date())
    ;(window as any).gtag('config', process.env.NEXT_PUBLIC_GOOGLE_ANALYTICS_ID)
  }

  /**
   * Initialize PostHog
   */
  private initPostHog(): void {
    if (typeof window === 'undefined') return

    // Load PostHog script
    const script = document.createElement('script')
    script.innerHTML = `
      !function(t,e){var o,n,p,r;e.__SV||(window.posthog=e,e._i=[],e.init=function(i,s,a){function g(t,e){var o=e.split(".");2==o.length&&(t=t[o[0]],e=o[1]);var n=t;return function(){var t=Array.prototype.slice.call(arguments,0);n.apply(t,arguments)}}(p=t.createElement("script")).type="text/javascript",p.async=!0,p.src=s.api_host+"/static/array.js",(r=t.getElementsByTagName("script")[0]).parentNode.insertBefore(p,r);var u=e;for(void 0!==a?u=e[a]=[]:a="posthog",u.people=u.people||[],u.toString=function(t){var e="posthog";return"posthog"!==a&&(e+="."+a),t||(e+=" (stub)"),e},u.people.toString=function(){return u.toString(1)+".people (stub)"},o="capture identify alias people.set people.set_once set_config register register_once unregister opt_out_capturing has_opted_out_capturing opt_in_capturing reset isFeatureEnabled onFeatureFlags getFeatureFlag getFeatureFlagPayload reloadFeatureFlags group updateEarlyAccessFeatureEnrollment getEarlyAccessFeatures getActiveMatchingSurveys getSurveys onSessionId".split(" "),n=0;n<o.length;n++)g(u,o[n]);e._i.push([i,s,a])},e.__SV=1)}(document,window.posthog||[]);
      posthog.init('${process.env.NEXT_PUBLIC_POSTHOG_KEY}',{api_host:'${process.env.NEXT_PUBLIC_POSTHOG_HOST || 'https://app.posthog.com'}'})
    `
    document.head.appendChild(script)
  }

  /**
   * Reset analytics (for logout, etc.)
   */
  reset(): void {
    if (this.isDevelopment) {
      console.log('Analytics: Reset')
    }
    
    if (!this.isInitialized) {
      return
    }

    // PostHog
    if (typeof window !== 'undefined' && (window as any).posthog) {
      ;(window as any).posthog.reset()
    }
  }

  /**
   * Set user properties
   */
  setUserProperties(properties: Record<string, any>): void {
    if (!this.isInitialized || this.isDevelopment) {
      console.log('Analytics: Set user properties', properties)
      return
    }

    // PostHog
    if (typeof window !== 'undefined' && (window as any).posthog) {
      ;(window as any).posthog.people.set(properties)
    }
  }

  /**
   * Reset initialization state (for testing purposes)
   */
  resetForTesting(): void {
    this.isInitialized = false
  }
}

export const analyticsService = new AnalyticsService()
