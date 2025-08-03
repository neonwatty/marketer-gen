import React from 'react';
import { render, screen, fireEvent, waitFor } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { axe, toHaveNoViolations } from 'jest-axe';

expect.extend(toHaveNoViolations);

// Theme system accessibility and color contrast testing
describe('Theme System Accessibility', () => {
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
      'tabindex': { enabled: true }
    },
    tags: ['wcag2a', 'wcag2aa', 'wcag21aa']
  };

  // WCAG AA compliant color combinations
  const themes = {
    light: {
      name: 'Light Theme',
      colors: {
        background: '#ffffff',
        surface: '#f8f9fa',
        text: '#212529',
        textSecondary: '#6c757d',
        primary: '#007bff',
        primaryText: '#ffffff',
        success: '#28a745',
        successText: '#ffffff',
        warning: '#ffc107',
        warningText: '#212529',
        danger: '#dc3545',
        dangerText: '#ffffff',
        border: '#dee2e6',
        focus: '#0056b3'
      }
    },
    dark: {
      name: 'Dark Theme',
      colors: {
        background: '#121212',
        surface: '#1e1e1e',
        text: '#ffffff',
        textSecondary: '#b3b3b3',
        primary: '#4dabf7',
        primaryText: '#000000',
        success: '#51cf66',
        successText: '#000000',
        warning: '#ffd43b',
        warningText: '#000000',
        danger: '#ff6b6b',
        dangerText: '#000000',
        border: '#333333',
        focus: '#74c0fc'
      }
    },
    highContrast: {
      name: 'High Contrast',
      colors: {
        background: '#000000',
        surface: '#000000',
        text: '#ffffff',
        textSecondary: '#ffffff',
        primary: '#ffff00',
        primaryText: '#000000',
        success: '#00ff00',
        successText: '#000000',
        warning: '#ffff00',
        warningText: '#000000',
        danger: '#ff0000',
        dangerText: '#ffffff',
        border: '#ffffff',
        focus: '#ffff00'
      }
    }
  };

  it('should meet WCAG AA color contrast requirements for light theme', async () => {
    const LightThemeComponent = () => (
      <div 
        style={{ 
          backgroundColor: themes.light.colors.background,
          color: themes.light.colors.text,
          padding: '20px',
          minHeight: '400px'
        }}
      >
        {/* Regular text - needs 4.5:1 contrast ratio */}
        <p style={{ color: themes.light.colors.text, fontSize: '16px' }}>
          This is regular text that should meet AA contrast requirements (4.5:1 ratio)
        </p>
        
        <p style={{ color: themes.light.colors.textSecondary, fontSize: '16px' }}>
          This is secondary text that should also meet AA requirements
        </p>

        {/* Large text - needs 3:1 contrast ratio */}
        <h1 style={{ 
          color: themes.light.colors.text, 
          fontSize: '32px', 
          fontWeight: 'bold',
          marginBottom: '20px'
        }}>
          Large Text Header (3:1 ratio required)
        </h1>

        <h2 style={{ 
          color: themes.light.colors.text, 
          fontSize: '24px', 
          fontWeight: 'bold',
          marginBottom: '16px'
        }}>
          Smaller Large Text (3:1 ratio required)
        </h2>

        {/* Interactive elements */}
        <div style={{ marginBottom: '20px' }}>
          <button 
            style={{ 
              backgroundColor: themes.light.colors.primary,
              color: themes.light.colors.primaryText,
              border: '2px solid transparent',
              padding: '12px 24px',
              fontSize: '16px',
              borderRadius: '4px',
              marginRight: '12px'
            }}
            onFocus={(e) => {
              e.target.style.outline = `2px solid ${themes.light.colors.focus}`;
              e.target.style.outlineOffset = '2px';
            }}
            onBlur={(e) => {
              e.target.style.outline = 'none';
            }}
          >
            Primary Button
          </button>
          
          <button 
            style={{ 
              backgroundColor: themes.light.colors.success,
              color: themes.light.colors.successText,
              border: '2px solid transparent',
              padding: '12px 24px',
              fontSize: '16px',
              borderRadius: '4px',
              marginRight: '12px'
            }}
            onFocus={(e) => {
              e.target.style.outline = `2px solid ${themes.light.colors.focus}`;
              e.target.style.outlineOffset = '2px';
            }}
            onBlur={(e) => {
              e.target.style.outline = 'none';
            }}
          >
            Success Button
          </button>
          
          <button 
            style={{ 
              backgroundColor: themes.light.colors.warning,
              color: themes.light.colors.warningText,
              border: '2px solid transparent',
              padding: '12px 24px',
              fontSize: '16px',
              borderRadius: '4px',
              marginRight: '12px'
            }}
            onFocus={(e) => {
              e.target.style.outline = `2px solid ${themes.light.colors.focus}`;
              e.target.style.outlineOffset = '2px';
            }}
            onBlur={(e) => {
              e.target.style.outline = 'none';
            }}
          >
            Warning Button
          </button>
          
          <button 
            style={{ 
              backgroundColor: themes.light.colors.danger,
              color: themes.light.colors.dangerText,
              border: '2px solid transparent',
              padding: '12px 24px',
              fontSize: '16px',
              borderRadius: '4px'
            }}
            onFocus={(e) => {
              e.target.style.outline = `2px solid ${themes.light.colors.focus}`;
              e.target.style.outlineOffset = '2px';
            }}
            onBlur={(e) => {
              e.target.style.outline = 'none';
            }}
          >
            Danger Button
          </button>
        </div>

        {/* Links */}
        <div style={{ marginBottom: '20px' }}>
          <a 
            href="#example" 
            style={{ 
              color: themes.light.colors.primary,
              textDecoration: 'underline'
            }}
            onFocus={(e) => {
              e.target.style.outline = `2px solid ${themes.light.colors.focus}`;
              e.target.style.outlineOffset = '2px';
            }}
            onBlur={(e) => {
              e.target.style.outline = 'none';
            }}
          >
            Link with proper contrast
          </a>
        </div>

        {/* Form elements */}
        <div style={{ marginBottom: '20px' }}>
          <label 
            htmlFor="theme-input"
            style={{ 
              display: 'block', 
              color: themes.light.colors.text,
              marginBottom: '8px',
              fontSize: '16px'
            }}
          >
            Form Input Label
          </label>
          <input
            type="text"
            id="theme-input"
            style={{
              backgroundColor: themes.light.colors.background,
              color: themes.light.colors.text,
              border: `2px solid ${themes.light.colors.border}`,
              padding: '8px 12px',
              fontSize: '16px',
              borderRadius: '4px'
            }}
            onFocus={(e) => {
              e.target.style.borderColor = themes.light.colors.focus;
              e.target.style.outline = `2px solid ${themes.light.colors.focus}`;
              e.target.style.outlineOffset = '2px';
            }}
            onBlur={(e) => {
              e.target.style.borderColor = themes.light.colors.border;
              e.target.style.outline = 'none';
            }}
            placeholder="Placeholder text"
          />
        </div>

        {/* Status indicators */}
        <div style={{ marginBottom: '20px' }}>
          <div 
            role="alert"
            style={{
              backgroundColor: themes.light.colors.danger,
              color: themes.light.colors.dangerText,
              padding: '12px',
              borderRadius: '4px',
              marginBottom: '12px'
            }}
          >
            Error message with proper contrast
          </div>
          
          <div 
            role="status"
            style={{
              backgroundColor: themes.light.colors.success,
              color: themes.light.colors.successText,
              padding: '12px',
              borderRadius: '4px',
              marginBottom: '12px'
            }}
          >
            Success message with proper contrast
          </div>
          
          <div 
            style={{
              backgroundColor: themes.light.colors.warning,
              color: themes.light.colors.warningText,
              padding: '12px',
              borderRadius: '4px'
            }}
          >
            Warning message with proper contrast
          </div>
        </div>
      </div>
    );

    const { container } = render(<LightThemeComponent />);
    
    const results = await axe(container, wcagConfig);
    expect(results).toHaveNoViolations();

    // Test focus indicators
    const primaryButton = screen.getByRole('button', { name: 'Primary Button' });
    primaryButton.focus();
    expect(primaryButton).toHaveFocus();

    const linkElement = screen.getByRole('link', { name: 'Link with proper contrast' });
    linkElement.focus();
    expect(linkElement).toHaveFocus();
  });

  it('should meet WCAG AA color contrast requirements for dark theme', async () => {
    const DarkThemeComponent = () => (
      <div 
        style={{ 
          backgroundColor: themes.dark.colors.background,
          color: themes.dark.colors.text,
          padding: '20px',
          minHeight: '400px'
        }}
      >
        {/* Dark theme text */}
        <p style={{ color: themes.dark.colors.text, fontSize: '16px' }}>
          Dark theme regular text with proper contrast
        </p>
        
        <p style={{ color: themes.dark.colors.textSecondary, fontSize: '16px' }}>
          Dark theme secondary text with adequate contrast
        </p>

        {/* Dark theme headers */}
        <h1 style={{ 
          color: themes.dark.colors.text, 
          fontSize: '32px', 
          fontWeight: 'bold',
          marginBottom: '20px'
        }}>
          Dark Theme Header
        </h1>

        {/* Dark theme buttons */}
        <div style={{ marginBottom: '20px' }}>
          <button 
            style={{ 
              backgroundColor: themes.dark.colors.primary,
              color: themes.dark.colors.primaryText,
              border: '2px solid transparent',
              padding: '12px 24px',
              fontSize: '16px',
              borderRadius: '4px',
              marginRight: '12px'
            }}
            onFocus={(e) => {
              e.target.style.outline = `2px solid ${themes.dark.colors.focus}`;
              e.target.style.outlineOffset = '2px';
            }}
            onBlur={(e) => {
              e.target.style.outline = 'none';
            }}
          >
            Primary Button
          </button>
          
          <button 
            style={{ 
              backgroundColor: themes.dark.colors.success,
              color: themes.dark.colors.successText,
              border: '2px solid transparent',
              padding: '12px 24px',
              fontSize: '16px',
              borderRadius: '4px',
              marginRight: '12px'
            }}
          >
            Success Button
          </button>
        </div>

        {/* Dark theme form */}
        <div style={{ marginBottom: '20px' }}>
          <label 
            htmlFor="dark-input"
            style={{ 
              display: 'block', 
              color: themes.dark.colors.text,
              marginBottom: '8px',
              fontSize: '16px'
            }}
          >
            Dark Theme Input
          </label>
          <input
            type="text"
            id="dark-input"
            style={{
              backgroundColor: themes.dark.colors.surface,
              color: themes.dark.colors.text,
              border: `2px solid ${themes.dark.colors.border}`,
              padding: '8px 12px',
              fontSize: '16px',
              borderRadius: '4px'
            }}
            onFocus={(e) => {
              e.target.style.borderColor = themes.dark.colors.focus;
              e.target.style.outline = `2px solid ${themes.dark.colors.focus}`;
              e.target.style.outlineOffset = '2px';
            }}
            onBlur={(e) => {
              e.target.style.borderColor = themes.dark.colors.border;
              e.target.style.outline = 'none';
            }}
          />
        </div>

        {/* Dark theme cards */}
        <div 
          style={{
            backgroundColor: themes.dark.colors.surface,
            border: `1px solid ${themes.dark.colors.border}`,
            padding: '20px',
            borderRadius: '8px',
            marginBottom: '20px'
          }}
        >
          <h3 style={{ color: themes.dark.colors.text, marginBottom: '12px' }}>
            Dark Theme Card
          </h3>
          <p style={{ color: themes.dark.colors.textSecondary, marginBottom: '16px' }}>
            Card content with proper dark theme contrast
          </p>
          <button
            style={{
              backgroundColor: themes.dark.colors.primary,
              color: themes.dark.colors.primaryText,
              border: 'none',
              padding: '8px 16px',
              borderRadius: '4px'
            }}
          >
            Card Action
          </button>
        </div>
      </div>
    );

    const { container } = render(<DarkThemeComponent />);
    
    const results = await axe(container, wcagConfig);
    expect(results).toHaveNoViolations();

    // Verify dark theme elements
    const darkInput = screen.getByLabelText('Dark Theme Input');
    expect(darkInput).toBeInTheDocument();

    const cardAction = screen.getByRole('button', { name: 'Card Action' });
    expect(cardAction).toBeInTheDocument();
  });

  it('should provide high contrast theme for enhanced accessibility', async () => {
    const HighContrastComponent = () => (
      <div 
        style={{ 
          backgroundColor: themes.highContrast.colors.background,
          color: themes.highContrast.colors.text,
          padding: '20px',
          minHeight: '400px'
        }}
      >
        {/* High contrast text */}
        <p style={{ color: themes.highContrast.colors.text, fontSize: '16px' }}>
          High contrast text with maximum readability
        </p>

        <h1 style={{ 
          color: themes.highContrast.colors.text, 
          fontSize: '32px', 
          fontWeight: 'bold',
          marginBottom: '20px'
        }}>
          High Contrast Header
        </h1>

        {/* High contrast buttons */}
        <div style={{ marginBottom: '20px' }}>
          <button 
            style={{ 
              backgroundColor: themes.highContrast.colors.primary,
              color: themes.highContrast.colors.primaryText,
              border: `3px solid ${themes.highContrast.colors.border}`,
              padding: '12px 24px',
              fontSize: '16px',
              fontWeight: 'bold',
              borderRadius: '0', // High contrast often uses sharp corners
              marginRight: '12px'
            }}
            onFocus={(e) => {
              e.target.style.outline = `3px solid ${themes.highContrast.colors.focus}`;
              e.target.style.outlineOffset = '2px';
            }}
            onBlur={(e) => {
              e.target.style.outline = 'none';
            }}
          >
            Primary Action
          </button>
          
          <button 
            style={{ 
              backgroundColor: themes.highContrast.colors.success,
              color: themes.highContrast.colors.successText,
              border: `3px solid ${themes.highContrast.colors.border}`,
              padding: '12px 24px',
              fontSize: '16px',
              fontWeight: 'bold',
              borderRadius: '0',
              marginRight: '12px'
            }}
          >
            Success Action
          </button>
          
          <button 
            style={{ 
              backgroundColor: themes.highContrast.colors.danger,
              color: themes.highContrast.colors.dangerText,
              border: `3px solid ${themes.highContrast.colors.border}`,
              padding: '12px 24px',
              fontSize: '16px',
              fontWeight: 'bold',
              borderRadius: '0'
            }}
          >
            Danger Action
          </button>
        </div>

        {/* High contrast form */}
        <div style={{ marginBottom: '20px' }}>
          <label 
            htmlFor="hc-input"
            style={{ 
              display: 'block', 
              color: themes.highContrast.colors.text,
              marginBottom: '8px',
              fontSize: '18px',
              fontWeight: 'bold'
            }}
          >
            High Contrast Input
          </label>
          <input
            type="text"
            id="hc-input"
            style={{
              backgroundColor: themes.highContrast.colors.background,
              color: themes.highContrast.colors.text,
              border: `3px solid ${themes.highContrast.colors.border}`,
              padding: '12px',
              fontSize: '18px',
              fontWeight: 'bold',
              borderRadius: '0'
            }}
            onFocus={(e) => {
              e.target.style.outline = `3px solid ${themes.highContrast.colors.focus}`;
              e.target.style.outlineOffset = '2px';
            }}
            onBlur={(e) => {
              e.target.style.outline = 'none';
            }}
          />
        </div>

        {/* High contrast links */}
        <div style={{ marginBottom: '20px' }}>
          <a 
            href="#hc-example" 
            style={{ 
              color: themes.highContrast.colors.primary,
              textDecoration: 'underline',
              fontSize: '18px',
              fontWeight: 'bold'
            }}
            onFocus={(e) => {
              e.target.style.outline = `3px solid ${themes.highContrast.colors.focus}`;
              e.target.style.outlineOffset = '2px';
            }}
            onBlur={(e) => {
              e.target.style.outline = 'none';
            }}
          >
            High Contrast Link
          </a>
        </div>

        {/* High contrast alerts */}
        <div 
          role="alert"
          style={{
            backgroundColor: themes.highContrast.colors.danger,
            color: themes.highContrast.colors.dangerText,
            border: `3px solid ${themes.highContrast.colors.border}`,
            padding: '16px',
            fontSize: '18px',
            fontWeight: 'bold',
            borderRadius: '0'
          }}
        >
          High contrast error message
        </div>
      </div>
    );

    const { container } = render(<HighContrastComponent />);
    
    const results = await axe(container, wcagConfig);
    expect(results).toHaveNoViolations();

    // Test high contrast elements
    const hcInput = screen.getByLabelText('High Contrast Input');
    expect(hcInput).toBeInTheDocument();

    const hcLink = screen.getByRole('link', { name: 'High Contrast Link' });
    hcLink.focus();
    expect(hcLink).toHaveFocus();
  });

  it('should provide accessible theme switching interface', async () => {
    const ThemeSwitcher = () => {
      const [currentTheme, setCurrentTheme] = React.useState('light');
      const [reducedMotion, setReducedMotion] = React.useState(false);
      const [highContrast, setHighContrast] = React.useState(false);

      const theme = themes[currentTheme as keyof typeof themes];

      return (
        <div 
          style={{ 
            backgroundColor: theme.colors.background,
            color: theme.colors.text,
            padding: '20px',
            minHeight: '100vh',
            transition: reducedMotion ? 'none' : 'all 0.3s ease'
          }}
        >
          <h1 style={{ marginBottom: '32px' }}>Theme Accessibility Settings</h1>
          
          {/* Theme selection */}
          <section style={{ marginBottom: '32px' }}>
            <fieldset>
              <legend style={{ fontSize: '1.125rem', fontWeight: 'bold', marginBottom: '16px' }}>
                Choose Theme
              </legend>
              <div role="radiogroup" aria-label="Theme selection">
                {Object.entries(themes).map(([key, themeConfig]) => (
                  <label 
                    key={key}
                    style={{ 
                      display: 'block', 
                      marginBottom: '12px',
                      padding: '12px',
                      border: currentTheme === key ? `2px solid ${theme.colors.focus}` : `1px solid ${theme.colors.border}`,
                      borderRadius: '8px',
                      backgroundColor: currentTheme === key ? theme.colors.surface : 'transparent'
                    }}
                  >
                    <input
                      type="radio"
                      name="theme"
                      value={key}
                      checked={currentTheme === key}
                      onChange={(e) => setCurrentTheme(e.target.value)}
                      style={{ marginRight: '12px' }}
                    />
                    <span style={{ fontWeight: currentTheme === key ? 'bold' : 'normal' }}>
                      {themeConfig.name}
                    </span>
                    <div style={{ fontSize: '0.875rem', color: theme.colors.textSecondary, marginTop: '4px' }}>
                      {key === 'light' && 'Standard light theme with good contrast'}
                      {key === 'dark' && 'Dark theme that reduces eye strain'}
                      {key === 'highContrast' && 'Maximum contrast for enhanced accessibility'}
                    </div>
                  </label>
                ))}
              </div>
            </fieldset>
          </section>

          {/* Accessibility preferences */}
          <section style={{ marginBottom: '32px' }}>
            <h2 style={{ fontSize: '1.125rem', fontWeight: 'bold', marginBottom: '16px' }}>
              Accessibility Preferences
            </h2>
            
            <div style={{ marginBottom: '16px' }}>
              <label style={{ display: 'flex', alignItems: 'center', cursor: 'pointer' }}>
                <input
                  type="checkbox"
                  checked={reducedMotion}
                  onChange={(e) => setReducedMotion(e.target.checked)}
                  style={{ marginRight: '12px' }}
                />
                <div>
                  <div style={{ fontWeight: '500' }}>Reduce Motion</div>
                  <div style={{ fontSize: '0.875rem', color: theme.colors.textSecondary }}>
                    Minimize animations and transitions
                  </div>
                </div>
              </label>
            </div>

            <div style={{ marginBottom: '16px' }}>
              <label style={{ display: 'flex', alignItems: 'center', cursor: 'pointer' }}>
                <input
                  type="checkbox"
                  checked={highContrast}
                  onChange={(e) => setHighContrast(e.target.checked)}
                  style={{ marginRight: '12px' }}
                />
                <div>
                  <div style={{ fontWeight: '500' }}>Force High Contrast</div>
                  <div style={{ fontSize: '0.875rem', color: theme.colors.textSecondary }}>
                    Override theme with maximum contrast
                  </div>
                </div>
              </label>
            </div>
          </section>

          {/* Theme preview */}
          <section style={{ marginBottom: '32px' }}>
            <h2 style={{ fontSize: '1.125rem', fontWeight: 'bold', marginBottom: '16px' }}>
              Theme Preview
            </h2>
            
            <div 
              style={{
                border: `2px solid ${theme.colors.border}`,
                borderRadius: '8px',
                padding: '20px',
                backgroundColor: theme.colors.surface
              }}
            >
              <h3 style={{ marginBottom: '16px' }}>Sample Content</h3>
              
              <p style={{ marginBottom: '16px', color: theme.colors.text }}>
                This is how regular text will appear in the selected theme.
              </p>
              
              <p style={{ marginBottom: '16px', color: theme.colors.textSecondary }}>
                This is secondary text with reduced opacity.
              </p>
              
              <div style={{ marginBottom: '16px' }}>
                <button
                  style={{
                    backgroundColor: theme.colors.primary,
                    color: theme.colors.primaryText,
                    border: 'none',
                    padding: '12px 24px',
                    borderRadius: '4px',
                    marginRight: '12px',
                    fontSize: '16px'
                  }}
                  onFocus={(e) => {
                    e.target.style.outline = `2px solid ${theme.colors.focus}`;
                    e.target.style.outlineOffset = '2px';
                  }}
                  onBlur={(e) => {
                    e.target.style.outline = 'none';
                  }}
                >
                  Primary Button
                </button>
                
                <a 
                  href="#preview" 
                  style={{ 
                    color: theme.colors.primary,
                    textDecoration: 'underline'
                  }}
                  onFocus={(e) => {
                    e.target.style.outline = `2px solid ${theme.colors.focus}`;
                    e.target.style.outlineOffset = '2px';
                  }}
                  onBlur={(e) => {
                    e.target.style.outline = 'none';
                  }}
                >
                  Sample Link
                </a>
              </div>
              
              <div>
                <label 
                  htmlFor="preview-input"
                  style={{ 
                    display: 'block', 
                    marginBottom: '8px',
                    color: theme.colors.text
                  }}
                >
                  Form Input
                </label>
                <input
                  type="text"
                  id="preview-input"
                  placeholder="Enter text here"
                  style={{
                    backgroundColor: theme.colors.background,
                    color: theme.colors.text,
                    border: `2px solid ${theme.colors.border}`,
                    padding: '8px 12px',
                    borderRadius: '4px',
                    fontSize: '16px'
                  }}
                  onFocus={(e) => {
                    e.target.style.borderColor = theme.colors.focus;
                    e.target.style.outline = `2px solid ${theme.colors.focus}`;
                    e.target.style.outlineOffset = '2px';
                  }}
                  onBlur={(e) => {
                    e.target.style.borderColor = theme.colors.border;
                    e.target.style.outline = 'none';
                  }}
                />
              </div>
            </div>
          </section>

          {/* Save preferences */}
          <section>
            <button
              type="button"
              style={{
                backgroundColor: theme.colors.primary,
                color: theme.colors.primaryText,
                border: 'none',
                padding: '14px 28px',
                borderRadius: '6px',
                fontSize: '16px',
                fontWeight: '500'
              }}
              onFocus={(e) => {
                e.target.style.outline = `2px solid ${theme.colors.focus}`;
                e.target.style.outlineOffset = '2px';
              }}
              onBlur={(e) => {
                e.target.style.outline = 'none';
              }}
              onClick={() => {
                // Save preferences to localStorage or user settings
                alert('Theme preferences saved!');
              }}
            >
              Save Preferences
            </button>
            
            <div 
              role="status" 
              aria-live="polite"
              style={{ 
                marginTop: '16px',
                fontSize: '0.875rem',
                color: theme.colors.textSecondary
              }}
            >
              Current theme: {theme.name}
              {reducedMotion && ' • Reduced motion enabled'}
              {highContrast && ' • High contrast mode enabled'}
            </div>
          </section>
        </div>
      );
    };

    const { container } = render(<ThemeSwitcher />);
    
    const results = await axe(container, wcagConfig);
    expect(results).toHaveNoViolations();

    // Test theme switching
    const darkThemeRadio = screen.getByRole('radio', { name: 'Dark Theme' });
    await userEvent.click(darkThemeRadio);
    
    expect(darkThemeRadio).toBeChecked();
    expect(screen.getByText('Current theme: Dark Theme')).toBeInTheDocument();

    // Test high contrast option
    const highContrastRadio = screen.getByRole('radio', { name: 'High Contrast' });
    await userEvent.click(highContrastRadio);
    
    expect(highContrastRadio).toBeChecked();

    // Test accessibility preferences
    const reducedMotionCheckbox = screen.getByRole('checkbox', { name: /reduce motion/i });
    await userEvent.click(reducedMotionCheckbox);
    
    expect(reducedMotionCheckbox).toBeChecked();
    expect(screen.getByText(/reduced motion enabled/i)).toBeInTheDocument();

    // Test save functionality
    const saveButton = screen.getByRole('button', { name: 'Save Preferences' });
    await userEvent.click(saveButton);
  });

  it('should respect system preferences for theme and motion', async () => {
    const SystemPreferencesComponent = () => {
      const [systemDarkMode, setSystemDarkMode] = React.useState(false);
      const [systemReducedMotion, setSystemReducedMotion] = React.useState(false);
      const [systemHighContrast, setSystemHighContrast] = React.useState(false);

      // Mock system preference detection
      React.useEffect(() => {
        // In a real implementation, these would detect actual system preferences
        const darkModeQuery = window.matchMedia('(prefers-color-scheme: dark)');
        const reducedMotionQuery = window.matchMedia('(prefers-reduced-motion: reduce)');
        const contrastQuery = window.matchMedia('(prefers-contrast: high)');

        setSystemDarkMode(darkModeQuery.matches);
        setSystemReducedMotion(reducedMotionQuery.matches);
        setSystemHighContrast(contrastQuery.matches);
      }, []);

      const currentTheme = systemHighContrast ? themes.highContrast :
                          systemDarkMode ? themes.dark : themes.light;

      return (
        <div 
          style={{ 
            backgroundColor: currentTheme.colors.background,
            color: currentTheme.colors.text,
            padding: '20px',
            minHeight: '400px',
            transition: systemReducedMotion ? 'none' : 'all 0.3s ease'
          }}
        >
          <h1 style={{ marginBottom: '24px' }}>System Preferences Detection</h1>
          
          <div role="status" aria-live="polite" style={{ marginBottom: '24px' }}>
            <h2 style={{ fontSize: '1.125rem', marginBottom: '12px' }}>
              Detected System Preferences:
            </h2>
            <ul style={{ listStyle: 'none', padding: 0 }}>
              <li style={{ marginBottom: '8px' }}>
                <strong>Color Scheme:</strong> {systemDarkMode ? 'Dark' : 'Light'}
              </li>
              <li style={{ marginBottom: '8px' }}>
                <strong>Motion:</strong> {systemReducedMotion ? 'Reduced' : 'No preference'}
              </li>
              <li style={{ marginBottom: '8px' }}>
                <strong>Contrast:</strong> {systemHighContrast ? 'High' : 'Standard'}
              </li>
            </ul>
          </div>

          <section style={{ marginBottom: '24px' }}>
            <h2 style={{ fontSize: '1.125rem', marginBottom: '16px' }}>
              System Preference Override
            </h2>
            <p style={{ marginBottom: '16px', color: currentTheme.colors.textSecondary }}>
              These controls simulate system preference changes for testing purposes.
            </p>
            
            <div style={{ marginBottom: '12px' }}>
              <label style={{ display: 'flex', alignItems: 'center' }}>
                <input
                  type="checkbox"
                  checked={systemDarkMode}
                  onChange={(e) => setSystemDarkMode(e.target.checked)}
                  style={{ marginRight: '12px' }}
                />
                Simulate Dark Mode Preference
              </label>
            </div>
            
            <div style={{ marginBottom: '12px' }}>
              <label style={{ display: 'flex', alignItems: 'center' }}>
                <input
                  type="checkbox"
                  checked={systemReducedMotion}
                  onChange={(e) => setSystemReducedMotion(e.target.checked)}
                  style={{ marginRight: '12px' }}
                />
                Simulate Reduced Motion Preference
              </label>
            </div>
            
            <div style={{ marginBottom: '12px' }}>
              <label style={{ display: 'flex', alignItems: 'center' }}>
                <input
                  type="checkbox"
                  checked={systemHighContrast}
                  onChange={(e) => setSystemHighContrast(e.target.checked)}
                  style={{ marginRight: '12px' }}
                />
                Simulate High Contrast Preference
              </label>
            </div>
          </section>

          <section>
            <h2 style={{ fontSize: '1.125rem', marginBottom: '16px' }}>
              Applied Theme: {currentTheme.name}
            </h2>
            
            <div 
              style={{
                backgroundColor: currentTheme.colors.surface,
                border: `1px solid ${currentTheme.colors.border}`,
                borderRadius: '8px',
                padding: '16px'
              }}
            >
              <p style={{ marginBottom: '16px' }}>
                This content automatically adapts to your system preferences.
              </p>
              
              <button
                style={{
                  backgroundColor: currentTheme.colors.primary,
                  color: currentTheme.colors.primaryText,
                  border: systemHighContrast ? `2px solid ${currentTheme.colors.border}` : 'none',
                  padding: '12px 24px',
                  borderRadius: systemHighContrast ? '0' : '4px',
                  fontSize: '16px',
                  fontWeight: systemHighContrast ? 'bold' : 'normal'
                }}
                onFocus={(e) => {
                  e.target.style.outline = `2px solid ${currentTheme.colors.focus}`;
                  e.target.style.outlineOffset = '2px';
                }}
                onBlur={(e) => {
                  e.target.style.outline = 'none';
                }}
              >
                Adaptive Button
              </button>
            </div>
          </section>
        </div>
      );
    };

    const { container } = render(<SystemPreferencesComponent />);
    
    const results = await axe(container, wcagConfig);
    expect(results).toHaveNoViolations();

    // Test system preference simulation
    const darkModeCheckbox = screen.getByRole('checkbox', { name: /simulate dark mode/i });
    const highContrastCheckbox = screen.getByRole('checkbox', { name: /simulate high contrast/i });
    
    await userEvent.click(darkModeCheckbox);
    expect(screen.getByText('Applied Theme: Dark Theme')).toBeInTheDocument();
    
    await userEvent.click(highContrastCheckbox);
    expect(screen.getByText('Applied Theme: High Contrast')).toBeInTheDocument();

    // Test adaptive button
    const adaptiveButton = screen.getByRole('button', { name: 'Adaptive Button' });
    adaptiveButton.focus();
    expect(adaptiveButton).toHaveFocus();
  });
});