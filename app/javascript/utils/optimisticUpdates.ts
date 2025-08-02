import type { OptimisticUpdate, OptimisticQueue } from '../types/collaboration';

export interface OptimisticUpdateConfig {
  timeout: number;
  maxRetries: number;
  rollbackDelay: number;
}

export class OptimisticUpdateManager<T = Record<string, unknown>> implements OptimisticQueue<T> {
  public updates: Map<string, OptimisticUpdate<T>> = new Map();
  private config: OptimisticUpdateConfig;
  private timeouts: Map<string, NodeJS.Timeout> = new Map();
  private callbacks: Map<string, Function[]> = new Map();

  constructor(config: Partial<OptimisticUpdateConfig> = {}) {
    this.config = {
      timeout: 10000, // 10 seconds
      maxRetries: 3,
      rollbackDelay: 1000, // 1 second delay before rollback
      ...config
    };
  }

  /**
   * Create an optimistic update
   */
  createUpdate(
    id: string,
    type: string,
    originalData: T,
    optimisticData: T,
    applyCallback?: (data: T) => void
  ): OptimisticUpdate<T> {
    const update: OptimisticUpdate<T> = {
      id,
      type,
      original_data: originalData,
      optimistic_data: optimisticData,
      timestamp: new Date().toISOString(),
      confirmed: false,
      failed: false
    };

    this.updates.set(id, update);

    // Apply optimistic update immediately
    if (applyCallback) {
      applyCallback(optimisticData);
    }

    // Set timeout for auto-rollback
    const timeoutId = setTimeout(() => {
      this.fail(id, 'Operation timed out');
    }, this.config.timeout);

    this.timeouts.set(id, timeoutId);

    this.emit('update_created', update);
    return update;
  }

  /**
   * Confirm an optimistic update
   */
  confirm(updateId: string, serverData?: T): void {
    const update = this.updates.get(updateId);
    if (!update || update.confirmed || update.failed) {return;}

    update.confirmed = true;
    update.optimistic_data = serverData || update.optimistic_data;

    // Clear timeout
    const timeoutId = this.timeouts.get(updateId);
    if (timeoutId) {
      clearTimeout(timeoutId);
      this.timeouts.delete(updateId);
    }

    this.emit('update_confirmed', update);

    // Clean up after a delay
    setTimeout(() => {
      this.updates.delete(updateId);
    }, 1000);
  }

  /**
   * Fail an optimistic update and trigger rollback
   */
  fail(updateId: string, error: string): void {
    const update = this.updates.get(updateId);
    if (!update || update.confirmed || update.failed) {return;}

    update.failed = true;
    update.error_message = error;

    // Clear timeout
    const timeoutId = this.timeouts.get(updateId);
    if (timeoutId) {
      clearTimeout(timeoutId);
      this.timeouts.delete(updateId);
    }

    this.emit('update_failed', update);

    // Schedule rollback after delay
    setTimeout(() => {
      this.rollback(updateId);
    }, this.config.rollbackDelay);
  }

  /**
   * Rollback an optimistic update
   */
  rollback(updateId: string): void {
    const update = this.updates.get(updateId);
    if (!update) {return;}

    this.emit('update_rollback', update);

    // Clean up
    this.updates.delete(updateId);
    this.timeouts.delete(updateId);
  }

  /**
   * Get pending updates
   */
  getPendingUpdates(): OptimisticUpdate<T>[] {
    return Array.from(this.updates.values()).filter(
      update => !update.confirmed && !update.failed
    );
  }

  /**
   * Get failed updates
   */
  getFailedUpdates(): OptimisticUpdate<T>[] {
    return Array.from(this.updates.values()).filter(update => update.failed);
  }

  /**
   * Retry a failed update
   */
  retry(updateId: string, retryCallback?: (update: OptimisticUpdate<T>) => Promise<void>): boolean {
    const update = this.updates.get(updateId);
    if (!update || !update.failed) {return false;}

    // Reset failure state
    update.failed = false;
    update.error_message = undefined;

    if (retryCallback) {
      retryCallback(update).catch(error => {
        this.fail(updateId, error.message);
      });
    }

    this.emit('update_retried', update);
    return true;
  }

  /**
   * Clear all updates
   */
  clear(): void {
    // Clear all timeouts
    this.timeouts.forEach(timeoutId => clearTimeout(timeoutId));
    this.timeouts.clear();

    // Clear updates
    this.updates.clear();

    this.emit('queue_cleared', null);
  }

  /**
   * Register event callback
   */
  on(event: string, callback: Function): void {
    if (!this.callbacks.has(event)) {
      this.callbacks.set(event, []);
    }
    this.callbacks.get(event)!.push(callback);
  }

  /**
   * Unregister event callback
   */
  off(event: string, callback: Function): void {
    const callbacks = this.callbacks.get(event);
    if (callbacks) {
      const index = callbacks.indexOf(callback);
      if (index > -1) {
        callbacks.splice(index, 1);
      }
    }
  }

  /**
   * Emit event to callbacks
   */
  private emit(event: string, data: any): void {
    const callbacks = this.callbacks.get(event) || [];
    callbacks.forEach(callback => {
      try {
        callback(data);
      } catch (error) {
        console.error(`Error in optimistic update callback for ${event}:`, error);
      }
    });
  }

  /**
   * Get update statistics
   */
  getStats(): {
    total: number;
    pending: number;
    confirmed: number;
    failed: number;
    averageLatency: number;
  } {
    const updates = Array.from(this.updates.values());
    const now = Date.now();

    const stats = {
      total: updates.length,
      pending: updates.filter(u => !u.confirmed && !u.failed).length,
      confirmed: updates.filter(u => u.confirmed).length,
      failed: updates.filter(u => u.failed).length,
      averageLatency: 0
    };

    // Calculate average latency for confirmed updates
    const confirmedUpdates = updates.filter(u => u.confirmed);
    if (confirmedUpdates.length > 0) {
      const totalLatency = confirmedUpdates.reduce((sum, update) => {
        const created = new Date(update.timestamp).getTime();
        return sum + (now - created);
      }, 0);
      stats.averageLatency = totalLatency / confirmedUpdates.length;
    }

    return stats;
  }
}

/**
 * DOM-specific optimistic update manager
 */
export class DOMOptimisticManager extends OptimisticUpdateManager<Element> {
  private mutationObserver: MutationObserver | null = null;

  constructor(config?: Partial<OptimisticUpdateConfig>) {
    super(config);
    this.setupMutationObserver();
  }

  /**
   * Apply optimistic DOM update
   */
  applyDOMUpdate(
    id: string,
    element: Element,
    property: string,
    newValue: any,
    updateType: 'attribute' | 'textContent' | 'innerHTML' | 'style' = 'textContent'
  ): OptimisticUpdate<Element> {
    const originalValue = this.getDOMValue(element, property, updateType);
    
    const update = this.createUpdate(
      id,
      `dom_${updateType}`,
      element,
      element,
      () => {
        this.setDOMValue(element, property, newValue, updateType);
        this.addOptimisticMarker(element, id);
      }
    );

    // Store original value for rollback
    (update as any).originalValue = originalValue;
    (update as any).property = property;
    (update as any).updateType = updateType;

    return update;
  }

  /**
   * Rollback DOM update
   */
  rollback(updateId: string): void {
    const update = this.updates.get(updateId) as any;
    if (!update) {return;}

    const element = update.original_data;
    if (element && element.isConnected) {
      this.setDOMValue(element, update.property, update.originalValue, update.updateType);
      this.removeOptimisticMarker(element, updateId);
      this.addFailureMarker(element, updateId);
    }

    super.rollback(updateId);
  }

  /**
   * Confirm DOM update
   */
  confirm(updateId: string, serverData?: Element): void {
    const update = this.updates.get(updateId);
    if (!update) {return;}

    const element = update.original_data;
    if (element && element.isConnected) {
      this.removeOptimisticMarker(element, updateId);
      this.addConfirmedMarker(element, updateId);
    }

    super.confirm(updateId, serverData);
  }

  private getDOMValue(element: Element, property: string, updateType: string): any {
    switch (updateType) {
      case 'attribute':
        return element.getAttribute(property);
      case 'textContent':
        return element.textContent;
      case 'innerHTML':
        return element.innerHTML;
      case 'style':
        return (element as HTMLElement).style.getPropertyValue(property);
      default:
        return (element as any)[property];
    }
  }

  private setDOMValue(element: Element, property: string, value: any, updateType: string): void {
    switch (updateType) {
      case 'attribute':
        element.setAttribute(property, value);
        break;
      case 'textContent':
        element.textContent = value;
        break;
      case 'innerHTML':
        element.innerHTML = value;
        break;
      case 'style':
        (element as HTMLElement).style.setProperty(property, value);
        break;
      default:
        (element as any)[property] = value;
    }
  }

  private addOptimisticMarker(element: Element, updateId: string): void {
    element.classList.add('optimistic-update');
    element.setAttribute('data-optimistic-id', updateId);
  }

  private removeOptimisticMarker(element: Element, updateId: string): void {
    element.classList.remove('optimistic-update');
    element.removeAttribute('data-optimistic-id');
  }

  private addConfirmedMarker(element: Element, updateId: string): void {
    element.classList.add('optimistic-confirmed');
    setTimeout(() => {
      element.classList.remove('optimistic-confirmed');
    }, 1000);
  }

  private addFailureMarker(element: Element, updateId: string): void {
    element.classList.add('optimistic-failed');
    setTimeout(() => {
      element.classList.remove('optimistic-failed');
    }, 3000);
  }

  private setupMutationObserver(): void {
    this.mutationObserver = new MutationObserver((mutations) => {
      mutations.forEach((mutation) => {
        // Handle cases where optimistically updated elements are removed
        if (mutation.type === 'childList') {
          mutation.removedNodes.forEach((node) => {
            if (node.nodeType === Node.ELEMENT_NODE) {
              const element = node as Element;
              const updateId = element.getAttribute('data-optimistic-id');
              if (updateId && this.updates.has(updateId)) {
                // Element was removed before confirmation - consider it failed
                this.fail(updateId, 'Element was removed from DOM');
              }
            }
          });
        }
      });
    });

    this.mutationObserver.observe(document.body, {
      childList: true,
      subtree: true
    });
  }

  destroy(): void {
    if (this.mutationObserver) {
      this.mutationObserver.disconnect();
      this.mutationObserver = null;
    }
    this.clear();
  }
}

/**
 * Form-specific optimistic update manager
 */
export class FormOptimisticManager extends DOMOptimisticManager {
  /**
   * Apply optimistic form field update
   */
  updateFormField(
    fieldName: string,
    newValue: any,
    form?: HTMLFormElement
  ): OptimisticUpdate<Element> | null {
    const field = form ? 
      form.querySelector(`[name="${fieldName}"]`) :
      document.querySelector(`[name="${fieldName}"]`);

    if (!field) {return null;}

    const updateId = `form_${fieldName}_${Date.now()}`;
    
    if (field instanceof HTMLInputElement || field instanceof HTMLTextAreaElement) {
      return this.applyDOMUpdate(updateId, field, 'value', newValue, 'attribute');
    } else if (field instanceof HTMLSelectElement) {
      return this.applyDOMUpdate(updateId, field, 'value', newValue, 'attribute');
    }

    return null;
  }

  /**
   * Apply optimistic form submission
   */
  submitForm(
    form: HTMLFormElement,
    optimisticData: Record<string, any>
  ): OptimisticUpdate<Element> {
    const updateId = `form_submit_${Date.now()}`;
    
    return this.createUpdate(
      updateId,
      'form_submit',
      form,
      form,
      () => {
        // Disable form during optimistic submission
        const inputs = form.querySelectorAll('input, button, textarea, select');
        inputs.forEach(input => {
          (input as HTMLInputElement).disabled = true;
        });
        
        // Add loading state
        form.classList.add('optimistic-submitting');
        
        // Update fields with optimistic data
        Object.entries(optimisticData).forEach(([fieldName, value]) => {
          this.updateFormField(fieldName, value, form);
        });
      }
    );
  }

  /**
   * Confirm form submission
   */
  confirmSubmission(updateId: string): void {
    const update = this.updates.get(updateId);
    if (!update) {return;}

    const form = update.original_data as HTMLFormElement;
    if (form) {
      // Re-enable form
      const inputs = form.querySelectorAll('input, button, textarea, select');
      inputs.forEach(input => {
        (input as HTMLInputElement).disabled = false;
      });
      
      form.classList.remove('optimistic-submitting');
      form.classList.add('submission-confirmed');
      
      setTimeout(() => {
        form.classList.remove('submission-confirmed');
      }, 2000);
    }

    this.confirm(updateId);
  }

  /**
   * Fail form submission
   */
  failSubmission(updateId: string, error: string): void {
    const update = this.updates.get(updateId);
    if (!update) {return;}

    const form = update.original_data as HTMLFormElement;
    if (form) {
      // Re-enable form
      const inputs = form.querySelectorAll('input, button, textarea, select');
      inputs.forEach(input => {
        (input as HTMLInputElement).disabled = false;
      });
      
      form.classList.remove('optimistic-submitting');
      form.classList.add('submission-failed');
      
      setTimeout(() => {
        form.classList.remove('submission-failed');
      }, 3000);
    }

    this.fail(updateId, error);
  }
}

// Export singleton instances
let domOptimisticManager: DOMOptimisticManager | null = null;
let formOptimisticManager: FormOptimisticManager | null = null;

export const getDOMOptimisticManager = (): DOMOptimisticManager => {
  if (!domOptimisticManager) {
    domOptimisticManager = new DOMOptimisticManager();
  }
  return domOptimisticManager;
};

export const getFormOptimisticManager = (): FormOptimisticManager => {
  if (!formOptimisticManager) {
    formOptimisticManager = new FormOptimisticManager();
  }
  return formOptimisticManager;
};

export const destroyOptimisticManagers = (): void => {
  if (domOptimisticManager) {
    domOptimisticManager.destroy();
    domOptimisticManager = null;
  }
  if (formOptimisticManager) {
    formOptimisticManager.destroy();
    formOptimisticManager = null;
  }
};