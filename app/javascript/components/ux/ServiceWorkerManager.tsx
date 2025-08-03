import React, { useEffect, useState, useCallback } from 'react';
import { useToast } from './FeedbackSystems';

export interface ServiceWorkerState {
  isSupported: boolean;
  isRegistered: boolean;
  isInstalling: boolean;
  isWaiting: boolean;
  isActive: boolean;
  hasUpdate: boolean;
  cacheSize: number;
  offlineReady: boolean;
}

export interface OfflineAction {
  id: string;
  url: string;
  method: string;
  headers: Record<string, string>;
  body?: string;
  timestamp: number;
  retryCount: number;
}

// Service Worker Manager Hook
export const useServiceWorker = () => {
  const [state, setState] = useState<ServiceWorkerState>({
    isSupported: 'serviceWorker' in navigator,
    isRegistered: false,
    isInstalling: false,
    isWaiting: false,
    isActive: false,
    hasUpdate: false,
    cacheSize: 0,
    offlineReady: false
  });

  const { addToast } = useToast();

  const updateServiceWorker = useCallback(() => {
    if (state.hasUpdate && 'serviceWorker' in navigator) {
      const registration = navigator.serviceWorker.controller;
      if (registration) {
        registration.postMessage({ type: 'SKIP_WAITING' });
        window.location.reload();
      }
    }
  }, [state.hasUpdate]);

  const getCacheSize = useCallback(async () => {
    if ('serviceWorker' in navigator && navigator.serviceWorker.controller) {
      return new Promise<number>((resolve) => {
        const messageChannel = new MessageChannel();
        messageChannel.port1.onmessage = (event) => {
          if (event.data.type === 'CACHE_SIZE') {
            resolve(event.data.size);
          }
        };
        
        navigator.serviceWorker.controller.postMessage(
          { type: 'GET_CACHE_SIZE' },
          [messageChannel.port2]
        );
      });
    }
    return 0;
  }, []);

  const clearCache = useCallback(async () => {
    if ('serviceWorker' in navigator && navigator.serviceWorker.controller) {
      return new Promise<void>((resolve) => {
        const messageChannel = new MessageChannel();
        messageChannel.port1.onmessage = (event) => {
          if (event.data.type === 'CACHE_CLEARED') {
            addToast({
              type: 'success',
              title: 'Cache Cleared',
              message: 'All cached data has been removed'
            });
            resolve();
          }
        };
        
        navigator.serviceWorker.controller.postMessage(
          { type: 'CLEAR_CACHE' },
          [messageChannel.port2]
        );
      });
    }
  }, [addToast]);

  useEffect(() => {
    if (!state.isSupported) {return;}

    const registerServiceWorker = async () => {
      try {
        const registration = await navigator.serviceWorker.register('/sw.js', {
          scope: '/'
        });

        console.log('Service Worker registered:', registration);

        setState(prev => ({
          ...prev,
          isRegistered: true,
          isInstalling: registration.installing !== null,
          isWaiting: registration.waiting !== null,
          isActive: registration.active !== null
        }));

        // Handle service worker updates
        registration.addEventListener('updatefound', () => {
          const newWorker = registration.installing;
          if (newWorker) {
            setState(prev => ({ ...prev, isInstalling: true }));

            newWorker.addEventListener('statechange', () => {
              if (newWorker.state === 'installed') {
                if (navigator.serviceWorker.controller) {
                  // New version available
                  setState(prev => ({ ...prev, hasUpdate: true, isWaiting: true }));
                  addToast({
                    type: 'info',
                    title: 'Update Available',
                    message: 'A new version is ready to install',
                    action: {
                      label: 'Update Now',
                      onClick: updateServiceWorker
                    },
                    duration: 0 // Don't auto-dismiss
                  });
                } else {
                  // First time install
                  setState(prev => ({ ...prev, offlineReady: true }));
                  addToast({
                    type: 'success',
                    title: 'Offline Ready',
                    message: 'App is now available offline'
                  });
                }
                setState(prev => ({ ...prev, isInstalling: false }));
              }
            });
          }
        });

        // Get initial cache size
        const cacheSize = await getCacheSize();
        setState(prev => ({ ...prev, cacheSize }));

      } catch (error) {
        console.error('Service Worker registration failed:', error);
        addToast({
          type: 'error',
          title: 'Offline Features Unavailable',
          message: 'Could not enable offline functionality'
        });
      }
    };

    registerServiceWorker();

    // Listen for service worker messages
    navigator.serviceWorker.addEventListener('message', (event) => {
      if (event.data.type === 'CACHE_UPDATED') {
        getCacheSize().then(size => {
          setState(prev => ({ ...prev, cacheSize: size }));
        });
      }
    });

    // Listen for connection changes
    const handleOnline = () => {
      addToast({
        type: 'success',
        title: 'Back Online',
        message: 'Internet connection restored'
      });
    };

    const handleOffline = () => {
      addToast({
        type: 'warning',
        title: 'Gone Offline',
        message: 'You can continue working with cached content'
      });
    };

    window.addEventListener('online', handleOnline);
    window.addEventListener('offline', handleOffline);

    return () => {
      window.removeEventListener('online', handleOnline);
      window.removeEventListener('offline', handleOffline);
    };
  }, [state.isSupported, addToast, updateServiceWorker, getCacheSize]);

  return {
    ...state,
    updateServiceWorker,
    getCacheSize,
    clearCache
  };
};

// Offline Action Manager
export class OfflineActionManager {
  private static instance: OfflineActionManager;
  private dbName = 'OfflineActions';
  private dbVersion = 1;
  private storeName = 'actions';

  static getInstance(): OfflineActionManager {
    if (!OfflineActionManager.instance) {
      OfflineActionManager.instance = new OfflineActionManager();
    }
    return OfflineActionManager.instance;
  }

  private async openDB(): Promise<IDBDatabase> {
    return new Promise((resolve, reject) => {
      const request = indexedDB.open(this.dbName, this.dbVersion);

      request.onupgradeneeded = () => {
        const db = request.result;
        if (!db.objectStoreNames.contains(this.storeName)) {
          const store = db.createObjectStore(this.storeName, { keyPath: 'id' });
          store.createIndex('timestamp', 'timestamp', { unique: false });
        }
      };

      request.onsuccess = () => resolve(request.result);
      request.onerror = () => reject(request.error);
    });
  }

  async addAction(action: Omit<OfflineAction, 'id' | 'timestamp' | 'retryCount'>): Promise<void> {
    const db = await this.openDB();
    const transaction = db.transaction([this.storeName], 'readwrite');
    const store = transaction.objectStore(this.storeName);

    const offlineAction: OfflineAction = {
      ...action,
      id: `action_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`,
      timestamp: Date.now(),
      retryCount: 0
    };

    return new Promise((resolve, reject) => {
      const request = store.add(offlineAction);
      request.onsuccess = () => {
        // Register background sync if available
        if ('serviceWorker' in navigator && 'sync' in window.ServiceWorkerRegistration.prototype) {
          navigator.serviceWorker.ready.then(registration => {
            return registration.sync.register('sync-offline-actions');
          }).catch(console.error);
        }
        resolve();
      };
      request.onerror = () => reject(request.error);
    });
  }

  async getActions(): Promise<OfflineAction[]> {
    const db = await this.openDB();
    const transaction = db.transaction([this.storeName], 'readonly');
    const store = transaction.objectStore(this.storeName);

    return new Promise((resolve, reject) => {
      const request = store.getAll();
      request.onsuccess = () => resolve(request.result);
      request.onerror = () => reject(request.error);
    });
  }

  async removeAction(id: string): Promise<void> {
    const db = await this.openDB();
    const transaction = db.transaction([this.storeName], 'readwrite');
    const store = transaction.objectStore(this.storeName);

    return new Promise((resolve, reject) => {
      const request = store.delete(id);
      request.onsuccess = () => resolve();
      request.onerror = () => reject(request.error);
    });
  }

  async clearActions(): Promise<void> {
    const db = await this.openDB();
    const transaction = db.transaction([this.storeName], 'readwrite');
    const store = transaction.objectStore(this.storeName);

    return new Promise((resolve, reject) => {
      const request = store.clear();
      request.onsuccess = () => resolve();
      request.onerror = () => reject(request.error);
    });
  }
}

// Service Worker Status Component
export const ServiceWorkerStatus: React.FC = () => {
  const sw = useServiceWorker();
  const [isExpanded, setIsExpanded] = useState(false);

  const formatBytes = (bytes: number): string => {
    if (bytes === 0) {return '0 Bytes';}
    const k = 1024;
    const sizes = ['Bytes', 'KB', 'MB', 'GB'];
    const i = Math.floor(Math.log(bytes) / Math.log(k));
    return `${parseFloat((bytes / Math.pow(k, i)).toFixed(2))  } ${  sizes[i]}`;
  };

  if (!sw.isSupported) {return null;}

  return (
    <div className="fixed bottom-4 left-4 z-40">
      <div className="bg-white dark:bg-gray-800 border border-gray-200 dark:border-gray-700 rounded-lg shadow-lg">
        <button
          onClick={() => setIsExpanded(!isExpanded)}
          className="flex items-center space-x-2 p-3 w-full text-left hover:bg-gray-50 dark:hover:bg-gray-700 rounded-lg"
        >
          <div className={`w-3 h-3 rounded-full ${
            sw.isActive ? 'bg-green-500' : sw.isInstalling ? 'bg-yellow-500' : 'bg-red-500'
          }`} />
          <span className="text-sm font-medium">
            {sw.isActive ? 'Online' : sw.isInstalling ? 'Installing...' : 'Offline'}
          </span>
          <svg
            className={`w-4 h-4 transform transition-transform ${isExpanded ? 'rotate-180' : ''}`}
            fill="none"
            stroke="currentColor"
            viewBox="0 0 24 24"
          >
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M19 9l-7 7-7-7" />
          </svg>
        </button>

        {isExpanded && (
          <div className="border-t border-gray-200 dark:border-gray-700 p-3 space-y-3">
            <div className="text-xs text-gray-600 dark:text-gray-400 space-y-1">
              <div>Status: {sw.isActive ? 'Active' : 'Inactive'}</div>
              <div>Cache: {formatBytes(sw.cacheSize)}</div>
              <div>Offline Ready: {sw.offlineReady ? 'Yes' : 'No'}</div>
            </div>

            {sw.hasUpdate && (
              <button
                onClick={sw.updateServiceWorker}
                className="w-full px-3 py-2 bg-blue-600 text-white text-xs rounded hover:bg-blue-700"
              >
                Update Available - Click to Install
              </button>
            )}

            <div className="flex space-x-2">
              <button
                onClick={() => sw.getCacheSize()}
                className="flex-1 px-2 py-1 text-xs bg-gray-100 dark:bg-gray-700 rounded hover:bg-gray-200 dark:hover:bg-gray-600"
              >
                Refresh
              </button>
              
              <button
                onClick={sw.clearCache}
                className="flex-1 px-2 py-1 text-xs bg-red-100 text-red-700 dark:bg-red-900 dark:text-red-300 rounded hover:bg-red-200 dark:hover:bg-red-800"
              >
                Clear Cache
              </button>
            </div>
          </div>
        )}
      </div>
    </div>
  );
};

// Offline Action Queue Component
export const OfflineActionQueue: React.FC = () => {
  const [actions, setActions] = useState<OfflineAction[]>([]);
  const [isVisible, setIsVisible] = useState(false);
  const manager = OfflineActionManager.getInstance();

  useEffect(() => {
    const loadActions = async () => {
      try {
        const offlineActions = await manager.getActions();
        setActions(offlineActions);
        setIsVisible(offlineActions.length > 0);
      } catch (error) {
        console.error('Failed to load offline actions:', error);
      }
    };

    loadActions();

    // Poll for updates
    const interval = setInterval(loadActions, 5000);
    return () => clearInterval(interval);
  }, [manager]);

  const clearQueue = async () => {
    try {
      await manager.clearActions();
      setActions([]);
      setIsVisible(false);
    } catch (error) {
      console.error('Failed to clear offline actions:', error);
    }
  };

  if (!isVisible) {return null;}

  return (
    <div className="fixed top-4 left-4 bg-yellow-50 dark:bg-yellow-900/20 border border-yellow-200 dark:border-yellow-800 rounded-lg p-4 max-w-sm z-50">
      <div className="flex items-start justify-between mb-2">
        <h3 className="text-sm font-semibold text-yellow-800 dark:text-yellow-200">
          Pending Actions ({actions.length})
        </h3>
        <button
          onClick={() => setIsVisible(false)}
          className="text-yellow-600 dark:text-yellow-400 hover:text-yellow-800 dark:hover:text-yellow-200"
        >
          <svg className="w-4 h-4" fill="currentColor" viewBox="0 0 20 20">
            <path fillRule="evenodd" d="M4.293 4.293a1 1 0 011.414 0L10 8.586l4.293-4.293a1 1 0 111.414 1.414L11.414 10l4.293 4.293a1 1 0 01-1.414 1.414L10 11.414l-4.293 4.293a1 1 0 01-1.414-1.414L8.586 10 4.293 5.707a1 1 0 010-1.414z" clipRule="evenodd" />
          </svg>
        </button>
      </div>
      
      <p className="text-xs text-yellow-700 dark:text-yellow-300 mb-3">
        These actions will sync when you're back online.
      </p>
      
      <div className="space-y-2 max-h-32 overflow-y-auto">
        {actions.slice(0, 3).map((action) => (
          <div key={action.id} className="text-xs text-yellow-600 dark:text-yellow-400 bg-yellow-100 dark:bg-yellow-900/40 p-2 rounded">
            <div className="font-medium">{action.method} {new URL(action.url).pathname}</div>
            <div className="text-yellow-500 dark:text-yellow-500">
              {new Date(action.timestamp).toLocaleTimeString()}
            </div>
          </div>
        ))}
        {actions.length > 3 && (
          <div className="text-xs text-yellow-600 dark:text-yellow-400">
            ...and {actions.length - 3} more
          </div>
        )}
      </div>
      
      <button
        onClick={clearQueue}
        className="mt-3 w-full px-3 py-1 text-xs bg-yellow-200 dark:bg-yellow-800 text-yellow-800 dark:text-yellow-200 rounded hover:bg-yellow-300 dark:hover:bg-yellow-700"
      >
        Clear Queue
      </button>
    </div>
  );
};

// PWA Install Prompt
export const PWAInstallPrompt: React.FC = () => {
  const [deferredPrompt, setDeferredPrompt] = useState<any>(null);
  const [showPrompt, setShowPrompt] = useState(false);

  useEffect(() => {
    const handleBeforeInstallPrompt = (e: Event) => {
      e.preventDefault();
      setDeferredPrompt(e);
      setShowPrompt(true);
    };

    window.addEventListener('beforeinstallprompt', handleBeforeInstallPrompt);

    return () => {
      window.removeEventListener('beforeinstallprompt', handleBeforeInstallPrompt);
    };
  }, []);

  const handleInstall = async () => {
    if (deferredPrompt) {
      deferredPrompt.prompt();
      const { outcome } = await deferredPrompt.userChoice;
      
      if (outcome === 'accepted') {
        console.log('PWA install accepted');
      } else {
        console.log('PWA install dismissed');
      }
      
      setDeferredPrompt(null);
      setShowPrompt(false);
    }
  };

  const handleDismiss = () => {
    setShowPrompt(false);
    setDeferredPrompt(null);
  };

  if (!showPrompt) {return null;}

  return (
    <div className="fixed bottom-4 right-4 bg-blue-600 text-white p-4 rounded-lg shadow-lg max-w-sm z-50">
      <div className="flex items-start space-x-3">
        <div className="flex-shrink-0">
          <svg className="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 18h.01M8 21h8a2 2 0 002-2V5a2 2 0 00-2-2H8a2 2 0 00-2 2v14a2 2 0 002 2z" />
          </svg>
        </div>
        <div className="flex-1">
          <h3 className="text-sm font-semibold mb-1">Install App</h3>
          <p className="text-xs opacity-90 mb-3">
            Install Marketer Gen for a better experience with offline access.
          </p>
          <div className="flex space-x-2">
            <button
              onClick={handleInstall}
              className="px-3 py-1 bg-white text-blue-600 text-xs rounded font-medium hover:bg-gray-100"
            >
              Install
            </button>
            <button
              onClick={handleDismiss}
              className="px-3 py-1 bg-blue-700 text-xs rounded hover:bg-blue-800"
            >
              Not Now
            </button>
          </div>
        </div>
        <button
          onClick={handleDismiss}
          className="flex-shrink-0 text-blue-200 hover:text-white"
        >
          <svg className="w-4 h-4" fill="currentColor" viewBox="0 0 20 20">
            <path fillRule="evenodd" d="M4.293 4.293a1 1 0 011.414 0L10 8.586l4.293-4.293a1 1 0 111.414 1.414L11.414 10l4.293 4.293a1 1 0 01-1.414 1.414L10 11.414l-4.293 4.293a1 1 0 01-1.414-1.414L8.586 10 4.293 5.707a1 1 0 010-1.414z" clipRule="evenodd" />
          </svg>
        </button>
      </div>
    </div>
  );
};