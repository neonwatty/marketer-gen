# Email content generation adapter
# Handles welcome series, nurture campaigns, promotional emails with personalization
class ContentAdapters::EmailAdapter < ContentAdapters::BaseChannelAdapter
  # Email type configurations
  EMAIL_TYPES = {
    welcome: {
      subject_max_length: 50,
      body_optimal_length: [200, 400],
      personalization_level: :high,
      call_to_action: :required,
      tone: 'friendly'
    },
    nurture: {
      subject_max_length: 60,
      body_optimal_length: [300, 600],
      personalization_level: :medium,
      call_to_action: :optional,
      tone: 'helpful'
    },
    promotional: {
      subject_max_length: 45,
      body_optimal_length: [150, 300],
      personalization_level: :medium,
      call_to_action: :required,
      tone: 'exciting'
    },
    newsletter: {
      subject_max_length: 55,
      body_optimal_length: [500, 1000],
      personalization_level: :low,
      call_to_action: :multiple,
      tone: 'informative'
    },
    transactional: {
      subject_max_length: 60,
      body_optimal_length: [100, 300],
      personalization_level: :high,
      call_to_action: :specific,
      tone: 'professional'
    },
    re_engagement: {
      subject_max_length: 50,
      body_optimal_length: [200, 350],
      personalization_level: :high,
      call_to_action: :required,
      tone: 'personal'
    }
  }.freeze

  # Subject line best practices
  SUBJECT_LINE_PATTERNS = {
    welcome: [
      "Welcome to {{brand_name}}, {{first_name}}!",
      "{{first_name}}, let's get started!",
      "Your journey with {{brand_name}} begins now"
    ],
    promotional: [
      "{{discount}}% off just for you, {{first_name}}",
      "Last chance: {{offer}} expires soon",
      "{{first_name}}, don't miss this exclusive offer"
    ],
    nurture: [
      "{{first_name}}, here's what you need to know",
      "Your next step towards {{goal}}",
      "{{first_name}}, we thought you'd find this helpful"
    ],
    newsletter: [
      "{{brand_name}} Weekly: {{main_topic}}",
      "This week's top {{industry}} insights",
      "{{first_name}}, your {{frequency}} update is here"
    ]
  }.freeze

  protected

  def setup_channel_metadata
    super
    @supported_content_types = %w[welcome nurture promotional newsletter transactional re_engagement drip_sequence]
    @constraints = {
      subject_max_length: 50,
      body_max_length: 2000,
      min_length: 50,
      personalization_required: true,
      cta_required: true
    }
  end

  public

  def generate_content(request)
    validate_email_request!(request)
    
    email_type = determine_email_type(request)
    email_config = EMAIL_TYPES[email_type.to_sym] || EMAIL_TYPES[:nurture]
    
    # Build AI prompt for email content
    ai_prompt = build_email_prompt(request, email_type, email_config)
    
    # Generate content using AI service
    ai_response = ai_service.generate_content_for_channel(
      'email',
      ai_prompt,
      {
        max_tokens: calculate_email_max_tokens(email_config),
        temperature: determine_email_creativity(email_type),
        email_type: email_type
      }
    )
    
    # Parse AI response into email components
    email_components = parse_email_response(ai_response, email_config)
    
    # Apply personalization
    personalized_components = apply_personalization(email_components, request)
    
    # Format email content
    formatted_email = format_email_content(personalized_components, email_type, request)
    
    # Build response
    response = ContentResponse.new(
      content: formatted_email[:body],
      channel_type: 'email',
      content_type: email_type,
      request_id: request.request_id,
      title: formatted_email[:subject],
      subtitle: formatted_email[:preheader],
      call_to_action: formatted_email[:cta],
      sections: formatted_email[:sections] || [],
      channel_specific_data: build_email_metadata(email_type, formatted_email, request)
    )
    
    response
  end

  def optimize_content(content, performance_data = {})
    optimization_suggestions = []
    
    # Extract performance metrics
    open_rate = performance_data[:open_rate] || 0
    click_rate = performance_data[:click_rate] || 0
    unsubscribe_rate = performance_data[:unsubscribe_rate] || 0
    
    # Subject line optimization
    if open_rate < 0.20
      optimization_suggestions << {
        type: :subject_line,
        suggestion: "Low open rate detected. Try shorter, more personal subject lines with urgency or curiosity",
        priority: :high,
        specific_tips: [
          "Use recipient's first name",
          "Create sense of urgency or scarcity",
          "Ask a question to spark curiosity",
          "Avoid spam trigger words"
        ]
      }
    end
    
    # Content length optimization
    word_count = content.split.size
    if click_rate < 0.03 && word_count > 200
      optimization_suggestions << {
        type: :length,
        suggestion: "Long content with low engagement. Consider shorter, more focused messages",
        priority: :medium
      }
    end
    
    # Call-to-action optimization
    if click_rate < 0.05
      optimization_suggestions << {
        type: :cta,
        suggestion: "Low click-through rate. Strengthen call-to-action and make it more prominent",
        priority: :high,
        specific_tips: [
          "Use action-oriented button text",
          "Create single, clear call-to-action",
          "Add urgency or incentive",
          "Make CTA visually prominent"
        ]
      }
    end
    
    # Unsubscribe rate optimization
    if unsubscribe_rate > 0.005
      optimization_suggestions << {
        type: :retention,
        suggestion: "High unsubscribe rate indicates content may not match subscriber expectations",
        priority: :high,
        specific_tips: [
          "Ensure content matches what was promised",
          "Reduce frequency if sending too often",
          "Improve segmentation and personalization",
          "Provide more value in each email"
        ]
      }
    end
    
    # Personalization optimization
    unless has_personalization?(content)
      optimization_suggestions << {
        type: :personalization,
        suggestion: "Add personalization elements to improve engagement",
        priority: :medium
      }
    end
    
    optimization_suggestions
  end

  def validate_content(content, request)
    email_type = determine_email_type(request)
    email_config = EMAIL_TYPES[email_type.to_sym]
    errors = []
    
    # Parse email components for validation
    components = parse_email_content_for_validation(content)
    
    # Subject line validation
    if components[:subject] && components[:subject].length > email_config[:subject_max_length]
      errors << "Subject line too long: #{components[:subject].length}/#{email_config[:subject_max_length]} characters"
    end
    
    if components[:subject] && has_spam_triggers?(components[:subject])
      errors << "Subject line contains potential spam triggers"
    end
    
    # Body length validation
    word_count = content.split.size
    optimal_range = email_config[:body_optimal_length]
    if word_count < optimal_range[0]
      errors << "Email body too short for #{email_type} type (#{word_count} words, recommended: #{optimal_range[0]}-#{optimal_range[1]})"
    elsif word_count > optimal_range[1] * 2
      errors << "Email body too long for #{email_type} type (#{word_count} words, recommended: #{optimal_range[0]}-#{optimal_range[1]})"
    end
    
    # Call-to-action validation
    if email_config[:call_to_action] == :required && !has_call_to_action?(content)
      errors << "#{email_type.capitalize} emails require a call-to-action"
    end
    
    # Personalization validation
    if email_config[:personalization_level] == :high && !has_personalization?(content)
      errors << "#{email_type.capitalize} emails should include personalization"
    end
    
    raise ContentValidationError, errors.join('; ') unless errors.empty?
    true
  end

  def supports_variants?
    true
  end

  def supports_optimization?
    true
  end

  def generate_variants(request, count: 3)
    variants = []
    
    count.times do |index|
      variant_request = request.dup
      variant_strategy = [:subject_variation, :length_variation, :cta_variation][index % 3]
      
      variant_request.variant_context = {
        variant_index: index + 1,
        total_variants: count,
        strategy: variant_strategy
      }
      
      # Apply strategy-specific modifications
      case variant_strategy
      when :subject_variation
        variant_request.requirements << "test_subject_line_#{index + 1}"
      when :length_variation
        variant_request.constraints[:target_length] = vary_email_length(request, index)
      when :cta_variation
        variant_request.requirements << "alternative_cta_#{index + 1}"
      end
      
      variants << generate_content(variant_request)
    end
    
    variants
  end

  protected

  def determine_email_type(request)
    # Extract email type from content type or campaign context
    content_type = request.content_type.to_s.downcase
    
    return content_type if EMAIL_TYPES.key?(content_type.to_sym)
    
    # Infer email type from context
    if request.campaign_context[:sequence_type]
      return request.campaign_context[:sequence_type]
    end
    
    if request.optimization_goals.include?('conversion')
      return 'promotional'
    elsif request.optimization_goals.include?('engagement')
      return 'nurture'
    end
    
    'nurture' # Default
  end

  def validate_email_request!(request)
    if request.brand_context[:name].blank?
      raise InvalidContentRequestError, "Brand name is required for email generation"
    end
    
    if request.target_audience.blank?
      raise InvalidContentRequestError, "Target audience information is required for email personalization"
    end
  end

  def build_email_prompt(request, email_type, email_config)
    context = request.to_ai_context
    
    prompt_parts = []
    prompt_parts << "Create a #{email_type} email for #{context[:brand_context][:name]}."
    
    # Add email type specific guidance
    case email_type.to_sym
    when :welcome
      prompt_parts << "This is a welcome email for new subscribers. Make them feel valued and set expectations."
    when :nurture
      prompt_parts << "This is a nurture email to build relationships and provide value without direct selling."
    when :promotional
      prompt_parts << "This is a promotional email with a specific offer or product focus."
    when :newsletter
      prompt_parts << "This is a newsletter with multiple pieces of valuable content."
    when :re_engagement
      prompt_parts << "This is to re-engage inactive subscribers. Be empathetic but compelling."
    end
    
    # Brand and audience context
    prompt_parts << "Brand context: #{format_brand_context_for_email(context[:brand_context])}"
    prompt_parts << "Target audience: #{format_audience_for_email(context[:target_audience])}"
    
    # Email requirements
    prompt_parts << "Requirements:"
    prompt_parts << "- Subject line: maximum #{email_config[:subject_max_length]} characters"
    prompt_parts << "- Body: #{email_config[:body_optimal_length][0]}-#{email_config[:body_optimal_length][1]} words optimal"
    prompt_parts << "- Tone: #{email_config[:tone]}"
    prompt_parts << "- Personalization level: #{email_config[:personalization_level]}"
    
    if email_config[:call_to_action] == :required
      prompt_parts << "- Must include clear call-to-action"
    end
    
    # Content prompt
    prompt_parts << "Content focus: #{request.prompt}"
    
    # Campaign context
    if request.campaign_context.any?
      prompt_parts << "Campaign context: #{format_campaign_context_for_email(request.campaign_context)}"
    end
    
    # Variant context
    if request.variant_context.any?
      prompt_parts << apply_variant_instructions(request.variant_context, email_type)
    end
    
    # Output format
    prompt_parts << "\nFormat your response as follows:"
    prompt_parts << "SUBJECT: [compelling subject line]"
    prompt_parts << "PREHEADER: [preview text that complements subject]"
    prompt_parts << "GREETING: [personalized greeting]"
    prompt_parts << "BODY: [main email content]"
    prompt_parts << "CTA: [call-to-action with button text and URL placeholder]"
    prompt_parts << "SIGNATURE: [closing and signature]"
    
    prompt_parts.join("\n")
  end

  def parse_email_response(ai_response, email_config)
    components = {}
    
    # Extract structured components
    components[:subject] = extract_component(ai_response, 'SUBJECT')
    components[:preheader] = extract_component(ai_response, 'PREHEADER')
    components[:greeting] = extract_component(ai_response, 'GREETING')
    components[:body] = extract_component(ai_response, 'BODY')
    components[:cta] = extract_component(ai_response, 'CTA')
    components[:signature] = extract_component(ai_response, 'SIGNATURE')
    
    # Fallback parsing if structured format not used
    if components[:subject].blank?
      components = parse_unstructured_email_response(ai_response)
    end
    
    components
  end

  def apply_personalization(components, request)
    personalized = components.dup
    
    # Get personalization data
    person_data = extract_personalization_data(request)
    
    # Apply personalization tokens
    personalized.each do |key, content|
      next unless content.is_a?(String)
      
      # Replace personalization tokens
      person_data.each do |token, value|
        personalized[key] = content.gsub("{{#{token}}}", value.to_s)
      end
    end
    
    # Add dynamic personalization based on audience data
    personalized[:greeting] = personalize_greeting(personalized[:greeting], person_data)
    personalized[:subject] = personalize_subject_line(personalized[:subject], person_data, request)
    
    personalized
  end

  def format_email_content(components, email_type, request)
    formatted = {
      subject: components[:subject] || "Update from #{request.brand_context[:name]}",
      preheader: components[:preheader] || "",
      body: build_email_body(components),
      cta: extract_cta_details(components[:cta]),
      sections: split_into_sections(components[:body])
    }
    
    # Apply email type specific formatting
    case email_type.to_sym
    when :newsletter
      formatted[:sections] = format_newsletter_sections(components, request)
    when :promotional
      formatted = add_promotional_elements(formatted, request)
    when :welcome
      formatted = add_welcome_elements(formatted, request)
    end
    
    formatted
  end

  def build_email_metadata(email_type, formatted_email, request)
    {
      email_type: email_type,
      subject_length: formatted_email[:subject].length,
      body_word_count: formatted_email[:body].split.size,
      personalization_tokens: count_personalization_tokens(formatted_email[:body]),
      has_cta: formatted_email[:cta].present?,
      spam_score: calculate_spam_score(formatted_email),
      delivery_recommendations: generate_delivery_recommendations(email_type, request),
      a_b_test_suggestions: generate_ab_test_suggestions(email_type)
    }
  end

  # Utility methods
  def format_brand_context_for_email(brand_context)
    parts = []
    parts << "Company: #{brand_context[:name]}"
    parts << "Industry: #{brand_context[:industry]}" if brand_context[:industry]
    parts << "Brand voice: #{brand_context[:voice]}" if brand_context[:voice]
    parts << "Values: #{brand_context[:values]&.join(', ')}" if brand_context[:values]
    parts.join(", ")
  end

  def format_audience_for_email(target_audience)
    parts = []
    parts << "Demographics: #{target_audience[:demographics]}" if target_audience[:demographics]
    parts << "Interests: #{target_audience[:interests]&.join(', ')}" if target_audience[:interests]
    parts << "Pain points: #{target_audience[:pain_points]&.join(', ')}" if target_audience[:pain_points]
    parts << "Goals: #{target_audience[:goals]&.join(', ')}" if target_audience[:goals]
    parts.join(", ")
  end

  def format_campaign_context_for_email(campaign_context)
    parts = []
    parts << "Campaign: #{campaign_context[:name]}" if campaign_context[:name]
    parts << "Goal: #{campaign_context[:objective]}" if campaign_context[:objective]
    parts << "Sequence position: #{campaign_context[:sequence_position]}" if campaign_context[:sequence_position]
    parts << "Previous interactions: #{campaign_context[:previous_engagement]}" if campaign_context[:previous_engagement]
    parts.join(", ")
  end

  def apply_variant_instructions(variant_context, email_type)
    case variant_context[:strategy]
    when :subject_variation
      "Create 3 different subject line approaches: curiosity-driven, benefit-focused, and urgency-based."
    when :length_variation
      "Adjust content length - make this version #{variant_context[:variant_index] == 1 ? 'shorter and punchier' : 'more detailed and comprehensive'}."
    when :cta_variation
      "Test different call-to-action approaches: #{variant_context[:variant_index] == 1 ? 'direct action' : 'value proposition focused'}."
    else
      ""
    end
  end

  def extract_component(text, component_name)
    pattern = /#{component_name}:\s*(.+?)(?=\n[A-Z]+:|$)/m
    match = text.match(pattern)
    match ? match[1].strip : ""
  end

  def parse_unstructured_email_response(response)
    # Fallback parser for unstructured responses
    lines = response.split("\n")
    
    {
      subject: extract_likely_subject_line(lines),
      preheader: "",
      greeting: extract_likely_greeting(lines),
      body: response, # Use full response as body
      cta: extract_likely_cta(response),
      signature: extract_likely_signature(lines)
    }
  end

  def extract_personalization_data(request)
    data = {
      'brand_name' => request.brand_context[:name],
      'first_name' => request.target_audience[:first_name] || 'there',
      'company' => request.target_audience[:company] || '',
      'industry' => request.brand_context[:industry] || ''
    }
    
    # Add campaign-specific data
    if request.campaign_context[:discount]
      data['discount'] = request.campaign_context[:discount]
    end
    
    if request.campaign_context[:offer]
      data['offer'] = request.campaign_context[:offer]
    end
    
    data
  end

  def personalize_greeting(greeting, person_data)
    return "Hi #{person_data['first_name']}," if greeting.blank?
    
    # Enhance existing greeting with personalization
    if greeting.include?('Hi') || greeting.include?('Hello')
      greeting.gsub(/Hi|Hello/, "Hi #{person_data['first_name']}")
    else
      "Hi #{person_data['first_name']}, #{greeting}"
    end
  end

  def personalize_subject_line(subject_line, person_data, request)
    return subject_line if subject_line.blank?
    
    # Apply subject line patterns if generic
    if subject_line.length < 20 || !subject_line.include?(person_data['first_name'])
      email_type = determine_email_type(request)
      patterns = SUBJECT_LINE_PATTERNS[email_type.to_sym]
      
      if patterns && rand < 0.3 # 30% chance to use pattern
        pattern = patterns.sample
        return apply_personalization_tokens(pattern, person_data)
      end
    end
    
    subject_line
  end

  def apply_personalization_tokens(text, person_data)
    result = text.dup
    person_data.each do |token, value|
      result = result.gsub("{{#{token}}}", value.to_s)
    end
    result
  end

  def build_email_body(components)
    body_parts = []
    
    body_parts << components[:greeting] if components[:greeting].present?
    body_parts << components[:body] if components[:body].present?
    
    if components[:cta].present?
      body_parts << "\n#{components[:cta]}"
    end
    
    body_parts << components[:signature] if components[:signature].present?
    
    body_parts.join("\n\n")
  end

  def extract_cta_details(cta_text)
    return nil if cta_text.blank?
    
    # Extract button text and URL if present
    button_match = cta_text.match(/\[([^\]]+)\]\(([^)]+)\)/) # Markdown link format
    
    if button_match
      {
        text: button_match[1],
        url: button_match[2],
        full_text: cta_text
      }
    else
      {
        text: cta_text,
        url: '[URL_PLACEHOLDER]',
        full_text: cta_text
      }
    end
  end

  def split_into_sections(body_text)
    return [] if body_text.blank?
    
    # Split by double line breaks or section indicators
    sections = body_text.split(/\n\n+/).map(&:strip).reject(&:blank?)
    
    sections.map.with_index do |section, index|
      {
        id: "section_#{index + 1}",
        content: section,
        type: determine_section_type(section)
      }
    end
  end

  def determine_section_type(section)
    if section.include?('?')
      'question'
    elsif has_call_to_action?(section)
      'cta'
    elsif section.length < 50
      'header'
    else
      'content'
    end
  end

  def has_personalization?(content)
    personalization_indicators = [
      /\{\{[^}]+\}\}/, # Template tokens
      /\b(you|your)\b/i, # Direct address
      /Hi [A-Z][a-z]+,/, # Personalized greeting
      /@[a-zA-Z]+/ # Name mentions
    ]
    
    personalization_indicators.any? { |pattern| content.match?(pattern) }
  end

  def has_spam_triggers?(text)
    spam_words = %w[
      FREE URGENT ACT\ NOW LIMITED\ TIME GUARANTEE CONGRATULATIONS
      WINNER CASH MONEY PRIZE BONUS DISCOUNT% SAVE$ CHEAP
    ]
    
    spam_patterns = [
      /!{3,}/, # Multiple exclamation marks
      /[A-Z]{5,}/, # All caps words
      /\$\$+/, # Multiple dollar signs
    ]
    
    text_upper = text.upcase
    
    spam_words.any? { |word| text_upper.include?(word) } ||
    spam_patterns.any? { |pattern| text.match?(pattern) }
  end

  def calculate_spam_score(email_components)
    score = 0
    
    # Subject line spam indicators
    if has_spam_triggers?(email_components[:subject])
      score += 0.3
    end
    
    # Body spam indicators
    if has_spam_triggers?(email_components[:body])
      score += 0.2
    end
    
    # Length indicators
    if email_components[:subject].length > 60
      score += 0.1
    end
    
    # Excessive punctuation
    if email_components[:body].count('!') > 3
      score += 0.1
    end
    
    [score, 1.0].min
  end

  def count_personalization_tokens(text)
    text.scan(/\{\{[^}]+\}\}/).size
  end

  def vary_email_length(request, index)
    base_length = request.constraints[:max_length] || 400
    
    case index
    when 0
      base_length * 0.6 # Short version
    when 1
      base_length * 1.4 # Long version
    else
      base_length # Standard version
    end
  end

  def calculate_email_max_tokens(email_config)
    # Estimate tokens needed for optimal email length
    max_words = email_config[:body_optimal_length][1]
    (max_words * 1.5).ceil + 100 # Buffer for structure
  end

  def determine_email_creativity(email_type)
    creativity_levels = {
      welcome: 0.7,
      nurture: 0.6,
      promotional: 0.8,
      newsletter: 0.5,
      transactional: 0.3,
      re_engagement: 0.8
    }
    
    creativity_levels[email_type.to_sym] || 0.6
  end

  def generate_delivery_recommendations(email_type, request)
    recommendations = []
    
    case email_type.to_sym
    when :welcome
      recommendations << "Send immediately after signup"
      recommendations << "Follow up with series over 7 days"
    when :promotional
      recommendations << "Best days: Tuesday-Thursday"
      recommendations << "Best times: 10 AM - 2 PM EST"
    when :newsletter
      recommendations << "Consistent schedule (weekly/monthly)"
      recommendations << "Same day and time each period"
    when :re_engagement
      recommendations << "Send during high-activity hours"
      recommendations << "Consider timezone of inactive users"
    end
    
    recommendations
  end

  def generate_ab_test_suggestions(email_type)
    suggestions = []
    
    case email_type.to_sym
    when :promotional
      suggestions << "Test different discount percentages in subject line"
      suggestions << "Test urgency vs benefit-focused copy"
    when :welcome
      suggestions << "Test immediate value vs relationship building"
      suggestions << "Test single CTA vs multiple options"
    when :nurture
      suggestions << "Test educational vs entertainment content"
      suggestions << "Test personal stories vs industry insights"
    end
    
    suggestions
  end

  # Helper methods for parsing unstructured responses
  def extract_likely_subject_line(lines)
    # Look for short lines at the beginning that could be subjects
    subject_candidates = lines.first(3).select { |line| line.length < 60 && !line.include?('Hi ') }
    subject_candidates.first || "Update from #{brand_context[:name]}"
  end

  def extract_likely_greeting(lines)
    greeting_line = lines.find { |line| line.match?(/^(Hi|Hello|Dear|Good morning)/) }
    greeting_line || "Hi there,"
  end

  def extract_likely_cta(text)
    cta_patterns = [
      /(?:learn more|get started|sign up|contact us|buy now|shop now|discover|try now|click here|read more)/i
    ]
    
    cta_patterns.each do |pattern|
      match = text.match(pattern)
      return match[0] if match
    end
    
    nil
  end

  def extract_likely_signature(lines)
    # Look for signature patterns at the end
    signature_indicators = ['best', 'regards', 'sincerely', 'thanks', 'team']
    
    signature_candidates = lines.last(3).select do |line|
      signature_indicators.any? { |indicator| line.downcase.include?(indicator) }
    end
    
    signature_candidates.first || "Best regards,\nThe #{brand_context[:name]} Team"
  end
end