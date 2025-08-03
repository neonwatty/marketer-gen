import React from 'react';
import { render, screen, fireEvent, waitFor } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { axe, toHaveNoViolations } from 'jest-axe';

expect.extend(toHaveNoViolations);

// UX optimization components for motor disability accommodations
describe('UX Optimization Accessibility', () => {
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

  it('should provide accessible drag and drop interface', async () => {
    const DragDropComponent = () => {
      const [items, setItems] = React.useState([
        { id: 1, text: 'Item 1', category: 'todo' },
        { id: 2, text: 'Item 2', category: 'todo' },
        { id: 3, text: 'Item 3', category: 'in-progress' },
        { id: 4, text: 'Item 4', category: 'done' }
      ]);
      const [draggedItem, setDraggedItem] = React.useState<number | null>(null);

      const categories = ['todo', 'in-progress', 'done'];

      const moveItem = (itemId: number, newCategory: string) => {
        setItems(prev => prev.map(item => 
          item.id === itemId ? { ...item, category: newCategory } : item
        ));
      };

      const moveItemKeyboard = (itemId: number, direction: 'up' | 'down' | 'left' | 'right') => {
        const item = items.find(i => i.id === itemId);
        if (!item) return;

        const currentCategoryIndex = categories.indexOf(item.category);
        const itemsInCategory = items.filter(i => i.category === item.category);
        const currentItemIndex = itemsInCategory.findIndex(i => i.id === itemId);

        if (direction === 'left' && currentCategoryIndex > 0) {
          moveItem(itemId, categories[currentCategoryIndex - 1]);
        } else if (direction === 'right' && currentCategoryIndex < categories.length - 1) {
          moveItem(itemId, categories[currentCategoryIndex + 1]);
        } else if (direction === 'up' && currentItemIndex > 0) {
          // Reorder within category (implementation would swap positions)
        } else if (direction === 'down' && currentItemIndex < itemsInCategory.length - 1) {
          // Reorder within category (implementation would swap positions)
        }
      };

      return (
        <div role="region" aria-labelledby="kanban-title">
          <h1 id="kanban-title">Accessible Kanban Board</h1>
          
          <div 
            style={{
              display: 'grid',
              gridTemplateColumns: 'repeat(3, 1fr)',
              gap: '24px',
              padding: '20px'
            }}
          >
            {categories.map((category) => (
              <div
                key={category}
                role="region"
                aria-labelledby={`${category}-title`}
                style={{
                  backgroundColor: '#f8f9fa',
                  borderRadius: '8px',
                  padding: '16px',
                  minHeight: '400px'
                }}
                onDragOver={(e) => e.preventDefault()}
                onDrop={(e) => {
                  e.preventDefault();
                  if (draggedItem) {
                    moveItem(draggedItem, category);
                    setDraggedItem(null);
                  }
                }}
              >
                <h2 
                  id={`${category}-title`}
                  style={{ 
                    textTransform: 'capitalize',
                    marginBottom: '16px',
                    fontSize: '1.125rem'
                  }}
                >
                  {category.replace('-', ' ')} ({items.filter(i => i.category === category).length})
                </h2>
                
                <ul role="list" style={{ listStyle: 'none', padding: 0, margin: 0 }}>
                  {items.filter(item => item.category === category).map((item, index) => (
                    <li key={item.id} style={{ marginBottom: '12px' }}>
                      <div
                        role="button"
                        tabIndex={0}
                        aria-describedby={`item-${item.id}-instructions`}
                        draggable
                        onDragStart={() => setDraggedItem(item.id)}
                        onDragEnd={() => setDraggedItem(null)}
                        onKeyDown={(e) => {
                          switch (e.key) {
                            case 'ArrowLeft':
                              e.preventDefault();
                              moveItemKeyboard(item.id, 'left');
                              break;
                            case 'ArrowRight':
                              e.preventDefault();
                              moveItemKeyboard(item.id, 'right');
                              break;
                            case 'ArrowUp':
                              e.preventDefault();
                              moveItemKeyboard(item.id, 'up');
                              break;
                            case 'ArrowDown':
                              e.preventDefault();
                              moveItemKeyboard(item.id, 'down');
                              break;
                            case 'Enter':
                            case ' ':
                              e.preventDefault();
                              // Open item details or edit mode
                              break;
                          }
                        }}
                        style={{
                          backgroundColor: '#fff',
                          border: '2px solid #ddd',
                          borderRadius: '6px',
                          padding: '12px',
                          cursor: 'grab',
                          transition: 'all 0.2s ease',
                          opacity: draggedItem === item.id ? 0.5 : 1
                        }}
                        onFocus={(e) => {
                          e.target.style.outline = '2px solid #007bff';
                          e.target.style.outlineOffset = '2px';
                        }}
                        onBlur={(e) => {
                          e.target.style.outline = 'none';
                        }}
                      >
                        <div style={{ fontWeight: '500', marginBottom: '8px' }}>
                          {item.text}
                        </div>
                        
                        <div style={{ fontSize: '0.875rem', color: '#666' }}>
                          Position {index + 1} of {items.filter(i => i.category === category).length}
                        </div>
                        
                        <div 
                          id={`item-${item.id}-instructions`}
                          className="sr-only"
                        >
                          Use arrow keys to move between categories and positions. 
                          Left/Right arrows move between columns, Up/Down arrows reorder within column.
                          Press Enter or Space to edit item.
                        </div>
                      </div>
                    </li>
                  ))}
                </ul>
                
                {items.filter(item => item.category === category).length === 0 && (
                  <div 
                    style={{
                      color: '#999',
                      fontStyle: 'italic',
                      textAlign: 'center',
                      padding: '40px 20px'
                    }}
                    role="status"
                  >
                    No items in this category
                  </div>
                )}
              </div>
            ))}
          </div>

          {/* Alternative controls for users who can't use drag and drop */}
          <section style={{ marginTop: '32px', padding: '20px' }}>
            <h2>Alternative Controls</h2>
            <p style={{ marginBottom: '16px', color: '#666' }}>
              Use these controls if drag and drop is not accessible to you:
            </p>
            
            <div style={{ display: 'flex', gap: '16px', flexWrap: 'wrap' }}>
              {items.map((item) => (
                <div key={item.id} style={{ 
                  border: '1px solid #ddd', 
                  borderRadius: '4px', 
                  padding: '12px',
                  backgroundColor: '#f8f9fa'
                }}>
                  <div style={{ fontWeight: '500', marginBottom: '8px' }}>
                    {item.text}
                  </div>
                  <div style={{ marginBottom: '8px', fontSize: '0.875rem' }}>
                    Current: {item.category.replace('-', ' ')}
                  </div>
                  <select
                    value={item.category}
                    onChange={(e) => moveItem(item.id, e.target.value)}
                    aria-label={`Move ${item.text} to different category`}
                    style={{
                      width: '100%',
                      padding: '4px 8px',
                      border: '1px solid #ccc',
                      borderRadius: '4px'
                    }}
                  >
                    {categories.map((cat) => (
                      <option key={cat} value={cat}>
                        {cat.replace('-', ' ')}
                      </option>
                    ))}
                  </select>
                </div>
              ))}
            </div>
          </section>

          {/* Status announcements */}
          <div role="status" aria-live="polite" aria-atomic="true" className="sr-only">
            {draggedItem && `Moving ${items.find(i => i.id === draggedItem)?.text}`}
          </div>
        </div>
      );
    };

    const { container } = render(<DragDropComponent />);
    
    const results = await axe(container, wcagConfig);
    expect(results).toHaveNoViolations();

    // Test keyboard navigation
    const firstItem = screen.getByRole('button', { name: /item 1/i });
    firstItem.focus();
    expect(firstItem).toHaveFocus();

    // Test arrow key movement
    await userEvent.keyboard('{ArrowRight}');
    
    // Should move item to next category
    await waitFor(() => {
      expect(screen.getByText('in progress (2)')).toBeInTheDocument();
    });

    // Test alternative controls
    const selectControl = screen.getByLabelText(/move item 2/i);
    await userEvent.selectOptions(selectControl, 'done');
    
    await waitFor(() => {
      expect(screen.getByText('done (2)')).toBeInTheDocument();
    });
  });

  it('should provide accessible large click targets and hover states', async () => {
    const LargeTargetsComponent = () => {
      const [selectedCard, setSelectedCard] = React.useState<number | null>(null);
      const [hoveredButton, setHoveredButton] = React.useState<number | null>(null);

      return (
        <div role="region" aria-labelledby="targets-title">
          <h1 id="targets-title">Large Click Targets</h1>
          
          {/* Large button targets */}
          <section style={{ marginBottom: '32px' }}>
            <h2>Action Buttons (Minimum 44x44px)</h2>
            <div style={{ display: 'flex', gap: '16px', flexWrap: 'wrap' }}>
              {[
                { id: 1, label: 'Primary Action', color: '#007bff' },
                { id: 2, label: 'Secondary Action', color: '#6c757d' },
                { id: 3, label: 'Success Action', color: '#28a745' },
                { id: 4, label: 'Warning Action', color: '#ffc107' },
                { id: 5, label: 'Danger Action', color: '#dc3545' }
              ].map((button) => (
                <button
                  key={button.id}
                  type="button"
                  style={{
                    minHeight: '44px',
                    minWidth: '44px',
                    padding: '12px 24px',
                    fontSize: '16px',
                    fontWeight: '500',
                    backgroundColor: hoveredButton === button.id ? 
                      `${button.color}dd` : button.color,
                    color: button.id === 4 ? '#000' : '#fff',
                    border: 'none',
                    borderRadius: '6px',
                    cursor: 'pointer',
                    transition: 'all 0.2s ease',
                    transform: hoveredButton === button.id ? 'translateY(-2px)' : 'none',
                    boxShadow: hoveredButton === button.id ? 
                      '0 4px 8px rgba(0,0,0,0.2)' : '0 2px 4px rgba(0,0,0,0.1)'
                  }}
                  onMouseEnter={() => setHoveredButton(button.id)}
                  onMouseLeave={() => setHoveredButton(null)}
                  onFocus={(e) => {
                    setHoveredButton(button.id);
                    e.target.style.outline = '3px solid #007bff';
                    e.target.style.outlineOffset = '2px';
                  }}
                  onBlur={(e) => {
                    setHoveredButton(null);
                    e.target.style.outline = 'none';
                  }}
                  aria-describedby={`button-${button.id}-desc`}
                >
                  {button.label}
                  <div id={`button-${button.id}-desc`} className="sr-only">
                    Large clickable button with enhanced hover and focus states
                  </div>
                </button>
              ))}
            </div>
          </section>

          {/* Card targets */}
          <section style={{ marginBottom: '32px' }}>
            <h2>Interactive Cards</h2>
            <div 
              style={{
                display: 'grid',
                gridTemplateColumns: 'repeat(auto-fit, minmax(300px, 1fr))',
                gap: '20px'
              }}
            >
              {[1, 2, 3, 4].map((cardId) => (
                <div
                  key={cardId}
                  role="button"
                  tabIndex={0}
                  aria-pressed={selectedCard === cardId}
                  onClick={() => setSelectedCard(selectedCard === cardId ? null : cardId)}
                  onKeyDown={(e) => {
                    if (e.key === 'Enter' || e.key === ' ') {
                      e.preventDefault();
                      setSelectedCard(selectedCard === cardId ? null : cardId);
                    }
                  }}
                  style={{
                    backgroundColor: selectedCard === cardId ? '#e3f2fd' : '#fff',
                    border: selectedCard === cardId ? '3px solid #007bff' : '2px solid #ddd',
                    borderRadius: '12px',
                    padding: '24px',
                    cursor: 'pointer',
                    transition: 'all 0.3s ease',
                    boxShadow: selectedCard === cardId ? 
                      '0 8px 16px rgba(0,0,0,0.15)' : '0 2px 8px rgba(0,0,0,0.1)',
                    transform: selectedCard === cardId ? 'scale(1.02)' : 'scale(1)',
                    minHeight: '120px',
                    display: 'flex',
                    flexDirection: 'column',
                    justifyContent: 'center'
                  }}
                  onFocus={(e) => {
                    e.target.style.outline = '3px solid #007bff';
                    e.target.style.outlineOffset = '2px';
                  }}
                  onBlur={(e) => {
                    e.target.style.outline = 'none';
                  }}
                  aria-describedby={`card-${cardId}-desc`}
                >
                  <h3 style={{ 
                    fontSize: '1.25rem', 
                    marginBottom: '12px',
                    color: selectedCard === cardId ? '#007bff' : '#333'
                  }}>
                    Interactive Card {cardId}
                  </h3>
                  <p style={{ 
                    color: '#666', 
                    marginBottom: '16px',
                    lineHeight: '1.5'
                  }}>
                    This card has large click targets and clear visual feedback
                    for better accessibility.
                  </p>
                  <div style={{ 
                    fontSize: '0.875rem',
                    color: selectedCard === cardId ? '#007bff' : '#999'
                  }}>
                    {selectedCard === cardId ? 'Selected' : 'Click to select'}
                  </div>
                  
                  <div id={`card-${cardId}-desc`} className="sr-only">
                    Large interactive card with enhanced visual feedback. 
                    Press Enter or Space to toggle selection.
                  </div>
                </div>
              ))}
            </div>
          </section>

          {/* Form controls with large targets */}
          <section style={{ marginBottom: '32px' }}>
            <h2>Form Controls</h2>
            <form style={{ maxWidth: '600px' }}>
              <div style={{ marginBottom: '24px' }}>
                <fieldset>
                  <legend style={{ 
                    fontSize: '1.125rem', 
                    fontWeight: '500',
                    marginBottom: '16px'
                  }}>
                    Large Radio Buttons
                  </legend>
                  <div role="radiogroup">
                    {['Option 1', 'Option 2', 'Option 3'].map((option, index) => (
                      <label
                        key={option}
                        style={{
                          display: 'flex',
                          alignItems: 'center',
                          padding: '12px',
                          marginBottom: '8px',
                          cursor: 'pointer',
                          borderRadius: '6px',
                          transition: 'background-color 0.2s ease'
                        }}
                        onMouseEnter={(e) => {
                          e.currentTarget.style.backgroundColor = '#f8f9fa';
                        }}
                        onMouseLeave={(e) => {
                          e.currentTarget.style.backgroundColor = 'transparent';
                        }}
                      >
                        <input
                          type="radio"
                          name="large-radio"
                          value={option}
                          style={{
                            width: '20px',
                            height: '20px',
                            marginRight: '12px',
                            cursor: 'pointer'
                          }}
                        />
                        <span style={{ fontSize: '16px' }}>{option}</span>
                      </label>
                    ))}
                  </div>
                </fieldset>
              </div>

              <div style={{ marginBottom: '24px' }}>
                <h3 style={{ marginBottom: '16px' }}>Large Checkboxes</h3>
                {['Feature A', 'Feature B', 'Feature C'].map((feature) => (
                  <label
                    key={feature}
                    style={{
                      display: 'flex',
                      alignItems: 'center',
                      padding: '12px',
                      marginBottom: '8px',
                      cursor: 'pointer',
                      borderRadius: '6px',
                      transition: 'background-color 0.2s ease'
                    }}
                    onMouseEnter={(e) => {
                      e.currentTarget.style.backgroundColor = '#f8f9fa';
                    }}
                    onMouseLeave={(e) => {
                      e.currentTarget.style.backgroundColor = 'transparent';
                    }}
                  >
                    <input
                      type="checkbox"
                      style={{
                        width: '20px',
                        height: '20px',
                        marginRight: '12px',
                        cursor: 'pointer'
                      }}
                    />
                    <span style={{ fontSize: '16px' }}>{feature}</span>
                  </label>
                ))}
              </div>

              <div style={{ marginBottom: '24px' }}>
                <label 
                  htmlFor="large-select"
                  style={{ 
                    display: 'block', 
                    marginBottom: '8px',
                    fontSize: '16px',
                    fontWeight: '500'
                  }}
                >
                  Large Select Dropdown
                </label>
                <select
                  id="large-select"
                  style={{
                    width: '100%',
                    minHeight: '44px',
                    padding: '12px',
                    fontSize: '16px',
                    border: '2px solid #ccc',
                    borderRadius: '6px',
                    backgroundColor: '#fff',
                    cursor: 'pointer'
                  }}
                  onFocus={(e) => {
                    e.target.style.borderColor = '#007bff';
                    e.target.style.outline = '2px solid #007bff';
                    e.target.style.outlineOffset = '2px';
                  }}
                  onBlur={(e) => {
                    e.target.style.borderColor = '#ccc';
                    e.target.style.outline = 'none';
                  }}
                >
                  <option value="">Choose an option</option>
                  <option value="1">Option 1</option>
                  <option value="2">Option 2</option>
                  <option value="3">Option 3</option>
                </select>
              </div>

              <button
                type="submit"
                style={{
                  minHeight: '48px',
                  padding: '14px 32px',
                  fontSize: '18px',
                  fontWeight: '500',
                  backgroundColor: '#007bff',
                  color: '#fff',
                  border: 'none',
                  borderRadius: '8px',
                  cursor: 'pointer',
                  transition: 'all 0.2s ease'
                }}
                onFocus={(e) => {
                  e.target.style.outline = '3px solid #007bff';
                  e.target.style.outlineOffset = '2px';
                  e.target.style.transform = 'translateY(-2px)';
                  e.target.style.boxShadow = '0 4px 12px rgba(0,123,255,0.3)';
                }}
                onBlur={(e) => {
                  e.target.style.outline = 'none';
                  e.target.style.transform = 'none';
                  e.target.style.boxShadow = 'none';
                }}
                onMouseEnter={(e) => {
                  e.target.style.backgroundColor = '#0056b3';
                  e.target.style.transform = 'translateY(-2px)';
                  e.target.style.boxShadow = '0 4px 12px rgba(0,123,255,0.3)';
                }}
                onMouseLeave={(e) => {
                  e.target.style.backgroundColor = '#007bff';
                  e.target.style.transform = 'none';
                  e.target.style.boxShadow = 'none';
                }}
              >
                Submit Form
              </button>
            </form>
          </section>

          {/* Status feedback */}
          <div role="status" aria-live="polite" aria-atomic="true">
            {selectedCard && `Card ${selectedCard} is selected`}
          </div>
        </div>
      );
    };

    const { container } = render(<LargeTargetsComponent />);
    
    const results = await axe(container, wcagConfig);
    expect(results).toHaveNoViolations();

    // Test large button targets
    const primaryButton = screen.getByRole('button', { name: 'Primary Action' });
    const computedStyle = window.getComputedStyle(primaryButton);
    expect(parseInt(computedStyle.minHeight)).toBeGreaterThanOrEqual(44);
    expect(parseInt(computedStyle.minWidth)).toBeGreaterThanOrEqual(44);

    // Test card interaction
    const firstCard = screen.getByRole('button', { name: /interactive card 1/i });
    await userEvent.click(firstCard);
    expect(firstCard).toHaveAttribute('aria-pressed', 'true');

    // Test form controls
    const radioButton = screen.getByRole('radio', { name: 'Option 1' });
    const checkbox = screen.getByRole('checkbox', { name: 'Feature A' });
    
    await userEvent.click(radioButton);
    expect(radioButton).toBeChecked();
    
    await userEvent.click(checkbox);
    expect(checkbox).toBeChecked();
  });

  it('should provide accessible timeout and session management', async () => {
    const TimeoutManagement = () => {
      const [timeRemaining, setTimeRemaining] = React.useState(300); // 5 minutes
      const [showWarning, setShowWarning] = React.useState(false);
      const [isExtending, setIsExtending] = React.useState(false);
      const [sessionExtended, setSessionExtended] = React.useState(false);

      React.useEffect(() => {
        const interval = setInterval(() => {
          setTimeRemaining(prev => {
            if (prev <= 60 && !showWarning) {
              setShowWarning(true);
            }
            return Math.max(0, prev - 1);
          });
        }, 1000);

        return () => clearInterval(interval);
      }, [showWarning]);

      const extendSession = async () => {
        setIsExtending(true);
        // Simulate API call
        setTimeout(() => {
          setTimeRemaining(300);
          setShowWarning(false);
          setIsExtending(false);
          setSessionExtended(true);
          setTimeout(() => setSessionExtended(false), 3000);
        }, 1000);
      };

      const formatTime = (seconds: number) => {
        const mins = Math.floor(seconds / 60);
        const secs = seconds % 60;
        return `${mins}:${secs.toString().padStart(2, '0')}`;
      };

      return (
        <div role="region" aria-labelledby="session-title">
          <h1 id="session-title">Session Management</h1>
          
          {/* Session timer */}
          <div 
            role="timer"
            aria-live="polite"
            aria-atomic="true"
            style={{
              padding: '16px',
              backgroundColor: timeRemaining <= 60 ? '#fff3cd' : '#f8f9fa',
              border: timeRemaining <= 60 ? '2px solid #ffc107' : '1px solid #ddd',
              borderRadius: '8px',
              marginBottom: '24px'
            }}
          >
            <div style={{ 
              fontSize: '1.25rem', 
              fontWeight: 'bold',
              marginBottom: '8px',
              color: timeRemaining <= 60 ? '#856404' : '#333'
            }}>
              Session Time Remaining: {formatTime(timeRemaining)}
            </div>
            <div style={{ 
              fontSize: '0.875rem',
              color: timeRemaining <= 60 ? '#856404' : '#666'
            }}>
              Your session will expire automatically for security.
            </div>
          </div>

          {/* Warning dialog */}
          {showWarning && (
            <div
              role="alertdialog"
              aria-labelledby="warning-title"
              aria-describedby="warning-desc"
              aria-modal="true"
              style={{
                position: 'fixed',
                top: '50%',
                left: '50%',
                transform: 'translate(-50%, -50%)',
                backgroundColor: '#fff',
                border: '3px solid #ffc107',
                borderRadius: '12px',
                padding: '32px',
                boxShadow: '0 8px 32px rgba(0,0,0,0.3)',
                maxWidth: '500px',
                zIndex: 1000
              }}
            >
              <h2 id="warning-title" style={{ 
                color: '#856404',
                marginBottom: '16px',
                fontSize: '1.5rem'
              }}>
                Session Expiring Soon
              </h2>
              
              <div id="warning-desc" style={{ marginBottom: '24px' }}>
                <p style={{ marginBottom: '12px' }}>
                  Your session will expire in {formatTime(timeRemaining)} due to inactivity.
                </p>
                <p>
                  Would you like to extend your session? Any unsaved work will be lost if your session expires.
                </p>
              </div>

              <div style={{ display: 'flex', gap: '12px', justifyContent: 'flex-end' }}>
                <button
                  type="button"
                  onClick={() => setShowWarning(false)}
                  style={{
                    padding: '12px 24px',
                    border: '2px solid #6c757d',
                    backgroundColor: 'transparent',
                    color: '#6c757d',
                    borderRadius: '6px',
                    fontSize: '16px',
                    cursor: 'pointer'
                  }}
                  onFocus={(e) => {
                    e.target.style.outline = '2px solid #007bff';
                    e.target.style.outlineOffset = '2px';
                  }}
                  onBlur={(e) => {
                    e.target.style.outline = 'none';
                  }}
                >
                  Continue Without Extending
                </button>
                
                <button
                  type="button"
                  onClick={extendSession}
                  disabled={isExtending}
                  style={{
                    padding: '12px 24px',
                    backgroundColor: '#ffc107',
                    color: '#000',
                    border: 'none',
                    borderRadius: '6px',
                    fontSize: '16px',
                    fontWeight: '500',
                    cursor: isExtending ? 'not-allowed' : 'pointer',
                    opacity: isExtending ? 0.7 : 1
                  }}
                  onFocus={(e) => {
                    e.target.style.outline = '2px solid #007bff';
                    e.target.style.outlineOffset = '2px';
                  }}
                  onBlur={(e) => {
                    e.target.style.outline = 'none';
                  }}
                >
                  {isExtending ? 'Extending...' : 'Extend Session'}
                </button>
              </div>
            </div>
          )}

          {/* Backdrop */}
          {showWarning && (
            <div
              style={{
                position: 'fixed',
                top: 0,
                left: 0,
                right: 0,
                bottom: 0,
                backgroundColor: 'rgba(0,0,0,0.5)',
                zIndex: 999
              }}
              onClick={() => setShowWarning(false)}
            />
          )}

          {/* Success message */}
          {sessionExtended && (
            <div
              role="alert"
              aria-atomic="true"
              style={{
                backgroundColor: '#d4edda',
                color: '#155724',
                border: '1px solid #c3e6cb',
                borderRadius: '6px',
                padding: '16px',
                marginBottom: '24px'
              }}
            >
              <strong>Session Extended:</strong> Your session has been extended for another 5 minutes.
            </div>
          )}

          {/* Main content */}
          <section>
            <h2>Your Work Area</h2>
            <div style={{
              backgroundColor: '#f8f9fa',
              border: '1px solid #ddd',
              borderRadius: '8px',
              padding: '24px',
              minHeight: '300px'
            }}>
              <p style={{ marginBottom: '16px' }}>
                This represents your work area. Any changes you make here need to be saved 
                before your session expires.
              </p>
              
              <form>
                <div style={{ marginBottom: '16px' }}>
                  <label 
                    htmlFor="work-input"
                    style={{ display: 'block', marginBottom: '8px' }}
                  >
                    Work Content
                  </label>
                  <textarea
                    id="work-input"
                    rows={6}
                    style={{
                      width: '100%',
                      padding: '12px',
                      border: '2px solid #ccc',
                      borderRadius: '6px',
                      fontSize: '16px'
                    }}
                    placeholder="Enter your work here..."
                    onFocus={(e) => {
                      e.target.style.borderColor = '#007bff';
                      e.target.style.outline = '2px solid #007bff';
                      e.target.style.outlineOffset = '2px';
                    }}
                    onBlur={(e) => {
                      e.target.style.borderColor = '#ccc';
                      e.target.style.outline = 'none';
                    }}
                  />
                </div>
                
                <div style={{ display: 'flex', gap: '12px' }}>
                  <button
                    type="button"
                    style={{
                      padding: '12px 24px',
                      backgroundColor: '#28a745',
                      color: '#fff',
                      border: 'none',
                      borderRadius: '6px',
                      fontSize: '16px',
                      cursor: 'pointer'
                    }}
                    onFocus={(e) => {
                      e.target.style.outline = '2px solid #007bff';
                      e.target.style.outlineOffset = '2px';
                    }}
                    onBlur={(e) => {
                      e.target.style.outline = 'none';
                    }}
                  >
                    Save Work
                  </button>
                  
                  <button
                    type="button"
                    onClick={extendSession}
                    disabled={isExtending}
                    style={{
                      padding: '12px 24px',
                      backgroundColor: '#007bff',
                      color: '#fff',
                      border: 'none',
                      borderRadius: '6px',
                      fontSize: '16px',
                      cursor: isExtending ? 'not-allowed' : 'pointer',
                      opacity: isExtending ? 0.7 : 1
                    }}
                    onFocus={(e) => {
                      e.target.style.outline = '2px solid #007bff';
                      e.target.style.outlineOffset = '2px';
                    }}
                    onBlur={(e) => {
                      e.target.style.outline = 'none';
                    }}
                  >
                    {isExtending ? 'Extending...' : 'Extend Session'}
                  </button>
                </div>
              </form>
            </div>
          </section>

          {/* Accessibility settings */}
          <section style={{ marginTop: '32px' }}>
            <h2>Session Accessibility Settings</h2>
            <div style={{
              backgroundColor: '#f8f9fa',
              border: '1px solid #ddd',
              borderRadius: '8px',
              padding: '20px'
            }}>
              <div style={{ marginBottom: '16px' }}>
                <label style={{ display: 'flex', alignItems: 'center' }}>
                  <input
                    type="checkbox"
                    style={{ marginRight: '12px' }}
                  />
                  <div>
                    <div style={{ fontWeight: '500' }}>Extended Session Timeouts</div>
                    <div style={{ fontSize: '0.875rem', color: '#666' }}>
                      Automatically extend sessions for users who need more time
                    </div>
                  </div>
                </label>
              </div>
              
              <div style={{ marginBottom: '16px' }}>
                <label style={{ display: 'flex', alignItems: 'center' }}>
                  <input
                    type="checkbox"
                    style={{ marginRight: '12px' }}
                  />
                  <div>
                    <div style={{ fontWeight: '500' }}>Audio Timeout Warnings</div>
                    <div style={{ fontSize: '0.875rem', color: '#666' }}>
                      Play audio alerts for session expiration warnings
                    </div>
                  </div>
                </label>
              </div>
              
              <div>
                <label style={{ display: 'flex', alignItems: 'center' }}>
                  <input
                    type="checkbox"
                    style={{ marginRight: '12px' }}
                  />
                  <div>
                    <div style={{ fontWeight: '500' }}>Auto-Save Work</div>
                    <div style={{ fontSize: '0.875rem', color: '#666' }}>
                      Automatically save work every few minutes
                    </div>
                  </div>
                </label>
              </div>
            </div>
          </section>
        </div>
      );
    };

    const { container } = render(<TimeoutManagement />);
    
    const results = await axe(container, wcagConfig);
    expect(results).toHaveNoViolations();

    // Test session timer
    const timer = screen.getByRole('timer');
    expect(timer).toBeInTheDocument();
    expect(timer).toHaveAttribute('aria-live', 'polite');

    // Test work area
    const workInput = screen.getByLabelText('Work Content');
    const saveButton = screen.getByRole('button', { name: 'Save Work' });
    const extendButton = screen.getByRole('button', { name: 'Extend Session' });

    await userEvent.type(workInput, 'Test content');
    expect(workInput).toHaveValue('Test content');

    await userEvent.click(extendButton);
    expect(extendButton).toBeDisabled();

    // Wait for extension to complete
    await waitFor(() => {
      expect(extendButton).not.toBeDisabled();
    }, { timeout: 2000 });
  });
});