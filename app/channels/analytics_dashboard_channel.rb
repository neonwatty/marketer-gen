# frozen_string_literal: true

# ActionCable channel for real-time analytics dashboard updates
# Streams live metrics from Google Analytics, Social Media, Email, and CRM integrations
class AnalyticsDashboardChannel < ApplicationCable::Channel
  def subscribed
    # Verify user authentication
    return reject unless current_user

    # Subscribe to user's analytics stream
    stream_for current_user
    
    # Subscribe to brand-specific analytics if brand_id provided
    if params[:brand_id].present?
      brand = current_user.brands.find_by(id: params[:brand_id])
      stream_for brand if brand
    end

    # Log subscription for monitoring
    Rails.logger.info "User #{current_user.id} subscribed to analytics dashboard"
    
    # Send initial connection confirmation
    transmit({
      type: 'connection_established',
      timestamp: Time.current.iso8601,
      user_id: current_user.id,
      brand_id: params[:brand_id]
    })
  end

  def unsubscribed
    Rails.logger.info "User #{current_user&.id} unsubscribed from analytics dashboard"
  end

  # Handle real-time metric requests
  def request_metrics(data)
    return unless current_user

    metric_type = data['metric_type']
    time_range = data['time_range'] || '24h'
    brand_id = data['brand_id']

    case metric_type
    when 'social_media'
      broadcast_social_media_metrics(brand_id, time_range)
    when 'email'
      broadcast_email_metrics(brand_id, time_range)
    when 'google_analytics'
      broadcast_google_analytics_metrics(brand_id, time_range)
    when 'crm'
      broadcast_crm_metrics(brand_id, time_range)
    when 'all'
      broadcast_all_metrics(brand_id, time_range)
    else
      transmit_error("Unknown metric type: #{metric_type}")
    end
  rescue StandardError => e
    Rails.logger.error "Analytics channel error: #{e.message}"
    transmit_error("Failed to fetch metrics: #{e.message}")
  end

  # Handle custom metric builder requests
  def build_custom_metric(data)
    return unless current_user

    begin
      # Parse custom metric configuration
      metric_config = {
        name: data['name'],
        sources: data['sources'] || [],
        aggregation: data['aggregation'] || 'sum',
        time_range: data['time_range'] || '7d',
        filters: data['filters'] || {}
      }

      # Build and transmit custom metric
      result = build_custom_metric_data(metric_config, data['brand_id'])
      
      transmit({
        type: 'custom_metric_result',
        metric_name: metric_config[:name],
        data: result,
        timestamp: Time.current.iso8601
      })
    rescue StandardError => e
      transmit_error("Failed to build custom metric: #{e.message}")
    end
  end

  # Handle drill-down requests
  def drill_down(data)
    return unless current_user

    begin
      source = data['source'] # e.g., 'social_media', 'email'
      metric = data['metric'] # e.g., 'engagement_rate', 'click_rate'
      dimension = data['dimension'] # e.g., 'platform', 'campaign'
      filters = data['filters'] || {}

      result = perform_drill_down(source, metric, dimension, filters, data['brand_id'])
      
      transmit({
        type: 'drill_down_result',
        source: source,
        metric: metric,
        dimension: dimension,
        data: result,
        timestamp: Time.current.iso8601
      })
    rescue StandardError => e
      transmit_error("Failed to perform drill-down: #{e.message}")
    end
  end

  private

  def broadcast_social_media_metrics(brand_id, time_range)
    brand = find_brand(brand_id)
    return unless brand

    metrics = Analytics::SocialMediaIntegrationService.new(brand).real_time_metrics(time_range)
    
    transmit({
      type: 'social_media_metrics',
      data: metrics,
      time_range: time_range,
      timestamp: Time.current.iso8601
    })
  end

  def broadcast_email_metrics(brand_id, time_range)
    brand = find_brand(brand_id)
    return unless brand

    metrics = Analytics::EmailAnalyticsService.new(brand).real_time_metrics(time_range)
    
    transmit({
      type: 'email_metrics',
      data: metrics,
      time_range: time_range,
      timestamp: Time.current.iso8601
    })
  end

  def broadcast_google_analytics_metrics(brand_id, time_range)
    brand = find_brand(brand_id)
    return unless brand

    # Check if Google Analytics is connected
    return transmit_error("Google Analytics not connected") unless brand.google_analytics_connected?

    metrics = Analytics::GoogleAnalyticsService.new(
      user_id: current_user.id,
      property_id: brand.google_analytics_property_id
    ).real_time_metrics(time_range)
    
    transmit({
      type: 'google_analytics_metrics',
      data: metrics,
      time_range: time_range,
      timestamp: Time.current.iso8601
    })
  end

  def broadcast_crm_metrics(brand_id, time_range)
    brand = find_brand(brand_id)
    return unless brand

    metrics = Analytics::CrmAnalyticsService.new(brand).real_time_metrics(time_range)
    
    transmit({
      type: 'crm_metrics',
      data: metrics,
      time_range: time_range,
      timestamp: Time.current.iso8601
    })
  end

  def broadcast_all_metrics(brand_id, time_range)
    broadcast_social_media_metrics(brand_id, time_range)
    broadcast_email_metrics(brand_id, time_range)
    broadcast_google_analytics_metrics(brand_id, time_range)
    broadcast_crm_metrics(brand_id, time_range)
  end

  def build_custom_metric_data(config, brand_id)
    brand = find_brand(brand_id)
    return {} unless brand

    # Aggregate data from multiple sources based on configuration
    aggregated_data = {}
    
    config[:sources].each do |source|
      case source
      when 'social_media'
        data = Analytics::SocialMediaIntegrationService.new(brand).filtered_metrics(config)
        aggregated_data[:social_media] = data
      when 'email'
        data = Analytics::EmailAnalyticsService.new(brand).filtered_metrics(config)
        aggregated_data[:email] = data
      when 'google_analytics'
        if brand.google_analytics_connected?
          service = Analytics::GoogleAnalyticsService.new(
            user_id: current_user.id,
            property_id: brand.google_analytics_property_id
          )
          data = service.filtered_metrics(config)
          aggregated_data[:google_analytics] = data
        end
      when 'crm'
        data = Analytics::CrmAnalyticsService.new(brand).filtered_metrics(config)
        aggregated_data[:crm] = data
      end
    end

    # Apply aggregation logic
    apply_aggregation(aggregated_data, config[:aggregation])
  end

  def perform_drill_down(source, metric, dimension, filters, brand_id)
    brand = find_brand(brand_id)
    return {} unless brand

    case source
    when 'social_media'
      Analytics::SocialMediaIntegrationService.new(brand).drill_down(metric, dimension, filters)
    when 'email'
      Analytics::EmailAnalyticsService.new(brand).drill_down(metric, dimension, filters)
    when 'google_analytics'
      return {} unless brand.google_analytics_connected?
      
      service = Analytics::GoogleAnalyticsService.new(
        user_id: current_user.id,
        property_id: brand.google_analytics_property_id
      )
      service.drill_down(metric, dimension, filters)
    when 'crm'
      Analytics::CrmAnalyticsService.new(brand).drill_down(metric, dimension, filters)
    else
      {}
    end
  end

  def apply_aggregation(data, aggregation_type)
    case aggregation_type
    when 'sum'
      data.values.sum { |source_data| source_data.is_a?(Hash) ? source_data.values.sum : source_data }
    when 'average'
      values = data.values.flat_map { |source_data| source_data.is_a?(Hash) ? source_data.values : [source_data] }
      values.sum / values.size.to_f
    when 'max'
      data.values.flat_map { |source_data| source_data.is_a?(Hash) ? source_data.values : [source_data] }.max
    when 'min'
      data.values.flat_map { |source_data| source_data.is_a?(Hash) ? source_data.values : [source_data] }.min
    else
      data
    end
  end

  def find_brand(brand_id)
    return nil unless brand_id.present?
    
    current_user.brands.find_by(id: brand_id)
  end

  def transmit_error(message)
    transmit({
      type: 'error',
      message: message,
      timestamp: Time.current.iso8601
    })
  end

  def current_user
    # This should be set by ApplicationCable::Connection
    connection.current_user
  end
end