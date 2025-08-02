module CampaignPlansHelper
  # Status badge styling
  def status_badge_classes(status)
    case status.to_s
    when 'draft'
      'bg-gray-100 text-gray-800'
    when 'in_review'
      'bg-yellow-100 text-yellow-800'
    when 'approved'
      'bg-green-100 text-green-800'
    when 'rejected'
      'bg-red-100 text-red-800'
    when 'archived'
      'bg-gray-100 text-gray-600'
    else
      'bg-gray-100 text-gray-800'
    end
  end

  # Status progress calculation
  def status_progress_percentage(status)
    case status.to_s
    when 'draft' then 25
    when 'in_review' then 50
    when 'approved' then 100
    when 'rejected' then 75
    else 0
    end
  end

  def status_progress_color(status)
    case status.to_s
    when 'draft' then 'bg-blue-500'
    when 'in_review' then 'bg-yellow-500'
    when 'approved' then 'bg-green-500'
    when 'rejected' then 'bg-red-500'
    else 'bg-gray-500'
    end
  end

  # Comment type styling
  def comment_type_classes(comment_type)
    case comment_type.to_s
    when 'general' then 'bg-gray-100 text-gray-800'
    when 'feedback' then 'bg-yellow-100 text-yellow-800'
    when 'approval' then 'bg-green-100 text-green-800'
    when 'question' then 'bg-blue-100 text-blue-800'
    when 'concern' then 'bg-red-100 text-red-800'
    else 'bg-gray-100 text-gray-800'
    end
  end

  # Budget calculations
  def budget_percentage(amount, total)
    return 0 if total.nil? || total.zero?
    ((amount.to_f / total.to_f) * 100).round(1)
  end

  def top_channel_by_budget(channel_data)
    return {} unless channel_data.present?
    channel_data.max_by { |channel| channel[:budget_allocation] || 0 }
  end

  def total_expected_reach(channel_data)
    return 0 unless channel_data.present?
    channel_data.sum { |channel| channel[:expected_reach] || 0 }
  end

  def reach_percentage(reach, all_channels)
    return 0 unless all_channels.present?
    max_reach = all_channels.map { |c| c[:expected_reach] || 0 }.max
    return 0 if max_reach.zero?
    ((reach.to_f / max_reach.to_f) * 100).round
  end

  # Channel icons
  def channel_icon(slug)
    icons = {
      'social_media' => content_tag(:svg, class: "w-5 h-5 text-blue-600", fill: "currentColor", viewBox: "0 0 20 20") do
        content_tag(:path, nil, d: "M2 5a2 2 0 012-2h7a2 2 0 012 2v4a2 2 0 01-2 2H9l-3 3v-3H4a2 2 0 01-2-2V5z") +
        content_tag(:path, nil, d: "M15 7v2a4 4 0 01-4 4H9.828l-1.766 1.767c.28.149.599.233.938.233h2l3 3v-3h2a2 2 0 002-2V9a2 2 0 00-2-2h-1z")
      end,
      'email' => content_tag(:svg, class: "w-5 h-5 text-green-600", fill: "currentColor", viewBox: "0 0 20 20") do
        content_tag(:path, nil, d: "M2.003 5.884L10 9.882l7.997-3.998A2 2 0 0016 4H4a2 2 0 00-1.997 1.884z") +
        content_tag(:path, nil, d: "M18 8.118l-8 4-8-4V14a2 2 0 002 2h12a2 2 0 002-2V8.118z")
      end,
      'paid_search' => content_tag(:svg, class: "w-5 h-5 text-yellow-600", fill: "currentColor", viewBox: "0 0 20 20") do
        content_tag(:path, fill_rule: "evenodd", d: "M8 4a4 4 0 100 8 4 4 0 000-8zM2 8a6 6 0 1110.89 3.476l4.817 4.817a1 1 0 01-1.414 1.414l-4.816-4.816A6 6 0 012 8z", clip_rule: "evenodd")
      end,
      'content_marketing' => content_tag(:svg, class: "w-5 h-5 text-purple-600", fill: "currentColor", viewBox: "0 0 20 20") do
        content_tag(:path, fill_rule: "evenodd", d: "M4 4a2 2 0 012-2h8a2 2 0 012 2v12a1 1 0 110 2h-3a1 1 0 01-1-1v-2a1 1 0 00-1-1H9a1 1 0 00-1 1v2a1 1 0 01-1 1H4a1 1 0 110-2V4zm3 1h2v2H7V5zm2 4H7v2h2V9zm2-4h2v2h-2V5zm2 4h-2v2h2V9z", clip_rule: "evenodd")
      end,
      'linkedin' => content_tag(:svg, class: "w-5 h-5 text-blue-700", fill: "currentColor", viewBox: "0 0 20 20") do
        content_tag(:path, fill_rule: "evenodd", d: "M16.338 16.338H13.67V12.16c0-.995-.017-2.277-1.387-2.277-1.39 0-1.601 1.086-1.601 2.207v4.248H8.014v-8.59h2.559v1.174h.037c.356-.675 1.227-1.387 2.526-1.387 2.703 0 3.203 1.778 3.203 4.092v4.711zM5.005 6.575a1.548 1.548 0 11-.003-3.096 1.548 1.548 0 01.003 3.096zm-1.337 9.763H6.34v-8.59H3.667v8.59zM17.668 1H2.328C1.595 1 1 1.581 1 2.298v15.403C1 18.418 1.595 19 2.328 19h15.34c.734 0 1.332-.582 1.332-1.299V2.298C19 1.581 18.402 1 17.668 1z", clip_rule: "evenodd")
      end,
      'webinars' => content_tag(:svg, class: "w-5 h-5 text-indigo-600", fill: "currentColor", viewBox: "0 0 20 20") do
        content_tag(:path, d: "M2 6a2 2 0 012-2h6a2 2 0 012 2v2a2 2 0 01-2 2H4a2 2 0 01-2-2V6zM14.553 7.106A1 1 0 0014 8v4a1 1 0 00.553.894l2 1A1 1 0 0018 13V7a1 1 0 00-1.447-.894l-2 1z")
      end,
      'partnerships' => content_tag(:svg, class: "w-5 h-5 text-green-700", fill: "currentColor", viewBox: "0 0 20 20") do
        content_tag(:path, d: "M13 6a3 3 0 11-6 0 3 3 0 016 0zM18 8a2 2 0 11-4 0 2 2 0 014 0zM14 15a4 4 0 00-8 0v3h8v-3z") +
        content_tag(:path, d: "M6 8a2 2 0 11-4 0 2 2 0 014 0zM16 18v-3a5.972 5.972 0 00-.75-2.906A3.005 3.005 0 0119 15v3h-3zM4.75 12.094A5.973 5.973 0 004 15v3H1v-3a3 3 0 013.75-2.906z")
      end,
      'display_ads' => content_tag(:svg, class: "w-5 h-5 text-orange-600", fill: "currentColor", viewBox: "0 0 20 20") do
        content_tag(:path, fill_rule: "evenodd", d: "M4 3a2 2 0 00-2 2v10a2 2 0 002 2h12a2 2 0 002-2V5a2 2 0 00-2-2H4zm12 12H4l4-8 3 6 2-4 3 6z", clip_rule: "evenodd")
      end,
      'product_marketing' => content_tag(:svg, class: "w-5 h-5 text-purple-700", fill: "currentColor", viewBox: "0 0 20 20") do
        content_tag(:path, fill_rule: "evenodd", d: "M10 2L3 7v11a1 1 0 001 1h12a1 1 0 001-1V7l-7-5zM6 9.5a.5.5 0 01.5-.5h7a.5.5 0 01.5.5v1a.5.5 0 01-.5.5h-7a.5.5 0 01-.5-.5v-1zm.5 3a.5.5 0 00-.5.5v1a.5.5 0 00.5.5h7a.5.5 0 00.5-.5v-1a.5.5 0 00-.5-.5h-7z", clip_rule: "evenodd")
      end,
      'community' => content_tag(:svg, class: "w-5 h-5 text-teal-600", fill: "currentColor", viewBox: "0 0 20 20") do
        content_tag(:path, d: "M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z")
      end,
      'event_marketing' => content_tag(:svg, class: "w-5 h-5 text-red-600", fill: "currentColor", viewBox: "0 0 20 20") do
        content_tag(:path, fill_rule: "evenodd", d: "M6 2a1 1 0 00-1 1v1H4a2 2 0 00-2 2v10a2 2 0 002 2h12a2 2 0 002-2V6a2 2 0 00-2-2h-1V3a1 1 0 10-2 0v1H7V3a1 1 0 00-1-1zm0 5a1 1 0 000 2h8a1 1 0 100-2H6z", clip_rule: "evenodd")
      end
    }
    
    icons[slug.to_s] || content_tag(:svg, class: "w-5 h-5 text-gray-600", fill: "currentColor", viewBox: "0 0 20 20") do
      content_tag(:path, fill_rule: "evenodd", d: "M10 18a8 8 0 100-16 8 8 0 000 16zm1-11a1 1 0 10-2 0v2H7a1 1 0 100 2h2v2a1 1 0 102 0v-2h2a1 1 0 100-2h-2V7z", clip_rule: "evenodd")
    end
  end

  # Metrics formatting
  def format_metric_value(value)
    return value.to_s unless value.is_a?(Numeric)
    
    if value >= 1_000_000
      "#{(value / 1_000_000.0).round(1)}M"
    elsif value >= 1_000
      "#{(value / 1_000.0).round(1)}K"
    elsif value.is_a?(Float) && value < 1
      "#{(value * 100).round(1)}%"
    elsif value.is_a?(Float)
      value.round(1).to_s
    else
      number_with_delimiter(value)
    end
  end

  def calculate_progress_percentage(stage_metrics)
    return 0 unless stage_metrics.present?
    # Simple calculation based on number of metrics defined
    # In a real implementation, this would compare actual vs target values
    (stage_metrics.length * 20).clamp(0, 100)
  end

  # Funnel data preparation
  def prepare_funnel_data(metrics_data)
    stages = []
    
    if metrics_data[:awareness_metrics].present?
      awareness_value = metrics_data[:awareness_metrics].values.first || 10000
      stages << {
        name: 'Awareness',
        value: awareness_value,
        percentage: 100,
        color: 'awareness',
        conversion_rate: nil
      }
    end
    
    if metrics_data[:consideration_metrics].present?
      consideration_value = metrics_data[:consideration_metrics].values.first || 2500
      awareness_value = stages.first ? stages.first[:value] : 10000
      stages << {
        name: 'Consideration',
        value: consideration_value,
        percentage: ((consideration_value.to_f / awareness_value.to_f) * 100).round,
        color: 'consideration',
        conversion_rate: ((consideration_value.to_f / awareness_value.to_f) * 100).round(1)
      }
    end
    
    if metrics_data[:conversion_metrics].present?
      conversion_value = metrics_data[:conversion_metrics].values.first || 500
      previous_value = stages.last ? stages.last[:value] : 2500
      stages << {
        name: 'Conversion',
        value: conversion_value,
        percentage: ((conversion_value.to_f / stages.first[:value].to_f) * 100).round,
        color: 'conversion',
        conversion_rate: ((conversion_value.to_f / previous_value.to_f) * 100).round(1)
      }
    end
    
    if metrics_data[:retention_metrics].present?
      retention_value = metrics_data[:retention_metrics].values.first || 400
      previous_value = stages.last ? stages.last[:value] : 500
      stages << {
        name: 'Retention',
        value: retention_value,
        percentage: ((retention_value.to_f / stages.first[:value].to_f) * 100).round,
        color: 'retention',
        conversion_rate: ((retention_value.to_f / previous_value.to_f) * 100).round(1)
      }
    end
    
    stages
  end

  # Analytics insights
  def calculate_overall_conversion_rate(metrics_data)
    funnel_stages = prepare_funnel_data(metrics_data)
    return 0 if funnel_stages.length < 2
    
    first_stage = funnel_stages.first[:value]
    last_stage = funnel_stages.last[:value]
    
    ((last_stage.to_f / first_stage.to_f) * 100).round(1)
  end

  def identify_weakest_stage(metrics_data)
    funnel_stages = prepare_funnel_data(metrics_data)
    return 'Unknown' if funnel_stages.length < 2
    
    # Find stage with lowest conversion rate
    weakest = funnel_stages.drop(1).min_by { |stage| stage[:conversion_rate] || 0 }
    weakest ? weakest[:name] : 'Unknown'
  end

  def calculate_cost_per_conversion(metrics_data)
    # This would integrate with budget data in a real implementation
    rand(50..250).round
  end

  def calculate_required_timeframe(metrics_data)
    # This would analyze the metrics complexity and estimated achievement timeline
    rand(8..24)
  end

  # Stage icons
  def stage_icon(stage)
    icons = {
      'awareness' => content_tag(:svg, class: "w-5 h-5 text-journey-awareness-600", fill: "currentColor", viewBox: "0 0 20 20") do
        content_tag(:path, nil, d: "M10 12a2 2 0 100-4 2 2 0 000 4z") +
        content_tag(:path, fill_rule: "evenodd", d: "M.458 10C1.732 5.943 5.522 3 10 3s8.268 2.943 9.542 7c-1.274 4.057-5.064 7-9.542 7S1.732 14.057.458 10zM14 10a4 4 0 11-8 0 4 4 0 018 0z", clip_rule: "evenodd")
      end,
      'consideration' => content_tag(:svg, class: "w-5 h-5 text-journey-consideration-600", fill: "currentColor", viewBox: "0 0 20 20") do
        content_tag(:path, fill_rule: "evenodd", d: "M18 10a8 8 0 11-16 0 8 8 0 0116 0zm-8-3a1 1 0 00-.867.5 1 1 0 11-1.731-1A3 3 0 0113 8a3.001 3.001 0 01-2 2.83V11a1 1 0 11-2 0v-1a1 1 0 011-1 1 1 0 100-2zm0 8a1 1 0 100-2 1 1 0 000 2z", clip_rule: "evenodd")
      end,
      'conversion' => content_tag(:svg, class: "w-5 h-5 text-journey-conversion-600", fill: "currentColor", viewBox: "0 0 20 20") do
        content_tag(:path, fill_rule: "evenodd", d: "M10 18a8 8 0 100-16 8 8 0 000 16zm3.707-9.293a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z", clip_rule: "evenodd")
      end,
      'retention' => content_tag(:svg, class: "w-5 h-5 text-journey-retention-600", fill: "currentColor", viewBox: "0 0 20 20") do
        content_tag(:path, fill_rule: "evenodd", d: "M4 2a1 1 0 011 1v2.101a7.002 7.002 0 0111.601 2.566 1 1 0 11-1.885.666A5.002 5.002 0 005.999 7H9a1 1 0 010 2H4a1 1 0 01-1-1V3a1 1 0 011-1zm.008 9.057a1 1 0 011.276.61A5.002 5.002 0 0014.001 13H11a1 1 0 110-2h5a1 1 0 011 1v5a1 1 0 11-2 0v-2.101a7.002 7.002 0 01-11.601-2.566 1 1 0 01.61-1.276z", clip_rule: "evenodd")
      end
    }
    
    icons[stage.to_s] || content_tag(:svg, class: "w-5 h-5 text-gray-600", fill: "currentColor", viewBox: "0 0 20 20") do
      content_tag(:path, fill_rule: "evenodd", d: "M10 18a8 8 0 100-16 8 8 0 000 16zm1-11a1 1 0 10-2 0v2H7a1 1 0 100 2h2v2a1 1 0 102 0v-2h2a1 1 0 100-2h-2V7z", clip_rule: "evenodd")
    end
  end

  # Permission helpers
  def can_approve_plan?(plan)
    return false unless current_user
    current_user.admin? || current_user == plan.campaign.user
  end

  def can_edit_plan?(plan)
    return false unless current_user
    return false if plan.approved?
    current_user == plan.user || current_user.admin?
  end

  def can_comment_on_plan?(plan)
    return false unless current_user
    # All authenticated users can comment
    true
  end
end