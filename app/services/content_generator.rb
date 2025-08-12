# Main content generation service that orchestrates channel-specific adapters
# Provides a unified interface for generating marketing content across all channels
class ContentGenerator < ContentGeneratorBase
  include ActiveModel::Model
  include ActiveModel::Attributes

  # Service configuration
  attribute :registry, default: -> { ContentGeneratorRegistry.instance }
  attribute :cache_enabled, :boolean, default: true
  attribute :validation_enabled, :boolean, default: true
  attribute :optimization_enabled, :boolean, default: true

  # Content generation statistics
  attr_reader :generation_stats

  def initialize(attributes = {})
    super(attributes)
    @generation_stats = initialize_stats
  end

  # Generate content for a specific channel
  def generate_content(request)
    start_time = Time.current
    
    begin
      # Validate and preprocess request
      validate_request!(request)
      processed_request = preprocess_request(request)
      
      # Get channel adapter
      adapter = get_adapter_for_channel(processed_request.channel_type)
      
      # Generate content using adapter
      response = adapter.generate_content_with_validation(processed_request)
      
      # Post-process response
      final_response = postprocess_response(response, processed_request)
      
      # Update statistics
      record_successful_generation(processed_request.channel_type, Time.current - start_time)
      
      final_response
    rescue => e
      record_failed_generation(request&.channel_type, e, Time.current - start_time)
      raise
    end
  end

  # Generate content for multiple channels from a single request
  def generate_multi_channel_content(base_request, channel_types, options = {})
    results = {}
    parallel_execution = options.fetch(:parallel, false)
    
    if parallel_execution && defined?(Parallel)
      # Use parallel gem if available for concurrent generation
      results = Parallel.map(channel_types, in_threads: [channel_types.size, 4].min) do |channel_type|
        [channel_type, generate_single_channel_content(base_request, channel_type)]
      end.to_h
    else
      # Sequential generation
      channel_types.each do |channel_type|
        results[channel_type] = generate_single_channel_content(base_request, channel_type)
      end
    end
    
    ContentMultiChannelResponse.new(
      request_id: base_request.request_id,
      channel_results: results,
      generated_at: Time.current,
      generation_summary: summarize_multi_channel_results(results)
    )
  end

  # Generate A/B test variants for content
  def generate_variants(request, variant_count: 3, strategies: nil)
    validate_request!(request)
    
    adapter = get_adapter_for_channel(request.channel_type)
    
    # Use adapter's variant generation if available
    if adapter.supports_variants?
      variants = adapter.generate_variants(request, count: variant_count)
    else
      # Fallback to basic variant generation
      variants = generate_basic_variants(request, variant_count)
    end
    
    ContentVariantResponse.new(
      original_request: request,
      variants: variants,
      generated_at: Time.current,
      variant_analysis: analyze_variants(variants)
    )
  end

  # Optimize existing content based on performance data
  def optimize_content(content, channel_type, performance_data = {})
    adapter = get_adapter_for_channel(channel_type)
    
    if adapter.supports_optimization?
      adapter.optimize_content(content, performance_data)
    else
      generate_optimization_suggestions(content, channel_type, performance_data)
    end
  end

  # Batch content generation for campaigns
  def generate_campaign_content(campaign_request)
    validate_campaign_request!(campaign_request)
    
    results = {}
    
    campaign_request.content_requirements.each do |requirement|
      begin
        content_request = build_content_request_from_requirement(requirement, campaign_request)
        results[requirement[:id]] = generate_content(content_request)
      rescue => e
        results[requirement[:id]] = { error: e.message, requirement: requirement }
      end
    end
    
    ContentCampaignResponse.new(
      campaign_id: campaign_request.campaign_id,
      content_results: results,
      generated_at: Time.current,
      campaign_summary: summarize_campaign_results(results)
    )
  end

  # Content scheduling and calendar generation
  def generate_content_calendar(calendar_request)
    validate_calendar_request!(calendar_request)
    
    calendar_entries = []
    
    calendar_request.date_range.each do |date|
      daily_content = generate_daily_content(calendar_request, date)
      calendar_entries << ContentCalendarEntry.new(
        date: date,
        content_items: daily_content,
        themes: determine_daily_themes(calendar_request, date)
      )
    end
    
    ContentCalendar.new(
      entries: calendar_entries,
      date_range: calendar_request.date_range,
      generated_at: Time.current,
      calendar_metadata: build_calendar_metadata(calendar_request)
    )
  end

  # Get service health and statistics
  def health_status
    {
      status: :healthy,
      adapters: registry.health_check,
      statistics: @generation_stats,
      last_updated: Time.current
    }
  end

  # Export content in various formats
  def export_content(content_items, format, options = {})
    case format.to_s
    when 'csv'
      export_to_csv(content_items, options)
    when 'json'
      export_to_json(content_items, options)
    when 'pdf'
      export_to_pdf(content_items, options)
    when 'calendar'
      export_to_calendar(content_items, options)
    when 'markdown'
      export_to_markdown(content_items, options)
    else
      raise ArgumentError, "Unsupported export format: #{format}"
    end
  end

  private

  def get_adapter_for_channel(channel_type)
    unless registry.supports_channel?(channel_type)
      raise ChannelNotSupportedError, "Channel '#{channel_type}' is not supported"
    end
    
    registry.adapter_for(channel_type,
      brand_context: brand_context,
      ai_service: ai_service
    )
  end

  def generate_single_channel_content(base_request, channel_type)
    begin
      adapted_request = adapt_request_for_channel(base_request, channel_type)
      generate_content(adapted_request)
    rescue => e
      { error: e.message, channel: channel_type }
    end
  end

  def adapt_request_for_channel(base_request, channel_type)
    adapted_request = base_request.dup
    adapted_request.channel_type = channel_type
    
    # Apply channel-specific adaptations from registry configuration
    channel_config = registry.configuration_for(channel_type)
    
    if channel_config[:max_length]
      adapted_request.constraints[:max_length] = channel_config[:max_length]
    end
    
    if channel_config[:requires_cta]
      adapted_request.requirements << "call_to_action"
    end
    
    adapted_request
  end

  def preprocess_request(request)
    processed_request = request.dup
    
    # Add service-level context
    processed_request.brand_context = processed_request.brand_context.merge({
      service_version: "1.0",
      generation_timestamp: Time.current.iso8601
    })
    
    # Apply global brand guidelines
    if brand_context.present?
      processed_request.brand_context = processed_request.brand_context.merge(brand_context)
    end
    
    processed_request
  end

  def postprocess_response(response, request)
    return response unless response.is_a?(ContentResponse)
    
    # Add service-level metadata
    response.model_used = ai_service.model_name if ai_service
    response.request_id = request.request_id
    
    # Apply validation if enabled
    if validation_enabled
      validate_response_quality(response, request)
    end
    
    # Apply optimization suggestions if enabled
    if optimization_enabled
      response.optimization_suggestions = generate_optimization_suggestions(
        response.content, request.channel_type
      )
    end
    
    response
  end

  def validate_response_quality(response, request)
    # Check basic quality metrics
    if response.quality_score && response.quality_score < 0.3
      Rails.logger.warn "Low quality content generated for #{request.channel_type}: #{response.quality_score}"
    end
    
    # Check content guidelines compliance
    if has_content_violations?(response.content)
      response.content_warnings << "Content may violate brand guidelines"
    end
  end

  def has_content_violations?(content)
    # Simple content violation detection - in a real implementation, this would be more sophisticated
    violation_patterns = [
      /\b(spam|scam|fake|illegal)\b/i,
      /\b(click here|act now|limited time)\b/i # Avoid spammy language
    ]
    
    violation_patterns.any? { |pattern| content.match?(pattern) }
  end

  def generate_basic_variants(request, count)
    variants = []
    
    count.times do |index|
      variant_request = request.dup
      variant_request.variant_context = {
        variant_index: index + 1,
        total_variants: count,
        strategy: [:tone_variation, :structure_variation, :length_variation][index % 3]
      }
      
      # Modify request based on strategy
      case variant_request.variant_context[:strategy]
      when :tone_variation
        variant_request.tone = vary_tone(variant_request.tone, index)
      when :structure_variation
        variant_request.style = vary_style(variant_request.style, index)
      when :length_variation
        variant_request.constraints[:target_length] = vary_length_target(variant_request, index)
      end
      
      variants << generate_content(variant_request)
    end
    
    variants
  end

  def vary_tone(original_tone, index)
    tone_variations = {
      'professional' => ['authoritative', 'formal', 'expert'],
      'casual' => ['friendly', 'conversational', 'playful'],
      'friendly' => ['warm', 'approachable', 'casual']
    }
    
    variations = tone_variations[original_tone] || ['professional', 'friendly', 'casual']
    variations[index % variations.length]
  end

  def vary_style(original_style, index)
    style_variations = {
      'conversational' => ['direct', 'storytelling', 'informative'],
      'formal' => ['structured', 'analytical', 'authoritative'],
      'creative' => ['playful', 'imaginative', 'bold']
    }
    
    variations = style_variations[original_style] || ['conversational', 'direct', 'creative']
    variations[index % variations.length]
  end

  def vary_length_target(request, index)
    current_max = request.constraints[:max_length] || 1000
    
    case index
    when 0
      current_max * 0.7 # Shorter
    when 1
      current_max * 1.2 # Longer
    else
      current_max # Same
    end
  end

  def analyze_variants(variants)
    return {} if variants.empty?
    
    {
      variant_count: variants.length,
      average_length: variants.map(&:character_count).sum / variants.length,
      length_range: {
        min: variants.map(&:character_count).min,
        max: variants.map(&:character_count).max
      },
      average_quality: variants.map(&:quality_score).compact.sum / variants.length,
      predicted_performance: variants.map(&:engagement_prediction).compact.sum / variants.length
    }
  end

  def generate_optimization_suggestions(content, channel_type, performance_data = {})
    suggestions = []
    
    # Length optimization
    channel_config = registry.configuration_for(channel_type)
    optimal_length = channel_config[:optimal_length] || 500
    
    if content.length > optimal_length * 1.5
      suggestions << "Content is quite long for #{channel_type}. Consider shortening for better engagement."
    elsif content.length < optimal_length * 0.5
      suggestions << "Content might be too short for #{channel_type}. Consider adding more value."
    end
    
    # Performance-based suggestions
    if performance_data[:engagement_rate] && performance_data[:engagement_rate] < 0.02
      suggestions << "Low engagement detected. Try adding questions or interactive elements."
    end
    
    if performance_data[:click_rate] && performance_data[:click_rate] < 0.01
      suggestions << "Low click-through rate. Consider strengthening your call-to-action."
    end
    
    suggestions
  end

  def initialize_stats
    {
      total_generations: 0,
      successful_generations: 0,
      failed_generations: 0,
      average_generation_time: 0,
      generations_by_channel: Hash.new(0),
      last_reset: Time.current
    }
  end

  def record_successful_generation(channel_type, duration)
    @generation_stats[:total_generations] += 1
    @generation_stats[:successful_generations] += 1
    @generation_stats[:generations_by_channel][channel_type] += 1
    
    # Update average generation time
    current_avg = @generation_stats[:average_generation_time]
    total_successful = @generation_stats[:successful_generations]
    @generation_stats[:average_generation_time] = 
      ((current_avg * (total_successful - 1)) + duration) / total_successful
  end

  def record_failed_generation(channel_type, error, duration)
    @generation_stats[:total_generations] += 1
    @generation_stats[:failed_generations] += 1
    
    Rails.logger.error "Content generation failed for #{channel_type}: #{error.message}"
  end

  def summarize_multi_channel_results(results)
    {
      total_channels: results.keys.length,
      successful_channels: results.count { |_, result| !result.is_a?(Hash) || !result.key?(:error) },
      failed_channels: results.count { |_, result| result.is_a?(Hash) && result.key?(:error) },
      average_quality: calculate_average_quality(results),
      content_distribution: analyze_content_distribution(results)
    }
  end

  def calculate_average_quality(results)
    quality_scores = results.values
                           .reject { |result| result.is_a?(Hash) && result.key?(:error) }
                           .map { |response| response.quality_score }
                           .compact
    
    return 0 if quality_scores.empty?
    quality_scores.sum / quality_scores.length
  end

  def analyze_content_distribution(results)
    successful_results = results.values.reject { |result| result.is_a?(Hash) && result.key?(:error) }
    
    {
      total_words: successful_results.map(&:word_count).sum,
      average_words_per_channel: successful_results.map(&:word_count).sum / [successful_results.length, 1].max,
      content_types: successful_results.map(&:content_type).uniq
    }
  end

  # Export format implementations
  def export_to_csv(content_items, options = {})
    require 'csv'
    
    CSV.generate(headers: true) do |csv|
      csv << ['Channel', 'Content Type', 'Content', 'Word Count', 'Quality Score', 'Generated At']
      
      content_items.each do |item|
        csv << [
          item.channel_type,
          item.content_type,
          item.content.gsub(/["\n\r]/, ' '),
          item.word_count,
          item.quality_score,
          item.generated_at
        ]
      end
    end
  end

  def export_to_json(content_items, options = {})
    {
      content_items: content_items.map(&:as_json),
      exported_at: Time.current,
      export_options: options
    }.to_json
  end

  def export_to_calendar(content_items, options = {})
    # Generate ICS format for calendar import
    calendar_data = "BEGIN:VCALENDAR\nVERSION:2.0\nPRODID:ContentGenerator\n"
    
    content_items.each_with_index do |item, index|
      calendar_data += "BEGIN:VEVENT\n"
      calendar_data += "UID:content-#{item.request_id || index}@contentgenerator\n"
      calendar_data += "SUMMARY:#{item.content_type.humanize} Content\n"
      calendar_data += "DESCRIPTION:#{item.preview(100)}\n"
      calendar_data += "DTSTART:#{item.generated_at.strftime('%Y%m%dT%H%M%S')}\n"
      calendar_data += "DTEND:#{(item.generated_at + 1.hour).strftime('%Y%m%dT%H%M%S')}\n"
      calendar_data += "END:VEVENT\n"
    end
    
    calendar_data += "END:VCALENDAR"
    calendar_data
  end

  def export_to_markdown(content_items, options = {})
    markdown = "# Generated Content\n\n"
    markdown += "*Exported on #{Time.current.strftime('%B %d, %Y at %I:%M %p')}*\n\n"
    
    content_items.group_by(&:channel_type).each do |channel, items|
      markdown += "## #{channel.humanize}\n\n"
      
      items.each_with_index do |item, index|
        markdown += "### #{item.content_type.humanize} #{index + 1}\n\n"
        markdown += "#{item.content}\n\n"
        markdown += "**Metrics:** #{item.word_count} words, Quality: #{item.quality_score&.round(2)}\n\n"
        markdown += "---\n\n"
      end
    end
    
    markdown
  end

  def validate_campaign_request!(request)
    raise ArgumentError, "Campaign request must respond to campaign_id" unless request.respond_to?(:campaign_id)
    raise ArgumentError, "Campaign request must respond to content_requirements" unless request.respond_to?(:content_requirements)
  end

  def validate_calendar_request!(request)
    raise ArgumentError, "Calendar request must respond to date_range" unless request.respond_to?(:date_range)
    raise ArgumentError, "Date range cannot be empty" if request.date_range.empty?
  end
end