import React from 'react';
import { render, screen, fireEvent, waitFor } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { axe, toHaveNoViolations } from 'jest-axe';

expect.extend(toHaveNoViolations);

// Responsive design accessibility testing
describe('Responsive Design Accessibility', () => {
  const wcagConfig = {
    rules: {
      'color-contrast': { enabled: true },
      'aria-allowed-attr': { enabled: true },
      'aria-required-attr': { enabled: true },
      'aria-roles': { enabled: true },
      'aria-valid-attr': { enabled: true },
      'button-name': { enabled: true },
      'label': { enabled: true },
      'region': { enabled: true },
      'tabindex': { enabled: true },
      'meta-viewport': { enabled: true }
    },
    tags: ['wcag2a', 'wcag2aa', 'wcag21aa']
  };

  const breakpoints = {
    mobile: { width: 375, height: 667 },
    tablet: { width: 768, height: 1024 },
    desktop: { width: 1440, height: 900 },
    large: { width: 1920, height: 1080 }
  };

  beforeEach(() => {
    // Reset viewport
    global.testUtils.mockViewport(1440, 900);
  });

  it('should be accessible across all breakpoints - mobile', async () => {
    global.testUtils.mockViewport(breakpoints.mobile.width, breakpoints.mobile.height);

    const ResponsiveComponent = () => (
      <div className="responsive-layout">
        <header role="banner">
          <button 
            aria-label="Toggle navigation menu"
            className="mobile-menu-toggle"
            style={{ 
              minHeight: '44px', 
              minWidth: '44px',
              fontSize: '16px',
              padding: '12px'
            }}
          >
            <span aria-hidden="true">☰</span>
          </button>
          
          <h1 style={{ fontSize: '1.5rem' }}>Mobile Header</h1>
        </header>

        <main role="main" style={{ padding: '16px' }}>
          <section>
            <h2 style={{ fontSize: '1.25rem', marginBottom: '16px' }}>Content Section</h2>
            
            {/* Mobile-optimized form */}
            <form>
              <div style={{ marginBottom: '16px' }}>
                <label htmlFor="mobile-input" style={{ display: 'block', marginBottom: '8px' }}>
                  Search
                </label>
                <input
                  type="text"
                  id="mobile-input"
                  style={{
                    width: '100%',
                    minHeight: '44px',
                    fontSize: '16px',
                    padding: '12px',
                    border: '2px solid #ccc',
                    borderRadius: '4px'
                  }}
                />
              </div>
              
              <button
                type="submit"
                style={{
                  width: '100%',
                  minHeight: '44px',
                  fontSize: '16px',
                  padding: '12px 24px',
                  backgroundColor: '#007bff',
                  color: '#fff',
                  border: 'none',
                  borderRadius: '4px'
                }}
              >
                Search
              </button>
            </form>

            {/* Mobile-friendly cards */}
            <div style={{ marginTop: '24px' }}>
              <div 
                style={{
                  border: '1px solid #ddd',
                  borderRadius: '8px',
                  padding: '16px',
                  marginBottom: '16px',
                  touchAction: 'manipulation'
                }}
                tabIndex={0}
              >
                <h3 style={{ fontSize: '1.125rem', marginBottom: '8px' }}>
                  Card Title
                </h3>
                <p style={{ fontSize: '1rem', lineHeight: '1.5' }}>
                  Card content that adapts to mobile screen sizes.
                </p>
                <button
                  type="button"
                  style={{
                    minHeight: '44px',
                    minWidth: '44px',
                    fontSize: '16px',
                    padding: '12px 16px',
                    marginTop: '12px'
                  }}
                >
                  Action
                </button>
              </div>
            </div>
          </section>
        </main>

        <nav 
          role="navigation" 
          aria-label="Bottom navigation"
          style={{
            position: 'fixed',
            bottom: 0,
            left: 0,
            right: 0,
            backgroundColor: '#fff',
            borderTop: '1px solid #ddd',
            padding: '8px'
          }}
        >
          <ul 
            role="list"
            style={{
              display: 'flex',
              justifyContent: 'space-around',
              listStyle: 'none',
              margin: 0,
              padding: 0
            }}
          >
            {['Home', 'Search', 'Profile', 'Settings'].map((item) => (
              <li key={item}>
                <button
                  type="button"
                  aria-label={item}
                  style={{
                    minHeight: '44px',
                    minWidth: '44px',
                    fontSize: '12px',
                    display: 'flex',
                    flexDirection: 'column',
                    alignItems: 'center',
                    justifyContent: 'center',
                    border: 'none',
                    background: 'none',
                    color: '#007bff'
                  }}
                >
                  <span aria-hidden="true" style={{ marginBottom: '4px' }}>
                    {item === 'Home' ? '🏠' : item === 'Search' ? '🔍' : 
                     item === 'Profile' ? '👤' : '⚙️'}
                  </span>
                  <span style={{ fontSize: '10px' }}>{item}</span>
                </button>
              </li>
            ))}
          </ul>
        </nav>
      </div>
    );

    const { container } = render(<ResponsiveComponent />);
    
    const results = await axe(container, wcagConfig);
    expect(results).toHaveNoViolations();

    // Test touch target sizes
    const menuToggle = screen.getByRole('button', { name: /toggle navigation/i });
    const computedStyle = window.getComputedStyle(menuToggle);
    expect(parseInt(computedStyle.minHeight)).toBeGreaterThanOrEqual(44);
    expect(parseInt(computedStyle.minWidth)).toBeGreaterThanOrEqual(44);

    // Test form accessibility on mobile
    const searchInput = screen.getByLabelText('Search');
    const searchButton = screen.getByRole('button', { name: 'Search' });
    
    expect(searchInput).toHaveStyle({ fontSize: '16px' }); // Prevents zoom on iOS
    expect(searchButton).toHaveStyle({ minHeight: '44px' });

    // Test bottom navigation
    const homeButton = screen.getByRole('button', { name: 'Home' });
    expect(homeButton).toHaveStyle({ minHeight: '44px', minWidth: '44px' });
  });

  it('should adapt navigation and layout for tablet screens', async () => {
    global.testUtils.mockViewport(breakpoints.tablet.width, breakpoints.tablet.height);

    const TabletLayout = () => {
      const [sidebarOpen, setSidebarOpen] = React.useState(false);

      return (
        <div className="tablet-layout" style={{ display: 'flex' }}>
          {/* Tablet sidebar */}
          <aside 
            role="complementary"
            aria-label="Sidebar navigation"
            style={{
              width: sidebarOpen ? '280px' : '60px',
              transition: 'width 0.3s ease',
              borderRight: '1px solid #ddd',
              backgroundColor: '#f8f9fa'
            }}
          >
            <button
              type="button"
              aria-expanded={sidebarOpen}
              aria-controls="sidebar-content"
              aria-label={sidebarOpen ? 'Collapse sidebar' : 'Expand sidebar'}
              onClick={() => setSidebarOpen(!sidebarOpen)}
              style={{
                width: '100%',
                minHeight: '44px',
                padding: '12px',
                border: 'none',
                backgroundColor: 'transparent'
              }}
            >
              <span aria-hidden="true">{sidebarOpen ? '◀' : '▶'}</span>
            </button>

            <nav id="sidebar-content" role="navigation" aria-label="Main navigation">
              <ul role="list" style={{ listStyle: 'none', padding: 0, margin: 0 }}>
                {[
                  { name: 'Dashboard', icon: '📊' },
                  { name: 'Campaigns', icon: '📢' },
                  { name: 'Analytics', icon: '📈' },
                  { name: 'Settings', icon: '⚙️' }
                ].map((item) => (
                  <li key={item.name}>
                    <a
                      href={`/${item.name.toLowerCase()}`}
                      style={{
                        display: 'flex',
                        alignItems: 'center',
                        padding: '12px',
                        textDecoration: 'none',
                        color: '#333',
                        minHeight: '44px'
                      }}
                    >
                      <span aria-hidden="true" style={{ marginRight: sidebarOpen ? '12px' : '0' }}>
                        {item.icon}
                      </span>
                      {sidebarOpen && <span>{item.name}</span>}
                      {!sidebarOpen && <span className="sr-only">{item.name}</span>}
                    </a>
                  </li>
                ))}
              </ul>
            </nav>
          </aside>

          {/* Main content area */}
          <main 
            role="main" 
            style={{ 
              flex: 1, 
              padding: '24px',
              minHeight: '100vh'
            }}
          >
            <header>
              <h1 style={{ fontSize: '2rem', marginBottom: '24px' }}>
                Tablet Layout
              </h1>
            </header>

            {/* Grid layout for tablet */}
            <div 
              style={{
                display: 'grid',
                gridTemplateColumns: 'repeat(auto-fit, minmax(300px, 1fr))',
                gap: '24px'
              }}
              role="region"
              aria-label="Content grid"
            >
              {[1, 2, 3, 4].map((item) => (
                <div
                  key={item}
                  style={{
                    border: '1px solid #ddd',
                    borderRadius: '8px',
                    padding: '20px',
                    backgroundColor: '#fff'
                  }}
                  tabIndex={0}
                  role="article"
                  aria-labelledby={`card-${item}-title`}
                >
                  <h2 id={`card-${item}-title`} style={{ marginBottom: '16px' }}>
                    Content Card {item}
                  </h2>
                  <p style={{ marginBottom: '16px', lineHeight: '1.6' }}>
                    This is content that adapts well to tablet screen sizes with appropriate spacing and typography.
                  </p>
                  <div>
                    <button
                      type="button"
                      style={{
                        minHeight: '40px',
                        padding: '8px 16px',
                        marginRight: '8px',
                        fontSize: '14px'
                      }}
                    >
                      Primary Action
                    </button>
                    <button
                      type="button"
                      style={{
                        minHeight: '40px',
                        padding: '8px 16px',
                        fontSize: '14px',
                        backgroundColor: 'transparent',
                        border: '1px solid #007bff',
                        color: '#007bff'
                      }}
                    >
                      Secondary
                    </button>
                  </div>
                </div>
              ))}
            </div>

            {/* Tablet-optimized form */}
            <section style={{ marginTop: '32px' }}>
              <h2>Form Section</h2>
              <form style={{ maxWidth: '600px' }}>
                <div 
                  style={{
                    display: 'grid',
                    gridTemplateColumns: '1fr 1fr',
                    gap: '16px',
                    marginBottom: '24px'
                  }}
                >
                  <div>
                    <label htmlFor="first-name" style={{ display: 'block', marginBottom: '8px' }}>
                      First Name
                    </label>
                    <input
                      type="text"
                      id="first-name"
                      style={{
                        width: '100%',
                        minHeight: '40px',
                        padding: '8px 12px',
                        fontSize: '16px',
                        border: '2px solid #ccc',
                        borderRadius: '4px'
                      }}
                    />
                  </div>
                  
                  <div>
                    <label htmlFor="last-name" style={{ display: 'block', marginBottom: '8px' }}>
                      Last Name
                    </label>
                    <input
                      type="text"
                      id="last-name"
                      style={{
                        width: '100%',
                        minHeight: '40px',
                        padding: '8px 12px',
                        fontSize: '16px',
                        border: '2px solid #ccc',
                        borderRadius: '4px'
                      }}
                    />
                  </div>
                </div>
                
                <button
                  type="submit"
                  style={{
                    minHeight: '44px',
                    padding: '12px 24px',
                    fontSize: '16px',
                    backgroundColor: '#007bff',
                    color: '#fff',
                    border: 'none',
                    borderRadius: '4px'
                  }}
                >
                  Submit
                </button>
              </form>
            </section>
          </main>
        </div>
      );
    };

    const { container } = render(<TabletLayout />);
    
    const results = await axe(container, wcagConfig);
    expect(results).toHaveNoViolations();

    // Test sidebar functionality
    const sidebarToggle = screen.getByRole('button', { name: /expand sidebar/i });
    expect(sidebarToggle).toHaveAttribute('aria-expanded', 'false');

    await userEvent.click(sidebarToggle);
    expect(sidebarToggle).toHaveAttribute('aria-expanded', 'true');
    expect(sidebarToggle).toHaveAccessibleName('Collapse sidebar');

    // Test navigation links
    const dashboardLink = screen.getByRole('link', { name: 'Dashboard' });
    expect(dashboardLink).toBeInTheDocument();

    // Test form grid layout
    const firstNameInput = screen.getByLabelText('First Name');
    const lastNameInput = screen.getByLabelText('Last Name');
    
    expect(firstNameInput).toHaveStyle({ minHeight: '40px' });
    expect(lastNameInput).toHaveStyle({ minHeight: '40px' });
  });

  it('should provide optimal desktop experience with complex layouts', async () => {
    global.testUtils.mockViewport(breakpoints.desktop.width, breakpoints.desktop.height);

    const DesktopLayout = () => {
      const [activeView, setActiveView] = React.useState('grid');
      const [selectedItems, setSelectedItems] = React.useState<number[]>([]);

      return (
        <div className="desktop-layout">
          <header 
            role="banner"
            style={{
              display: 'flex',
              justifyContent: 'space-between',
              alignItems: 'center',
              padding: '16px 32px',
              borderBottom: '1px solid #ddd',
              backgroundColor: '#fff'
            }}
          >
            <h1 style={{ fontSize: '1.75rem' }}>Desktop Dashboard</h1>
            
            <nav role="navigation" aria-label="Primary navigation">
              <ul 
                role="menubar"
                style={{
                  display: 'flex',
                  listStyle: 'none',
                  margin: 0,
                  padding: 0,
                  gap: '24px'
                }}
              >
                {['Dashboard', 'Campaigns', 'Analytics', 'Reports', 'Settings'].map((item) => (
                  <li key={item} role="none">
                    <a
                      href={`/${item.toLowerCase()}`}
                      role="menuitem"
                      style={{
                        textDecoration: 'none',
                        color: '#333',
                        padding: '8px 16px',
                        borderRadius: '4px',
                        transition: 'background-color 0.2s'
                      }}
                      onMouseEnter={(e) => {
                        e.currentTarget.style.backgroundColor = '#f8f9fa';
                      }}
                      onMouseLeave={(e) => {
                        e.currentTarget.style.backgroundColor = 'transparent';
                      }}
                      onFocus={(e) => {
                        e.currentTarget.style.outline = '2px solid #007bff';
                        e.currentTarget.style.outlineOffset = '2px';
                      }}
                      onBlur={(e) => {
                        e.currentTarget.style.outline = 'none';
                      }}
                    >
                      {item}
                    </a>
                  </li>
                ))}
              </ul>
            </nav>

            <div role="group" aria-label="User actions">
              <button
                type="button"
                aria-label="Notifications"
                style={{
                  padding: '8px',
                  marginRight: '8px',
                  border: 'none',
                  backgroundColor: 'transparent',
                  borderRadius: '4px'
                }}
              >
                <span aria-hidden="true">🔔</span>
              </button>
              <button
                type="button"
                aria-label="User menu"
                style={{
                  padding: '8px',
                  border: 'none',
                  backgroundColor: 'transparent',
                  borderRadius: '4px'
                }}
              >
                <span aria-hidden="true">👤</span>
              </button>
            </div>
          </header>

          <div style={{ display: 'flex', minHeight: 'calc(100vh - 80px)' }}>
            {/* Sidebar */}
            <aside 
              role="complementary"
              aria-label="Filters and actions"
              style={{
                width: '280px',
                padding: '24px',
                borderRight: '1px solid #ddd',
                backgroundColor: '#f8f9fa'
              }}
            >
              <section>
                <h2 style={{ fontSize: '1.25rem', marginBottom: '16px' }}>Filters</h2>
                
                <div style={{ marginBottom: '24px' }}>
                  <label htmlFor="search-filter" style={{ display: 'block', marginBottom: '8px' }}>
                    Search
                  </label>
                  <input
                    type="text"
                    id="search-filter"
                    style={{
                      width: '100%',
                      padding: '8px 12px',
                      border: '1px solid #ccc',
                      borderRadius: '4px'
                    }}
                    placeholder="Search items..."
                  />
                </div>

                <fieldset style={{ marginBottom: '24px' }}>
                  <legend style={{ marginBottom: '12px', fontWeight: 'bold' }}>Status</legend>
                  <div role="group">
                    {['Active', 'Paused', 'Draft', 'Archived'].map((status) => (
                      <label key={status} style={{ display: 'block', marginBottom: '8px' }}>
                        <input
                          type="checkbox"
                          value={status}
                          style={{ marginRight: '8px' }}
                        />
                        {status}
                      </label>
                    ))}
                  </div>
                </fieldset>

                <div>
                  <label htmlFor="date-range" style={{ display: 'block', marginBottom: '8px' }}>
                    Date Range
                  </label>
                  <select
                    id="date-range"
                    style={{
                      width: '100%',
                      padding: '8px',
                      border: '1px solid #ccc',
                      borderRadius: '4px'
                    }}
                  >
                    <option>Last 7 days</option>
                    <option>Last 30 days</option>
                    <option>Last 90 days</option>
                    <option>Custom range</option>
                  </select>
                </div>
              </section>
            </aside>

            {/* Main content */}
            <main role="main" style={{ flex: 1, padding: '24px' }}>
              {/* View controls */}
              <div 
                style={{
                  display: 'flex',
                  justifyContent: 'space-between',
                  alignItems: 'center',
                  marginBottom: '24px'
                }}
              >
                <div role="group" aria-label="View options">
                  <button
                    type="button"
                    aria-pressed={activeView === 'grid'}
                    onClick={() => setActiveView('grid')}
                    style={{
                      padding: '8px 16px',
                      marginRight: '8px',
                      border: '1px solid #ccc',
                      backgroundColor: activeView === 'grid' ? '#007bff' : '#fff',
                      color: activeView === 'grid' ? '#fff' : '#333',
                      borderRadius: '4px'
                    }}
                  >
                    Grid View
                  </button>
                  <button
                    type="button"
                    aria-pressed={activeView === 'list'}
                    onClick={() => setActiveView('list')}
                    style={{
                      padding: '8px 16px',
                      border: '1px solid #ccc',
                      backgroundColor: activeView === 'list' ? '#007bff' : '#fff',
                      color: activeView === 'list' ? '#fff' : '#333',
                      borderRadius: '4px'
                    }}
                  >
                    List View
                  </button>
                </div>

                {selectedItems.length > 0 && (
                  <div role="toolbar" aria-label="Bulk actions">
                    <span style={{ marginRight: '16px' }}>
                      {selectedItems.length} selected
                    </span>
                    <button type="button" style={{ marginRight: '8px' }}>
                      Edit Selected
                    </button>
                    <button type="button">
                      Delete Selected
                    </button>
                  </div>
                )}
              </div>

              {/* Content area */}
              <div
                role="region"
                aria-label="Content items"
                style={{
                  display: activeView === 'grid' ? 'grid' : 'block',
                  gridTemplateColumns: activeView === 'grid' ? 'repeat(auto-fill, minmax(320px, 1fr))' : 'none',
                  gap: activeView === 'grid' ? '24px' : '16px'
                }}
              >
                {[1, 2, 3, 4, 5, 6, 7, 8].map((item) => (
                  <div
                    key={item}
                    style={{
                      border: '1px solid #ddd',
                      borderRadius: '8px',
                      padding: '20px',
                      backgroundColor: '#fff',
                      display: activeView === 'list' ? 'flex' : 'block',
                      alignItems: activeView === 'list' ? 'center' : 'normal'
                    }}
                    role="article"
                    aria-labelledby={`item-${item}-title`}
                  >
                    <input
                      type="checkbox"
                      aria-label={`Select item ${item}`}
                      checked={selectedItems.includes(item)}
                      onChange={(e) => {
                        if (e.target.checked) {
                          setSelectedItems([...selectedItems, item]);
                        } else {
                          setSelectedItems(selectedItems.filter(id => id !== item));
                        }
                      }}
                      style={{ 
                        marginRight: activeView === 'list' ? '16px' : '0',
                        marginBottom: activeView === 'grid' ? '12px' : '0'
                      }}
                    />
                    
                    <div style={{ flex: activeView === 'list' ? 1 : 'none' }}>
                      <h3 
                        id={`item-${item}-title`}
                        style={{ 
                          fontSize: '1.125rem',
                          marginBottom: activeView === 'grid' ? '12px' : '4px'
                        }}
                      >
                        Desktop Item {item}
                      </h3>
                      <p style={{ 
                        marginBottom: activeView === 'grid' ? '16px' : '0',
                        color: '#666'
                      }}>
                        Description for item {item} with detailed information.
                      </p>
                    </div>

                    <div 
                      style={{ 
                        marginLeft: activeView === 'list' ? '16px' : '0',
                        marginTop: activeView === 'grid' ? '16px' : '0'
                      }}
                    >
                      <button
                        type="button"
                        aria-label={`Edit item ${item}`}
                        style={{
                          padding: '6px 12px',
                          marginRight: '8px',
                          fontSize: '14px'
                        }}
                      >
                        Edit
                      </button>
                      <button
                        type="button"
                        aria-label={`Delete item ${item}`}
                        style={{
                          padding: '6px 12px',
                          fontSize: '14px',
                          backgroundColor: '#dc3545',
                          color: '#fff',
                          border: 'none',
                          borderRadius: '4px'
                        }}
                      >
                        Delete
                      </button>
                    </div>
                  </div>
                ))}
              </div>

              {/* Pagination */}
              <nav 
                aria-label="Pagination"
                style={{
                  display: 'flex',
                  justifyContent: 'center',
                  marginTop: '32px'
                }}
              >
                <ul 
                  role="list"
                  style={{
                    display: 'flex',
                    listStyle: 'none',
                    margin: 0,
                    padding: 0,
                    gap: '8px'
                  }}
                >
                  <li>
                    <button disabled aria-label="Previous page">Previous</button>
                  </li>
                  {[1, 2, 3, 4, 5].map((page) => (
                    <li key={page}>
                      <button
                        aria-current={page === 1 ? 'page' : undefined}
                        aria-label={page === 1 ? `Current page, page ${page}` : `Go to page ${page}`}
                        style={{
                          padding: '8px 12px',
                          border: '1px solid #ccc',
                          backgroundColor: page === 1 ? '#007bff' : '#fff',
                          color: page === 1 ? '#fff' : '#333',
                          borderRadius: '4px'
                        }}
                      >
                        {page}
                      </button>
                    </li>
                  ))}
                  <li>
                    <button aria-label="Next page">Next</button>
                  </li>
                </ul>
              </nav>
            </main>
          </div>
        </div>
      );
    };

    const { container } = render(<DesktopLayout />);
    
    const results = await axe(container, wcagConfig);
    expect(results).toHaveNoViolations();

    // Test view toggle
    const listViewButton = screen.getByRole('button', { name: 'List View' });
    expect(listViewButton).toHaveAttribute('aria-pressed', 'false');

    await userEvent.click(listViewButton);
    expect(listViewButton).toHaveAttribute('aria-pressed', 'true');

    // Test bulk selection
    const firstCheckbox = screen.getByRole('checkbox', { name: 'Select item 1' });
    await userEvent.click(firstCheckbox);
    
    expect(screen.getByText('1 selected')).toBeInTheDocument();
    expect(screen.getByRole('toolbar', { name: 'Bulk actions' })).toBeInTheDocument();

    // Test navigation
    const dashboardLink = screen.getByRole('menuitem', { name: 'Dashboard' });
    dashboardLink.focus();
    expect(dashboardLink).toHaveFocus();
  });

  it('should handle large screens with advanced layouts', async () => {
    global.testUtils.mockViewport(breakpoints.large.width, breakpoints.large.height);

    const LargeScreenLayout = () => (
      <div 
        className="large-screen-layout"
        style={{
          display: 'grid',
          gridTemplateColumns: '300px 1fr 400px',
          gridTemplateRows: '80px 1fr',
          gridTemplateAreas: `
            "header header header"
            "sidebar main aside"
          `,
          minHeight: '100vh'
        }}
      >
        <header 
          role="banner"
          style={{
            gridArea: 'header',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'space-between',
            padding: '0 32px',
            borderBottom: '1px solid #ddd',
            backgroundColor: '#fff'
          }}
        >
          <h1 style={{ fontSize: '2rem' }}>Large Screen Layout</h1>
          
          <nav role="navigation" aria-label="Primary navigation">
            <ul 
              role="menubar"
              style={{
                display: 'flex',
                listStyle: 'none',
                margin: 0,
                padding: 0,
                gap: '32px'
              }}
            >
              {['Dashboard', 'Analytics', 'Campaigns', 'Reports', 'Team', 'Settings'].map((item) => (
                <li key={item} role="none">
                  <a
                    href={`/${item.toLowerCase()}`}
                    role="menuitem"
                    style={{
                      textDecoration: 'none',
                      color: '#333',
                      padding: '12px 16px',
                      borderRadius: '6px',
                      transition: 'all 0.2s ease'
                    }}
                  >
                    {item}
                  </a>
                </li>
              ))}
            </ul>
          </nav>
        </header>

        <aside 
          role="complementary"
          aria-label="Navigation and filters"
          style={{
            gridArea: 'sidebar',
            padding: '32px 24px',
            borderRight: '1px solid #ddd',
            backgroundColor: '#f8f9fa'
          }}
        >
          <section>
            <h2 style={{ fontSize: '1.25rem', marginBottom: '24px' }}>Quick Actions</h2>
            <div style={{ marginBottom: '32px' }}>
              {['New Campaign', 'Generate Report', 'Import Data'].map((action) => (
                <button
                  key={action}
                  type="button"
                  style={{
                    width: '100%',
                    padding: '12px 16px',
                    marginBottom: '12px',
                    border: '1px solid #007bff',
                    backgroundColor: '#fff',
                    color: '#007bff',
                    borderRadius: '6px',
                    textAlign: 'left'
                  }}
                >
                  {action}
                </button>
              ))}
            </div>
          </section>

          <section>
            <h2 style={{ fontSize: '1.25rem', marginBottom: '24px' }}>Filters</h2>
            
            <div style={{ marginBottom: '24px' }}>
              <label htmlFor="advanced-search" style={{ display: 'block', marginBottom: '8px' }}>
                Advanced Search
              </label>
              <input
                type="text"
                id="advanced-search"
                style={{
                  width: '100%',
                  padding: '10px 12px',
                  border: '2px solid #ccc',
                  borderRadius: '6px'
                }}
                placeholder="Search with filters..."
              />
            </div>

            <div style={{ marginBottom: '24px' }}>
              <label htmlFor="category-filter" style={{ display: 'block', marginBottom: '8px' }}>
                Category
              </label>
              <select
                id="category-filter"
                style={{
                  width: '100%',
                  padding: '10px',
                  border: '2px solid #ccc',
                  borderRadius: '6px'
                }}
              >
                <option>All Categories</option>
                <option>Marketing</option>
                <option>Sales</option>
                <option>Support</option>
              </select>
            </div>
          </section>
        </aside>

        <main 
          role="main"
          style={{
            gridArea: 'main',
            padding: '32px',
            overflow: 'auto'
          }}
        >
          <div 
            style={{
              display: 'grid',
              gridTemplateColumns: 'repeat(auto-fit, minmax(400px, 1fr))',
              gap: '32px',
              marginBottom: '32px'
            }}
          >
            {/* Large screen dashboard widgets */}
            {[1, 2, 3, 4].map((widget) => (
              <div
                key={widget}
                role="region"
                aria-labelledby={`widget-${widget}-title`}
                style={{
                  border: '1px solid #ddd',
                  borderRadius: '12px',
                  padding: '24px',
                  backgroundColor: '#fff',
                  boxShadow: '0 2px 4px rgba(0,0,0,0.1)'
                }}
              >
                <h3 id={`widget-${widget}-title`} style={{ marginBottom: '20px' }}>
                  Advanced Widget {widget}
                </h3>
                
                {/* Widget content */}
                <div style={{ height: '200px', marginBottom: '20px' }}>
                  <div 
                    role="img"
                    aria-label={`Chart data for widget ${widget}`}
                    style={{
                      width: '100%',
                      height: '100%',
                      backgroundColor: '#f8f9fa',
                      borderRadius: '8px',
                      display: 'flex',
                      alignItems: 'center',
                      justifyContent: 'center',
                      color: '#666'
                    }}
                  >
                    Chart Visualization {widget}
                  </div>
                </div>
                
                <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                  <div>
                    <div style={{ fontSize: '2rem', fontWeight: 'bold', color: '#007bff' }}>
                      {Math.floor(Math.random() * 10000)}
                    </div>
                    <div style={{ fontSize: '0.875rem', color: '#666' }}>
                      +{Math.floor(Math.random() * 20)}% this week
                    </div>
                  </div>
                  
                  <button
                    type="button"
                    aria-label={`View details for widget ${widget}`}
                    style={{
                      padding: '8px 16px',
                      border: '1px solid #007bff',
                      backgroundColor: 'transparent',
                      color: '#007bff',
                      borderRadius: '6px'
                    }}
                  >
                    View Details
                  </button>
                </div>
              </div>
            ))}
          </div>

          {/* Large data table */}
          <section>
            <h2 style={{ marginBottom: '24px' }}>Detailed Data View</h2>
            <div style={{ overflowX: 'auto' }}>
              <table 
                role="table"
                style={{
                  width: '100%',
                  borderCollapse: 'collapse',
                  backgroundColor: '#fff',
                  borderRadius: '8px',
                  overflow: 'hidden',
                  boxShadow: '0 2px 4px rgba(0,0,0,0.1)'
                }}
              >
                <thead>
                  <tr style={{ backgroundColor: '#f8f9fa' }}>
                    <th scope="col" style={{ padding: '16px', textAlign: 'left', borderBottom: '1px solid #ddd' }}>
                      Campaign
                    </th>
                    <th scope="col" style={{ padding: '16px', textAlign: 'left', borderBottom: '1px solid #ddd' }}>
                      Status
                    </th>
                    <th scope="col" style={{ padding: '16px', textAlign: 'left', borderBottom: '1px solid #ddd' }}>
                      Budget
                    </th>
                    <th scope="col" style={{ padding: '16px', textAlign: 'left', borderBottom: '1px solid #ddd' }}>
                      Performance
                    </th>
                    <th scope="col" style={{ padding: '16px', textAlign: 'left', borderBottom: '1px solid #ddd' }}>
                      Actions
                    </th>
                  </tr>
                </thead>
                <tbody>
                  {[1, 2, 3, 4, 5].map((row) => (
                    <tr key={row} style={{ borderBottom: '1px solid #eee' }}>
                      <th scope="row" style={{ padding: '16px' }}>
                        Campaign {row}
                      </th>
                      <td style={{ padding: '16px' }}>
                        <span 
                          style={{
                            padding: '4px 12px',
                            borderRadius: '20px',
                            backgroundColor: row % 2 === 0 ? '#d4edda' : '#fff3cd',
                            color: row % 2 === 0 ? '#155724' : '#856404',
                            fontSize: '0.875rem'
                          }}
                        >
                          {row % 2 === 0 ? 'Active' : 'Paused'}
                        </span>
                      </td>
                      <td style={{ padding: '16px' }}>
                        ${(Math.random() * 50000).toFixed(0)}
                      </td>
                      <td style={{ padding: '16px' }}>
                        {(Math.random() * 100).toFixed(1)}%
                      </td>
                      <td style={{ padding: '16px' }}>
                        <div role="group" aria-label={`Actions for campaign ${row}`}>
                          <button
                            type="button"
                            aria-label={`Edit campaign ${row}`}
                            style={{
                              padding: '6px 12px',
                              marginRight: '8px',
                              border: '1px solid #007bff',
                              backgroundColor: 'transparent',
                              color: '#007bff',
                              borderRadius: '4px',
                              fontSize: '0.875rem'
                            }}
                          >
                            Edit
                          </button>
                          <button
                            type="button"
                            aria-label={`View campaign ${row}`}
                            style={{
                              padding: '6px 12px',
                              border: '1px solid #28a745',
                              backgroundColor: 'transparent',
                              color: '#28a745',
                              borderRadius: '4px',
                              fontSize: '0.875rem'
                            }}
                          >
                            View
                          </button>
                        </div>
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          </section>
        </main>

        <aside 
          role="complementary"
          aria-label="Activity and notifications"
          style={{
            gridArea: 'aside',
            padding: '32px 24px',
            borderLeft: '1px solid #ddd',
            backgroundColor: '#fff'
          }}
        >
          <section>
            <h2 style={{ fontSize: '1.25rem', marginBottom: '24px' }}>Recent Activity</h2>
            <ul role="list" style={{ listStyle: 'none', padding: 0, margin: 0 }}>
              {[1, 2, 3, 4, 5].map((item) => (
                <li 
                  key={item}
                  style={{
                    padding: '16px',
                    marginBottom: '12px',
                    border: '1px solid #eee',
                    borderRadius: '8px',
                    backgroundColor: '#f8f9fa'
                  }}
                >
                  <div style={{ fontWeight: '500', marginBottom: '4px' }}>
                    Activity {item}
                  </div>
                  <div style={{ fontSize: '0.875rem', color: '#666' }}>
                    Description of activity {item}
                  </div>
                  <div style={{ fontSize: '0.75rem', color: '#999', marginTop: '8px' }}>
                    {Math.floor(Math.random() * 60)} minutes ago
                  </div>
                </li>
              ))}
            </ul>
          </section>

          <section style={{ marginTop: '32px' }}>
            <h2 style={{ fontSize: '1.25rem', marginBottom: '24px' }}>Quick Stats</h2>
            <div>
              {[
                { label: 'Total Campaigns', value: '24' },
                { label: 'Active Users', value: '1,247' },
                { label: 'Conversion Rate', value: '3.8%' },
                { label: 'Revenue', value: '$45,230' }
              ].map((stat, index) => (
                <div 
                  key={stat.label}
                  style={{
                    padding: '16px',
                    marginBottom: '12px',
                    textAlign: 'center',
                    border: '1px solid #ddd',
                    borderRadius: '8px'
                  }}
                >
                  <div style={{ fontSize: '1.5rem', fontWeight: 'bold', color: '#007bff' }}>
                    {stat.value}
                  </div>
                  <div style={{ fontSize: '0.875rem', color: '#666' }}>
                    {stat.label}
                  </div>
                </div>
              ))}
            </div>
          </section>
        </aside>
      </div>
    );

    const { container } = render(<LargeScreenLayout />);
    
    const results = await axe(container, wcagConfig);
    expect(results).toHaveNoViolations();

    // Test advanced navigation
    const primaryNav = screen.getByRole('navigation', { name: 'Primary navigation' });
    expect(primaryNav).toBeInTheDocument();

    // Test complex grid layout
    const widgets = screen.getAllByText(/Advanced Widget/);
    expect(widgets).toHaveLength(4);

    // Test large data table
    const dataTable = screen.getByRole('table');
    expect(dataTable).toBeInTheDocument();

    // Test action buttons in table
    const editButtons = screen.getAllByRole('button', { name: /edit campaign/i });
    expect(editButtons.length).toBeGreaterThan(0);
  });

  it('should maintain accessibility across breakpoint transitions', async () => {
    const ResponsiveTransition = () => {
      const [windowWidth, setWindowWidth] = React.useState(1440);
      
      React.useEffect(() => {
        const handleResize = () => {
          setWindowWidth(window.innerWidth);
        };
        
        window.addEventListener('resize', handleResize);
        return () => window.removeEventListener('resize', handleResize);
      }, []);

      const isMobile = windowWidth < 768;
      const isTablet = windowWidth >= 768 && windowWidth < 1200;
      const isDesktop = windowWidth >= 1200;

      return (
        <div className="responsive-transition">
          <header role="banner">
            <h1 style={{ fontSize: isMobile ? '1.5rem' : isTablet ? '1.75rem' : '2rem' }}>
              Responsive Header
            </h1>
            
            {/* Navigation adapts to screen size */}
            {isMobile ? (
              <button
                type="button"
                aria-label="Toggle navigation menu"
                style={{ minHeight: '44px', minWidth: '44px' }}
              >
                Menu
              </button>
            ) : (
              <nav role="navigation" aria-label="Primary navigation">
                <ul role="list" style={{ display: 'flex', gap: isTablet ? '16px' : '24px' }}>
                  {['Home', 'About', 'Services', 'Contact'].map((item) => (
                    <li key={item}>
                      <a href={`/${item.toLowerCase()}`}>{item}</a>
                    </li>
                  ))}
                </ul>
              </nav>
            )}
          </header>

          <main role="main" style={{ padding: isMobile ? '16px' : isTablet ? '24px' : '32px' }}>
            {/* Content grid adapts */}
            <div
              style={{
                display: 'grid',
                gridTemplateColumns: isMobile ? '1fr' : 
                                   isTablet ? 'repeat(2, 1fr)' : 
                                   'repeat(3, 1fr)',
                gap: isMobile ? '16px' : isTablet ? '20px' : '24px'
              }}
              role="region"
              aria-label="Content grid"
            >
              {[1, 2, 3, 4, 5, 6].map((item) => (
                <div
                  key={item}
                  style={{
                    padding: isMobile ? '16px' : '20px',
                    border: '1px solid #ddd',
                    borderRadius: '8px'
                  }}
                  role="article"
                >
                  <h2 style={{ 
                    fontSize: isMobile ? '1.125rem' : '1.25rem', 
                    marginBottom: '12px' 
                  }}>
                    Item {item}
                  </h2>
                  <p style={{ lineHeight: '1.6' }}>
                    Content that adapts to different screen sizes.
                  </p>
                  <button
                    type="button"
                    style={{
                      minHeight: isMobile ? '44px' : '40px',
                      padding: isMobile ? '12px 16px' : '8px 16px',
                      fontSize: isMobile ? '16px' : '14px',
                      width: isMobile ? '100%' : 'auto'
                    }}
                  >
                    Action
                  </button>
                </div>
              ))}
            </div>

            {/* Form adapts */}
            <section style={{ marginTop: '32px' }}>
              <h2>Responsive Form</h2>
              <form style={{ maxWidth: isDesktop ? '600px' : '100%' }}>
                <div 
                  style={{
                    display: isMobile ? 'block' : 'grid',
                    gridTemplateColumns: isMobile ? '1fr' : 'repeat(2, 1fr)',
                    gap: '16px',
                    marginBottom: '24px'
                  }}
                >
                  <div style={{ marginBottom: isMobile ? '16px' : '0' }}>
                    <label htmlFor="responsive-email" style={{ display: 'block', marginBottom: '8px' }}>
                      Email
                    </label>
                    <input
                      type="email"
                      id="responsive-email"
                      style={{
                        width: '100%',
                        minHeight: isMobile ? '44px' : '40px',
                        padding: '8px 12px',
                        fontSize: isMobile ? '16px' : '14px',
                        border: '2px solid #ccc',
                        borderRadius: '4px'
                      }}
                    />
                  </div>
                  
                  <div>
                    <label htmlFor="responsive-phone" style={{ display: 'block', marginBottom: '8px' }}>
                      Phone
                    </label>
                    <input
                      type="tel"
                      id="responsive-phone"
                      style={{
                        width: '100%',
                        minHeight: isMobile ? '44px' : '40px',
                        padding: '8px 12px',
                        fontSize: isMobile ? '16px' : '14px',
                        border: '2px solid #ccc',
                        borderRadius: '4px'
                      }}
                    />
                  </div>
                </div>
                
                <button
                  type="submit"
                  style={{
                    minHeight: isMobile ? '44px' : '40px',
                    padding: '12px 24px',
                    fontSize: isMobile ? '16px' : '14px',
                    width: isMobile ? '100%' : 'auto',
                    backgroundColor: '#007bff',
                    color: '#fff',
                    border: 'none',
                    borderRadius: '4px'
                  }}
                >
                  Submit
                </button>
              </form>
            </section>
          </main>

          {/* Screen size indicator for testing */}
          <div 
            role="status" 
            aria-live="polite"
            style={{
              position: 'fixed',
              bottom: '20px',
              right: '20px',
              padding: '8px 12px',
              backgroundColor: '#333',
              color: '#fff',
              borderRadius: '4px',
              fontSize: '12px'
            }}
          >
            {isMobile ? 'Mobile' : isTablet ? 'Tablet' : 'Desktop'} ({windowWidth}px)
          </div>
        </div>
      );
    };

    // Test at different breakpoints
    for (const [breakpointName, dimensions] of Object.entries(breakpoints)) {
      global.testUtils.mockViewport(dimensions.width, dimensions.height);
      
      const { container, unmount } = render(<ResponsiveTransition />);
      
      const results = await axe(container, wcagConfig);
      expect(results).toHaveNoViolations();

      // Test responsive elements
      const header = screen.getByRole('banner');
      expect(header).toBeInTheDocument();

      const main = screen.getByRole('main');
      expect(main).toBeInTheDocument();

      // Check touch targets on mobile
      if (breakpointName === 'mobile') {
        const menuButton = screen.queryByRole('button', { name: /toggle navigation/i });
        if (menuButton) {
          const computedStyle = window.getComputedStyle(menuButton);
          expect(parseInt(computedStyle.minHeight)).toBeGreaterThanOrEqual(44);
          expect(parseInt(computedStyle.minWidth)).toBeGreaterThanOrEqual(44);
        }
      }

      // Check form inputs have appropriate font size on mobile (prevents zoom)
      const emailInput = screen.getByLabelText('Email');
      if (breakpointName === 'mobile') {
        expect(emailInput).toHaveStyle({ fontSize: '16px' });
      }

      unmount();
    }
  });
});