require 'test_helper'

class AttributionModelTest < ActiveSupport::TestCase
  def setup
    @user = users(:one)
    @journey = journeys(:awareness_journey)
    @touchpoint = Touchpoint.create!(
      user: @user,
      journey: @journey,
      channel: 'email',
      touchpoint_type: 'click',
      occurred_at: 2.hours.ago
    )
    
    @attribution_model = AttributionModel.new(
      user: @user,
      journey: @journey,
      touchpoint: @touchpoint,
      model_type: 'linear',
      attribution_percentage: 25.0,
      conversion_value: 100.0,
      confidence_score: 0.8
    )
  end

  test "should be valid with valid attributes" do
    assert @attribution_model.valid?
  end

  test "should require model_type" do
    @attribution_model.model_type = nil
    assert_not @attribution_model.valid?
    assert_includes @attribution_model.errors[:model_type], "can't be blank"
  end

  test "should validate model_type inclusion" do
    @attribution_model.model_type = 'invalid_type'
    assert_not @attribution_model.valid?
    assert_includes @attribution_model.errors[:model_type], "is not included in the list"
  end

  test "should require attribution_percentage" do
    # Skip the callback that would set attribution_percentage automatically
    @attribution_model.attribution_percentage = nil
    @attribution_model.define_singleton_method(:calculate_attribution_percentage) { nil }
    assert_not @attribution_model.valid?
    assert_includes @attribution_model.errors[:attribution_percentage], "can't be blank"
  end

  test "should validate attribution_percentage range" do
    @attribution_model.attribution_percentage = 0
    assert_not @attribution_model.valid?
    assert_includes @attribution_model.errors[:attribution_percentage], "must be greater than 0"
    
    @attribution_model.attribution_percentage = 150
    assert_not @attribution_model.valid?
    assert_includes @attribution_model.errors[:attribution_percentage], "must be less than or equal to 100"
  end

  test "should validate conversion_value numericality" do
    @attribution_model.conversion_value = -10
    assert_not @attribution_model.valid?
    assert_includes @attribution_model.errors[:conversion_value], "must be greater than or equal to 0"
  end

  test "should validate confidence_score range" do
    @attribution_model.confidence_score = 1.5
    assert_not @attribution_model.valid?
    assert_includes @attribution_model.errors[:confidence_score], "must be in 0.0..1.0"
    
    @attribution_model.confidence_score = -0.1
    assert_not @attribution_model.valid?
    assert_includes @attribution_model.errors[:confidence_score], "must be in 0.0..1.0"
  end

  test "attribution_credit should calculate correctly" do
    expected_credit = (@attribution_model.conversion_value * @attribution_model.attribution_percentage / 100.0).round(2)
    assert_equal expected_credit, @attribution_model.attribution_credit
  end

  test "attribution_credit should return 0 when conversion_value is nil" do
    @attribution_model.conversion_value = nil
    assert_equal 0, @attribution_model.attribution_credit
  end

  test "weighted_attribution_score should calculate correctly" do
    # Mock touchpoint attribution score
    @touchpoint.stubs(:channel_attribution_score).returns(0.8)
    
    expected_score = ((@attribution_model.attribution_percentage / 100.0) * 
                     @attribution_model.confidence_score * 
                     @touchpoint.channel_attribution_score).round(4)
    
    assert_equal expected_score, @attribution_model.weighted_attribution_score
  end

  test "should delegate channel_name to touchpoint" do
    assert_equal @touchpoint.channel, @attribution_model.channel_name
  end

  test "should delegate touchpoint_type to touchpoint" do  
    assert_equal @touchpoint.touchpoint_type, @attribution_model.touchpoint_type
  end

  test "should delegate touchpoint_timestamp to touchpoint" do
    assert_equal @touchpoint.occurred_at, @attribution_model.touchpoint_timestamp
  end

  test "time_to_conversion should calculate correctly" do
    # Create a conversion touchpoint
    conversion_touchpoint = Touchpoint.create!(
      user: @user,
      journey: @journey,
      channel: 'website',
      touchpoint_type: 'conversion',
      occurred_at: 2.hours.from_now
    )
    
    time_diff = @attribution_model.time_to_conversion
    assert_not_nil time_diff
    assert time_diff > 0
  end

  test "time_to_conversion should return nil without conversions" do
    assert_nil @attribution_model.time_to_conversion
  end

  test "attribution_analysis should return complete analysis" do
    analysis = @attribution_model.attribution_analysis
    
    expected_keys = [
      :model_type, :attribution_percentage, :attribution_credit, :confidence_score,
      :weighted_score, :channel, :touchpoint_type, :journey_position, 
      :time_to_conversion, :calculation_metadata
    ]
    
    expected_keys.each do |key|
      assert_includes analysis.keys, key, "Missing key: #{key}"
    end
  end

  test "aggregate_by_channel should group attributions correctly" do
    # Create multiple attribution models
    attribution1 = AttributionModel.create!(
      user: @user,
      journey: @journey,
      touchpoint: @touchpoint,
      model_type: 'linear',
      attribution_percentage: 25.0,
      conversion_value: 100.0,
      confidence_score: 0.8
    )
    
    touchpoint2 = Touchpoint.create!(
      user: @user,
      journey: @journey,
      channel: 'social_media',
      touchpoint_type: 'click',
      occurred_at: 1.hour.ago
    )
    
    attribution2 = AttributionModel.create!(
      user: @user,
      journey: @journey,
      touchpoint: touchpoint2,
      model_type: 'linear',
      attribution_percentage: 25.0,
      conversion_value: 100.0,
      confidence_score: 0.7
    )
    
    aggregated = AttributionModel.aggregate_by_channel([attribution1, attribution2])
    
    assert_includes aggregated.keys, @touchpoint.channel
    assert_includes aggregated.keys, touchpoint2.channel
    assert_includes aggregated[@touchpoint.channel].keys, :total_credit
    assert_includes aggregated[@touchpoint.channel].keys, :average_percentage
  end

  test "model_comparison should compare models for journey" do
    # Create attributions for different model types
    AttributionModel.create!(
      user: @user,
      journey: @journey,
      touchpoint: @touchpoint,
      model_type: 'first_touch',
      attribution_percentage: 100.0,
      conversion_value: 100.0,
      confidence_score: 0.9
    )
    
    AttributionModel.create!(
      user: @user,
      journey: @journey,
      touchpoint: @touchpoint,
      model_type: 'last_touch',
      attribution_percentage: 100.0,
      conversion_value: 100.0,
      confidence_score: 0.85
    )
    
    comparison = AttributionModel.model_comparison(@journey.id)
    assert comparison.any?
    
    comparison.each do |model_data|
      assert_includes model_data.keys, :model_type
      assert_includes model_data.keys, :total_credit
      assert_includes model_data.keys, :channel_distribution
    end
  end

  # Scope tests
  test "by_model_type scope should filter correctly" do
    @attribution_model.save!
    
    linear_models = AttributionModel.by_model_type('linear')
    assert_includes linear_models, @attribution_model
  end

  test "by_journey scope should filter correctly" do
    @attribution_model.save!
    
    journey_models = AttributionModel.by_journey(@journey.id)
    assert_includes journey_models, @attribution_model
  end

  test "high_confidence scope should filter correctly" do
    @attribution_model.save!
    
    high_confidence = AttributionModel.high_confidence
    assert_includes high_confidence, @attribution_model
    
    @attribution_model.update!(confidence_score: 0.5)
    high_confidence = AttributionModel.high_confidence
    assert_not_includes high_confidence, @attribution_model.reload
  end

  test "with_conversion_value scope should filter correctly" do
    @attribution_model.save!
    
    with_value = AttributionModel.with_conversion_value
    assert_includes with_value, @attribution_model
    
    @attribution_model.update!(conversion_value: nil)
    with_value = AttributionModel.with_conversion_value
    assert_not_includes with_value, @attribution_model.reload
  end

  test "should serialize calculation_metadata and algorithm_parameters" do
    metadata = { 'calculation_time' => Time.current.to_s, 'version' => '1.0' }
    parameters = { 'decay_rate' => 0.7, 'position_weights' => { 'first' => 0.4 } }
    
    @attribution_model.calculation_metadata = metadata
    @attribution_model.algorithm_parameters = parameters
    @attribution_model.save!
    
    @attribution_model.reload
    assert_equal metadata, @attribution_model.calculation_metadata
    assert_equal parameters, @attribution_model.algorithm_parameters
  end

  test "should calculate attribution percentage on create if not provided" do
    attribution_without_percentage = AttributionModel.new(
      user: @user,
      journey: @journey, 
      touchpoint: @touchpoint,
      model_type: 'linear',
      conversion_value: 100.0
    )
    
    # Mock the service call
    service_mock = mock('AttributionModelingService')
    service_mock.expects(:calculate_attribution_for_touchpoint).returns(33.33)
    AttributionModelingService.expects(:new).returns(service_mock)
    
    attribution_without_percentage.save!
    assert_not_nil attribution_without_percentage.attribution_percentage
  end

  test "should set confidence score on create if not provided" do
    attribution_without_confidence = AttributionModel.new(
      user: @user,
      journey: @journey,
      touchpoint: @touchpoint,
      model_type: 'linear',
      attribution_percentage: 25.0,
      conversion_value: 100.0
    )
    
    # Mock touchpoint methods
    @touchpoint.stubs(:channel_attribution_score).returns(0.8)
    @touchpoint.stubs(:journey_position).returns(2)
    @touchpoint.stubs(:time_since_previous_touchpoint).returns(1.5)
    
    attribution_without_confidence.save!
    assert_not_nil attribution_without_confidence.confidence_score
    assert attribution_without_confidence.confidence_score.between?(0, 1)
  end
end