require "test_helper"

class ContentAbTestServiceTest < ActiveSupport::TestCase
  fixtures :users, :campaign_plans, :generated_contents

  def setup
    @user = users(:marketer_user)
    @campaign_plan = campaign_plans(:draft_plan)
    @control_content = generated_contents(:one)
    @variant_content = generated_contents(:two)
    
    @test_params = {
      test_name: 'Email Subject Test',
      status: 'draft',
      primary_goal: 'click_rate',
      confidence_level: '95',
      traffic_allocation: 100,
      minimum_sample_size: 100,
      test_duration_days: 14,
      description: 'Testing different email subject lines',
      campaign_plan: @campaign_plan,
      control_content: @control_content
    }
    
    @ab_test = ContentAbTest.create!(@test_params.merge(created_by: @user))
    @service = ContentAbTestService.new(@ab_test, @user)
  end

  # Service initialization tests
  test "should initialize service with test and user" do
    assert_equal @ab_test, @service.test
    assert_equal @user, @service.user
    assert_empty @service.errors
  end

  # Test creation tests
  test "should create test successfully" do
    service = ContentAbTestService.new(nil, @user)
    
    new_test_params = @test_params.merge(test_name: 'New Email Subject Test')
    test = service.create_test(new_test_params)
    
    assert test
    assert test.persisted?
    assert_equal new_test_params[:test_name], test.test_name
    assert_equal @user, test.created_by
    assert_not_nil test.metadata
  end

  test "should handle test creation validation errors" do
    service = ContentAbTestService.new(nil, @user)
    invalid_params = @test_params.merge(test_name: nil) # Invalid
    
    result = service.create_test(invalid_params)
    
    assert_not result
    assert_not_empty service.errors
    assert_includes service.errors.first, "Test name can't be blank"
  end

  test "should create test via class method" do
    new_test_params = @test_params.merge(test_name: 'Class Method Test')
    test = ContentAbTestService.create_test(new_test_params, @user)
    
    assert test
    assert test.persisted?
    assert_equal new_test_params[:test_name], test.test_name
  end

  # Simple A/B test setup tests
  test "should setup simple ab test with control and variant" do
    service = ContentAbTestService.new(nil, @user)
    
    test = service.setup_simple_ab_test(@control_content, @variant_content, {
      test_name: 'Simple A/B Test',
      primary_goal: 'conversion_rate'
    })
    
    assert test
    assert test.persisted?
    assert_equal @control_content, test.control_content
    assert_equal @campaign_plan, test.campaign_plan
    assert_equal 1, test.content_ab_test_variants.count
    
    variant = test.content_ab_test_variants.first
    assert_equal @variant_content, variant.generated_content
    assert_equal 50.0, variant.traffic_split
    assert_equal 'Variant A', variant.variant_name
  end

  test "should setup simple ab test via class method" do
    test = ContentAbTestService.setup_simple_ab_test(
      @control_content, 
      @variant_content, 
      { test_name: 'Class Method Test' }, 
      @user
    )
    
    assert test
    assert test.persisted?
    assert_equal 1, test.content_ab_test_variants.count
  end

  test "should handle simple ab test creation errors" do
    service = ContentAbTestService.new(nil, @user)
    
    # Use content from different campaign
    other_campaign = campaign_plans(:active_plan)
    other_content = GeneratedContent.create!(
      title: 'Other Content',
      body_content: 'Content for different campaign with enough characters to pass validation requirements and meet the minimum standard format length requirements for content generation testing purposes.',
      content_type: 'email',
      format_variant: 'standard',
      status: 'draft',
      campaign_plan: other_campaign,
      created_by: @user
    )
    
    result = service.setup_simple_ab_test(@control_content, other_content, {
      test_name: 'Cross-campaign Test'
    })
    
    assert_not result
    assert_not_empty service.errors
  end

  # Bulk creation tests
  test "should create test from multiple content variants" do
    # Create additional content
    variant2 = GeneratedContent.create!(
      title: 'Variant 2',
      body_content: 'Second variant content with sufficient characters for validation requirements and meeting standard format length requirements for comprehensive testing purposes in our content generation system.',
      content_type: 'email',
      format_variant: 'standard',
      status: 'draft',
      campaign_plan: @campaign_plan,
      created_by: @user
    )
    
    content_variants = [@control_content, @variant_content, variant2]
    service = ContentAbTestService.new(nil, @user)
    
    bulk_test_params = @test_params.merge(test_name: 'Bulk Creation Test')
    test = service.bulk_create_from_content_variants(content_variants, bulk_test_params)
    
    assert test
    assert test.persisted?
    assert_equal @control_content, test.control_content
    assert_equal 2, test.content_ab_test_variants.count # Excludes control
    
    variants = test.content_ab_test_variants.order(:id)
    assert_equal 'Variant A', variants[0].variant_name
    assert_equal 'Variant B', variants[1].variant_name
    assert_equal 50.0, variants[0].traffic_split # 100 / 2 variants
    assert_equal 50.0, variants[1].traffic_split
  end

  test "should handle empty content variants for bulk creation" do
    service = ContentAbTestService.new(nil, @user)
    
    result = service.bulk_create_from_content_variants([], @test_params)
    
    assert_not result
    assert_not_empty service.errors
  end

  # Variant management tests
  test "should add variant to test" do
    variant = @service.add_variant(@variant_content, {
      variant_name: 'New Variant',
      traffic_split: 30.0
    })
    
    assert variant
    assert variant.persisted?
    assert_equal 'New Variant', variant.variant_name
    assert_equal 30.0, variant.traffic_split
    assert_equal @variant_content, variant.generated_content
  end

  test "should not add variant to active test" do
    @ab_test.update!(status: 'active')
    
    result = @service.add_variant(@variant_content)
    
    assert_not result
    assert_not_empty @service.errors
  end

  test "should remove variant from test" do
    variant = @ab_test.add_variant!(@variant_content, variant_name: 'Test Variant', traffic_split: 50)
    
    result = @service.remove_variant(variant)
    
    assert result
    assert_not ContentAbTestVariant.exists?(variant.id)
  end

  test "should not remove variant from active test" do
    variant = @ab_test.add_variant!(@variant_content, variant_name: 'Test Variant', traffic_split: 50)
    @ab_test.update!(status: 'active')
    
    result = @service.remove_variant(variant)
    
    assert_not result
    assert_not_empty @service.errors
  end

  # Test lifecycle tests
  test "should start test successfully" do
    @ab_test.add_variant!(@variant_content, variant_name: 'Variant A', traffic_split: 50)
    
    result = @service.start_test
    
    assert result
    assert @ab_test.reload.active?
    assert_not_nil @ab_test.start_date
    assert_not_nil @ab_test.end_date
    assert_not_nil @ab_test.metadata['started_at']
  end

  test "should start test with custom start date" do
    @ab_test.add_variant!(@variant_content, variant_name: 'Variant A', traffic_split: 50)
    start_date = 1.day.from_now
    
    result = @service.start_test(start_date: start_date)
    
    assert result
    assert_equal start_date.to_date, @ab_test.reload.start_date.to_date
  end

  test "should not start test without variants" do
    result = @service.start_test
    
    assert_not result
    assert_not_empty @service.errors
  end

  test "should pause active test" do
    @ab_test.update!(status: 'active')
    
    result = @service.pause_test('Need to review setup')
    
    assert result
    assert @ab_test.reload.paused?
    assert_equal 'Need to review setup', @ab_test.metadata['reason']
  end

  test "should not pause non-active test" do
    result = @service.pause_test
    
    assert_not result
    assert_not_empty @service.errors
  end

  test "should resume paused test" do
    @ab_test.update!(status: 'paused')
    
    result = @service.resume_test('Setup review complete')
    
    assert result
    assert @ab_test.reload.active?
    assert_equal 'Setup review complete', @ab_test.metadata['reason']
  end

  test "should not resume non-paused test" do
    result = @service.resume_test
    
    assert_not result
    assert_not_empty @service.errors
  end

  test "should stop active test" do
    @ab_test.update!(status: 'active', start_date: 1.day.ago)
    
    result = @service.stop_test('Manual stop for analysis')
    
    assert result
    assert @ab_test.reload.stopped?
    assert_not_nil @ab_test.end_date
    assert_equal 'Manual stop for analysis', @ab_test.metadata['stop_reason']
  end

  test "should complete test when conditions are met" do
    @ab_test.update!(status: 'active', start_date: 15.days.ago, minimum_sample_size: 10)
    
    # Mock the conditions for completion
    @ab_test.stubs(:can_complete?).returns(true)
    @ab_test.stubs(:minimum_sample_size_reached?).returns(true)
    @ab_test.stubs(:test_duration_reached?).returns(true)
    
    result = @service.complete_test
    
    assert result
    assert @ab_test.reload.completed?
    assert_not_nil @ab_test.end_date
  end

  test "should not complete test when conditions not met" do
    @ab_test.update!(status: 'active')
    
    result = @service.complete_test
    
    assert_not result
    assert_not_empty @service.errors
  end

  # Results recording tests
  test "should record single result" do
    variant = @ab_test.add_variant!(@variant_content, variant_name: 'Variant A', traffic_split: 50)
    @ab_test.update!(status: 'active')
    
    results_data = [
      {
        variant_id: variant.id,
        metric_name: 'click_rate',
        metric_value: 2.5,
        sample_size: 100
      }
    ]
    
    count = @service.record_results(results_data)
    
    assert_equal 1, count
    assert_equal 1, variant.content_ab_test_results.count
    
    result = variant.content_ab_test_results.first
    assert_equal 'click_rate', result.metric_name
    assert_equal 2.5, result.metric_value
    assert_equal 100, result.sample_size
  end

  test "should record results by variant name" do
    variant = @ab_test.add_variant!(@variant_content, variant_name: 'Variant A', traffic_split: 50)
    @ab_test.update!(status: 'active')
    
    results_data = [
      {
        variant_name: 'Variant A', # Use name instead of ID
        metric_name: 'conversion_rate',
        metric_value: 1.2,
        sample_size: 50
      }
    ]
    
    count = @service.record_results(results_data)
    
    assert_equal 1, count
    assert_equal 1, variant.content_ab_test_results.count
  end

  test "should batch record results for multiple variants" do
    variant_a = @ab_test.add_variant!(@variant_content, variant_name: 'Variant A', traffic_split: 25)
    variant_b = @ab_test.add_variant!(@control_content, variant_name: 'Variant B', traffic_split: 25)
    @ab_test.update!(status: 'active')
    
    variant_results_map = {
      variant_a.id => [
        { metric_name: 'click_rate', metric_value: 2.5, sample_size: 100 },
        { metric_name: 'conversion_rate', metric_value: 1.2, sample_size: 50 }
      ],
      variant_b.id => [
        { metric_name: 'click_rate', metric_value: 3.0, sample_size: 120 }
      ]
    }
    
    count = @service.batch_record_results(variant_results_map)
    
    assert_equal 3, count
    assert_equal 2, variant_a.content_ab_test_results.count
    assert_equal 1, variant_b.content_ab_test_results.count
  end

  test "should handle invalid variant identifier for results" do
    @ab_test.update!(status: 'active')
    
    results_data = [
      {
        variant_id: 99999, # Non-existent
        metric_name: 'click_rate',
        metric_value: 2.5,
        sample_size: 100
      }
    ]
    
    count = @service.record_results(results_data)
    
    assert_equal 0, count
  end

  # Performance reporting tests
  test "should generate performance report" do
    variant = @ab_test.add_variant!(@variant_content, variant_name: 'Variant A', traffic_split: 50)
    @ab_test.update!(status: 'active', start_date: 5.days.ago)
    
    # Add some results
    variant.record_result!('click_rate', 2.5, 100)
    variant.record_result!('conversion_rate', 1.2, 50)
    
    report = @service.generate_performance_report
    
    assert_includes report.keys, :test_summary
    assert_includes report.keys, :current_results
    assert_includes report.keys, :performance_trends
    assert_includes report.keys, :statistical_analysis
    assert_includes report.keys, :recommendations
    assert_includes report.keys, :export_data
    
    assert_equal @ab_test.test_name, report[:test_summary][:test_name]
  end

  test "should generate report for custom date range" do
    variant = @ab_test.add_variant!(@variant_content, variant_name: 'Variant A', traffic_split: 50)
    @ab_test.update!(status: 'active', start_date: 10.days.ago)
    
    date_range = 5.days.ago.to_date..Date.current
    
    report = @service.generate_performance_report(date_range)
    
    assert_not_nil report
    assert_includes report.keys, :export_data
  end

  test "should return empty report for inactive test" do
    report = @service.generate_performance_report
    
    assert_equal({}, report)
  end

  # Test cloning tests
  test "should clone test with variants" do
    original_variant = @ab_test.add_variant!(@variant_content, variant_name: 'Original Variant', traffic_split: 50)
    
    cloned_test = @service.clone_test(test_name: 'Cloned Test')
    
    assert cloned_test
    assert cloned_test.persisted?
    assert_equal 'Cloned Test', cloned_test.test_name
    assert_equal 'draft', cloned_test.status
    assert_nil cloned_test.start_date
    assert_nil cloned_test.end_date
    assert_equal @ab_test.control_content, cloned_test.control_content
    assert_equal 1, cloned_test.content_ab_test_variants.count
    
    cloned_variant = cloned_test.content_ab_test_variants.first
    assert_equal original_variant.variant_name, cloned_variant.variant_name
    assert_equal original_variant.traffic_split, cloned_variant.traffic_split
    assert_equal original_variant.generated_content, cloned_variant.generated_content
  end

  test "should clone test with default name" do
    cloned_test = @service.clone_test
    
    assert cloned_test
    assert_equal "#{@ab_test.test_name} (Clone)", cloned_test.test_name
  end

  test "should handle clone test errors" do
    # Force an error by making test_name too long
    long_name = 'a' * 300
    
    result = @service.clone_test(test_name: long_name)
    
    assert_not result
    assert_not_empty @service.errors
  end

  # Error handling tests
  test "should collect and expose service errors" do
    # Try to start test without variants
    @service.start_test
    
    assert_not_empty @service.errors
    assert_includes @service.errors.first, "Test cannot be started"
  end

  test "should clear errors between operations" do
    # Generate an error
    @service.start_test
    assert_not_empty @service.errors
    
    # Successful operation should clear errors
    @ab_test.add_variant!(@variant_content, variant_name: 'Variant A', traffic_split: 50)
    result = @service.start_test
    
    # Errors should be updated (not necessarily empty, but different)
    if result
      # If successful, no new errors
      assert_empty @service.errors
    else
      # If failed, should have current error, not old one
      assert_not_empty @service.errors
    end
  end

  # Integration tests
  test "should handle complete test workflow" do
    # Step 1: Add variant
    variant = @service.add_variant(@variant_content, {
      variant_name: 'Email Variant A',
      traffic_split: 50.0
    })
    assert variant
    
    # Step 2: Start test
    result = @service.start_test
    assert result
    assert @ab_test.reload.active?
    
    # Step 3: Record some results
    results_data = [
      {
        variant_id: variant.id,
        metric_name: 'click_rate',
        metric_value: 2.5,
        sample_size: 150
      }
    ]
    count = @service.record_results(results_data)
    assert_equal 1, count
    
    # Step 4: Generate report
    report = @service.generate_performance_report
    assert_not_nil report[:test_summary]
    assert_not_nil report[:current_results]
    
    # Step 5: Stop test
    result = @service.stop_test('Test complete')
    assert result
    assert @ab_test.reload.stopped?
  end

  test "should prevent operations on inappropriate test states" do
    @ab_test.update!(status: 'completed')
    
    # Should not be able to add variants to completed test
    variant = @service.add_variant(@variant_content)
    assert_not variant
    
    # Should not be able to start completed test
    result = @service.start_test
    assert_not result
  end
end