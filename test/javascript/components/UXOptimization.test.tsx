import React from 'react';
import { render, screen, fireEvent, waitFor } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { axe, toHaveNoViolations } from 'jest-axe';

expect.extend(toHaveNoViolations);

// Mock UX optimization components that don't exist yet - will fail initially (TDD)
const LoadingState = ({ 
  type = 'spinner', 
  message, 
  skeleton = false,
  progress,
  ...props 
}: any) => {
  throw new Error('LoadingState component not implemented yet');
};

const ErrorBoundary = ({ 
  children, 
  fallback,
  onError,
  recovery = false,
  ...props 
}: any) => {
  throw new Error('ErrorBoundary component not implemented yet');
};

const Toast = ({ 
  message, 
  type = 'info',
  duration = 5000,
  actions = [],
  onDismiss,
  ...props 
}: any) => {
  throw new Error('Toast component not implemented yet');
};

const ProgressIndicator = ({ 
  value, 
  max = 100,
  label,
  showPercentage = true,
  indeterminate = false,
  ...props 
}: any) => {
  throw new Error('ProgressIndicator component not implemented yet');
};

const SkeletonLoader = ({ 
  variant = 'text',
  width,
  height,
  animation = 'pulse',
  ...props 
}: any) => {
  throw new Error('SkeletonLoader component not implemented yet');
};

const ContextualHelp = ({ 
  content, 
  trigger,
  placement = 'top',
  interactive = false,
  ...props 
}: any) => {
  throw new Error('ContextualHelp component not implemented yet');
};

const OnboardingTour = ({ 
  steps, 
  onComplete,
  onSkip,
  currentStep = 0,
  ...props 
}: any) => {
  throw new Error('OnboardingTour component not implemented yet');
};

const PerformanceMonitor = ({ 
  children, 
  thresholds,
  onMetricsUpdate,
  reportingEnabled = false,
  ...props 
}: any) => {
  throw new Error('PerformanceMonitor component not implemented yet');
};

describe('User Experience Optimization', () => {
  describe('Loading States', () => {
    it('should render spinner loading state', () => {
      render(
        <LoadingState 
          type="spinner"
          message="Loading content..."
        />
      );
      
      expect(screen.getByRole('status')).toBeInTheDocument();
      expect(screen.getByText('Loading content...')).toBeInTheDocument();
    });

    it('should render skeleton loading state', () => {
      render(
        <LoadingState 
          type="skeleton"
          skeleton={true}
        />
      );
      
      expect(screen.getByTestId('skeleton-loader')).toBeInTheDocument();
      expect(screen.getByTestId('skeleton-loader')).toHaveClass('skeleton-pulse');
    });

    it('should show progress bar with percentage', () => {
      render(
        <LoadingState 
          type="progress"
          progress={65}
          message="Uploading file..."
        />
      );
      
      expect(screen.getByRole('progressbar')).toHaveAttribute('aria-valuenow', '65');
      expect(screen.getByText('65%')).toBeInTheDocument();
      expect(screen.getByText('Uploading file...')).toBeInTheDocument();
    });

    it('should support indeterminate progress', () => {
      render(
        <LoadingState 
          type="progress"
          indeterminate={true}
          message="Processing..."
        />
      );
      
      const progressBar = screen.getByRole('progressbar');
      expect(progressBar).not.toHaveAttribute('aria-valuenow');
      expect(progressBar).toHaveClass('progress-indeterminate');
    });

    it('should handle loading timeout', async () => {
      const mockOnTimeout = jest.fn();
      
      render(
        <LoadingState 
          type="spinner"
          message="Loading..."
          timeout={1000}
          onTimeout={mockOnTimeout}
        />
      );
      
      await waitFor(() => {
        expect(mockOnTimeout).toHaveBeenCalled();
      }, { timeout: 1200 });
    });

    it('should provide loading cancellation', async () => {
      const mockOnCancel = jest.fn();
      
      render(
        <LoadingState 
          type="progress"
          message="Uploading..."
          cancellable={true}
          onCancel={mockOnCancel}
        />
      );
      
      const cancelButton = screen.getByRole('button', { name: /cancel/i });
      await userEvent.click(cancelButton);
      
      expect(mockOnCancel).toHaveBeenCalled();
    });
  });

  describe('Error Boundaries & Recovery', () => {
    const ThrowError = ({ shouldThrow }: { shouldThrow: boolean }) => {
      if (shouldThrow) {
        throw new Error('Test error');
      }
      return <div>Working component</div>;
    };

    it('should catch and display errors', () => {
      const consoleSpy = jest.spyOn(console, 'error').mockImplementation();
      
      render(
        <ErrorBoundary fallback={<div>Something went wrong</div>}>
          <ThrowError shouldThrow={true} />
        </ErrorBoundary>
      );
      
      expect(screen.getByText('Something went wrong')).toBeInTheDocument();
      expect(screen.queryByText('Working component')).not.toBeInTheDocument();
      
      consoleSpy.mockRestore();
    });

    it('should call error handler', () => {
      const consoleSpy = jest.spyOn(console, 'error').mockImplementation();
      const mockOnError = jest.fn();
      
      render(
        <ErrorBoundary 
          fallback={<div>Error occurred</div>}
          onError={mockOnError}
        >
          <ThrowError shouldThrow={true} />
        </ErrorBoundary>
      );
      
      expect(mockOnError).toHaveBeenCalledWith(
        expect.any(Error),
        expect.any(Object)
      );
      
      consoleSpy.mockRestore();
    });

    it('should provide error recovery option', async () => {
      const consoleSpy = jest.spyOn(console, 'error').mockImplementation();
      
      const RecoverableError = () => (
        <div>
          <div>Something went wrong</div>
          <button onClick={() => window.location.reload()}>Try again</button>
        </div>
      );
      
      render(
        <ErrorBoundary 
          fallback={<RecoverableError />}
          recovery={true}
        >
          <ThrowError shouldThrow={true} />
        </ErrorBoundary>
      );
      
      expect(screen.getByRole('button', { name: /try again/i })).toBeInTheDocument();
      
      consoleSpy.mockRestore();
    });

    it('should render children when no error', () => {
      render(
        <ErrorBoundary fallback={<div>Error</div>}>
          <ThrowError shouldThrow={false} />
        </ErrorBoundary>
      );
      
      expect(screen.getByText('Working component')).toBeInTheDocument();
      expect(screen.queryByText('Error')).not.toBeInTheDocument();
    });

    it('should provide error details in development', () => {
      const originalEnv = process.env.NODE_ENV;
      process.env.NODE_ENV = 'development';
      
      const consoleSpy = jest.spyOn(console, 'error').mockImplementation();
      
      render(
        <ErrorBoundary 
          fallback={<div>Error with details</div>}
          showDetails={true}
        >
          <ThrowError shouldThrow={true} />
        </ErrorBoundary>
      );
      
      expect(screen.getByText(/error details/i)).toBeInTheDocument();
      expect(screen.getByText(/test error/i)).toBeInTheDocument();
      
      process.env.NODE_ENV = originalEnv;
      consoleSpy.mockRestore();
    });
  });

  describe('Toast Notifications', () => {
    it('should render toast with message', () => {
      render(
        <Toast 
          message="Operation completed successfully"
          type="success"
        />
      );
      
      expect(screen.getByText('Operation completed successfully')).toBeInTheDocument();
      expect(screen.getByTestId('toast')).toHaveClass('toast-success');
    });

    it('should auto-dismiss after duration', async () => {
      const mockOnDismiss = jest.fn();
      
      render(
        <Toast 
          message="Auto-dismiss toast"
          duration={1000}
          onDismiss={mockOnDismiss}
        />
      );
      
      await waitFor(() => {
        expect(mockOnDismiss).toHaveBeenCalled();
      }, { timeout: 1200 });
    });

    it('should support different toast types', () => {
      const types = ['success', 'error', 'warning', 'info'];
      
      types.forEach(type => {
        render(
          <Toast 
            message={`${type} message`}
            type={type}
            data-testid={`toast-${type}`}
          />
        );
        
        expect(screen.getByTestId(`toast-${type}`)).toHaveClass(`toast-${type}`);
      });
    });

    it('should render toast with actions', async () => {
      const mockAction = jest.fn();
      const actions = [
        { label: 'Undo', onClick: mockAction },
        { label: 'View Details', onClick: jest.fn() }
      ];
      
      render(
        <Toast 
          message="Action required"
          actions={actions}
        />
      );
      
      expect(screen.getByRole('button', { name: 'Undo' })).toBeInTheDocument();
      expect(screen.getByRole('button', { name: 'View Details' })).toBeInTheDocument();
      
      await userEvent.click(screen.getByRole('button', { name: 'Undo' }));
      expect(mockAction).toHaveBeenCalled();
    });

    it('should be dismissible manually', async () => {
      const mockOnDismiss = jest.fn();
      
      render(
        <Toast 
          message="Dismissible toast"
          onDismiss={mockOnDismiss}
          dismissible={true}
        />
      );
      
      const dismissButton = screen.getByRole('button', { name: /close|dismiss/i });
      await userEvent.click(dismissButton);
      
      expect(mockOnDismiss).toHaveBeenCalled();
    });

    it('should support rich content', () => {
      const richContent = (
        <div>
          <strong>Upload Complete</strong>
          <br />
          <span>5 files uploaded successfully</span>
        </div>
      );
      
      render(
        <Toast 
          message={richContent}
          type="success"
          richContent={true}
        />
      );
      
      expect(screen.getByText('Upload Complete')).toBeInTheDocument();
      expect(screen.getByText('5 files uploaded successfully')).toBeInTheDocument();
    });

    it('should stack multiple toasts', () => {
      render(
        <div>
          <Toast message="First toast" data-testid="toast-1" />
          <Toast message="Second toast" data-testid="toast-2" />
          <Toast message="Third toast" data-testid="toast-3" />
        </div>
      );
      
      expect(screen.getByTestId('toast-1')).toBeInTheDocument();
      expect(screen.getByTestId('toast-2')).toBeInTheDocument();
      expect(screen.getByTestId('toast-3')).toBeInTheDocument();
      
      // Should be positioned correctly
      expect(screen.getByTestId('toast-1')).toHaveStyle('z-index: 1003');
      expect(screen.getByTestId('toast-2')).toHaveStyle('z-index: 1002');
      expect(screen.getByTestId('toast-3')).toHaveStyle('z-index: 1001');
    });
  });

  describe('Progress Indicators', () => {
    it('should render progress bar with value', () => {
      render(
        <ProgressIndicator 
          value={75}
          max={100}
          label="Upload progress"
        />
      );
      
      const progressBar = screen.getByRole('progressbar');
      expect(progressBar).toHaveAttribute('aria-valuenow', '75');
      expect(progressBar).toHaveAttribute('aria-valuemax', '100');
      expect(screen.getByText('75%')).toBeInTheDocument();
      expect(screen.getByText('Upload progress')).toBeInTheDocument();
    });

    it('should support indeterminate progress', () => {
      render(
        <ProgressIndicator 
          indeterminate={true}
          label="Processing..."
        />
      );
      
      const progressBar = screen.getByRole('progressbar');
      expect(progressBar).not.toHaveAttribute('aria-valuenow');
      expect(progressBar).toHaveClass('progress-indeterminate');
    });

    it('should show custom progress text', () => {
      render(
        <ProgressIndicator 
          value={50}
          label="File upload"
          customText="2.5 MB of 5 MB"
          showPercentage={false}
        />
      );
      
      expect(screen.getByText('2.5 MB of 5 MB')).toBeInTheDocument();
      expect(screen.queryByText('50%')).not.toBeInTheDocument();
    });

    it('should support different sizes', () => {
      const sizes = ['small', 'medium', 'large'];
      
      sizes.forEach(size => {
        render(
          <ProgressIndicator 
            value={50}
            size={size}
            data-testid={`progress-${size}`}
          />
        );
        
        expect(screen.getByTestId(`progress-${size}`)).toHaveClass(`progress-${size}`);
      });
    });

    it('should animate progress changes', async () => {
      const { rerender } = render(
        <ProgressIndicator 
          value={25}
          animated={true}
          data-testid="animated-progress"
        />
      );
      
      expect(screen.getByTestId('animated-progress')).toHaveClass('progress-animated');
      
      rerender(
        <ProgressIndicator 
          value={75}
          animated={true}
          data-testid="animated-progress"
        />
      );
      
      // Should animate to new value
      await waitFor(() => {
        expect(screen.getByRole('progressbar')).toHaveAttribute('aria-valuenow', '75');
      });
    });

    it('should support step-based progress', () => {
      render(
        <ProgressIndicator 
          steps={['Start', 'Processing', 'Complete']}
          currentStep={1}
          showSteps={true}
        />
      );
      
      expect(screen.getByText('Start')).toBeInTheDocument();
      expect(screen.getByText('Processing')).toBeInTheDocument();
      expect(screen.getByText('Complete')).toBeInTheDocument();
      
      // Current step should be highlighted
      expect(screen.getByText('Processing').closest('.step')).toHaveClass('step-current');
    });
  });

  describe('Skeleton Loaders', () => {
    it('should render text skeleton', () => {
      render(
        <SkeletonLoader 
          variant="text"
          width="200px"
          height="16px"
        />
      );
      
      const skeleton = screen.getByTestId('skeleton-loader');
      expect(skeleton).toHaveClass('skeleton-text');
      expect(skeleton).toHaveStyle('width: 200px; height: 16px');
    });

    it('should render different skeleton variants', () => {
      const variants = ['text', 'rectangle', 'circle', 'avatar'];
      
      variants.forEach(variant => {
        render(
          <SkeletonLoader 
            variant={variant}
            data-testid={`skeleton-${variant}`}
          />
        );
        
        expect(screen.getByTestId(`skeleton-${variant}`)).toHaveClass(`skeleton-${variant}`);
      });
    });

    it('should support different animations', () => {
      const animations = ['pulse', 'wave', 'none'];
      
      animations.forEach(animation => {
        render(
          <SkeletonLoader 
            variant="text"
            animation={animation}
            data-testid={`skeleton-${animation}`}
          />
        );
        
        if (animation !== 'none') {
          expect(screen.getByTestId(`skeleton-${animation}`)).toHaveClass(`skeleton-${animation}`);
        }
      });
    });

    it('should render complex skeleton layouts', () => {
      render(
        <div data-testid="skeleton-layout">
          <SkeletonLoader variant="avatar" width="40px" height="40px" />
          <div>
            <SkeletonLoader variant="text" width="120px" height="16px" />
            <SkeletonLoader variant="text" width="80px" height="14px" />
          </div>
        </div>
      );
      
      const layout = screen.getByTestId('skeleton-layout');
      expect(layout.querySelectorAll('[data-testid="skeleton-loader"]')).toHaveLength(3);
    });

    it('should support responsive skeleton sizes', () => {
      global.testUtils.mockViewport(320, 568);
      
      render(
        <SkeletonLoader 
          variant="rectangle"
          responsive={true}
          data-testid="responsive-skeleton"
        />
      );
      
      expect(screen.getByTestId('responsive-skeleton')).toHaveClass('skeleton-mobile');
    });
  });

  describe('Contextual Help', () => {
    it('should render help tooltip on hover', async () => {
      render(
        <ContextualHelp 
          content="This field is required for campaign creation"
          trigger={<button>Campaign Name</button>}
        />
      );
      
      const trigger = screen.getByRole('button', { name: 'Campaign Name' });
      await userEvent.hover(trigger);
      
      await waitFor(() => {
        expect(screen.getByText('This field is required for campaign creation'))
          .toBeInTheDocument();
      });
    });

    it('should support different placements', async () => {
      const placements = ['top', 'bottom', 'left', 'right'];
      
      for (const placement of placements) {
        render(
          <ContextualHelp 
            content={`Help text ${placement}`}
            trigger={<button>{placement} trigger</button>}
            placement={placement}
          />
        );
        
        const trigger = screen.getByRole('button', { name: `${placement} trigger` });
        await userEvent.hover(trigger);
        
        await waitFor(() => {
          const tooltip = screen.getByText(`Help text ${placement}`).closest('.tooltip');
          expect(tooltip).toHaveClass(`tooltip-${placement}`);
        });
        
        await userEvent.unhover(trigger);
        await waitFor(() => {
          expect(screen.queryByText(`Help text ${placement}`)).not.toBeInTheDocument();
        });
      }
    });

    it('should support interactive help content', async () => {
      const interactiveContent = (
        <div>
          <p>Help content with link</p>
          <a href="/docs">Learn more</a>
        </div>
      );
      
      render(
        <ContextualHelp 
          content={interactiveContent}
          trigger={<button>Help trigger</button>}
          interactive={true}
        />
      );
      
      const trigger = screen.getByRole('button', { name: 'Help trigger' });
      await userEvent.hover(trigger);
      
      await waitFor(() => {
        expect(screen.getByText('Help content with link')).toBeInTheDocument();
        expect(screen.getByRole('link', { name: 'Learn more' })).toBeInTheDocument();
      });
    });

    it('should close on escape key', async () => {
      render(
        <ContextualHelp 
          content="Press escape to close"
          trigger={<button>Help trigger</button>}
          interactive={true}
        />
      );
      
      const trigger = screen.getByRole('button', { name: 'Help trigger' });
      await userEvent.hover(trigger);
      
      await waitFor(() => {
        expect(screen.getByText('Press escape to close')).toBeInTheDocument();
      });
      
      await userEvent.keyboard('{Escape}');
      
      await waitFor(() => {
        expect(screen.queryByText('Press escape to close')).not.toBeInTheDocument();
      });
    });
  });

  describe('Onboarding Tour', () => {
    const mockTourSteps = [
      {
        id: 'welcome',
        title: 'Welcome to the Platform',
        content: 'Let us show you around',
        target: '#welcome-section'
      },
      {
        id: 'dashboard',
        title: 'Your Dashboard',
        content: 'This is where you can see all your campaigns',
        target: '#dashboard'
      },
      {
        id: 'create-campaign',
        title: 'Create Your First Campaign',
        content: 'Click here to create a new campaign',
        target: '#create-button'
      }
    ];

    it('should render tour step', () => {
      render(
        <OnboardingTour 
          steps={mockTourSteps}
          currentStep={0}
          onComplete={jest.fn()}
        />
      );
      
      expect(screen.getByText('Welcome to the Platform')).toBeInTheDocument();
      expect(screen.getByText('Let us show you around')).toBeInTheDocument();
      expect(screen.getByText('Step 1 of 3')).toBeInTheDocument();
    });

    it('should navigate between steps', async () => {
      const { rerender } = render(
        <OnboardingTour 
          steps={mockTourSteps}
          currentStep={0}
          onComplete={jest.fn()}
        />
      );
      
      expect(screen.getByText('Welcome to the Platform')).toBeInTheDocument();
      
      rerender(
        <OnboardingTour 
          steps={mockTourSteps}
          currentStep={1}
          onComplete={jest.fn()}
        />
      );
      
      expect(screen.getByText('Your Dashboard')).toBeInTheDocument();
      expect(screen.getByText('Step 2 of 3')).toBeInTheDocument();
    });

    it('should handle tour completion', async () => {
      const mockOnComplete = jest.fn();
      
      render(
        <OnboardingTour 
          steps={mockTourSteps}
          currentStep={2}
          onComplete={mockOnComplete}
        />
      );
      
      const finishButton = screen.getByRole('button', { name: /finish|complete/i });
      await userEvent.click(finishButton);
      
      expect(mockOnComplete).toHaveBeenCalled();
    });

    it('should allow skipping the tour', async () => {
      const mockOnSkip = jest.fn();
      
      render(
        <OnboardingTour 
          steps={mockTourSteps}
          currentStep={0}
          onSkip={mockOnSkip}
        />
      );
      
      const skipButton = screen.getByRole('button', { name: /skip/i });
      await userEvent.click(skipButton);
      
      expect(mockOnSkip).toHaveBeenCalled();
    });

    it('should highlight target elements', () => {
      // Mock DOM element
      document.body.innerHTML = '<div id="dashboard">Dashboard content</div>';
      
      render(
        <OnboardingTour 
          steps={mockTourSteps}
          currentStep={1}
          onComplete={jest.fn()}
          highlightTarget={true}
        />
      );
      
      const targetElement = document.getElementById('dashboard');
      expect(targetElement).toHaveClass('tour-highlight');
    });

    it('should support tour progress persistence', () => {
      const mockSetItem = jest.spyOn(Storage.prototype, 'setItem');
      
      render(
        <OnboardingTour 
          steps={mockTourSteps}
          currentStep={1}
          onComplete={jest.fn()}
          persistProgress={true}
          tourId="platform-tour"
        />
      );
      
      expect(mockSetItem).toHaveBeenCalledWith('tour-platform-tour-progress', '1');
    });
  });

  describe('Performance Monitoring', () => {
    const mockThresholds = {
      renderTime: 100,
      interactionTime: 50,
      memoryUsage: 100 * 1024 * 1024 // 100MB
    };

    it('should monitor component performance', async () => {
      const mockOnMetricsUpdate = jest.fn();
      
      render(
        <PerformanceMonitor 
          thresholds={mockThresholds}
          onMetricsUpdate={mockOnMetricsUpdate}
        >
          <div>Monitored component</div>
        </PerformanceMonitor>
      );
      
      // Simulate performance entry
      const mockPerformanceEntry = {
        name: 'component-render',
        duration: 75,
        startTime: performance.now()
      };
      
      // Mock performance observer
      const mockObserver = {
        observe: jest.fn(),
        disconnect: jest.fn()
      };
      
      global.PerformanceObserver = jest.fn().mockImplementation((callback) => {
        // Simulate callback with mock entry
        setTimeout(() => callback({ getEntries: () => [mockPerformanceEntry] }), 0);
        return mockObserver;
      });
      
      await waitFor(() => {
        expect(mockOnMetricsUpdate).toHaveBeenCalledWith({
          renderTime: 75,
          withinThreshold: true
        });
      });
    });

    it('should detect performance violations', async () => {
      const mockOnMetricsUpdate = jest.fn();
      
      render(
        <PerformanceMonitor 
          thresholds={mockThresholds}
          onMetricsUpdate={mockOnMetricsUpdate}
          reportViolations={true}
        >
          <div>Slow component</div>
        </PerformanceMonitor>
      );
      
      // Simulate slow performance
      const mockSlowEntry = {
        name: 'component-render',
        duration: 150, // Exceeds threshold
        startTime: performance.now()
      };
      
      global.PerformanceObserver = jest.fn().mockImplementation((callback) => {
        setTimeout(() => callback({ getEntries: () => [mockSlowEntry] }), 0);
        return { observe: jest.fn(), disconnect: jest.fn() };
      });
      
      await waitFor(() => {
        expect(mockOnMetricsUpdate).toHaveBeenCalledWith({
          renderTime: 150,
          withinThreshold: false,
          violation: true
        });
      });
    });

    it('should monitor memory usage', () => {
      // Mock memory API
      global.performance.memory = {
        usedJSHeapSize: 50 * 1024 * 1024, // 50MB
        totalJSHeapSize: 100 * 1024 * 1024,
        jsHeapSizeLimit: 2 * 1024 * 1024 * 1024
      };
      
      const mockOnMetricsUpdate = jest.fn();
      
      render(
        <PerformanceMonitor 
          thresholds={mockThresholds}
          onMetricsUpdate={mockOnMetricsUpdate}
          monitorMemory={true}
        >
          <div>Memory monitored component</div>
        </PerformanceMonitor>
      );
      
      expect(mockOnMetricsUpdate).toHaveBeenCalledWith(
        expect.objectContaining({
          memoryUsage: 50 * 1024 * 1024,
          memoryWithinThreshold: true
        })
      );
    });

    it('should generate performance reports', async () => {
      const mockOnMetricsUpdate = jest.fn();
      
      render(
        <PerformanceMonitor 
          thresholds={mockThresholds}
          onMetricsUpdate={mockOnMetricsUpdate}
          reportingEnabled={true}
          reportInterval={1000}
        >
          <div>Reported component</div>
        </PerformanceMonitor>
      );
      
      await waitFor(() => {
        expect(mockOnMetricsUpdate).toHaveBeenCalledWith(
          expect.objectContaining({
            report: true,
            timestamp: expect.any(Number)
          })
        );
      }, { timeout: 1200 });
    });
  });

  describe('Performance Tests', () => {
    it('should render loading states within 100ms', async () => {
      const renderTime = await global.testUtils.measureRenderTime(() => {
        render(
          <LoadingState 
            type="spinner"
            message="Loading..."
          />
        );
      });
      
      expect(renderTime).toBeLessThan(100);
    });

    it('should render skeleton loaders efficiently', async () => {
      const renderTime = await global.testUtils.measureRenderTime(() => {
        render(
          <div>
            {Array.from({ length: 10 }, (_, i) => (
              <SkeletonLoader key={i} variant="text" />
            ))}
          </div>
        );
      });
      
      expect(renderTime).toBeLessThan(100);
    });

    it('should handle multiple toasts efficiently', async () => {
      const renderTime = await global.testUtils.measureRenderTime(() => {
        render(
          <div>
            {Array.from({ length: 5 }, (_, i) => (
              <Toast key={i} message={`Toast ${i + 1}`} type="info" />
            ))}
          </div>
        );
      });
      
      expect(renderTime).toBeLessThan(100);
    });
  });

  describe('Accessibility', () => {
    it('should have no accessibility violations', async () => {
      const { container } = render(
        <div>
          <LoadingState type="spinner" message="Loading..." />
          <Toast message="Success message" type="success" />
          <ProgressIndicator value={50} label="Progress" />
        </div>
      );
      
      const results = await axe(container, global.axeConfig);
      expect(results).toHaveNoViolations();
    });

    it('should provide proper ARIA labels for loading states', () => {
      render(
        <LoadingState 
          type="spinner"
          message="Loading content..."
          ariaLabel="Content is loading"
        />
      );
      
      const loadingElement = screen.getByRole('status');
      expect(loadingElement).toHaveAttribute('aria-label', 'Content is loading');
    });

    it('should announce toast messages to screen readers', () => {
      render(
        <Toast 
          message="Operation completed"
          type="success"
          announceToScreenReader={true}
        />
      );
      
      expect(screen.getByText('Operation completed'))
        .toHaveAttribute('aria-live', 'polite');
    });

    it('should support keyboard navigation for dismissible toasts', async () => {
      const mockOnDismiss = jest.fn();
      
      render(
        <Toast 
          message="Dismissible toast"
          type="info"
          dismissible={true}
          onDismiss={mockOnDismiss}
        />
      );
      
      const dismissButton = screen.getByRole('button', { name: /close|dismiss/i });
      dismissButton.focus();
      
      await userEvent.keyboard('{Enter}');
      expect(mockOnDismiss).toHaveBeenCalled();
    });

    it('should provide progress information to screen readers', () => {
      render(
        <ProgressIndicator 
          value={75}
          max={100}
          label="File upload progress"
        />
      );
      
      const progressBar = screen.getByRole('progressbar');
      expect(progressBar).toHaveAttribute('aria-label', 'File upload progress');
      expect(progressBar).toHaveAttribute('aria-valuenow', '75');
      expect(progressBar).toHaveAttribute('aria-valuemax', '100');
      expect(progressBar).toHaveAttribute('aria-valuetext', '75%');
    });
  });

  describe('Responsive Design', () => {
    const breakpoints = [320, 768, 1024, 1440, 2560];

    breakpoints.forEach(width => {
      it(`should adapt toast positioning at ${width}px`, () => {
        global.testUtils.mockViewport(width, 800);
        
        render(
          <Toast 
            message="Responsive toast"
            type="info"
            responsive={true}
            data-testid={`toast-${width}`}
          />
        );
        
        const toast = screen.getByTestId(`toast-${width}`);
        
        if (width < 768) {
          expect(toast).toHaveClass('toast-mobile');
        } else {
          expect(toast).toHaveClass('toast-desktop');
        }
      });
    });

    it('should stack toasts vertically on mobile', () => {
      global.testUtils.mockViewport(320, 568);
      
      render(
        <div data-testid="toast-container">
          <Toast message="First toast" data-testid="toast-1" />
          <Toast message="Second toast" data-testid="toast-2" />
        </div>
      );
      
      const container = screen.getByTestId('toast-container');
      expect(container).toHaveClass('toast-container-mobile');
    });

    it('should adapt skeleton sizes for mobile', () => {
      global.testUtils.mockViewport(320, 568);
      
      render(
        <SkeletonLoader 
          variant="text"
          responsive={true}
          data-testid="mobile-skeleton"
        />
      );
      
      expect(screen.getByTestId('mobile-skeleton')).toHaveClass('skeleton-mobile');
    });
  });

  describe('Error Handling', () => {
    it('should handle toast rendering errors gracefully', () => {
      const consoleSpy = jest.spyOn(console, 'error').mockImplementation();
      
      render(
        <Toast 
          message={null}
          type="invalid-type"
          fallbackMessage="Toast error occurred"
        />
      );
      
      expect(screen.getByText('Toast error occurred')).toBeInTheDocument();
      
      consoleSpy.mockRestore();
    });

    it('should handle progress calculation errors', () => {
      render(
        <ProgressIndicator 
          value={NaN}
          max={100}
          label="Invalid progress"
          fallbackValue={0}
        />
      );
      
      const progressBar = screen.getByRole('progressbar');
      expect(progressBar).toHaveAttribute('aria-valuenow', '0');
    });

    it('should handle skeleton rendering failures', () => {
      const consoleSpy = jest.spyOn(console, 'error').mockImplementation();
      
      render(
        <SkeletonLoader 
          variant="invalid-variant"
          fallbackVariant="text"
          data-testid="fallback-skeleton"
        />
      );
      
      expect(screen.getByTestId('fallback-skeleton')).toHaveClass('skeleton-text');
      
      consoleSpy.mockRestore();
    });
  });
});

// Export components for integration tests
export { 
  LoadingState, 
  ErrorBoundary, 
  Toast, 
  ProgressIndicator, 
  SkeletonLoader,
  ContextualHelp,
  OnboardingTour,
  PerformanceMonitor 
};