import React from 'react';
import { render, screen, fireEvent, waitFor } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { axe, toHaveNoViolations } from 'jest-axe';

expect.extend(toHaveNoViolations);

// Campaign management interface accessibility testing
describe('Campaign Management Accessibility', () => {
  const wcagConfig = {
    rules: {
      'color-contrast': { enabled: true },
      'aria-allowed-attr': { enabled: true },
      'aria-required-attr': { enabled: true },
      'aria-roles': { enabled: true },
      'aria-valid-attr': { enabled: true },
      'aria-valid-attr-value': { enabled: true },
      'button-name': { enabled: true },
      'form-field-multiple-labels': { enabled: true },
      'label': { enabled: true },
      'table-duplicate-name': { enabled: true },
      'td-headers-attr': { enabled: true },
      'th-has-data-cells': { enabled: true },
      'tabindex': { enabled: true }
    },
    tags: ['wcag2a', 'wcag2aa', 'wcag21aa']
  };

  it('should provide accessible campaign creation form', async () => {
    const CampaignForm = () => {
      const [formData, setFormData] = React.useState({
        name: '',
        objective: '',
        budget: '',
        startDate: '',
        endDate: '',
        targetAudience: '',
        channels: [] as string[]
      });
      const [errors, setErrors] = React.useState<Record<string, string>>({});
      const [step, setStep] = React.useState(1);
      const totalSteps = 3;

      const validateCurrentStep = () => {
        const newErrors: Record<string, string> = {};
        
        if (step === 1) {
          if (!formData.name.trim()) newErrors.name = 'Campaign name is required';
          if (!formData.objective) newErrors.objective = 'Campaign objective is required';
        } else if (step === 2) {
          if (!formData.budget) newErrors.budget = 'Budget is required';
          if (!formData.startDate) newErrors.startDate = 'Start date is required';
          if (!formData.endDate) newErrors.endDate = 'End date is required';
        } else if (step === 3) {
          if (!formData.targetAudience) newErrors.targetAudience = 'Target audience is required';
          if (formData.channels.length === 0) newErrors.channels = 'At least one channel must be selected';
        }
        
        setErrors(newErrors);
        return Object.keys(newErrors).length === 0;
      };

      const handleNext = () => {
        if (validateCurrentStep() && step < totalSteps) {
          setStep(step + 1);
        }
      };

      const handlePrevious = () => {
        if (step > 1) {
          setStep(step - 1);
        }
      };

      const handleChannelChange = (channel: string, checked: boolean) => {
        if (checked) {
          setFormData(prev => ({
            ...prev,
            channels: [...prev.channels, channel]
          }));
        } else {
          setFormData(prev => ({
            ...prev,
            channels: prev.channels.filter(c => c !== channel)
          }));
        }
      };

      return (
        <div role="region" aria-labelledby="campaign-form-title">
          <h1 id="campaign-form-title">Create New Campaign</h1>
          
          {/* Progress indicator */}
          <nav aria-label="Campaign creation progress">
            <ol role="list" className="progress-steps">
              {[1, 2, 3].map((stepNumber) => (
                <li 
                  key={stepNumber}
                  aria-current={step === stepNumber ? 'step' : undefined}
                  className={step === stepNumber ? 'current' : step > stepNumber ? 'completed' : 'pending'}
                >
                  <span aria-label={`Step ${stepNumber} ${
                    step === stepNumber ? '(current)' : 
                    step > stepNumber ? '(completed)' : '(pending)'
                  }`}>
                    {stepNumber}
                  </span>
                  <span>
                    {stepNumber === 1 ? 'Basic Information' :
                     stepNumber === 2 ? 'Budget & Schedule' : 'Targeting & Channels'}
                  </span>
                </li>
              ))}
            </ol>
          </nav>

          <form noValidate>
            {/* Step 1: Basic Information */}
            {step === 1 && (
              <fieldset>
                <legend>Basic Information</legend>
                
                <div>
                  <label htmlFor="campaign-name">
                    Campaign Name <span aria-label="required">*</span>
                  </label>
                  <input
                    type="text"
                    id="campaign-name"
                    value={formData.name}
                    onChange={(e) => setFormData(prev => ({ ...prev, name: e.target.value }))}
                    aria-required="true"
                    aria-invalid={errors.name ? 'true' : 'false'}
                    aria-describedby={errors.name ? 'name-error' : 'name-help'}
                  />
                  <div id="name-help">Enter a descriptive name for your campaign</div>
                  {errors.name && (
                    <div id="name-error" role="alert" aria-live="polite">
                      {errors.name}
                    </div>
                  )}
                </div>

                <fieldset>
                  <legend>
                    Campaign Objective <span aria-label="required">*</span>
                  </legend>
                  <div role="radiogroup" aria-required="true" aria-invalid={errors.objective ? 'true' : 'false'}>
                    {[
                      { value: 'awareness', label: 'Brand Awareness', desc: 'Increase brand visibility and recognition' },
                      { value: 'engagement', label: 'Engagement', desc: 'Drive user interaction and engagement' },
                      { value: 'conversion', label: 'Conversion', desc: 'Generate leads and sales' },
                      { value: 'retention', label: 'Customer Retention', desc: 'Keep existing customers engaged' }
                    ].map((objective) => (
                      <label key={objective.value}>
                        <input
                          type="radio"
                          name="objective"
                          value={objective.value}
                          checked={formData.objective === objective.value}
                          onChange={(e) => setFormData(prev => ({ ...prev, objective: e.target.value }))}
                          aria-describedby={`${objective.value}-desc`}
                        />
                        <span>{objective.label}</span>
                        <div id={`${objective.value}-desc`} className="option-description">
                          {objective.desc}
                        </div>
                      </label>
                    ))}
                  </div>
                  {errors.objective && (
                    <div role="alert" aria-live="polite">
                      {errors.objective}
                    </div>
                  )}
                </fieldset>
              </fieldset>
            )}

            {/* Step 2: Budget & Schedule */}
            {step === 2 && (
              <fieldset>
                <legend>Budget & Schedule</legend>
                
                <div>
                  <label htmlFor="budget">
                    Budget (USD) <span aria-label="required">*</span>
                  </label>
                  <input
                    type="number"
                    id="budget"
                    min="0"
                    step="100"
                    value={formData.budget}
                    onChange={(e) => setFormData(prev => ({ ...prev, budget: e.target.value }))}
                    aria-required="true"
                    aria-invalid={errors.budget ? 'true' : 'false'}
                    aria-describedby={errors.budget ? 'budget-error' : 'budget-help'}
                  />
                  <div id="budget-help">Enter your total campaign budget in USD</div>
                  {errors.budget && (
                    <div id="budget-error" role="alert" aria-live="polite">
                      {errors.budget}
                    </div>
                  )}
                </div>

                <div>
                  <label htmlFor="start-date">
                    Start Date <span aria-label="required">*</span>
                  </label>
                  <input
                    type="date"
                    id="start-date"
                    value={formData.startDate}
                    onChange={(e) => setFormData(prev => ({ ...prev, startDate: e.target.value }))}
                    aria-required="true"
                    aria-invalid={errors.startDate ? 'true' : 'false'}
                    aria-describedby={errors.startDate ? 'start-date-error' : undefined}
                  />
                  {errors.startDate && (
                    <div id="start-date-error" role="alert" aria-live="polite">
                      {errors.startDate}
                    </div>
                  )}
                </div>

                <div>
                  <label htmlFor="end-date">
                    End Date <span aria-label="required">*</span>
                  </label>
                  <input
                    type="date"
                    id="end-date"
                    value={formData.endDate}
                    onChange={(e) => setFormData(prev => ({ ...prev, endDate: e.target.value }))}
                    aria-required="true"
                    aria-invalid={errors.endDate ? 'true' : 'false'}
                    aria-describedby={errors.endDate ? 'end-date-error' : undefined}
                    min={formData.startDate}
                  />
                  {errors.endDate && (
                    <div id="end-date-error" role="alert" aria-live="polite">
                      {errors.endDate}
                    </div>
                  )}
                </div>
              </fieldset>
            )}

            {/* Step 3: Targeting & Channels */}
            {step === 3 && (
              <fieldset>
                <legend>Targeting & Channels</legend>
                
                <div>
                  <label htmlFor="target-audience">
                    Target Audience <span aria-label="required">*</span>
                  </label>
                  <textarea
                    id="target-audience"
                    rows={4}
                    value={formData.targetAudience}
                    onChange={(e) => setFormData(prev => ({ ...prev, targetAudience: e.target.value }))}
                    aria-required="true"
                    aria-invalid={errors.targetAudience ? 'true' : 'false'}
                    aria-describedby={errors.targetAudience ? 'audience-error' : 'audience-help'}
                    placeholder="Describe your target audience..."
                  />
                  <div id="audience-help">
                    Describe your target audience demographics, interests, and behaviors
                  </div>
                  {errors.targetAudience && (
                    <div id="audience-error" role="alert" aria-live="polite">
                      {errors.targetAudience}
                    </div>
                  )}
                </div>

                <fieldset>
                  <legend>
                    Marketing Channels <span aria-label="required">*</span>
                  </legend>
                  <div role="group" aria-required="true" aria-invalid={errors.channels ? 'true' : 'false'}>
                    {[
                      { value: 'social-media', label: 'Social Media', desc: 'Facebook, Instagram, Twitter, LinkedIn' },
                      { value: 'email', label: 'Email Marketing', desc: 'Newsletter campaigns and automation' },
                      { value: 'search-ads', label: 'Search Advertising', desc: 'Google Ads and Bing Ads' },
                      { value: 'display-ads', label: 'Display Advertising', desc: 'Banner ads and retargeting' },
                      { value: 'content', label: 'Content Marketing', desc: 'Blog posts and articles' },
                      { value: 'influencer', label: 'Influencer Marketing', desc: 'Partnership with influencers' }
                    ].map((channel) => (
                      <label key={channel.value}>
                        <input
                          type="checkbox"
                          value={channel.value}
                          checked={formData.channels.includes(channel.value)}
                          onChange={(e) => handleChannelChange(channel.value, e.target.checked)}
                          aria-describedby={`${channel.value}-desc`}
                        />
                        <span>{channel.label}</span>
                        <div id={`${channel.value}-desc`} className="option-description">
                          {channel.desc}
                        </div>
                      </label>
                    ))}
                  </div>
                  {errors.channels && (
                    <div role="alert" aria-live="polite">
                      {errors.channels}
                    </div>
                  )}
                </fieldset>
              </fieldset>
            )}

            {/* Navigation buttons */}
            <div role="group" aria-label="Form navigation">
              <button
                type="button"
                onClick={handlePrevious}
                disabled={step === 1}
              >
                Previous
              </button>
              
              {step < totalSteps ? (
                <button
                  type="button"
                  onClick={handleNext}
                >
                  Next
                </button>
              ) : (
                <button
                  type="submit"
                  onClick={(e) => {
                    e.preventDefault();
                    if (validateCurrentStep()) {
                      alert('Campaign created successfully!');
                    }
                  }}
                >
                  Create Campaign
                </button>
              )}
              
              <button type="button">
                Save as Draft
              </button>
            </div>
          </form>
        </div>
      );
    };

    const { container } = render(<CampaignForm />);
    
    const results = await axe(container, wcagConfig);
    expect(results).toHaveNoViolations();

    // Test form navigation
    const nextButton = screen.getByRole('button', { name: 'Next' });
    const nameInput = screen.getByLabelText(/campaign name/i);
    
    // Try to proceed without filling required fields
    await userEvent.click(nextButton);
    
    // Should show validation errors
    expect(screen.getByRole('alert')).toBeInTheDocument();
    expect(nameInput).toHaveAttribute('aria-invalid', 'true');
    
    // Fill required fields and proceed
    await userEvent.type(nameInput, 'Test Campaign');
    const awarenessRadio = screen.getByRole('radio', { name: /brand awareness/i });
    await userEvent.click(awarenessRadio);
    
    await userEvent.click(nextButton);
    
    // Should move to step 2
    expect(screen.getByText('Budget & Schedule')).toBeInTheDocument();
  });

  it('should provide accessible campaign data table with filtering and sorting', async () => {
    const CampaignTable = () => {
      const [campaigns] = React.useState([
        {
          id: 1,
          name: 'Summer Sale 2024',
          status: 'Active',
          budget: 50000,
          spent: 32000,
          impressions: 125000,
          clicks: 3200,
          conversions: 156,
          startDate: '2024-06-01',
          endDate: '2024-08-31'
        },
        {
          id: 2,
          name: 'Brand Awareness Q3',
          status: 'Paused',
          budget: 75000,
          spent: 45000,
          impressions: 89000,
          clicks: 2100,
          conversions: 89,
          startDate: '2024-07-01',
          endDate: '2024-09-30'
        },
        {
          id: 3,
          name: 'Holiday Promotion',
          status: 'Draft',
          budget: 100000,
          spent: 0,
          impressions: 0,
          clicks: 0,
          conversions: 0,
          startDate: '2024-11-01',
          endDate: '2024-12-31'
        }
      ]);

      const [sortColumn, setSortColumn] = React.useState('name');
      const [sortDirection, setSortDirection] = React.useState<'asc' | 'desc'>('asc');
      const [statusFilter, setStatusFilter] = React.useState('all');
      const [selectedCampaigns, setSelectedCampaigns] = React.useState<number[]>([]);

      const handleSort = (column: string) => {
        if (column === sortColumn) {
          setSortDirection(sortDirection === 'asc' ? 'desc' : 'asc');
        } else {
          setSortColumn(column);
          setSortDirection('asc');
        }
      };

      const handleSelectAll = (checked: boolean) => {
        if (checked) {
          setSelectedCampaigns(campaigns.map(c => c.id));
        } else {
          setSelectedCampaigns([]);
        }
      };

      const handleSelectCampaign = (id: number, checked: boolean) => {
        if (checked) {
          setSelectedCampaigns(prev => [...prev, id]);
        } else {
          setSelectedCampaigns(prev => prev.filter(cid => cid !== id));
        }
      };

      const filteredCampaigns = campaigns.filter(campaign => 
        statusFilter === 'all' || campaign.status.toLowerCase() === statusFilter
      );

      return (
        <div role="region" aria-labelledby="campaigns-table-title">
          <h2 id="campaigns-table-title">Campaign Management</h2>
          
          {/* Filters and actions */}
          <div role="group" aria-label="Table controls">
            <div>
              <label htmlFor="status-filter">Filter by status:</label>
              <select
                id="status-filter"
                value={statusFilter}
                onChange={(e) => setStatusFilter(e.target.value)}
                aria-describedby="filter-help"
              >
                <option value="all">All Campaigns</option>
                <option value="active">Active</option>
                <option value="paused">Paused</option>
                <option value="draft">Draft</option>
              </select>
              <div id="filter-help" className="sr-only">
                Filter campaigns by their current status
              </div>
            </div>

            {selectedCampaigns.length > 0 && (
              <div role="toolbar" aria-label="Bulk actions">
                <span aria-live="polite">
                  {selectedCampaigns.length} campaign{selectedCampaigns.length !== 1 ? 's' : ''} selected
                </span>
                <button type="button" aria-describedby="bulk-pause-desc">
                  Pause Selected
                </button>
                <div id="bulk-pause-desc" className="sr-only">
                  Pause all selected campaigns
                </div>
                <button type="button" aria-describedby="bulk-delete-desc">
                  Delete Selected
                </button>
                <div id="bulk-delete-desc" className="sr-only">
                  Delete all selected campaigns
                </div>
              </div>
            )}
          </div>

          {/* Campaign table */}
          <table role="table" aria-labelledby="campaigns-table-title" aria-describedby="table-desc">
            <caption id="table-desc">
              Campaign data with sortable columns. {filteredCampaigns.length} campaigns shown.
            </caption>
            
            <thead>
              <tr>
                <th scope="col">
                  <input
                    type="checkbox"
                    aria-label="Select all campaigns"
                    checked={selectedCampaigns.length === campaigns.length}
                    onChange={(e) => handleSelectAll(e.target.checked)}
                  />
                </th>
                <th scope="col">
                  <button
                    onClick={() => handleSort('name')}
                    aria-sort={sortColumn === 'name' ? sortDirection : 'none'}
                    aria-label={`Sort by campaign name ${sortColumn === 'name' ? sortDirection : ''}`}
                  >
                    Campaign Name
                    <span aria-hidden="true">
                      {sortColumn === 'name' && (sortDirection === 'asc' ? ' ↑' : ' ↓')}
                    </span>
                  </button>
                </th>
                <th scope="col">
                  <button
                    onClick={() => handleSort('status')}
                    aria-sort={sortColumn === 'status' ? sortDirection : 'none'}
                    aria-label={`Sort by status ${sortColumn === 'status' ? sortDirection : ''}`}
                  >
                    Status
                    <span aria-hidden="true">
                      {sortColumn === 'status' && (sortDirection === 'asc' ? ' ↑' : ' ↓')}
                    </span>
                  </button>
                </th>
                <th scope="col">
                  <button
                    onClick={() => handleSort('budget')}
                    aria-sort={sortColumn === 'budget' ? sortDirection : 'none'}
                    aria-label={`Sort by budget ${sortColumn === 'budget' ? sortDirection : ''}`}
                  >
                    Budget
                    <span aria-hidden="true">
                      {sortColumn === 'budget' && (sortDirection === 'asc' ? ' ↑' : ' ↓')}
                    </span>
                  </button>
                </th>
                <th scope="col">Spend Progress</th>
                <th scope="col">Performance</th>
                <th scope="col">Duration</th>
                <th scope="col">Actions</th>
              </tr>
            </thead>
            
            <tbody>
              {filteredCampaigns.map((campaign) => {
                const spendPercentage = (campaign.spent / campaign.budget) * 100;
                const ctr = campaign.impressions > 0 ? (campaign.clicks / campaign.impressions) * 100 : 0;
                const conversionRate = campaign.clicks > 0 ? (campaign.conversions / campaign.clicks) * 100 : 0;
                
                return (
                  <tr key={campaign.id}>
                    <td>
                      <input
                        type="checkbox"
                        aria-label={`Select ${campaign.name}`}
                        checked={selectedCampaigns.includes(campaign.id)}
                        onChange={(e) => handleSelectCampaign(campaign.id, e.target.checked)}
                      />
                    </td>
                    <th scope="row">
                      <a href={`/campaigns/${campaign.id}`} aria-describedby={`campaign-${campaign.id}-desc`}>
                        {campaign.name}
                      </a>
                      <div id={`campaign-${campaign.id}-desc`} className="sr-only">
                        View details for {campaign.name}
                      </div>
                    </th>
                    <td>
                      <span 
                        className={`status-badge ${campaign.status.toLowerCase()}`}
                        aria-label={`Status: ${campaign.status}`}
                      >
                        {campaign.status}
                      </span>
                    </td>
                    <td>
                      <div>
                        <div aria-label={`Budget: $${campaign.budget.toLocaleString()}`}>
                          ${campaign.budget.toLocaleString()}
                        </div>
                        <div aria-label={`Spent: $${campaign.spent.toLocaleString()}`}>
                          Spent: ${campaign.spent.toLocaleString()}
                        </div>
                      </div>
                    </td>
                    <td>
                      <div role="progressbar" 
                           aria-valuenow={spendPercentage} 
                           aria-valuemin={0} 
                           aria-valuemax={100}
                           aria-label={`Spend progress: ${spendPercentage.toFixed(1)}% of budget used`}>
                        <div 
                          style={{ 
                            width: `${Math.min(spendPercentage, 100)}%`, 
                            height: '20px', 
                            backgroundColor: spendPercentage > 90 ? '#dc3545' : 
                                            spendPercentage > 70 ? '#ffc107' : '#28a745'
                          }}
                          aria-hidden="true"
                        />
                        <span className="sr-only">{spendPercentage.toFixed(1)}% spent</span>
                      </div>
                    </td>
                    <td>
                      <div aria-label={`Performance metrics for ${campaign.name}`}>
                        <div>CTR: {ctr.toFixed(2)}%</div>
                        <div>Conv Rate: {conversionRate.toFixed(2)}%</div>
                        <div>{campaign.conversions} conversions</div>
                      </div>
                    </td>
                    <td>
                      <time dateTime={campaign.startDate} aria-label={`Start date: ${campaign.startDate}`}>
                        {new Date(campaign.startDate).toLocaleDateString()}
                      </time>
                      {' - '}
                      <time dateTime={campaign.endDate} aria-label={`End date: ${campaign.endDate}`}>
                        {new Date(campaign.endDate).toLocaleDateString()}
                      </time>
                    </td>
                    <td>
                      <div role="group" aria-label={`Actions for ${campaign.name}`}>
                        <button 
                          type="button"
                          aria-label={`Edit ${campaign.name}`}
                        >
                          Edit
                        </button>
                        <button 
                          type="button"
                          aria-label={campaign.status === 'Active' ? `Pause ${campaign.name}` : `Resume ${campaign.name}`}
                        >
                          {campaign.status === 'Active' ? 'Pause' : 'Resume'}
                        </button>
                        <button 
                          type="button"
                          aria-label={`Duplicate ${campaign.name}`}
                        >
                          Duplicate
                        </button>
                        <button 
                          type="button"
                          aria-label={`Delete ${campaign.name}`}
                          onClick={() => confirm(`Are you sure you want to delete ${campaign.name}?`)}
                        >
                          Delete
                        </button>
                      </div>
                    </td>
                  </tr>
                );
              })}
            </tbody>
          </table>

          {/* Pagination */}
          <nav aria-label="Campaign table pagination">
            <div role="status" aria-live="polite">
              Showing {filteredCampaigns.length} of {campaigns.length} campaigns
            </div>
            <ul role="list">
              <li>
                <button disabled aria-label="Go to previous page">Previous</button>
              </li>
              <li>
                <button aria-current="page" aria-label="Current page, page 1">1</button>
              </li>
              <li>
                <button aria-label="Go to page 2">2</button>
              </li>
              <li>
                <button aria-label="Go to next page">Next</button>
              </li>
            </ul>
          </nav>
        </div>
      );
    };

    const { container } = render(<CampaignTable />);
    
    const results = await axe(container, wcagConfig);
    expect(results).toHaveNoViolations();

    // Test table sorting
    const nameSort = screen.getByRole('button', { name: /sort by campaign name/i });
    expect(nameSort).toHaveAttribute('aria-sort', 'asc');
    
    await userEvent.click(nameSort);
    expect(nameSort).toHaveAttribute('aria-sort', 'desc');

    // Test filtering
    const statusFilter = screen.getByLabelText('Filter by status:');
    await userEvent.selectOptions(statusFilter, 'active');
    
    // Test selection
    const selectAllCheckbox = screen.getByRole('checkbox', { name: 'Select all campaigns' });
    const firstCampaignCheckbox = screen.getByRole('checkbox', { name: /select summer sale/i });
    
    await userEvent.click(selectAllCheckbox);
    expect(firstCampaignCheckbox).toBeChecked();
    
    // Should show bulk actions
    expect(screen.getByRole('toolbar', { name: 'Bulk actions' })).toBeInTheDocument();
  });

  it('should provide accessible campaign dashboard with real-time updates', async () => {
    const CampaignDashboard = () => {
      const [selectedCampaign, setSelectedCampaign] = React.useState('campaign-1');
      const [timeRange, setTimeRange] = React.useState('7d');
      const [isLive, setIsLive] = React.useState(false);
      const [lastUpdate, setLastUpdate] = React.useState(new Date());

      React.useEffect(() => {
        if (isLive) {
          const interval = setInterval(() => {
            setLastUpdate(new Date());
          }, 30000); // Update every 30 seconds

          return () => clearInterval(interval);
        }
      }, [isLive]);

      return (
        <div role="region" aria-labelledby="dashboard-title">
          <h1 id="dashboard-title">Campaign Dashboard</h1>
          
          {/* Dashboard controls */}
          <div role="group" aria-label="Dashboard controls">
            <div>
              <label htmlFor="campaign-select">Campaign:</label>
              <select
                id="campaign-select"
                value={selectedCampaign}
                onChange={(e) => setSelectedCampaign(e.target.value)}
              >
                <option value="campaign-1">Summer Sale 2024</option>
                <option value="campaign-2">Brand Awareness Q3</option>
                <option value="campaign-3">Holiday Promotion</option>
              </select>
            </div>

            <fieldset>
              <legend>Time Range</legend>
              <div role="radiogroup">
                {[
                  { value: '1d', label: 'Last 24 hours' },
                  { value: '7d', label: 'Last 7 days' },
                  { value: '30d', label: 'Last 30 days' },
                  { value: 'custom', label: 'Custom range' }
                ].map((option) => (
                  <label key={option.value}>
                    <input
                      type="radio"
                      name="timeRange"
                      value={option.value}
                      checked={timeRange === option.value}
                      onChange={(e) => setTimeRange(e.target.value)}
                    />
                    {option.label}
                  </label>
                ))}
              </div>
            </fieldset>

            <div>
              <label>
                <input
                  type="checkbox"
                  checked={isLive}
                  onChange={(e) => setIsLive(e.target.checked)}
                />
                Live Updates
              </label>
            </div>
          </div>

          {/* Real-time status */}
          <div role="status" aria-live="polite" aria-atomic="true">
            {isLive ? (
              <span>
                Live data - Last updated: {lastUpdate.toLocaleTimeString()}
              </span>
            ) : (
              <span>Static data view</span>
            )}
          </div>

          {/* Key metrics */}
          <div role="group" aria-label="Key performance metrics" aria-live={isLive ? 'polite' : 'off'}>
            <div role="img" aria-labelledby="impressions-metric" aria-describedby="impressions-change">
              <h3 id="impressions-metric">Impressions</h3>
              <div style={{ fontSize: '2rem', color: '#007bff' }}>125,000</div>
              <div id="impressions-change">+12.5% from previous period</div>
            </div>

            <div role="img" aria-labelledby="clicks-metric" aria-describedby="clicks-change">
              <h3 id="clicks-metric">Clicks</h3>
              <div style={{ fontSize: '2rem', color: '#28a745' }}>3,200</div>
              <div id="clicks-change">+8.3% from previous period</div>
            </div>

            <div role="img" aria-labelledby="conversions-metric" aria-describedby="conversions-change">
              <h3 id="conversions-metric">Conversions</h3>
              <div style={{ fontSize: '2rem', color: '#ffc107' }}>156</div>
              <div id="conversions-change">-3.1% from previous period</div>
            </div>

            <div role="img" aria-labelledby="roas-metric" aria-describedby="roas-change">
              <h3 id="roas-metric">ROAS</h3>
              <div style={{ fontSize: '2rem', color: '#17a2b8' }}>3.45x</div>
              <div id="roas-change">+15.2% from previous period</div>
            </div>
          </div>

          {/* Performance chart */}
          <div role="img" aria-labelledby="performance-chart-title" aria-describedby="performance-chart-desc">
            <h2 id="performance-chart-title">Performance Over Time</h2>
            <p id="performance-chart-desc">
              Line chart showing campaign performance metrics over the selected time period
            </p>
            
            {/* Chart visualization */}
            <svg width="600" height="300" aria-hidden="true">
              <line x1="0" y1="200" x2="600" y2="100" stroke="#007bff" strokeWidth="2"/>
              <line x1="0" y1="250" x2="600" y2="150" stroke="#28a745" strokeWidth="2"/>
              <line x1="0" y1="180" x2="600" y2="120" stroke="#ffc107" strokeWidth="2"/>
            </svg>

            {/* Accessible data table */}
            <details>
              <summary>View chart data in table format</summary>
              <table>
                <caption>Performance data over time</caption>
                <thead>
                  <tr>
                    <th scope="col">Date</th>
                    <th scope="col">Impressions</th>
                    <th scope="col">Clicks</th>
                    <th scope="col">Conversions</th>
                  </tr>
                </thead>
                <tbody>
                  <tr>
                    <th scope="row">Jan 1</th>
                    <td>15,000</td>
                    <td>400</td>
                    <td>18</td>
                  </tr>
                  <tr>
                    <th scope="row">Jan 2</th>
                    <td>16,500</td>
                    <td>450</td>
                    <td>22</td>
                  </tr>
                  <tr>
                    <th scope="row">Jan 3</th>
                    <td>18,200</td>
                    <td>480</td>
                    <td>25</td>
                  </tr>
                </tbody>
              </table>
            </details>
          </div>

          {/* Campaign status alerts */}
          <div role="region" aria-labelledby="alerts-title">
            <h2 id="alerts-title">Campaign Alerts</h2>
            
            <div role="alert" aria-atomic="true">
              <h3>Budget Alert</h3>
              <p>Campaign "Summer Sale 2024" has spent 85% of its budget.</p>
              <button type="button">Increase Budget</button>
              <button type="button">Pause Campaign</button>
            </div>

            <div role="status" aria-atomic="true">
              <h3>Performance Update</h3>
              <p>CTR has improved by 15% over the last 24 hours.</p>
            </div>
          </div>
        </div>
      );
    };

    const { container } = render(<CampaignDashboard />);
    
    const results = await axe(container, wcagConfig);
    expect(results).toHaveNoViolations();

    // Test live updates toggle
    const liveToggle = screen.getByRole('checkbox', { name: /live updates/i });
    await userEvent.click(liveToggle);
    
    // Should enable live updates
    expect(liveToggle).toBeChecked();
    
    // Test campaign selection
    const campaignSelect = screen.getByLabelText('Campaign:');
    await userEvent.selectOptions(campaignSelect, 'campaign-2');
    
    // Test time range selection
    const timeRangeOptions = screen.getAllByRole('radio');
    const thirtyDaysOption = timeRangeOptions.find(option => 
      (option as HTMLInputElement).value === '30d'
    );
    
    if (thirtyDaysOption) {
      await userEvent.click(thirtyDaysOption);
      expect(thirtyDaysOption).toBeChecked();
    }

    // Test chart data table
    const chartDetails = screen.getByRole('group', { name: /view chart data/i });
    expect(chartDetails).toBeInTheDocument();
  });
});