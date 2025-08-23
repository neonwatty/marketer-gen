require "test_helper"

class ContentAbTestWorkflowTest < ActionDispatch::IntegrationTest
  fixtures :users, :campaign_plans, :generated_contents

  def setup
    @user = users(:marketer_user)
    @campaign_plan = campaign_plans(:draft_plan)
    @control_content = generated_contents(:one)
    @variant_content = generated_contents(:two)
  end

  test "complete A/B test lifecycle workflow" do
    # Step 1: Create A/B test
    ab_test = ContentAbTest.create!(
      test_name: 'Email Subject Line A/B Test',
      status: 'draft',
      primary_goal: 'click_rate',
      confidence_level: '95',
      traffic_allocation: 100,
      minimum_sample_size: 200,
      test_duration_days: 14,
      description: 'Testing different email subject lines for better engagement',
      campaign_plan: @campaign_plan,
      created_by: @user,
      control_content: @control_content
    )

    assert ab_test.persisted?
    assert_equal 'draft', ab_test.status
    assert ab_test.draft?

    # Step 2: Add variants to the test
    variant_a = ab_test.add_variant!(
      @variant_content,
      variant_name: 'Subject Line A',
      traffic_split: 50.0
    )

    assert variant_a.persisted?
    assert_equal 'Subject Line A', variant_a.variant_name
    assert_equal 50.0, variant_a.traffic_split
    assert_equal 'draft', variant_a.status
    assert_equal 1, ab_test.content_ab_test_variants.count

    # Step 3: Start the test
    service = ContentAbTestService.new(ab_test, @user)
    start_result = service.start_test(start_date: Time.current)

    assert start_result
    ab_test.reload
    assert_equal 'active', ab_test.status
    assert ab_test.active?
    assert ab_test.running?
    assert_not_nil ab_test.start_date
    assert_not_nil ab_test.end_date

    # Variants should also be activated
    variant_a.reload
    assert_equal 'active', variant_a.status

    # Step 4: Record performance data over time
    test_days = 5
    daily_sample_size = 50

    test_days.times do |day|
      date = day.days.ago.to_date

      # Record results for variant A
      variant_a.record_result!('impressions', 1000 + (day * 10), daily_sample_size, date)
      variant_a.record_result!('clicks', 25 + day, daily_sample_size, date)
      variant_a.record_result!('conversions', 3 + (day * 0.5), daily_sample_size, date)

      # Calculate derived metrics
      click_rate = ((25 + day).to_f / (1000 + (day * 10)) * 100).round(2)
      conversion_rate = ((3 + (day * 0.5)).to_f / (25 + day) * 100).round(2)

      variant_a.record_result!('click_rate', click_rate, daily_sample_size, date)
      variant_a.record_result!('conversion_rate', conversion_rate, daily_sample_size, date)
    end

    # Verify results were recorded
    variant_a.reload
    assert variant_a.sample_size > 0
    assert variant_a.content_ab_test_results.count > 0

    # Step 5: Analyze performance
    performance_metrics = variant_a.performance_metrics
    assert_includes performance_metrics.keys, 'click_rate'
    assert_includes performance_metrics.keys, 'conversion_rate'
    assert_includes performance_metrics.keys, 'impressions'

    click_rate_metrics = performance_metrics['click_rate']
    assert click_rate_metrics[:count] > 0
    assert click_rate_metrics[:average] > 0

    # Step 6: Check test progress
    assert ab_test.reload.running?
    
    # Mock minimum sample size reached for test progression
    ab_test.update!(minimum_sample_size: 100) # Lower than current sample size
    
    # Step 7: Generate performance report
    report = service.generate_performance_report
    
    assert_includes report.keys, :test_summary
    assert_includes report.keys, :current_results
    assert_includes report.keys, :performance_trends
    assert_includes report.keys, :recommendations

    test_summary = report[:test_summary]
    assert_equal ab_test.test_name, test_summary[:test_name]
    assert_equal 'active', test_summary[:status]
    assert test_summary[:total_sample_size] > 0

    # Step 8: Stop the test early for analysis
    stop_result = service.stop_test('Sufficient data collected for decision')
    
    assert stop_result
    ab_test.reload
    assert_equal 'stopped', ab_test.status
    assert ab_test.stopped?
    assert_not_nil ab_test.end_date
    assert_equal 'Sufficient data collected for decision', ab_test.metadata['stop_reason']

    # Step 9: Verify final state
    variant_a.reload
    assert_equal 'stopped', variant_a.status
    
    # Step 10: Generate final report
    final_report = service.generate_performance_report
    assert_not_nil final_report[:test_summary]
    assert_equal 'stopped', final_report[:test_summary][:status]
  end

  test "A/B test with multiple variants workflow" do
    # Create additional content for more variants
    variant_content_2 = GeneratedContent.create!(
      title: 'Email Variant 2',
      body_content: 'Second email variant with sufficient content length to pass all validations and meet the minimum character requirement for standard format which needs at least one hundred characters of content to be considered valid for testing purposes.',
      content_type: 'email',
      format_variant: 'standard',
      status: 'draft',
      campaign_plan: @campaign_plan,
      created_by: @user
    )

    variant_content_3 = GeneratedContent.create!(
      title: 'Email Variant 3',
      body_content: 'Third email variant with sufficient content length to pass all validations and meet the minimum character requirement for standard format which needs at least one hundred characters of content to be considered valid for testing purposes.',
      content_type: 'email',
      format_variant: 'standard',
      status: 'draft',
      campaign_plan: @campaign_plan,
      created_by: @user
    )

    # Step 1: Create A/B test with multiple variants
    service = ContentAbTestService.new(nil, @user)
    content_variants = [@control_content, @variant_content, variant_content_2, variant_content_3]
    
    ab_test = service.bulk_create_from_content_variants(content_variants, {
      test_name: 'Multi-Variant Email Test',
      primary_goal: 'conversion_rate',
      confidence_level: '99',
      traffic_allocation: 100,
      minimum_sample_size: 400,
      test_duration_days: 21,
      description: 'Testing multiple email variants for best performance'
    })

    assert ab_test
    assert ab_test.persisted?
    assert_equal @control_content, ab_test.control_content
    assert_equal 3, ab_test.content_ab_test_variants.count # Excludes control

    variants = ab_test.content_ab_test_variants.order(:id)
    
    # Check traffic distribution (should be equal)
    expected_split = 100.0 / 3 # 33.33% each
    variants.each do |variant|
      assert_in_delta expected_split, variant.traffic_split, 0.1
    end

    # Step 2: Start the multi-variant test
    start_result = service.start_test
    
    assert start_result
    ab_test.reload
    assert ab_test.active?

    # Step 3: Record differentiated performance for each variant
    variants.each_with_index do |variant, index|
      base_performance = 2.0 + (index * 0.5) # Different performance levels
      
      5.times do |day|
        date = day.days.ago.to_date
        
        # Simulate different performance patterns
        daily_conversions = base_performance + (day * 0.1)
        sample_size = 80 + (index * 10) # Different sample sizes
        
        variant.record_result!('conversion_rate', daily_conversions, sample_size, date)
        variant.record_result!('click_rate', daily_conversions * 1.5, sample_size, date)
      end
    end

    # Step 4: Analyze comparative performance
    ab_test.reload
    current_results = ab_test.current_results
    
    assert_includes current_results.keys, :control
    assert_includes current_results.keys, :variants
    assert_equal 3, current_results[:variants].count

    # Check that each variant has recorded metrics
    current_results[:variants].each do |variant_result|
      assert_includes variant_result[:metrics].keys, 'conversion_rate'
      assert_includes variant_result[:metrics].keys, 'click_rate'
      assert variant_result[:sample_size] > 0
    end

    # Step 5: Find the best performing variant
    best_variant_data = current_results[:variants].max_by do |v| 
      v[:metrics]['conversion_rate'] || 0 
    end
    
    assert_not_nil best_variant_data
    assert best_variant_data[:metrics]['conversion_rate'] > 0

    # Step 6: Complete the test
    # Mock conditions for completion
    ab_test.update!(minimum_sample_size: 100) # Lower threshold for testing
    
    complete_result = service.complete_test
    
    assert complete_result
    ab_test.reload
    assert ab_test.completed?
    assert_not_nil ab_test.end_date

    # Verify final results
    final_report = service.generate_performance_report
    assert_equal 'completed', final_report[:test_summary][:status]
  end

  test "A/B test pause and resume workflow" do
    # Step 1: Set up and start test
    ab_test = ContentAbTest.create!(
      test_name: 'Pausable A/B Test',
      status: 'draft',
      primary_goal: 'engagement_rate',
      confidence_level: '95',
      traffic_allocation: 100,
      minimum_sample_size: 150,
      test_duration_days: 10,
      campaign_plan: @campaign_plan,
      created_by: @user,
      control_content: @control_content
    )

    variant = ab_test.add_variant!(@variant_content, variant_name: 'Test Variant', traffic_split: 50)
    service = ContentAbTestService.new(ab_test, @user)
    
    # Start test
    assert service.start_test
    ab_test.reload
    assert ab_test.active?

    # Step 2: Record some initial results
    variant.record_result!('engagement_rate', 3.5, 50)
    variant.record_result!('click_rate', 2.8, 50)

    # Step 3: Pause the test
    pause_reason = 'Need to review preliminary results'
    pause_result = service.pause_test(pause_reason)
    
    assert pause_result
    ab_test.reload
    assert ab_test.paused?
    assert_equal pause_reason, ab_test.metadata['reason']

    # Variant should also be paused
    variant.reload
    assert variant.paused?

    # Step 4: Try to record results while paused (should still work)
    variant.record_result!('engagement_rate', 3.8, 25)
    assert_equal 2, variant.content_ab_test_results.where(metric_name: 'engagement_rate').count

    # Step 5: Resume the test
    resume_reason = 'Review completed, continuing test'
    resume_result = service.resume_test(resume_reason)
    
    assert resume_result
    ab_test.reload
    assert ab_test.active?
    assert_equal resume_reason, ab_test.metadata['reason']

    # Variant should be active again
    variant.reload
    assert variant.active?

    # Step 6: Continue recording results after resume
    variant.record_result!('engagement_rate', 4.2, 75)
    variant.record_result!('conversion_rate', 1.8, 75)

    # Step 7: Verify all results were recorded properly
    assert variant.content_ab_test_results.count >= 4
    
    # Check performance metrics include all recorded data
    performance = variant.performance_metrics
    assert_includes performance.keys, 'engagement_rate'
    assert_includes performance.keys, 'click_rate'
    assert_includes performance.keys, 'conversion_rate'

    # Engagement rate should show improvement trend
    engagement_metrics = performance['engagement_rate']
    assert engagement_metrics[:count] >= 3
    assert engagement_metrics[:average] > 3.5
  end

  test "A/B test error handling and recovery workflow" do
    # Step 1: Create test with potential issues
    ab_test = ContentAbTest.create!(
      test_name: 'Error Handling Test',
      status: 'draft',
      primary_goal: 'click_rate',
      confidence_level: '95',
      traffic_allocation: 100,
      minimum_sample_size: 100,
      test_duration_days: 7,
      campaign_plan: @campaign_plan,
      created_by: @user,
      control_content: @control_content
    )

    service = ContentAbTestService.new(ab_test, @user)

    # Step 2: Try to start test without variants (should fail)
    start_result = service.start_test
    
    assert_not start_result
    assert_not_empty service.errors
    assert ab_test.reload.draft? # Should remain draft

    # Step 3: Add variant and start successfully
    variant = ab_test.add_variant!(@variant_content, variant_name: 'Recovery Variant', traffic_split: 50)
    
    start_result = service.start_test
    assert start_result
    assert ab_test.reload.active?

    # Step 4: Try to record invalid results
    invalid_results = [
      {
        variant_id: 99999, # Non-existent variant
        metric_name: 'click_rate',
        metric_value: 2.5,
        sample_size: 100
      }
    ]

    recorded_count = service.record_results(invalid_results)
    assert_equal 0, recorded_count # Should record nothing

    # Step 5: Record valid results to recover
    valid_results = [
      {
        variant_id: variant.id,
        metric_name: 'click_rate',
        metric_value: 2.8,
        sample_size: 100
      }
    ]

    recorded_count = service.record_results(valid_results)
    assert_equal 1, recorded_count
    assert_equal 1, variant.content_ab_test_results.count

    # Step 6: Try operations on wrong test state
    # Complete the test first
    service.stop_test('Test completed')
    ab_test.reload
    assert ab_test.stopped?

    # Try to add variant to stopped test (should fail)
    add_result = service.add_variant(@control_content)
    assert_not add_result
    assert_not_empty service.errors

    # Try to start stopped test (should fail)
    start_again_result = service.start_test
    assert_not start_again_result
    assert_not_empty service.errors

    # Step 7: Verify test state is consistent despite errors
    ab_test.reload
    assert ab_test.stopped? # Should still be stopped
    assert_equal 1, ab_test.content_ab_test_variants.count # Should still have 1 variant
  end

  test "A/B test data integrity throughout workflow" do
    # Step 1: Create test and track initial state
    ab_test = ContentAbTest.create!(
      test_name: 'Data Integrity Test',
      status: 'draft',
      primary_goal: 'conversion_rate',
      confidence_level: '95',
      traffic_allocation: 100,
      minimum_sample_size: 200,
      test_duration_days: 14,
      campaign_plan: @campaign_plan,
      created_by: @user,
      control_content: @control_content
    )

    initial_created_at = ab_test.created_at
    initial_test_name = ab_test.test_name

    # Step 2: Add variants and verify relationships
    variant_a = ab_test.add_variant!(@variant_content, variant_name: 'Variant A', traffic_split: 50)
    
    assert_equal ab_test, variant_a.content_ab_test
    assert_equal @variant_content, variant_a.generated_content
    assert_equal @campaign_plan, variant_a.generated_content.campaign_plan
    
    # Verify campaign consistency
    assert_equal ab_test.campaign_plan, variant_a.generated_content.campaign_plan

    # Step 3: Start test and verify timestamps
    service = ContentAbTestService.new(ab_test, @user)
    service.start_test
    
    ab_test.reload
    assert_not_nil ab_test.start_date
    assert_not_nil ab_test.end_date
    assert ab_test.end_date > ab_test.start_date
    assert_equal initial_created_at, ab_test.created_at # Should not change
    assert_equal initial_test_name, ab_test.test_name # Should not change

    # Step 4: Record results and verify data consistency
    sample_dates = [Date.current, 1.day.ago.to_date, 2.days.ago.to_date]
    total_samples = 0

    sample_dates.each_with_index do |date, index|
      sample_size = 80 + (index * 10)  # This will give us 80, 90, 100 = 270 total
      conversion_rate = 2.0 + (index * 0.3)
      
      variant_a.record_result!('conversion_rate', conversion_rate, sample_size, date)
      total_samples += sample_size
    end

    # Verify sample size tracking
    variant_a.reload
    assert_equal total_samples, variant_a.sample_size

    # Verify individual results
    results = variant_a.content_ab_test_results.order(:recorded_date)
    assert_equal sample_dates.count, results.count
    
    # Since results are ordered by recorded_date (ascending), we need to reverse the sample_dates for comparison
    sorted_sample_dates = sample_dates.sort
    results.each_with_index do |result, index|
      assert_equal sorted_sample_dates[index], result.recorded_date
      assert_equal variant_a, result.content_ab_test_variant
      assert_equal ab_test, result.content_ab_test
      assert_equal @variant_content, result.generated_content
    end

    # Step 5: Verify aggregated data accuracy
    performance_metrics = variant_a.performance_metrics
    conversion_metrics = performance_metrics['conversion_rate']
    
    expected_total = sample_dates.each_with_index.sum { |date, index| 2.0 + (index * 0.3) }
    expected_average = expected_total / sample_dates.count
    
    assert_in_delta expected_average, conversion_metrics[:average], 0.01
    assert_equal expected_total, conversion_metrics[:total]
    assert_equal sample_dates.count, conversion_metrics[:count]

    # Step 6: Complete test and verify final state integrity
    complete_result = service.complete_test
    assert complete_result, "Failed to complete test: #{service.errors.join(', ')}"
    
    ab_test.reload
    variant_a.reload
    
    assert ab_test.completed?
    assert variant_a.completed?
    assert_not_nil ab_test.end_date
    
    # Verify metadata consistency
    assert_not_nil ab_test.metadata['completed_at']
    assert_not_nil variant_a.metadata['completed_at']
    
    # Verify relationships are maintained
    assert_equal ab_test, variant_a.content_ab_test
    assert_equal @campaign_plan, ab_test.campaign_plan
    assert_equal @user, ab_test.created_by
    assert_equal @control_content, ab_test.control_content
    
    # Verify sample size consistency
    total_recorded_samples = variant_a.content_ab_test_results.sum(:sample_size)
    assert_equal variant_a.sample_size, total_recorded_samples
  end

  test "A/B test performance comparison workflow" do
    # Step 1: Create test with two distinct variants
    ab_test = ContentAbTest.create!(
      test_name: 'Performance Comparison Test',
      status: 'draft',
      primary_goal: 'click_rate',
      confidence_level: '95',
      traffic_allocation: 100,
      minimum_sample_size: 300,
      test_duration_days: 14,
      campaign_plan: @campaign_plan,
      created_by: @user,
      control_content: @control_content
    )

    # Create a second variant content for better comparison
    variant_content_2 = GeneratedContent.create!(
      title: 'High Performance Variant',
      body_content: 'This is a high-performance variant designed to outperform the control with sufficient content length to pass all validations and meet the minimum character requirement for standard format which needs at least one hundred characters of content.',
      content_type: 'email',
      format_variant: 'standard',
      status: 'draft',
      campaign_plan: @campaign_plan,
      created_by: @user
    )

    variant_a = ab_test.add_variant!(@variant_content, variant_name: 'Standard Variant', traffic_split: 50)
    variant_b = ab_test.add_variant!(variant_content_2, variant_name: 'High Performance Variant', traffic_split: 50)

    # Step 2: Start test and record differentiated performance
    service = ContentAbTestService.new(ab_test, @user)
    service.start_test

    ab_test.reload
    assert ab_test.active?

    # Record different performance levels for each variant
    test_period_days = 7

    test_period_days.times do |day|
      date = day.days.ago.to_date
      
      # Variant A: Moderate performance
      variant_a.record_result!('impressions', 1000, 50, date)
      variant_a.record_result!('clicks', 20 + day, 50, date)
      variant_a.record_result!('conversions', 2 + (day * 0.2), 50, date)
      variant_a.record_result!('click_rate', ((20 + day).to_f / 1000 * 100).round(2), 50, date)
      
      # Variant B: Higher performance
      variant_b.record_result!('impressions', 1000, 50, date)
      variant_b.record_result!('clicks', 35 + day, 50, date)
      variant_b.record_result!('conversions', 4 + (day * 0.3), 50, date)
      variant_b.record_result!('click_rate', ((35 + day).to_f / 1000 * 100).round(2), 50, date)
    end

    # Step 3: Analyze comparative performance
    variant_a.reload
    variant_b.reload

    perf_a = variant_a.performance_metrics
    perf_b = variant_b.performance_metrics

    # Variant B should outperform Variant A
    assert perf_b['click_rate'][:average] > perf_a['click_rate'][:average]
    assert perf_b['conversions'][:total] > perf_a['conversions'][:total]

    # Step 4: Compare variants directly (note: control has no recorded results in this test)
    comparison_a = variant_a.compare_with_control
    comparison_b = variant_b.compare_with_control

    # Comparison should be empty if no control results are recorded
    assert comparison_a.is_a?(Hash)
    assert comparison_b.is_a?(Hash)

    # Step 5: Generate comprehensive performance report
    report = service.generate_performance_report

    current_results = report[:current_results]
    variants_data = current_results[:variants]
    
    assert_equal 2, variants_data.count

    variant_a_data = variants_data.find { |v| v[:variant_name] == 'Standard Variant' }
    variant_b_data = variants_data.find { |v| v[:variant_name] == 'High Performance Variant' }

    assert_not_nil variant_a_data
    assert_not_nil variant_b_data

    # Verify performance data structure
    %w[click_rate conversions impressions].each do |metric|
      assert_includes variant_a_data[:metrics].keys, metric
      assert_includes variant_b_data[:metrics].keys, metric
    end

    # Variant B should show better metrics
    assert variant_b_data[:metrics]['click_rate'] > variant_a_data[:metrics]['click_rate']

    # Step 6: Check performance trends
    trends = report[:performance_trends]
    
    assert_includes trends.keys, 'Standard Variant'
    assert_includes trends.keys, 'High Performance Variant'

    variant_a_trends = trends['Standard Variant']
    variant_b_trends = trends['High Performance Variant']

    # Both should have trend data
    assert_not_empty variant_a_trends
    assert_not_empty variant_b_trends

    # Step 7: Complete test and verify winner detection
    service.complete_test

    ab_test.reload
    assert ab_test.completed?

    # Generate final report with winner
    final_report = service.generate_performance_report
    
    # Should have key insights about performance differences
    assert_includes final_report.keys, :recommendations
    recommendations = final_report[:recommendations]
    
    # Should have some recommendations (may include future testing, sample size, etc.)
    assert_not_empty recommendations
    
    # Verify recommendations are properly structured
    recommendations.each do |r|
      assert_includes r.keys, :type
      assert_includes r.keys, :message
      assert_includes r.keys, :priority
    end
  end
end