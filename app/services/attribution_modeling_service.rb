class AttributionModelingService < ApplicationService
  attr_reader :journey, :touchpoints, :conversions

  def initialize(journey)
    @journey = journey
    @touchpoints = journey.touchpoints.chronological.includes(:attribution_models)
    @conversions = @touchpoints.conversions
  end

  def generate_attribution_models(model_types = AttributionModel::MODEL_TYPES)
    results = {}

    return results if conversions.empty?

    model_types.each do |model_type|
      results[model_type] = generate_model_for_type(model_type)
    end

    results
  end

  def calculate_attribution_for_touchpoint(touchpoint, model_type)
    case model_type
    when "first_touch"
      first_touch_attribution(touchpoint)
    when "last_touch"
      last_touch_attribution(touchpoint)
    when "linear"
      linear_attribution(touchpoint)
    when "time_decay"
      time_decay_attribution(touchpoint)
    when "position_based"
      position_based_attribution(touchpoint)
    when "data_driven"
      data_driven_attribution(touchpoint)
    when "custom"
      custom_attribution(touchpoint)
    else
      0.0
    end
  end

  def channel_effectiveness_analysis
    return {} if touchpoints.empty?

    channel_stats = touchpoints.group_by(&:channel).transform_values do |channel_touchpoints|
      conversions_count = channel_touchpoints.count(&:conversion?)
      total_count = channel_touchpoints.count

      {
        touchpoint_count: total_count,
        conversion_count: conversions_count,
        conversion_rate: total_count > 0 ? (conversions_count.to_f / total_count * 100).round(2) : 0,
        average_time_to_conversion: calculate_average_conversion_time(channel_touchpoints),
        attribution_models: channel_touchpoints.flat_map(&:attribution_models).group_by(&:model_type)
      }
    end

    # Calculate ROI and channel value
    channel_stats.each do |channel, stats|
      stats[:total_attribution_value] = calculate_channel_attribution_value(channel)
      stats[:roi_score] = calculate_channel_roi_score(channel, stats)
    end

    channel_stats
  end

  def journey_attribution_summary
    return {} if conversions.empty?

    conversion_touchpoint = conversions.last
    conversion_value = conversion_touchpoint.metadata&.dig("conversion_value") || 100

    models_summary = {}
    AttributionModel::MODEL_TYPES.each do |model_type|
      model_attributions = AttributionModel.where(journey: journey, model_type: model_type)
      next if model_attributions.empty?

      models_summary[model_type] = {
        total_conversion_value: conversion_value,
        channel_attribution: model_attributions.group_by(&:channel_name).transform_values do |attributions|
          {
            attribution_credit: attributions.sum(&:attribution_credit),
            percentage: attributions.sum(&:attribution_percentage),
            touchpoint_count: attributions.count,
            average_confidence: (attributions.sum(&:confidence_score) / attributions.count.to_f).round(3)
          }
        end,
        model_confidence: (model_attributions.sum(&:confidence_score) / model_attributions.count.to_f).round(3),
        touchpoints_attributed: model_attributions.count
      }
    end

    models_summary
  end

  def compare_attribution_models
    return {} if conversions.empty?

    model_comparison = {}
    journey_summary = journey_attribution_summary

    # Compare channel attribution across models
    all_channels = journey_summary.values.flat_map { |model| model[:channel_attribution].keys }.uniq

    all_channels.each do |channel|
      model_comparison[channel] = {}

      AttributionModel::MODEL_TYPES.each do |model_type|
        model_data = journey_summary[model_type]
        next unless model_data

        channel_data = model_data[:channel_attribution][channel]
        model_comparison[channel][model_type] = channel_data || { attribution_credit: 0, percentage: 0 }
      end
    end

    {
      channel_comparison: model_comparison,
      model_summary: journey_summary,
      recommendations: generate_model_recommendations(model_comparison)
    }
  end

  def calculate_multi_touch_attribution(decay_rate: 0.5, position_weights: { first: 0.4, last: 0.4, middle: 0.2 })
    return [] if touchpoints.empty?

    attributions = []
    total_touchpoints = touchpoints.count

    # Calculate raw weights first
    raw_attributions = touchpoints.each_with_index.map do |touchpoint, index|
      time_weight = calculate_time_decay_weight(touchpoint, decay_rate)
      position_weight = calculate_position_weight(index + 1, total_touchpoints, position_weights)
      combined_weight = (time_weight * 0.6) + (position_weight * 0.4)

      {
        touchpoint: touchpoint,
        time_weight: time_weight,
        position_weight: position_weight,
        combined_weight: combined_weight
      }
    end

    # Normalize weights to sum to 100%
    total_weight = raw_attributions.sum { |attr| attr[:combined_weight] }

    raw_attributions.each do |attr|
      normalized_percentage = total_weight > 0 ? (attr[:combined_weight] / total_weight * 100).round(2) : 0

      attributions << {
        touchpoint: attr[:touchpoint],
        attribution_percentage: normalized_percentage,
        time_weight: attr[:time_weight],
        position_weight: attr[:position_weight],
        combined_weight: attr[:combined_weight]
      }
    end

    attributions
  end

  private

  def generate_model_for_type(model_type)
    attributions = []

    touchpoints.each do |touchpoint|
      attribution_percentage = calculate_attribution_for_touchpoint(touchpoint, model_type)
      next if attribution_percentage <= 0

      attribution = AttributionModel.create!(
        user: journey.user,
        touchpoint: touchpoint,
        journey: journey,
        model_type: model_type,
        attribution_percentage: attribution_percentage,
        conversion_value: get_conversion_value,
        calculation_metadata: build_calculation_metadata(touchpoint, model_type)
      )

      attributions << attribution
    end

    attributions
  end

  def first_touch_attribution(touchpoint)
    first_touchpoint = touchpoints.first
    touchpoint == first_touchpoint ? 100.0 : 0.0
  end

  def last_touch_attribution(touchpoint)
    # Find the last touchpoint before conversion (excluding conversion itself)
    if conversions.any?
      conversion_time = conversions.last.occurred_at
      last_interaction = touchpoints.where("occurred_at < ?", conversion_time).order(:occurred_at).last

      # If no touchpoints before conversion, give credit to the conversion touchpoint
      if last_interaction.nil?
        touchpoint == conversions.last ? 100.0 : 0.0
      else
        touchpoint == last_interaction ? 100.0 : 0.0
      end
    else
      touchpoint == touchpoints.last ? 100.0 : 0.0
    end
  end

  def linear_attribution(touchpoint)
    total_touchpoints = touchpoints.count
    return 0.0 if total_touchpoints == 0

    (100.0 / total_touchpoints).round(2)
  end

  def time_decay_attribution(touchpoint, decay_rate = 0.7)
    return 0.0 if conversions.empty?

    conversion_time = conversions.last.occurred_at
    touchpoint_time = touchpoint.occurred_at

    # Calculate days between touchpoint and conversion
    days_difference = ((conversion_time - touchpoint_time) / 1.day).ceil

    # Apply exponential decay
    weight = decay_rate ** days_difference

    # Calculate total weight for normalization
    total_weight = touchpoints.sum do |tp|
      days_diff = ((conversion_time - tp.occurred_at) / 1.day).ceil
      decay_rate ** days_diff
    end

    return 0.0 if total_weight == 0

    ((weight / total_weight) * 100).round(2)
  end

  def position_based_attribution(touchpoint)
    total_touchpoints = touchpoints.count
    touchpoint_position = touchpoints.index(touchpoint) + 1

    case total_touchpoints
    when 1
      100.0
    when 2
      [ 1, 2 ].include?(touchpoint_position) ? 50.0 : 0.0
    else
      case touchpoint_position
      when 1, total_touchpoints  # First and last get 40% each
        40.0
      else  # Middle touchpoints share remaining 20%
        middle_touchpoints = total_touchpoints - 2
        middle_touchpoints > 0 ? (20.0 / middle_touchpoints).round(2) : 0.0
      end
    end
  end

  def data_driven_attribution(touchpoint)
    # Simplified data-driven model based on channel performance and conversion probability
    channel_effectiveness = calculate_channel_effectiveness(touchpoint.channel)
    position_score = calculate_position_score(touchpoint)
    timing_score = calculate_timing_score(touchpoint)

    # Weighted combination of factors
    raw_score = (channel_effectiveness * 0.4) + (position_score * 0.3) + (timing_score * 0.3)

    # Normalize across all touchpoints
    total_score = touchpoints.sum do |tp|
      ch_eff = calculate_channel_effectiveness(tp.channel)
      pos_score = calculate_position_score(tp)
      time_score = calculate_timing_score(tp)
      (ch_eff * 0.4) + (pos_score * 0.3) + (time_score * 0.3)
    end

    return 0.0 if total_score == 0

    ((raw_score / total_score) * 100).round(2)
  end

  def custom_attribution(touchpoint)
    # Custom attribution logic based on business rules
    base_score = linear_attribution(touchpoint)

    # Apply multipliers based on touchpoint characteristics
    multiplier = 1.0

    # Boost conversion touchpoints
    multiplier *= 2.0 if touchpoint.conversion?

    # Boost high-engagement touchpoints
    multiplier *= 1.5 if touchpoint.touchpoint_type == "engagement"

    # Boost certain channels
    multiplier *= 1.3 if %w[email webinar].include?(touchpoint.channel)

    # Apply time decay
    if conversions.any?
      days_to_conversion = (conversions.last.occurred_at - touchpoint.occurred_at) / 1.day
      time_multiplier = [ 1.0 - (days_to_conversion * 0.1), 0.1 ].max
      multiplier *= time_multiplier
    end

    (base_score * multiplier).round(2)
  end

  def calculate_channel_effectiveness(channel)
    channel_touchpoints = journey.user.touchpoints.where(channel: channel)
    return 0.5 if channel_touchpoints.empty?

    conversion_rate = channel_touchpoints.conversions.count.to_f / channel_touchpoints.count
    [ conversion_rate * 2, 1.0 ].min  # Cap at 1.0
  end

  def calculate_position_score(touchpoint)
    total_touchpoints = touchpoints.count
    position = touchpoints.index(touchpoint) + 1

    # Higher scores for first and last positions
    case position
    when 1, total_touchpoints
      1.0
    when 2, total_touchpoints - 1
      0.8
    else
      0.6
    end
  end

  def calculate_timing_score(touchpoint)
    return 0.7 if conversions.empty?

    conversion_time = conversions.last.occurred_at
    days_to_conversion = (conversion_time - touchpoint.occurred_at) / 1.day

    # Score decreases with time distance from conversion
    case days_to_conversion
    when 0..1 then 1.0
    when 1..3 then 0.9
    when 3..7 then 0.8
    when 7..14 then 0.7
    when 14..30 then 0.6
    else 0.5
    end
  end

  def get_conversion_value
    conversion_touchpoint = conversions.last
    return 100 unless conversion_touchpoint  # Default conversion value

    conversion_touchpoint.metadata&.dig("conversion_value") ||
    conversion_touchpoint.metadata&.dig("revenue") ||
    100
  end

  def build_calculation_metadata(touchpoint, model_type)
    {
      calculation_timestamp: Time.current,
      model_type: model_type,
      touchpoint_id: touchpoint.id,
      journey_id: journey.id,
      total_touchpoints: touchpoints.count,
      touchpoint_position: touchpoints.index(touchpoint) + 1,
      conversion_count: conversions.count,
      algorithm_version: "1.0"
    }
  end

  def calculate_time_decay_weight(touchpoint, decay_rate)
    return 1.0 if conversions.empty?

    conversion_time = conversions.last.occurred_at
    days_difference = ((conversion_time - touchpoint.occurred_at) / 1.day).ceil
    decay_rate ** days_difference
  end

  def calculate_position_weight(position, total_touchpoints, weights)
    case position
    when 1
      weights[:first]
    when total_touchpoints
      weights[:last]
    else
      weights[:middle] / [ total_touchpoints - 2, 1 ].max
    end
  end

  def calculate_average_conversion_time(channel_touchpoints)
    conversions = channel_touchpoints.select(&:conversion?)
    return nil if conversions.empty?

    times = []
    conversions.each do |conversion|
      first_touchpoint = channel_touchpoints.min_by(&:occurred_at)
      time_diff = (conversion.occurred_at - first_touchpoint.occurred_at) / 1.hour
      times << time_diff
    end

    (times.sum / times.count).round(2)
  end

  def calculate_channel_attribution_value(channel)
    channel_attributions = AttributionModel.joins(:touchpoint)
                                          .where(journey: journey, touchpoints: { channel: channel })

    channel_attributions.sum(&:attribution_credit)
  end

  def calculate_channel_roi_score(channel, stats)
    # Simplified ROI calculation based on conversion rate and attribution value
    conversion_rate = stats[:conversion_rate]
    attribution_value = stats[:total_attribution_value] || 0

    return 0 if conversion_rate == 0

    # ROI score based on conversion rate and attribution value
    (conversion_rate * attribution_value / 100).round(2)
  end

  def generate_model_recommendations(model_comparison)
    recommendations = []

    # Find channels with high variance across models
    high_variance_channels = model_comparison.select do |channel, models|
      credits = models.values.map { |model| model[:attribution_credit] || 0 }
      variance = calculate_variance(credits)
      variance > 10  # High variance threshold
    end

    if high_variance_channels.any?
      recommendations << "Consider data-driven attribution for channels with high model variance: #{high_variance_channels.keys.join(', ')}"
    end

    # Recommend models based on journey characteristics
    if touchpoints.count <= 3
      recommendations << "Linear or position-based attribution recommended for short customer journeys"
    elsif touchpoints.count > 10
      recommendations << "Time-decay or data-driven attribution recommended for complex customer journeys"
    end

    recommendations
  end

  def calculate_variance(values)
    return 0 if values.empty?

    mean = values.sum.to_f / values.count
    variance = values.sum { |v| (v - mean) ** 2 } / values.count
    Math.sqrt(variance)
  end
end
