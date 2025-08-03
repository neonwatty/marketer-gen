import React, { Component, ErrorInfo, ReactNode } from 'react';
import { motion } from 'framer-motion';

// Error types
export interface AppError {
  name: string;
  message: string;
  stack?: string;
  code?: string;
  statusCode?: number;
  timestamp: Date;
  userAgent: string;
  url: string;
}

export interface ErrorBoundaryState {
  hasError: boolean;
  error?: AppError;
  errorId?: string;
}

export interface ErrorRecoveryOptions {
  canRetry?: boolean;
  canReport?: boolean;
  canGoBack?: boolean;
  canRefresh?: boolean;
  showDetails?: boolean;
  customActions?: Array<{
    label: string;
    action: () => void;
    variant?: 'primary' | 'secondary' | 'danger';
  }>;
}

// Error Boundary Component
export class ErrorBoundary extends Component<{
  children: ReactNode;
  fallback?: React.ComponentType<{
    error: AppError;
    retry: () => void;
    resetError: () => void;
  }>;
  onError?: (error: AppError, errorInfo: ErrorInfo) => void;
  recovery?: ErrorRecoveryOptions;
}, ErrorBoundaryState> {
  constructor(props: any) {
    super(props);
    this.state = { hasError: false };
  }

  static getDerivedStateFromError(error: Error): ErrorBoundaryState {
    const appError: AppError = {
      name: error.name,
      message: error.message,
      stack: error.stack,
      timestamp: new Date(),
      userAgent: navigator.userAgent,
      url: window.location.href
    };

    return {
      hasError: true,
      error: appError,
      errorId: `error_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`
    };
  }

  componentDidCatch(error: Error, errorInfo: ErrorInfo) {
    const appError: AppError = {
      name: error.name,
      message: error.message,
      stack: error.stack,
      timestamp: new Date(),
      userAgent: navigator.userAgent,
      url: window.location.href
    };

    // Log error to monitoring service
    this.logError(appError, errorInfo);

    // Call onError prop if provided
    if (this.props.onError) {
      this.props.onError(appError, errorInfo);
    }
  }

  private logError = async (error: AppError, errorInfo?: ErrorInfo) => {
    try {
      // Send error to logging service
      await fetch('/api/errors', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          error,
          errorInfo,
          errorId: this.state.errorId
        })
      });
    } catch (loggingError) {
      console.error('Failed to log error:', loggingError);
    }
  };

  private retry = () => {
    this.setState({ hasError: false, error: undefined, errorId: undefined });
  };

  private resetError = () => {
    this.setState({ hasError: false, error: undefined, errorId: undefined });
  };

  render() {
    if (this.state.hasError && this.state.error) {
      if (this.props.fallback) {
        const FallbackComponent = this.props.fallback;
        return (
          <FallbackComponent
            error={this.state.error}
            retry={this.retry}
            resetError={this.resetError}
          />
        );
      }

      return (
        <ErrorDisplay
          error={this.state.error}
          errorId={this.state.errorId}
          recovery={this.props.recovery}
          onRetry={this.retry}
          onReset={this.resetError}
        />
      );
    }

    return this.props.children;
  }
}

// Error Display Component
export const ErrorDisplay: React.FC<{
  error: AppError;
  errorId?: string;
  recovery?: ErrorRecoveryOptions;
  onRetry?: () => void;
  onReset?: () => void;
  variant?: 'full' | 'compact' | 'inline';
}> = ({
  error,
  errorId,
  recovery = {},
  onRetry,
  onReset,
  variant = 'full'
}) => {
  const [showDetails, setShowDetails] = React.useState(false);
  const [isReporting, setIsReporting] = React.useState(false);

  const {
    canRetry = true,
    canReport = true,
    canGoBack = true,
    canRefresh = true,
    showDetails: showDetailsOption = true,
    customActions = []
  } = recovery;

  const handleReport = async () => {
    setIsReporting(true);
    try {
      await fetch('/api/errors/report', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          errorId,
          userFeedback: 'User reported error'
        })
      });
      // Show success message
    } catch (reportError) {
      console.error('Failed to report error:', reportError);
    } finally {
      setIsReporting(false);
    }
  };

  const getErrorSolution = (error: AppError): string => {
    if (error.statusCode === 404) {
      return "The page you're looking for doesn't exist. Try going back or searching for what you need.";
    }
    if (error.statusCode === 403) {
      return "You don't have permission to access this resource. Contact your administrator if you believe this is incorrect.";
    }
    if (error.statusCode === 500) {
      return "We're experiencing technical difficulties. Please try again in a few moments or contact support.";
    }
    if (error.name === 'NetworkError') {
      return "Check your internet connection and try again. If the problem persists, our servers might be temporarily unavailable.";
    }
    return "An unexpected error occurred. Please try refreshing the page or contact support if the problem continues.";
  };

  if (variant === 'inline') {
    return (
      <motion.div
        initial={{ opacity: 0, y: -10 }}
        animate={{ opacity: 1, y: 0 }}
        className="bg-red-50 dark:bg-red-900/20 border border-red-200 dark:border-red-800 rounded-lg p-4"
      >
        <div className="flex items-start space-x-3">
          <div className="flex-shrink-0">
            <svg className="w-5 h-5 text-red-400" fill="currentColor" viewBox="0 0 20 20">
              <path fillRule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zM8.707 7.293a1 1 0 00-1.414 1.414L8.586 10l-1.293 1.293a1 1 0 101.414 1.414L10 11.414l1.293 1.293a1 1 0 001.414-1.414L11.414 10l1.293-1.293a1 1 0 00-1.414-1.414L10 8.586 8.707 7.293z" clipRule="evenodd" />
            </svg>
          </div>
          <div className="flex-1">
            <p className="text-sm font-medium text-red-800 dark:text-red-200">
              {error.message}
            </p>
            <p className="text-sm text-red-700 dark:text-red-300 mt-1">
              {getErrorSolution(error)}
            </p>
            {canRetry && onRetry && (
              <button
                onClick={onRetry}
                className="mt-2 text-sm font-medium text-red-800 dark:text-red-200 hover:text-red-900 dark:hover:text-red-100"
              >
                Try again
              </button>
            )}
          </div>
        </div>
      </motion.div>
    );
  }

  if (variant === 'compact') {
    return (
      <motion.div
        initial={{ opacity: 0, scale: 0.95 }}
        animate={{ opacity: 1, scale: 1 }}
        className="bg-white dark:bg-gray-800 border border-gray-200 dark:border-gray-700 rounded-lg p-6 max-w-md mx-auto"
      >
        <div className="text-center">
          <div className="w-16 h-16 mx-auto mb-4 bg-red-100 dark:bg-red-900/30 rounded-full flex items-center justify-center">
            <svg className="w-8 h-8 text-red-600 dark:text-red-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-2.5L13.732 4c-.77-.833-1.964-.833-2.732 0L3.732 16.5c-.77.833.192 2.5 1.732 2.5z" />
            </svg>
          </div>
          <h3 className="text-lg font-semibold text-gray-900 dark:text-gray-100 mb-2">
            Something went wrong
          </h3>
          <p className="text-gray-600 dark:text-gray-400 mb-4">
            {getErrorSolution(error)}
          </p>
          <div className="flex justify-center space-x-3">
            {canRetry && onRetry && (
              <button
                onClick={onRetry}
                className="px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 transition-colors"
              >
                Try Again
              </button>
            )}
            {canGoBack && (
              <button
                onClick={() => window.history.back()}
                className="px-4 py-2 bg-gray-300 dark:bg-gray-600 text-gray-700 dark:text-gray-300 rounded-lg hover:bg-gray-400 dark:hover:bg-gray-500 transition-colors"
              >
                Go Back
              </button>
            )}
          </div>
        </div>
      </motion.div>
    );
  }

  return (
    <motion.div
      initial={{ opacity: 0 }}
      animate={{ opacity: 1 }}
      className="min-h-screen bg-gray-50 dark:bg-gray-900 flex items-center justify-center p-4"
    >
      <div className="bg-white dark:bg-gray-800 rounded-lg shadow-lg max-w-2xl w-full p-8">
        <div className="text-center mb-8">
          <div className="w-20 h-20 mx-auto mb-6 bg-red-100 dark:bg-red-900/30 rounded-full flex items-center justify-center">
            <svg className="w-10 h-10 text-red-600 dark:text-red-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-2.5L13.732 4c-.77-.833-1.964-.833-2.732 0L3.732 16.5c-.77.833.192 2.5 1.732 2.5z" />
            </svg>
          </div>
          <h1 className="text-2xl font-bold text-gray-900 dark:text-gray-100 mb-4">
            Oops! Something went wrong
          </h1>
          <p className="text-gray-600 dark:text-gray-400 mb-6">
            {getErrorSolution(error)}
          </p>
        </div>

        {/* Error Details */}
        {showDetailsOption && (
          <div className="mb-6">
            <button
              onClick={() => setShowDetails(!showDetails)}
              className="flex items-center text-sm text-gray-500 dark:text-gray-400 hover:text-gray-700 dark:hover:text-gray-300"
            >
              <svg
                className={`w-4 h-4 mr-2 transform transition-transform ${showDetails ? 'rotate-90' : ''}`}
                fill="none"
                stroke="currentColor"
                viewBox="0 0 24 24"
              >
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 5l7 7-7 7" />
              </svg>
              {showDetails ? 'Hide' : 'Show'} technical details
            </button>
            
            {showDetails && (
              <motion.div
                initial={{ opacity: 0, height: 0 }}
                animate={{ opacity: 1, height: 'auto' }}
                className="mt-4 p-4 bg-gray-100 dark:bg-gray-700 rounded-lg text-sm font-mono overflow-auto"
              >
                <div className="space-y-2">
                  <div><strong>Error:</strong> {error.name}</div>
                  <div><strong>Message:</strong> {error.message}</div>
                  {errorId && <div><strong>Error ID:</strong> {errorId}</div>}
                  <div><strong>Time:</strong> {error.timestamp.toISOString()}</div>
                  <div><strong>URL:</strong> {error.url}</div>
                  {error.stack && (
                    <div>
                      <strong>Stack trace:</strong>
                      <pre className="mt-2 text-xs text-gray-600 dark:text-gray-400 whitespace-pre-wrap">
                        {error.stack}
                      </pre>
                    </div>
                  )}
                </div>
              </motion.div>
            )}
          </div>
        )}

        {/* Action Buttons */}
        <div className="flex flex-wrap justify-center gap-3">
          {canRetry && onRetry && (
            <button
              onClick={onRetry}
              className="px-6 py-3 bg-blue-600 text-white rounded-lg hover:bg-blue-700 transition-colors"
            >
              Try Again
            </button>
          )}
          
          {canRefresh && (
            <button
              onClick={() => window.location.reload()}
              className="px-6 py-3 bg-green-600 text-white rounded-lg hover:bg-green-700 transition-colors"
            >
              Refresh Page
            </button>
          )}
          
          {canGoBack && (
            <button
              onClick={() => window.history.back()}
              className="px-6 py-3 bg-gray-300 dark:bg-gray-600 text-gray-700 dark:text-gray-300 rounded-lg hover:bg-gray-400 dark:hover:bg-gray-500 transition-colors"
            >
              Go Back
            </button>
          )}
          
          {canReport && (
            <button
              onClick={handleReport}
              disabled={isReporting}
              className="px-6 py-3 bg-yellow-600 text-white rounded-lg hover:bg-yellow-700 transition-colors disabled:opacity-50"
            >
              {isReporting ? 'Reporting...' : 'Report Issue'}
            </button>
          )}

          {customActions.map((action, index) => (
            <button
              key={index}
              onClick={action.action}
              className={`px-6 py-3 rounded-lg transition-colors ${
                action.variant === 'danger'
                  ? 'bg-red-600 text-white hover:bg-red-700'
                  : action.variant === 'secondary'
                  ? 'bg-gray-300 dark:bg-gray-600 text-gray-700 dark:text-gray-300 hover:bg-gray-400 dark:hover:bg-gray-500'
                  : 'bg-blue-600 text-white hover:bg-blue-700'
              }`}
            >
              {action.label}
            </button>
          ))}
        </div>

        {/* Contact Support */}
        <div className="mt-8 pt-6 border-t border-gray-200 dark:border-gray-700 text-center">
          <p className="text-sm text-gray-500 dark:text-gray-400">
            Need help? {' '}
            <a
              href="/support"
              className="text-blue-600 dark:text-blue-400 hover:text-blue-700 dark:hover:text-blue-300"
            >
              Contact our support team
            </a>
            {errorId && (
              <>
                {' '} and reference error ID: <code className="bg-gray-100 dark:bg-gray-700 px-2 py-1 rounded text-xs">{errorId}</code>
              </>
            )}
          </p>
        </div>
      </div>
    </motion.div>
  );
};

// Network Error Handling Hook
export const useNetworkErrorHandling = () => {
  const [isOnline, setIsOnline] = React.useState(navigator.onLine);
  const [networkError, setNetworkError] = React.useState<string | null>(null);

  React.useEffect(() => {
    const handleOnline = () => {
      setIsOnline(true);
      setNetworkError(null);
    };

    const handleOffline = () => {
      setIsOnline(false);
      setNetworkError('You are currently offline. Some features may not be available.');
    };

    window.addEventListener('online', handleOnline);
    window.addEventListener('offline', handleOffline);

    return () => {
      window.removeEventListener('online', handleOnline);
      window.removeEventListener('offline', handleOffline);
    };
  }, []);

  return { isOnline, networkError };
};

// Offline Mode Component
export const OfflineIndicator: React.FC = () => {
  const { isOnline, networkError } = useNetworkErrorHandling();

  if (isOnline) {return null;}

  return (
    <motion.div
      initial={{ opacity: 0, y: -100 }}
      animate={{ opacity: 1, y: 0 }}
      exit={{ opacity: 0, y: -100 }}
      className="fixed top-0 left-0 right-0 bg-yellow-500 text-white p-3 text-center z-50"
    >
      <div className="flex items-center justify-center space-x-2">
        <svg className="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 8v4m0 4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
        </svg>
        <span className="font-medium">{networkError}</span>
      </div>
    </motion.div>
  );
};