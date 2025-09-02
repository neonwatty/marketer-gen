require 'test_helper'

class JourneyBrandContextBuilderTest < ActiveSupport::TestCase
  def setup
    @user = users(:one)
    @journey = journeys(:awareness_journey)
    @brand_identity = brand_identities(:active_brand)
    @brand_identity.update!(is_active: true)
    
    @builder = JourneyBrandContextBuilder.new(@journey, @user)
  end

  test "builds complete context with brand identity" do
    context = @builder.build_complete_context
    
    assert_not_nil context[:brand]
    assert_not_nil context[:brand_assets]
    assert_not_nil context[:journey]
    assert_not_nil context[:historical_performance]
  end

  test "builds brand context with all required fields" do
    context = @builder.send(:build_brand_context)
    
    assert_equal @brand_identity.id, context[:id]
    assert_equal @brand_identity.company_name, context[:name]
    assert_not_nil context[:voice]
    assert_not_nil context[:tone_guidelines]
    assert_not_nil context[:messaging_framework]
    assert_not_nil context[:core_values]
    assert_not_nil context[:unique_selling_points]
    assert_not_nil context[:restrictions]
  end

  test "builds brand assets context" do
    # Add some brand assets
    @brand_identity.brand_assets.create!(
      asset_type: 'logo',
      file_url: 'https://example.com/logo.png',
      metadata: { primary: true }
    )
    
    context = @builder.send(:build_brand_assets_context)
    
    assert_not_nil context[:logos]
    assert_not_nil context[:color_palette]
    assert_not_nil context[:typography]
    assert_not_nil context[:visual_style]
  end

  test "builds journey context with existing steps" do
    # Add journey steps
    @journey.journey_steps.create!(
      name: "Welcome Email",
      step_type: "email",
      sequence_order: 0
    )
    @journey.journey_steps.create!(
      name: "Follow-up",
      step_type: "email",
      sequence_order: 1
    )
    
    context = @builder.send(:build_journey_context)
    
    assert_equal @journey.campaign_type, context[:campaign_type]
    assert_equal @journey.target_audience, context[:target_audience]
    assert_equal 2, context[:existing_steps].length
    assert_equal @journey.stages, context[:stages]
  end

  test "builds performance context from historical data" do
    # Add some performance data
    @journey.journey_steps.create!(
      name: "Test Step",
      step_type: "email",
      ai_generated: true,
      performance_metrics: {
        engagement_rate: 75,
        click_through_rate: 45
      }
    )
    
    context = @builder.send(:build_performance_context)
    
    assert_not_nil context[:average_engagement]
    assert_not_nil context[:best_performing_channels]
    assert_not_nil context[:optimal_timing]
  end

  test "builds generic context when no brand identity" do
    BrandIdentity.where(user: @user).update_all(is_active: false)
    builder = JourneyBrandContextBuilder.new(@journey, @user)
    
    context = builder.build_complete_context
    
    assert_nil context[:brand]
    assert_not_nil context[:journey]
    assert_equal "No specific brand identity", context[:generic_context]
  end

  test "includes brand variants context when adaptations exist" do
    # Create brand adaptation
    @brand_identity.brand_adaptations.create!(
      name: "Holiday Campaign",
      tone_adjustments: { festive: true },
      is_active: true
    )
    
    context = @builder.send(:build_brand_variants_context)
    
    assert_not_nil context[:active_adaptations]
    assert context[:active_adaptations].any?
  end

  test "builds industry context" do
    @brand_identity.update!(industry: 'technology')
    
    context = @builder.send(:build_industry_context)
    
    assert_equal 'technology', context[:industry]
    assert_not_nil context[:industry_best_practices]
    assert_not_nil context[:compliance_requirements]
  end

  test "calculates average engagement from performance metrics" do
    steps = [
      @journey.journey_steps.create!(
        name: "Step 1",
        performance_metrics: { engagement_rate: 80 }
      ),
      @journey.journey_steps.create!(
        name: "Step 2",
        performance_metrics: { engagement_rate: 60 }
      )
    ]
    
    avg = @builder.send(:calculate_average_engagement, steps)
    
    assert_equal 70, avg
  end

  test "identifies best performing channels" do
    steps = [
      @journey.journey_steps.create!(
        name: "Email 1",
        channels: ['email'],
        performance_metrics: { engagement_rate: 80 }
      ),
      @journey.journey_steps.create!(
        name: "Social 1",
        channels: ['social'],
        performance_metrics: { engagement_rate: 60 }
      ),
      @journey.journey_steps.create!(
        name: "Email 2",
        channels: ['email'],
        performance_metrics: { engagement_rate: 75 }
      )
    ]
    
    channels = @builder.send(:identify_best_performing_channels, steps)
    
    assert_equal 'email', channels.first[:channel]
    assert_equal 77.5, channels.first[:avg_performance]
  end

  test "determines optimal timing patterns" do
    steps = [
      @journey.journey_steps.create!(
        name: "Morning Email",
        timing_trigger_type: 'time_based',
        performance_metrics: { engagement_rate: 85 }
      ),
      @journey.journey_steps.create!(
        name: "Immediate",
        timing_trigger_type: 'immediate',
        performance_metrics: { engagement_rate: 60 }
      )
    ]
    
    timing = @builder.send(:determine_optimal_timing, steps)
    
    assert_not_nil timing[:best_timing]
    assert_equal 'time_based', timing[:best_timing]
  end

  test "handles missing metadata gracefully" do
    # Brand identity with minimal data
    minimal_brand = BrandIdentity.create!(
      user: @user,
      company_name: "Test Company"
    )
    minimal_brand.update!(is_active: true)
    
    builder = JourneyBrandContextBuilder.new(@journey, @user)
    context = builder.build_complete_context
    
    assert_not_nil context
    assert_not_nil context[:brand]
    assert_equal "Test Company", context[:brand][:name]
  end

  test "includes competitor analysis when available" do
    @brand_identity.update!(
      metadata: {
        competitors: ['Competitor A', 'Competitor B'],
        competitive_advantages: ['Better pricing', 'Superior support']
      }
    )
    
    context = @builder.build_complete_context
    
    assert_not_nil context[:brand][:competitive_positioning]
  end

  test "extracts messaging framework from brand identity" do
    @brand_identity.update!(
      key_messages: ['Innovation', 'Reliability', 'Customer-first']
    )
    
    context = @builder.send(:build_brand_context)
    
    assert_equal @brand_identity.key_messages, context[:messaging_framework]
  end

  test "formats context for LLM consumption" do
    context = @builder.build_complete_context
    formatted = @builder.format_for_llm
    
    assert formatted.is_a?(String)
    assert formatted.include?(@brand_identity.company_name) if @brand_identity
    assert formatted.include?(@journey.campaign_type)
  end
end