class AbTestMonitoringChannel < ApplicationCable::Channel
  def subscribed
    ab_test = AbTest.find(params[:ab_test_id])
    
    # Ensure user has access to this A/B test
    reject unless can_access_ab_test?(ab_test)
    
    stream_from "ab_test_monitoring_#{params[:ab_test_id]}"
    
    # Send initial test data
    send_initial_test_data(ab_test)
    
    # Track user presence
    track_user_presence(ab_test)
  end

  def unsubscribed
    if params[:ab_test_id]
      ab_test = AbTest.find_by(id: params[:ab_test_id])
      if ab_test && can_access_ab_test?(ab_test)
        remove_user_presence(ab_test)
      end
    end
  end

  def receive_message(data)
    ab_test = AbTest.find(params[:ab_test_id])
    return unless can_access_ab_test?(ab_test)

    case data['type']
    when 'request_metrics_update'
      send_metrics_update(ab_test)
    when 'update_traffic_allocation'
      handle_traffic_allocation_update(ab_test, data)
    when 'heartbeat'
      handle_heartbeat(ab_test)
    end
  end

  private

  def can_access_ab_test?(ab_test)
    # Check if user can access this A/B test
    current_user == ab_test.user || 
    current_user == ab_test.campaign.user ||
    has_test_permission?(ab_test)
  end

  def has_test_permission?(ab_test)
    # For now, allow any authenticated user - can be tightened based on requirements
    true
  end

  def send_initial_test_data(ab_test)
    ActionCable.server.broadcast(
      "ab_test_monitoring_#{ab_test.id}",
      {
        type: 'initial_data',
        ab_test_id: ab_test.id,
        test_data: {
          name: ab_test.name,
          status: ab_test.status,
          test_type: ab_test.test_type,
          start_date: ab_test.start_date&.iso8601,
          end_date: ab_test.end_date&.iso8601,
          confidence_level: ab_test.confidence_level,
          significance_threshold: ab_test.significance_threshold,
          progress_percentage: ab_test.progress_percentage,
          statistical_significance_reached: ab_test.statistical_significance_reached?,
          winner_declared: ab_test.winner_declared?,
          winner_variant: ab_test.winner_variant&.name
        },
        variants: ab_test.ab_test_variants.map(&:monitoring_data),
        metrics: get_current_metrics(ab_test),
        timestamp: Time.current.iso8601,
        message_id: generate_message_id
      }
    )
  end

  def track_user_presence(ab_test)
    Rails.cache.write(
      "monitoring:ab_test:#{ab_test.id}:#{current_user.id}",
      {
        user: current_user_data,
        status: 'monitoring',
        last_seen: Time.current.iso8601,
        location: "ab_test_#{ab_test.id}"
      },
      expires_in: 10.minutes
    )
  end

  def remove_user_presence(ab_test)
    Rails.cache.delete("monitoring:ab_test:#{ab_test.id}:#{current_user.id}")
  end

  def send_metrics_update(ab_test)
    metrics_data = calculate_real_time_metrics(ab_test)
    
    ActionCable.server.broadcast(
      "ab_test_monitoring_#{ab_test.id}",
      {
        type: 'metrics_update',
        ab_test_id: ab_test.id,
        metrics: metrics_data,
        variants: ab_test.ab_test_variants.map(&:current_metrics),
        statistical_summary: ab_test.calculate_statistical_summary,
        timestamp: Time.current.iso8601,
        message_id: generate_message_id
      }
    )
  end

  def calculate_real_time_metrics(ab_test)
    variants_data = ab_test.ab_test_variants.map do |variant|
      previous_metrics = get_previous_metrics(variant)
      current_metrics = variant.current_metrics
      
      {
        variant_id: variant.id,
        variant_name: variant.name,
        is_control: variant.is_control,
        current_visitors: current_metrics[:total_visitors],
        current_conversions: current_metrics[:conversions],
        current_conversion_rate: current_metrics[:conversion_rate],
        traffic_percentage: variant.traffic_percentage,
        change_since_last_update: calculate_metric_changes(previous_metrics, current_metrics),
        confidence_interval: calculate_confidence_interval(variant),
        statistical_significance: variant.is_control? ? nil : calculate_significance_vs_control(ab_test, variant)
      }
    end

    {
      overall_visitors: variants_data.sum { |v| v[:current_visitors] },
      overall_conversions: variants_data.sum { |v| v[:current_conversions] },
      overall_conversion_rate: ab_test.calculate_overall_conversion_rate,
      test_duration_hours: ab_test.running? ? ((Time.current - ab_test.start_date) / 1.hour).round(1) : 0,
      progress_percentage: ab_test.progress_percentage,
      variants: variants_data,
      alerts: generate_real_time_alerts(ab_test, variants_data)
    }
  end

  def get_previous_metrics(variant)
    # Get metrics from 5 minutes ago for comparison
    cache_key = "variant_metrics:#{variant.id}:#{5.minutes.ago.to_i}"
    Rails.cache.read(cache_key) || variant.current_metrics
  end

  def calculate_metric_changes(previous, current)
    {
      visitors_change: current[:total_visitors] - (previous[:total_visitors] || 0),
      conversions_change: current[:conversions] - (previous[:conversions] || 0),
      conversion_rate_change: current[:conversion_rate] - (previous[:conversion_rate] || 0)
    }
  end

  def calculate_confidence_interval(variant)
    return [0, 0] if variant.total_visitors == 0

    p = variant.conversion_rate / 100.0
    n = variant.total_visitors

    # 95% confidence interval
    margin_of_error = 1.96 * Math.sqrt(p * (1 - p) / n)
    
    lower = [(p - margin_of_error) * 100, 0].max
    upper = [(p + margin_of_error) * 100, 100].min

    [lower.round(2), upper.round(2)]
  end

  def calculate_significance_vs_control(ab_test, variant)
    control = ab_test.ab_test_variants.find_by(is_control: true)
    return 0 unless control

    ab_test.send(:calculate_statistical_significance_between, control, variant)
  end

  def generate_real_time_alerts(ab_test, variants_data)
    alerts = []

    # Check for statistical significance
    if ab_test.statistical_significance_reached? && !ab_test.winner_declared?
      alerts << {
        level: 'success',
        message: 'Statistical significance reached! Consider declaring a winner.',
        action_required: true
      }
    end

    # Check for unusual traffic patterns
    variants_data.each do |variant_data|
      if variant_data[:change_since_last_update][:visitors_change] == 0 && ab_test.running?
        alerts << {
          level: 'warning',
          message: "No traffic to #{variant_data[:variant_name]} in the last 5 minutes",
          variant_id: variant_data[:variant_id]
        }
      end

      # Check for sudden conversion rate changes
      rate_change = variant_data[:change_since_last_update][:conversion_rate_change].abs
      if rate_change > 5.0 # More than 5% change
        alerts << {
          level: 'info',
          message: "#{variant_data[:variant_name]} conversion rate changed by #{rate_change.round(1)}%",
          variant_id: variant_data[:variant_id]
        }
      end
    end

    # Check test duration
    if ab_test.running? && ab_test.duration_days > 30
      alerts << {
        level: 'warning',
        message: 'Test has been running for over 30 days. Consider ending it.',
        action_required: true
      }
    end

    alerts
  end

  def handle_traffic_allocation_update(ab_test, data)
    return unless can_modify_test?(ab_test) && valid_traffic_data?(data)

    begin
      variant = ab_test.ab_test_variants.find(data['variant_id'])
      old_percentage = variant.traffic_percentage
      
      variant.update!(traffic_percentage: data['new_percentage'])
      
      # Broadcast the traffic allocation change
      ActionCable.server.broadcast(
        "ab_test_monitoring_#{ab_test.id}",
        {
          type: 'traffic_allocation_updated',
          user: current_user_data,
          ab_test_id: ab_test.id,
          variant_id: variant.id,
          variant_name: variant.name,
          old_percentage: old_percentage,
          new_percentage: variant.traffic_percentage,
          timestamp: Time.current.iso8601,
          message_id: generate_message_id
        }
      )
      
    rescue => e
      send_error_message(ab_test, 'traffic_allocation_error', e.message)
    end
  end

  def can_modify_test?(ab_test)
    # Only test owner or campaign owner can modify traffic allocation
    current_user == ab_test.user || current_user == ab_test.campaign.user
  end

  def valid_traffic_data?(data)
    data['variant_id'].present? && 
    data['new_percentage'].is_a?(Numeric) &&
    data['new_percentage'] >= 0 &&
    data['new_percentage'] <= 100
  end

  def handle_heartbeat(ab_test)
    # Update user presence
    track_user_presence(ab_test)
    
    # Cache current metrics for future comparison
    ab_test.ab_test_variants.each do |variant|
      cache_key = "variant_metrics:#{variant.id}:#{Time.current.to_i}"
      Rails.cache.write(cache_key, variant.current_metrics, expires_in: 1.hour)
    end
    
    # Check if we should send automatic updates
    if should_send_automatic_update?(ab_test)
      send_metrics_update(ab_test)
    end
    
    # Send heartbeat response
    ActionCable.server.broadcast(
      "ab_test_monitoring_#{ab_test.id}",
      {
        type: 'heartbeat_response',
        user: current_user_data,
        ab_test_id: ab_test.id,
        active_monitors: get_active_monitors(ab_test),
        timestamp: Time.current.iso8601,
        message_id: generate_message_id
      }
    )
  end

  def should_send_automatic_update?(ab_test)
    # Send updates every 30 seconds if test is running
    return false unless ab_test.running?
    
    last_update_key = "last_metrics_update:#{ab_test.id}"
    last_update = Rails.cache.read(last_update_key)
    
    if !last_update || Time.parse(last_update) < 30.seconds.ago
      Rails.cache.write(last_update_key, Time.current.iso8601, expires_in: 1.hour)
      true
    else
      false
    end
  end

  def get_active_monitors(ab_test)
    pattern = "monitoring:ab_test:#{ab_test.id}:*"
    keys = Rails.cache.redis.keys(pattern)
    
    keys.map do |key|
      presence_data = Rails.cache.read(key)
      presence_data if presence_data && 
                     Time.parse(presence_data[:last_seen]) > 10.minutes.ago
    end.compact
  end

  def get_current_metrics(ab_test)
    {
      total_visitors: ab_test.ab_test_variants.sum(:total_visitors),
      total_conversions: ab_test.ab_test_variants.sum(:conversions),
      overall_conversion_rate: ab_test.calculate_overall_conversion_rate,
      statistical_significance_reached: ab_test.statistical_significance_reached?,
      confidence_level: ab_test.confidence_level,
      test_progress: ab_test.progress_percentage
    }
  end

  def send_error_message(ab_test, error_type, message)
    ActionCable.server.broadcast(
      "ab_test_monitoring_#{ab_test.id}",
      {
        type: error_type,
        user: current_user_data,
        ab_test_id: ab_test.id,
        error: {
          message: message,
          timestamp: Time.current.iso8601
        },
        message_id: generate_message_id
      }
    )
  end

  def current_user_data
    {
      id: current_user.id,
      name: current_user.name || current_user.email,
      email: current_user.email,
      avatar_url: current_user.avatar.attached? ? url_for(current_user.avatar) : nil
    }
  end

  def generate_message_id
    "msg_#{Time.current.to_i}_#{SecureRandom.hex(4)}"
  end
end

# Add monitoring methods to AbTestVariant model
class AbTestVariant < ApplicationRecord
  def monitoring_data
    {
      id: id,
      name: name,
      is_control: is_control,
      traffic_percentage: traffic_percentage,
      total_visitors: total_visitors,
      conversions: conversions,
      conversion_rate: conversion_rate,
      created_at: created_at.iso8601
    }
  end

  def current_metrics
    {
      total_visitors: total_visitors || 0,
      conversions: conversions || 0,
      conversion_rate: conversion_rate || 0.0,
      bounce_rate: bounce_rate || 0.0,
      average_time_on_page: average_time_on_page || 0.0
    }
  end
end