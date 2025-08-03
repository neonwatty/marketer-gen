import React, { useState, useEffect } from 'react';
import {
  UXProvider,
  useUX,
  useToast,
  LoadingSpinner,
  Skeleton,
  ProgressIndicator,
  ErrorBoundary,
  SuccessConfirmation,
  ContextualHelp,
  OnboardingTour,
  OptimizedImage,
  PerformanceMetricsDisplay,
  ServiceWorkerStatus,
  AccessibilityPanel,
  useUXIntegration,
  createLazyComponent,
  LazyWrapper
} from '../ux';

// Example of lazy-loaded component
const LazyAnalyticsDashboard = createLazyComponent(
  () => import('../AnalyticsDashboard'),
  () => (
    <div className="p-8 text-center">
      <Skeleton className="h-64 w-full mb-4" />
      <p>Loading Analytics Dashboard...</p>
    </div>
  )
);

// Main example component demonstrating UX integration
const UXIntegrationExample: React.FC = () => {
  const [isLoading, setIsLoading] = useState(false);
  const [progress, setProgress] = useState(0);
  const [showSuccess, setShowSuccess] = useState(false);
  const [showOnboarding, setShowOnboarding] = useState(false);
  const [currentOnboardingStep, setCurrentOnboardingStep] = useState(0);
  const [showAccessibilityPanel, setShowAccessibilityPanel] = useState(false);
  const [activeHelp, setActiveHelp] = useState<string | null>(null);

  const { addToast } = useToast();
  const ux = useUXIntegration();

  // Example data loading simulation
  const handleDataLoad = async () => {
    setIsLoading(true);
    setProgress(0);

    try {
      // Simulate progressive loading
      for (let i = 0; i <= 100; i += 10) {
        setProgress(i);
        await new Promise(resolve => setTimeout(resolve, 200));
      }

      addToast({
        type: 'success',
        title: 'Data Loaded Successfully',
        message: 'All campaign data has been loaded and is ready for use.',
        action: {
          label: 'View Details',
          onClick: () => console.log('View details clicked')
        }
      });

      setShowSuccess(true);
    } catch (error) {
      addToast({
        type: 'error',
        title: 'Loading Failed',
        message: 'Failed to load campaign data. Please try again.',
        action: {
          label: 'Retry',
          onClick: handleDataLoad
        }
      });
    } finally {
      setIsLoading(false);
    }
  };

  // Onboarding tour steps
  const onboardingSteps = [
    {
      id: 'step-1',
      target: '#main-dashboard',
      title: 'Welcome to Your Dashboard',
      content: 'This is your main dashboard where you can see all your campaign metrics and performance data.',
      position: 'bottom' as const
    },
    {
      id: 'step-2',
      target: '#campaign-creator',
      title: 'Create New Campaigns',
      content: 'Click here to start creating new marketing campaigns with our AI-powered tools.',
      position: 'left' as const
    },
    {
      id: 'step-3',
      target: '#analytics-section',
      title: 'Analytics & Insights',
      content: 'View detailed analytics and get insights about your campaign performance.',
      position: 'top' as const
    }
  ];

  // Contextual help data
  const helpData = {
    'dashboard-help': {
      id: 'dashboard-help',
      target: '#main-dashboard',
      title: 'Dashboard Overview',
      content: 'Your dashboard provides a comprehensive view of all your marketing activities, campaign performance, and key metrics.',
      placement: 'right' as const
    },
    'campaign-help': {
      id: 'campaign-help',
      target: '#campaign-creator',
      title: 'Campaign Creation',
      content: 'Our AI-powered campaign creator helps you build effective marketing campaigns by analyzing your brand guidelines and target audience.',
      placement: 'bottom' as const
    }
  };

  const handleOnboardingNext = () => {
    if (currentOnboardingStep < onboardingSteps.length - 1) {
      setCurrentOnboardingStep(currentOnboardingStep + 1);
    } else {
      setShowOnboarding(false);
      addToast({
        type: 'success',
        title: 'Onboarding Complete!',
        message: 'You\'re all set to start creating amazing campaigns.'
      });
    }
  };

  const handleOnboardingPrev = () => {
    if (currentOnboardingStep > 0) {
      setCurrentOnboardingStep(currentOnboardingStep - 1);
    }
  };

  const handleOnboardingSkip = () => {
    setShowOnboarding(false);
    addToast({
      type: 'info',
      title: 'Onboarding Skipped',
      message: 'You can restart the tour anytime from the help menu.'
    });
  };

  return (
    <div className="min-h-screen bg-gray-50 dark:bg-gray-900">
      {/* Main Content */}
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        {/* Header */}
        <div className="mb-8">
          <div className="flex justify-between items-center">
            <div>
              <h1 className="text-3xl font-bold text-gray-900 dark:text-gray-100">
                UX Integration Example
              </h1>
              <p className="text-gray-600 dark:text-gray-400 mt-2">
                Demonstrating comprehensive UX optimization features
              </p>
            </div>
            
            <div className="flex space-x-4">
              <button
                onClick={() => setShowOnboarding(true)}
                className={ux.getClassName(
                  'px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 transition-colors',
                  {
                    highContrast: 'border-2 border-black',
                    reducedMotion: 'transition-none'
                  }
                )}
              >
                Start Tour
              </button>
              
              <button
                onClick={() => setShowAccessibilityPanel(true)}
                className="px-4 py-2 bg-gray-600 text-white rounded-lg hover:bg-gray-700 transition-colors"
              >
                Accessibility
              </button>
            </div>
          </div>
        </div>

        {/* Dashboard Section */}
        <div id="main-dashboard" className="mb-8">
          <div className="bg-white dark:bg-gray-800 rounded-lg shadow-lg p-6">
            <div className="flex justify-between items-center mb-6">
              <h2 className="text-xl font-semibold text-gray-900 dark:text-gray-100">
                Dashboard Overview
              </h2>
              
              <button
                onClick={() => setActiveHelp(activeHelp === 'dashboard-help' ? null : 'dashboard-help')}
                className="text-blue-600 hover:text-blue-700"
                aria-label="Get help with dashboard"
              >
                <svg className="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M8.228 9c.549-1.165 2.03-2 3.772-2 2.21 0 4 1.343 4 3 0 1.4-1.278 2.575-3.006 2.907-.542.104-.994.54-.994 1.093m0 3h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
                </svg>
              </button>
            </div>

            {/* Sample Dashboard Content */}
            <div className="grid grid-cols-1 md:grid-cols-3 gap-6 mb-6">
              <div className="bg-blue-50 dark:bg-blue-900/20 p-4 rounded-lg">
                <h3 className="font-medium text-blue-900 dark:text-blue-100">Active Campaigns</h3>
                <p className="text-2xl font-bold text-blue-600 dark:text-blue-400">12</p>
              </div>
              
              <div className="bg-green-50 dark:bg-green-900/20 p-4 rounded-lg">
                <h3 className="font-medium text-green-900 dark:text-green-100">Conversion Rate</h3>
                <p className="text-2xl font-bold text-green-600 dark:text-green-400">3.2%</p>
              </div>
              
              <div className="bg-purple-50 dark:bg-purple-900/20 p-4 rounded-lg">
                <h3 className="font-medium text-purple-900 dark:text-purple-100">Total Revenue</h3>
                <p className="text-2xl font-bold text-purple-600 dark:text-purple-400">$24,531</p>
              </div>
            </div>

            {/* Loading Example */}
            <div className="mb-6">
              <div className="flex justify-between items-center mb-4">
                <h3 className="text-lg font-medium text-gray-900 dark:text-gray-100">
                  Data Loading Example
                </h3>
                <button
                  onClick={handleDataLoad}
                  disabled={isLoading}
                  className={`px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 transition-colors disabled:opacity-50 ${
                    isLoading ? 'btn-loading' : ''
                  }`}
                >
                  {isLoading ? 'Loading...' : 'Load Data'}
                </button>
              </div>

              {isLoading && (
                <div className="space-y-4">
                  <ProgressIndicator
                    progress={progress}
                    label="Loading campaign data..."
                    estimate={10}
                  />
                  <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                    <Skeleton className="h-32" />
                    <Skeleton className="h-32" />
                  </div>
                </div>
              )}
            </div>
          </div>
        </div>

        {/* Campaign Creator Section */}
        <div id="campaign-creator" className="mb-8">
          <div className="bg-white dark:bg-gray-800 rounded-lg shadow-lg p-6">
            <div className="flex justify-between items-center mb-6">
              <h2 className="text-xl font-semibold text-gray-900 dark:text-gray-100">
                Campaign Creator
              </h2>
              
              <button
                onClick={() => setActiveHelp(activeHelp === 'campaign-help' ? null : 'campaign-help')}
                className="text-blue-600 hover:text-blue-700"
                aria-label="Get help with campaign creation"
              >
                <svg className="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M8.228 9c.549-1.165 2.03-2 3.772-2 2.21 0 4 1.343 4 3 0 1.4-1.278 2.575-3.006 2.907-.542.104-.994.54-.994 1.093m0 3h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
                </svg>
              </button>
            </div>

            <div className="text-center py-8">
              <OptimizedImage
                src="/images/campaign-placeholder.jpg"
                alt="Campaign creation interface"
                width={300}
                height={200}
                className="mx-auto rounded-lg mb-4"
                placeholder="blur"
                loading="lazy"
              />
              <p className="text-gray-600 dark:text-gray-400">
                AI-powered campaign creation tools coming soon...
              </p>
            </div>
          </div>
        </div>

        {/* Analytics Section */}
        <div id="analytics-section" className="mb-8">
          <ErrorBoundary
            fallback={({ error, retry }) => (
              <div className="bg-red-50 dark:bg-red-900/20 border border-red-200 dark:border-red-800 rounded-lg p-6">
                <h3 className="text-lg font-semibold text-red-800 dark:text-red-200 mb-2">
                  Failed to Load Analytics
                </h3>
                <p className="text-red-600 dark:text-red-400 mb-4">
                  {error.message}
                </p>
                <button
                  onClick={retry}
                  className="px-4 py-2 bg-red-600 text-white rounded-lg hover:bg-red-700"
                >
                  Try Again
                </button>
              </div>
            )}
          >
            <LazyWrapper
              fallback={
                <div className="bg-white dark:bg-gray-800 rounded-lg shadow-lg p-6">
                  <Skeleton className="h-8 w-48 mb-4" />
                  <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                    <Skeleton className="h-64" />
                    <Skeleton className="h-64" />
                  </div>
                </div>
              }
            >
              <LazyAnalyticsDashboard />
            </LazyWrapper>
          </ErrorBoundary>
        </div>

        {/* Performance Metrics (Development Only) */}
        {process.env.NODE_ENV === 'development' && ux.showPerformanceMetrics && (
          <div className="mb-8">
            <div className="bg-white dark:bg-gray-800 rounded-lg shadow-lg p-6">
              <h2 className="text-xl font-semibold text-gray-900 dark:text-gray-100 mb-6">
                Performance Metrics
              </h2>
              <PerformanceMetricsDisplay />
            </div>
          </div>
        )}
      </div>

      {/* Success Confirmation Modal */}
      <SuccessConfirmation
        isVisible={showSuccess}
        title="Data Loaded Successfully!"
        message="Your campaign data has been loaded and is ready for analysis."
        onClose={() => setShowSuccess(false)}
        showConfetti={true}
      />

      {/* Onboarding Tour */}
      <OnboardingTour
        steps={onboardingSteps}
        isActive={showOnboarding}
        currentStep={currentOnboardingStep}
        onNext={handleOnboardingNext}
        onPrev={handleOnboardingPrev}
        onSkip={handleOnboardingSkip}
        onComplete={() => {
          setShowOnboarding(false);
          addToast({
            type: 'success',
            title: 'Welcome Aboard!',
            message: 'You\'re ready to create amazing campaigns.'
          });
        }}
      />

      {/* Contextual Help */}
      {activeHelp && helpData[activeHelp] && (
        <ContextualHelp
          help={helpData[activeHelp]}
          isVisible={true}
          onClose={() => setActiveHelp(null)}
        />
      )}

      {/* Accessibility Panel */}
      <AccessibilityPanel
        isOpen={showAccessibilityPanel}
        onClose={() => setShowAccessibilityPanel(false)}
      />

      {/* Service Worker Status */}
      <ServiceWorkerStatus />
    </div>
  );
};

// Main App Component with UX Provider
const UXIntegrationApp: React.FC = () => {
  return (
    <UXProvider>
      <UXIntegrationExample />
    </UXProvider>
  );
};

export default UXIntegrationApp;