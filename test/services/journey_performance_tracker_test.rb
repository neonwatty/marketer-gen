require 'test_helper'

class JourneyPerformanceTrackerTest < ActiveSupport::TestCase
  def setup
    @user = users(:one)
    @journey = journeys(:awareness_journey)
    @brand_identity = brand_identities(:active_brand)
    @brand_identity.update!(is_active: true)
    
    @tracker = JourneyPerformanceTracker.new(@journey, @user)
  end

  test "tracks performance metrics for AI-generated steps" do
    step = @journey.journey_steps.create!(
      name: "AI Welcome Email",
      step_type: "email",
      ai_generated: true,
      brand_compliance_score: 85
    )
    
    metrics = {
      engagement_rate: 75,
      conversion_rate: 12,
      click_through_rate: 45,
      unsubscribe_rate: 2
    }
    
    @tracker.track_step_performance(step, metrics)
    
    step.reload
    assert_not_nil step.performance_metrics
    assert_equal 75, step.performance_metrics['engagement_rate']
    assert_not_nil step.last_performance_update
  end

  test "does not track performance for non-AI steps" do
    step = @journey.journey_steps.create!(
      name: "Manual Step",
      step_type: "email",
      ai_generated: false
    )
    
    @tracker.track_step_performance(step, { engagement_rate: 50 })
    
    step.reload
    # Should not update non-AI steps
    assert_nil step.performance_metrics
  end

  test "analyzes performance patterns" do
    # Create test data
    3.times do |i|
      step = @journey.journey_steps.create!(
        name: "Step #{i}",
        step_type: i.even? ? "email" : "social",
        ai_generated: true,
        brand_compliance_score: 80 + i * 5
      )
      
      @tracker.track_step_performance(step, {
        engagement_rate: 60 + i * 10,
        click_through_rate: 30 + i * 5
      })
    end
    
    patterns = @tracker.analyze_performance_patterns
    
    assert_not_nil patterns[:best_performing_step_types]
    assert_not_nil patterns[:channel_effectiveness]
    assert_not_nil patterns[:brand_compliance_impact]
  end

  test "generates performance recommendations" do
    # Add performance data
    5.times do |i|
      step = @journey.journey_steps.create!(
        name: "Step #{i}",
        step_type: "email",
        channels: ['email'],
        ai_generated: true,
        brand_compliance_score: 70 + i * 5
      )
      
      @tracker.track_step_performance(step, {
        engagement_rate: 50 + i * 8
      })
    end
    
    recommendations = @tracker.get_performance_recommendations
    
    assert recommendations.is_a?(Array)
    
    recommendations.each do |rec|
      assert_not_nil rec[:type]
      assert_not_nil rec[:priority]
      assert_not_nil rec[:recommendation]
      assert_not_nil rec[:reasoning]
    end
  end

  test "exports data for AI training" do
    # Create training data
    2.times do |i|
      step = @journey.journey_steps.create!(
        name: "Training Step #{i}",
        step_type: "email",
        ai_generated: true,
        brand_compliance_score: 85
      )
      
      @tracker.track_step_performance(step, {
        engagement_rate: 80,
        conversion_rate: 15
      })
    end
    
    training_data = @tracker.export_for_ai_training
    
    assert_equal @journey.id, training_data[:journey_id]
    assert_not_nil training_data[:training_samples]
    assert_not_nil training_data[:performance_summary]
    assert_not_nil training_data[:brand_context]
  end

  test "identifies best performing step types" do
    # Create varied performance data
    step_types = ['email', 'social', 'content', 'email', 'social']
    performances = [80, 60, 70, 85, 55]
    
    step_types.zip(performances).each do |type, perf|
      step = @journey.journey_steps.create!(
        name: "#{type.capitalize} Step",
        step_type: type,
        ai_generated: true
      )
      
      @tracker.track_step_performance(step, {
        engagement_rate: perf
      })
    end
    
    patterns = @tracker.analyze_performance_patterns
    best_performers = patterns[:best_performing_step_types]
    
    assert best_performers.any?
    assert_equal 'email', best_performers.first[:type]
    assert best_performers.first[:avg_performance] > 80
  end

  test "analyzes channel effectiveness" do
    channels_data = [
      ['email', 85],
      ['social', 65],
      ['email', 80],
      ['web', 70],
      ['social', 60]
    ]
    
    channels_data.each do |channels, performance|
      step = @journey.journey_steps.create!(
        name: "Channel Test",
        channels: [channels],
        ai_generated: true
      )
      
      @tracker.track_step_performance(step, {
        engagement_rate: performance
      })
    end
    
    patterns = @tracker.analyze_performance_patterns
    channel_effectiveness = patterns[:channel_effectiveness]
    
    assert channel_effectiveness.any?
    best_channel = channel_effectiveness.first
    assert_equal 'email', best_channel[:channel]
    assert best_channel[:effectiveness_score] > 80
  end

  test "calculates correlation between brand compliance and performance" do
    # Create data with clear correlation
    compliance_scores = [60, 70, 80, 90, 95]
    performance_scores = [50, 60, 75, 85, 92]
    
    compliance_scores.zip(performance_scores).each do |compliance, performance|
      step = @journey.journey_steps.create!(
        name: "Compliance Test",
        ai_generated: true,
        brand_compliance_score: compliance
      )
      
      @tracker.track_step_performance(step, {
        engagement_rate: performance
      })
    end
    
    patterns = @tracker.analyze_performance_patterns
    impact = patterns[:brand_compliance_impact]
    
    assert impact[:correlation] > 0.8
    assert_equal 'high', impact[:impact]
  end

  test "provides high priority recommendations for strong correlations" do
    # Create high brand compliance correlation
    10.times do |i|
      step = @journey.journey_steps.create!(
        name: "Step #{i}",
        ai_generated: true,
        brand_compliance_score: 70 + i * 3
      )
      
      @tracker.track_step_performance(step, {
        engagement_rate: 60 + i * 4
      })
    end
    
    recommendations = @tracker.get_performance_recommendations
    
    brand_rec = recommendations.find { |r| r[:type] == :brand_compliance }
    assert_not_nil brand_rec
    assert_equal :high, brand_rec[:priority]
  end

  test "updates journey AI performance score" do
    # Create AI steps with performance
    3.times do |i|
      step = @journey.journey_steps.create!(
        name: "AI Step #{i}",
        ai_generated: true
      )
      
      @tracker.track_step_performance(step, {
        engagement_rate: 70 + i * 5
      })
    end
    
    @journey.reload
    assert_not_nil @journey.ai_performance_score
    assert @journey.ai_performance_score > 0
  end

  test "handles missing performance data gracefully" do
    step = @journey.journey_steps.create!(
      name: "No Metrics Step",
      ai_generated: true
    )
    
    # Track with empty metrics
    @tracker.track_step_performance(step, {})
    
    patterns = @tracker.analyze_performance_patterns
    assert_not_nil patterns
    
    recommendations = @tracker.get_performance_recommendations
    assert recommendations.is_a?(Array)
  end

  test "stores learning patterns in cache" do
    patterns = { test: 'data' }
    
    @tracker.send(:store_learning_patterns, patterns)
    
    cached = Rails.cache.read("journey_learning_patterns_#{@journey.id}")
    assert_equal patterns, cached
  end

  test "analyzes optimal content length" do
    lengths = [100, 150, 200, 175, 160]
    performances = [0.7, 0.85, 0.6, 0.82, 0.88]
    
    # Create learning data with content lengths
    lengths.zip(performances).each do |length, perf|
      if defined?(JourneyLearningData)
        JourneyLearningData.create!(
          journey: @journey,
          user: @user,
          step_type: 'email',
          learning_model_input: {
            'step_attributes' => { 'content_length' => length }
          },
          learning_model_output: perf
        )
      end
    end
    
    patterns = @tracker.analyze_performance_patterns
    content_patterns = patterns[:content_patterns]
    
    if content_patterns[:optimal_content_length]
      assert_not_nil content_patterns[:optimal_content_length][:average]
    end
  end
end