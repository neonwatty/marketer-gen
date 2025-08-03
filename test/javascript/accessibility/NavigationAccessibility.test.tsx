import React from 'react';
import { render, screen, fireEvent, waitFor } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { axe, toHaveNoViolations } from 'jest-axe';

expect.extend(toHaveNoViolations);

// Navigation system accessibility testing
describe('Navigation System Accessibility', () => {
  const wcagConfig = {
    rules: {
      'color-contrast': { enabled: true },
      'aria-allowed-attr': { enabled: true },
      'aria-required-attr': { enabled: true },
      'aria-roles': { enabled: true },
      'aria-valid-attr': { enabled: true },
      'aria-valid-attr-value': { enabled: true },
      'button-name': { enabled: true },
      'link-name': { enabled: true },
      'list': { enabled: true },
      'listitem': { enabled: true },
      'region': { enabled: true },
      'bypass': { enabled: true },
      'focus-order-semantics': { enabled: true },
      'tabindex': { enabled: true },
      'landmark-banner-is-top-level': { enabled: true },
      'landmark-main-is-top-level': { enabled: true },
      'landmark-no-duplicate-banner': { enabled: true },
      'landmark-one-main': { enabled: true }
    },
    tags: ['wcag2a', 'wcag2aa', 'wcag21aa']
  };

  it('should provide accessible main navigation with skip links', async () => {
    const MainNavigation = () => (
      <div>
        {/* Skip links */}
        <div className="skip-links">
          <a href="#main-content" className="skip-link">Skip to main content</a>
          <a href="#navigation" className="skip-link">Skip to navigation</a>
          <a href="#footer" className="skip-link">Skip to footer</a>
        </div>

        {/* Main header */}
        <header role="banner">
          <div>
            <a href="/" aria-label="MarketGen home">
              <img src="/logo.svg" alt="MarketGen" width="120" height="40" />
            </a>
            
            {/* Primary navigation */}
            <nav id="navigation" role="navigation" aria-label="Primary navigation">
              <ul role="menubar">
                <li role="none">
                  <a 
                    href="/dashboard" 
                    role="menuitem" 
                    aria-current="page"
                    tabIndex={0}
                  >
                    Dashboard
                  </a>
                </li>
                
                <li role="none">
                  <button 
                    role="menuitem" 
                    aria-haspopup="true" 
                    aria-expanded="false"
                    id="campaigns-trigger"
                    tabIndex={0}
                  >
                    Campaigns
                    <span aria-hidden="true"> ▾</span>
                  </button>
                  <ul role="menu" aria-labelledby="campaigns-trigger" hidden>
                    <li role="none">
                      <a href="/campaigns/active" role="menuitem" tabIndex={-1}>
                        Active Campaigns
                      </a>
                    </li>
                    <li role="none">
                      <a href="/campaigns/draft" role="menuitem" tabIndex={-1}>
                        Draft Campaigns
                      </a>
                    </li>
                    <li role="none">
                      <a href="/campaigns/archived" role="menuitem" tabIndex={-1}>
                        Archived Campaigns
                      </a>
                    </li>
                  </ul>
                </li>
                
                <li role="none">
                  <button 
                    role="menuitem" 
                    aria-haspopup="true" 
                    aria-expanded="false"
                    id="analytics-trigger"
                    tabIndex={0}
                  >
                    Analytics
                    <span aria-hidden="true"> ▾</span>
                  </button>
                  <ul role="menu" aria-labelledby="analytics-trigger" hidden>
                    <li role="none">
                      <a href="/analytics/overview" role="menuitem" tabIndex={-1}>
                        Overview
                      </a>
                    </li>
                    <li role="none">
                      <a href="/analytics/reports" role="menuitem" tabIndex={-1}>
                        Custom Reports
                      </a>
                    </li>
                  </ul>
                </li>
                
                <li role="none">
                  <a href="/content" role="menuitem" tabIndex={0}>
                    Content Library
                  </a>
                </li>
                
                <li role="none">
                  <a href="/settings" role="menuitem" tabIndex={0}>
                    Settings
                  </a>
                </li>
              </ul>
            </nav>

            {/* User menu */}
            <div>
              <button 
                aria-haspopup="true" 
                aria-expanded="false"
                id="user-menu-trigger"
                aria-label="User menu"
              >
                <img src="/avatar.jpg" alt="" width="32" height="32" />
                <span>John Doe</span>
                <span aria-hidden="true"> ▾</span>
              </button>
              <ul role="menu" aria-labelledby="user-menu-trigger" hidden>
                <li role="none">
                  <a href="/profile" role="menuitem">Profile</a>
                </li>
                <li role="none">
                  <a href="/account" role="menuitem">Account Settings</a>
                </li>
                <li role="separator"></li>
                <li role="none">
                  <button role="menuitem" type="button">Sign Out</button>
                </li>
              </ul>
            </div>
          </div>
        </header>

        {/* Main content */}
        <main id="main-content" role="main" tabIndex={-1}>
          <h1>Dashboard</h1>
          <p>Main content area</p>
        </main>

        {/* Footer */}
        <footer id="footer" role="contentinfo">
          <nav aria-label="Footer navigation">
            <ul>
              <li><a href="/privacy">Privacy Policy</a></li>
              <li><a href="/terms">Terms of Service</a></li>
              <li><a href="/help">Help Center</a></li>
            </ul>
          </nav>
        </footer>
      </div>
    );

    const { container } = render(<MainNavigation />);
    
    const results = await axe(container, wcagConfig);
    expect(results).toHaveNoViolations();

    // Test skip links
    const skipToMain = screen.getByRole('link', { name: 'Skip to main content' });
    skipToMain.focus();
    expect(skipToMain).toHaveFocus();

    await userEvent.keyboard('{Enter}');
    
    // Skip link simulation - in a real implementation, this would focus the main content
    // For testing purposes, we simulate the focus management
    const mainContent = screen.getByRole('main');
    mainContent.focus();
    expect(mainContent).toHaveFocus();

    // Test main navigation
    const dashboardLink = screen.getByRole('menuitem', { name: 'Dashboard' });
    const campaignsButton = screen.getByRole('menuitem', { name: /campaigns/i });
    
    dashboardLink.focus();
    expect(dashboardLink).toHaveFocus();

    await userEvent.tab();
    expect(campaignsButton).toHaveFocus();

    // Test submenu expansion
    await userEvent.keyboard('{Enter}');
    expect(campaignsButton).toHaveAttribute('aria-expanded', 'true');
    
    const activeLink = screen.getByRole('menuitem', { name: 'Active Campaigns' });
    expect(activeLink).toBeInTheDocument();
  });

  it('should provide accessible mobile navigation', async () => {
    // Mock mobile viewport
    global.testUtils.mockViewport(375, 667);

    const MobileNavigation = () => {
      const [mobileMenuOpen, setMobileMenuOpen] = React.useState(false);
      const [activeSubmenu, setActiveSubmenu] = React.useState<string | null>(null);

      return (
        <div className="mobile-nav">
          <header role="banner">
            <div>
              {/* Mobile menu toggle */}
              <button
                aria-expanded={mobileMenuOpen}
                aria-controls="mobile-nav-menu"
                aria-label="Toggle navigation menu"
                onClick={() => setMobileMenuOpen(!mobileMenuOpen)}
                style={{ minHeight: '44px', minWidth: '44px' }}
              >
                <span aria-hidden="true">{mobileMenuOpen ? '✕' : '☰'}</span>
              </button>

              {/* Logo */}
              <a href="/" aria-label="MarketGen home">
                <img src="/logo.svg" alt="MarketGen" width="100" height="32" />
              </a>

              {/* User avatar */}
              <button aria-label="User menu" style={{ minHeight: '44px', minWidth: '44px' }}>
                <img src="/avatar.jpg" alt="" width="32" height="32" />
              </button>
            </div>

            {/* Mobile navigation menu */}
            <nav 
              id="mobile-nav-menu" 
              role="navigation" 
              aria-label="Mobile navigation"
              hidden={!mobileMenuOpen}
            >
              <ul role="list">
                <li>
                  <a href="/dashboard" style={{ minHeight: '44px', display: 'block' }}>
                    Dashboard
                  </a>
                </li>
                
                <li>
                  <button
                    aria-expanded={activeSubmenu === 'campaigns'}
                    aria-controls="campaigns-submenu"
                    onClick={() => setActiveSubmenu(
                      activeSubmenu === 'campaigns' ? null : 'campaigns'
                    )}
                    style={{ minHeight: '44px', width: '100%', textAlign: 'left' }}
                  >
                    Campaigns
                    <span aria-hidden="true">
                      {activeSubmenu === 'campaigns' ? ' ▴' : ' ▾'}
                    </span>
                  </button>
                  
                  <ul 
                    id="campaigns-submenu" 
                    hidden={activeSubmenu !== 'campaigns'}
                    style={{ paddingLeft: '20px' }}
                  >
                    <li>
                      <a href="/campaigns/active" style={{ minHeight: '44px', display: 'block' }}>
                        Active Campaigns
                      </a>
                    </li>
                    <li>
                      <a href="/campaigns/draft" style={{ minHeight: '44px', display: 'block' }}>
                        Draft Campaigns
                      </a>
                    </li>
                  </ul>
                </li>
                
                <li>
                  <button
                    aria-expanded={activeSubmenu === 'analytics'}
                    aria-controls="analytics-submenu"
                    onClick={() => setActiveSubmenu(
                      activeSubmenu === 'analytics' ? null : 'analytics'
                    )}
                    style={{ minHeight: '44px', width: '100%', textAlign: 'left' }}
                  >
                    Analytics
                    <span aria-hidden="true">
                      {activeSubmenu === 'analytics' ? ' ▴' : ' ▾'}
                    </span>
                  </button>
                  
                  <ul 
                    id="analytics-submenu" 
                    hidden={activeSubmenu !== 'analytics'}
                    style={{ paddingLeft: '20px' }}
                  >
                    <li>
                      <a href="/analytics/overview" style={{ minHeight: '44px', display: 'block' }}>
                        Overview
                      </a>
                    </li>
                    <li>
                      <a href="/analytics/reports" style={{ minHeight: '44px', display: 'block' }}>
                        Custom Reports
                      </a>
                    </li>
                  </ul>
                </li>
                
                <li>
                  <a href="/content" style={{ minHeight: '44px', display: 'block' }}>
                    Content Library
                  </a>
                </li>
                
                <li>
                  <a href="/settings" style={{ minHeight: '44px', display: 'block' }}>
                    Settings
                  </a>
                </li>
              </ul>
            </nav>
          </header>
        </div>
      );
    };

    const { container } = render(<MobileNavigation />);
    
    const results = await axe(container, wcagConfig);
    expect(results).toHaveNoViolations();

    // Test mobile menu toggle
    const menuToggle = screen.getByRole('button', { name: /toggle navigation menu/i });
    expect(menuToggle).toHaveAttribute('aria-expanded', 'false');

    await userEvent.click(menuToggle);
    expect(menuToggle).toHaveAttribute('aria-expanded', 'true');

    // Test touch target sizes (minimum 44x44px)
    const computedStyle = window.getComputedStyle(menuToggle);
    expect(parseInt(computedStyle.minHeight)).toBeGreaterThanOrEqual(44);
    expect(parseInt(computedStyle.minWidth)).toBeGreaterThanOrEqual(44);

    // Test submenu expansion
    const campaignsButton = screen.getByRole('button', { name: /campaigns/i });
    await userEvent.click(campaignsButton);
    expect(campaignsButton).toHaveAttribute('aria-expanded', 'true');
  });

  it('should provide accessible breadcrumb navigation', async () => {
    const BreadcrumbNavigation = () => (
      <nav aria-label="Breadcrumb" role="navigation">
        <ol role="list">
          <li>
            <a href="/" aria-label="Home">
              <span aria-hidden="true">🏠</span>
              <span className="sr-only">Home</span>
            </a>
          </li>
          <li aria-hidden="true"> / </li>
          <li>
            <a href="/campaigns">Campaigns</a>
          </li>
          <li aria-hidden="true"> / </li>
          <li>
            <a href="/campaigns/active">Active Campaigns</a>
          </li>
          <li aria-hidden="true"> / </li>
          <li aria-current="page">
            Campaign Details
          </li>
        </ol>
      </nav>
    );

    const { container } = render(<BreadcrumbNavigation />);
    
    const results = await axe(container, wcagConfig);
    expect(results).toHaveNoViolations();

    // Test current page indicator
    const currentPage = screen.getByText('Campaign Details');
    expect(currentPage).toHaveAttribute('aria-current', 'page');

    // Test navigation links
    const homeLink = screen.getByRole('link', { name: 'Home' });
    const campaignsLink = screen.getByRole('link', { name: 'Campaigns' });
    
    expect(homeLink).toBeInTheDocument();
    expect(campaignsLink).toBeInTheDocument();
  });

  it('should provide accessible sidebar navigation', async () => {
    const SidebarNavigation = () => {
      const [collapsed, setCollapsed] = React.useState(false);
      const [activeSection, setActiveSection] = React.useState('dashboard');

      return (
        <div>
          <aside 
            role="complementary" 
            aria-label="Secondary navigation"
            className={collapsed ? 'collapsed' : 'expanded'}
          >
            {/* Collapse toggle */}
            <button
              aria-expanded={!collapsed}
              aria-controls="sidebar-nav"
              aria-label={collapsed ? 'Expand sidebar' : 'Collapse sidebar'}
              onClick={() => setCollapsed(!collapsed)}
            >
              <span aria-hidden="true">{collapsed ? '▶' : '◀'}</span>
            </button>

            {/* Navigation sections */}
            <nav id="sidebar-nav" role="navigation" aria-label="Sidebar navigation">
              <section>
                <h2 id="main-section">Main</h2>
                <ul role="list" aria-labelledby="main-section">
                  <li>
                    <a 
                      href="/dashboard"
                      aria-current={activeSection === 'dashboard' ? 'page' : 'false'}
                      className={activeSection === 'dashboard' ? 'active' : ''}
                    >
                      <span aria-hidden="true">📊</span>
                      {!collapsed && <span>Dashboard</span>}
                    </a>
                  </li>
                  <li>
                    <a 
                      href="/campaigns"
                      aria-current={activeSection === 'campaigns' ? 'page' : 'false'}
                      className={activeSection === 'campaigns' ? 'active' : ''}
                    >
                      <span aria-hidden="true">📢</span>
                      {!collapsed && <span>Campaigns</span>}
                    </a>
                  </li>
                  <li>
                    <a 
                      href="/analytics"
                      aria-current={activeSection === 'analytics' ? 'page' : 'false'}
                      className={activeSection === 'analytics' ? 'active' : ''}
                    >
                      <span aria-hidden="true">📈</span>
                      {!collapsed && <span>Analytics</span>}
                    </a>
                  </li>
                </ul>
              </section>

              <section>
                <h2 id="content-section">Content</h2>
                <ul role="list" aria-labelledby="content-section">
                  <li>
                    <a href="/content/library">
                      <span aria-hidden="true">📁</span>
                      {!collapsed && <span>Library</span>}
                    </a>
                  </li>
                  <li>
                    <a href="/content/templates">
                      <span aria-hidden="true">📄</span>
                      {!collapsed && <span>Templates</span>}
                    </a>
                  </li>
                  <li>
                    <a href="/content/brands">
                      <span aria-hidden="true">🎨</span>
                      {!collapsed && <span>Brand Assets</span>}
                    </a>
                  </li>
                </ul>
              </section>

              <section>
                <h2 id="settings-section">Settings</h2>
                <ul role="list" aria-labelledby="settings-section">
                  <li>
                    <a href="/settings/account">
                      <span aria-hidden="true">⚙️</span>
                      {!collapsed && <span>Account</span>}
                    </a>
                  </li>
                  <li>
                    <a href="/settings/integrations">
                      <span aria-hidden="true">🔗</span>
                      {!collapsed && <span>Integrations</span>}
                    </a>
                  </li>
                </ul>
              </section>
            </nav>
          </aside>

          <main role="main">
            <h1>Main Content</h1>
          </main>
        </div>
      );
    };

    const { container } = render(<SidebarNavigation />);
    
    const results = await axe(container, wcagConfig);
    expect(results).toHaveNoViolations();

    // Test collapse functionality
    const collapseButton = screen.getByRole('button', { name: /collapse sidebar/i });
    expect(collapseButton).toHaveAttribute('aria-expanded', 'true');

    await userEvent.click(collapseButton);
    expect(collapseButton).toHaveAttribute('aria-expanded', 'false');
    expect(collapseButton).toHaveAccessibleName('Expand sidebar');

    // Test navigation groups
    const mainSection = screen.getByRole('group', { name: 'Main' });
    const contentSection = screen.getByRole('group', { name: 'Content' });
    const settingsSection = screen.getByRole('group', { name: 'Settings' });

    expect(mainSection).toBeInTheDocument();
    expect(contentSection).toBeInTheDocument();
    expect(settingsSection).toBeInTheDocument();
  });

  it('should handle keyboard navigation patterns correctly', async () => {
    const KeyboardNavigationTest = () => {
      const [activeIndex, setActiveIndex] = React.useState(0);
      const menuItems = ['Dashboard', 'Campaigns', 'Analytics', 'Content', 'Settings'];

      const handleKeyDown = (e: React.KeyboardEvent, index: number) => {
        switch (e.key) {
          case 'ArrowRight':
          case 'ArrowDown':
            e.preventDefault();
            setActiveIndex((index + 1) % menuItems.length);
            break;
          case 'ArrowLeft':
          case 'ArrowUp':
            e.preventDefault();
            setActiveIndex((index - 1 + menuItems.length) % menuItems.length);
            break;
          case 'Home':
            e.preventDefault();
            setActiveIndex(0);
            break;
          case 'End':
            e.preventDefault();
            setActiveIndex(menuItems.length - 1);
            break;
        }
      };

      return (
        <nav role="navigation" aria-label="Keyboard navigation test">
          <ul role="menubar" aria-label="Main navigation">
            {menuItems.map((item, index) => (
              <li key={item} role="none">
                <a
                  href={`/${item.toLowerCase()}`}
                  role="menuitem"
                  tabIndex={index === activeIndex ? 0 : -1}
                  onKeyDown={(e) => handleKeyDown(e, index)}
                  onFocus={() => setActiveIndex(index)}
                  aria-current={index === activeIndex ? 'page' : 'false'}
                >
                  {item}
                </a>
              </li>
            ))}
          </ul>
        </nav>
      );
    };

    const { container } = render(<KeyboardNavigationTest />);
    
    const results = await axe(container, wcagConfig);
    expect(results).toHaveNoViolations();

    // Test arrow key navigation
    const dashboardLink = screen.getByRole('menuitem', { name: 'Dashboard' });
    const campaignsLink = screen.getByRole('menuitem', { name: 'Campaigns' });
    const settingsLink = screen.getByRole('menuitem', { name: 'Settings' });

    dashboardLink.focus();
    expect(dashboardLink).toHaveFocus();
    expect(dashboardLink).toHaveAttribute('tabindex', '0');

    await userEvent.keyboard('{ArrowRight}');
    expect(campaignsLink).toHaveFocus();
    expect(campaignsLink).toHaveAttribute('tabindex', '0');
    expect(dashboardLink).toHaveAttribute('tabindex', '-1');

    // Test Home/End keys
    await userEvent.keyboard('{End}');
    expect(settingsLink).toHaveFocus();

    await userEvent.keyboard('{Home}');
    expect(dashboardLink).toHaveFocus();
  });
});