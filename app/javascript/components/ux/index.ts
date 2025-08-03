// UX Components Index
// This file exports all UX optimization components for easy importing

// Loading States & Performance
export {
  Skeleton,
  ProgressIndicator,
  LoadingSpinner,
  SkeletonCard,
  SkeletonTable,
  PageLoader,
  BrandedLoader,
  usePerformanceMonitoring
} from './LoadingStates';

// Error Handling & Recovery
export {
  ErrorBoundary,
  ErrorDisplay,
  useNetworkErrorHandling,
  OfflineIndicator
} from './ErrorHandling';

// Feedback Systems
export {
  ToastProvider,
  useToast,
  SuccessConfirmation,
  ContextualHelp,
  OnboardingTour,
  FeedbackWidget,
  toast
} from './FeedbackSystems';

// Performance Optimization
export {
  createLazyComponent,
  LazyWrapper,
  OptimizedImage,
  VirtualizedList,
  BundleAnalyzer,
  usePerformanceMetrics,
  CacheManager,
  ResourcePreloader,
  PerformanceMetricsDisplay
} from './PerformanceOptimization';

// Service Worker Management
export {
  useServiceWorker,
  OfflineActionManager,
  ServiceWorkerStatus,
  OfflineActionQueue,
  PWAInstallPrompt
} from './ServiceWorkerManager';

// UX Provider & Integration
export {
  UXProvider,
  useUX,
  AccessibilityPanel,
  useUXIntegration
} from './UXProvider';

// Types
export type {
  LoadingState,
  SkeletonProps,
  AppError,
  ErrorBoundaryState,
  ErrorRecoveryOptions,
  Toast,
  OnboardingStep,
  ContextualHelp,
  PerformanceMetrics,
  BundleStats,
  ServiceWorkerState,
  OfflineAction
} from './LoadingStates';

export type {
  AppError,
  ErrorBoundaryState,
  ErrorRecoveryOptions
} from './ErrorHandling';

export type {
  Toast,
  OnboardingStep,
  ContextualHelp
} from './FeedbackSystems';

export type {
  PerformanceMetrics,
  BundleStats
} from './PerformanceOptimization';

export type {
  ServiceWorkerState,
  OfflineAction
} from './ServiceWorkerManager';