require 'test_helper'

class CampaignPlanShowViewTest < ActionView::TestCase
  def setup
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

  test "renders strategic overview with objectives" do
    render 'campaign_plans/partials/strategic_overview', campaign_plan: @campaign_plan
    
    assert_includes rendered, 'Strategic Overview'
    assert_includes rendered, 'Campaign Objectives'
    assert_includes rendered, 'Increase brand awareness'
    assert_includes rendered, 'Drive website traffic'
  end

  test "renders strategic overview with key messages" do
    render 'campaign_plans/partials/strategic_overview', campaign_plan: @campaign_plan
    
    assert_includes rendered, 'Key Messages'
    assert_includes rendered, 'Quality products'
    assert_includes rendered, 'Excellent service'
    assert_select 'div.bg-green-50', count: 2
  end

  test "renders strategic overview with rationale" do
    render 'campaign_plans/partials/strategic_overview', campaign_plan: @campaign_plan
    
    assert_includes rendered, 'Strategic Rationale'
    assert_includes rendered, 'Strategic approach based on market analysis'
  end

  test "renders strategic overview fallback when no data present" do
    @campaign_plan.generated_strategy = nil
    render 'campaign_plans/partials/strategic_overview', campaign_plan: @campaign_plan
    
    assert_includes rendered, 'Strategic objectives will be defined'
    assert_includes rendered, 'Core messaging themes will be developed'
  end

  test "renders content map with platform specific strategies" do
    render 'campaign_plans/partials/content_map', campaign_plan: @campaign_plan
    
    assert_includes rendered, 'Content Mapping'
    assert_includes rendered, 'Social Media'
    assert_includes rendered, 'Email Marketing'
    assert_includes rendered, 'Content Marketing'
    assert_select 'div.content-map-platform', count: 3
  end

  test "content map includes interactive toggle elements" do
    render 'campaign_plans/partials/content_map', campaign_plan: @campaign_plan
    
    assert_select 'button.content-map-toggle', count: 3
    assert_select 'div.content-details[style*="display: none"]', count: 3
    assert_includes rendered, 'toggleContentSection'
  end

  test "content map shows platform-specific content types" do
    render 'campaign_plans/partials/content_map', campaign_plan: @campaign_plan
    
    assert_includes rendered, 'Recommended Content Types'
    assert_includes rendered, 'Publishing Frequency'
    assert_includes rendered, 'Strategic Purpose'
  end

  test "content map renders fallback when no channels present" do
    @campaign_plan.generated_strategy = nil
    render 'campaign_plans/partials/content_map', campaign_plan: @campaign_plan
    
    assert_includes rendered, 'Content Strategy Pending'
    assert_includes rendered, 'Detailed content mapping will be available'
  end

  test "renders creative approach with brand identity" do
    render 'campaign_plans/partials/creative_approach', campaign_plan: @campaign_plan
    
    assert_includes rendered, 'Creative Approach'
    assert_includes rendered, 'Brand Identity'
    assert_includes rendered, 'Visual Style'
    assert_includes rendered, 'Tone of Voice'
  end

  test "creative approach shows dynamic tone based on campaign type" do
    @campaign_plan.campaign_type = 'awareness'
    render 'campaign_plans/partials/creative_approach', campaign_plan: @campaign_plan
    
    assert_includes rendered, 'Inspiring and educational'
    
    @campaign_plan.campaign_type = 'conversion'
    render 'campaign_plans/partials/creative_approach', campaign_plan: @campaign_plan
    
    assert_includes rendered, 'Persuasive and action-oriented'
  end

  test "creative approach displays creative themes when available" do
    render 'campaign_plans/partials/creative_approach', campaign_plan: @campaign_plan
    
    assert_includes rendered, 'Creative Themes'
    assert_includes rendered, 'Authentic storytelling'
    assert_includes rendered, 'Customer success'
  end

  test "creative approach shows cross-platform threading" do
    render 'campaign_plans/partials/creative_approach', campaign_plan: @campaign_plan
    
    assert_includes rendered, 'Cross-Platform Content Threading'
    assert_includes rendered, 'Content Repurposing'
    assert_includes rendered, 'Narrative Consistency'
    assert_includes rendered, 'Cross-References'
  end

  test "creative approach includes asset framework when assets present" do
    render 'campaign_plans/partials/creative_approach', campaign_plan: @campaign_plan
    
    assert_includes rendered, 'Creative Asset Framework'
    assert_includes rendered, 'Brand guidelines'
    assert_includes rendered, 'Social media templates'
    assert_includes rendered, 'Email templates'
  end

  test "renders timeline visualization with interactive elements" do
    render 'campaign_plans/partials/timeline_visualization', campaign_plan: @campaign_plan
    
    assert_includes rendered, 'Interactive Timeline'
    assert_select 'button#timeline-play', count: 1
    assert_select 'select#timeline-view', count: 1
    assert_includes rendered, 'Animate Timeline'
  end

  test "timeline visualization displays timeline items correctly" do
    render 'campaign_plans/partials/timeline_visualization', campaign_plan: @campaign_plan
    
    assert_select 'div.timeline-item', count: 3
    assert_includes rendered, 'Campaign launch preparation'
    assert_includes rendered, 'Content creation and review'
    assert_includes rendered, 'Launch and monitoring'
  end

  test "timeline includes progress tracking elements" do
    render 'campaign_plans/partials/timeline_visualization', campaign_plan: @campaign_plan
    
    assert_select 'div#timeline-progress', count: 1
    assert_select 'span#timeline-counter', count: 1
    assert_includes rendered, '/ 3 activities'
  end

  test "timeline items have proper data attributes" do
    render 'campaign_plans/partials/timeline_visualization', campaign_plan: @campaign_plan
    
    assert_select 'div.timeline-item[data-index="0"][data-week="1"]', count: 1
    assert_select 'div.timeline-item[data-index="1"][data-week="2"]', count: 1
    assert_select 'div.timeline-item[data-index="2"][data-week="3"]', count: 1
  end

  test "timeline includes interactive JavaScript functions" do
    render 'campaign_plans/partials/timeline_visualization', campaign_plan: @campaign_plan
    
    assert_includes rendered, 'function animateTimeline'
    assert_includes rendered, 'function toggleTimelineDetails'
    assert_includes rendered, 'function changeTimelineView'
  end

  test "timeline renders fallback when no timeline present" do
    @campaign_plan.generated_timeline = nil
    render 'campaign_plans/partials/timeline_visualization', campaign_plan: @campaign_plan
    
    assert_includes rendered, 'Timeline Coming Soon'
    assert_includes rendered, 'Your interactive campaign timeline will be displayed here'
  end

  test "renders strategic rationale with channel selection logic" do
    render 'campaign_plans/partials/strategic_rationale', campaign_plan: @campaign_plan
    
    assert_includes rendered, 'Strategic Rationale'
    assert_includes rendered, 'Channel Selection'
    assert_includes rendered, 'Social Media'
    assert_includes rendered, 'Email Marketing'
    assert_includes rendered, 'Content Marketing'
  end

  test "strategic rationale includes timing strategy" do
    render 'campaign_plans/partials/strategic_rationale', campaign_plan: @campaign_plan
    
    assert_includes rendered, 'Timing Strategy'
    assert_includes rendered, 'Launch Timing'
    assert_includes rendered, 'Phased Approach'
    assert_includes rendered, 'Seasonal Considerations'
  end

  test "strategic rationale shows budget allocation logic when available" do
    render 'campaign_plans/partials/strategic_rationale', campaign_plan: @campaign_plan
    
    assert_includes rendered, 'Budget Allocation Logic'
    assert_includes rendered, 'Social'
    assert_includes rendered, 'Email'
    assert_includes rendered, 'Content'
    assert_includes rendered, '40%'
    assert_includes rendered, '30%'
  end

  test "strategic rationale includes risk mitigation framework" do
    render 'campaign_plans/partials/strategic_rationale', campaign_plan: @campaign_plan
    
    assert_includes rendered, 'Risk Mitigation Strategy'
    assert_includes rendered, 'Market Risks'
    assert_includes rendered, 'Execution Risks'
    assert_includes rendered, 'Performance Risks'
  end

  test "strategic rationale shows success metrics based on objective" do
    @campaign_plan.objective = 'awareness'
    render 'campaign_plans/partials/strategic_rationale', campaign_plan: @campaign_plan
    
    assert_includes rendered, 'Success Measurement Framework'
    assert_includes rendered, 'Primary KPIs'
    assert_includes rendered, 'Reach'
    assert_includes rendered, 'Impressions'
    assert_includes rendered, 'Brand Recall'
  end

  test "renders main show view with all partial sections" do
    # Set instance variable directly since template uses @campaign_plan
    controller.instance_variable_set(:@campaign_plan, @campaign_plan)
    render template: 'campaign_plans/show'
    
    assert_includes rendered, 'Strategic Overview'
    assert_includes rendered, 'Content Mapping'  
    assert_includes rendered, 'Creative Approach'
    assert_includes rendered, 'Interactive Timeline'
    assert_includes rendered, 'Strategic Rationale'
  end

end