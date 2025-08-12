# Advertising content generation adapter
# Handles Google Ads, Facebook Ads, LinkedIn Ads with headline/description variations
class ContentAdapters::AdsAdapter < ContentAdapters::BaseChannelAdapter
  # Platform-specific ad constraints and best practices
  AD_PLATFORMS = {
    google_ads: {
      headline_max_length: 30,
      headline_count: 15, # Up to 15 headlines for responsive ads
      description_max_length: 90,
      description_count: 4, # Up to 4 descriptions
      path_max_length: 15,
      path_count: 2,
      extensions: ['sitelink', 'callout', 'structured_snippet'],
      character_limits: { responsive: true }
    },
    facebook_ads: {
      headline_max_length: 40,
      headline_count: 5,
      description_max_length: 125,
      description_count: 5,
      primary_text_max_length: 125,
      link_description_max_length: 30,
      formats: ['single_image', 'video', 'carousel', 'collection'],
      audience_targeting: true
    },
    instagram_ads: {
      headline_max_length: 40,
      headline_count: 5,
      description_max_length: 125,
      description_count: 5,
      primary_text_max_length: 125,
      hashtag_support: true,
      story_format: true,
      visual_focus: true
    },
    linkedin_ads: {
      headline_max_length: 150,
      headline_count: 3,
      description_max_length: 600,
      description_count: 3,
      intro_text_max_length: 600,
      b2b_focus: true,
      professional_tone: true
    },
    twitter_ads: {
      headline_max_length: 50,
      description_max_length: 450,
      character_limit: 280,
      hashtag_support: true,
      promoted_tweet: true
    },
    microsoft_ads: {
      headline_max_length: 30,
      headline_count: 15,
      description_max_length: 90,
      description_count: 4,
      similar_to: 'google_ads'
    }
  }.freeze

  # Ad types and their characteristics
  AD_TYPES = {
    search: {
      focus: :keywords,
      intent: :high,
      format: :text_only,
      best_practices: ['match search intent', 'include keywords', 'clear value proposition']
    },
    display: {
      focus: :visual,
      intent: :medium,
      format: :image_text,
      best_practices: ['eye-catching visuals', 'minimal text', 'strong branding']
    },
    shopping: {
      focus: :product,
      intent: :high,
      format: :product_feed,
      best_practices: ['product benefits', 'pricing/offers', 'trust indicators']
    },
    video: {
      focus: :storytelling,
      intent: :medium,
      format: :video,
      best_practices: ['hook in first 3 seconds', 'visual storytelling', 'clear CTA']
    },
    social: {
      focus: :engagement,
      intent: :low,
      format: :native,
      best_practices: ['platform-native feel', 'social proof', 'conversational tone']
    },
    retargeting: {
      focus: :conversion,
      intent: :high,
      format: :personalized,
      best_practices: ['reference previous interaction', 'incentives', 'urgency']
    }
  }.freeze

  protected

  def setup_channel_metadata
    super
    @supported_content_types = %w[search display shopping video social retargeting brand awareness conversion lead_generation]
    @constraints = {
      headline_max_length: 30,
      description_max_length: 90,
      requires_cta: true,
      conversion_focused: true
    }
  end

  public

  def generate_content(request)
    validate_ads_request!(request)
    
    platform = request.channel_metadata[:platform] || 'google_ads'
    ad_type = request.channel_metadata[:ad_type] || 'search'
    ad_format = request.channel_metadata[:ad_format] || 'text'
    
    platform_config = AD_PLATFORMS[platform.to_sym] || AD_PLATFORMS[:google_ads]
    ad_type_config = AD_TYPES[ad_type.to_sym] || AD_TYPES[:search]
    
    # Generate multiple ad variations
    ad_variations = generate_ad_variations(request, platform, ad_type, platform_config)
    
    # Select best variation or return all for A/B testing
    primary_ad = select_primary_ad_variation(ad_variations, request)
    
    # Build response with all variations
    response = ContentResponse.new(
      content: format_ad_content(primary_ad),
      channel_type: 'ads',
      content_type: ad_type,
      request_id: request.request_id,
      title: primary_ad[:headline],
      call_to_action: primary_ad[:cta],
      sections: format_ad_sections(ad_variations),
      channel_specific_data: build_ads_metadata(platform, ad_type, ad_variations, request)
    )
    
    response
  end

  def optimize_content(content, performance_data = {})
    optimization_suggestions = []
    
    # Extract performance metrics
    ctr = performance_data[:click_through_rate] || 0
    conversion_rate = performance_data[:conversion_rate] || 0
    cost_per_click = performance_data[:cost_per_click] || 0
    quality_score = performance_data[:quality_score] || 0
    
    # Click-through rate optimization
    if ctr < 0.02 # Below 2% CTR
      optimization_suggestions << {
        type: :headline,
        suggestion: "Low CTR suggests weak headlines. Test more compelling, benefit-focused headlines",
        priority: :high,
        specific_tips: [
          "Include numbers or statistics",
          "Use power words like 'proven', 'guaranteed', 'exclusive'",
          "Add urgency or scarcity elements",
          "Test question-based headlines"
        ]
      }
    end
    
    # Conversion rate optimization
    if conversion_rate < 0.05 && ctr > 0.02 # Good CTR but poor conversion
      optimization_suggestions << {
        type: :landing_page_alignment,
        suggestion: "Good CTR but low conversion suggests message mismatch with landing page",
        priority: :high,
        specific_tips: [
          "Ensure headline matches landing page headline",
          "Maintain consistent offer throughout journey",
          "Test different landing pages",
          "Improve page load speed"
        ]
      }
    end
    
    # Cost optimization
    if cost_per_click > performance_data[:target_cpc]&.to_f * 1.5
      optimization_suggestions << {
        type: :cost_efficiency,
        suggestion: "High cost per click indicates low relevance or high competition",
        priority: :medium,
        specific_tips: [
          "Add negative keywords",
          "Improve quality score with better relevance",
          "Test long-tail keyword variations",
          "Adjust bidding strategy"
        ]
      }
    end
    
    # Quality score optimization (Google Ads specific)
    if quality_score && quality_score < 7
      optimization_suggestions << {
        type: :quality_score,
        suggestion: "Low quality score increases costs and reduces ad visibility",
        priority: :high,
        specific_tips: [
          "Include target keywords in headlines",
          "Improve ad relevance to keywords",
          "Optimize landing page experience",
          "Test ad extensions"
        ]
      }
    end
    
    optimization_suggestions
  end

  def validate_content(content, request)
    platform = request.channel_metadata[:platform] || 'google_ads'
    platform_config = AD_PLATFORMS[platform.to_sym]
    errors = []
    
    # Parse ad components
    ad_components = parse_ad_content_for_validation(content)
    
    # Headline validation
    if ad_components[:headline] && ad_components[:headline].length > platform_config[:headline_max_length]
      errors << "Headline too long: #{ad_components[:headline].length}/#{platform_config[:headline_max_length]} characters"
    end
    
    # Description validation
    if ad_components[:description] && ad_components[:description].length > platform_config[:description_max_length]
      errors << "Description too long: #{ad_components[:description].length}/#{platform_config[:description_max_length]} characters"
    end
    
    # CTA validation
    unless has_call_to_action?(content)
      errors << "Ad content must include a clear call-to-action"
    end
    
    # Keyword relevance (for search ads)
    if request.channel_metadata[:keywords] && !includes_target_keywords?(content, request.channel_metadata[:keywords])
      errors << "Ad content should include target keywords for relevance"
    end
    
    # Platform-specific validations
    case platform.to_sym
    when :linkedin_ads
      unless has_professional_tone?(content)
        errors << "LinkedIn ads should maintain professional tone"
      end
    when :facebook_ads, :instagram_ads
      if ad_components[:headline] && has_clickbait_language?(ad_components[:headline])
        errors << "Avoid clickbait language that violates platform policies"
      end
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

  def generate_variants(request, count: 5)
    # Ads typically need multiple variations for testing
    platform = request.channel_metadata[:platform] || 'google_ads'
    platform_config = AD_PLATFORMS[platform.to_sym]
    
    # Generate different types of variations
    variation_strategies = [
      :benefit_focused,
      :feature_focused, 
      :urgency_based,
      :question_based,
      :social_proof_based
    ]
    
    variants = []
    
    count.times do |index|
      strategy = variation_strategies[index % variation_strategies.length]
      
      variant_request = request.dup
      variant_request.variant_context = {
        variant_index: index + 1,
        total_variants: count,
        strategy: strategy,
        variation_focus: determine_variation_focus(strategy)
      }
      
      variants << generate_content(variant_request)
    end
    
    variants
  end

  protected

  def validate_ads_request!(request)
    platform = request.channel_metadata[:platform]
    
    unless platform && AD_PLATFORMS.key?(platform.to_sym)
      raise InvalidContentRequestError, "Valid ad platform must be specified: #{AD_PLATFORMS.keys.join(', ')}"
    end
    
    if request.optimization_goals.empty? || !request.optimization_goals.include?('conversion')
      raise InvalidContentRequestError, "Ad content requires conversion-focused optimization goals"
    end
  end

  def generate_ad_variations(request, platform, ad_type, platform_config)
    variations = []
    
    # Generate multiple headlines
    headlines = generate_ad_headlines(request, platform_config, 5)
    
    # Generate multiple descriptions
    descriptions = generate_ad_descriptions(request, platform_config, 3)
    
    # Generate CTAs
    ctas = generate_ad_ctas(request, ad_type, 3)
    
    # Create combinations
    headlines.each_with_index do |headline, h_idx|
      descriptions.each_with_index do |description, d_idx|
        ctas.each_with_index do |cta, c_idx|
          variations << {
            id: "var_#{h_idx}_#{d_idx}_#{c_idx}",
            headline: headline,
            description: description,
            cta: cta,
            score: calculate_ad_variation_score(headline, description, cta, request)
          }
        end
      end
    end
    
    # Return top variations
    variations.sort_by { |v| -v[:score] }.take(10)
  end

  def generate_ad_headlines(request, platform_config, count)
    headlines = []
    max_length = platform_config[:headline_max_length]
    
    # Build AI prompt for headlines
    headline_prompt = build_headline_prompt(request, max_length)
    
    # Generate headlines
    ai_response = ai_service.generate_content_for_channel(
      'ads',
      headline_prompt,
      {
        max_tokens: 200,
        temperature: 0.8,
        platform: request.channel_metadata[:platform]
      }
    )
    
    # Parse multiple headlines from response
    parsed_headlines = parse_headlines_from_response(ai_response, max_length)
    
    # Ensure we have enough variations
    while parsed_headlines.size < count
      additional_headline = generate_single_headline(request, max_length, parsed_headlines.size)
      parsed_headlines << additional_headline if additional_headline.length <= max_length
    end
    
    parsed_headlines.take(count)
  end

  def generate_ad_descriptions(request, platform_config, count)
    descriptions = []
    max_length = platform_config[:description_max_length]
    
    # Build AI prompt for descriptions
    description_prompt = build_description_prompt(request, max_length)
    
    # Generate descriptions
    ai_response = ai_service.generate_content_for_channel(
      'ads',
      description_prompt,
      {
        max_tokens: 300,
        temperature: 0.7,
        platform: request.channel_metadata[:platform]
      }
    )
    
    # Parse multiple descriptions
    parsed_descriptions = parse_descriptions_from_response(ai_response, max_length)
    
    # Ensure we have enough variations
    while parsed_descriptions.size < count
      additional_desc = generate_single_description(request, max_length, parsed_descriptions.size)
      parsed_descriptions << additional_desc if additional_desc.length <= max_length
    end
    
    parsed_descriptions.take(count)
  end

  def generate_ad_ctas(request, ad_type, count)
    # Predefined CTAs based on ad type and goals
    cta_sets = {
      search: ['Get Started', 'Learn More', 'Shop Now', 'Get Quote', 'Sign Up'],
      display: ['Discover More', 'See How', 'Try Free', 'Get Offer', 'Join Now'],
      shopping: ['Buy Now', 'Shop Sale', 'See Prices', 'Order Online', 'Get Discount'],
      video: ['Watch Now', 'See More', 'Get Started', 'Try Today', 'Learn How'],
      retargeting: ['Complete Purchase', 'Return & Save', 'Finish Order', 'Claim Offer', 'Get Discount']
    }
    
    base_ctas = cta_sets[ad_type.to_sym] || cta_sets[:search]
    
    # Customize based on campaign context
    if request.campaign_context[:offer]
      base_ctas.unshift("Get #{request.campaign_context[:offer]}")
    end
    
    base_ctas.take(count)
  end

  def build_headline_prompt(request, max_length)
    context = request.to_ai_context
    
    prompt_parts = []
    prompt_parts << "Create #{max_length}-character compelling ad headlines for #{context[:brand_context][:name]}."
    prompt_parts << "Product/Service: #{request.prompt}"
    prompt_parts << "Target audience: #{format_target_audience_for_ads(context[:target_audience])}"
    prompt_parts << "Brand benefits: #{context[:brand_context][:unique_value_proposition] || 'quality and reliability'}"
    
    # Add keyword context if available
    if request.channel_metadata[:keywords]
      prompt_parts << "Target keywords: #{request.channel_metadata[:keywords].join(', ')}"
      prompt_parts << "Include relevant keywords naturally in headlines."
    end
    
    # Add campaign context
    if request.campaign_context[:offer]
      prompt_parts << "Special offer: #{request.campaign_context[:offer]}"
    end
    
    # Variation strategy context
    if request.variant_context[:strategy]
      prompt_parts << apply_headline_strategy_context(request.variant_context[:strategy])
    end
    
    prompt_parts << "Create 5 different headlines, each exactly under #{max_length} characters."
    prompt_parts << "Format: one headline per line, no numbering."
    
    prompt_parts.join("\n")
  end

  def build_description_prompt(request, max_length)
    context = request.to_ai_context
    
    prompt_parts = []
    prompt_parts << "Create compelling #{max_length}-character ad descriptions for #{context[:brand_context][:name]}."
    prompt_parts << "Product/Service: #{request.prompt}"
    prompt_parts << "Key benefits: #{context[:brand_context][:key_benefits]&.join(', ') || 'quality, reliability, value'}"
    prompt_parts << "Target audience: #{format_target_audience_for_ads(context[:target_audience])}"
    
    # Add differentiators
    if context[:brand_context][:differentiators]
      prompt_parts << "Unique differentiators: #{context[:brand_context][:differentiators].join(', ')}"
    end
    
    # Campaign context
    if request.campaign_context[:urgency]
      prompt_parts << "Add urgency: #{request.campaign_context[:urgency]}"
    end
    
    prompt_parts << "Include clear value proposition and encourage action."
    prompt_parts << "Create 3 different descriptions, each under #{max_length} characters."
    prompt_parts << "Format: one description per line, no numbering."
    
    prompt_parts.join("\n")
  end

  def select_primary_ad_variation(variations, request)
    # Score based on relevance, keyword inclusion, and best practices
    variations.max_by { |variation| variation[:score] }
  end

  def calculate_ad_variation_score(headline, description, cta, request)
    score = 0.5 # Base score
    
    # Keyword relevance score
    if request.channel_metadata[:keywords]
      keywords = request.channel_metadata[:keywords]
      keyword_score = calculate_keyword_relevance_score(headline + " " + description, keywords)
      score += keyword_score * 0.3
    end
    
    # Length optimization score
    headline_optimal = headline.length <= 25 # Shorter headlines often perform better
    score += 0.1 if headline_optimal
    
    # CTA strength score
    cta_strength = calculate_cta_strength(cta)
    score += cta_strength * 0.2
    
    # Brand mention score
    brand_name = request.brand_context[:name]
    if brand_name && (headline.include?(brand_name) || description.include?(brand_name))
      score += 0.1
    end
    
    [score, 1.0].min
  end

  def format_ad_content(ad_variation)
    parts = []
    parts << "Headline: #{ad_variation[:headline]}"
    parts << "Description: #{ad_variation[:description]}"
    parts << "Call-to-Action: #{ad_variation[:cta]}"
    parts.join("\n")
  end

  def format_ad_sections(ad_variations)
    ad_variations.map do |variation|
      {
        id: variation[:id],
        type: 'ad_variation',
        content: format_ad_content(variation),
        metadata: {
          score: variation[:score],
          headline_length: variation[:headline].length,
          description_length: variation[:description].length
        }
      }
    end
  end

  def build_ads_metadata(platform, ad_type, variations, request)
    {
      platform: platform,
      ad_type: ad_type,
      variation_count: variations.size,
      best_variation_score: variations.map { |v| v[:score] }.max,
      average_headline_length: variations.map { |v| v[:headline].length }.sum / variations.size,
      average_description_length: variations.map { |v| v[:description].length }.sum / variations.size,
      keyword_density: calculate_overall_keyword_density(variations, request),
      platform_compliance: check_platform_compliance(variations, platform),
      optimization_recommendations: generate_ads_optimization_recommendations(variations, request)
    }
  end

  # Utility methods
  def format_target_audience_for_ads(target_audience)
    parts = []
    parts << "Demographics: #{target_audience[:demographics]}" if target_audience[:demographics]
    parts << "Interests: #{target_audience[:interests]&.join(', ')}" if target_audience[:interests]
    parts << "Intent: #{target_audience[:purchase_intent] || 'research'}" if target_audience[:purchase_intent]
    parts.join(", ")
  end

  def apply_headline_strategy_context(strategy)
    case strategy
    when :benefit_focused
      "Focus on key benefits and value proposition."
    when :feature_focused
      "Highlight specific features and capabilities."
    when :urgency_based
      "Create urgency with time-sensitive language."
    when :question_based
      "Use questions to engage and create curiosity."
    when :social_proof_based
      "Include social proof elements like ratings or testimonials."
    else
      ""
    end
  end

  def parse_headlines_from_response(response, max_length)
    lines = response.split("\n").map(&:strip).reject(&:blank?)
    
    # Filter out lines that are too long or clearly not headlines
    headlines = lines.select do |line|
      line.length <= max_length && 
      line.length >= 10 && 
      !line.downcase.start_with?('description:', 'cta:', 'here are')
    end
    
    headlines.take(5)
  end

  def parse_descriptions_from_response(response, max_length)
    lines = response.split("\n").map(&:strip).reject(&:blank?)
    
    # Filter descriptions
    descriptions = lines.select do |line|
      line.length <= max_length && 
      line.length >= 20 && 
      !line.downcase.start_with?('headline:', 'cta:', 'here are')
    end
    
    descriptions.take(3)
  end

  def generate_single_headline(request, max_length, variation_index)
    # Fallback headline generation
    brand_name = request.brand_context[:name]
    benefit = request.brand_context[:key_benefits]&.first || "Quality Service"
    
    templates = [
      "#{benefit} from #{brand_name}",
      "Get #{benefit} Today",
      "#{brand_name}: #{benefit}",
      "Discover #{benefit}",
      "#{benefit} Made Simple"
    ]
    
    template = templates[variation_index % templates.size]
    template.length <= max_length ? template : template[0...max_length-3] + "..."
  end

  def generate_single_description(request, max_length, variation_index)
    # Fallback description generation
    brand_name = request.brand_context[:name]
    value_prop = request.brand_context[:unique_value_proposition] || "trusted solutions"
    
    templates = [
      "Discover why thousands choose #{brand_name} for #{value_prop}. Get started today!",
      "#{brand_name} delivers #{value_prop} you can trust. Learn more now.",
      "Join customers who rely on #{brand_name} for #{value_prop}. See how!",
      "Experience the #{brand_name} difference. #{value_prop.capitalize} guaranteed.",
      "Ready for #{value_prop}? #{brand_name} makes it easy. Start now!"
    ]
    
    template = templates[variation_index % templates.size]
    template.length <= max_length ? template : template[0...max_length-3] + "..."
  end

  def calculate_keyword_relevance_score(text, keywords)
    return 0 if keywords.empty?
    
    text_words = text.downcase.split(/\W+/)
    keyword_matches = keywords.count do |keyword|
      keyword_words = keyword.downcase.split(/\W+/)
      keyword_words.all? { |word| text_words.include?(word) }
    end
    
    keyword_matches.to_f / keywords.size
  end

  def calculate_cta_strength(cta)
    # Score CTA based on action words and urgency
    strong_action_words = %w[get buy shop start try discover save join claim]
    urgency_words = %w[now today limited exclusive instant immediately]
    
    score = 0.3 # Base score
    
    cta_lower = cta.downcase
    score += 0.4 if strong_action_words.any? { |word| cta_lower.include?(word) }
    score += 0.3 if urgency_words.any? { |word| cta_lower.include?(word) }
    
    score
  end

  def includes_target_keywords?(content, keywords)
    content_lower = content.downcase
    keywords.any? { |keyword| content_lower.include?(keyword.downcase) }
  end

  def has_professional_tone?(content)
    professional_indicators = %w[professional quality expertise solution service trusted proven reliable]
    unprofessional_indicators = %w[awesome crazy insane super amazing]
    
    content_lower = content.downcase
    professional_score = professional_indicators.count { |word| content_lower.include?(word) }
    unprofessional_score = unprofessional_indicators.count { |word| content_lower.include?(word) }
    
    professional_score >= unprofessional_score
  end

  def has_clickbait_language?(content)
    clickbait_phrases = [
      "you won't believe",
      "shocking",
      "this one trick",
      "doctors hate",
      "weird trick",
      "secret that",
      "unbelievable"
    ]
    
    content_lower = content.downcase
    clickbait_phrases.any? { |phrase| content_lower.include?(phrase) }
  end

  def parse_ad_content_for_validation(content)
    components = {}
    
    # Extract headline
    headline_match = content.match(/headline:\s*(.+?)(?=\n|$)/i)
    components[:headline] = headline_match[1].strip if headline_match
    
    # Extract description
    desc_match = content.match(/description:\s*(.+?)(?=\n|$)/i)
    components[:description] = desc_match[1].strip if desc_match
    
    # Extract CTA
    cta_match = content.match(/call[-\s]to[-\s]action:\s*(.+?)(?=\n|$)/i)
    components[:cta] = cta_match[1].strip if cta_match
    
    components
  end

  def determine_variation_focus(strategy)
    focus_mapping = {
      benefit_focused: "customer benefits and value",
      feature_focused: "product features and capabilities",
      urgency_based: "time-sensitive offers and scarcity",
      question_based: "engaging questions and curiosity",
      social_proof_based: "testimonials and trust indicators"
    }
    
    focus_mapping[strategy] || "general appeal"
  end

  def calculate_overall_keyword_density(variations, request)
    return 0 unless request.channel_metadata[:keywords]
    
    all_text = variations.map { |v| "#{v[:headline]} #{v[:description]}" }.join(" ")
    keyword_density = calculate_keyword_relevance_score(all_text, request.channel_metadata[:keywords])
    (keyword_density * 100).round(2) # Return as percentage
  end

  def check_platform_compliance(variations, platform)
    compliance_score = 1.0
    
    case platform.to_sym
    when :facebook_ads, :instagram_ads
      # Check for policy violations
      variations.each do |variation|
        text = "#{variation[:headline]} #{variation[:description]}"
        if has_clickbait_language?(text)
          compliance_score -= 0.2
        end
      end
    when :google_ads
      # Check trademark usage and capitalization
      variations.each do |variation|
        text = "#{variation[:headline]} #{variation[:description]}"
        if text.match(/[A-Z]{4,}/) # Excessive caps
          compliance_score -= 0.1
        end
      end
    end
    
    [compliance_score, 0.0].max
  end

  def generate_ads_optimization_recommendations(variations, request)
    recommendations = []
    
    # Analyze headline lengths
    avg_headline_length = variations.map { |v| v[:headline].length }.sum / variations.size
    platform_config = AD_PLATFORMS[request.channel_metadata[:platform].to_sym]
    
    if avg_headline_length > platform_config[:headline_max_length] * 0.8
      recommendations << "Consider shorter headlines for better mobile visibility"
    end
    
    # Analyze keyword usage
    if request.channel_metadata[:keywords]
      keyword_usage = calculate_overall_keyword_density(variations, request)
      if keyword_usage < 30
        recommendations << "Include more target keywords for better relevance"
      elsif keyword_usage > 80
        recommendations << "Reduce keyword density to avoid appearing spammy"
      end
    end
    
    # Analyze CTA diversity
    unique_ctas = variations.map { |v| v[:cta] }.uniq.size
    if unique_ctas < 3
      recommendations << "Test more diverse call-to-action approaches"
    end
    
    recommendations
  end
end