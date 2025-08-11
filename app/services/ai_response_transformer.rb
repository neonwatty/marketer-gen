# AI Response Transformer for consistent output formatting
# Transforms AI responses into standardized formats for different use cases
class AiResponseTransformer
  include ActiveModel::Model
  include ActiveModel::Attributes

  # Supported output formats
  OUTPUT_FORMATS = %w[
    standard
    campaign_plan
    brand_analysis
    content_generation
    social_media
    email
    ad_copy
    blog_post
    landing_page
    optimization_report
    json
    markdown
    html
  ].freeze

  # Transformation options
  TRANSFORMATION_OPTIONS = %w[
    normalize_whitespace
    extract_metadata
    format_links
    process_hashtags
    extract_mentions
    apply_branding
    add_timestamps
    include_source_info
    validate_structure
  ].freeze

  class TransformationError < StandardError; end
  class UnsupportedFormatError < TransformationError; end
  class ValidationError < TransformationError; end

  attribute :target_format, :string, default: 'standard'
  attribute :transformation_options, :string, default: -> { ['normalize_whitespace', 'extract_metadata'] }
  attribute :brand_guidelines, :string, default: -> { {} }
  attribute :strict_validation, :boolean, default: false
  attribute :preserve_original, :boolean, default: true

  attr_reader :transformed_content, :transformation_metadata

  def initialize(attributes = {})
    super(attributes)
    @transformation_metadata = {}
    validate_configuration!
  end

  # Main transformation method
  def transform(content, options = {})
    return transformation_error("Content cannot be empty") if content.blank?

    @original_content = content
    @options = options
    @transformation_metadata = {
      source_format: detect_source_format(content),
      target_format: target_format,
      transformation_options: transformation_options,
      started_at: Time.current
    }

    begin
      # Parse the content first
      parsed_content = parse_input_content(content)
      
      # Apply pre-transformation processing
      processed_content = apply_pre_transformations(parsed_content)
      
      # Apply format-specific transformation
      @transformed_content = case target_format
      when 'standard'
        transform_to_standard_format(processed_content)
      when 'campaign_plan'
        transform_to_campaign_plan(processed_content)
      when 'brand_analysis'
        transform_to_brand_analysis(processed_content)
      when 'content_generation'
        transform_to_content_generation(processed_content)
      when 'social_media'
        transform_to_social_media(processed_content)
      when 'email'
        transform_to_email_format(processed_content)
      when 'ad_copy'
        transform_to_ad_copy(processed_content)
      when 'blog_post'
        transform_to_blog_post(processed_content)
      when 'landing_page'
        transform_to_landing_page(processed_content)
      when 'optimization_report'
        transform_to_optimization_report(processed_content)
      when 'json'
        transform_to_json(processed_content)
      when 'markdown'
        transform_to_markdown(processed_content)
      when 'html'
        transform_to_html(processed_content)
      else
        raise UnsupportedFormatError, "Unsupported target format: #{target_format}"
      end

      # Apply post-transformation processing
      @transformed_content = apply_post_transformations(@transformed_content)

      # Validate if strict validation is enabled
      validate_transformed_content! if strict_validation

      # Update metadata
      @transformation_metadata.merge!(
        completed_at: Time.current,
        success: true,
        content_length_before: content.to_s.length,
        content_length_after: @transformed_content.to_s.length,
        transformations_applied: transformation_options
      )

      # Generate final result
      generate_transformation_result

    rescue => error
      Rails.logger.error "AI response transformation failed: #{error.message}"
      Rails.logger.error error.backtrace.join("\n") if error.respond_to?(:backtrace)

      @transformation_metadata.merge!(
        completed_at: Time.current,
        success: false,
        error: {
          type: error.class.name,
          message: error.message
        }
      )

      transformation_error("Transformation failed: #{error.message}")
    end
  end

  # Quick transformation without full metadata
  def quick_transform(content, target_format = nil)
    original_format = self.target_format
    self.target_format = target_format if target_format
    
    result = transform(content)
    transformed_content = result[:transformed_content]
    
    self.target_format = original_format
    transformed_content
  rescue
    content # Return original content if transformation fails
  end

  # Batch transformation
  def transform_batch(content_array, options = {})
    content_array.map.with_index do |content, index|
      begin
        transform(content, options.merge(batch_index: index))
      rescue => error
        {
          batch_index: index,
          success: false,
          error: error.message,
          original_content: preserve_original ? content : nil
        }
      end
    end
  end

  private

  def validate_configuration!
    unless OUTPUT_FORMATS.include?(target_format)
      raise UnsupportedFormatError, "Invalid target format: #{target_format}"
    end

    invalid_options = transformation_options - TRANSFORMATION_OPTIONS
    if invalid_options.any?
      raise TransformationError, "Invalid transformation options: #{invalid_options.join(', ')}"
    end
  end

  def detect_source_format(content)
    case content
    when Hash
      if content.key?(:provider) || content.key?('provider')
        'ai_response'
      else
        'structured_data'
      end
    when String
      if content.strip.start_with?('{', '[')
        'json_string'
      elsif content.include?('```') || content.match?(/^#+\s+/)
        'markdown'
      elsif content.include?('<') && content.include?('>')
        'html'
      else
        'plain_text'
      end
    else
      'unknown'
    end
  end

  def parse_input_content(content)
    case detect_source_format(content)
    when 'ai_response'
      # Already parsed AI response
      content
    when 'structured_data'
      # Hash with structured data
      content
    when 'json_string'
      # Parse JSON string
      begin
        JSON.parse(content)
      rescue JSON::ParserError
        { content: content, format: 'json_parse_failed' }
      end
    when 'markdown', 'html', 'plain_text'
      # Text content
      { content: content, format: detect_source_format(content) }
    else
      # Fallback
      { content: content.to_s, format: 'unknown' }
    end
  end

  def apply_pre_transformations(content)
    processed = content.dup

    transformation_options.each do |option|
      case option
      when 'normalize_whitespace'
        processed = normalize_whitespace(processed)
      when 'extract_metadata'
        processed = extract_content_metadata(processed)
      when 'format_links'
        processed = format_links(processed)
      when 'process_hashtags'
        processed = process_hashtags(processed)
      when 'extract_mentions'
        processed = extract_mentions(processed)
      end
    end

    processed
  end

  def apply_post_transformations(content)
    processed = content

    transformation_options.each do |option|
      case option
      when 'apply_branding'
        processed = apply_branding(processed)
      when 'add_timestamps'
        processed = add_timestamps(processed)
      when 'include_source_info'
        processed = include_source_info(processed)
      end
    end

    processed
  end

  # Format-specific transformation methods

  def transform_to_standard_format(content)
    {
      content: extract_main_content(content),
      metadata: extract_metadata_hash(content),
      format: 'standard',
      transformed_at: Time.current,
      original_preserved: preserve_original ? @original_content : nil
    }
  end

  def transform_to_campaign_plan(content)
    main_content = extract_main_content(content)
    
    # Extract campaign plan structure
    plan_structure = {
      title: extract_field_value(main_content, %w[title name campaign_name]),
      objective: extract_field_value(main_content, %w[objective goal purpose]),
      target_audience: extract_field_value(main_content, %w[target_audience audience demographic]),
      budget: extract_budget_breakdown(main_content),
      timeline: extract_timeline_data(main_content),
      channels: extract_channel_list(main_content),
      key_messages: extract_key_messages(main_content),
      success_metrics: extract_success_metrics(main_content),
      creative_direction: extract_creative_direction(main_content),
      implementation_steps: extract_implementation_steps(main_content)
    }.compact

    {
      campaign_plan: plan_structure,
      format: 'campaign_plan',
      metadata: extract_metadata_hash(content),
      generated_at: Time.current,
      validation: validate_campaign_plan_completeness(plan_structure)
    }
  end

  def transform_to_brand_analysis(content)
    main_content = extract_main_content(content)

    analysis_structure = {
      brand_overview: extract_brand_overview(main_content),
      brand_voice: extract_brand_voice_analysis(main_content),
      brand_values: extract_brand_values(main_content),
      competitive_position: extract_competitive_analysis(main_content),
      opportunities: extract_opportunities(main_content),
      recommendations: extract_recommendations(main_content),
      compliance_notes: extract_compliance_notes(main_content),
      risk_assessment: extract_risk_assessment(main_content)
    }.compact

    {
      brand_analysis: analysis_structure,
      format: 'brand_analysis',
      metadata: extract_metadata_hash(content),
      analysis_date: Time.current,
      confidence_scores: calculate_analysis_confidence(analysis_structure)
    }
  end

  def transform_to_content_generation(content)
    main_content = extract_main_content(content)
    content_type = @options[:content_type] || 'general'

    generated_content = {
      primary_content: extract_primary_content(main_content),
      variations: extract_content_variations(main_content),
      metadata: {
        content_type: content_type,
        word_count: count_words(extract_primary_content(main_content)),
        character_count: extract_primary_content(main_content).to_s.length,
        readability_score: estimate_readability(extract_primary_content(main_content)),
        key_themes: extract_key_themes(main_content)
      },
      optimization_suggestions: extract_optimization_suggestions(main_content)
    }

    {
      generated_content: generated_content,
      format: 'content_generation',
      content_type: content_type,
      metadata: extract_metadata_hash(content),
      generated_at: Time.current
    }
  end

  def transform_to_social_media(content)
    main_content = extract_main_content(content)
    
    social_content = {
      post_text: extract_social_post_text(main_content),
      hashtags: extract_hashtags_array(main_content),
      mentions: extract_mentions_array(main_content),
      call_to_action: extract_call_to_action(main_content),
      image_suggestions: extract_image_suggestions(main_content),
      platform_variations: generate_platform_variations(main_content)
    }.compact

    {
      social_media_content: social_content,
      format: 'social_media',
      metadata: extract_metadata_hash(content).merge(
        character_count: social_content[:post_text].to_s.length,
        hashtag_count: social_content[:hashtags]&.length || 0,
        mention_count: social_content[:mentions]&.length || 0
      ),
      generated_at: Time.current
    }
  end

  def transform_to_email_format(content)
    main_content = extract_main_content(content)

    email_structure = {
      subject_line: extract_field_value(main_content, %w[subject subject_line title]),
      preheader: extract_field_value(main_content, %w[preheader preview_text preview]),
      greeting: extract_field_value(main_content, %w[greeting salutation opening]),
      body: extract_email_body(main_content),
      call_to_action: extract_call_to_action(main_content),
      signature: extract_field_value(main_content, %w[signature closing sign_off]),
      personalization_fields: extract_personalization_fields(main_content)
    }.compact

    {
      email_content: email_structure,
      format: 'email',
      metadata: extract_metadata_hash(content).merge(
        estimated_read_time: estimate_read_time(email_structure[:body]),
        personalization_count: email_structure[:personalization_fields]&.length || 0
      ),
      generated_at: Time.current
    }
  end

  def transform_to_ad_copy(content)
    main_content = extract_main_content(content)

    ad_structure = {
      headline: extract_ad_headline(main_content),
      description: extract_ad_description(main_content),
      call_to_action: extract_call_to_action(main_content),
      key_benefits: extract_key_benefits(main_content),
      target_keywords: extract_target_keywords(main_content),
      ad_variations: generate_ad_variations(main_content)
    }.compact

    {
      ad_copy: ad_structure,
      format: 'ad_copy',
      metadata: extract_metadata_hash(content).merge(
        headline_length: ad_structure[:headline].to_s.length,
        description_length: ad_structure[:description].to_s.length,
        variation_count: ad_structure[:ad_variations]&.length || 0
      ),
      generated_at: Time.current
    }
  end

  def transform_to_blog_post(content)
    main_content = extract_main_content(content)

    blog_structure = {
      title: extract_blog_title(main_content),
      meta_description: extract_meta_description(main_content),
      introduction: extract_blog_introduction(main_content),
      main_content: extract_blog_main_content(main_content),
      conclusion: extract_blog_conclusion(main_content),
      tags: extract_blog_tags(main_content),
      seo_keywords: extract_seo_keywords(main_content),
      featured_image_suggestions: extract_image_suggestions(main_content)
    }.compact

    {
      blog_post: blog_structure,
      format: 'blog_post',
      metadata: extract_metadata_hash(content).merge(
        word_count: count_words(blog_structure[:main_content]),
        estimated_read_time: estimate_read_time(blog_structure[:main_content]),
        seo_score: calculate_seo_score(blog_structure)
      ),
      generated_at: Time.current
    }
  end

  def transform_to_landing_page(content)
    main_content = extract_main_content(content)

    landing_page_structure = {
      headline: extract_landing_headline(main_content),
      subheadline: extract_landing_subheadline(main_content),
      hero_section: extract_hero_section(main_content),
      value_proposition: extract_value_proposition(main_content),
      features: extract_feature_list(main_content),
      testimonials: extract_testimonials(main_content),
      call_to_action: extract_call_to_action(main_content),
      footer_content: extract_footer_content(main_content)
    }.compact

    {
      landing_page: landing_page_structure,
      format: 'landing_page',
      metadata: extract_metadata_hash(content).merge(
        conversion_elements: count_conversion_elements(landing_page_structure),
        trust_signals: count_trust_signals(landing_page_structure)
      ),
      generated_at: Time.current
    }
  end

  def transform_to_optimization_report(content)
    main_content = extract_main_content(content)

    report_structure = {
      executive_summary: extract_executive_summary(main_content),
      current_performance: extract_performance_metrics(main_content),
      opportunities: extract_optimization_opportunities(main_content),
      recommendations: extract_prioritized_recommendations(main_content),
      implementation_timeline: extract_implementation_timeline(main_content),
      expected_results: extract_expected_results(main_content),
      success_metrics: extract_success_metrics(main_content)
    }.compact

    {
      optimization_report: report_structure,
      format: 'optimization_report',
      metadata: extract_metadata_hash(content).merge(
        recommendation_count: report_structure[:recommendations]&.length || 0,
        priority_level: calculate_priority_level(report_structure)
      ),
      generated_at: Time.current
    }
  end

  def transform_to_json(content)
    case content
    when Hash
      content.to_json
    when String
      begin
        # Try to parse as JSON first
        JSON.parse(content).to_json
      rescue JSON::ParserError
        # Convert text to structured JSON
        { content: content, format: 'text', transformed_at: Time.current.iso8601 }.to_json
      end
    else
      { content: content.to_s, format: 'unknown', transformed_at: Time.current.iso8601 }.to_json
    end
  end

  def transform_to_markdown(content)
    main_content = extract_main_content(content)
    
    if main_content.is_a?(Hash)
      # Convert structured data to markdown
      markdown_content = []
      
      if title = main_content[:title] || main_content['title']
        markdown_content << "# #{title}\n"
      end
      
      main_content.each do |key, value|
        next if key.to_s == 'title'
        
        case value
        when Array
          markdown_content << "## #{key.to_s.humanize}\n"
          value.each { |item| markdown_content << "- #{item}" }
          markdown_content << ""
        when Hash
          markdown_content << "## #{key.to_s.humanize}\n"
          markdown_content << value.to_yaml.gsub(/^---\n/, '').strip
          markdown_content << ""
        else
          markdown_content << "## #{key.to_s.humanize}\n"
          markdown_content << value.to_s
          markdown_content << ""
        end
      end
      
      markdown_content.join("\n")
    else
      # Ensure proper markdown formatting
      format_as_markdown(main_content.to_s)
    end
  end

  def transform_to_html(content)
    main_content = extract_main_content(content)
    
    if main_content.is_a?(Hash)
      # Convert structured data to HTML
      html_content = ["<div class='transformed-content'>"]
      
      if title = main_content[:title] || main_content['title']
        html_content << "<h1>#{CGI.escapeHTML(title)}</h1>"
      end
      
      main_content.each do |key, value|
        next if key.to_s == 'title'
        
        html_content << "<div class='section'>"
        html_content << "<h2>#{CGI.escapeHTML(key.to_s.humanize)}</h2>"
        
        case value
        when Array
          html_content << "<ul>"
          value.each { |item| html_content << "<li>#{CGI.escapeHTML(item.to_s)}</li>" }
          html_content << "</ul>"
        when Hash
          html_content << "<dl>"
          value.each do |k, v|
            html_content << "<dt>#{CGI.escapeHTML(k.to_s.humanize)}</dt>"
            html_content << "<dd>#{CGI.escapeHTML(v.to_s)}</dd>"
          end
          html_content << "</dl>"
        else
          html_content << "<p>#{CGI.escapeHTML(value.to_s)}</p>"
        end
        
        html_content << "</div>"
      end
      
      html_content << "</div>"
      html_content.join("\n")
    else
      # Convert text to basic HTML
      text = main_content.to_s
      html_text = CGI.escapeHTML(text)
      
      # Convert line breaks to paragraphs
      paragraphs = html_text.split(/\n\s*\n/).map { |p| p.strip }
      paragraphs.map { |p| "<p>#{p.gsub(/\n/, '<br>')}</p>" }.join("\n")
    end
  end

  # Content extraction helper methods

  def extract_main_content(content)
    case content
    when Hash
      content[:content] || content['content'] || 
      content[:text] || content['text'] ||
      content[:body] || content['body'] ||
      content
    else
      content.to_s
    end
  end

  def extract_metadata_hash(content)
    case content
    when Hash
      content.except(:content, 'content', :text, 'text', :body, 'body')
    else
      { source_format: detect_source_format(content) }
    end
  end

  def extract_field_value(content, field_names)
    text = content.to_s
    
    field_names.each do |field|
      # Look for field followed by colon and value
      match = text.match(/#{Regexp.escape(field)}[:\-\s]*([^\n\r]+)/i)
      return match[1].strip if match
      
      # Look for field in structured format
      if content.is_a?(Hash)
        value = content[field] || content[field.to_sym]
        return value if value.present?
      end
    end
    
    nil
  end

  # Transformation utility methods

  def normalize_whitespace(content)
    if content.is_a?(Hash)
      content.transform_values do |value|
        value.is_a?(String) ? normalize_text_whitespace(value) : value
      end
    else
      normalize_text_whitespace(content.to_s)
    end
  end

  def normalize_text_whitespace(text)
    text.gsub(/\r\n|\r/, "\n")      # Normalize line endings
        .gsub(/[ \t]+/, ' ')        # Normalize spaces and tabs  
        .gsub(/\n{3,}/, "\n\n")     # Limit consecutive newlines
        .strip
  end

  def extract_content_metadata(content)
    if content.is_a?(Hash)
      metadata = content.dup
      main_content = extract_main_content(content)
      
      if main_content.is_a?(String)
        metadata[:word_count] = count_words(main_content)
        metadata[:character_count] = main_content.length
        metadata[:estimated_read_time] = estimate_read_time(main_content)
      end
      
      metadata
    else
      text = content.to_s
      {
        content: text,
        word_count: count_words(text),
        character_count: text.length,
        estimated_read_time: estimate_read_time(text)
      }
    end
  end

  def format_links(content)
    if content.is_a?(Hash)
      content.transform_values { |value| value.is_a?(String) ? format_text_links(value) : value }
    else
      format_text_links(content.to_s)
    end
  end

  def format_text_links(text)
    # Convert plain URLs to proper links
    text.gsub(%r{https?://[^\s]+}) { |url| "[#{url}](#{url})" }
  end

  def process_hashtags(content)
    if content.is_a?(Hash) && content[:hashtags]
      content
    elsif content.is_a?(String)
      hashtags = content.scan(/#\w+/)
      content_without_hashtags = content.gsub(/#\w+/, '').strip
      
      { content: content_without_hashtags, hashtags: hashtags }
    else
      content
    end
  end

  def extract_mentions(content)
    if content.is_a?(Hash) && content[:mentions]
      content
    elsif content.is_a?(String)
      mentions = content.scan(/@\w+/)
      content_without_mentions = content.gsub(/@\w+/, '').strip
      
      { content: content_without_mentions, mentions: mentions }
    else
      content
    end
  end

  def apply_branding(content)
    return content unless brand_guidelines.is_a?(Hash) && brand_guidelines.any?
    
    # Apply brand-specific transformations
    if brand_guidelines['brand_name']
      # Ensure brand name appears correctly
      content = content.to_s.gsub(/\b#{Regexp.escape(brand_guidelines['brand_name'])}\b/i, brand_guidelines['brand_name'])
    end
    
    content
  end

  def add_timestamps(content)
    if content.is_a?(Hash)
      content.merge(generated_at: Time.current, transformed_at: Time.current)
    else
      { content: content, generated_at: Time.current, transformed_at: Time.current }
    end
  end

  def include_source_info(content)
    source_info = {
      transformer_version: '1.0',
      transformation_options: transformation_options,
      target_format: target_format
    }
    
    if content.is_a?(Hash)
      content.merge(source_info: source_info)
    else
      { content: content, source_info: source_info }
    end
  end

  # Validation methods

  def validate_transformed_content!
    case target_format
    when 'campaign_plan'
      validate_campaign_plan_structure!
    when 'email'
      validate_email_structure!
    when 'social_media'
      validate_social_media_structure!
    when 'json'
      validate_json_structure!
    end
  end

  def validate_campaign_plan_structure!
    unless @transformed_content.is_a?(Hash) && @transformed_content[:campaign_plan]
      raise ValidationError, "Campaign plan structure is invalid"
    end
    
    required_fields = %w[objective target_audience]
    plan = @transformed_content[:campaign_plan]
    
    missing_fields = required_fields.select { |field| plan[field.to_sym].blank? && plan[field].blank? }
    if missing_fields.any?
      raise ValidationError, "Campaign plan missing required fields: #{missing_fields.join(', ')}"
    end
  end

  def validate_email_structure!
    unless @transformed_content.is_a?(Hash) && @transformed_content[:email_content]
      raise ValidationError, "Email structure is invalid"
    end
  end

  def validate_social_media_structure!
    unless @transformed_content.is_a?(Hash) && @transformed_content[:social_media_content]
      raise ValidationError, "Social media structure is invalid"
    end
  end

  def validate_json_structure!
    begin
      JSON.parse(@transformed_content) if @transformed_content.is_a?(String)
    rescue JSON::ParserError => e
      raise ValidationError, "Invalid JSON structure: #{e.message}"
    end
  end

  # Utility methods

  def count_words(text)
    text.to_s.split(/\W+/).reject(&:empty?).length
  end

  def estimate_read_time(text)
    word_count = count_words(text)
    # Average reading speed: 200 words per minute
    (word_count / 200.0).ceil
  end

  def estimate_readability(text)
    # Simplified readability score (0-100, higher is easier to read)
    sentences = text.to_s.split(/[.!?]+/).length
    words = count_words(text)
    
    return 0 if sentences == 0 || words == 0
    
    avg_sentence_length = words.to_f / sentences
    # Simple formula: shorter sentences = higher readability
    [100 - (avg_sentence_length * 2), 0].max.round
  end

  def format_as_markdown(text)
    # Basic markdown formatting for plain text
    lines = text.split("\n")
    formatted_lines = []
    
    lines.each_with_index do |line, index|
      line = line.strip
      next if line.empty?
      
      # Convert titles (first line or lines that look like titles)
      if index == 0 || line.match?(/^[A-Z][^.]*$/) && line.length > 10 && line.length < 100
        formatted_lines << "# #{line}"
      # Convert section headers  
      elsif line.match?(/^[A-Z][^:]*:$/)
        formatted_lines << "## #{line.gsub(/:$/, '')}"
      # Convert list items
      elsif line.match?(/^\s*[-*]\s+/)
        formatted_lines << line
      elsif line.match?(/^\s*\d+\.\s+/)
        formatted_lines << line
      else
        formatted_lines << line
      end
      
      formatted_lines << "" # Add blank line after each section
    end
    
    formatted_lines.join("\n").gsub(/\n{3,}/, "\n\n")
  end

  def generate_transformation_result
    {
      success: true,
      transformed_content: @transformed_content,
      target_format: target_format,
      metadata: @transformation_metadata,
      original_content: preserve_original ? @original_content : nil,
      transformation_options: transformation_options
    }
  end

  def transformation_error(message)
    {
      success: false,
      error: message,
      target_format: target_format,
      metadata: @transformation_metadata,
      original_content: preserve_original ? @original_content : nil
    }
  end

  # Placeholder methods for complex extractions (to be implemented as needed)
  def extract_budget_breakdown(content); extract_field_value(content, %w[budget allocation]); end
  def extract_timeline_data(content); extract_field_value(content, %w[timeline schedule]); end
  def extract_channel_list(content); extract_field_value(content, %w[channels platforms media])&.split(/[,\n]/)&.map(&:strip); end
  def extract_key_messages(content); extract_field_value(content, %w[messages key_messages])&.split(/[,\n]/)&.map(&:strip); end
  def extract_success_metrics(content); extract_field_value(content, %w[metrics kpis success_criteria])&.split(/[,\n]/)&.map(&:strip); end
  def extract_creative_direction(content); extract_field_value(content, %w[creative direction style]); end
  def extract_implementation_steps(content); extract_field_value(content, %w[steps implementation tasks])&.split(/[,\n]/)&.map(&:strip); end
  def validate_campaign_plan_completeness(plan); { complete: plan.keys.length >= 5, missing_fields: [] }; end
  
  # More placeholder methods for other content types
  def extract_brand_overview(content); extract_field_value(content, %w[overview summary]); end
  def extract_brand_voice_analysis(content); extract_field_value(content, %w[voice tone brand_voice]); end
  def extract_brand_values(content); extract_field_value(content, %w[values core_values principles])&.split(/[,\n]/)&.map(&:strip); end
  def extract_competitive_analysis(content); extract_field_value(content, %w[competitive competition analysis]); end
  def extract_opportunities(content); extract_field_value(content, %w[opportunities potential suggestions])&.split(/[,\n]/)&.map(&:strip); end
  def extract_recommendations(content); extract_field_value(content, %w[recommendations suggestions advice])&.split(/[,\n]/)&.map(&:strip); end
  def extract_compliance_notes(content); extract_field_value(content, %w[compliance legal regulations]); end
  def extract_risk_assessment(content); extract_field_value(content, %w[risks assessment concerns]); end
  def calculate_analysis_confidence(analysis); { overall: 85, detailed_scores: {} }; end
  
  # Additional placeholder methods would continue for other content types...
  def extract_primary_content(content); content.to_s; end
  def extract_content_variations(content); []; end
  def extract_key_themes(content); []; end
  def extract_optimization_suggestions(content); []; end
  def extract_social_post_text(content); content.to_s; end
  def extract_hashtags_array(content); content.to_s.scan(/#\w+/); end
  def extract_mentions_array(content); content.to_s.scan(/@\w+/); end
  def extract_call_to_action(content); extract_field_value(content, %w[cta call_to_action action]); end
  def extract_image_suggestions(content); []; end
  def generate_platform_variations(content); {}; end
  def extract_email_body(content); content.to_s; end
  def extract_personalization_fields(content); []; end
end