import React from 'react';
import { render, screen, fireEvent, waitFor } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { axe, toHaveNoViolations } from 'jest-axe';

expect.extend(toHaveNoViolations);

// Mock campaign management components that don't exist yet - will fail initially (TDD)
const CampaignTable = ({ 
  campaigns, 
  onSort, 
  onFilter, 
  onBulkAction,
  selectable = false,
  ...props 
}: any) => {
  throw new Error('CampaignTable component not implemented yet');
};

const CampaignForm = ({ 
  campaign, 
  onSubmit, 
  onCancel,
  isEditing = false,
  steps = [],
  ...props 
}: any) => {
  throw new Error('CampaignForm component not implemented yet');
};

const CampaignFilters = ({ 
  filters, 
  onFilterChange,
  savedFilters = [],
  ...props 
}: any) => {
  throw new Error('CampaignFilters component not implemented yet');
};

const BulkActions = ({ 
  selectedItems, 
  onAction,
  availableActions = [],
  ...props 
}: any) => {
  throw new Error('BulkActions component not implemented yet');
};

const StatusIndicator = ({ 
  status, 
  showLabel = true,
  interactive = false,
  ...props 
}: any) => {
  throw new Error('StatusIndicator component not implemented yet');
};

const WorkflowVisualizer = ({ 
  workflow, 
  currentStep,
  onStepClick,
  ...props 
}: any) => {
  throw new Error('WorkflowVisualizer component not implemented yet');
};

describe('Campaign Management Interface', () => {
  const mockCampaigns = [
    {
      id: '1',
      name: 'Q4 Product Launch',
      status: 'active',
      type: 'product_launch',
      budget: 50000,
      startDate: '2024-10-01',
      endDate: '2024-12-31',
      owner: 'John Doe',
      tags: ['high-priority', 'product'],
      performance: { clicks: 1250, conversions: 85, ctr: 2.5 }
    },
    {
      id: '2',
      name: 'Holiday Campaign',
      status: 'draft',
      type: 'seasonal',
      budget: 25000,
      startDate: '2024-11-15',
      endDate: '2024-12-25',
      owner: 'Jane Smith',
      tags: ['seasonal', 'promotion'],
      performance: { clicks: 0, conversions: 0, ctr: 0 }
    },
    {
      id: '3',
      name: 'Brand Awareness',
      status: 'paused',
      type: 'brand',
      budget: 75000,
      startDate: '2024-09-01',
      endDate: '2024-11-30',
      owner: 'Mike Johnson',
      tags: ['brand', 'awareness'],
      performance: { clicks: 3500, conversions: 120, ctr: 1.8 }
    }
  ];

  describe('Campaign Table', () => {
    it('should render campaign list', () => {
      render(
        <CampaignTable campaigns={mockCampaigns} />
      );
      
      mockCampaigns.forEach(campaign => {
        expect(screen.getByText(campaign.name)).toBeInTheDocument();
        expect(screen.getByText(campaign.owner)).toBeInTheDocument();
      });
    });

    it('should display campaign status indicators', () => {
      render(
        <CampaignTable campaigns={mockCampaigns} />
      );
      
      expect(screen.getByText('active')).toBeInTheDocument();
      expect(screen.getByText('draft')).toBeInTheDocument();
      expect(screen.getByText('paused')).toBeInTheDocument();
    });

    it('should support column sorting', async () => {
      const mockOnSort = jest.fn();
      
      render(
        <CampaignTable 
          campaigns={mockCampaigns}
          onSort={mockOnSort}
        />
      );
      
      const nameHeader = screen.getByRole('columnheader', { name: /name/i });
      await userEvent.click(nameHeader);
      
      expect(mockOnSort).toHaveBeenCalledWith('name', 'asc');
      
      // Click again for descending sort
      await userEvent.click(nameHeader);
      expect(mockOnSort).toHaveBeenCalledWith('name', 'desc');
    });

    it('should support custom column configuration', () => {
      const customColumns = [
        { key: 'name', label: 'Campaign Name', sortable: true },
        { key: 'budget', label: 'Budget', sortable: true, format: 'currency' },
        { key: 'performance.ctr', label: 'CTR', sortable: true, format: 'percentage' }
      ];
      
      render(
        <CampaignTable 
          campaigns={mockCampaigns}
          columns={customColumns}
        />
      );
      
      expect(screen.getByText('Campaign Name')).toBeInTheDocument();
      expect(screen.getByText('Budget')).toBeInTheDocument();
      expect(screen.getByText('CTR')).toBeInTheDocument();
      
      // Check formatted values
      expect(screen.getByText('$50,000')).toBeInTheDocument();
      expect(screen.getByText('2.5%')).toBeInTheDocument();
    });

    it('should support row selection', async () => {
      render(
        <CampaignTable 
          campaigns={mockCampaigns}
          selectable={true}
        />
      );
      
      const checkboxes = screen.getAllByRole('checkbox');
      expect(checkboxes).toHaveLength(4); // 3 campaigns + select all
      
      // Select individual campaign
      await userEvent.click(checkboxes[1]);
      expect(checkboxes[1]).toBeChecked();
      
      // Select all
      await userEvent.click(checkboxes[0]);
      checkboxes.slice(1).forEach(checkbox => {
        expect(checkbox).toBeChecked();
      });
    });

    it('should support inline editing', async () => {
      const mockOnUpdate = jest.fn();
      
      render(
        <CampaignTable 
          campaigns={mockCampaigns}
          inlineEditing={true}
          onUpdate={mockOnUpdate}
        />
      );
      
      const campaignRow = screen.getByText('Q4 Product Launch').closest('tr');
      const editButton = campaignRow?.querySelector('[aria-label="Edit campaign"]');
      
      await userEvent.click(editButton!);
      
      const nameInput = screen.getByDisplayValue('Q4 Product Launch');
      await userEvent.clear(nameInput);
      await userEvent.type(nameInput, 'Updated Campaign Name');
      
      const saveButton = screen.getByRole('button', { name: /save/i });
      await userEvent.click(saveButton);
      
      expect(mockOnUpdate).toHaveBeenCalledWith('1', {
        name: 'Updated Campaign Name'
      });
    });

    it('should handle pagination', () => {
      const manyCampaigns = Array.from({ length: 50 }, (_, i) => ({
        ...mockCampaigns[0],
        id: `campaign-${i}`,
        name: `Campaign ${i + 1}`
      }));
      
      render(
        <CampaignTable 
          campaigns={manyCampaigns}
          pagination={{ pageSize: 10, currentPage: 1 }}
        />
      );
      
      // Should only show 10 campaigns
      expect(screen.getAllByRole('row')).toHaveLength(11); // 10 data rows + header
      
      // Pagination controls
      expect(screen.getByRole('button', { name: /next page/i })).toBeInTheDocument();
      expect(screen.getByText('1 of 5')).toBeInTheDocument();
    });

    it('should export table data', async () => {
      const mockOnExport = jest.fn();
      
      render(
        <CampaignTable 
          campaigns={mockCampaigns}
          exportable={true}
          onExport={mockOnExport}
        />
      );
      
      const exportButton = screen.getByRole('button', { name: /export/i });
      await userEvent.click(exportButton);
      
      // Export format selection
      expect(screen.getByText('CSV')).toBeInTheDocument();
      expect(screen.getByText('Excel')).toBeInTheDocument();
      expect(screen.getByText('PDF')).toBeInTheDocument();
      
      await userEvent.click(screen.getByText('CSV'));
      expect(mockOnExport).toHaveBeenCalledWith('csv', mockCampaigns);
    });
  });

  describe('Campaign Filters', () => {
    const mockFilters = {
      status: ['active', 'draft', 'paused', 'completed'],
      type: ['product_launch', 'seasonal', 'brand', 'promotional'],
      owner: ['John Doe', 'Jane Smith', 'Mike Johnson'],
      dateRange: { start: null, end: null },
      budget: { min: 0, max: 100000 }
    };

    it('should render filter controls', () => {
      render(
        <CampaignFilters 
          filters={mockFilters}
          onFilterChange={jest.fn()}
        />
      );
      
      expect(screen.getByLabelText(/status/i)).toBeInTheDocument();
      expect(screen.getByLabelText(/type/i)).toBeInTheDocument();
      expect(screen.getByLabelText(/owner/i)).toBeInTheDocument();
      expect(screen.getByLabelText(/date range/i)).toBeInTheDocument();
      expect(screen.getByLabelText(/budget/i)).toBeInTheDocument();
    });

    it('should handle filter changes', async () => {
      const mockOnFilterChange = jest.fn();
      
      render(
        <CampaignFilters 
          filters={mockFilters}
          onFilterChange={mockOnFilterChange}
        />
      );
      
      const statusFilter = screen.getByLabelText(/status/i);
      await userEvent.selectOptions(statusFilter, ['active', 'draft']);
      
      expect(mockOnFilterChange).toHaveBeenCalledWith({
        ...mockFilters,
        status: ['active', 'draft']
      });
    });

    it('should support date range filtering', async () => {
      const mockOnFilterChange = jest.fn();
      
      render(
        <CampaignFilters 
          filters={mockFilters}
          onFilterChange={mockOnFilterChange}
        />
      );
      
      const startDateInput = screen.getByLabelText(/start date/i);
      const endDateInput = screen.getByLabelText(/end date/i);
      
      await userEvent.type(startDateInput, '2024-10-01');
      await userEvent.type(endDateInput, '2024-12-31');
      
      expect(mockOnFilterChange).toHaveBeenCalledWith({
        ...mockFilters,
        dateRange: { start: '2024-10-01', end: '2024-12-31' }
      });
    });

    it('should support budget range filtering', async () => {
      const mockOnFilterChange = jest.fn();
      
      render(
        <CampaignFilters 
          filters={mockFilters}
          onFilterChange={mockOnFilterChange}
        />
      );
      
      const minBudgetInput = screen.getByLabelText(/minimum budget/i);
      const maxBudgetInput = screen.getByLabelText(/maximum budget/i);
      
      await userEvent.clear(minBudgetInput);
      await userEvent.type(minBudgetInput, '10000');
      await userEvent.clear(maxBudgetInput);
      await userEvent.type(maxBudgetInput, '75000');
      
      expect(mockOnFilterChange).toHaveBeenCalledWith({
        ...mockFilters,
        budget: { min: 10000, max: 75000 }
      });
    });

    it('should save and load filter presets', async () => {
      const savedFilters = [
        { id: '1', name: 'Active Campaigns', filters: { status: ['active'] } },
        { id: '2', name: 'High Budget', filters: { budget: { min: 50000, max: 100000 } } }
      ];
      
      render(
        <CampaignFilters 
          filters={mockFilters}
          onFilterChange={jest.fn()}
          savedFilters={savedFilters}
        />
      );
      
      const presetSelect = screen.getByLabelText(/saved filters/i);
      await userEvent.selectOptions(presetSelect, '1');
      
      expect(screen.getByDisplayValue('active')).toBeInTheDocument();
    });

    it('should clear all filters', async () => {
      const mockOnFilterChange = jest.fn();
      
      render(
        <CampaignFilters 
          filters={{ ...mockFilters, status: ['active'] }}
          onFilterChange={mockOnFilterChange}
        />
      );
      
      const clearButton = screen.getByRole('button', { name: /clear filters/i });
      await userEvent.click(clearButton);
      
      expect(mockOnFilterChange).toHaveBeenCalledWith({
        status: [],
        type: [],
        owner: [],
        dateRange: { start: null, end: null },
        budget: { min: 0, max: 100000 }
      });
    });
  });

  describe('Campaign Form', () => {
    const mockCampaign = {
      name: '',
      description: '',
      type: '',
      budget: 0,
      startDate: '',
      endDate: '',
      targetAudience: '',
      goals: [],
      channels: []
    };

    it('should render multi-step form', () => {
      const steps = [
        { id: 'basic', title: 'Basic Information', fields: ['name', 'description', 'type'] },
        { id: 'budget', title: 'Budget & Timeline', fields: ['budget', 'startDate', 'endDate'] },
        { id: 'targeting', title: 'Targeting', fields: ['targetAudience', 'goals'] },
        { id: 'channels', title: 'Channels', fields: ['channels'] },
        { id: 'review', title: 'Review', fields: [] }
      ];
      
      render(
        <CampaignForm 
          campaign={mockCampaign}
          onSubmit={jest.fn()}
          steps={steps}
        />
      );
      
      steps.forEach(step => {
        expect(screen.getByText(step.title)).toBeInTheDocument();
      });
      
      expect(screen.getByText('Step 1 of 5')).toBeInTheDocument();
    });

    it('should validate form fields', async () => {
      render(
        <CampaignForm 
          campaign={mockCampaign}
          onSubmit={jest.fn()}
        />
      );
      
      const submitButton = screen.getByRole('button', { name: /save campaign/i });
      await userEvent.click(submitButton);
      
      expect(screen.getByText(/campaign name is required/i)).toBeInTheDocument();
      expect(screen.getByText(/campaign type is required/i)).toBeInTheDocument();
      expect(screen.getByText(/budget must be greater than 0/i)).toBeInTheDocument();
    });

    it('should support step navigation', async () => {
      const steps = [
        { id: 'basic', title: 'Basic Information' },
        { id: 'budget', title: 'Budget & Timeline' }
      ];
      
      render(
        <CampaignForm 
          campaign={mockCampaign}
          onSubmit={jest.fn()}
          steps={steps}
        />
      );
      
      // Fill required field
      await userEvent.type(screen.getByLabelText(/campaign name/i), 'Test Campaign');
      
      const nextButton = screen.getByRole('button', { name: /next/i });
      await userEvent.click(nextButton);
      
      expect(screen.getByText('Step 2 of 2')).toBeInTheDocument();
      expect(screen.getByLabelText(/budget/i)).toBeInTheDocument();
      
      // Go back
      const prevButton = screen.getByRole('button', { name: /previous/i });
      await userEvent.click(prevButton);
      
      expect(screen.getByText('Step 1 of 2')).toBeInTheDocument();
    });

    it('should auto-save progress', async () => {
      const mockOnAutoSave = jest.fn();
      
      render(
        <CampaignForm 
          campaign={mockCampaign}
          onSubmit={jest.fn()}
          autoSave={true}
          onAutoSave={mockOnAutoSave}
        />
      );
      
      const nameInput = screen.getByLabelText(/campaign name/i);
      await userEvent.type(nameInput, 'Auto-saved Campaign');
      
      await waitFor(() => {
        expect(mockOnAutoSave).toHaveBeenCalledWith({
          ...mockCampaign,
          name: 'Auto-saved Campaign'
        });
      }, { timeout: 1500 });
    });

    it('should handle form submission', async () => {
      const mockOnSubmit = jest.fn();
      
      render(
        <CampaignForm 
          campaign={mockCampaign}
          onSubmit={mockOnSubmit}
        />
      );
      
      // Fill required fields
      await userEvent.type(screen.getByLabelText(/campaign name/i), 'Test Campaign');
      await userEvent.selectOptions(screen.getByLabelText(/campaign type/i), 'product_launch');
      await userEvent.type(screen.getByLabelText(/budget/i), '25000');
      await userEvent.type(screen.getByLabelText(/start date/i), '2024-10-01');
      await userEvent.type(screen.getByLabelText(/end date/i), '2024-12-31');
      
      const submitButton = screen.getByRole('button', { name: /save campaign/i });
      await userEvent.click(submitButton);
      
      expect(mockOnSubmit).toHaveBeenCalledWith({
        ...mockCampaign,
        name: 'Test Campaign',
        type: 'product_launch',
        budget: 25000,
        startDate: '2024-10-01',
        endDate: '2024-12-31'
      });
    });

    it('should support conditional form sections', async () => {
      render(
        <CampaignForm 
          campaign={mockCampaign}
          onSubmit={jest.fn()}
          conditionalSections={true}
        />
      );
      
      const typeSelect = screen.getByLabelText(/campaign type/i);
      await userEvent.selectOptions(typeSelect, 'seasonal');
      
      // Seasonal-specific fields should appear
      expect(screen.getByLabelText(/holiday/i)).toBeInTheDocument();
      expect(screen.getByLabelText(/seasonal theme/i)).toBeInTheDocument();
    });
  });

  describe('Bulk Actions', () => {
    const selectedCampaigns = ['1', '2'];
    const availableActions = [
      { id: 'activate', label: 'Activate', icon: 'play' },
      { id: 'pause', label: 'Pause', icon: 'pause' },
      { id: 'duplicate', label: 'Duplicate', icon: 'copy' },
      { id: 'delete', label: 'Delete', icon: 'trash', destructive: true }
    ];

    it('should render available actions', () => {
      render(
        <BulkActions 
          selectedItems={selectedCampaigns}
          onAction={jest.fn()}
          availableActions={availableActions}
        />
      );
      
      availableActions.forEach(action => {
        expect(screen.getByText(action.label)).toBeInTheDocument();
      });
    });

    it('should show selection count', () => {
      render(
        <BulkActions 
          selectedItems={selectedCampaigns}
          onAction={jest.fn()}
          availableActions={availableActions}
        />
      );
      
      expect(screen.getByText('2 campaigns selected')).toBeInTheDocument();
    });

    it('should handle bulk actions', async () => {
      const mockOnAction = jest.fn();
      
      render(
        <BulkActions 
          selectedItems={selectedCampaigns}
          onAction={mockOnAction}
          availableActions={availableActions}
        />
      );
      
      await userEvent.click(screen.getByText('Activate'));
      
      expect(mockOnAction).toHaveBeenCalledWith('activate', selectedCampaigns);
    });

    it('should show confirmation for destructive actions', async () => {
      const mockOnAction = jest.fn();
      
      render(
        <BulkActions 
          selectedItems={selectedCampaigns}
          onAction={mockOnAction}
          availableActions={availableActions}
        />
      );
      
      await userEvent.click(screen.getByText('Delete'));
      
      expect(screen.getByText(/are you sure you want to delete 2 campaigns/i))
        .toBeInTheDocument();
      
      const confirmButton = screen.getByRole('button', { name: /confirm delete/i });
      await userEvent.click(confirmButton);
      
      expect(mockOnAction).toHaveBeenCalledWith('delete', selectedCampaigns);
    });

    it('should disable actions when no items selected', () => {
      render(
        <BulkActions 
          selectedItems={[]}
          onAction={jest.fn()}
          availableActions={availableActions}
        />
      );
      
      availableActions.forEach(action => {
        expect(screen.getByText(action.label)).toBeDisabled();
      });
    });
  });

  describe('Status Management', () => {
    it('should display status indicators', () => {
      const statuses = ['active', 'draft', 'paused', 'completed', 'archived'];
      
      statuses.forEach(status => {
        render(
          <StatusIndicator 
            status={status}
            data-testid={`status-${status}`}
          />
        );
        
        const indicator = screen.getByTestId(`status-${status}`);
        expect(indicator).toHaveClass(`status-${status}`);
      });
    });

    it('should support interactive status changes', async () => {
      const mockOnStatusChange = jest.fn();
      
      render(
        <StatusIndicator 
          status="draft"
          interactive={true}
          onStatusChange={mockOnStatusChange}
        />
      );
      
      await userEvent.click(screen.getByRole('button', { name: /change status/i }));
      
      expect(screen.getByText('Active')).toBeInTheDocument();
      expect(screen.getByText('Paused')).toBeInTheDocument();
      
      await userEvent.click(screen.getByText('Active'));
      expect(mockOnStatusChange).toHaveBeenCalledWith('active');
    });

    it('should show status history', () => {
      const statusHistory = [
        { status: 'draft', timestamp: '2024-10-01T10:00:00Z', user: 'John Doe' },
        { status: 'active', timestamp: '2024-10-02T09:00:00Z', user: 'Jane Smith' },
        { status: 'paused', timestamp: '2024-10-15T14:30:00Z', user: 'Mike Johnson' }
      ];
      
      render(
        <StatusIndicator 
          status="paused"
          showHistory={true}
          statusHistory={statusHistory}
        />
      );
      
      statusHistory.forEach(entry => {
        expect(screen.getByText(entry.status)).toBeInTheDocument();
        expect(screen.getByText(entry.user)).toBeInTheDocument();
      });
    });
  });

  describe('Workflow Visualization', () => {
    const mockWorkflow = {
      steps: [
        { id: 'draft', name: 'Draft', status: 'completed' },
        { id: 'review', name: 'Review', status: 'current' },
        { id: 'approve', name: 'Approval', status: 'pending' },
        { id: 'launch', name: 'Launch', status: 'pending' }
      ]
    };

    it('should render workflow steps', () => {
      render(
        <WorkflowVisualizer 
          workflow={mockWorkflow}
          currentStep="review"
        />
      );
      
      mockWorkflow.steps.forEach(step => {
        expect(screen.getByText(step.name)).toBeInTheDocument();
      });
    });

    it('should highlight current step', () => {
      render(
        <WorkflowVisualizer 
          workflow={mockWorkflow}
          currentStep="review"
        />
      );
      
      const currentStep = screen.getByText('Review').closest('[data-testid="workflow-step"]');
      expect(currentStep).toHaveClass('step-current');
    });

    it('should handle step navigation', async () => {
      const mockOnStepClick = jest.fn();
      
      render(
        <WorkflowVisualizer 
          workflow={mockWorkflow}
          currentStep="review"
          onStepClick={mockOnStepClick}
        />
      );
      
      await userEvent.click(screen.getByText('Draft'));
      expect(mockOnStepClick).toHaveBeenCalledWith('draft');
    });

    it('should show step progress', () => {
      render(
        <WorkflowVisualizer 
          workflow={mockWorkflow}
          currentStep="review"
          showProgress={true}
        />
      );
      
      expect(screen.getByText('Step 2 of 4')).toBeInTheDocument();
      expect(screen.getByRole('progressbar')).toHaveAttribute('aria-valuenow', '50');
    });
  });

  describe('Performance Tests', () => {
    it('should render campaign table within 100ms', async () => {
      const renderTime = await global.testUtils.measureRenderTime(() => {
        render(<CampaignTable campaigns={mockCampaigns} />);
      });
      
      expect(renderTime).toBeLessThan(100);
    });

    it('should handle large datasets efficiently', async () => {
      const largeCampaignList = Array.from({ length: 1000 }, (_, i) => ({
        ...mockCampaigns[0],
        id: `campaign-${i}`,
        name: `Campaign ${i + 1}`
      }));
      
      const renderTime = await global.testUtils.measureRenderTime(() => {
        render(
          <CampaignTable 
            campaigns={largeCampaignList}
            virtualized={true}
          />
        );
      });
      
      expect(renderTime).toBeLessThan(100);
    });

    it('should optimize form rendering', async () => {
      const renderTime = await global.testUtils.measureRenderTime(() => {
        render(
          <CampaignForm 
            campaign={mockCampaigns[0]}
            onSubmit={jest.fn()}
          />
        );
      });
      
      expect(renderTime).toBeLessThan(100);
    });
  });

  describe('Accessibility', () => {
    it('should have no accessibility violations in table', async () => {
      const { container } = render(
        <CampaignTable campaigns={mockCampaigns} />
      );
      
      const results = await axe(container, global.axeConfig);
      expect(results).toHaveNoViolations();
    });

    it('should have no accessibility violations in form', async () => {
      const { container } = render(
        <CampaignForm 
          campaign={mockCampaigns[0]}
          onSubmit={jest.fn()}
        />
      );
      
      const results = await axe(container, global.axeConfig);
      expect(results).toHaveNoViolations();
    });

    it('should support keyboard navigation in table', async () => {
      render(
        <CampaignTable 
          campaigns={mockCampaigns}
          selectable={true}
        />
      );
      
      // Tab through table elements
      await userEvent.tab(); // Header checkbox
      await userEvent.tab(); // First row checkbox
      
      expect(screen.getAllByRole('checkbox')[1]).toHaveFocus();
      
      // Space to select
      await userEvent.keyboard(' ');
      expect(screen.getAllByRole('checkbox')[1]).toBeChecked();
    });

    it('should announce bulk action results', async () => {
      render(
        <BulkActions 
          selectedItems={['1', '2']}
          onAction={jest.fn()}
          availableActions={[{ id: 'activate', label: 'Activate' }]}
        />
      );
      
      await userEvent.click(screen.getByText('Activate'));
      
      expect(screen.getByText('2 campaigns activated'))
        .toHaveAttribute('aria-live', 'polite');
    });
  });

  describe('Responsive Design', () => {
    const breakpoints = [320, 768, 1024, 1440, 2560];

    breakpoints.forEach(width => {
      it(`should adapt table layout at ${width}px`, () => {
        global.testUtils.mockViewport(width, 800);
        
        render(
          <CampaignTable 
            campaigns={mockCampaigns}
            responsive={true}
            data-testid={`table-${width}`}
          />
        );
        
        const table = screen.getByTestId(`table-${width}`);
        
        if (width < 768) {
          expect(table).toHaveClass('table-mobile');
        } else if (width < 1024) {
          expect(table).toHaveClass('table-tablet');
        } else {
          expect(table).toHaveClass('table-desktop');
        }
      });
    });

    it('should stack form fields on mobile', () => {
      global.testUtils.mockViewport(320, 568);
      
      render(
        <CampaignForm 
          campaign={mockCampaigns[0]}
          onSubmit={jest.fn()}
          responsive={true}
          data-testid="mobile-form"
        />
      );
      
      expect(screen.getByTestId('mobile-form')).toHaveClass('form-mobile');
    });
  });

  describe('Error Handling', () => {
    it('should handle form validation errors', async () => {
      const mockOnSubmit = jest.fn().mockRejectedValue({
        errors: {
          name: 'Campaign name already exists',
          budget: 'Budget must be positive'
        }
      });
      
      render(
        <CampaignForm 
          campaign={mockCampaigns[0]}
          onSubmit={mockOnSubmit}
        />
      );
      
      const submitButton = screen.getByRole('button', { name: /save campaign/i });
      await userEvent.click(submitButton);
      
      await waitFor(() => {
        expect(screen.getByText('Campaign name already exists')).toBeInTheDocument();
        expect(screen.getByText('Budget must be positive')).toBeInTheDocument();
      });
    });

    it('should handle bulk action failures', async () => {
      const mockOnAction = jest.fn().mockRejectedValue(
        new Error('Failed to activate campaigns')
      );
      
      render(
        <BulkActions 
          selectedItems={['1', '2']}
          onAction={mockOnAction}
          availableActions={[{ id: 'activate', label: 'Activate' }]}
        />
      );
      
      await userEvent.click(screen.getByText('Activate'));
      
      await waitFor(() => {
        expect(screen.getByText(/failed to activate campaigns/i))
          .toBeInTheDocument();
      });
    });
  });
});

// Export components for integration tests
export { 
  CampaignTable, 
  CampaignForm, 
  CampaignFilters, 
  BulkActions, 
  StatusIndicator, 
  WorkflowVisualizer 
};