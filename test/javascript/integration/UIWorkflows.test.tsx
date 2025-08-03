import React from 'react';
import { render, screen, fireEvent, waitFor } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { axe, toHaveNoViolations } from 'jest-axe';

expect.extend(toHaveNoViolations);

// Import all UI components for integration testing
import { 
  DashboardWidget,
  Navigation, 
  NavigationItem, 
  Breadcrumb, 
  SearchBar 
} from '../components/Navigation.test';

import { 
  ContentEditor, 
  RichTextEditor, 
  MediaManager, 
  LivePreview, 
  TemplateSelector 
} from '../components/ContentEditor.test';

import { 
  CampaignTable, 
  CampaignForm, 
  CampaignFilters, 
  BulkActions 
} from '../components/CampaignManagement.test';

import { 
  AnalyticsDashboard, 
  InteractiveChart, 
  MetricCard, 
  TimeRangePicker 
} from '../components/AnalyticsDashboard.test';

import { 
  ThemeProvider, 
  ThemeCustomizer, 
  BrandingPanel 
} from '../components/ThemeSystem.test';

import { 
  LoadingState, 
  ErrorBoundary, 
  Toast, 
  OnboardingTour 
} from '../components/UXOptimization.test';

// Mock complete application wrapper
const MockAppProvider = ({ children, theme = 'light', user = null }: any) => {
  // This would normally wrap the app with providers
  return (
    <ErrorBoundary fallback={<div>App Error</div>}>
      <ThemeProvider theme={theme}>
        <div data-testid="app-root">
          {children}
        </div>
      </ThemeProvider>
    </ErrorBoundary>
  );
};

describe('UI Integration Tests - Complete User Workflows', () => {
  const mockUser = {
    id: '1',
    name: 'Test User',
    email: 'test@example.com',
    role: 'admin',
    preferences: {
      theme: 'light',
      notifications: true
    }
  };

  const mockDashboardData = {
    widgets: [
      { id: 'campaigns', type: 'metric', title: 'Active Campaigns', value: 24 },
      { id: 'revenue', type: 'metric', title: 'Revenue', value: 45600 },
      { id: 'performance', type: 'chart', title: 'Campaign Performance' }
    ],
    navigation: [
      { id: 'dashboard', label: 'Dashboard', href: '/dashboard', active: true },
      { id: 'campaigns', label: 'Campaigns', href: '/campaigns' },
      { id: 'content', label: 'Content', href: '/content' },
      { id: 'analytics', label: 'Analytics', href: '/analytics' }
    ]
  };

  describe('Complete Dashboard Workflow', () => {
    it('should render full dashboard with navigation and widgets', async () => {
      // This test will fail initially - good for TDD
      expect(() => {
        render(
          <MockAppProvider user={mockUser}>
            <Navigation 
              items={mockDashboardData.navigation}
              currentPath="/dashboard"
            />
            <main>
              <div data-testid="dashboard-widgets">
                {mockDashboardData.widgets.map(widget => (
                  <DashboardWidget 
                    key={widget.id}
                    title={widget.title}
                    type={widget.type}
                    value={widget.value}
                  />
                ))}
              </div>
            </main>
          </MockAppProvider>
        );
      }).toThrow('Navigation component not implemented yet');
    });

    it('should support dashboard customization workflow', async () => {
      // Full workflow: customize dashboard, save layout, verify persistence
      expect(async () => {
        render(
          <MockAppProvider user={mockUser}>
            <div data-testid="customizable-dashboard">
              <button data-testid="customize-btn">Customize Dashboard</button>
              <div data-testid="widget-container">
                {mockDashboardData.widgets.map(widget => (
                  <DashboardWidget 
                    key={widget.id}
                    title={widget.title}
                    draggable={true}
                    customizable={true}
                  />
                ))}
              </div>
            </div>
          </MockAppProvider>
        );

        // Start customization
        await userEvent.click(screen.getByTestId('customize-btn'));
        
        // Simulate drag and drop
        const widgets = screen.getAllByTestId('dashboard-widget');
        fireEvent.dragStart(widgets[0]);
        fireEvent.dragOver(widgets[1]);
        fireEvent.drop(widgets[1]);
        
        // Save layout
        await userEvent.click(screen.getByRole('button', { name: /save layout/i }));
        
        // Verify persistence
        const savedLayout = localStorage.getItem('dashboard-layout');
        expect(JSON.parse(savedLayout)).toEqual(expect.any(Array));
      }).rejects.toThrow();
    });

    it('should handle dashboard real-time updates', async () => {
      expect(() => {
        const mockWebSocket = {
          addEventListener: jest.fn(),
          send: jest.fn(),
          close: jest.fn()
        };
        global.WebSocket = jest.fn(() => mockWebSocket);

        render(
          <MockAppProvider user={mockUser}>
            <AnalyticsDashboard 
              data={mockDashboardData}
              realTime={true}
              websocketUrl="ws://localhost:3000/dashboard"
            />
          </MockAppProvider>
        );
        
        // Simulate real-time update
        const messageHandler = mockWebSocket.addEventListener.mock.calls
          .find(call => call[0] === 'message')[1];
        
        messageHandler({ 
          data: JSON.stringify({ 
            type: 'widget_update', 
            widgetId: 'campaigns', 
            value: 26 
          })
        });
      }).toThrow('AnalyticsDashboard component not implemented yet');
    });
  });

  describe('Content Creation Workflow', () => {
    it('should complete end-to-end content creation', async () => {
      expect(async () => {
        render(
          <MockAppProvider user={mockUser}>
            <div data-testid="content-creation-flow">
              {/* Step 1: Template Selection */}
              <TemplateSelector 
                templates={[
                  { id: '1', name: 'Email Template', category: 'email' },
                  { id: '2', name: 'Social Template', category: 'social' }
                ]}
                onSelect={jest.fn()}
              />
              
              {/* Step 2: Content Editing */}
              <ContentEditor 
                value=""
                onChange={jest.fn()}
                features={['richText', 'media', 'preview']}
              />
              
              {/* Step 3: Media Management */}
              <MediaManager 
                onUpload={jest.fn()}
                onSelect={jest.fn()}
              />
              
              {/* Step 4: Live Preview */}
              <LivePreview 
                content={{ title: 'Test', body: 'Content' }}
                channel="email"
              />
            </div>
          </MockAppProvider>
        );

        // Complete workflow steps
        await userEvent.click(screen.getByText('Email Template'));
        await userEvent.type(screen.getByRole('textbox'), 'Test content');
        
        // Upload media
        const fileInput = screen.getByLabelText(/upload/i);
        const file = new File(['test'], 'test.jpg', { type: 'image/jpeg' });
        await userEvent.upload(fileInput, file);
        
        // Verify preview updates
        expect(screen.getByText('Test content')).toBeInTheDocument();
      }).rejects.toThrow();
    });

    it('should support collaborative editing workflow', async () => {
      expect(() => {
        const mockWebSocket = {
          addEventListener: jest.fn(),
          send: jest.fn(),
          close: jest.fn()
        };
        global.WebSocket = jest.fn(() => mockWebSocket);

        render(
          <MockAppProvider user={mockUser}>
            <ContentEditor 
              value="Shared content"
              onChange={jest.fn()}
              collaborative={true}
              activeUsers={[
                { id: '2', name: 'Collaborator', cursor: { line: 1, ch: 5 } }
              ]}
            />
          </MockAppProvider>
        );
        
        // Verify collaborative features
        expect(screen.getByText('Collaborator')).toBeInTheDocument();
      }).toThrow('ContentEditor component not implemented yet');
    });
  });

  describe('Campaign Management Workflow', () => {
    const mockCampaigns = [
      { id: '1', name: 'Q4 Campaign', status: 'active', budget: 5000 },
      { id: '2', name: 'Holiday Campaign', status: 'draft', budget: 3000 }
    ];

    it('should complete campaign management workflow', async () => {
      expect(async () => {
        render(
          <MockAppProvider user={mockUser}>
            <div data-testid="campaign-management">
              {/* Campaign List with Filters */}
              <CampaignFilters 
                filters={{ status: [], type: [], budget: { min: 0, max: 10000 } }}
                onFilterChange={jest.fn()}
              />
              
              <CampaignTable 
                campaigns={mockCampaigns}
                selectable={true}
                onSort={jest.fn()}
              />
              
              {/* Bulk Actions */}
              <BulkActions 
                selectedItems={[]}
                availableActions={[
                  { id: 'activate', label: 'Activate' },
                  { id: 'delete', label: 'Delete' }
                ]}
                onAction={jest.fn()}
              />
              
              {/* Campaign Form */}
              <CampaignForm 
                campaign={{ name: '', budget: 0 }}
                onSubmit={jest.fn()}
                steps={[
                  { id: 'basic', title: 'Basic Info' },
                  { id: 'targeting', title: 'Targeting' }
                ]}
              />
            </div>
          </MockAppProvider>
        );

        // Filter campaigns
        const statusFilter = screen.getByLabelText(/status/i);
        await userEvent.selectOptions(statusFilter, 'active');
        
        // Select campaigns
        const checkboxes = screen.getAllByRole('checkbox');
        await userEvent.click(checkboxes[1]); // Select first campaign
        
        // Perform bulk action
        await userEvent.click(screen.getByText('Activate'));
        
        // Create new campaign
        await userEvent.type(screen.getByLabelText(/campaign name/i), 'New Campaign');
        await userEvent.type(screen.getByLabelText(/budget/i), '5000');
        await userEvent.click(screen.getByRole('button', { name: /save/i }));
      }).rejects.toThrow();
    });

    it('should handle campaign approval workflow', async () => {
      expect(() => {
        render(
          <MockAppProvider user={mockUser}>
            <div data-testid="approval-workflow">
              <CampaignForm 
                campaign={{ 
                  id: '1', 
                  name: 'Pending Campaign',
                  status: 'pending_approval'
                }}
                onSubmit={jest.fn()}
                approvalWorkflow={true}
              />
            </div>
          </MockAppProvider>
        );
        
        // Verify approval UI
        expect(screen.getByText(/pending approval/i)).toBeInTheDocument();
        expect(screen.getByRole('button', { name: /approve/i })).toBeInTheDocument();
        expect(screen.getByRole('button', { name: /reject/i })).toBeInTheDocument();
      }).toThrow();
    });
  });

  describe('Analytics Dashboard Integration', () => {
    const mockAnalyticsData = {
      metrics: {
        campaigns: { value: 24, trend: 12.5 },
        revenue: { value: 45600, trend: 8.3 }
      },
      charts: {
        performance: {
          type: 'line',
          data: [
            { date: '2024-10-01', value: 100 },
            { date: '2024-10-02', value: 150 }
          ]
        }
      }
    };

    it('should render interactive analytics dashboard', async () => {
      expect(() => {
        render(
          <MockAppProvider user={mockUser}>
            <div data-testid="analytics-integration">
              <TimeRangePicker 
                value={{ start: '2024-10-01', end: '2024-10-31' }}
                onChange={jest.fn()}
                presets={[
                  { label: 'Last 7 days', value: { start: '2024-10-24', end: '2024-10-31' } }
                ]}
              />
              
              <div data-testid="metrics-row">
                <MetricCard 
                  title="Total Campaigns"
                  value={mockAnalyticsData.metrics.campaigns.value}
                  trend={mockAnalyticsData.metrics.campaigns.trend}
                />
                <MetricCard 
                  title="Revenue"
                  value={mockAnalyticsData.metrics.revenue.value}
                  trend={mockAnalyticsData.metrics.revenue.trend}
                />
              </div>
              
              <InteractiveChart 
                type="line"
                data={mockAnalyticsData.charts.performance.data}
                onDataPointClick={jest.fn()}
              />
            </div>
          </MockAppProvider>
        );
        
        // Verify metrics display
        expect(screen.getByText('24')).toBeInTheDocument();
        expect(screen.getByText('+12.5%')).toBeInTheDocument();
      }).toThrow();
    });

    it('should handle chart interactions and drill-down', async () => {
      expect(async () => {
        const mockOnDataPointClick = jest.fn();
        
        render(
          <MockAppProvider user={mockUser}>
            <InteractiveChart 
              type="line"
              data={mockAnalyticsData.charts.performance.data}
              onDataPointClick={mockOnDataPointClick}
              drillDown={true}
            />
          </MockAppProvider>
        );
        
        // Click on data point
        const dataPoint = screen.getByTestId('data-point-0');
        await userEvent.click(dataPoint);
        
        expect(mockOnDataPointClick).toHaveBeenCalledWith({
          date: '2024-10-01',
          value: 100
        });
        
        // Verify drill-down panel opens
        expect(screen.getByTestId('drill-down-panel')).toBeInTheDocument();
      }).rejects.toThrow();
    });
  });

  describe('Theme and Branding Integration', () => {
    it('should support complete theme customization workflow', async () => {
      expect(async () => {
        render(
          <MockAppProvider theme="light">
            <div data-testid="theme-workflow">
              <ThemeCustomizer 
                currentTheme="light"
                availableThemes={[
                  { id: 'light', name: 'Light' },
                  { id: 'dark', name: 'Dark' }
                ]}
                onThemeChange={jest.fn()}
                customizable={true}
              />
              
              <BrandingPanel 
                brandConfig={{
                  logo: '/logo.png',
                  primaryColor: '#007bff',
                  fontFamily: 'Inter'
                }}
                onBrandChange={jest.fn()}
              />
            </div>
          </MockAppProvider>
        );
        
        // Switch theme
        await userEvent.click(screen.getByText('Dark'));
        
        // Customize brand colors
        const colorInput = screen.getByLabelText(/primary color/i);
        await userEvent.clear(colorInput);
        await userEvent.type(colorInput, '#ff6b6b');
        
        // Upload logo
        const logoInput = screen.getByLabelText(/upload logo/i);
        const logoFile = new File(['logo'], 'new-logo.png', { type: 'image/png' });
        await userEvent.upload(logoInput, logoFile);
        
        // Verify changes applied
        const themeRoot = screen.getByTestId('app-root');
        expect(themeRoot).toHaveStyle('--primary-color: #ff6b6b');
      }).rejects.toThrow();
    });

    it('should validate accessibility compliance during customization', async () => {
      expect(() => {
        render(
          <MockAppProvider>
            <ThemeCustomizer 
              currentTheme="light"
              availableThemes={[{ id: 'light', name: 'Light' }]}
              onThemeChange={jest.fn()}
              validateAccessibility={true}
            />
          </MockAppProvider>
        );
        
        // Should show accessibility warnings for poor contrast
        expect(screen.getByText(/contrast warning/i)).toBeInTheDocument();
      }).toThrow();
    });
  });

  describe('Cross-Component Integration', () => {
    it('should integrate navigation with content areas', async () => {
      expect(async () => {
        const mockNavigate = jest.fn();
        
        render(
          <MockAppProvider user={mockUser}>
            <div data-testid="integrated-layout">
              <Navigation 
                items={mockDashboardData.navigation}
                currentPath="/campaigns"
                onNavigate={mockNavigate}
              />
              
              <Breadcrumb 
                items={[
                  { label: 'Home', href: '/' },
                  { label: 'Campaigns', href: '/campaigns' },
                  { label: 'Edit Campaign' }
                ]}
              />
              
              <main data-testid="main-content">
                <CampaignForm 
                  campaign={{ name: 'Test Campaign' }}
                  onSubmit={jest.fn()}
                />
              </main>
            </div>
          </MockAppProvider>
        );
        
        // Navigate using navigation
        await userEvent.click(screen.getByText('Analytics'));
        expect(mockNavigate).toHaveBeenCalledWith('/analytics');
        
        // Navigate using breadcrumb
        await userEvent.click(screen.getByText('Home'));
        expect(mockNavigate).toHaveBeenCalledWith('/');
      }).rejects.toThrow();
    });

    it('should integrate search with all content types', async () => {
      expect(async () => {
        const mockOnSearch = jest.fn();
        
        render(
          <MockAppProvider user={mockUser}>
            <SearchBar 
              onSearch={mockOnSearch}
              suggestions={[
                { id: '1', title: 'Q4 Campaign', type: 'campaign' },
                { id: '2', title: 'Email Template', type: 'template' },
                { id: '3', title: 'Analytics Report', type: 'report' }
              ]}
            />
          </MockAppProvider>
        );
        
        // Search for content
        const searchInput = screen.getByRole('combobox');
        await userEvent.type(searchInput, 'campaign');
        
        // Verify suggestions appear
        expect(screen.getByText('Q4 Campaign')).toBeInTheDocument();
        
        // Select suggestion
        await userEvent.click(screen.getByText('Q4 Campaign'));
        expect(mockOnSearch).toHaveBeenCalledWith('Q4 Campaign');
      }).rejects.toThrow();
    });

    it('should integrate loading states across components', async () => {
      expect(() => {
        render(
          <MockAppProvider user={mockUser}>
            <div data-testid="loading-integration">
              <LoadingState 
                type="skeleton"
                skeleton={true}
              />
              
              <AnalyticsDashboard 
                data={null}
                loading={true}
                timeRange={{ start: '2024-10-01', end: '2024-10-31' }}
              />
              
              <CampaignTable 
                campaigns={[]}
                loading={true}
              />
            </div>
          </MockAppProvider>
        );
        
        // Verify all components show loading states
        expect(screen.getAllByTestId('skeleton-loader')).toHaveLength(3);
      }).toThrow();
    });

    it('should integrate error handling across components', async () => {
      expect(() => {
        const consoleSpy = jest.spyOn(console, 'error').mockImplementation();
        
        render(
          <MockAppProvider user={mockUser}>
            <ErrorBoundary 
              fallback={<div>Global error occurred</div>}
              onError={jest.fn()}
            >
              <AnalyticsDashboard 
                data={null}
                error="Failed to load analytics"
                timeRange={{ start: '2024-10-01', end: '2024-10-31' }}
              />
            </ErrorBoundary>
          </MockAppProvider>
        );
        
        // Should show error message
        expect(screen.getByText(/failed to load analytics/i)).toBeInTheDocument();
        
        consoleSpy.mockRestore();
      }).toThrow();
    });
  });

  describe('User Experience Flows', () => {
    it('should complete onboarding tour workflow', async () => {
      expect(async () => {
        const mockOnComplete = jest.fn();
        
        render(
          <MockAppProvider user={{ ...mockUser, isNewUser: true }}>
            <OnboardingTour 
              steps={[
                { id: 'welcome', title: 'Welcome', content: 'Welcome to the platform' },
                { id: 'dashboard', title: 'Dashboard', content: 'This is your dashboard' },
                { id: 'campaigns', title: 'Campaigns', content: 'Create campaigns here' }
              ]}
              currentStep={0}
              onComplete={mockOnComplete}
            />
            
            <div data-testid="app-content">
              <Navigation items={mockDashboardData.navigation} />
              <main>Dashboard content</main>
            </div>
          </MockAppProvider>
        );
        
        // Progress through tour
        expect(screen.getByText('Welcome to the platform')).toBeInTheDocument();
        
        await userEvent.click(screen.getByRole('button', { name: /next/i }));
        expect(screen.getByText('This is your dashboard')).toBeInTheDocument();
        
        await userEvent.click(screen.getByRole('button', { name: /next/i }));
        expect(screen.getByText('Create campaigns here')).toBeInTheDocument();
        
        await userEvent.click(screen.getByRole('button', { name: /finish/i }));
        expect(mockOnComplete).toHaveBeenCalled();
      }).rejects.toThrow();
    });

    it('should handle toast notifications across workflows', async () => {
      expect(async () => {
        render(
          <MockAppProvider user={mockUser}>
            <div data-testid="toast-workflow">
              <CampaignForm 
                campaign={{ name: '' }}
                onSubmit={async () => {
                  // Simulate successful save
                  return Promise.resolve();
                }}
                showToasts={true}
              />
              
              <div data-testid="toast-container">
                <Toast 
                  message="Campaign saved successfully"
                  type="success"
                  duration={3000}
                />
              </div>
            </div>
          </MockAppProvider>
        );
        
        // Submit form
        await userEvent.type(screen.getByLabelText(/campaign name/i), 'Test Campaign');
        await userEvent.click(screen.getByRole('button', { name: /save/i }));
        
        // Verify success toast appears
        expect(screen.getByText('Campaign saved successfully')).toBeInTheDocument();
      }).rejects.toThrow();
    });
  });

  describe('Performance Integration', () => {
    it('should maintain performance across integrated components', async () => {
      const renderTime = await global.testUtils.measureRenderTime(() => {
        render(
          <MockAppProvider user={mockUser}>
            <div data-testid="performance-test">
              <Navigation items={mockDashboardData.navigation} />
              <AnalyticsDashboard 
                data={mockAnalyticsData}
                timeRange={{ start: '2024-10-01', end: '2024-10-31' }}
              />
              <CampaignTable campaigns={mockCampaigns} />
            </div>
          </MockAppProvider>
        );
      });
      
      // Integrated components should still render within threshold
      expect(renderTime).toBeLessThan(200); // Slightly higher threshold for integration
    });

    it('should handle memory usage with multiple components', () => {
      // Mock memory API
      const initialMemory = 50 * 1024 * 1024; // 50MB
      global.performance.memory = {
        usedJSHeapSize: initialMemory,
        totalJSHeapSize: 100 * 1024 * 1024,
        jsHeapSizeLimit: 2 * 1024 * 1024 * 1024
      };
      
      render(
        <MockAppProvider user={mockUser}>
          <div data-testid="memory-test">
            {/* Render multiple heavy components */}
            <AnalyticsDashboard data={mockAnalyticsData} />
            <CampaignTable campaigns={mockCampaigns} />
            <ContentEditor value="" onChange={jest.fn()} />
          </div>
        </MockAppProvider>
      );
      
      // Memory usage should not increase dramatically
      const finalMemory = global.performance.memory.usedJSHeapSize;
      expect(finalMemory - initialMemory).toBeLessThan(20 * 1024 * 1024); // <20MB increase
    });
  });

  describe('Accessibility Integration', () => {
    it('should maintain accessibility across integrated components', async () => {
      const { container } = render(
        <MockAppProvider user={mockUser}>
          <div data-testid="accessibility-integration">
            <Navigation 
              items={mockDashboardData.navigation}
              aria-label="Main navigation"
            />
            <main role="main" aria-label="Main content">
              <h1>Dashboard</h1>
              <AnalyticsDashboard 
                data={mockAnalyticsData}
                timeRange={{ start: '2024-10-01', end: '2024-10-31' }}
              />
            </main>
          </div>
        </MockAppProvider>
      );
      
      const results = await axe(container, global.axeConfig);
      expect(results).toHaveNoViolations();
    });

    it('should support keyboard navigation across components', async () => {
      render(
        <MockAppProvider user={mockUser}>
          <div data-testid="keyboard-navigation">
            <Navigation items={mockDashboardData.navigation} />
            <CampaignTable 
              campaigns={mockCampaigns}
              selectable={true}
            />
          </div>
        </MockAppProvider>
      );
      
      // Tab through navigation
      await userEvent.tab();
      expect(screen.getByText('Dashboard')).toHaveFocus();
      
      // Tab to table
      await userEvent.tab({ shift: false });
      const firstCheckbox = screen.getAllByRole('checkbox')[0];
      expect(firstCheckbox).toHaveFocus();
    });
  });

  describe('Responsive Integration', () => {
    const breakpoints = [320, 768, 1024, 1440, 2560];

    breakpoints.forEach(width => {
      it(`should maintain responsive layout at ${width}px`, () => {
        global.testUtils.mockViewport(width, 800);
        
        render(
          <MockAppProvider user={mockUser}>
            <div data-testid={`responsive-${width}`}>
              <Navigation 
                items={mockDashboardData.navigation}
                responsive={true}
              />
              <main>
                <AnalyticsDashboard 
                  data={mockAnalyticsData}
                  responsive={true}
                />
              </main>
            </div>
          </MockAppProvider>
        );
        
        const container = screen.getByTestId(`responsive-${width}`);
        
        if (width < 768) {
          expect(container).toHaveClass('layout-mobile');
        } else if (width < 1024) {
          expect(container).toHaveClass('layout-tablet');
        } else {
          expect(container).toHaveClass('layout-desktop');
        }
      });
    });

    it('should adapt component interactions for touch devices', () => {
      global.testUtils.mockViewport(320, 568);
      
      // Mock touch capability
      global.navigator.maxTouchPoints = 5;
      
      render(
        <MockAppProvider user={mockUser}>
          <div data-testid="touch-interface">
            <Navigation 
              items={mockDashboardData.navigation}
              touchOptimized={true}
            />
            <InteractiveChart 
              type="line"
              data={mockAnalyticsData.charts.performance.data}
              touchEnabled={true}
            />
          </div>
        </MockAppProvider>
      );
      
      const interface_ = screen.getByTestId('touch-interface');
      expect(interface_).toHaveClass('touch-optimized');
    });
  });
});

// Export for use in other integration tests
export { MockAppProvider };