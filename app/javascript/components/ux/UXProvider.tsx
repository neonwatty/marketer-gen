import React, { createContext, useContext, useEffect, useState } from 'react';
import { AnimatePresence } from 'framer-motion';
import { ToastProvider } from './FeedbackSystems';
import { ErrorBoundary } from './ErrorHandling';
import { ServiceWorkerStatus, OfflineActionQueue, PWAInstallPrompt } from './ServiceWorkerManager';
import { OfflineIndicator } from './ErrorHandling';
import { PerformanceMetricsDisplay } from './PerformanceOptimization';

// Global UX Context
interface UXContextType {
  theme: 'light' | 'dark' | 'auto';
  setTheme: (theme: 'light' | 'dark' | 'auto') => void;
  reducedMotion: boolean;
  setReducedMotion: (reduced: boolean) => void;
  highContrast: boolean;
  setHighContrast: (contrast: boolean) => void;
  fontSize: 'small' | 'medium' | 'large';
  setFontSize: (size: 'small' | 'medium' | 'large') => void;
  isOnline: boolean;
  showPerformanceMetrics: boolean;
  setShowPerformanceMetrics: (show: boolean) => void;
}

const UXContext = createContext<UXContextType | null>(null);

export const useUX = () => {
  const context = useContext(UXContext);
  if (!context) {
    throw new Error('useUX must be used within a UXProvider');
  }
  return context;
};

// UX Provider Component
export const UXProvider: React.FC<{ children: React.ReactNode }> = ({ children }) => {
  const [theme, setTheme] = useState<'light' | 'dark' | 'auto'>('auto');
  const [reducedMotion, setReducedMotion] = useState(false);
  const [highContrast, setHighContrast] = useState(false);
  const [fontSize, setFontSize] = useState<'small' | 'medium' | 'large'>('medium');
  const [isOnline, setIsOnline] = useState(navigator.onLine);
  const [showPerformanceMetrics, setShowPerformanceMetrics] = useState(false);

  // Load preferences from localStorage
  useEffect(() => {
    const savedTheme = localStorage.getItem('ux-theme') as 'light' | 'dark' | 'auto' || 'auto';
    const savedReducedMotion = localStorage.getItem('ux-reduced-motion') === 'true';
    const savedHighContrast = localStorage.getItem('ux-high-contrast') === 'true';
    const savedFontSize = localStorage.getItem('ux-font-size') as 'small' | 'medium' | 'large' || 'medium';
    const savedShowMetrics = localStorage.getItem('ux-show-metrics') === 'true';

    setTheme(savedTheme);
    setReducedMotion(savedReducedMotion);
    setHighContrast(savedHighContrast);
    setFontSize(savedFontSize);
    setShowPerformanceMetrics(savedShowMetrics);

    // Check for system preferences
    const mediaReducedMotion = window.matchMedia('(prefers-reduced-motion: reduce)');
    const mediaHighContrast = window.matchMedia('(prefers-contrast: high)');
    
    if (mediaReducedMotion.matches) {setReducedMotion(true);}
    if (mediaHighContrast.matches) {setHighContrast(true);}

    // Listen for changes
    mediaReducedMotion.addEventListener('change', (e) => setReducedMotion(e.matches));
    mediaHighContrast.addEventListener('change', (e) => setHighContrast(e.matches));

    return () => {
      mediaReducedMotion.removeEventListener('change', (e) => setReducedMotion(e.matches));
      mediaHighContrast.removeEventListener('change', (e) => setHighContrast(e.matches));
    };
  }, []);

  // Apply theme
  useEffect(() => {
    const root = document.documentElement;
    
    if (theme === 'auto') {
      const mediaQuery = window.matchMedia('(prefers-color-scheme: dark)');
      const applyTheme = (e: MediaQueryListEvent | MediaQueryList) => {
        root.classList.toggle('dark', e.matches);
      };
      
      applyTheme(mediaQuery);
      mediaQuery.addEventListener('change', applyTheme);
      
      return () => mediaQuery.removeEventListener('change', applyTheme);
    } else {
      root.classList.toggle('dark', theme === 'dark');
    }
    
    localStorage.setItem('ux-theme', theme);
  }, [theme]);

  // Apply accessibility preferences
  useEffect(() => {
    const root = document.documentElement;
    
    // Reduced motion
    root.style.setProperty('--motion-scale', reducedMotion ? '0' : '1');
    root.classList.toggle('reduce-motion', reducedMotion);
    localStorage.setItem('ux-reduced-motion', reducedMotion.toString());
    
    // High contrast
    root.classList.toggle('high-contrast', highContrast);
    localStorage.setItem('ux-high-contrast', highContrast.toString());
    
    // Font size
    const fontSizeMap = {
      small: '14px',
      medium: '16px',
      large: '18px'
    };
    root.style.setProperty('--base-font-size', fontSizeMap[fontSize]);
    localStorage.setItem('ux-font-size', fontSize);
    
    // Performance metrics
    localStorage.setItem('ux-show-metrics', showPerformanceMetrics.toString());
  }, [reducedMotion, highContrast, fontSize, showPerformanceMetrics]);

  // Online/offline status
  useEffect(() => {
    const updateOnlineStatus = () => setIsOnline(navigator.onLine);
    
    window.addEventListener('online', updateOnlineStatus);
    window.addEventListener('offline', updateOnlineStatus);
    
    return () => {
      window.removeEventListener('online', updateOnlineStatus);
      window.removeEventListener('offline', updateOnlineStatus);
    };
  }, []);

  const contextValue: UXContextType = {
    theme,
    setTheme,
    reducedMotion,
    setReducedMotion,
    highContrast,
    setHighContrast,
    fontSize,
    setFontSize,
    isOnline,
    showPerformanceMetrics,
    setShowPerformanceMetrics
  };

  return (
    <UXContext.Provider value={contextValue}>
      <ToastProvider>
        <ErrorBoundary>
          <div className={`ux-root ${reducedMotion ? 'reduce-motion' : ''} ${highContrast ? 'high-contrast' : ''}`}>
            {children}
            
            {/* Global UX Components */}
            <AnimatePresence>
              <OfflineIndicator />
              <ServiceWorkerStatus />
              <OfflineActionQueue />
              <PWAInstallPrompt />
            </AnimatePresence>
            
            {/* Performance Metrics (Development/Debug) */}
            {showPerformanceMetrics && process.env.NODE_ENV === 'development' && (
              <div className="fixed top-4 right-4 z-50">
                <PerformanceMetricsDisplay />
              </div>
            )}
          </div>
        </ErrorBoundary>
      </ToastProvider>
    </UXContext.Provider>
  );
};

// Accessibility Settings Panel
export const AccessibilityPanel: React.FC<{
  isOpen: boolean;
  onClose: () => void;
}> = ({ isOpen, onClose }) => {
  const ux = useUX();

  if (!isOpen) {return null;}

  return (
    <div className="fixed inset-0 z-50 bg-black bg-opacity-50 flex items-center justify-center p-4">
      <div className="bg-white dark:bg-gray-800 rounded-lg shadow-xl max-w-md w-full p-6">
        <div className="flex justify-between items-center mb-6">
          <h2 className="text-xl font-semibold text-gray-900 dark:text-gray-100">
            Accessibility Settings
          </h2>
          <button
            onClick={onClose}
            className="text-gray-400 hover:text-gray-600 dark:hover:text-gray-300"
          >
            <svg className="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M6 18L18 6M6 6l12 12" />
            </svg>
          </button>
        </div>

        <div className="space-y-6">
          {/* Theme Selection */}
          <div>
            <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">
              Theme
            </label>
            <div className="grid grid-cols-3 gap-2">
              {(['light', 'dark', 'auto'] as const).map((themeOption) => (
                <button
                  key={themeOption}
                  onClick={() => ux.setTheme(themeOption)}
                  className={`p-2 text-xs rounded-lg border-2 transition-colors ${
                    ux.theme === themeOption
                      ? 'border-blue-500 bg-blue-50 dark:bg-blue-900/20 text-blue-700 dark:text-blue-300'
                      : 'border-gray-200 dark:border-gray-600 hover:border-gray-300 dark:hover:border-gray-500'
                  }`}
                >
                  {themeOption.charAt(0).toUpperCase() + themeOption.slice(1)}
                </button>
              ))}
            </div>
          </div>

          {/* Font Size */}
          <div>
            <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">
              Font Size
            </label>
            <div className="grid grid-cols-3 gap-2">
              {(['small', 'medium', 'large'] as const).map((sizeOption) => (
                <button
                  key={sizeOption}
                  onClick={() => ux.setFontSize(sizeOption)}
                  className={`p-2 text-xs rounded-lg border-2 transition-colors ${
                    ux.fontSize === sizeOption
                      ? 'border-blue-500 bg-blue-50 dark:bg-blue-900/20 text-blue-700 dark:text-blue-300'
                      : 'border-gray-200 dark:border-gray-600 hover:border-gray-300 dark:hover:border-gray-500'
                  }`}
                >
                  {sizeOption.charAt(0).toUpperCase() + sizeOption.slice(1)}
                </button>
              ))}
            </div>
          </div>

          {/* Accessibility Toggles */}
          <div className="space-y-4">
            <div className="flex items-center justify-between">
              <div>
                <div className="text-sm font-medium text-gray-700 dark:text-gray-300">
                  Reduced Motion
                </div>
                <div className="text-xs text-gray-500 dark:text-gray-400">
                  Minimize animations and transitions
                </div>
              </div>
              <button
                onClick={() => ux.setReducedMotion(!ux.reducedMotion)}
                className={`relative inline-flex h-6 w-11 items-center rounded-full transition-colors ${
                  ux.reducedMotion ? 'bg-blue-600' : 'bg-gray-200 dark:bg-gray-700'
                }`}
              >
                <span
                  className={`inline-block h-4 w-4 transform rounded-full bg-white transition-transform ${
                    ux.reducedMotion ? 'translate-x-6' : 'translate-x-1'
                  }`}
                />
              </button>
            </div>

            <div className="flex items-center justify-between">
              <div>
                <div className="text-sm font-medium text-gray-700 dark:text-gray-300">
                  High Contrast
                </div>
                <div className="text-xs text-gray-500 dark:text-gray-400">
                  Increase color contrast for better visibility
                </div>
              </div>
              <button
                onClick={() => ux.setHighContrast(!ux.highContrast)}
                className={`relative inline-flex h-6 w-11 items-center rounded-full transition-colors ${
                  ux.highContrast ? 'bg-blue-600' : 'bg-gray-200 dark:bg-gray-700'
                }`}
              >
                <span
                  className={`inline-block h-4 w-4 transform rounded-full bg-white transition-transform ${
                    ux.highContrast ? 'translate-x-6' : 'translate-x-1'
                  }`}
                />
              </button>
            </div>

            {process.env.NODE_ENV === 'development' && (
              <div className="flex items-center justify-between">
                <div>
                  <div className="text-sm font-medium text-gray-700 dark:text-gray-300">
                    Performance Metrics
                  </div>
                  <div className="text-xs text-gray-500 dark:text-gray-400">
                    Show performance information (dev only)
                  </div>
                </div>
                <button
                  onClick={() => ux.setShowPerformanceMetrics(!ux.showPerformanceMetrics)}
                  className={`relative inline-flex h-6 w-11 items-center rounded-full transition-colors ${
                    ux.showPerformanceMetrics ? 'bg-blue-600' : 'bg-gray-200 dark:bg-gray-700'
                  }`}
                >
                  <span
                    className={`inline-block h-4 w-4 transform rounded-full bg-white transition-transform ${
                      ux.showPerformanceMetrics ? 'translate-x-6' : 'translate-x-1'
                    }`}
                  />
                </button>
              </div>
            )}
          </div>
        </div>

        <div className="mt-6 pt-4 border-t border-gray-200 dark:border-gray-700">
          <button
            onClick={onClose}
            className="w-full px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 transition-colors"
          >
            Save Settings
          </button>
        </div>
      </div>
    </div>
  );
};

// UX Integration Helper Hook
export const useUXIntegration = () => {
  const ux = useUX();

  const getAnimationProps = (type: 'fade' | 'slide' | 'scale' = 'fade') => {
    if (ux.reducedMotion) {
      return {
        initial: { opacity: 0 },
        animate: { opacity: 1 },
        exit: { opacity: 0 },
        transition: { duration: 0.1 }
      };
    }

    const animations = {
      fade: {
        initial: { opacity: 0 },
        animate: { opacity: 1 },
        exit: { opacity: 0 },
        transition: { duration: 0.3 }
      },
      slide: {
        initial: { opacity: 0, x: -20 },
        animate: { opacity: 1, x: 0 },
        exit: { opacity: 0, x: 20 },
        transition: { duration: 0.3 }
      },
      scale: {
        initial: { opacity: 0, scale: 0.9 },
        animate: { opacity: 1, scale: 1 },
        exit: { opacity: 0, scale: 0.9 },
        transition: { duration: 0.3 }
      }
    };

    return animations[type];
  };

  const getClassName = (baseClass: string, variants?: {
    highContrast?: string;
    reducedMotion?: string;
  }) => {
    let className = baseClass;
    
    if (ux.highContrast && variants?.highContrast) {
      className += ` ${variants.highContrast}`;
    }
    
    if (ux.reducedMotion && variants?.reducedMotion) {
      className += ` ${variants.reducedMotion}`;
    }
    
    return className;
  };

  return {
    ...ux,
    getAnimationProps,
    getClassName
  };
};