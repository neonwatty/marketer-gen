import React from 'react';
import { motion, AnimatePresence } from 'framer-motion';

// Types for loading states
export interface LoadingState {
  isLoading: boolean;
  progress?: number;
  message?: string;
  estimate?: number;
  showCancel?: boolean;
  onCancel?: () => void;
}

export interface SkeletonProps {
  className?: string;
  variant?: 'text' | 'rectangular' | 'circular' | 'button';
  width?: string | number;
  height?: string | number;
  animation?: 'pulse' | 'wave' | 'none';
}

// Skeleton Loading Component
export const Skeleton: React.FC<SkeletonProps> = ({
  className = '',
  variant = 'text',
  width,
  height,
  animation = 'pulse'
}) => {
  const baseClasses = 'bg-gray-200 dark:bg-gray-700';
  
  const variantClasses = {
    text: 'h-4 rounded',
    rectangular: 'rounded-lg',
    circular: 'rounded-full',
    button: 'h-10 rounded-lg'
  };

  const animationClasses = {
    pulse: 'animate-pulse',
    wave: 'animate-wave',
    none: ''
  };

  const style = {
    width: width || (variant === 'text' ? '100%' : undefined),
    height: height || (variant === 'circular' ? width : undefined)
  };

  return (
    <div
      className={`${baseClasses} ${variantClasses[variant]} ${animationClasses[animation]} ${className}`}
      style={style}
      role="progressbar"
      aria-label="Loading content"
    />
  );
};

// Progress Indicator Component
export const ProgressIndicator: React.FC<{
  progress: number;
  showPercentage?: boolean;
  variant?: 'linear' | 'circular';
  size?: 'sm' | 'md' | 'lg';
  color?: 'primary' | 'secondary' | 'success' | 'warning' | 'danger';
  label?: string;
  estimate?: number;
}> = ({
  progress,
  showPercentage = true,
  variant = 'linear',
  size = 'md',
  color = 'primary',
  label,
  estimate
}) => {
  const sizeClasses = {
    sm: variant === 'linear' ? 'h-1' : 'w-6 h-6',
    md: variant === 'linear' ? 'h-2' : 'w-8 h-8',
    lg: variant === 'linear' ? 'h-3' : 'w-12 h-12'
  };

  const colorClasses = {
    primary: 'bg-blue-600',
    secondary: 'bg-gray-600',
    success: 'bg-green-600',
    warning: 'bg-yellow-600',
    danger: 'bg-red-600'
  };

  const formatTime = (seconds: number) => {
    if (seconds < 60) {return `${seconds}s`;}
    const minutes = Math.floor(seconds / 60);
    const remainingSeconds = seconds % 60;
    return `${minutes}m ${remainingSeconds}s`;
  };

  if (variant === 'circular') {
    const circumference = 2 * Math.PI * 16;
    const strokeDashoffset = circumference - (progress / 100) * circumference;

    return (
      <div className="flex flex-col items-center space-y-2">
        {label && <span className="text-sm font-medium text-gray-700 dark:text-gray-300">{label}</span>}
        <div className={`relative ${sizeClasses[size]}`}>
          <svg
            className="transform -rotate-90 w-full h-full"
            viewBox="0 0 36 36"
            role="progressbar"
            aria-valuenow={progress}
            aria-valuemin={0}
            aria-valuemax={100}
          >
            <path
              className="stroke-gray-200 dark:stroke-gray-700"
              strokeWidth="3"
              fill="none"
              d="M18 2.0845 a 15.9155 15.9155 0 0 1 0 31.831 a 15.9155 15.9155 0 0 1 0 -31.831"
            />
            <motion.path
              className={`stroke-current ${colorClasses[color]}`}
              strokeWidth="3"
              strokeLinecap="round"
              fill="none"
              d="M18 2.0845 a 15.9155 15.9155 0 0 1 0 31.831 a 15.9155 15.9155 0 0 1 0 -31.831"
              initial={{ strokeDasharray: `${circumference} ${circumference}`, strokeDashoffset: circumference }}
              animate={{ strokeDashoffset }}
              transition={{ duration: 0.3, ease: "easeInOut" }}
            />
          </svg>
          {showPercentage && (
            <div className="absolute inset-0 flex items-center justify-center">
              <span className="text-xs font-semibold">{Math.round(progress)}%</span>
            </div>
          )}
        </div>
        {estimate && (
          <span className="text-xs text-gray-500 dark:text-gray-400">
            ~{formatTime(Math.round((estimate * (100 - progress)) / 100))} remaining
          </span>
        )}
      </div>
    );
  }

  return (
    <div className="w-full space-y-2">
      {(label || showPercentage || estimate) && (
        <div className="flex justify-between items-center">
          {label && <span className="text-sm font-medium text-gray-700 dark:text-gray-300">{label}</span>}
          <div className="flex items-center space-x-2 text-sm text-gray-500 dark:text-gray-400">
            {showPercentage && <span>{Math.round(progress)}%</span>}
            {estimate && (
              <span>~{formatTime(Math.round((estimate * (100 - progress)) / 100))} left</span>
            )}
          </div>
        </div>
      )}
      <div className={`w-full bg-gray-200 dark:bg-gray-700 rounded-full ${sizeClasses[size]}`}>
        <motion.div
          className={`${sizeClasses[size]} ${colorClasses[color]} rounded-full transition-all duration-300 ease-out`}
          initial={{ width: 0 }}
          animate={{ width: `${progress}%` }}
          role="progressbar"
          aria-valuenow={progress}
          aria-valuemin={0}
          aria-valuemax={100}
        />
      </div>
    </div>
  );
};

// Loading Spinner Component
export const LoadingSpinner: React.FC<{
  size?: 'sm' | 'md' | 'lg' | 'xl';
  color?: 'primary' | 'secondary' | 'white';
  label?: string;
}> = ({ size = 'md', color = 'primary', label }) => {
  const sizeClasses = {
    sm: 'w-4 h-4',
    md: 'w-6 h-6',
    lg: 'w-8 h-8',
    xl: 'w-12 h-12'
  };

  const colorClasses = {
    primary: 'text-blue-600',
    secondary: 'text-gray-600',
    white: 'text-white'
  };

  return (
    <div className="flex flex-col items-center space-y-2">
      <motion.div
        className={`${sizeClasses[size]} ${colorClasses[color]}`}
        animate={{ rotate: 360 }}
        transition={{ duration: 1, repeat: Infinity, ease: "linear" }}
        role="status"
        aria-label={label || "Loading"}
      >
        <svg fill="none" viewBox="0 0 24 24">
          <circle
            className="opacity-25"
            cx="12"
            cy="12"
            r="10"
            stroke="currentColor"
            strokeWidth="4"
          />
          <path
            className="opacity-75"
            fill="currentColor"
            d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"
          />
        </svg>
      </motion.div>
      {label && (
        <span className="text-sm text-gray-600 dark:text-gray-400">{label}</span>
      )}
    </div>
  );
};

// Skeleton Layout Components
export const SkeletonCard: React.FC<{ className?: string }> = ({ className = '' }) => (
  <div className={`p-4 border border-gray-200 dark:border-gray-700 rounded-lg space-y-3 ${className}`}>
    <Skeleton variant="rectangular" height={12} className="w-3/4" />
    <Skeleton variant="text" />
    <Skeleton variant="text" className="w-5/6" />
    <div className="flex space-x-2 pt-2">
      <Skeleton variant="button" className="w-20" />
      <Skeleton variant="button" className="w-16" />
    </div>
  </div>
);

export const SkeletonTable: React.FC<{ rows?: number; columns?: number }> = ({ 
  rows = 5, 
  columns = 4 
}) => (
  <div className="space-y-3">
    {/* Header */}
    <div className="grid gap-4" style={{ gridTemplateColumns: `repeat(${columns}, 1fr)` }}>
      {Array.from({ length: columns }).map((_, i) => (
        <Skeleton key={i} variant="text" height={8} className="w-3/4" />
      ))}
    </div>
    {/* Rows */}
    {Array.from({ length: rows }).map((_, rowIndex) => (
      <div key={rowIndex} className="grid gap-4" style={{ gridTemplateColumns: `repeat(${columns}, 1fr)` }}>
        {Array.from({ length: columns }).map((_, colIndex) => (
          <Skeleton key={colIndex} variant="text" />
        ))}
      </div>
    ))}
  </div>
);

// Page Loading Component
export const PageLoader: React.FC<{
  message?: string;
  showProgress?: boolean;
  progress?: number;
}> = ({ message = "Loading...", showProgress = false, progress = 0 }) => (
  <motion.div
    initial={{ opacity: 0 }}
    animate={{ opacity: 1 }}
    exit={{ opacity: 0 }}
    className="fixed inset-0 bg-white dark:bg-gray-900 bg-opacity-80 dark:bg-opacity-80 backdrop-blur-sm z-50 flex items-center justify-center"
  >
    <div className="text-center space-y-4">
      <LoadingSpinner size="xl" />
      <p className="text-lg font-medium text-gray-700 dark:text-gray-300">{message}</p>
      {showProgress && (
        <div className="w-64">
          <ProgressIndicator progress={progress} />
        </div>
      )}
    </div>
  </motion.div>
);

// Branded Loading Animation
export const BrandedLoader: React.FC<{
  brandColor?: string;
  message?: string;
}> = ({ brandColor = '#3B82F6', message }) => (
  <div className="flex flex-col items-center space-y-4">
    <div className="relative">
      <motion.div
        className="w-16 h-16 border-4 border-gray-200 dark:border-gray-700 rounded-full"
        style={{ borderTopColor: brandColor }}
        animate={{ rotate: 360 }}
        transition={{ duration: 1, repeat: Infinity, ease: "linear" }}
      />
      <motion.div
        className="absolute inset-2 rounded-full"
        style={{ backgroundColor: brandColor }}
        animate={{
          scale: [1, 1.2, 1],
          opacity: [0.7, 0.3, 0.7]
        }}
        transition={{
          duration: 2,
          repeat: Infinity,
          ease: "easeInOut"
        }}
      />
    </div>
    {message && (
      <motion.p
        className="text-sm font-medium text-gray-600 dark:text-gray-400"
        animate={{ opacity: [0.5, 1, 0.5] }}
        transition={{ duration: 2, repeat: Infinity, ease: "easeInOut" }}
      >
        {message}
      </motion.p>
    )}
  </div>
);

// Performance Monitoring Hook
export const usePerformanceMonitoring = () => {
  React.useEffect(() => {
    // Monitor loading performance
    const observer = new PerformanceObserver((list) => {
      list.getEntries().forEach((entry) => {
        if (entry.entryType === 'navigation') {
          const navigationEntry = entry as PerformanceNavigationTiming;
          console.log('Page Load Performance:', {
            loadTime: navigationEntry.loadEventEnd - navigationEntry.loadEventStart,
            domReady: navigationEntry.domContentLoadedEventEnd - navigationEntry.domContentLoadedEventStart,
            firstPaint: navigationEntry.responseEnd - navigationEntry.requestStart
          });
        }
      });
    });

    observer.observe({ entryTypes: ['navigation', 'paint', 'largest-contentful-paint'] });

    return () => observer.disconnect();
  }, []);
};