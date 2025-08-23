require "test_helper"

class ContentAbTestResultTest < ActiveSupport::TestCase
  fixtures :users, :campaign_plans, :generated_contents

  def setup
    @user = users(:marketer_user)
    @campaign_plan = campaign_plans(:draft_plan)
    
    # Create control content that belongs to the same campaign
    @control_content = GeneratedContent.create!(
      title: 'Control Email Subject',
      body_content: 'This is a control email subject line designed to test effectiveness in our email marketing campaign. It provides a baseline for comparison against other variants.',
      content_type: 'email',
      format_variant: 'standard',
      campaign_plan: @campaign_plan,
      created_by: @user
    )
    
    # Create variant content that belongs to the same campaign
    @variant_content = GeneratedContent.create!(
      title: 'Variant Email Subject',
      body_content: 'This is a variant email subject line designed to test effectiveness in our email marketing campaign. It aims to improve performance over the control version.',
      content_type: 'email',
      format_variant: 'standard',
      campaign_plan: @campaign_plan,
      created_by: @user
    )
    
    @ab_test = ContentAbTest.create!(
      test_name: 'Email Subject Test',
      status: 'active',
      primary_goal: 'click_rate',
      confidence_level: '95',
      traffic_allocation: 100,
      minimum_sample_size: 100,
      test_duration_days: 14,
      start_date: 1.day.from_now, # Future date to avoid validation issues
      campaign_plan: @campaign_plan,
      created_by: @user,
      control_content: @control_content
    )
    
    @variant = ContentAbTestVariant.create!(
      content_ab_test: @ab_test,
      generated_content: @variant_content,
      variant_name: 'Variant A',
      status: 'active',
      traffic_split: 50.0,
      sample_size: 0
    )
    
    @result = ContentAbTestResult.new(
      content_ab_test_variant: @variant,
      metric_name: 'click_rate',
      metric_value: 2.5,
      sample_size: 100,
      recorded_date: Date.current,
      data_source: 'google_analytics'
    )
  end

  # Basic validation tests
  test "should be valid with valid attributes" do
    assert @result.valid?, "Result should be valid: #{@result.errors.full_messages}"
  end

  test "should require metric_name" do
    @result.metric_name = nil
    assert_not @result.valid?
    assert_includes @result.errors[:metric_name], "can't be blank"
  end

  test "should require metric_value" do
    @result.metric_value = nil
    assert_not @result.valid?
    assert_includes @result.errors[:metric_value], "can't be blank"
  end

  test "should require sample_size" do
    @result.sample_size = nil
    assert_not @result.valid?
    assert_includes @result.errors[:sample_size], "can't be blank"
  end

  test "should require recorded_date" do
    @result.recorded_date = nil
    assert_not @result.valid?
    assert_includes @result.errors[:recorded_date], "can't be blank"
  end

  test "should validate metric_name inclusion" do
    @result.metric_name = 'invalid_metric'
    assert_not @result.valid?
    assert_includes @result.errors[:metric_name], "is not included in the list"
  end

  test "should validate data_source inclusion when present" do
    @result.data_source = 'invalid_source'
    assert_not @result.valid?
    assert_includes @result.errors[:data_source], "is not included in the list"
  end

  test "should validate sample_size is positive" do
    @result.sample_size = 0
    assert_not @result.valid?
    assert_includes @result.errors[:sample_size], "must be greater than 0"
    
    @result.sample_size = -10
    assert_not @result.valid?
    assert_includes @result.errors[:sample_size], "must be greater than 0"
  end

  test "should not allow recorded_date in future" do
    @result.recorded_date = 1.day.from_now.to_date
    assert_not @result.valid?
    assert_includes @result.errors[:recorded_date], "cannot be in the future"
  end

  test "should validate metric_value range for percentage metrics" do
    percentage_metrics = %w[click_rate conversion_rate engagement_rate open_rate response_rate bounce_rate]
    
    percentage_metrics.each do |metric|
      @result.metric_name = metric
      
      # Test invalid negative value
      @result.metric_value = -5
      assert_not @result.valid?
      assert_includes @result.errors[:metric_value], "for #{metric} should be between 0 and 100"
      
      # Test invalid value over 100
      @result.metric_value = 150
      assert_not @result.valid?
      assert_includes @result.errors[:metric_value], "for #{metric} should be between 0 and 100"
      
      # Test valid value
      @result.metric_value = 25.5
      @result.valid? # Clear previous errors
      assert_not_includes @result.errors[:metric_value], "for #{metric} should be between 0 and 100"
    end
  end

  test "should validate time_on_page metric range" do
    @result.metric_name = 'time_on_page'
    
    @result.metric_value = -10
    assert_not @result.valid?
    assert_includes @result.errors[:metric_value], "for time on page should be reasonable (0-86400 seconds)"
    
    @result.metric_value = 100000 # More than 24 hours
    assert_not @result.valid?
    assert_includes @result.errors[:metric_value], "for time on page should be reasonable (0-86400 seconds)"
    
    @result.metric_value = 300 # 5 minutes - valid
    assert @result.valid?
  end

  test "should validate revenue and cost metrics are not negative" do
    revenue_metrics = %w[revenue cost_per_click cost_per_conversion]
    
    revenue_metrics.each do |metric|
      @result.metric_name = metric
      @result.metric_value = -10
      
      assert_not @result.valid?
      assert_includes @result.errors[:metric_value], "for #{metric} cannot be negative"
      
      @result.metric_value = 15.50
      @result.valid? # Clear errors
      assert_not_includes @result.errors[:metric_value], "for #{metric} cannot be negative"
    end
  end

  test "should validate variant belongs to active test" do
    @ab_test.update!(status: 'draft')
    assert_not @result.valid?
    assert_includes @result.errors[:content_ab_test_variant], "must belong to an active, paused, or completed test"
    
    @ab_test.update!(status: 'completed')
    assert @result.valid?
  end

  test "should set default metadata on create" do
    @result.save!
    assert_not_nil @result.metadata
    assert_equal 'system', @result.metadata['recorded_by']
    assert_equal false, @result.metadata['data_quality_checked']
  end

  test "should set default data_source" do
    @result.data_source = nil
    @result.save!
    assert_equal 'manual', @result.data_source
  end

  # Association tests
  test "should belong to content_ab_test_variant" do
    assert_respond_to @result, :content_ab_test_variant
    assert_equal @variant, @result.content_ab_test_variant
  end

  test "should have content_ab_test through variant" do
    assert_respond_to @result, :content_ab_test
    @result.save!
    assert_equal @ab_test, @result.content_ab_test
  end

  test "should have generated_content through variant" do
    assert_respond_to @result, :generated_content
    @result.save!
    assert_equal @variant_content, @result.generated_content
  end

  # Performance analysis tests
  test "should calculate conversion value for revenue metrics" do
    @result.metric_name = 'revenue'
    @result.metric_value = 25.50
    @result.sample_size = 10
    @result.save!
    
    conversion_value = @result.conversion_value
    assert_equal 255.0, conversion_value # 25.50 * 10
  end

  test "should return zero conversion value for non-revenue metrics" do
    @result.metric_name = 'click_rate'
    @result.save!
    
    assert_equal 0.0, @result.conversion_value
  end

  test "should calculate cost efficiency for cost metrics" do
    @result.metric_name = 'cost_per_click'
    @result.metric_value = 2.50 # $2.50 per click
    @result.sample_size = 100 # 100 clicks
    @result.save!
    
    efficiency = @result.cost_efficiency
    assert_equal 40.0, efficiency # 100 / 2.50 = 40 clicks per dollar
  end

  test "should return nil cost efficiency for non-cost metrics" do
    @result.metric_name = 'click_rate'
    @result.save!
    
    assert_nil @result.cost_efficiency
  end

  test "should determine performance rating for rate metrics" do
    rate_metrics = %w[click_rate conversion_rate engagement_rate open_rate response_rate]
    
    rate_metrics.each do |metric|
      @result.metric_name = metric
      
      @result.metric_value = 0.5
      assert_equal 'poor', @result.performance_rating
      
      @result.metric_value = 2.0
      assert_equal 'fair', @result.performance_rating
      
      @result.metric_value = 4.0
      assert_equal 'good', @result.performance_rating
      
      @result.metric_value = 7.0
      assert_equal 'very_good', @result.performance_rating
      
      @result.metric_value = 12.0
      assert_equal 'excellent', @result.performance_rating
    end
  end

  test "should determine performance rating for bounce rate" do
    @result.metric_name = 'bounce_rate'
    
    @result.metric_value = 15.0
    assert_equal 'excellent', @result.performance_rating
    
    @result.metric_value = 30.0
    assert_equal 'very_good', @result.performance_rating
    
    @result.metric_value = 50.0
    assert_equal 'good', @result.performance_rating
    
    @result.metric_value = 70.0
    assert_equal 'fair', @result.performance_rating
    
    @result.metric_value = 85.0
    assert_equal 'poor', @result.performance_rating
  end

  # Metric type identification tests
  test "should identify conversion metrics" do
    conversion_metrics = %w[conversion_rate conversions signups purchases revenue]
    
    conversion_metrics.each do |metric|
      @result.metric_name = metric
      assert @result.is_conversion_metric?
    end
    
    @result.metric_name = 'click_rate'
    assert_not @result.is_conversion_metric?
  end

  test "should identify engagement metrics" do
    engagement_metrics = %w[engagement_rate clicks shares likes comments views]
    
    engagement_metrics.each do |metric|
      @result.metric_name = metric
      assert @result.is_engagement_metric?
    end
    
    @result.metric_name = 'conversion_rate'
    assert_not @result.is_engagement_metric?
  end

  test "should identify traffic metrics" do
    traffic_metrics = %w[impressions click_rate views]
    
    traffic_metrics.each do |metric|
      @result.metric_name = metric
      assert @result.is_traffic_metric?
    end
    
    @result.metric_name = 'revenue'
    assert_not @result.is_traffic_metric?
  end

  test "should identify cost metrics" do
    @result.metric_name = 'cost_per_click'
    assert @result.is_cost_metric?
    
    @result.metric_name = 'cost_per_conversion'
    assert @result.is_cost_metric?
    
    @result.metric_name = 'return_on_ad_spend'
    assert @result.is_cost_metric?
    
    @result.metric_name = 'click_rate'
    assert_not @result.is_cost_metric?
  end

  # Data quality tests
  test "should calculate data quality score" do
    @result.save!
    
    # Base score should be high for valid result
    base_score = @result.data_quality_score
    assert base_score > 80
    
    # Score should decrease for missing metadata
    @result.update!(metadata: nil)
    lower_score = @result.data_quality_score
    assert lower_score < base_score
  end

  test "should determine high confidence based on sample size and quality" do
    @result.sample_size = 150 # Above expected minimum
    @result.save!
    
    assert @result.has_high_confidence?
    
    @result.sample_size = 10 # Below expected minimum
    assert_not @result.has_high_confidence?
  end

  test "should define expected minimum sample size by metric type" do
    @result.metric_name = 'conversion_rate'
    assert_equal 100, @result.expected_minimum_sample_size
    
    @result.metric_name = 'engagement_rate'
    assert_equal 50, @result.expected_minimum_sample_size
    
    @result.metric_name = 'revenue'
    assert_equal 30, @result.expected_minimum_sample_size
    
    @result.metric_name = 'custom_metric'
    assert_equal 20, @result.expected_minimum_sample_size
  end

  # Comparison tests
  test "should compare with previous period" do
    @result.save!
    
    # Create a previous result
    previous_date = 7.days.ago.to_date
    previous_result = ContentAbTestResult.create!(
      content_ab_test_variant: @variant,
      metric_name: 'click_rate',
      metric_value: 2.0, # Lower than current 2.5
      sample_size: 100,
      recorded_date: previous_date,
      data_source: 'google_analytics'
    )
    
    comparison = @result.compare_with_previous_period(7)
    
    assert_not_nil comparison
    assert_equal 2.5, comparison[:current_value]
    assert_equal 2.0, comparison[:previous_value]
    assert_equal 25.0, comparison[:improvement_percent] # (2.5 - 2.0) / 2.0 * 100
    assert comparison[:is_better]
    assert_equal previous_date, comparison[:previous_date]
  end

  test "should return nil for comparison when no previous data" do
    @result.save!
    
    comparison = @result.compare_with_previous_period(7)
    assert_nil comparison
  end

  test "should get daily trend" do
    @result.save!
    
    # Create additional results for trend
    (1..5).each do |i|
      ContentAbTestResult.create!(
        content_ab_test_variant: @variant,
        metric_name: 'click_rate',
        metric_value: 2.0 + (i * 0.1),
        sample_size: 100,
        recorded_date: i.days.ago.to_date,
        data_source: 'google_analytics'
      )
    end
    
    trend = @result.daily_trend(7)
    
    assert trend.keys.count > 0
    assert trend.values.all? { |v| v.is_a?(Numeric) }
  end

  # Export and reporting tests
  test "should provide analytics hash" do
    @result.save!
    analytics = @result.to_analytics_hash
    
    expected_keys = %w[test_id test_name variant_id variant_name content_id content_title 
                      metric_name metric_value sample_size recorded_date data_source 
                      performance_rating conversion_value data_quality_score metadata]
    
    expected_keys.each do |key|
      assert_includes analytics.keys, key.to_sym
    end
    
    assert_equal @ab_test.id, analytics[:test_id]
    assert_equal @ab_test.test_name, analytics[:test_name]
    assert_equal @variant.id, analytics[:variant_id]
    assert_equal @variant.variant_name, analytics[:variant_name]
  end

  test "should format metric values appropriately" do
    percentage_metrics = %w[click_rate conversion_rate engagement_rate]
    percentage_metrics.each do |metric|
      @result.metric_name = metric
      @result.metric_value = 2.5678
      assert_equal '2.57%', @result.formatted_metric_value
    end
    
    @result.metric_name = 'revenue'
    @result.metric_value = 123.456
    assert_equal '$123.46', @result.formatted_metric_value
    
    @result.metric_name = 'cost_per_click'
    @result.metric_value = 1.234
    assert_equal '$1.23', @result.formatted_metric_value
    
    @result.metric_name = 'time_on_page'
    @result.metric_value = 125.7
    assert_equal '126 seconds', @result.formatted_metric_value
    
    @result.metric_name = 'clicks'
    @result.metric_value = 42
    assert_equal '42', @result.formatted_metric_value
  end

  # Bulk operations tests
  test "should bulk create results" do
    results_data = [
      {
        variant_id: @variant.id,
        metric_name: 'click_rate',
        metric_value: 2.5,
        sample_size: 100,
        date: Date.current,
        data_source: 'google_analytics'
      },
      {
        variant_id: @variant.id,
        metric_name: 'conversion_rate',
        metric_value: 1.2,
        sample_size: 50,
        date: Date.current,
        data_source: 'google_analytics'
      }
    ]
    
    assert_difference 'ContentAbTestResult.count', 2 do
      ContentAbTestResult.bulk_create_results(results_data)
    end
  end

  test "should handle bulk create validation errors gracefully" do
    results_data = [
      {
        variant_id: @variant.id,
        metric_name: 'invalid_metric', # Invalid
        metric_value: 2.5,
        sample_size: 100
      }
    ]
    
    assert_no_difference 'ContentAbTestResult.count' do
      results = ContentAbTestResult.bulk_create_results(results_data)
      assert_empty results
    end
  end

  test "should aggregate by metric" do
    # Create multiple results
    ContentAbTestResult.create!(
      content_ab_test_variant: @variant,
      metric_name: 'click_rate',
      metric_value: 2.0,
      sample_size: 100,
      recorded_date: Date.current
    )
    
    ContentAbTestResult.create!(
      content_ab_test_variant: @variant,
      metric_name: 'click_rate',
      metric_value: 3.0,
      sample_size: 150,
      recorded_date: Date.current
    )
    
    aggregation = ContentAbTestResult.aggregate_by_metric('click_rate', [@variant.id])
    
    assert_equal 5.0, aggregation[:total_value] # 2.0 + 3.0
    assert_equal 2.5, aggregation[:average_value] # (2.0 + 3.0) / 2
    assert_equal 250, aggregation[:total_sample_size] # 100 + 150
    assert_equal 2, aggregation[:count]
  end

  test "should provide performance summary by variant" do
    # Create multiple results with different metrics
    %w[click_rate conversion_rate engagement_rate].each_with_index do |metric, index|
      ContentAbTestResult.create!(
        content_ab_test_variant: @variant,
        metric_name: metric,
        metric_value: 2.0 + index,
        sample_size: 100,
        recorded_date: Date.current
      )
    end
    
    summary = ContentAbTestResult.performance_summary_by_variant(@variant.id)
    
    assert_includes summary.keys, 'click_rate'
    assert_includes summary.keys, 'conversion_rate'
    assert_includes summary.keys, 'engagement_rate'
    
    click_summary = summary['click_rate']
    assert_equal 2.0, click_summary[:average]
    assert_equal 100, click_summary[:total_sample_size]
  end

  # Scope tests
  test "should scope by metric" do
    @result.save!
    
    other_result = ContentAbTestResult.create!(
      content_ab_test_variant: @variant,
      metric_name: 'conversion_rate',
      metric_value: 1.5,
      sample_size: 50,
      recorded_date: Date.current
    )
    
    click_results = ContentAbTestResult.by_metric('click_rate')
    conversion_results = ContentAbTestResult.by_metric('conversion_rate')
    
    assert_includes click_results, @result
    assert_not_includes click_results, other_result
    assert_includes conversion_results, other_result
    assert_not_includes conversion_results, @result
  end

  test "should scope by date range" do
    @result.save!
    
    old_result = ContentAbTestResult.create!(
      content_ab_test_variant: @variant,
      metric_name: 'click_rate',
      metric_value: 2.0,
      sample_size: 100,
      recorded_date: 10.days.ago.to_date
    )
    
    recent_range = 5.days.ago.to_date..Date.current
    recent_results = ContentAbTestResult.by_date_range(recent_range.first, recent_range.last)
    
    assert_includes recent_results, @result
    assert_not_includes recent_results, old_result
  end

  test "should scope by data source" do
    @result.save!
    
    facebook_result = ContentAbTestResult.create!(
      content_ab_test_variant: @variant,
      metric_name: 'click_rate',
      metric_value: 2.0,
      sample_size: 100,
      recorded_date: Date.current,
      data_source: 'facebook_ads'
    )
    
    google_results = ContentAbTestResult.by_data_source('google_analytics')
    facebook_results = ContentAbTestResult.by_data_source('facebook_ads')
    
    assert_includes google_results, @result
    assert_not_includes google_results, facebook_result
    assert_includes facebook_results, facebook_result
    assert_not_includes facebook_results, @result
  end

  test "should scope conversion metrics" do
    @result.save!
    
    conversion_result = ContentAbTestResult.create!(
      content_ab_test_variant: @variant,
      metric_name: 'conversion_rate',
      metric_value: 1.5,
      sample_size: 100,
      recorded_date: Date.current
    )
    
    conversion_metrics = ContentAbTestResult.conversion_metrics
    
    assert_includes conversion_metrics, conversion_result
    assert_not_includes conversion_metrics, @result
  end

  test "should scope engagement metrics" do
    engagement_result = ContentAbTestResult.create!(
      content_ab_test_variant: @variant,
      metric_name: 'engagement_rate',
      metric_value: 3.5,
      sample_size: 100,
      recorded_date: Date.current
    )
    
    engagement_metrics = ContentAbTestResult.engagement_metrics
    
    assert_includes engagement_metrics, engagement_result
    assert_not_includes engagement_metrics, @result
  end

  # Search tests
  test "should search results by test name, variant name, and metric" do
    @result.save!
    
    # Create unique content for the other test
    other_control_content = GeneratedContent.create!(
      title: 'Social Media Control',
      body_content: 'This is a social media control content designed to test effectiveness in our social media marketing campaign. It provides a baseline for comparison.',
      content_type: 'social_post',
      format_variant: 'standard',
      campaign_plan: @campaign_plan,
      created_by: @user
    )
    
    other_variant_content = GeneratedContent.create!(
      title: 'Social Media Variant',
      body_content: 'This is a social media variant content designed to test effectiveness in our social media marketing campaign. It aims to improve engagement.',
      content_type: 'social_post',
      format_variant: 'standard',
      campaign_plan: @campaign_plan,
      created_by: @user
    )
    
    # Create result with different test name
    other_test = ContentAbTest.create!(
      test_name: 'Social Media Test',
      status: 'active',
      primary_goal: 'engagement_rate',
      confidence_level: '95',
      traffic_allocation: 100,
      minimum_sample_size: 100,
      test_duration_days: 14,
      start_date: 1.day.from_now,
      campaign_plan: @campaign_plan,
      created_by: @user,
      control_content: other_control_content
    )
    
    other_variant = ContentAbTestVariant.create!(
      content_ab_test: other_test,
      generated_content: other_variant_content,
      variant_name: 'Social Variant',
      status: 'active',
      traffic_split: 50.0
    )
    
    other_result = ContentAbTestResult.create!(
      content_ab_test_variant: other_variant,
      metric_name: 'engagement_rate',
      metric_value: 3.0,
      sample_size: 100,
      recorded_date: Date.current
    )
    
    email_results = ContentAbTestResult.search_results('email')
    social_results = ContentAbTestResult.search_results('social')
    click_results = ContentAbTestResult.search_results('click')
    
    assert_includes email_results, @result
    assert_not_includes email_results, other_result
    assert_includes social_results, other_result
    assert_not_includes social_results, @result
    assert_includes click_results, @result
    assert_not_includes click_results, other_result
  end
end