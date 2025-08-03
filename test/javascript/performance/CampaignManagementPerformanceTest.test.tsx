/**
 * Campaign Management Interface Performance Test Suite
 * Tests campaign creation, editing, and management performance
 */

import React from 'react';
import { render, screen, fireEvent, waitFor } from '@testing-library/react';
import userEvent from '@testing-library/user-event';

// Mock Campaign Management components
const MockCampaignForm = ({ 
  initialData = {},
  onSave,
  onCancel,
  mode = 'create' // 'create' | 'edit'
}: {
  initialData?: any;
  onSave?: (data: any) => void;
  onCancel?: () => void;
  mode?: 'create' | 'edit';
}) => {
  const [formData, setFormData] = React.useState({
    name: '',
    description: '',
    target_audience: '',
    budget: '',
    start_date: '',
    end_date: '',
    channels: [],
    objectives: [],
    ...initialData
  });
  const [validationErrors, setValidationErrors] = React.useState<Record<string, string>>({});
  const [isValidating, setIsValidating] = React.useState(false);
  const [isSaving, setIsSaving] = React.useState(false);

  // Real-time validation
  React.useEffect(() => {
    const validateField = (field: string, value: any) => {
      const errors: Record<string, string> = {};
      
      switch (field) {
        case 'name':
          if (!value || value.length < 3) {
            errors.name = 'Name must be at least 3 characters';
          }
          break;
        case 'budget':
          if (value && (isNaN(value) || parseFloat(value) <= 0)) {
            errors.budget = 'Budget must be a positive number';
          }
          break;
        case 'start_date':
          if (value && new Date(value) < new Date()) {
            errors.start_date = 'Start date cannot be in the past';
          }
          break;
      }
      
      setValidationErrors(prev => ({ ...prev, ...errors }));
    };

    Object.entries(formData).forEach(([key, value]) => {
      validateField(key, value);
    });
  }, [formData]);

  const handleInputChange = (field: string, value: any) => {
    setFormData(prev => ({ ...prev, [field]: value }));
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    
    setIsValidating(true);
    await new Promise(resolve => setTimeout(resolve, 50)); // Simulate validation delay
    setIsValidating(false);
    
    if (Object.keys(validationErrors).length > 0) {
      return;
    }
    
    setIsSaving(true);
    await new Promise(resolve => setTimeout(resolve, 200)); // Simulate API call
    setIsSaving(false);
    
    onSave?.(formData);
  };

  return (
    <div className="campaign-form" data-testid="campaign-form">
      <h2>{mode === 'create' ? 'Create Campaign' : 'Edit Campaign'}</h2>
      
      <form onSubmit={handleSubmit}>
        {/* Basic Information */}
        <div className="form-section">
          <h3>Basic Information</h3>
          
          <div className="form-field">
            <label htmlFor="campaign-name">Campaign Name</label>
            <input
              id="campaign-name"
              data-testid="campaign-name"
              type="text"
              value={formData.name}
              onChange={(e) => handleInputChange('name', e.target.value)}
              className={validationErrors.name ? 'error' : ''}
            />
            {validationErrors.name && (
              <span className="error-message" data-testid="name-error">
                {validationErrors.name}
              </span>
            )}
          </div>

          <div className="form-field">
            <label htmlFor="campaign-description">Description</label>
            <textarea
              id="campaign-description"
              data-testid="campaign-description"
              value={formData.description}
              onChange={(e) => handleInputChange('description', e.target.value)}
              rows={4}
            />
          </div>

          <div className="form-field">
            <label htmlFor="target-audience">Target Audience</label>
            <select
              id="target-audience"
              data-testid="target-audience"
              value={formData.target_audience}
              onChange={(e) => handleInputChange('target_audience', e.target.value)}
            >
              <option value="">Select audience</option>
              <option value="millennials">Millennials</option>
              <option value="gen-z">Gen Z</option>
              <option value="gen-x">Gen X</option>
              <option value="boomers">Baby Boomers</option>
            </select>
          </div>
        </div>

        {/* Budget and Dates */}
        <div className="form-section">
          <h3>Budget & Timeline</h3>
          
          <div className="form-field">
            <label htmlFor="budget">Budget ($)</label>
            <input
              id="budget"
              data-testid="budget"
              type="number"
              value={formData.budget}
              onChange={(e) => handleInputChange('budget', e.target.value)}
              className={validationErrors.budget ? 'error' : ''}
            />
            {validationErrors.budget && (
              <span className="error-message" data-testid="budget-error">
                {validationErrors.budget}
              </span>
            )}
          </div>

          <div className="form-field">
            <label htmlFor="start-date">Start Date</label>
            <input
              id="start-date"
              data-testid="start-date"
              type="date"
              value={formData.start_date}
              onChange={(e) => handleInputChange('start_date', e.target.value)}
              className={validationErrors.start_date ? 'error' : ''}
            />
            {validationErrors.start_date && (
              <span className="error-message" data-testid="start-date-error">
                {validationErrors.start_date}
              </span>
            )}
          </div>

          <div className="form-field">
            <label htmlFor="end-date">End Date</label>
            <input
              id="end-date"
              data-testid="end-date"
              type="date"
              value={formData.end_date}
              onChange={(e) => handleInputChange('end_date', e.target.value)}
            />
          </div>
        </div>

        {/* Channels */}
        <div className="form-section">
          <h3>Marketing Channels</h3>
          <div className="checkbox-group" data-testid="channels-group">
            {['email', 'social_media', 'paid_ads', 'content_marketing', 'seo'].map(channel => (
              <label key={channel} className="checkbox-item">
                <input
                  type="checkbox"
                  checked={formData.channels.includes(channel)}
                  onChange={(e) => {
                    if (e.target.checked) {
                      handleInputChange('channels', [...formData.channels, channel]);
                    } else {
                      handleInputChange('channels', formData.channels.filter((c: string) => c !== channel));
                    }
                  }}
                />
                {channel.replace('_', ' ').toUpperCase()}
              </label>
            ))}
          </div>
        </div>

        {/* Form Actions */}
        <div className="form-actions">
          <button
            type="button"
            onClick={onCancel}
            disabled={isSaving}
            className="cancel-button"
            data-testid="cancel-button"
          >
            Cancel
          </button>
          <button
            type="submit"
            disabled={isSaving || isValidating || Object.keys(validationErrors).length > 0}
            className="save-button"
            data-testid="save-button"
          >
            {isSaving ? 'Saving...' : 'Save Campaign'}
          </button>
        </div>
      </form>
    </div>
  );
};

const MockCampaignList = ({ 
  campaigns = [],
  onEdit,
  onDelete,
  onBulkAction,
  pageSize = 20
}: {
  campaigns?: any[];
  onEdit?: (campaign: any) => void;
  onDelete?: (campaignId: string) => void;
  onBulkAction?: (action: string, campaignIds: string[]) => void;
  pageSize?: number;
}) => {
  const [selectedCampaigns, setSelectedCampaigns] = React.useState<string[]>([]);
  const [sortField, setSortField] = React.useState('name');
  const [sortDirection, setSortDirection] = React.useState<'asc' | 'desc'>('asc');
  const [filterStatus, setFilterStatus] = React.useState('all');
  const [currentPage, setCurrentPage] = React.useState(1);
  const [searchTerm, setSearchTerm] = React.useState('');

  // Filter and sort campaigns
  const filteredCampaigns = React.useMemo(() => {
    let filtered = campaigns;
    
    // Apply search filter
    if (searchTerm) {
      filtered = filtered.filter(campaign => 
        campaign.name.toLowerCase().includes(searchTerm.toLowerCase()) ||
        campaign.description.toLowerCase().includes(searchTerm.toLowerCase())
      );
    }
    
    // Apply status filter
    if (filterStatus !== 'all') {
      filtered = filtered.filter(campaign => campaign.status === filterStatus);
    }
    
    // Apply sorting
    filtered.sort((a, b) => {
      const aValue = a[sortField];
      const bValue = b[sortField];
      const comparison = aValue < bValue ? -1 : aValue > bValue ? 1 : 0;
      return sortDirection === 'asc' ? comparison : -comparison;
    });
    
    return filtered;
  }, [campaigns, searchTerm, filterStatus, sortField, sortDirection]);

  // Paginate campaigns
  const paginatedCampaigns = React.useMemo(() => {
    const startIndex = (currentPage - 1) * pageSize;
    return filteredCampaigns.slice(startIndex, startIndex + pageSize);
  }, [filteredCampaigns, currentPage, pageSize]);

  const totalPages = Math.ceil(filteredCampaigns.length / pageSize);

  const handleSort = (field: string) => {
    if (sortField === field) {
      setSortDirection(sortDirection === 'asc' ? 'desc' : 'asc');
    } else {
      setSortField(field);
      setSortDirection('asc');
    }
  };

  const handleSelectAll = (checked: boolean) => {
    if (checked) {
      setSelectedCampaigns(paginatedCampaigns.map(c => c.id));
    } else {
      setSelectedCampaigns([]);
    }
  };

  const handleSelectCampaign = (campaignId: string, checked: boolean) => {
    if (checked) {
      setSelectedCampaigns(prev => [...prev, campaignId]);
    } else {
      setSelectedCampaigns(prev => prev.filter(id => id !== campaignId));
    }
  };

  return (
    <div className="campaign-list" data-testid="campaign-list">
      {/* Search and Filters */}
      <div className="list-controls">
        <input
          type="text"
          placeholder="Search campaigns..."
          value={searchTerm}
          onChange={(e) => setSearchTerm(e.target.value)}
          data-testid="search-input"
          className="search-input"
        />
        
        <select
          value={filterStatus}
          onChange={(e) => setFilterStatus(e.target.value)}
          data-testid="status-filter"
          className="status-filter"
        >
          <option value="all">All Status</option>
          <option value="draft">Draft</option>
          <option value="active">Active</option>
          <option value="paused">Paused</option>
          <option value="completed">Completed</option>
        </select>
      </div>

      {/* Bulk Actions */}
      {selectedCampaigns.length > 0 && (
        <div className="bulk-actions" data-testid="bulk-actions">
          <span>{selectedCampaigns.length} selected</span>
          <button onClick={() => onBulkAction?.('delete', selectedCampaigns)}>
            Delete Selected
          </button>
          <button onClick={() => onBulkAction?.('archive', selectedCampaigns)}>
            Archive Selected
          </button>
        </div>
      )}

      {/* Campaign Table */}
      <div className="campaign-table-container">
        <table className="campaign-table" data-testid="campaign-table">
          <thead>
            <tr>
              <th>
                <input
                  type="checkbox"
                  checked={selectedCampaigns.length === paginatedCampaigns.length && paginatedCampaigns.length > 0}
                  onChange={(e) => handleSelectAll(e.target.checked)}
                />
              </th>
              <th onClick={() => handleSort('name')} className="sortable">
                Name {sortField === 'name' && (sortDirection === 'asc' ? '↑' : '↓')}
              </th>
              <th onClick={() => handleSort('status')} className="sortable">
                Status {sortField === 'status' && (sortDirection === 'asc' ? '↑' : '↓')}
              </th>
              <th onClick={() => handleSort('budget')} className="sortable">
                Budget {sortField === 'budget' && (sortDirection === 'asc' ? '↑' : '↓')}
              </th>
              <th onClick={() => handleSort('start_date')} className="sortable">
                Start Date {sortField === 'start_date' && (sortDirection === 'asc' ? '↑' : '↓')}
              </th>
              <th>Actions</th>
            </tr>
          </thead>
          <tbody>
            {paginatedCampaigns.map(campaign => (
              <tr key={campaign.id} data-testid={`campaign-row-${campaign.id}`}>
                <td>
                  <input
                    type="checkbox"
                    checked={selectedCampaigns.includes(campaign.id)}
                    onChange={(e) => handleSelectCampaign(campaign.id, e.target.checked)}
                  />
                </td>
                <td>{campaign.name}</td>
                <td>
                  <span className={`status-badge status-${campaign.status}`}>
                    {campaign.status}
                  </span>
                </td>
                <td>${campaign.budget?.toLocaleString() || 'N/A'}</td>
                <td>{campaign.start_date || 'N/A'}</td>
                <td>
                  <button onClick={() => onEdit?.(campaign)} className="edit-btn">
                    Edit
                  </button>
                  <button onClick={() => onDelete?.(campaign.id)} className="delete-btn">
                    Delete
                  </button>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>

      {/* Pagination */}
      {totalPages > 1 && (
        <div className="pagination" data-testid="pagination">
          <button
            disabled={currentPage === 1}
            onClick={() => setCurrentPage(currentPage - 1)}
            data-testid="prev-page"
          >
            Previous
          </button>
          <span>Page {currentPage} of {totalPages}</span>
          <button
            disabled={currentPage === totalPages}
            onClick={() => setCurrentPage(currentPage + 1)}
            data-testid="next-page"
          >
            Next
          </button>
        </div>
      )}
    </div>
  );
};

// Performance measurement utilities
const measureRenderTime = async (renderFunction: () => void): Promise<number> => {
  const start = performance.now();
  renderFunction();
  await new Promise(resolve => setTimeout(resolve, 0));
  const end = performance.now();
  return end - start;
};

const measureInteractionTime = async (interaction: () => Promise<void>): Promise<number> => {
  const start = performance.now();
  await interaction();
  const end = performance.now();
  return end - start;
};

const measureMemoryUsage = (): number => {
  if ('memory' in performance) {
    return (performance as any).memory.usedJSHeapSize;
  }
  return 0;
};

describe('Campaign Management Performance Tests', () => {
  const PERFORMANCE_THRESHOLDS = {
    FORM_RENDER: 100,           // 100ms for form rendering
    LIST_RENDER: 200,           // 200ms for campaign list
    LARGE_LIST_RENDER: 500,     // 500ms for large lists
    FORM_VALIDATION: 50,        // 50ms for validation
    SEARCH_RESPONSE: 100,       // 100ms for search
    SORT_RESPONSE: 100,         // 100ms for sorting
    PAGINATION_RESPONSE: 50,    // 50ms for pagination
    BULK_ACTION: 200,           // 200ms for bulk actions
    FORM_SAVE: 300,            // 300ms for form save
    MEMORY_LEAK_THRESHOLD: 10 * 1024 * 1024, // 10MB
    TABLE_ROW_RENDER: 5,       // 5ms per table row
    FILTER_RESPONSE: 100       // 100ms for filtering
  };

  // Generate mock campaign data
  const generateCampaigns = (count: number) => {
    return Array.from({ length: count }, (_, i) => ({
      id: `campaign-${i}`,
      name: `Campaign ${i + 1}`,
      description: `Description for campaign ${i + 1}`,
      status: ['draft', 'active', 'paused', 'completed'][i % 4],
      budget: Math.floor(Math.random() * 100000) + 5000,
      start_date: new Date(Date.now() + (i - count/2) * 24 * 60 * 60 * 1000).toISOString().split('T')[0],
      target_audience: ['millennials', 'gen-z', 'gen-x', 'boomers'][i % 4],
      channels: ['email', 'social_media', 'paid_ads'].slice(0, (i % 3) + 1)
    }));
  };

  describe('Campaign Form Performance', () => {
    it('should render create form within performance threshold', async () => {
      const renderTime = await measureRenderTime(() => {
        render(<MockCampaignForm mode="create" />);
      });

      expect(renderTime).toBeLessThan(PERFORMANCE_THRESHOLDS.FORM_RENDER);
    });

    it('should render edit form with data efficiently', async () => {
      const campaignData = {
        name: 'Existing Campaign',
        description: 'Campaign description',
        target_audience: 'millennials',
        budget: 50000,
        start_date: '2024-01-01',
        end_date: '2024-12-31',
        channels: ['email', 'social_media']
      };

      const renderTime = await measureRenderTime(() => {
        render(<MockCampaignForm mode="edit" initialData={campaignData} />);
      });

      expect(renderTime).toBeLessThan(PERFORMANCE_THRESHOLDS.FORM_RENDER);
    });

    it('should handle form validation efficiently', async () => {
      render(<MockCampaignForm />);
      
      const nameInput = screen.getByTestId('campaign-name');
      
      const validationTime = await measureInteractionTime(async () => {
        await userEvent.type(nameInput, 'ab'); // Too short, should trigger validation
        await new Promise(resolve => setTimeout(resolve, 10));
      });

      expect(validationTime).toBeLessThan(PERFORMANCE_THRESHOLDS.FORM_VALIDATION);
      
      // Should show validation error
      await waitFor(() => {
        expect(screen.getByTestId('name-error')).toBeInTheDocument();
      });
    });

    it('should handle rapid input changes without performance degradation', async () => {
      render(<MockCampaignForm />);
      
      const nameInput = screen.getByTestId('campaign-name');
      const descriptionInput = screen.getByTestId('campaign-description');
      
      const rapidInputTime = await measureInteractionTime(async () => {
        await userEvent.type(nameInput, 'Campaign Name');
        await userEvent.type(descriptionInput, 'Campaign description with some longer text content');
        
        const budgetInput = screen.getByTestId('budget');
        await userEvent.type(budgetInput, '50000');
        
        const audienceSelect = screen.getByTestId('target-audience');
        await userEvent.selectOptions(audienceSelect, 'millennials');
      });

      expect(rapidInputTime).toBeLessThan(PERFORMANCE_THRESHOLDS.FORM_VALIDATION * 4);
    });

    it('should save form efficiently', async () => {
      const mockSave = jest.fn();
      render(<MockCampaignForm onSave={mockSave} />);
      
      // Fill out form
      await userEvent.type(screen.getByTestId('campaign-name'), 'Test Campaign');
      await userEvent.type(screen.getByTestId('campaign-description'), 'Test description');
      await userEvent.type(screen.getByTestId('budget'), '25000');
      
      const saveButton = screen.getByTestId('save-button');
      
      const saveTime = await measureInteractionTime(async () => {
        await userEvent.click(saveButton);
        await waitFor(() => {
          expect(mockSave).toHaveBeenCalled();
        });
      });

      expect(saveTime).toBeLessThan(PERFORMANCE_THRESHOLDS.FORM_SAVE);
    });
  });

  describe('Campaign List Performance', () => {
    it('should render empty list efficiently', async () => {
      const renderTime = await measureRenderTime(() => {
        render(<MockCampaignList campaigns={[]} />);
      });

      expect(renderTime).toBeLessThan(PERFORMANCE_THRESHOLDS.LIST_RENDER);
    });

    it('should render small campaign list efficiently', async () => {
      const campaigns = generateCampaigns(20);
      
      const renderTime = await measureRenderTime(() => {
        render(<MockCampaignList campaigns={campaigns} />);
      });

      expect(renderTime).toBeLessThan(PERFORMANCE_THRESHOLDS.LIST_RENDER);
    });

    it('should handle large campaign lists with pagination', async () => {
      const campaigns = generateCampaigns(1000);
      
      const renderTime = await measureRenderTime(() => {
        render(<MockCampaignList campaigns={campaigns} pageSize={50} />);
      });

      expect(renderTime).toBeLessThan(PERFORMANCE_THRESHOLDS.LARGE_LIST_RENDER);
      
      // Should only render first page
      const rows = screen.getAllByTestId(/campaign-row-/);
      expect(rows.length).toBe(50);
    });

    it('should handle search efficiently', async () => {
      const campaigns = generateCampaigns(100);
      render(<MockCampaignList campaigns={campaigns} />);
      
      const searchInput = screen.getByTestId('search-input');
      
      const searchTime = await measureInteractionTime(async () => {
        await userEvent.type(searchInput, 'Campaign 1');
      });

      expect(searchTime).toBeLessThan(PERFORMANCE_THRESHOLDS.SEARCH_RESPONSE);
      
      // Should filter results
      await waitFor(() => {
        const rows = screen.getAllByTestId(/campaign-row-/);
        expect(rows.length).toBeLessThan(campaigns.length);
      });
    });

    it('should handle sorting efficiently', async () => {
      const campaigns = generateCampaigns(100);
      render(<MockCampaignList campaigns={campaigns} />);
      
      // Click on name column to sort
      const nameHeader = screen.getByText(/Name/);
      
      const sortTime = await measureInteractionTime(async () => {
        fireEvent.click(nameHeader);
        await new Promise(resolve => setTimeout(resolve, 10));
      });

      expect(sortTime).toBeLessThan(PERFORMANCE_THRESHOLDS.SORT_RESPONSE);
    });

    it('should handle pagination efficiently', async () => {
      const campaigns = generateCampaigns(100);
      render(<MockCampaignList campaigns={campaigns} pageSize={20} />);
      
      const nextButton = screen.getByTestId('next-page');
      
      const paginationTime = await measureInteractionTime(async () => {
        fireEvent.click(nextButton);
        await new Promise(resolve => setTimeout(resolve, 10));
      });

      expect(paginationTime).toBeLessThan(PERFORMANCE_THRESHOLDS.PAGINATION_RESPONSE);
    });

    it('should handle filtering efficiently', async () => {
      const campaigns = generateCampaigns(200);
      render(<MockCampaignList campaigns={campaigns} />);
      
      const statusFilter = screen.getByTestId('status-filter');
      
      const filterTime = await measureInteractionTime(async () => {
        await userEvent.selectOptions(statusFilter, 'active');
      });

      expect(filterTime).toBeLessThan(PERFORMANCE_THRESHOLDS.FILTER_RESPONSE);
    });
  });

  describe('Bulk Operations Performance', () => {
    it('should handle bulk selection efficiently', async () => {
      const campaigns = generateCampaigns(50);
      render(<MockCampaignList campaigns={campaigns} />);
      
      // Select all campaigns
      const selectAllCheckbox = screen.getByRole('checkbox');
      
      const selectionTime = await measureInteractionTime(async () => {
        fireEvent.click(selectAllCheckbox);
        await new Promise(resolve => setTimeout(resolve, 10));
      });

      expect(selectionTime).toBeLessThan(PERFORMANCE_THRESHOLDS.BULK_ACTION);
      
      // Should show bulk actions
      await waitFor(() => {
        expect(screen.getByTestId('bulk-actions')).toBeInTheDocument();
      });
    });

    it('should handle individual selection efficiently', async () => {
      const campaigns = generateCampaigns(20);
      render(<MockCampaignList campaigns={campaigns} />);
      
      const checkboxes = screen.getAllByRole('checkbox').slice(1); // Skip select-all
      
      const selectionTime = await measureInteractionTime(async () => {
        // Select first 5 campaigns
        for (let i = 0; i < 5; i++) {
          fireEvent.click(checkboxes[i]);
        }
        await new Promise(resolve => setTimeout(resolve, 10));
      });

      expect(selectionTime).toBeLessThan(PERFORMANCE_THRESHOLDS.BULK_ACTION);
    });

    it('should process bulk actions efficiently', async () => {
      const mockBulkAction = jest.fn();
      const campaigns = generateCampaigns(30);
      render(<MockCampaignList campaigns={campaigns} onBulkAction={mockBulkAction} />);
      
      // Select some campaigns
      const selectAllCheckbox = screen.getByRole('checkbox');
      fireEvent.click(selectAllCheckbox);
      
      await waitFor(() => {
        expect(screen.getByTestId('bulk-actions')).toBeInTheDocument();
      });
      
      const deleteButton = screen.getByText('Delete Selected');
      
      const bulkActionTime = await measureInteractionTime(async () => {
        fireEvent.click(deleteButton);
        await new Promise(resolve => setTimeout(resolve, 10));
      });

      expect(bulkActionTime).toBeLessThan(PERFORMANCE_THRESHOLDS.BULK_ACTION);
      expect(mockBulkAction).toHaveBeenCalled();
    });
  });

  describe('Memory Management', () => {
    it('should not leak memory with form interactions', async () => {
      const initialMemory = measureMemoryUsage();
      
      const { unmount } = render(<MockCampaignForm />);
      
      // Simulate form interactions
      const nameInput = screen.getByTestId('campaign-name');
      for (let i = 0; i < 50; i++) {
        await userEvent.clear(nameInput);
        await userEvent.type(nameInput, `Campaign ${i}`);
      }
      
      unmount();
      
      if (global.gc) {
        global.gc();
      }
      
      const finalMemory = measureMemoryUsage();
      const memoryDiff = finalMemory - initialMemory;
      
      expect(memoryDiff).toBeLessThan(PERFORMANCE_THRESHOLDS.MEMORY_LEAK_THRESHOLD);
    });

    it('should handle large lists without excessive memory usage', async () => {
      const initialMemory = measureMemoryUsage();
      
      const campaigns = generateCampaigns(500);
      const { unmount } = render(<MockCampaignList campaigns={campaigns} />);
      
      // Simulate interactions
      const searchInput = screen.getByTestId('search-input');
      await userEvent.type(searchInput, 'test');
      await userEvent.clear(searchInput);
      
      unmount();
      
      if (global.gc) {
        global.gc();
      }
      
      const finalMemory = measureMemoryUsage();
      const memoryDiff = finalMemory - initialMemory;
      
      expect(memoryDiff).toBeLessThan(PERFORMANCE_THRESHOLDS.MEMORY_LEAK_THRESHOLD * 2);
    });
  });

  describe('Real-time Updates Performance', () => {
    it('should handle campaign status updates efficiently', async () => {
      const campaigns = generateCampaigns(20);
      const { rerender } = render(<MockCampaignList campaigns={campaigns} />);
      
      // Update campaign status
      const updatedCampaigns = campaigns.map(c => ({
        ...c,
        status: c.id === 'campaign-0' ? 'active' : c.status
      }));
      
      const updateTime = await measureInteractionTime(async () => {
        rerender(<MockCampaignList campaigns={updatedCampaigns} />);
        await new Promise(resolve => setTimeout(resolve, 10));
      });

      expect(updateTime).toBeLessThan(PERFORMANCE_THRESHOLDS.LIST_RENDER);
    });

    it('should handle incremental campaign additions efficiently', async () => {
      const initialCampaigns = generateCampaigns(20);
      const { rerender } = render(<MockCampaignList campaigns={initialCampaigns} />);
      
      // Add 5 new campaigns
      const newCampaigns = [...initialCampaigns, ...generateCampaigns(5)];
      
      const addTime = await measureInteractionTime(async () => {
        rerender(<MockCampaignList campaigns={newCampaigns} />);
        await new Promise(resolve => setTimeout(resolve, 10));
      });

      expect(addTime).toBeLessThan(PERFORMANCE_THRESHOLDS.LIST_RENDER);
    });
  });

  describe('Responsive Performance', () => {
    it('should adapt to mobile view efficiently', async () => {
      Object.defineProperty(window, 'innerWidth', { value: 390 });
      
      const campaigns = generateCampaigns(20);
      const renderTime = await measureRenderTime(() => {
        render(<MockCampaignList campaigns={campaigns} />);
      });

      expect(renderTime).toBeLessThan(PERFORMANCE_THRESHOLDS.LIST_RENDER * 1.5);
    });

    it('should handle viewport changes efficiently', async () => {
      const campaigns = generateCampaigns(20);
      const { rerender } = render(<MockCampaignList campaigns={campaigns} />);
      
      const resizeTime = await measureInteractionTime(async () => {
        Object.defineProperty(window, 'innerWidth', { value: 768 });
        fireEvent(window, new Event('resize'));
        rerender(<MockCampaignList campaigns={campaigns} />);
      });

      expect(resizeTime).toBeLessThan(100);
    });
  });
});