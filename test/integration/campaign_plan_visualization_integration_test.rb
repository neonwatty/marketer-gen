require 'test_helper'

class CampaignPlanVisualizationIntegrationTest < ActionDispatch::IntegrationTest
  def setup
    @user = users(:marketer_user)
    sign_in_as @user
    
    @campaign_plan = campaign_plans(:completed_plan)
    @campaign_plan.generated_strategy = {
      'objectives' => ['Increase brand awareness', 'Drive website traffic'],
      'key_messages' => ['Quality products', 'Excellent service'],
      'rationale' => 'Strategic approach based on market analysis',
      'channels' => ['Social Media', 'Email Marketing', 'Content Marketing'],
      'budget_allocation' => { 'social' => 40, 'email' => 30, 'content' => 30 },
      'creative_themes' => ['Authentic storytelling', 'Customer success']
    }
    @campaign_plan.generated_timeline = [
      { 'week' => 1, 'activity' => 'Campaign launch preparation' },
      { 'week' => 2, 'activity' => 'Content creation and review' },
      { 'week' => 3, 'activity' => 'Launch and monitoring' }
    ]
    @campaign_plan.generated_assets = ['Brand guidelines', 'Social media templates', 'Email templates']
    @campaign_plan.save!
  end

  test "campaign plan show page renders with proper data assignment" do
    get campaign_plan_path(@campaign_plan)
    
    assert_response :success
    assert_equal @campaign_plan, assigns(:campaign_plan)
    
    # Verify all partial content is rendered
    assert_select 'h2', text: 'Strategic Overview'
    assert_select 'h2', text: 'Content Mapping'
    assert_select 'h2', text: 'Creative Approach'
    assert_select 'h2', text: 'Interactive Timeline'
    assert_select 'h2', text: 'Strategic Rationale'
  end

  test "view properly displays campaign strategy data" do
    get campaign_plan_path(@campaign_plan)
    
    # Check strategic overview content
    assert_select 'div.border-l-4.border-blue-500' do
      assert_select 'h3', text: 'Campaign Objectives'
    end
    
    # Check key messages display
    assert_select 'div.border-l-4.border-green-500' do
      assert_select 'h3', text: 'Key Messages'
      assert_select 'div.bg-green-50', count: 2
    end
    
    # Check strategic rationale
    assert_select 'div.border-l-4.border-purple-500' do
      assert_select 'h3', text: 'Strategic Rationale'
    end
  end

  test "content mapping displays platform-specific information" do
    get campaign_plan_path(@campaign_plan)
    
    # Should have content map platforms for each channel
    assert_select 'div.content-map-platform', count: 3
    
    # Check platform data attributes
    assert_select 'div[data-platform="social-media"]'
    assert_select 'div[data-platform="email-marketing"]' 
    assert_select 'div[data-platform="content-marketing"]'
    
    # Check toggle buttons
    assert_select 'button.content-map-toggle', count: 3
    
    # Check content details sections
    assert_select 'div.content-details[style*="display: none"]', count: 3
  end

  test "timeline visualization renders interactive elements" do
    get campaign_plan_path(@campaign_plan)
    
    # Check timeline controls
    assert_select 'button#timeline-play'
    assert_select 'select#timeline-view'
    assert_select 'span#timeline-counter'
    
    # Check timeline items
    assert_select 'div.timeline-item', count: 3
    assert_select 'div.timeline-item[data-index="0"][data-week="1"]'
    assert_select 'div.timeline-item[data-index="1"][data-week="2"]'
    assert_select 'div.timeline-item[data-index="2"][data-week="3"]'
    
    # Check progress elements
    assert_select 'div#timeline-progress'
    assert_select 'div.timeline-progress'
  end

  test "creative approach section displays dynamic content" do
    get campaign_plan_path(@campaign_plan)
    
    # Check brand identity section
    assert_select 'div.bg-gradient-to-br.from-pink-50' do
      assert_select 'h3', text: 'Brand Identity'
      assert_select 'h4', text: 'Visual Style'
      assert_select 'h4', text: 'Tone of Voice'
    end
    
    # Check creative themes
    assert_select 'div.bg-gradient-to-br.from-blue-50' do
      assert_select 'h3', text: 'Creative Themes'
    end
    
    # Check cross-platform threading
    assert_select 'h3', text: 'Cross-Platform Content Threading'
    assert_select 'h4', text: 'Content Repurposing'
    assert_select 'h4', text: 'Narrative Consistency'
    assert_select 'h4', text: 'Cross-References'
  end

  test "strategic rationale shows budget allocation when present" do
    get campaign_plan_path(@campaign_plan)
    
    # Check budget allocation section
    assert_select 'h3', text: 'Budget Allocation Logic'
    
    # Check individual allocation items
    assert_select 'div.bg-gray-50 h4', text: 'Social'
    assert_select 'div.bg-gray-50 h4', text: 'Email'
    assert_select 'div.bg-gray-50 h4', text: 'Content'
    
    # Check percentage displays
    assert_select 'span.text-green-600', text: '40%'
    assert_select 'span.text-green-600', text: '30%'
  end

  test "risk mitigation and success metrics are displayed" do
    get campaign_plan_path(@campaign_plan)
    
    # Check risk mitigation section
    assert_select 'h3', text: 'Risk Mitigation Strategy'
    assert_select 'h4', text: 'Market Risks'
    assert_select 'h4', text: 'Execution Risks'  
    assert_select 'h4', text: 'Performance Risks'
    
    # Check success metrics framework
    assert_select 'h3', text: 'Success Measurement Framework'
    assert_select 'h4', text: 'Primary KPIs'
    assert_select 'h4', text: 'Secondary Metrics'
  end

  test "CSS classes and styling are properly applied" do
    get campaign_plan_path(@campaign_plan)
    
    # Check main layout classes
    assert_select 'div.container.mx-auto.px-4.py-8'
    assert_select 'div.max-w-4xl.mx-auto'
    
    # Check card styling
    assert_select 'div.bg-white.rounded-lg.shadow-sm.border.border-gray-200', minimum: 5
    
    # Check responsive grid classes
    assert_select 'div.grid.grid-cols-1.lg\\:grid-cols-2', minimum: 1
    assert_select 'div.grid.grid-cols-1.md\\:grid-cols-2', minimum: 1
    
    # Check icon styling
    assert_select 'svg.w-6.h-6', minimum: 5
  end

  test "JavaScript includes are present for interactive features" do
    get campaign_plan_path(@campaign_plan)
    
    # Check that JavaScript functions are included
    assert_includes response.body, 'function toggleContentSection'
    assert_includes response.body, 'function animateTimeline'
    assert_includes response.body, 'function toggleTimelineDetails'
    assert_includes response.body, 'function changeTimelineView'
    
    # Check event listeners
    assert_includes response.body, 'addEventListener'
    assert_includes response.body, 'DOMContentLoaded'
  end

  test "view handles different campaign types correctly" do
    # Test awareness campaign (using brand_awareness which is valid)
    @campaign_plan.update(campaign_type: 'brand_awareness')
    get campaign_plan_path(@campaign_plan)
    
    assert_includes response.body, 'Inspiring and educational'
    
    # Test conversion campaign (using sales_promotion which is valid)
    @campaign_plan.update(campaign_type: 'sales_promotion')
    get campaign_plan_path(@campaign_plan)
    
    assert_includes response.body, 'Persuasive and action-oriented'
    
    # Test engagement campaign (using the default case)
    @campaign_plan.update(campaign_type: 'product_launch')
    get campaign_plan_path(@campaign_plan)
    
    assert_includes response.body, 'Professional yet approachable'
  end

  test "view handles different campaign objectives for success metrics" do
    # Test awareness objective
    @campaign_plan.update(objective: 'brand_awareness')
    get campaign_plan_path(@campaign_plan)
    
    assert_includes response.body, 'Reach'
    assert_includes response.body, 'Impressions'
    assert_includes response.body, 'Brand Recall'
    
    # Test conversion objective
    @campaign_plan.update(objective: 'customer_acquisition')
    get campaign_plan_path(@campaign_plan)
    
    assert_includes response.body, 'Conversion Rate'
    assert_includes response.body, 'Cost per Acquisition'
    assert_includes response.body, 'Revenue'
  end

  test "partial rendering works correctly with data flow" do
    get campaign_plan_path(@campaign_plan)
    
    # Verify that partials receive the campaign_plan variable correctly
    assert_select 'div.strategic-overview' # from strategic_overview partial
    assert_select 'div.content-map-platform' # from content_map partial  
    assert_select 'div.creative-approach' # from creative_approach partial
    assert_select 'div.timeline-container' # from timeline_visualization partial
    assert_select 'div.strategic-rationale' # from strategic_rationale partial
    
    # Check that data is properly passed to partials
    assert_includes response.body, 'Increase brand awareness'
    assert_includes response.body, 'Social Media'
    assert_includes response.body, 'Campaign launch preparation'
  end

  test "view gracefully handles missing or nil data" do
    # Test with minimal data
    @campaign_plan.update(
      generated_strategy: nil,
      generated_timeline: nil,
      generated_assets: nil,
      generated_summary: nil
    )
    
    get campaign_plan_path(@campaign_plan)
    assert_response :success
    
    # Should show fallback content
    assert_includes response.body, 'Strategic objectives will be defined'
    assert_includes response.body, 'Timeline Coming Soon'
    assert_includes response.body, 'Content Strategy Pending'
  end

  test "view handles empty arrays and objects" do
    @campaign_plan.update(
      generated_strategy: {},
      generated_timeline: [],
      generated_assets: []
    )
    
    get campaign_plan_path(@campaign_plan)
    assert_response :success
    
    # Should not cause errors and show appropriate fallbacks
    assert_includes response.body, 'Strategic Overview'
    assert_includes response.body, 'Interactive Timeline'
  end

  test "view properly escapes user-generated content" do
    @campaign_plan.generated_strategy = {
      'objectives' => ['<script>alert("xss")</script>Test objective'],
      'rationale' => '<script>alert("xss")</script>Test rationale'
    }
    @campaign_plan.save!
    
    get campaign_plan_path(@campaign_plan)
    
    # Script tags should be escaped
    assert_not_includes response.body, '<script>alert("xss")</script>'
    assert_includes response.body, '&lt;script&gt;'
  end

  test "view includes proper meta tags and page structure" do
    get campaign_plan_path(@campaign_plan)
    
    # Check page title is set
    assert_select 'title', text: /#{@campaign_plan.name}/
    
    # Check main content structure
    assert_select 'div.container'
    assert_select 'h1', text: @campaign_plan.name
    
    # Check status indicator
    assert_select 'span.px-3.py-1', text: /#{@campaign_plan.status.humanize}/
  end

  test "view performance with large datasets" do
    # Create campaign with large dataset
    large_timeline = Array.new(50) do |i|
      { 'week' => i + 1, 'activity' => "Activity #{i + 1}" }
    end
    
    @campaign_plan.update(generated_timeline: large_timeline)
    
    start_time = Time.current
    get campaign_plan_path(@campaign_plan)
    render_time = Time.current - start_time
    
    assert_response :success
    assert render_time < 2.seconds, "View rendering took too long: #{render_time}s"
    
    # Should still render all timeline items
    assert_select 'div.timeline-item', count: 50
  end
end