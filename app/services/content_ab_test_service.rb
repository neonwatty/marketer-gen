class ContentAbTestService
  attr_reader :test, :user, :errors

  def initialize(test, user)
    @test = test
    @user = user
    @errors = []
  end

  class << self
    def create_test(params, user)
      new(nil, user).create_test(params)
    end

    def setup_simple_ab_test(control_content, variant_content, test_params, user)
      new(nil, user).setup_simple_ab_test(control_content, variant_content, test_params)
    end

    def bulk_create_from_content_variants(content_variants, test_params, user)
      new(nil, user).bulk_create_from_content_variants(content_variants, test_params)
    end
  end

  def create_test(params)
    @errors.clear # Clear previous errors
    
    ActiveRecord::Base.transaction do
      @test = ContentAbTest.new(params.merge(created_by: user))

      if @test.save
        initialize_default_settings
        @test
      else
        @errors = @test.errors.full_messages
        false
      end
    end
  rescue => e
    @errors << "Failed to create A/B test: #{e.message}"
    false
  end

  def setup_simple_ab_test(control_content, variant_content, test_params = {})
    ActiveRecord::Base.transaction do
      # Create the A/B test
      @test = ContentAbTest.create!(
        test_params.merge(
          campaign_plan: control_content.campaign_plan,
          control_content: control_content,
          created_by: user,
          test_name: test_params[:test_name] || "#{control_content.title} vs #{variant_content.title}",
          status: "draft",
          primary_goal: test_params[:primary_goal] || "click_rate",
          confidence_level: test_params[:confidence_level] || "95",
          traffic_allocation: test_params[:traffic_allocation] || 100,
          minimum_sample_size: test_params[:minimum_sample_size] || 100,
          test_duration_days: test_params[:test_duration_days] || 14
        )
      )

      # Add the variant
      @test.add_variant!(
        variant_content,
        variant_name: test_params[:variant_name] || "Variant A",
        traffic_split: 50.0
      )

      initialize_default_settings
      @test
    end
  rescue => e
    @errors << "Failed to setup simple A/B test: #{e.message}"
    false
  end

  def bulk_create_from_content_variants(content_variants, test_params)
    if content_variants.empty?
      @errors << "Cannot create test: no content variants provided"
      return false
    end

    control_content = content_variants.first

    ActiveRecord::Base.transaction do
      @test = ContentAbTest.create!(
        test_params.merge(
          campaign_plan: control_content.campaign_plan,
          control_content: control_content,
          created_by: user,
          status: "draft"
        )
      )

      # Add all other contents as variants
      traffic_split = 100.0 / (content_variants.count - 1)

      content_variants[1..-1].each_with_index do |content, index|
        @test.add_variant!(
          content,
          variant_name: "Variant #{('A'.ord + index).chr}",
          traffic_split: traffic_split
        )
      end

      initialize_default_settings
      @test
    end
  rescue => e
    @errors << "Failed to bulk create A/B test: #{e.message}"
    false
  end

  def add_variant(content, variant_params = {})
    unless can_modify_test?
      @errors << "Cannot add variant to #{@test.status} test"
      return false
    end

    variant = @test.add_variant!(
      content,
      variant_name: variant_params[:variant_name],
      traffic_split: variant_params[:traffic_split]
    )

    if variant
      log_action("variant_added", { variant_name: variant.variant_name, content_id: content.id })
      variant
    else
      @errors << "Failed to add variant to test"
      false
    end
  rescue => e
    @errors << "Failed to add variant: #{e.message}"
    false
  end

  def remove_variant(variant)
    unless can_modify_test?
      @errors << "Cannot remove variant from #{@test.status} test"
      return false
    end
    
    unless variant.content_ab_test == @test
      @errors << "Variant does not belong to this test"
      return false
    end

    ActiveRecord::Base.transaction do
      variant_name = variant.variant_name
      content_id = variant.generated_content_id

      @test.remove_variant!(variant)
      log_action("variant_removed", { variant_name: variant_name, content_id: content_id })
      true
    end
  rescue => e
    @errors << "Failed to remove variant: #{e.message}"
    false
  end

  def start_test(start_params = {})
    @errors.clear # Clear previous errors
    
    unless @test.can_start?
      @errors << "Test cannot be started: must be in draft status and have variants"
      return false
    end

    ActiveRecord::Base.transaction do
      start_date = start_params[:start_date] || Time.current
      end_date = start_date + @test.test_duration_days.days
      
      @test.update!(end_date: end_date)

      if @test.start_test!(start_date)
        initialize_tracking_infrastructure
        notify_test_started
        log_action("test_started", { start_date: @test.start_date })
        true
      else
        @errors << "Failed to start test"
        false
      end
    end
  rescue => e
    @errors << "Failed to start test: #{e.message}"
    false
  end

  def pause_test(reason = nil)
    unless @test.active?
      @errors << "Test cannot be paused: must be in active status"
      return false
    end

    ActiveRecord::Base.transaction do
      @test.metadata = (@test.metadata || {}).merge(reason: reason) if reason
      if @test.pause_test!
        # Also pause all variants
        @test.content_ab_test_variants.update_all(status: 'paused')
        log_action("test_paused", { reason: reason })
        notify_test_paused(reason)
        true
      else
        @errors << "Failed to pause test"
        false
      end
    end
  rescue => e
    @errors << "Failed to pause test: #{e.message}"
    false
  end

  def resume_test(reason = nil)
    unless @test.paused?
      @errors << "Test cannot be resumed: must be in paused status"
      return false
    end

    ActiveRecord::Base.transaction do
      @test.metadata = (@test.metadata || {}).merge(reason: reason) if reason
      if @test.resume_test!
        # Also resume all variants
        @test.content_ab_test_variants.update_all(status: 'active')
        log_action("test_resumed", { reason: reason })
        notify_test_resumed(reason)
        true
      else
        @errors << "Failed to resume test"
        false
      end
    end
  rescue => e
    @errors << "Failed to resume test: #{e.message}"
    false
  end

  def stop_test(reason = nil)
    return false unless @test.active? || @test.paused?

    ActiveRecord::Base.transaction do
      if @test.stop_test!(reason)
        # Also stop all variants
        @test.content_ab_test_variants.update_all(status: 'stopped')
        generate_final_report
        notify_test_stopped(reason)
        log_action("test_stopped", { reason: reason })
        true
      else
        @errors << "Failed to stop test"
        false
      end
    end
  rescue => e
    @errors << "Failed to stop test: #{e.message}"
    false
  end

  def complete_test
    unless @test.can_complete?
      @errors << "Test cannot be completed: must be active and have minimum sample size"
      return false
    end

    ActiveRecord::Base.transaction do
      if @test.complete_test!
        # Also complete all variants
        @test.content_ab_test_variants.update_all(status: 'completed')
        final_report = generate_final_report
        notify_test_completed(final_report)
        log_action("test_completed", { winner: @test.winner_variant&.title })
        true
      else
        @errors << "Failed to complete test"
        false
      end
    end
  rescue => e
    @errors << "Failed to complete test: #{e.message}"
    false
  end

  def record_results(results_data)
    return false if results_data.blank?

    results_recorded = 0

    ActiveRecord::Base.transaction do
      results_data.each do |result|
        variant = find_variant(result[:variant_id] || result[:variant_name])
        next unless variant

        variant.record_result!(
          result[:metric_name],
          result[:metric_value],
          result[:sample_size] || 1,
          result[:date] || Date.current
        )

        results_recorded += 1
      end
    end

    if results_recorded > 0
      check_significance_after_results
      log_action("results_recorded", { count: results_recorded })
    end

    results_recorded
  rescue => e
    @errors << "Failed to record results: #{e.message}"
    0
  end

  def batch_record_results(variant_results_map)
    return false if variant_results_map.blank?

    total_recorded = 0

    ActiveRecord::Base.transaction do
      variant_results_map.each do |variant_identifier, results|
        variant = find_variant(variant_identifier)
        next unless variant

        recorded = variant.batch_record_results!(results)
        total_recorded += results.count if recorded
      end
    end

    if total_recorded > 0
      check_significance_after_results
      log_action("batch_results_recorded", { total_count: total_recorded })
    end

    total_recorded
  rescue => e
    @errors << "Failed to batch record results: #{e.message}"
    0
  end

  def generate_performance_report(date_range = nil)
    return {} unless @test.active? || @test.completed? || @test.stopped?

    date_range ||= (@test.start_date.to_date..Date.current)

    recommendations = @test.completed? ? generate_final_recommendations : generate_recommendations
    
    {
      test_summary: @test.test_summary,
      current_results: @test.current_results,
      performance_trends: generate_performance_trends(date_range),
      statistical_analysis: generate_statistical_analysis,
      recommendations: recommendations,
      export_data: generate_export_data(date_range)
    }
  end

  def clone_test(new_params = {})
    @errors.clear # Clear previous errors
    
    ActiveRecord::Base.transaction do
      cloned_test = @test.dup
      cloned_test.assign_attributes(
        new_params.merge(
          test_name: new_params[:test_name] || "#{@test.test_name} (Clone)",
          status: "draft",
          start_date: nil,
          end_date: nil,
          statistical_significance: false,
          winner_variant_id: nil,
          created_by: user
        )
      )

      if cloned_test.save
        # Clone variants
        @test.content_ab_test_variants.each do |variant|
          cloned_test.add_variant!(
            variant.generated_content,
            variant_name: variant.variant_name,
            traffic_split: variant.traffic_split
          )
        end

        cloned_service = ContentAbTestService.new(cloned_test, user)
        cloned_service.send(:initialize_default_settings)

        cloned_test
      else
        @errors.concat(cloned_test.errors.full_messages)
        false
      end
    end
  rescue => e
    @errors << "Failed to clone test: #{e.message}"
    false
  end

  private

  def can_modify_test?
    @test.present? && (@test.draft? || @test.paused?)
  end

  def initialize_default_settings
    return unless @test

    # Set default secondary goals based on primary goal
    secondary_goals = case @test.primary_goal
    when "conversion_rate"
      [ "click_rate", "engagement_rate" ]
    when "click_rate"
      [ "engagement_rate", "time_on_page" ]
    when "engagement_rate"
      [ "click_rate", "share_rate" ]
    else
      []
    end

    metadata = (@test.metadata || {}).merge(
      service_initialized: true,
      initialization_timestamp: Time.current,
      default_settings_applied: true
    )

    @test.update!(
      secondary_goals: secondary_goals,
      metadata: metadata
    )
  end

  def initialize_tracking_infrastructure
    # This would integrate with external tracking systems
    # For now, we'll just log the initialization
    Rails.logger.info "Initializing tracking infrastructure for A/B test #{@test.id}"

    # Example integrations that could happen here:
    # - Set up Google Analytics goals
    # - Configure marketing automation tracking
    # - Initialize webhook endpoints
    # - Set up real-time data collection
  end

  def find_variant(identifier)
    if identifier.is_a?(Integer)
      @test.content_ab_test_variants.find(identifier)
    else
      @test.content_ab_test_variants.find_by(variant_name: identifier.to_s)
    end
  rescue ActiveRecord::RecordNotFound
    nil
  end

  def check_significance_after_results
    return unless @test.active?
    return unless @test.minimum_sample_size_reached?

    if @test.statistical_significance_achieved?
      notify_significance_achieved

      # Auto-complete if configured
      if auto_complete_enabled?
        complete_test
      end
    end
  end

  def generate_performance_trends(date_range)
    trends = {}

    @test.content_ab_test_variants.includes(:content_ab_test_results).each do |variant|
      trends[variant.variant_name] = {}

      ContentAbTestResult::METRIC_TYPES.each do |metric|
        daily_data = variant.content_ab_test_results
                       .where(metric_name: metric, recorded_date: date_range)
                       .group(:recorded_date)
                       .order(:recorded_date)
                       .average(:metric_value)

        trends[variant.variant_name][metric] = daily_data if daily_data.any?
      end
    end

    trends
  end

  def generate_statistical_analysis
    return {} unless @test.active? || @test.completed?

    analysis = @test.current_results.dig(:statistical_analysis) || {}

    # Add additional analysis
    analysis[:test_power] = calculate_test_power
    analysis[:effect_size] = calculate_effect_size
    analysis[:confidence_intervals] = calculate_confidence_intervals

    analysis
  end

  def generate_recommendations
    recommendations = []

    # Sample size recommendations
    if !@test.minimum_sample_size_reached?
      needed = @test.minimum_sample_size - @test.content_ab_test_results.sum(:sample_size)
      recommendations << {
        type: "sample_size",
        message: "Collect #{needed} more samples to reach minimum sample size",
        priority: "high"
      }
    end

    # Duration recommendations
    if @test.active? && !@test.test_duration_reached?
      days_left = (@test.end_date.to_date - Date.current).to_i
      recommendations << {
        type: "duration",
        message: "Continue test for #{days_left} more days to reach planned duration",
        priority: "medium"
      }
    end

    # Statistical significance recommendations
    if @test.statistical_significance_achieved?
      winner_variant = @test.winner_variant
      recommendations << {
        type: "winner",
        message: "Statistically significant winner detected: #{winner_variant&.title}",
        priority: "high"
      }
    end

    recommendations
  end

  def generate_export_data(date_range)
    {
      test_details: @test.attributes,
      variants: @test.content_ab_test_variants.includes(:generated_content, :content_ab_test_results).map(&:detailed_analytics),
      results: @test.content_ab_test_results.where(recorded_date: date_range).map(&:to_analytics_hash),
      summary_metrics: @test.current_results
    }
  end

  def generate_final_report
    report = {
      test_summary: @test.test_summary,
      final_results: @test.current_results,
      winner: @test.winner_variant&.title,
      statistical_significance: @test.statistical_significance,
      total_sample_size: @test.content_ab_test_results.sum(:sample_size),
      test_duration: (@test.end_date - @test.start_date).to_i / 1.day,
      key_insights: generate_key_insights,
      recommendations: generate_final_recommendations
    }

    # Store report in test metadata
    @test.update!(
      metadata: (@test.metadata || {}).merge(
        final_report: report,
        final_report_generated_at: Time.current
      )
    )

    report
  end

  def generate_key_insights
    insights = []

    # Performance insights
    best_metric = @test.current_results.dig(:variants)&.max_by { |v| v[:metrics][@test.primary_goal.to_s] }
    if best_metric
      insights << "Best performing variant: #{best_metric[:variant_name]} with #{@test.primary_goal} of #{best_metric[:metrics][@test.primary_goal.to_s]}%"
    end

    # Traffic insights
    total_traffic = @test.content_ab_test_results.sum(:sample_size)
    insights << "Total traffic tested: #{total_traffic} users"

    # Duration insights
    if @test.start_date && @test.end_date
      duration = ((@test.end_date - @test.start_date) / 1.day).round(1)
      insights << "Test duration: #{duration} days"
    end

    insights
  end

  def generate_final_recommendations
    recommendations = generate_recommendations

    # Add implementation recommendations
    if @test.winner_variant
      recommendations << {
        type: "implementation",
        message: "Implement winning variant: #{@test.winner_variant.title}",
        priority: "high"
      }
    end

    # Add future test recommendations
    recommendations << {
      type: "future_testing",
      message: "Consider testing additional variations of the winning approach",
      priority: "low"
    }

    recommendations
  end

  def calculate_test_power
    # Simplified test power calculation
    # In production, use proper statistical libraries
    return 0.8 if @test.minimum_sample_size_reached?

    current_size = @test.content_ab_test_results.sum(:sample_size)
    (current_size.to_f / @test.minimum_sample_size).round(2)
  end

  def calculate_effect_size
    # Simplified effect size calculation
    return 0.0 unless @test.current_results.dig(:variants)&.count.to_i > 0

    control_value = @test.current_results.dig(:control, :metrics, @test.primary_goal.to_s) || 0
    best_variant = @test.current_results.dig(:variants)&.max_by { |v| v[:metrics][@test.primary_goal.to_s] }
    variant_value = best_variant&.dig(:metrics, @test.primary_goal.to_s) || 0

    return 0.0 if control_value.zero?

    ((variant_value - control_value) / control_value).round(4)
  end

  def calculate_confidence_intervals
    # Placeholder for confidence interval calculations
    # In production, implement proper statistical calculations
    {}
  end

  def auto_complete_enabled?
    @test.metadata&.dig("auto_stop_enabled") == true
  end

  def log_action(action, details = {})
    Rails.logger.info "A/B Test #{@test.id} - #{action}: #{details.to_json}"
  end

  def notify_test_started
    # Implement notification logic (email, Slack, webhooks, etc.)
    Rails.logger.info "A/B Test '#{@test.test_name}' has been started"
  end

  def notify_test_paused(reason)
    Rails.logger.info "A/B Test '#{@test.test_name}' has been paused. Reason: #{reason}"
  end

  def notify_test_resumed(reason)
    Rails.logger.info "A/B Test '#{@test.test_name}' has been resumed. Reason: #{reason}"
  end

  def notify_test_stopped(reason)
    Rails.logger.info "A/B Test '#{@test.test_name}' has been stopped. Reason: #{reason}"
  end

  def notify_test_completed(report)
    Rails.logger.info "A/B Test '#{@test.test_name}' has been completed. Winner: #{report[:winner]}"
  end

  def notify_significance_achieved
    Rails.logger.info "A/B Test '#{@test.test_name}' has achieved statistical significance"
  end
end
