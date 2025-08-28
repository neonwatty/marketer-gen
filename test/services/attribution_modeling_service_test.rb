require 'test_helper'

class AttributionModelingServiceTest < ActiveSupport::TestCase
  def setup
    @user = users(:one)
    @journey = journeys(:awareness_journey)
    
    # Create touchpoints for testing
    @touchpoint1 = Touchpoint.create!(
      user: @user,
      journey: @journey,
      channel: 'email',
      touchpoint_type: 'click',
      occurred_at: 5.days.ago
    )
    
    @touchpoint2 = Touchpoint.create!(
      user: @user,
      journey: @journey,
      channel: 'social_media',
      touchpoint_type: 'engagement',
      occurred_at: 3.days.ago
    )
    
    @touchpoint3 = Touchpoint.create!(
      user: @user,
      journey: @journey,
      channel: 'website',
      touchpoint_type: 'conversion',
      occurred_at: 1.day.ago,
      metadata: { 'conversion_value' => 150 }
    )
    
    @service = AttributionModelingService.new(@journey)
  end

  test "should initialize with journey and touchpoints" do
    assert_equal @journey, @service.journey
    assert_equal 3, @service.touchpoints.count
    assert_equal 1, @service.conversions.count
  end

  test "generate_attribution_models should create models for each type" do
    models = @service.generate_attribution_models(['linear', 'first_touch'])
    
    assert_includes models.keys, 'linear'
    assert_includes models.keys, 'first_touch'
    assert models['linear'].all? { |model| model.is_a?(AttributionModel) }
    assert models['first_touch'].all? { |model| model.is_a?(AttributionModel) }
  end

  test "should return empty hash when no conversions exist" do
    # Remove conversion touchpoint
    @touchpoint3.destroy
    
    models = @service.generate_attribution_models(['linear'])
    assert_equal({}, models)
  end

  # First Touch Attribution Tests
  test "first_touch_attribution should give 100% to first touchpoint" do
    percentage1 = @service.calculate_attribution_for_touchpoint(@touchpoint1, 'first_touch')
    percentage2 = @service.calculate_attribution_for_touchpoint(@touchpoint2, 'first_touch')
    percentage3 = @service.calculate_attribution_for_touchpoint(@touchpoint3, 'first_touch')
    
    assert_equal 100.0, percentage1
    assert_equal 0.0, percentage2
    assert_equal 0.0, percentage3
  end

  # Last Touch Attribution Tests
  test "last_touch_attribution should give 100% to last touchpoint before conversion" do
    percentage1 = @service.calculate_attribution_for_touchpoint(@touchpoint1, 'last_touch')
    percentage2 = @service.calculate_attribution_for_touchpoint(@touchpoint2, 'last_touch')
    percentage3 = @service.calculate_attribution_for_touchpoint(@touchpoint3, 'last_touch')
    
    assert_equal 0.0, percentage1
    assert_equal 100.0, percentage2
    assert_equal 0.0, percentage3
  end

  # Linear Attribution Tests
  test "linear_attribution should distribute equally among all touchpoints" do
    percentage1 = @service.calculate_attribution_for_touchpoint(@touchpoint1, 'linear')
    percentage2 = @service.calculate_attribution_for_touchpoint(@touchpoint2, 'linear')
    percentage3 = @service.calculate_attribution_for_touchpoint(@touchpoint3, 'linear')
    
    expected_percentage = (100.0 / 3).round(2)
    assert_equal expected_percentage, percentage1
    assert_equal expected_percentage, percentage2
    assert_equal expected_percentage, percentage3
  end

  # Time Decay Attribution Tests
  test "time_decay_attribution should give more credit to recent touchpoints" do
    percentage1 = @service.calculate_attribution_for_touchpoint(@touchpoint1, 'time_decay')
    percentage2 = @service.calculate_attribution_for_touchpoint(@touchpoint2, 'time_decay')
    percentage3 = @service.calculate_attribution_for_touchpoint(@touchpoint3, 'time_decay')
    
    # More recent touchpoints should get higher attribution
    assert percentage2 > percentage1, "More recent touchpoint should get higher attribution"
    assert percentage3 >= percentage2, "Conversion touchpoint should get highest attribution"
    
    # All percentages should sum to approximately 100
    total = percentage1 + percentage2 + percentage3
    assert_in_delta 100.0, total, 0.1
  end

  # Position Based Attribution Tests
  test "position_based_attribution should give 40% each to first and last" do
    percentage1 = @service.calculate_attribution_for_touchpoint(@touchpoint1, 'position_based')
    percentage2 = @service.calculate_attribution_for_touchpoint(@touchpoint2, 'position_based')
    percentage3 = @service.calculate_attribution_for_touchpoint(@touchpoint3, 'position_based')
    
    assert_equal 40.0, percentage1
    assert_equal 20.0, percentage2
    assert_equal 40.0, percentage3
  end

  test "position_based_attribution with two touchpoints should split 50/50" do
    @touchpoint2.destroy # Remove middle touchpoint
    service = AttributionModelingService.new(@journey.reload)
    
    percentage1 = service.calculate_attribution_for_touchpoint(@touchpoint1, 'position_based')
    percentage3 = service.calculate_attribution_for_touchpoint(@touchpoint3, 'position_based')
    
    assert_equal 50.0, percentage1
    assert_equal 50.0, percentage3
  end

  test "position_based_attribution with one touchpoint should give 100%" do
    @touchpoint1.destroy
    @touchpoint2.destroy
    service = AttributionModelingService.new(@journey.reload)
    
    percentage3 = service.calculate_attribution_for_touchpoint(@touchpoint3, 'position_based')
    assert_equal 100.0, percentage3
  end

  # Data Driven Attribution Tests
  test "data_driven_attribution should consider multiple factors" do
    percentage = @service.calculate_attribution_for_touchpoint(@touchpoint1, 'data_driven')
    
    assert percentage > 0
    assert percentage <= 100
  end

  # Custom Attribution Tests  
  test "custom_attribution should apply business rule multipliers" do
    # Test conversion touchpoint gets boost
    conversion_percentage = @service.calculate_attribution_for_touchpoint(@touchpoint3, 'custom')
    linear_percentage = @service.calculate_attribution_for_touchpoint(@touchpoint3, 'linear')
    
    assert conversion_percentage > linear_percentage, "Conversion touchpoints should get boosted attribution"
  end

  # Channel Effectiveness Analysis Tests
  test "channel_effectiveness_analysis should return analysis for all channels" do
    analysis = @service.channel_effectiveness_analysis
    
    assert_includes analysis.keys, 'email'
    assert_includes analysis.keys, 'social_media' 
    assert_includes analysis.keys, 'website'
    
    analysis.each do |channel, stats|
      assert_includes stats.keys, :touchpoint_count
      assert_includes stats.keys, :conversion_count
      assert_includes stats.keys, :conversion_rate
      assert_includes stats.keys, :total_attribution_value
      assert_includes stats.keys, :roi_score
    end
  end

  test "channel_effectiveness_analysis should return empty hash with no touchpoints" do
    @touchpoint1.destroy
    @touchpoint2.destroy
    @touchpoint3.destroy
    
    service = AttributionModelingService.new(@journey.reload)
    analysis = service.channel_effectiveness_analysis
    
    assert_equal({}, analysis)
  end

  # Journey Attribution Summary Tests
  test "journey_attribution_summary should summarize all models" do
    # First generate some attribution models
    @service.generate_attribution_models(['linear', 'first_touch'])
    
    summary = @service.journey_attribution_summary
    
    assert_includes summary.keys, 'linear'
    assert_includes summary.keys, 'first_touch'
    
    summary.each do |model_type, data|
      assert_includes data.keys, :total_conversion_value
      assert_includes data.keys, :channel_attribution
      assert_includes data.keys, :model_confidence
      assert_includes data.keys, :touchpoints_attributed
    end
  end

  test "journey_attribution_summary should return empty hash with no conversions" do
    @touchpoint3.destroy # Remove conversion
    
    service = AttributionModelingService.new(@journey.reload)
    summary = service.journey_attribution_summary
    
    assert_equal({}, summary)
  end

  # Model Comparison Tests
  test "compare_attribution_models should compare models across channels" do
    @service.generate_attribution_models(['linear', 'first_touch', 'last_touch'])
    
    comparison = @service.compare_attribution_models
    
    assert_includes comparison.keys, :channel_comparison
    assert_includes comparison.keys, :model_summary
    assert_includes comparison.keys, :recommendations
    
    # Check channel comparison structure
    channel_comparison = comparison[:channel_comparison]
    assert_includes channel_comparison.keys, 'email'
    
    channel_comparison.each do |channel, models|
      models.each do |model_type, data|
        assert_includes data.keys, :attribution_credit
        assert_includes data.keys, :percentage
      end
    end
  end

  # Multi-touch Attribution Tests
  test "calculate_multi_touch_attribution should combine time decay and position" do
    attributions = @service.calculate_multi_touch_attribution
    
    assert_equal 3, attributions.count
    assert attributions.all? { |attr| attr.key?(:touchpoint) }
    assert attributions.all? { |attr| attr.key?(:attribution_percentage) }
    assert attributions.all? { |attr| attr.key?(:time_weight) }
    assert attributions.all? { |attr| attr.key?(:position_weight) }
    
    # Total attribution should sum to approximately 100%
    total_attribution = attributions.sum { |attr| attr[:attribution_percentage] }
    assert_in_delta 100.0, total_attribution, 1.0
  end

  test "calculate_multi_touch_attribution should return empty array with no touchpoints" do
    @touchpoint1.destroy
    @touchpoint2.destroy
    @touchpoint3.destroy
    
    service = AttributionModelingService.new(@journey.reload)
    attributions = service.calculate_multi_touch_attribution
    
    assert_equal [], attributions
  end

  # Edge Case Tests
  test "should handle journey with single touchpoint" do
    @touchpoint1.destroy
    @touchpoint2.destroy
    
    service = AttributionModelingService.new(@journey.reload)
    
    percentage = service.calculate_attribution_for_touchpoint(@touchpoint3, 'linear')
    assert_equal 100.0, percentage
    
    percentage = service.calculate_attribution_for_touchpoint(@touchpoint3, 'first_touch')  
    assert_equal 100.0, percentage
    
    percentage = service.calculate_attribution_for_touchpoint(@touchpoint3, 'last_touch')
    assert_equal 100.0, percentage
  end

  test "should handle journey with no touchpoints" do
    @touchpoint1.destroy
    @touchpoint2.destroy 
    @touchpoint3.destroy
    
    service = AttributionModelingService.new(@journey.reload)
    
    assert_equal 0, service.touchpoints.count
    assert_equal 0, service.conversions.count
    
    models = service.generate_attribution_models(['linear'])
    assert_equal({}, models)
  end

  # Private Method Tests (testing through public interface)
  test "should calculate conversion value from touchpoint metadata" do
    # Create attribution models to trigger private method usage
    models = @service.generate_attribution_models(['linear'])
    
    linear_models = models['linear']
    conversion_model = linear_models.find { |model| model.touchpoint == @touchpoint3 }
    
    # Should use the conversion value from touchpoint metadata
    assert_equal 150, conversion_model.conversion_value
  end

  test "should use default conversion value when not provided" do
    @touchpoint3.update!(metadata: {})
    
    service = AttributionModelingService.new(@journey.reload)
    models = service.generate_attribution_models(['linear'])
    
    linear_models = models['linear']
    conversion_model = linear_models.find { |model| model.touchpoint == @touchpoint3 }
    
    assert_equal 100, conversion_model.conversion_value
  end

  test "should build calculation metadata" do
    models = @service.generate_attribution_models(['linear'])
    
    model = models['linear'].first
    metadata = model.calculation_metadata
    
    assert_includes metadata.keys, 'calculation_timestamp'
    assert_includes metadata.keys, 'model_type'
    assert_includes metadata.keys, 'touchpoint_id'
    assert_includes metadata.keys, 'journey_id'
    assert_includes metadata.keys, 'total_touchpoints'
    assert_includes metadata.keys, 'touchpoint_position'
    assert_includes metadata.keys, 'conversion_count'
    assert_includes metadata.keys, 'algorithm_version'
    
    assert_equal 'linear', metadata['model_type']
    assert_equal @journey.id, metadata['journey_id']
    assert_equal 3, metadata['total_touchpoints']
    assert_equal 1, metadata['conversion_count']
    assert_equal '1.0', metadata['algorithm_version']
  end
end