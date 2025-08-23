require "test_helper"

class ContentAbTestVariantTest < ActiveSupport::TestCase
  fixtures :users, :campaign_plans, :generated_contents

  def setup
    @user = users(:marketer_user)
    @campaign_plan = campaign_plans(:draft_plan)
    @control_content = generated_contents(:one)
    @variant_content = generated_contents(:two)
    
    @ab_test = ContentAbTest.create!(
      test_name: 'Email Subject Test',
      status: 'draft',
      primary_goal: 'click_rate',
      confidence_level: '95',
      traffic_allocation: 100,
      minimum_sample_size: 100,
      test_duration_days: 14,
      campaign_plan: @campaign_plan,
      created_by: @user,
      control_content: @control_content
    )
    
    @variant = ContentAbTestVariant.new(
      content_ab_test: @ab_test,
      generated_content: @variant_content,
      variant_name: 'Variant A',
      status: 'draft',
      traffic_split: 50.0,
      sample_size: 0
    )
  end

  # Basic validation tests
  test "should be valid with valid attributes" do
    assert @variant.valid?, "Variant should be valid: #{@variant.errors.full_messages}"
  end

  test "should require variant_name" do
    @variant.variant_name = nil
    assert_not @variant.valid?
    assert_includes @variant.errors[:variant_name], "can't be blank"
  end

  test "should require status" do
    @variant.status = nil
    assert_not @variant.valid?
    assert_includes @variant.errors[:status], "can't be blank"
  end

  test "should require traffic_split" do
    @variant.traffic_split = nil
    assert_not @variant.valid?
    assert_includes @variant.errors[:traffic_split], "can't be blank"
  end

  test "should validate status inclusion" do
    @variant.status = 'invalid_status'
    assert_not @variant.valid?
    assert_includes @variant.errors[:status], "is not included in the list"
  end

  test "should validate traffic_split range" do
    @variant.traffic_split = 150
    assert_not @variant.valid?
    assert_includes @variant.errors[:traffic_split], "must be less than or equal to 100"
    
    @variant.traffic_split = 0
    assert_not @variant.valid?
    assert_includes @variant.errors[:traffic_split], "must be greater than 0"
  end

  test "should validate traffic_split minimum for meaningful results" do
    @variant.traffic_split = 3
    assert_not @variant.valid?
    assert_includes @variant.errors[:traffic_split], "should be at least 5% for meaningful results"
  end

  test "should validate traffic_split maximum to allow control group" do
    @variant.traffic_split = 97
    assert_not @variant.valid?
    assert_includes @variant.errors[:traffic_split], "should not exceed 95% to allow for control group"
  end

  test "should validate sample_size is non-negative" do
    @variant.sample_size = -10
    assert_not @variant.valid?
    assert_includes @variant.errors[:sample_size], "must be greater than or equal to 0"
  end

  test "should set default metadata on create" do
    @variant.save!
    assert_not_nil @variant.metadata
    assert_equal 'manual', @variant.metadata['creation_method']
  end

  test "should set default sample_size to 0" do
    @variant.sample_size = nil
    @variant.save!
    assert_equal 0, @variant.sample_size
  end

  # Association tests
  test "should belong to content_ab_test" do
    assert_respond_to @variant, :content_ab_test
    assert_equal @ab_test, @variant.content_ab_test
  end

  test "should belong to generated_content" do
    assert_respond_to @variant, :generated_content
    assert_equal @variant_content, @variant.generated_content
  end

  test "should have many content_ab_test_results" do
    assert_respond_to @variant, :content_ab_test_results
  end

  # Custom validation tests
  test "should validate generated_content belongs to same campaign" do
    other_campaign = campaign_plans(:completed_plan)
    other_content = GeneratedContent.create!(
      title: 'Other Campaign Content',
      body_content: 'This content belongs to a different campaign and has enough characters to pass validation. This is a much longer piece of content that should easily meet the minimum character requirement for standard format content. It contains detailed information and provides value to the reader.',
      content_type: 'email',
      format_variant: 'standard',
      status: 'draft',
      campaign_plan: other_campaign,
      created_by: @user
    )
    
    @variant.generated_content = other_content
    assert_not @variant.valid?
    assert_includes @variant.errors[:generated_content], "must belong to the same campaign as the test"
  end

  test "should validate variant_name uniqueness within test" do
    @variant.save!
    
    duplicate_variant = ContentAbTestVariant.new(
      content_ab_test: @ab_test,
      generated_content: @variant_content,
      variant_name: 'Variant A', # Same name
      status: 'draft',
      traffic_split: 25.0
    )
    
    assert_not duplicate_variant.valid?
    assert_includes duplicate_variant.errors[:variant_name], "must be unique within the test"
  end

  test "should allow same variant_name in different tests" do
    other_test = ContentAbTest.create!(
      test_name: 'Other Test',
      status: 'draft',
      primary_goal: 'conversion_rate',
      confidence_level: '95',
      traffic_allocation: 100,
      minimum_sample_size: 100,
      test_duration_days: 14,
      campaign_plan: @campaign_plan,
      created_by: @user,
      control_content: @control_content
    )
    
    @variant.save!
    
    other_variant = ContentAbTestVariant.new(
      content_ab_test: other_test,
      generated_content: @variant_content,
      variant_name: 'Variant A', # Same name, different test
      status: 'draft',
      traffic_split: 50.0
    )
    
    assert other_variant.valid?
  end

  test "should prevent content from being in multiple active tests" do
    # Create first variant
    @variant.save!
    
    # Start the test to make it active
    @ab_test.update!(status: 'active')
    
    # Try to create another test with same content
    other_test = ContentAbTest.create!(
      test_name: 'Other Active Test',
      status: 'active',
      primary_goal: 'conversion_rate',
      confidence_level: '95',
      traffic_allocation: 100,
      minimum_sample_size: 100,
      test_duration_days: 14,
      campaign_plan: @campaign_plan,
      created_by: @user,
      control_content: @control_content
    )
    
    duplicate_variant = ContentAbTestVariant.new(
      content_ab_test: other_test,
      generated_content: @variant_content, # Same content in different active test
      variant_name: 'Other Variant',
      status: 'draft',
      traffic_split: 50.0
    )
    
    assert_not duplicate_variant.valid?
    assert_includes duplicate_variant.errors[:generated_content], "is already being tested in another active A/B test"
  end

  # Status method tests
  test "should have status check methods" do
    @variant.status = 'draft'
    assert @variant.draft?
    assert_not @variant.active?
    
    @variant.status = 'active'
    assert @variant.active?
    assert_not @variant.draft?
    
    @variant.status = 'completed'
    assert @variant.completed?
    assert_not @variant.active?
  end

  # Performance tracking tests
  test "should record single result" do
    @variant.save!
    @ab_test.update!(status: 'active') # Make test active to allow recording results
    
    assert_difference '@variant.content_ab_test_results.count', 1 do
      @variant.record_result!('click_rate', 2.5, 100, Date.current)
    end
    
    result = @variant.content_ab_test_results.last
    assert_equal 'click_rate', result.metric_name
    assert_equal 2.5, result.metric_value
    assert_equal 100, result.sample_size
    assert_equal Date.current, result.recorded_date
  end

  test "should update sample_size when recording results" do
    @variant.save!
    @ab_test.update!(status: 'active') # Make test active to allow recording results
    initial_sample_size = @variant.sample_size
    
    @variant.record_result!('click_rate', 2.5, 100)
    @variant.reload
    
    assert_equal initial_sample_size + 100, @variant.sample_size
  end

  test "should batch record multiple results" do
    @variant.save!
    @ab_test.update!(status: 'active') # Make test active to allow recording results
    
    results_data = [
      { metric_name: 'click_rate', metric_value: 2.5, sample_size: 100, date: Date.current },
      { metric_name: 'conversion_rate', metric_value: 1.2, sample_size: 50, date: Date.current }
    ]
    
    assert_difference '@variant.content_ab_test_results.count', 2 do
      @variant.batch_record_results!(results_data)
    end
    
    @variant.reload
    assert_equal 150, @variant.sample_size # 0 + 100 + 50
  end

  # Analytics method tests
  test "should calculate performance metrics" do
    @variant.save!
    @ab_test.update!(status: 'active') # Make test active to allow recording results
    
    # Add some test results
    @variant.record_result!('click_rate', 2.0, 100)
    @variant.record_result!('click_rate', 3.0, 100)
    @variant.record_result!('conversion_rate', 1.5, 50)
    
    metrics = @variant.performance_metrics
    
    assert_includes metrics.keys, 'click_rate'
    assert_includes metrics.keys, 'conversion_rate'
    
    click_metrics = metrics['click_rate']
    assert_equal 2.5, click_metrics[:average] # (2.0 + 3.0) / 2
    assert_equal 5.0, click_metrics[:total] # 2.0 + 3.0
    assert_equal 2, click_metrics[:count]
  end

  test "should calculate conversion rate" do
    @variant.save!
    @ab_test.update!(status: 'active') # Make test active to allow recording results
    
    @variant.record_result!('impressions', 1000, 1)
    @variant.record_result!('conversions', 25, 1)
    
    conversion_rate = @variant.conversion_rate('impressions', 'conversions')
    assert_equal 2.5, conversion_rate # (25/1000) * 100
  end

  test "should get total metric value" do
    @variant.save!
    @ab_test.update!(status: 'active') # Make test active to allow recording results
    
    @variant.record_result!('clicks', 10, 1)
    @variant.record_result!('clicks', 15, 1)
    @variant.record_result!('clicks', 20, 1)
    
    total_clicks = @variant.total_metric_value('clicks')
    assert_equal 45.0, total_clicks
  end

  test "should get average metric value" do
    @variant.save!
    @ab_test.update!(status: 'active') # Make test active to allow recording results
    
    @variant.record_result!('click_rate', 2.0, 1)
    @variant.record_result!('click_rate', 4.0, 1)
    
    avg_rate = @variant.average_metric_value('click_rate')
    assert_equal 3.0, avg_rate
  end

  # Lifecycle method tests
  test "should activate variant when test is draft" do
    @variant.save!
    
    assert @variant.can_activate?
    assert @variant.activate!
    assert @variant.active?
    assert_not_nil @variant.metadata['activated_at']
  end

  test "should not activate variant when test is active" do
    @ab_test.update!(status: 'active')
    @variant.save!
    
    assert_not @variant.can_activate?
  end

  test "should pause active variant" do
    @variant.status = 'active'
    @variant.save!
    
    assert @variant.pause!
    assert @variant.paused?
    assert_not_nil @variant.metadata['paused_at']
  end

  test "should stop active variant with reason" do
    @variant.status = 'active'
    @variant.save!
    
    assert @variant.stop!('Low performance')
    assert @variant.stopped?
    assert_equal 'Low performance', @variant.metadata['stop_reason']
  end

  test "should complete variant when conditions are met" do
    @variant.status = 'active'
    @variant.sample_size = 200 # Above minimum
    @variant.save!
    
    # Mock minimum sample size calculation
    @variant.stubs(:minimum_sample_size_for_variant).returns(100)
    
    assert @variant.can_complete?
    assert @variant.complete!
    assert @variant.completed?
  end

  # Utility method tests
  test "should check if is control variant" do
    @variant.save!
    
    # This variant is not the control
    assert_not @variant.is_control_variant?
    
    # Create a variant that uses the control content
    control_variant = ContentAbTestVariant.create!(
      content_ab_test: @ab_test,
      generated_content: @control_content, # This is the control content
      variant_name: 'Control',
      status: 'draft',
      traffic_split: 50.0
    )
    
    assert control_variant.is_control_variant?
  end

  test "should format traffic allocation percentage" do
    @variant.traffic_split = 25.5
    assert_equal '25.5%', @variant.traffic_allocation_percentage
  end

  test "should calculate expected daily traffic" do
    @ab_test.update!(status: 'active', test_duration_days: 10)
    # Mock the target_audience_size method since it doesn't exist in the database
    @campaign_plan.stubs(:target_audience_size).returns(1000)
    @variant.traffic_split = 25.0
    @variant.save!
    
    expected = @variant.expected_daily_traffic
    # (1000 / 10) * (25 / 100) = 25
    assert_equal 25, expected
  end

  test "should calculate minimum sample size for variant" do
    @ab_test.minimum_sample_size = 400
    @variant.traffic_split = 25.0 # 25%
    @variant.save!
    
    min_size = @variant.minimum_sample_size_for_variant
    assert_equal 100, min_size # 400 * 0.25 = 100
  end

  test "should check if has sufficient data" do
    @variant.sample_size = 150
    @variant.traffic_split = 25.0
    @ab_test.minimum_sample_size = 400
    @variant.save!
    
    assert @variant.has_sufficient_data? # 150 >= 100 (minimum for this variant)
    
    @variant.sample_size = 50
    @variant.save!
    
    assert_not @variant.has_sufficient_data? # 50 < 100
  end

  # Summary method tests
  test "should provide variant summary" do
    @variant.save!
    summary = @variant.variant_summary
    
    assert_includes summary.keys, :variant_name
    assert_includes summary.keys, :status
    assert_includes summary.keys, :traffic_split
    assert_includes summary.keys, :sample_size
    assert_includes summary.keys, :content_title
    assert_includes summary.keys, :test_name
    
    assert_equal @variant.variant_name, summary[:variant_name]
    assert_equal @variant_content.title, summary[:content_title]
    assert_equal @ab_test.test_name, summary[:test_name]
  end

  test "should provide detailed analytics" do
    @variant.save!
    analytics = @variant.detailed_analytics
    
    assert_includes analytics.keys, :basic_info
    assert_includes analytics.keys, :performance_metrics
    assert_includes analytics.keys, :traffic_allocation
    assert_includes analytics.keys, :content_details
    
    content_details = analytics[:content_details]
    assert_equal @variant_content.content_type, content_details[:content_type]
    assert_equal @variant_content.word_count, content_details[:word_count]
  end

  # Scope tests
  test "should scope by status" do
    @variant.save!
    
    active_variant = ContentAbTestVariant.create!(
      content_ab_test: @ab_test,
      generated_content: @control_content,
      variant_name: 'Active Variant',
      status: 'active',
      traffic_split: 30.0
    )
    
    draft_variants = ContentAbTestVariant.draft
    active_variants = ContentAbTestVariant.active
    
    assert_includes draft_variants, @variant
    assert_not_includes draft_variants, active_variant
    assert_includes active_variants, active_variant
    assert_not_includes active_variants, @variant
  end

  test "should scope by test" do
    @variant.save!
    
    other_test = ContentAbTest.create!(
      test_name: 'Other Test',
      status: 'draft',
      primary_goal: 'conversion_rate',
      confidence_level: '95',
      traffic_allocation: 100,
      minimum_sample_size: 100,
      test_duration_days: 14,
      campaign_plan: @campaign_plan,
      created_by: @user,
      control_content: @control_content
    )
    
    other_variant = ContentAbTestVariant.create!(
      content_ab_test: other_test,
      generated_content: @variant_content,
      variant_name: 'Other Test Variant',
      status: 'draft',
      traffic_split: 50.0
    )
    
    test_variants = ContentAbTestVariant.by_test(@ab_test.id)
    
    assert_includes test_variants, @variant
    assert_not_includes test_variants, other_variant
  end

  test "should scope high traffic variants" do
    @variant.traffic_split = 25.0 # Above 20%
    @variant.save!
    
    low_variant = ContentAbTestVariant.create!(
      content_ab_test: @ab_test,
      generated_content: @control_content,
      variant_name: 'Low Traffic',
      status: 'draft',
      traffic_split: 15.0 # Below 20%
    )
    
    high_traffic = ContentAbTestVariant.high_traffic
    
    assert_includes high_traffic, @variant
    assert_not_includes high_traffic, low_variant
  end

  # Performance trend tests
  test "should get performance trend over time" do
    @variant.save!
    @ab_test.update!(status: 'active') # Make test active to allow recording results
    
    # Add results over several days
    3.times do |i|
      date = i.days.ago.to_date
      @variant.record_result!('click_rate', 2.0 + i, 10, date)
    end
    
    trend = @variant.performance_trend('click_rate', 7)
    
    assert_equal 3, trend.keys.count
    assert trend.values.all? { |v| v.is_a?(Numeric) }
  end
end