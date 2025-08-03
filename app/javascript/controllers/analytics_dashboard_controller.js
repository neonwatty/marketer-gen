import { Controller } from "@hotwired/stimulus";
import React from "react";
import { createRoot } from "react-dom/client";
import AnalyticsDashboard from "../components/AnalyticsDashboard";

// Connects to data-controller="analytics-dashboard"
export default class extends Controller {
  static targets = ["container"];
  static values = { 
    brandId: String, 
    userId: String, 
    initialMetrics: Object,
    autoRefresh: Boolean,
    refreshInterval: Number
  };

  connect() {
    console.log("Analytics Dashboard controller connected");
    this.initializeReactComponent();
    this.initializeAccessibility();
    this.initializePerformanceMonitoring();
    
    if (this.autoRefreshValue) {
      this.startAutoRefresh();
    }
  }

  disconnect() {
    console.log("Analytics Dashboard controller disconnected");
    this.cleanup();
  }

  initializeReactComponent() {
    if (!this.containerTarget) {
      console.error("Container target not found for Analytics Dashboard");
      return;
    }

    // Create React root and render component
    this.root = createRoot(this.containerTarget);
    this.root.render(
      React.createElement(AnalyticsDashboard, {
        brandId: this.brandIdValue,
        userId: this.userIdValue,
        initialMetrics: this.initialMetricsValue
      })
    );

    // Set loading state
    this.setLoadingState(false);
  }

  // Handle brand selection change
  brandIdValueChanged() {
    if (this.root) {
      this.root.render(
        React.createElement(AnalyticsDashboard, {
          brandId: this.brandIdValue,
          userId: this.userIdValue,
          initialMetrics: this.initialMetricsValue
        })
      );
    }
  }

  // Start auto-refresh if enabled
  startAutoRefresh() {
    const interval = this.refreshIntervalValue || 30000; // Default 30 seconds
    
    this.refreshTimer = setInterval(() => {
      this.refreshData();
    }, interval);
  }

  // Stop auto-refresh
  stopAutoRefresh() {
    if (this.refreshTimer) {
      clearInterval(this.refreshTimer);
      this.refreshTimer = null;
    }
  }

  // Manually refresh data
  refreshData() {
    console.log("Refreshing analytics data...");
    this.setLoadingState(true);
    
    // Trigger refresh through ActionCable if connected
    // The React component handles this internally
    
    // Fallback: Fetch data via HTTP if WebSocket fails
    this.fetchDataViaHTTP()
      .catch(error => {
        console.error("Failed to refresh analytics data:", error);
        this.showError("Failed to refresh data. Please try again.");
      })
      .finally(() => {
        this.setLoadingState(false);
      });
  }

  // Fetch data via HTTP as fallback
  async fetchDataViaHTTP() {
    try {
      const response = await fetch(`/analytics/dashboard/data`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': this.getCSRFToken()
        },
        body: JSON.stringify({
          brand_id: this.brandIdValue,
          time_range: '30d'
        })
      });

      if (!response.ok) {
        throw new Error(`HTTP ${response.status}: ${response.statusText}`);
      }

      const data = await response.json();
      
      // Update React component with new data
      if (this.root) {
        this.root.render(
          React.createElement(AnalyticsDashboard, {
            brandId: this.brandIdValue,
            userId: this.userIdValue,
            initialMetrics: data
          })
        );
      }
    } catch (error) {
      console.error("HTTP fetch failed:", error);
      throw error;
    }
  }

  // Set loading state
  setLoadingState(loading) {
    if (loading) {
      this.element.classList.add("loading");
    } else {
      this.element.classList.remove("loading");
    }
  }

  // Show error message
  showError(message) {
    // Create or update error notification
    let errorNotification = this.element.querySelector('.analytics-error');
    
    if (!errorNotification) {
      errorNotification = document.createElement('div');
      errorNotification.className = 'analytics-error bg-red-100 border border-red-400 text-red-700 px-4 py-3 rounded mb-4';
      this.element.insertBefore(errorNotification, this.containerTarget);
    }
    
    errorNotification.innerHTML = `
      <div class="flex justify-between items-center">
        <span>${message}</span>
        <button onclick="this.parentElement.parentElement.remove()" class="text-red-700 hover:text-red-900 font-bold">×</button>
      </div>
    `;
    
    // Auto-hide after 5 seconds
    setTimeout(() => {
      if (errorNotification.parentElement) {
        errorNotification.remove();
      }
    }, 5000);
  }

  // Get CSRF token for requests
  getCSRFToken() {
    const token = document.querySelector('meta[name="csrf-token"]');
    return token ? token.getAttribute('content') : '';
  }

  // Handle window resize for responsive charts
  handleResize() {
    // Force chart re-render on window resize
    if (this.root) {
      this.root.render(
        React.createElement(AnalyticsDashboard, {
          brandId: this.brandIdValue,
          userId: this.userIdValue,
          initialMetrics: this.initialMetricsValue
        })
      );
    }
  }

  // Export functionality
  exportDashboard(format) {
    const event = new CustomEvent('analytics:export', {
      detail: { format }
    });
    this.element.dispatchEvent(event);
  }

  // Performance monitoring
  measurePerformance() {
    const startTime = performance.now();
    
    return {
      end: () => {
        const endTime = performance.now();
        const duration = endTime - startTime;
        
        // Log performance metrics
        console.log(`Analytics Dashboard render time: ${duration.toFixed(2)}ms`);
        
        // Track performance if duration exceeds threshold
        if (duration > 3000) { // 3 second threshold
          console.warn(`Analytics Dashboard slow render: ${duration.toFixed(2)}ms`);
          
          // Send performance data to monitoring service
          this.reportPerformanceIssue(duration);
        }
        
        return duration;
      }
    };
  }

  // Report performance issues
  reportPerformanceIssue(duration) {
    fetch('/analytics/performance', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'X-CSRF-Token': this.getCSRFToken()
      },
      body: JSON.stringify({
        component: 'analytics_dashboard',
        duration,
        user_id: this.userIdValue,
        brand_id: this.brandIdValue,
        timestamp: new Date().toISOString()
      })
    }).catch(error => {
      console.error("Failed to report performance issue:", error);
    });
  }

  // Cleanup resources
  cleanup() {
    this.stopAutoRefresh();
    
    if (this.root) {
      this.root.unmount();
      this.root = null;
    }
    
    // Remove any event listeners
    window.removeEventListener('resize', this.handleResize.bind(this));
  }

  // Initialize performance monitoring
  initializePerformanceMonitoring() {
    const observer = new PerformanceObserver((list) => {
      list.getEntries().forEach((entry) => {
        if (entry.entryType === 'measure' && entry.name.includes('analytics')) {
          console.log(`Performance measure: ${entry.name} - ${entry.duration.toFixed(2)}ms`);
        }
      });
    });
    
    observer.observe({ entryTypes: ['measure'] });
    this.performanceObserver = observer;
  }

  // Handle keyboard shortcuts
  handleKeyboardShortcuts(event) {
    // Ctrl/Cmd + R: Refresh data
    if ((event.ctrlKey || event.metaKey) && event.key === 'r') {
      event.preventDefault();
      this.refreshData();
    }
    
    // Ctrl/Cmd + E: Export as CSV
    if ((event.ctrlKey || event.metaKey) && event.key === 'e') {
      event.preventDefault();
      this.exportDashboard('csv');
    }
    
    // Ctrl/Cmd + P: Export as PDF
    if ((event.ctrlKey || event.metaKey) && event.key === 'p') {
      event.preventDefault();
      this.exportDashboard('pdf');
    }
  }

  // Initialize accessibility features
  initializeAccessibility() {
    // Add ARIA labels and roles
    this.containerTarget.setAttribute('role', 'main');
    this.containerTarget.setAttribute('aria-label', 'Analytics Dashboard');
    
    // Add keyboard navigation
    this.element.addEventListener('keydown', this.handleKeyboardShortcuts.bind(this));
    
    // Add screen reader announcements for data updates
    this.announceDataUpdates();
    
    // Add focus management
    this.setupFocusManagement();
    
    // Add skip links
    this.addSkipLinks();
  }

  // Setup focus management for dynamic content
  setupFocusManagement() {
    // Manage focus for modal dialogs and dynamic content
    this.focusStack = [];
    
    // Store original tabindex values for restoration
    this.originalTabindices = new Map();
  }

  // Add skip links for keyboard navigation
  addSkipLinks() {
    const skipLinks = document.createElement('div');
    skipLinks.className = 'sr-only focus:not-sr-only focus:absolute focus:top-4 focus:left-4 z-50';
    skipLinks.innerHTML = `
      <a href="#dashboard-title" class="bg-blue-600 text-white px-3 py-2 rounded">Skip to main content</a>
      <a href="#summary-metrics" class="bg-blue-600 text-white px-3 py-2 rounded ml-2">Skip to metrics</a>
      <a href="#main-chart" class="bg-blue-600 text-white px-3 py-2 rounded ml-2">Skip to charts</a>
    `;
    
    this.element.insertBefore(skipLinks, this.element.firstChild);
  }

  // Announce data updates for screen readers
  announceDataUpdates() {
    const announcement = document.createElement('div');
    announcement.setAttribute('aria-live', 'polite');
    announcement.setAttribute('aria-atomic', 'true');
    announcement.className = 'sr-only';
    announcement.id = 'analytics-announcements';
    
    this.element.appendChild(announcement);
    this.announcementTarget = announcement;
  }

  // Announce update to screen readers
  announceUpdate(message) {
    if (this.announcementTarget) {
      this.announcementTarget.textContent = message;
    }
  }
}