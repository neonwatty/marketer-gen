# frozen_string_literal: true

module Analytics
  class CrmAnalyticsService
    include ActiveModel::Model
    include RateLimitingService

    attr_accessor :brand, :date_range, :crm_integrations

    def initialize(brand:, date_range: nil)
      @brand = brand
      @date_range = date_range || default_date_range
      @crm_integrations = brand.crm_integrations.active
    end

    # Generate comprehensive analytics across all CRM integrations
    def generate_comprehensive_analytics
      with_rate_limiting("crm_analytics_comprehensive", user_id: brand.user_id) do
        analytics_data = {
          summary: generate_summary_metrics,
          lead_metrics: generate_lead_metrics,
          opportunity_metrics: generate_opportunity_metrics,
          conversion_metrics: generate_conversion_metrics,
          pipeline_metrics: generate_pipeline_metrics,
          attribution_metrics: generate_attribution_metrics,
          time_metrics: generate_time_based_metrics,
          platform_breakdown: generate_platform_breakdown,
          trends: generate_trend_analysis
        }

        # Store analytics in database
        store_analytics_data(analytics_data)

        ServiceResult.success(data: analytics_data)
      end
    rescue => e
      Rails.logger.error "CRM analytics generation failed for brand #{brand.id}: #{e.message}"
      ServiceResult.failure("Analytics generation failed: #{e.message}")
    end

    # Generate analytics for a specific CRM integration
    def generate_integration_analytics(integration)
      with_rate_limiting("#{integration.platform}_analytics", user_id: brand.user_id) do
        analytics_data = {
          integration_id: integration.id,
          platform: integration.platform,
          date_range: @date_range,
          lead_metrics: calculate_integration_lead_metrics(integration),
          opportunity_metrics: calculate_integration_opportunity_metrics(integration),
          conversion_metrics: calculate_integration_conversion_metrics(integration),
          pipeline_metrics: calculate_integration_pipeline_metrics(integration),
          sync_health: calculate_sync_health_metrics(integration)
        }

        ServiceResult.success(data: analytics_data)
      end
    rescue => e
      Rails.logger.error "Integration analytics failed for #{integration.platform}: #{e.message}"
      ServiceResult.failure("Integration analytics failed: #{e.message}")
    end

    # Calculate conversion rates from marketing to sales
    def calculate_conversion_rates
      total_leads = leads_in_range.count
      return zero_conversion_rates if total_leads == 0

      mql_count = leads_in_range.marketing_qualified.count
      sql_count = leads_in_range.sales_qualified.count
      converted_count = leads_in_range.converted.count

      total_opportunities = opportunities_in_range.count
      won_opportunities = opportunities_in_range.won.count

      {
        lead_to_mql_rate: calculate_percentage(mql_count, total_leads),
        mql_to_sql_rate: calculate_percentage(sql_count, mql_count),
        sql_to_opportunity_rate: calculate_percentage(total_opportunities, sql_count),
        lead_to_opportunity_rate: calculate_percentage(total_opportunities, total_leads),
        opportunity_to_customer_rate: calculate_percentage(won_opportunities, total_opportunities),
        overall_conversion_rate: calculate_percentage(won_opportunities, total_leads),
        conversion_counts: {
          total_leads: total_leads,
          mql_count: mql_count,
          sql_count: sql_count,
          opportunity_count: total_opportunities,
          won_count: won_opportunities,
          converted_lead_count: converted_count
        }
      }
    end

    # Calculate pipeline velocity metrics
    def calculate_pipeline_velocity
      open_opportunities = opportunities_in_range.open
      closed_opportunities = opportunities_in_range.closed

      return zero_pipeline_metrics if open_opportunities.empty? && closed_opportunities.empty?

      total_pipeline_value = open_opportunities.sum(:amount) || 0
      weighted_pipeline_value = open_opportunities.sum(&:weighted_amount)
      average_deal_size = opportunities_in_range.average(:amount) || 0
      average_sales_cycle = closed_opportunities.where.not(days_to_close: nil).average(:days_to_close) || 0

      # Calculate velocity (deal value / time in pipeline)
      velocity_scores = open_opportunities.map(&:pipeline_velocity_score).compact
      average_velocity = velocity_scores.any? ? velocity_scores.sum / velocity_scores.length : 0

      {
        total_pipeline_value: total_pipeline_value,
        weighted_pipeline_value: weighted_pipeline_value,
        pipeline_count: open_opportunities.count,
        average_deal_size: average_deal_size,
        average_sales_cycle_days: average_sales_cycle,
        pipeline_velocity: average_velocity,
        stage_breakdown: calculate_stage_breakdown(open_opportunities),
        risk_assessment: calculate_pipeline_risks(open_opportunities)
      }
    end

    # Calculate attribution metrics for marketing campaigns
    def calculate_attribution_metrics
      leads_with_attribution = leads_in_range.where.not(original_campaign: nil)
      opportunities_with_attribution = opportunities_in_range.where.not(original_campaign: nil)

      campaign_attribution = {}

      # Process lead attribution
      leads_with_attribution.group(:original_campaign).each do |campaign, leads|
        campaign_attribution[campaign] ||= { leads: 0, opportunities: 0, revenue: 0.0 }
        campaign_attribution[campaign][:leads] = leads.count
      end

      # Process opportunity attribution
      opportunities_with_attribution.includes(:crm_integration).group(:original_campaign).each do |campaign, opportunities|
        campaign_attribution[campaign] ||= { leads: 0, opportunities: 0, revenue: 0.0 }
        campaign_attribution[campaign][:opportunities] = opportunities.count
        campaign_attribution[campaign][:revenue] = opportunities.won.sum(:amount) || 0.0
      end

      # Calculate ROI for each campaign
      campaign_attribution.each do |campaign, metrics|
        if metrics[:leads] > 0
          metrics[:revenue_per_lead] = metrics[:revenue] / metrics[:leads]
          metrics[:conversion_rate] = (metrics[:opportunities].to_f / metrics[:leads] * 100).round(2)
        else
          metrics[:revenue_per_lead] = 0
          metrics[:conversion_rate] = 0
        end
      end

      {
        total_attributed_leads: leads_with_attribution.count,
        total_attributed_opportunities: opportunities_with_attribution.count,
        total_attributed_revenue: opportunities_with_attribution.won.sum(:amount) || 0.0,
        attribution_rate: calculate_percentage(leads_with_attribution.count, leads_in_range.count),
        campaign_breakdown: campaign_attribution.sort_by { |_, metrics| -metrics[:revenue] }.to_h,
        top_performing_campaigns: campaign_attribution.sort_by { |_, metrics| -metrics[:revenue] }.first(5).to_h
      }
    end

    # Calculate time-based metrics (velocity, progression)
    def calculate_time_metrics
      qualified_leads = leads_in_range.where.not(mql_date: nil)
      converted_leads = leads_in_range.converted.where.not(converted_at: nil)
      closed_opportunities = opportunities_in_range.closed.where.not(closed_at: nil)

      {
        average_time_to_mql: calculate_average_time_to_mql(qualified_leads),
        average_time_to_sql: calculate_average_time_to_sql(qualified_leads),
        average_time_to_conversion: calculate_average_time_to_conversion(converted_leads),
        average_sales_cycle: calculate_average_sales_cycle(closed_opportunities),
        lifecycle_progression: calculate_lifecycle_progression_times,
        velocity_trends: calculate_velocity_trends
      }
    end

    # Generate platform-specific performance comparison
    def generate_platform_comparison
      platform_metrics = {}

      @crm_integrations.each do |integration|
        platform_metrics[integration.platform] = {
          total_leads: integration.crm_leads.count,
          total_opportunities: integration.crm_opportunities.count,
          total_revenue: integration.crm_opportunities.won.sum(:amount) || 0.0,
          conversion_rate: calculate_platform_conversion_rate(integration),
          average_deal_size: integration.crm_opportunities.average(:amount) || 0.0,
          sync_health_score: integration.sync_health_score,
          last_sync: integration.last_successful_sync_at
        }
      end

      {
        platform_breakdown: platform_metrics,
        best_performing_platform: platform_metrics.max_by { |_, metrics| metrics[:total_revenue] }&.first,
        platform_rankings: rank_platforms_by_performance(platform_metrics)
      }
    end

    # Export analytics data for reporting
    def export_analytics_report(format: :json)
      analytics_data = generate_comprehensive_analytics

      if analytics_data.success?
        case format.to_sym
        when :json
          ServiceResult.success(data: analytics_data.data.to_json)
        when :csv
          csv_data = convert_to_csv(analytics_data.data)
          ServiceResult.success(data: csv_data)
        when :xlsx
          # Would need to implement Excel export
          ServiceResult.failure("Excel export not yet implemented")
        else
          ServiceResult.failure("Unsupported export format: #{format}")
        end
      else
        analytics_data
      end
    end

    private

    def default_date_range
      30.days.ago.beginning_of_day..Time.current.end_of_day
    end

    def leads_in_range
      @leads_in_range ||= brand.crm_leads.where(created_at: @date_range)
    end

    def opportunities_in_range
      @opportunities_in_range ||= brand.crm_opportunities.where(created_at: @date_range)
    end

    def generate_summary_metrics
      {
        total_integrations: @crm_integrations.count,
        active_integrations: @crm_integrations.where(status: "active").count,
        total_leads: leads_in_range.count,
        total_opportunities: opportunities_in_range.count,
        total_revenue: opportunities_in_range.won.sum(:amount) || 0.0,
        date_range: @date_range,
        generated_at: Time.current
      }
    end

    def generate_lead_metrics
      total_leads = leads_in_range.count
      return {} if total_leads == 0

      {
        total_leads: total_leads,
        new_leads: leads_in_range.where(created_at: @date_range).count,
        marketing_qualified_leads: leads_in_range.marketing_qualified.count,
        sales_qualified_leads: leads_in_range.sales_qualified.count,
        converted_leads: leads_in_range.converted.count,
        lead_sources: leads_in_range.group(:source).count,
        lifecycle_distribution: leads_in_range.group(:lifecycle_stage).count,
        average_lead_score: calculate_average_lead_score,
        data_completeness: calculate_lead_data_completeness
      }
    end

    def generate_opportunity_metrics
      total_opportunities = opportunities_in_range.count
      return {} if total_opportunities == 0

      {
        total_opportunities: total_opportunities,
        new_opportunities: opportunities_in_range.where(created_at: @date_range).count,
        open_opportunities: opportunities_in_range.open.count,
        closed_opportunities: opportunities_in_range.closed.count,
        won_opportunities: opportunities_in_range.won.count,
        lost_opportunities: opportunities_in_range.lost.count,
        total_value: opportunities_in_range.sum(:amount) || 0.0,
        won_value: opportunities_in_range.won.sum(:amount) || 0.0,
        average_deal_size: opportunities_in_range.average(:amount) || 0.0,
        win_rate: calculate_percentage(opportunities_in_range.won.count, opportunities_in_range.closed.count),
        stage_distribution: opportunities_in_range.group(:stage).count,
        source_distribution: opportunities_in_range.group(:lead_source).count
      }
    end

    def generate_conversion_metrics
      calculate_conversion_rates
    end

    def generate_pipeline_metrics
      calculate_pipeline_velocity
    end

    def generate_attribution_metrics
      calculate_attribution_metrics
    end

    def generate_time_based_metrics
      calculate_time_metrics
    end

    def generate_platform_breakdown
      generate_platform_comparison
    end

    def generate_trend_analysis
      # Compare current period to previous period
      previous_range = calculate_previous_period(@date_range)

      current_leads = leads_in_range.count
      previous_leads = brand.crm_leads.where(created_at: previous_range).count

      current_opportunities = opportunities_in_range.count
      previous_opportunities = brand.crm_opportunities.where(created_at: previous_range).count

      current_revenue = opportunities_in_range.won.sum(:amount) || 0.0
      previous_revenue = brand.crm_opportunities.where(created_at: previous_range).won.sum(:amount) || 0.0

      {
        leads_trend: calculate_percentage_change(current_leads, previous_leads),
        opportunities_trend: calculate_percentage_change(current_opportunities, previous_opportunities),
        revenue_trend: calculate_percentage_change(current_revenue, previous_revenue),
        period_comparison: {
          current: { leads: current_leads, opportunities: current_opportunities, revenue: current_revenue },
          previous: { leads: previous_leads, opportunities: previous_opportunities, revenue: previous_revenue }
        }
      }
    end

    def store_analytics_data(analytics_data)
      @crm_integrations.each do |integration|
        CrmAnalytics.create!(
          crm_integration: integration,
          brand: brand,
          analytics_date: Date.current,
          metric_type: "daily",
          total_leads: analytics_data.dig(:lead_metrics, :total_leads) || 0,
          marketing_qualified_leads: analytics_data.dig(:lead_metrics, :marketing_qualified_leads) || 0,
          sales_qualified_leads: analytics_data.dig(:lead_metrics, :sales_qualified_leads) || 0,
          converted_leads: analytics_data.dig(:lead_metrics, :converted_leads) || 0,
          total_opportunities: analytics_data.dig(:opportunity_metrics, :total_opportunities) || 0,
          won_opportunities: analytics_data.dig(:opportunity_metrics, :won_opportunities) || 0,
          total_opportunity_value: analytics_data.dig(:opportunity_metrics, :total_value) || 0.0,
          won_opportunity_value: analytics_data.dig(:opportunity_metrics, :won_value) || 0.0,
          average_deal_size: analytics_data.dig(:opportunity_metrics, :average_deal_size) || 0.0,
          opportunity_win_rate: analytics_data.dig(:opportunity_metrics, :win_rate) || 0.0,
          pipeline_value: analytics_data.dig(:pipeline_metrics, :total_pipeline_value) || 0.0,
          pipeline_velocity: analytics_data.dig(:pipeline_metrics, :pipeline_velocity) || 0.0,
          overall_conversion_rate: analytics_data.dig(:conversion_metrics, :overall_conversion_rate) || 0.0,
          calculated_at: Time.current,
          raw_metrics: analytics_data
        )
      end
    rescue ActiveRecord::RecordInvalid => e
      Rails.logger.warn "Failed to store analytics data: #{e.message}"
    end

    # Helper calculation methods
    def calculate_percentage(numerator, denominator)
      return 0.0 if denominator == 0
      (numerator.to_f / denominator * 100).round(2)
    end

    def calculate_percentage_change(current, previous)
      return 0.0 if previous == 0
      ((current - previous).to_f / previous * 100).round(2)
    end

    def calculate_previous_period(range)
      duration = range.end - range.begin
      (range.begin - duration)..(range.begin)
    end

    def zero_conversion_rates
      {
        lead_to_mql_rate: 0.0,
        mql_to_sql_rate: 0.0,
        sql_to_opportunity_rate: 0.0,
        lead_to_opportunity_rate: 0.0,
        opportunity_to_customer_rate: 0.0,
        overall_conversion_rate: 0.0,
        conversion_counts: {
          total_leads: 0,
          mql_count: 0,
          sql_count: 0,
          opportunity_count: 0,
          won_count: 0,
          converted_lead_count: 0
        }
      }
    end

    def zero_pipeline_metrics
      {
        total_pipeline_value: 0.0,
        weighted_pipeline_value: 0.0,
        pipeline_count: 0,
        average_deal_size: 0.0,
        average_sales_cycle_days: 0.0,
        pipeline_velocity: 0.0,
        stage_breakdown: {},
        risk_assessment: {}
      }
    end

    def calculate_stage_breakdown(opportunities)
      opportunities.group(:stage).group(:pipeline_id).count
    end

    def calculate_pipeline_risks(opportunities)
      risks = {
        stalled_deals: opportunities.select { |opp| opp.days_in_current_stage > 30 }.count,
        overdue_deals: opportunities.select { |opp| opp.close_date && opp.close_date < Date.current }.count,
        high_risk_deals: opportunities.select { |opp| opp.risk_level == "high" }.count
      }

      risks[:total_risk_score] = risks.values.sum
      risks
    end

    def calculate_average_lead_score
      scores = leads_in_range.where.not(lead_score: nil).pluck(:lead_score).map(&:to_f)
      scores.any? ? scores.sum / scores.length : 0.0
    end

    def calculate_lead_data_completeness
      total_leads = leads_in_range.count
      return 0.0 if total_leads == 0

      completeness_scores = leads_in_range.map(&:data_completeness_score)
      completeness_scores.sum / total_leads
    end

    def calculate_platform_conversion_rate(integration)
      total_leads = integration.crm_leads.count
      return 0.0 if total_leads == 0

      won_opportunities = integration.crm_opportunities.won.count
      calculate_percentage(won_opportunities, total_leads)
    end

    def rank_platforms_by_performance(platform_metrics)
      platform_metrics.sort_by do |platform, metrics|
        # Composite score based on revenue, conversion rate, and sync health
        revenue_score = (metrics[:total_revenue] / 10000).clamp(0, 100)
        conversion_score = metrics[:conversion_rate]
        health_score = metrics[:sync_health_score]

        -(revenue_score * 0.5 + conversion_score * 0.3 + health_score * 0.2)
      end.to_h
    end

    def calculate_average_time_to_mql(qualified_leads)
      times = qualified_leads.map(&:time_to_mql).compact
      times.any? ? times.sum / times.length : 0.0
    end

    def calculate_average_time_to_sql(qualified_leads)
      times = qualified_leads.map(&:time_to_sql).compact
      times.any? ? times.sum / times.length : 0.0
    end

    def calculate_average_time_to_conversion(converted_leads)
      times = converted_leads.map(&:time_to_conversion).compact
      times.any? ? times.sum / times.length : 0.0
    end

    def calculate_average_sales_cycle(closed_opportunities)
      cycles = closed_opportunities.where.not(days_to_close: nil).pluck(:days_to_close)
      cycles.any? ? cycles.sum / cycles.length : 0.0
    end

    def calculate_lifecycle_progression_times
      # This would involve more complex calculations to track time spent in each lifecycle stage
      {}
    end

    def calculate_velocity_trends
      # Calculate velocity trends over time periods
      {}
    end

    def calculate_integration_lead_metrics(integration)
      integration_leads = integration.crm_leads.where(created_at: @date_range)

      {
        total_leads: integration_leads.count,
        marketing_qualified: integration_leads.marketing_qualified.count,
        sales_qualified: integration_leads.sales_qualified.count,
        converted: integration_leads.converted.count,
        average_score: integration_leads.where.not(lead_score: nil).average(:lead_score) || 0.0
      }
    end

    def calculate_integration_opportunity_metrics(integration)
      integration_opportunities = integration.crm_opportunities.where(created_at: @date_range)

      {
        total_opportunities: integration_opportunities.count,
        won_opportunities: integration_opportunities.won.count,
        total_value: integration_opportunities.sum(:amount) || 0.0,
        won_value: integration_opportunities.won.sum(:amount) || 0.0,
        win_rate: calculate_percentage(integration_opportunities.won.count, integration_opportunities.closed.count)
      }
    end

    def calculate_integration_conversion_metrics(integration)
      total_leads = integration.crm_leads.count
      won_opportunities = integration.crm_opportunities.won.count

      {
        overall_conversion_rate: calculate_percentage(won_opportunities, total_leads)
      }
    end

    def calculate_integration_pipeline_metrics(integration)
      open_opportunities = integration.crm_opportunities.open

      {
        pipeline_value: open_opportunities.sum(:amount) || 0.0,
        pipeline_count: open_opportunities.count,
        average_deal_size: open_opportunities.average(:amount) || 0.0
      }
    end

    def calculate_sync_health_metrics(integration)
      {
        sync_health_score: integration.sync_health_score,
        last_sync: integration.last_successful_sync_at,
        error_count: integration.consecutive_error_count,
        daily_stats: integration.daily_sync_stats
      }
    end

    def convert_to_csv(analytics_data)
      # Convert analytics data to CSV format
      # This would need CSV library and proper formatting
      "CSV export not yet implemented"
    end
  end
end
