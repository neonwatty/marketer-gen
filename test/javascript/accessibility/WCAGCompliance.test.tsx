import React from 'react';
import { render, screen, fireEvent, waitFor } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { axe, toHaveNoViolations } from 'jest-axe';

expect.extend(toHaveNoViolations);

// Comprehensive WCAG 2.1 AA compliance testing
describe('WCAG 2.1 AA Compliance Tests', () => {
  // Enhanced axe configuration for comprehensive testing
  const wcagConfig = {
    rules: {
      // Color and Contrast (WCAG 1.4.3, 1.4.6)
      'color-contrast': { enabled: true },
      
      // Keyboard Navigation (WCAG 2.1.1, 2.1.2)
      'tabindex': { enabled: true },
      
      // Focus Management (WCAG 2.4.3, 2.4.7)
      'focus-order-semantics': { enabled: true },
      
      // ARIA and Semantics (WCAG 4.1.2)
      'aria-allowed-attr': { enabled: true },
      'aria-allowed-role': { enabled: true },
      'aria-required-attr': { enabled: true },
      'aria-required-children': { enabled: true },
      'aria-required-parent': { enabled: true },
      'aria-roles': { enabled: true },
      'aria-valid-attr': { enabled: true },
      'aria-valid-attr-value': { enabled: true },
      
      // Form Labels (WCAG 1.3.1, 3.3.2)
      'label': { enabled: true },
      'form-field-multiple-labels': { enabled: true },
      'label-content-name-mismatch': { enabled: true },
      
      // Images and Media (WCAG 1.1.1)
      'image-alt': { enabled: true },
      'image-redundant-alt': { enabled: true },
      'object-alt': { enabled: true },
      'svg-img-alt': { enabled: true },
      
      // Headings and Structure (WCAG 1.3.1, 2.4.6)
      'heading-order': { enabled: true },
      'empty-heading': { enabled: true },
      'p-as-heading': { enabled: true },
      
      // Tables (WCAG 1.3.1)
      'table-duplicate-name': { enabled: true },
      'table-fake-caption': { enabled: true },
      'td-headers-attr': { enabled: true },
      'th-has-data-cells': { enabled: true },
      
      // Language (WCAG 3.1.1, 3.1.2)
      'html-has-lang': { enabled: true },
      'html-lang-valid': { enabled: true },
      'valid-lang': { enabled: true },
      
      // Navigation (WCAG 2.4.1, 2.4.2)
      'bypass': { enabled: true },
      'document-title': { enabled: true },
      'landmark-banner-is-top-level': { enabled: true },
      'landmark-complementary-is-top-level': { enabled: true },
      'landmark-main-is-top-level': { enabled: true },
      'landmark-no-duplicate-banner': { enabled: true },
      'landmark-no-duplicate-contentinfo': { enabled: true },
      'landmark-one-main': { enabled: true },
      'page-has-heading-one': { enabled: true },
      'region': { enabled: true },
      
      // Links (WCAG 2.4.4, 2.4.9)
      'link-name': { enabled: true },
      'link-in-text-block': { enabled: true },
      
      // Input Assistance (WCAG 3.3.1, 3.3.3)
      'duplicate-id': { enabled: true },
      'duplicate-id-active': { enabled: true },
      'duplicate-id-aria': { enabled: true }
    },
    tags: ['wcag2a', 'wcag2aa', 'wcag21aa']
  };

  describe('Dashboard Components Accessibility', () => {
    it('should have no accessibility violations in dashboard widget', async () => {
      const { container } = render(
        <div role="region" aria-labelledby="widget-title">
          <h2 id="widget-title">Campaign Performance</h2>
          <div role="group" aria-label="Performance metrics">
            <div role="img" aria-label="Campaign metrics chart">
              <svg width="200" height="100" aria-hidden="true">
                <rect width="50" height="80" fill="#007bff" />
                <rect width="50" height="60" x="60" fill="#28a745" />
              </svg>
            </div>
            <table role="table" aria-label="Performance data">
              <caption>Campaign performance metrics</caption>
              <thead>
                <tr>
                  <th scope="col">Metric</th>
                  <th scope="col">Value</th>
                  <th scope="col">Change</th>
                </tr>
              </thead>
              <tbody>
                <tr>
                  <th scope="row">Impressions</th>
                  <td>12,500</td>
                  <td aria-label="12.5 percent increase">+12.5%</td>
                </tr>
                <tr>
                  <th scope="row">Clicks</th>
                  <td>350</td>
                  <td aria-label="3.2 percent decrease">-3.2%</td>
                </tr>
              </tbody>
            </table>
          </div>
        </div>
      );
      
      const results = await axe(container, wcagConfig);
      expect(results).toHaveNoViolations();
    });

    it('should have proper focus management in navigation', async () => {
      const { container } = render(
        <nav role="navigation" aria-label="Main navigation">
          <ul role="menubar">
            <li role="none">
              <a href="/dashboard" role="menuitem" aria-current="page">
                Dashboard
              </a>
            </li>
            <li role="none">
              <button 
                role="menuitem" 
                aria-haspopup="true" 
                aria-expanded="false"
                id="campaigns-menu"
              >
                Campaigns
              </button>
              <ul role="menu" aria-labelledby="campaigns-menu" hidden>
                <li role="none">
                  <a href="/campaigns/active" role="menuitem">Active Campaigns</a>
                </li>
                <li role="none">
                  <a href="/campaigns/draft" role="menuitem">Draft Campaigns</a>
                </li>
              </ul>
            </li>
            <li role="none">
              <a href="/analytics" role="menuitem">Analytics</a>
            </li>
          </ul>
        </nav>
      );
      
      const results = await axe(container, wcagConfig);
      expect(results).toHaveNoViolations();
      
      // Test keyboard navigation
      const dashboardLink = screen.getByRole('menuitem', { name: 'Dashboard' });
      const campaignsButton = screen.getByRole('menuitem', { name: 'Campaigns' });
      
      dashboardLink.focus();
      expect(dashboardLink).toHaveFocus();
      
      await userEvent.keyboard('{ArrowRight}');
      expect(campaignsButton).toHaveFocus();
      
      // Test submenu expansion
      await userEvent.keyboard('{Enter}');
      expect(campaignsButton).toHaveAttribute('aria-expanded', 'true');
    });

    it('should provide accessible form controls', async () => {
      const { container } = render(
        <form role="form" aria-labelledby="form-title">
          <h1 id="form-title">Create Campaign</h1>
          
          <fieldset>
            <legend>Basic Information</legend>
            
            <div>
              <label htmlFor="campaign-name">
                Campaign Name <span aria-label="required">*</span>
              </label>
              <input 
                type="text" 
                id="campaign-name" 
                name="campaignName"
                required 
                aria-describedby="name-help name-error"
                aria-invalid="false"
              />
              <div id="name-help">Enter a descriptive name for your campaign</div>
              <div id="name-error" role="alert" aria-live="polite" hidden>
                Campaign name is required
              </div>
            </div>
            
            <div>
              <label htmlFor="campaign-budget">Budget ($)</label>
              <input 
                type="number" 
                id="campaign-budget" 
                name="budget"
                min="0"
                step="100"
                aria-describedby="budget-help"
              />
              <div id="budget-help">Enter your campaign budget in USD</div>
            </div>
            
            <fieldset>
              <legend>Campaign Type</legend>
              <div role="radiogroup" aria-required="true">
                <label>
                  <input type="radio" name="type" value="awareness" required />
                  Brand Awareness
                </label>
                <label>
                  <input type="radio" name="type" value="conversion" required />
                  Conversion
                </label>
                <label>
                  <input type="radio" name="type" value="engagement" required />
                  Engagement
                </label>
              </div>
            </fieldset>
          </fieldset>
          
          <div>
            <button type="submit" aria-describedby="submit-help">
              Create Campaign
            </button>
            <div id="submit-help">Click to create your campaign</div>
          </div>
        </form>
      );
      
      const results = await axe(container, wcagConfig);
      expect(results).toHaveNoViolations();
      
      // Test form validation accessibility
      const nameInput = screen.getByLabelText(/campaign name/i);
      const submitButton = screen.getByRole('button', { name: /create campaign/i });
      
      await userEvent.click(submitButton);
      
      // Should show error message
      const errorMessage = screen.getByRole('alert');
      expect(errorMessage).toBeInTheDocument();
      expect(nameInput).toHaveAttribute('aria-invalid', 'true');
    });
  });

  describe('Color Contrast Compliance', () => {
    it('should meet WCAG AA contrast requirements', async () => {
      const { container } = render(
        <div style={{ backgroundColor: '#ffffff' }}>
          {/* Normal text - 4.5:1 ratio required */}
          <p style={{ color: '#212529', fontSize: '16px' }}>
            This is normal text that should meet AA requirements
          </p>
          
          {/* Large text - 3:1 ratio required */}
          <h1 style={{ color: '#495057', fontSize: '24px', fontWeight: 'bold' }}>
            Large Text Header
          </h1>
          
          {/* Interactive elements */}
          <button 
            style={{ 
              backgroundColor: '#007bff', 
              color: '#ffffff',
              border: '2px solid transparent',
              padding: '8px 16px'
            }}
            onFocus={(e) => {
              e.target.style.outline = '2px solid #0056b3';
              e.target.style.outlineOffset = '2px';
            }}
          >
            Primary Button
          </button>
          
          {/* Focus indicators */}
          <a 
            href="#content" 
            style={{ 
              color: '#0056b3',
              textDecoration: 'underline'
            }}
            onFocus={(e) => {
              e.target.style.outline = '2px solid #0056b3';
              e.target.style.outlineOffset = '2px';
            }}
          >
            Skip to content
          </a>
        </div>
      );
      
      const results = await axe(container, {
        ...wcagConfig,
        rules: {
          'color-contrast': { enabled: true },
          'color-contrast-enhanced': { enabled: true }
        }
      });
      
      expect(results).toHaveNoViolations();
    });

    it('should handle high contrast mode', () => {
      // Mock high contrast media query
      Object.defineProperty(window, 'matchMedia', {
        writable: true,
        value: jest.fn().mockImplementation(query => ({
          matches: query === '(prefers-contrast: high)',
          media: query,
          addEventListener: jest.fn(),
          removeEventListener: jest.fn(),
        })),
      });
      
      const { container } = render(
        <div 
          className="high-contrast"
          style={{
            '--high-contrast-bg': '#000000',
            '--high-contrast-text': '#ffffff',
            '--high-contrast-border': '#ffffff'
          }}
        >
          <p style={{ 
            color: 'var(--high-contrast-text)', 
            backgroundColor: 'var(--high-contrast-bg)',
            border: '1px solid var(--high-contrast-border)'
          }}>
            High contrast text
          </p>
        </div>
      );
      
      expect(container.firstChild).toHaveClass('high-contrast');
    });
  });

  describe('Keyboard Navigation', () => {
    it('should support full keyboard navigation', async () => {
      const { container } = render(
        <div>
          <header>
            <nav>
              <a href="#main" className="skip-link">Skip to main content</a>
              <ul>
                <li><a href="/home">Home</a></li>
                <li><a href="/about">About</a></li>
                <li><a href="/contact">Contact</a></li>
              </ul>
            </nav>
          </header>
          
          <main id="main" tabIndex={-1}>
            <h1>Main Content</h1>
            
            <div role="tablist" aria-label="Content sections">
              <button 
                role="tab" 
                aria-selected="true"
                aria-controls="panel1"
                id="tab1"
                tabIndex={0}
              >
                Overview
              </button>
              <button 
                role="tab" 
                aria-selected="false"
                aria-controls="panel2"
                id="tab2"
                tabIndex={-1}
              >
                Details
              </button>
            </div>
            
            <div role="tabpanel" aria-labelledby="tab1" id="panel1">
              <p>Overview content</p>
            </div>
            <div role="tabpanel" aria-labelledby="tab2" id="panel2" hidden>
              <p>Details content</p>
            </div>
            
            <table>
              <caption>Data Table</caption>
              <thead>
                <tr>
                  <th scope="col">Name</th>
                  <th scope="col">Value</th>
                  <th scope="col">Actions</th>
                </tr>
              </thead>
              <tbody>
                <tr>
                  <td>Item 1</td>
                  <td>100</td>
                  <td>
                    <button aria-label="Edit Item 1">Edit</button>
                    <button aria-label="Delete Item 1">Delete</button>
                  </td>
                </tr>
              </tbody>
            </table>
          </main>
        </div>
      );
      
      const results = await axe(container, wcagConfig);
      expect(results).toHaveNoViolations();
      
      // Test tab navigation
      const skipLink = screen.getByText('Skip to main content');
      const homeLink = screen.getByText('Home');
      const tab1 = screen.getByRole('tab', { name: 'Overview' });
      const tab2 = screen.getByRole('tab', { name: 'Details' });
      
      // Start navigation
      skipLink.focus();
      expect(skipLink).toHaveFocus();
      
      await userEvent.keyboard('{Enter}');
      expect(screen.getByRole('main')).toHaveFocus();
      
      // Test tab widget navigation
      tab1.focus();
      expect(tab1).toHaveFocus();
      
      await userEvent.keyboard('{ArrowRight}');
      expect(tab2).toHaveFocus();
      
      await userEvent.keyboard('{Enter}');
      expect(tab2).toHaveAttribute('aria-selected', 'true');
    });

    it('should handle focus trapping in modals', async () => {
      const { container } = render(
        <div>
          <button id="modal-trigger">Open Modal</button>
          
          <div 
            role="dialog"
            aria-labelledby="modal-title"
            aria-modal="true"
            data-testid="modal"
          >
            <div role="document">
              <header>
                <h2 id="modal-title">Modal Title</h2>
                <button aria-label="Close modal">×</button>
              </header>
              
              <div>
                <p>Modal content</p>
                <input type="text" placeholder="Enter text" />
                <button>Action Button</button>
              </div>
              
              <footer>
                <button>Cancel</button>
                <button>Confirm</button>
              </footer>
            </div>
          </div>
        </div>
      );
      
      const results = await axe(container, wcagConfig);
      expect(results).toHaveNoViolations();
      
      // Test focus management
      const modal = screen.getByTestId('modal');
      const closeButton = screen.getByLabelText('Close modal');
      const input = screen.getByPlaceholderText('Enter text');
      const confirmButton = screen.getByText('Confirm');
      
      // Focus should be trapped within modal
      closeButton.focus();
      expect(closeButton).toHaveFocus();
      
      // Tab to last element
      await userEvent.tab();
      await userEvent.tab();
      await userEvent.tab();
      await userEvent.tab();
      expect(confirmButton).toHaveFocus();
      
      // Tab again should return to first focusable element
      await userEvent.tab();
      expect(closeButton).toHaveFocus();
    });
  });

  describe('Screen Reader Support', () => {
    it('should provide proper ARIA labels and descriptions', async () => {
      const { container } = render(
        <div>
          {/* Live regions */}
          <div aria-live="polite" aria-atomic="true" id="status">
            Status updates appear here
          </div>
          
          <div aria-live="assertive" role="alert" id="errors">
            Error messages appear here
          </div>
          
          {/* Complex widget */}
          <div role="application" aria-label="Data visualization">
            <div 
              role="img" 
              aria-labelledby="chart-title"
              aria-describedby="chart-desc"
            >
              <h3 id="chart-title">Sales Performance Chart</h3>
              <p id="chart-desc">
                Bar chart showing sales data from January to December 2024
              </p>
              
              {/* Accessible data table for screen readers */}
              <table className="sr-only">
                <caption>Sales data by month</caption>
                <thead>
                  <tr>
                    <th scope="col">Month</th>
                    <th scope="col">Sales ($)</th>
                  </tr>
                </thead>
                <tbody>
                  <tr>
                    <th scope="row">January</th>
                    <td>45,000</td>
                  </tr>
                  <tr>
                    <th scope="row">February</th>
                    <td>52,000</td>
                  </tr>
                </tbody>
              </table>
            </div>
          </div>
          
          {/* Progress indicator */}
          <div>
            <label htmlFor="upload-progress">File upload progress</label>
            <progress 
              id="upload-progress"
              value="75" 
              max="100"
              aria-describedby="progress-text"
            >
              75%
            </progress>
            <div id="progress-text" aria-live="polite">
              75% complete, 2.5 MB of 10 MB uploaded
            </div>
          </div>
          
          {/* Expandable content */}
          <div>
            <button 
              aria-expanded="false"
              aria-controls="expandable-content"
              id="expand-trigger"
            >
              Show Details
            </button>
            <div id="expandable-content" aria-labelledby="expand-trigger" hidden>
              <p>Expandable content details</p>
            </div>
          </div>
        </div>
      );
      
      const results = await axe(container, wcagConfig);
      expect(results).toHaveNoViolations();
      
      // Test live region updates
      const statusRegion = screen.getByText('Status updates appear here');
      expect(statusRegion).toHaveAttribute('aria-live', 'polite');
      
      const errorRegion = screen.getByText('Error messages appear here');
      expect(errorRegion).toHaveAttribute('aria-live', 'assertive');
      
      // Test expandable content
      const expandButton = screen.getByText('Show Details');
      expect(expandButton).toHaveAttribute('aria-expanded', 'false');
      
      await userEvent.click(expandButton);
      expect(expandButton).toHaveAttribute('aria-expanded', 'true');
    });

    it('should announce dynamic content changes', async () => {
      const TestComponent = () => {
        const [status, setStatus] = React.useState('Ready');
        const [count, setCount] = React.useState(0);
        
        return (
          <div>
            <div aria-live="polite" aria-atomic="true">
              Status: {status}
            </div>
            
            <div aria-live="polite">
              Items: {count}
            </div>
            
            <button onClick={() => setStatus('Loading...')}>
              Start Process
            </button>
            
            <button onClick={() => setCount(c => c + 1)}>
              Add Item
            </button>
            
            <button onClick={() => {
              setStatus('Complete');
              setCount(5);
            }}>
              Finish
            </button>
          </div>
        );
      };
      
      const { container } = render(<TestComponent />);
      
      const results = await axe(container, wcagConfig);
      expect(results).toHaveNoViolations();
      
      // Test announcements
      expect(screen.getByText('Status: Ready')).toBeInTheDocument();
      
      await userEvent.click(screen.getByText('Start Process'));
      expect(screen.getByText('Status: Loading...')).toBeInTheDocument();
      
      await userEvent.click(screen.getByText('Add Item'));
      expect(screen.getByText('Items: 1')).toBeInTheDocument();
    });
  });

  describe('Mobile Accessibility', () => {
    it('should be accessible on mobile devices', async () => {
      // Mock mobile viewport
      global.testUtils.mockViewport(375, 667);
      
      const { container } = render(
        <div className="mobile-layout">
          {/* Touch-optimized navigation */}
          <nav role="navigation" aria-label="Mobile navigation">
            <button 
              aria-expanded="false"
              aria-controls="mobile-menu"
              className="menu-toggle"
              style={{ minHeight: '44px', minWidth: '44px' }}
            >
              <span className="sr-only">Toggle menu</span>
              ☰
            </button>
            
            <ul id="mobile-menu" className="mobile-menu" hidden>
              <li>
                <a href="/dashboard" style={{ minHeight: '44px', display: 'block' }}>
                  Dashboard
                </a>
              </li>
              <li>
                <a href="/campaigns" style={{ minHeight: '44px', display: 'block' }}>
                  Campaigns
                </a>
              </li>
            </ul>
          </nav>
          
          {/* Touch-friendly form controls */}
          <form>
            <div>
              <label htmlFor="mobile-input">Search</label>
              <input 
                type="text" 
                id="mobile-input"
                style={{ minHeight: '44px', fontSize: '16px' }}
                placeholder="Enter search term"
              />
            </div>
            
            <button 
              type="submit"
              style={{ minHeight: '44px', minWidth: '44px', fontSize: '16px' }}
            >
              Search
            </button>
          </form>
          
          {/* Swipe-enabled content */}
          <div 
            role="region"
            aria-label="Swipeable content"
            tabIndex={0}
            onKeyDown={(e) => {
              if (e.key === 'ArrowLeft' || e.key === 'ArrowRight') {
                // Handle keyboard navigation for swipe content
              }
            }}
          >
            <p>Swipe left or right, or use arrow keys to navigate</p>
          </div>
        </div>
      );
      
      const results = await axe(container, wcagConfig);
      expect(results).toHaveNoViolations();
      
      // Test touch target sizes (minimum 44x44px)
      const menuToggle = screen.getByRole('button', { name: /toggle menu/i });
      const computedStyle = window.getComputedStyle(menuToggle);
      expect(parseInt(computedStyle.minHeight)).toBeGreaterThanOrEqual(44);
      expect(parseInt(computedStyle.minWidth)).toBeGreaterThanOrEqual(44);
    });
  });

  describe('Error Handling Accessibility', () => {
    it('should provide accessible error messages', async () => {
      const FormWithErrors = () => {
        const [errors, setErrors] = React.useState<string[]>([]);
        
        const handleSubmit = (e: React.FormEvent) => {
          e.preventDefault();
          setErrors(['Name is required', 'Email is invalid']);
        };
        
        return (
          <form onSubmit={handleSubmit} noValidate>
            {errors.length > 0 && (
              <div role="alert" aria-atomic="true">
                <h2>Please correct the following errors:</h2>
                <ul>
                  {errors.map((error, index) => (
                    <li key={index}>{error}</li>
                  ))}
                </ul>
              </div>
            )}
            
            <div>
              <label htmlFor="name">Name *</label>
              <input 
                type="text" 
                id="name"
                aria-required="true"
                aria-invalid={errors.includes('Name is required') ? 'true' : 'false'}
                aria-describedby="name-error"
              />
              {errors.includes('Name is required') && (
                <div id="name-error" role="alert">
                  Name is required
                </div>
              )}
            </div>
            
            <div>
              <label htmlFor="email">Email *</label>
              <input 
                type="email" 
                id="email"
                aria-required="true"
                aria-invalid={errors.includes('Email is invalid') ? 'true' : 'false'}
                aria-describedby="email-error"
              />
              {errors.includes('Email is invalid') && (
                <div id="email-error" role="alert">
                  Email is invalid
                </div>
              )}
            </div>
            
            <button type="submit">Submit</button>
          </form>
        );
      };
      
      const { container } = render(<FormWithErrors />);
      
      const results = await axe(container, wcagConfig);
      expect(results).toHaveNoViolations();
      
      // Trigger validation errors
      await userEvent.click(screen.getByRole('button', { name: 'Submit' }));
      
      // Check error announcement
      const errorSummary = screen.getByRole('alert');
      expect(errorSummary).toHaveTextContent('Please correct the following errors:');
      
      // Check field-specific errors
      const nameInput = screen.getByLabelText(/name/i);
      const emailInput = screen.getByLabelText(/email/i);
      
      expect(nameInput).toHaveAttribute('aria-invalid', 'true');
      expect(emailInput).toHaveAttribute('aria-invalid', 'true');
    });
  });

  describe('Performance and Accessibility', () => {
    it('should maintain accessibility during loading states', async () => {
      const LoadingComponent = () => {
        const [loading, setLoading] = React.useState(true);
        
        React.useEffect(() => {
          const timer = setTimeout(() => setLoading(false), 1000);
          return () => clearTimeout(timer);
        }, []);
        
        if (loading) {
          return (
            <div>
              <div role="status" aria-live="polite">
                <span className="sr-only">Loading content...</span>
                <div aria-hidden="true">⏳</div>
              </div>
              
              {/* Skeleton content for screen readers */}
              <div className="sr-only">
                <h1>Page Title</h1>
                <p>Content is loading, please wait.</p>
              </div>
            </div>
          );
        }
        
        return (
          <div>
            <h1>Loaded Content</h1>
            <p>Content has finished loading.</p>
            <div aria-live="polite" aria-atomic="true">
              Content loaded successfully
            </div>
          </div>
        );
      };
      
      const { container } = render(<LoadingComponent />);
      
      // Test loading state accessibility
      expect(screen.getByRole('status')).toBeInTheDocument();
      expect(screen.getByText('Loading content...')).toBeInTheDocument();
      
      // Wait for content to load
      await waitFor(() => {
        expect(screen.getByText('Loaded Content')).toBeInTheDocument();
      }, { timeout: 1200 });
      
      const results = await axe(container, wcagConfig);
      expect(results).toHaveNoViolations();
    });
  });
});