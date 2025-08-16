require 'test_helper'

class CampaignPlanPartialsComponentTest < ActionView::TestCase
  def setup
    @campaign_plan = campaign_plans(:completed_plan)
  end

  # Strategic Overview Partial Tests
  class StrategicOverviewTest < CampaignPlanPartialsComponentTest
    test "renders with complete strategy data" do
      @campaign_plan.generated_strategy = {
        'objectives' => ['Increase brand awareness', 'Drive traffic'],
        'key_messages' => ['Quality first', 'Customer focused'],
        'rationale' => 'Based on market research'
      }
      
      render 'campaign_plans/partials/strategic_overview', campaign_plan: @campaign_plan
      
      assert_includes rendered, 'Strategic Overview'
      assert_includes rendered, 'Increase brand awareness'
      assert_includes rendered, 'Quality first'
      assert_includes rendered, 'Based on market research'
    end

    test "renders fallback content when strategy data missing" do
      @campaign_plan.generated_strategy = nil
      
      render 'campaign_plans/partials/strategic_overview', campaign_plan: @campaign_plan
      
      assert_includes rendered, 'Strategic objectives will be defined'
      assert_includes rendered, 'Core messaging themes will be developed'
      assert_includes rendered, 'Strategic decision-making framework'
    end

    test "handles partial strategy data gracefully" do
      @campaign_plan.generated_strategy = { 'objectives' => ['Test objective'] }
      
      render 'campaign_plans/partials/strategic_overview', campaign_plan: @campaign_plan
      
      assert_includes rendered, 'Test objective'
      assert_includes rendered, 'Core messaging themes will be developed'
    end

    test "applies proper CSS classes for styling" do
      @campaign_plan.generated_strategy = {
        'objectives' => ['Test'],
        'key_messages' => ['Test'],
        'rationale' => 'Test'
      }
      
      render 'campaign_plans/partials/strategic_overview', campaign_plan: @campaign_plan
      
      assert_select 'div.border-l-4.border-blue-500'
      assert_select 'div.border-l-4.border-green-500'
      assert_select 'div.border-l-4.border-purple-500'
      assert_select 'div.bg-green-50', minimum: 1
    end
  end

  # Content Map Partial Tests
  class ContentMapTest < CampaignPlanPartialsComponentTest
    test "renders platform-specific content with complete data" do
      @campaign_plan.generated_strategy = {
        'channels' => ['Social Media', 'Email Marketing', 'Content Marketing']
      }
      
      render 'campaign_plans/partials/content_map', campaign_plan: @campaign_plan
      
      assert_includes rendered, 'Content Mapping'
      assert_select 'div.content-map-platform', count: 3
      assert_select 'button.content-map-toggle', count: 3
      assert_includes rendered, 'Social Media'
      assert_includes rendered, 'Email Marketing'
    end

    test "shows platform-specific content types correctly" do
      @campaign_plan.generated_strategy = { 'channels' => ['Social Media'] }
      
      render 'campaign_plans/partials/content_map', campaign_plan: @campaign_plan
      
      assert_includes rendered, 'Visual Posts'
      assert_includes rendered, 'Stories'
      assert_includes rendered, 'Video Content'
      assert_includes rendered, '3-5 posts per week'
    end

    test "handles email marketing channel specifically" do
      @campaign_plan.generated_strategy = { 'channels' => ['Email Marketing'] }
      
      render 'campaign_plans/partials/content_map', campaign_plan: @campaign_plan
      
      assert_includes rendered, 'Welcome Series'
      assert_includes rendered, 'Newsletter'
      assert_includes rendered, 'Weekly newsletter'
    end

    test "renders fallback when no channels present" do
      @campaign_plan.generated_strategy = nil
      
      render 'campaign_plans/partials/content_map', campaign_plan: @campaign_plan
      
      assert_includes rendered, 'Content Strategy Pending'
      assert_includes rendered, 'Detailed content mapping will be available'
    end

    test "includes interactive JavaScript function" do
      @campaign_plan.generated_strategy = { 'channels' => ['Social Media'] }
      
      render 'campaign_plans/partials/content_map', campaign_plan: @campaign_plan
      
      assert_includes rendered, 'function toggleContentSection'
      assert_includes rendered, 'onclick="toggleContentSection(this)"'
    end

    test "sets proper data attributes for platforms" do
      @campaign_plan.generated_strategy = { 'channels' => ['Social Media', 'Email Marketing'] }
      
      render 'campaign_plans/partials/content_map', campaign_plan: @campaign_plan
      
      assert_select 'div[data-platform="social-media"]'
      assert_select 'div[data-platform="email-marketing"]'
    end
  end

  # Creative Approach Partial Tests
  class CreativeApproachTest < CampaignPlanPartialsComponentTest
    test "renders brand identity section" do
      render 'campaign_plans/partials/creative_approach', campaign_plan: @campaign_plan
      
      assert_includes rendered, 'Creative Approach'
      assert_includes rendered, 'Brand Identity'
      assert_includes rendered, 'Visual Style'
      assert_includes rendered, 'Tone of Voice'
    end

    test "shows dynamic tone based on campaign type" do
      @campaign_plan.campaign_type = 'awareness'
      render 'campaign_plans/partials/creative_approach', campaign_plan: @campaign_plan
      assert_includes rendered, 'Inspiring and educational'

      @campaign_plan.campaign_type = 'conversion'
      render 'campaign_plans/partials/creative_approach', campaign_plan: @campaign_plan
      assert_includes rendered, 'Persuasive and action-oriented'

      @campaign_plan.campaign_type = 'engagement'
      render 'campaign_plans/partials/creative_approach', campaign_plan: @campaign_plan
      assert_includes rendered, 'Conversational and friendly'

      @campaign_plan.campaign_type = 'retention'
      render 'campaign_plans/partials/creative_approach', campaign_plan: @campaign_plan
      assert_includes rendered, 'Supportive and relationship-focused'
    end

    test "displays creative themes when available" do
      @campaign_plan.generated_strategy = {
        'creative_themes' => ['Authentic storytelling', 'Customer success']
      }
      
      render 'campaign_plans/partials/creative_approach', campaign_plan: @campaign_plan
      
      assert_includes rendered, 'Authentic storytelling'
      assert_includes rendered, 'Customer success'
    end

    test "shows cross-platform threading content" do
      render 'campaign_plans/partials/creative_approach', campaign_plan: @campaign_plan
      
      assert_includes rendered, 'Cross-Platform Content Threading'
      assert_includes rendered, 'Content Repurposing'
      assert_includes rendered, 'Narrative Consistency'
      assert_includes rendered, 'Cross-References'
    end

    test "includes asset framework when assets present" do
      @campaign_plan.generated_assets = ['Brand guidelines', 'Templates']
      
      render 'campaign_plans/partials/creative_approach', campaign_plan: @campaign_plan
      
      assert_includes rendered, 'Creative Asset Framework'
      assert_includes rendered, 'Brand guidelines'
      assert_includes rendered, 'Templates'
    end

    test "handles missing assets gracefully" do
      @campaign_plan.generated_assets = nil
      
      render 'campaign_plans/partials/creative_approach', campaign_plan: @campaign_plan
      
      # Should not include asset framework section
      assert_not_includes rendered, 'Creative Asset Framework'
      # But should still render other sections
      assert_includes rendered, 'Brand Identity'
    end
  end

  # Timeline Visualization Partial Tests  
  class TimelineVisualizationTest < CampaignPlanPartialsComponentTest
    test "renders interactive timeline with complete data" do
      @campaign_plan.generated_timeline = [
        { 'week' => 1, 'activity' => 'Planning phase' },
        { 'week' => 2, 'activity' => 'Execution phase' }
      ]
      
      render 'campaign_plans/partials/timeline_visualization', campaign_plan: @campaign_plan
      
      assert_includes rendered, 'Interactive Timeline'
      assert_select 'button#timeline-play'
      assert_select 'select#timeline-view'
      assert_select 'div.timeline-item', count: 2
    end

    test "handles timeline with descriptions and deliverables" do
      @campaign_plan.generated_timeline = [
        { 
          'week' => 1, 
          'activity' => 'Planning', 
          'description' => 'Initial planning phase',
          'deliverables' => ['Project plan', 'Timeline']
        }
      ]
      
      render 'campaign_plans/partials/timeline_visualization', campaign_plan: @campaign_plan
      
      assert_includes rendered, 'Planning'
      assert_includes rendered, 'Initial planning phase'
      assert_includes rendered, 'Project plan'
      assert_includes rendered, 'Timeline'
    end

    test "sets proper data attributes for timeline items" do
      @campaign_plan.generated_timeline = [
        { 'week' => 1, 'activity' => 'Test' },
        { 'week' => 2, 'activity' => 'Test' }
      ]
      
      render 'campaign_plans/partials/timeline_visualization', campaign_plan: @campaign_plan
      
      assert_select 'div.timeline-item[data-index="0"][data-week="1"]'
      assert_select 'div.timeline-item[data-index="1"][data-week="2"]'
    end

    test "includes all required JavaScript functions" do
      @campaign_plan.generated_timeline = [{ 'activity' => 'Test' }]
      
      render 'campaign_plans/partials/timeline_visualization', campaign_plan: @campaign_plan
      
      assert_includes rendered, 'function animateTimeline'
      assert_includes rendered, 'function toggleTimelineDetails'
      assert_includes rendered, 'function changeTimelineView'
      assert_includes rendered, 'addEventListener'
    end

    test "handles non-array timeline data" do
      @campaign_plan.generated_timeline = "Simple timeline text"
      
      render 'campaign_plans/partials/timeline_visualization', campaign_plan: @campaign_plan
      
      assert_includes rendered, 'Simple timeline text'
      assert_select 'div.bg-gray-50.rounded-lg'
    end

    test "renders fallback when no timeline present" do
      @campaign_plan.generated_timeline = nil
      
      render 'campaign_plans/partials/timeline_visualization', campaign_plan: @campaign_plan
      
      assert_includes rendered, 'Timeline Coming Soon'
      assert_includes rendered, 'Your interactive campaign timeline will be displayed here'
    end
  end

  # Strategic Rationale Partial Tests
  class StrategicRationaleTest < CampaignPlanPartialsComponentTest
    test "renders channel selection rationale" do
      @campaign_plan.generated_strategy = {
        'channels' => ['Social Media', 'Email Marketing']
      }
      
      render 'campaign_plans/partials/strategic_rationale', campaign_plan: @campaign_plan
      
      assert_includes rendered, 'Strategic Rationale'
      assert_includes rendered, 'Channel Selection'
      assert_includes rendered, 'Social Media'
      assert_includes rendered, 'Email Marketing'
    end

    test "shows budget allocation logic when present" do
      @campaign_plan.generated_strategy = {
        'budget_allocation' => { 'social' => 50, 'email' => 50 }
      }
      
      render 'campaign_plans/partials/strategic_rationale', campaign_plan: @campaign_plan
      
      assert_includes rendered, 'Budget Allocation Logic'
      assert_includes rendered, 'Social'
      assert_includes rendered, 'Email'
      assert_includes rendered, '50%'
    end

    test "includes timing strategy section" do
      render 'campaign_plans/partials/strategic_rationale', campaign_plan: @campaign_plan
      
      assert_includes rendered, 'Timing Strategy'
      assert_includes rendered, 'Launch Timing'
      assert_includes rendered, 'Phased Approach'
      assert_includes rendered, 'Seasonal Considerations'
    end

    test "displays risk mitigation framework" do
      render 'campaign_plans/partials/strategic_rationale', campaign_plan: @campaign_plan
      
      assert_includes rendered, 'Risk Mitigation Strategy'
      assert_includes rendered, 'Market Risks'
      assert_includes rendered, 'Execution Risks'
      assert_includes rendered, 'Performance Risks'
    end

    test "shows success metrics based on campaign objective" do
      @campaign_plan.objective = 'awareness'
      render 'campaign_plans/partials/strategic_rationale', campaign_plan: @campaign_plan
      
      assert_includes rendered, 'Success Measurement Framework'
      assert_includes rendered, 'Reach'
      assert_includes rendered, 'Impressions'
      assert_includes rendered, 'Brand Recall'

      @campaign_plan.objective = 'conversion'
      render 'campaign_plans/partials/strategic_rationale', campaign_plan: @campaign_plan
      
      assert_includes rendered, 'Conversion Rate'
      assert_includes rendered, 'Cost per Acquisition'
      assert_includes rendered, 'Revenue'
    end

    test "incorporates timeline constraints when present" do
      @campaign_plan.timeline_constraints = 'Q4 holiday season'
      
      render 'campaign_plans/partials/strategic_rationale', campaign_plan: @campaign_plan
      
      assert_includes rendered, 'q4 holiday season'
    end

    test "handles missing strategy data gracefully" do
      @campaign_plan.generated_strategy = nil
      
      render 'campaign_plans/partials/strategic_rationale', campaign_plan: @campaign_plan
      
      assert_includes rendered, 'Channel selection rationale will be detailed here'
      # Should still show other sections that don't depend on strategy
      assert_includes rendered, 'Timing Strategy'
      assert_includes rendered, 'Risk Mitigation Strategy'
    end
  end

  # Cross-partial Integration Tests
  class PartialIntegrationTest < CampaignPlanPartialsComponentTest
    test "all partials work together without conflicts" do
      @campaign_plan.generated_strategy = {
        'objectives' => ['Test objective'],
        'channels' => ['Social Media'],
        'budget_allocation' => { 'social' => 100 }
      }
      @campaign_plan.generated_timeline = [{ 'activity' => 'Test activity' }]
      @campaign_plan.generated_assets = ['Test asset']
      
      # Test strategic overview partial
      render 'campaign_plans/partials/strategic_overview', campaign_plan: @campaign_plan
      strategic_overview = rendered
      assert_includes strategic_overview, 'Strategic Overview'
      
      # Test content map partial
      render 'campaign_plans/partials/content_map', campaign_plan: @campaign_plan
      content_map = rendered
      assert_includes content_map, 'Content Mapping'
      
      # Test creative approach partial
      render 'campaign_plans/partials/creative_approach', campaign_plan: @campaign_plan
      creative_approach = rendered
      assert_includes creative_approach, 'Creative Approach'
      
      # Test timeline partial
      render 'campaign_plans/partials/timeline_visualization', campaign_plan: @campaign_plan
      timeline = rendered
      assert_includes timeline, 'Interactive Timeline'
      
      # Test rationale partial
      render 'campaign_plans/partials/strategic_rationale', campaign_plan: @campaign_plan
      rationale = rendered
      assert_includes rationale, 'Strategic Rationale'
    end

    test "partials handle isolation correctly" do
      # Each partial should work independently
      minimal_plan = CampaignPlan.new(
        name: 'Test',
        campaign_type: 'awareness',
        objective: 'awareness'
      )
      
      # Should not raise errors even with minimal data
      assert_nothing_raised do
        render 'campaign_plans/partials/strategic_overview', campaign_plan: minimal_plan
        render 'campaign_plans/partials/content_map', campaign_plan: minimal_plan
        render 'campaign_plans/partials/creative_approach', campaign_plan: minimal_plan
        render 'campaign_plans/partials/timeline_visualization', campaign_plan: minimal_plan
        render 'campaign_plans/partials/strategic_rationale', campaign_plan: minimal_plan
      end
    end

    test "partials maintain consistent styling" do
      @campaign_plan.generated_strategy = { 'channels' => ['Test'] }
      
      # All partials should use consistent styling patterns
      partials = [
        'strategic_overview', 'content_map', 'creative_approach', 
        'timeline_visualization', 'strategic_rationale'
      ]
      
      partials.each do |partial|
        render "campaign_plans/partials/#{partial}", campaign_plan: @campaign_plan
        rendered_partial = rendered
        
        # Check for consistent card styling
        assert_includes rendered_partial, 'bg-white rounded-lg shadow-sm border border-gray-200'
        # Check for consistent heading styling
        assert_includes rendered_partial, 'text-xl font-semibold text-gray-900'
        # Check for consistent icon usage
        assert_includes rendered_partial, 'svg'
      end
    end
  end
end