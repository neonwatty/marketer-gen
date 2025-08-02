import { createConsumer } from "@rails/actioncable"

/**
 * WebSocket utility class for brand compliance real-time features
 * Provides a unified interface for all brand compliance WebSocket operations
 */
export class BrandComplianceWebSocket {
  constructor(brandId, options = {}) {
    this.brandId = brandId
    this.options = {
      sessionId: options.sessionId || this.generateSessionId(),
      autoReconnect: options.autoReconnect !== false,
      reconnectAttempts: options.reconnectAttempts || 5,
      reconnectInterval: options.reconnectInterval || 3000,
      ...options
    }
    
    this.subscriptions = new Map()
    this.eventHandlers = new Map()
    this.reconnectCount = 0
    this.isConnected = false
    
    this.initializeConsumer()
  }

  initializeConsumer() {
    try {
      this.consumer = createConsumer()
      this.setupGlobalEventHandlers()
    } catch (error) {
      console.error('Failed to initialize WebSocket consumer:', error)
      this.handleConnectionError(error)
    }
  }

  setupGlobalEventHandlers() {
    // Handle connection events
    this.consumer.connection.addEventListener('connect', () => {
      this.isConnected = true
      this.reconnectCount = 0
      this.triggerEvent('global:connected')
    })

    this.consumer.connection.addEventListener('disconnect', () => {
      this.isConnected = false
      this.triggerEvent('global:disconnected')
      
      if (this.options.autoReconnect) {
        this.attemptReconnection()
      }
    })

    this.consumer.connection.addEventListener('error', (event) => {
      this.handleConnectionError(event.detail)
    })
  }

  /**
   * Subscribe to brand compliance channel
   * @param {Object} options - Subscription options
   * @returns {Object} Subscription object
   */
  subscribeToBrandCompliance(options = {}) {
    const channelData = {
      channel: "BrandComplianceChannel",
      brand_id: this.brandId,
      session_id: this.options.sessionId,
      ...options
    }

    const subscription = this.consumer.subscriptions.create(channelData, {
      connected: () => {
        this.triggerEvent('compliance:connected', { channelData })
      },
      
      disconnected: () => {
        this.triggerEvent('compliance:disconnected', { channelData })
      },
      
      received: (data) => {
        this.handleComplianceMessage(data)
      },
      
      rejected: () => {
        console.error('Brand compliance subscription rejected')
        this.triggerEvent('compliance:rejected', { channelData })
      }
    })

    this.subscriptions.set('brand_compliance', subscription)
    return subscription
  }

  /**
   * Subscribe to brand analysis channel
   * @param {Object} options - Subscription options
   * @returns {Object} Subscription object
   */
  subscribeToBrandAnalysis(options = {}) {
    const channelData = {
      channel: "BrandAnalysisChannel", 
      brand_id: this.brandId,
      ...options
    }

    const subscription = this.consumer.subscriptions.create(channelData, {
      connected: () => {
        this.triggerEvent('analysis:connected', { channelData })
      },
      
      disconnected: () => {
        this.triggerEvent('analysis:disconnected', { channelData })
      },
      
      received: (data) => {
        this.handleAnalysisMessage(data)
      },
      
      rejected: () => {
        console.error('Brand analysis subscription rejected')
        this.triggerEvent('analysis:rejected', { channelData })
      }
    })

    this.subscriptions.set('brand_analysis', subscription)
    return subscription
  }

  /**
   * Subscribe to messaging framework channel
   * @param {Number} frameworkId - Framework ID
   * @param {Object} options - Subscription options
   * @returns {Object} Subscription object
   */
  subscribeToMessagingFramework(frameworkId, options = {}) {
    const channelData = {
      channel: "MessagingFrameworkChannel",
      brand_id: this.brandId,
      framework_id: frameworkId,
      ...options
    }

    const subscription = this.consumer.subscriptions.create(channelData, {
      connected: () => {
        this.triggerEvent('messaging:connected', { channelData })
      },
      
      disconnected: () => {
        this.triggerEvent('messaging:disconnected', { channelData })
      },
      
      received: (data) => {
        this.handleMessagingMessage(data)
      },
      
      rejected: () => {
        console.error('Messaging framework subscription rejected')
        this.triggerEvent('messaging:rejected', { channelData })
      }
    })

    this.subscriptions.set('messaging_framework', subscription)
    return subscription
  }

  /**
   * Subscribe to brand asset processing channel
   * @param {Object} options - Subscription options
   * @returns {Object} Subscription object
   */
  subscribeToBrandAssetProcessing(options = {}) {
    const channelData = {
      channel: "BrandAssetProcessingChannel",
      brand_id: this.brandId,
      ...options
    }

    const subscription = this.consumer.subscriptions.create(channelData, {
      connected: () => {
        this.triggerEvent('asset_processing:connected', { channelData })
      },
      
      disconnected: () => {
        this.triggerEvent('asset_processing:disconnected', { channelData })
      },
      
      received: (data) => {
        this.handleAssetProcessingMessage(data)
      },
      
      rejected: () => {
        console.error('Brand asset processing subscription rejected')
        this.triggerEvent('asset_processing:rejected', { channelData })
      }
    })

    this.subscriptions.set('brand_asset_processing', subscription)
    return subscription
  }

  // Message Handlers
  handleComplianceMessage(data) {
    const eventType = `compliance:${data.event}`
    this.triggerEvent(eventType, data)

    // Handle specific compliance events
    switch (data.event) {
      case 'check_complete':
        this.triggerEvent('compliance:results', data.results)
        break
      case 'violation_detected':
        this.triggerEvent('compliance:violation', data.violation)
        break
      case 'suggestion_generated':
        this.triggerEvent('compliance:suggestion', data.suggestion)
        break
      case 'score_updated':
        this.triggerEvent('compliance:score', data.score)
        break
    }
  }

  handleAnalysisMessage(data) {
    const eventType = `analysis:${data.event}`
    this.triggerEvent(eventType, data)

    // Handle specific analysis events
    switch (data.event) {
      case 'analysis_complete':
        this.triggerEvent('analysis:results', data.results)
        break
      case 'progress_update':
        this.triggerEvent('analysis:progress', data.progress)
        break
      case 'confidence_updated':
        this.triggerEvent('analysis:confidence', data.confidence)
        break
    }
  }

  handleMessagingMessage(data) {
    const eventType = `messaging:${data.event}`
    this.triggerEvent(eventType, data)

    // Handle specific messaging events
    switch (data.event) {
      case 'validation_complete':
        this.triggerEvent('messaging:validation', data.results)
        break
      case 'framework_updated':
        this.triggerEvent('messaging:updated', data.framework)
        break
      case 'suggestion_generated':
        this.triggerEvent('messaging:suggestion', data.suggestion)
        break
    }
  }

  handleAssetProcessingMessage(data) {
    const eventType = `asset_processing:${data.event}`
    this.triggerEvent(eventType, data)

    // Handle specific asset processing events
    switch (data.event) {
      case 'processing_complete':
        this.triggerEvent('asset_processing:complete', data.asset)
        break
      case 'processing_progress':
        this.triggerEvent('asset_processing:progress', data.progress)
        break
      case 'analysis_complete':
        this.triggerEvent('asset_processing:analysis', data.analysis)
        break
    }
  }

  // Channel Actions
  /**
   * Check compliance via WebSocket
   * @param {string} content - Content to check
   * @param {Object} options - Check options
   */
  checkCompliance(content, options = {}) {
    const subscription = this.subscriptions.get('brand_compliance')
    if (!subscription) {
      throw new Error('Brand compliance subscription not found. Call subscribeToBrandCompliance() first.')
    }

    subscription.perform('check_compliance', {
      content,
      content_type: options.contentType || 'general',
      compliance_level: options.complianceLevel || 'standard',
      generate_suggestions: options.generateSuggestions !== false,
      async: options.async !== false,
      ...options
    })
  }

  /**
   * Validate specific aspect
   * @param {string} aspect - Aspect to validate
   * @param {string} content - Content to validate
   */
  validateAspect(aspect, content) {
    const subscription = this.subscriptions.get('brand_compliance')
    if (!subscription) {
      throw new Error('Brand compliance subscription not found.')
    }

    subscription.perform('validate_aspect', {
      aspect,
      content
    })
  }

  /**
   * Get suggestions for violations
   * @param {Array} violationIds - Array of violation IDs
   */
  getSuggestions(violationIds) {
    const subscription = this.subscriptions.get('brand_compliance')
    if (!subscription) {
      throw new Error('Brand compliance subscription not found.')
    }

    subscription.perform('get_suggestions', {
      violation_ids: violationIds
    })
  }

  /**
   * Preview fix for violation
   * @param {string} violationId - Violation ID
   * @param {string} content - Content to fix
   */
  previewFix(violationId, content) {
    const subscription = this.subscriptions.get('brand_compliance')
    if (!subscription) {
      throw new Error('Brand compliance subscription not found.')
    }

    subscription.perform('preview_fix', {
      violation_id: violationId,
      content
    })
  }

  /**
   * Trigger brand analysis
   * @param {Object} options - Analysis options
   */
  triggerAnalysis(options = {}) {
    const subscription = this.subscriptions.get('brand_analysis')
    if (!subscription) {
      throw new Error('Brand analysis subscription not found.')
    }

    subscription.perform('trigger_analysis', {
      brand_id: this.brandId,
      force_refresh: options.forceRefresh || false,
      asset_ids: options.assetIds,
      ...options
    })
  }

  /**
   * Validate messaging framework content
   * @param {string} content - Content to validate
   * @param {Object} options - Validation options
   */
  validateMessagingContent(content, options = {}) {
    const subscription = this.subscriptions.get('messaging_framework')
    if (!subscription) {
      throw new Error('Messaging framework subscription not found.')
    }

    subscription.perform('validate_content', {
      content,
      field_type: options.fieldType || 'general',
      validation_type: options.validationType || 'comprehensive'
    })
  }

  // Event System
  /**
   * Add event listener
   * @param {string} eventType - Event type to listen for
   * @param {Function} handler - Event handler function
   */
  on(eventType, handler) {
    if (!this.eventHandlers.has(eventType)) {
      this.eventHandlers.set(eventType, [])
    }
    this.eventHandlers.get(eventType).push(handler)
  }

  /**
   * Remove event listener
   * @param {string} eventType - Event type
   * @param {Function} handler - Handler to remove
   */
  off(eventType, handler) {
    const handlers = this.eventHandlers.get(eventType)
    if (handlers) {
      const index = handlers.indexOf(handler)
      if (index > -1) {
        handlers.splice(index, 1)
      }
    }
  }

  /**
   * Trigger event
   * @param {string} eventType - Event type
   * @param {*} data - Event data
   */
  triggerEvent(eventType, data = null) {
    const handlers = this.eventHandlers.get(eventType) || []
    handlers.forEach(handler => {
      try {
        handler(data, eventType)
      } catch (error) {
        console.error(`Error in event handler for ${eventType}:`, error)
      }
    })
  }

  // Connection Management
  attemptReconnection() {
    if (this.reconnectCount >= this.options.reconnectAttempts) {
      console.error('Max reconnection attempts reached')
      this.triggerEvent('global:reconnect_failed')
      return
    }

    setTimeout(() => {
      this.reconnectCount++
      console.log(`Attempting reconnection ${this.reconnectCount}/${this.options.reconnectAttempts}`)
      
      try {
        this.consumer.connection.reconnect()
        this.triggerEvent('global:reconnect_attempt', { attempt: this.reconnectCount })
      } catch (error) {
        console.error('Reconnection attempt failed:', error)
        this.attemptReconnection()
      }
    }, this.options.reconnectInterval)
  }

  handleConnectionError(error) {
    console.error('WebSocket connection error:', error)
    this.triggerEvent('global:error', error)
  }

  // Utility Methods
  /**
   * Get connection status
   * @returns {boolean} Connection status
   */
  isWebSocketConnected() {
    return this.isConnected && this.consumer?.connection?.isOpen()
  }

  /**
   * Get all active subscriptions
   * @returns {Map} Active subscriptions
   */
  getActiveSubscriptions() {
    return new Map(this.subscriptions)
  }

  /**
   * Unsubscribe from a specific channel
   * @param {string} channelName - Channel name to unsubscribe from
   */
  unsubscribe(channelName) {
    const subscription = this.subscriptions.get(channelName)
    if (subscription) {
      subscription.unsubscribe()
      this.subscriptions.delete(channelName)
      this.triggerEvent(`${channelName}:unsubscribed`)
    }
  }

  /**
   * Unsubscribe from all channels and disconnect
   */
  disconnect() {
    // Unsubscribe from all channels
    this.subscriptions.forEach((subscription, channelName) => {
      subscription.unsubscribe()
      this.triggerEvent(`${channelName}:unsubscribed`)
    })
    
    this.subscriptions.clear()
    
    // Disconnect consumer
    if (this.consumer) {
      this.consumer.disconnect()
    }
    
    // Clear event handlers
    this.eventHandlers.clear()
    
    this.triggerEvent('global:disconnected')
  }

  /**
   * Generate unique session ID
   * @returns {string} Session ID
   */
  generateSessionId() {
    return `brand_ws_${  Date.now()  }_${  Math.random().toString(36).substr(2, 9)}`
  }

  /**
   * Get current session ID
   * @returns {string} Session ID
   */
  getSessionId() {
    return this.options.sessionId
  }

  /**
   * Update session ID
   * @param {string} sessionId - New session ID
   */
  setSessionId(sessionId) {
    this.options.sessionId = sessionId
  }
}

/**
 * Factory function to create BrandComplianceWebSocket instance
 * @param {Number} brandId - Brand ID
 * @param {Object} options - Options
 * @returns {BrandComplianceWebSocket} WebSocket instance
 */
export function createBrandComplianceWebSocket(brandId, options = {}) {
  return new BrandComplianceWebSocket(brandId, options)
}

/**
 * Singleton instance manager for global access
 */
class WebSocketManager {
  constructor() {
    this.instances = new Map()
  }

  /**
   * Get or create WebSocket instance for brand
   * @param {Number} brandId - Brand ID
   * @param {Object} options - Options
   * @returns {BrandComplianceWebSocket} WebSocket instance
   */
  getInstance(brandId, options = {}) {
    if (!this.instances.has(brandId)) {
      this.instances.set(brandId, new BrandComplianceWebSocket(brandId, options))
    }
    return this.instances.get(brandId)
  }

  /**
   * Remove instance for brand
   * @param {Number} brandId - Brand ID
   */
  removeInstance(brandId) {
    const instance = this.instances.get(brandId)
    if (instance) {
      instance.disconnect()
      this.instances.delete(brandId)
    }
  }

  /**
   * Get all active instances
   * @returns {Map} Active instances
   */
  getAllInstances() {
    return new Map(this.instances)
  }

  /**
   * Disconnect all instances
   */
  disconnectAll() {
    this.instances.forEach((instance) => {
      instance.disconnect()
    })
    this.instances.clear()
  }
}

// Export singleton manager
export const webSocketManager = new WebSocketManager()

// Export default for easy import
export default BrandComplianceWebSocket