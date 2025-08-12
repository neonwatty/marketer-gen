# Social Media content generation adapter
# Handles Twitter, LinkedIn, Facebook, Instagram posts with platform-specific constraints
class ContentAdapters::SocialMediaAdapter < ContentAdapters::BaseChannelAdapter
  # Platform-specific constraints
  PLATFORM_LIMITS = {
    twitter: {
      max_length: 280,
      max_hashtags: 2,
      max_mentions: 3,
      optimal_length_range: [71, 140],
      supports_threads: true
    },
    facebook: {
      max_length: 2200,
      max_hashtags: 30,
      max_mentions: 5,
      optimal_length_range: [40, 80],
      supports_media: true
    },
    instagram: {
      max_length: 2200,
      max_hashtags: 30,
      max_mentions: 20,
      optimal_length_range: [138, 150],
      requires_visual: true
    },
    linkedin: {
      max_length: 3000,
      max_hashtags: 5,
      max_mentions: 5,
      optimal_length_range: [150, 300],
      professional_tone: true
    },
    tiktok: {
      max_length: 2200,
      max_hashtags: 4,
      max_mentions: 3,
      optimal_length_range: [20, 50],
      trendy_language: true
    },
    youtube: {
      max_length: 5000,
      max_hashtags: 15,
      max_mentions: 5,
      optimal_length_range: [200, 400],
      supports_timestamps: true
    }
  }.freeze

  protected

  def setup_channel_metadata
    super
    @supported_content_types = %w[post story announcement promotional educational behind_scenes user_generated poll question]
    @constraints = determine_platform_constraints
  end

  def default_constraints
    {
      max_length: 280, # Default to Twitter limits
      min_length: 10,
      max_hashtags: 5,
      max_mentions: 3,
      requires_engagement: true
    }
  end

  public

  def generate_content(request)
    validate_social_media_request!(request)
    
    platform = request.channel_metadata[:platform] || 'twitter'
    platform_config = PLATFORM_LIMITS[platform.to_sym] || PLATFORM_LIMITS[:twitter]
    
    # Build AI prompt with platform-specific context
    ai_prompt = build_social_media_prompt(request, platform, platform_config)
    
    # Generate content using AI service
    ai_response = ai_service.generate_content_for_channel(
      'social_media',
      ai_prompt,
      {
        max_tokens: calculate_max_tokens(platform_config),
        temperature: determine_creativity_level(request),
        platform: platform
      }
    )
    
    # Parse and format response
    content_text = extract_content_from_ai_response(ai_response)
    
    # Apply platform-specific formatting
    formatted_content = format_for_platform(content_text, platform, request)
    
    # Extract social media elements
    elements = extract_social_elements(formatted_content, platform_config)
    
    # Build response
    response = ContentResponse.new(
      content: formatted_content,
      channel_type: 'social_media',
      content_type: request.content_type,
      request_id: request.request_id,
      title: elements[:title],
      hashtags: elements[:hashtags],
      mentions: elements[:mentions],
      call_to_action: elements[:cta],
      channel_specific_data: build_social_media_metadata(platform, elements, request)
    )
    
    response
  end

  def optimize_content(content, performance_data = {})
    optimization_suggestions = []
    
    # Analyze current performance
    engagement_rate = performance_data[:engagement_rate] || 0
    click_rate = performance_data[:click_rate] || 0
    reach = performance_data[:reach] || 0
    
    # Length optimization
    if content.length > 140 && engagement_rate < 0.02
      optimization_suggestions << {
        type: :length,
        suggestion: "Consider shortening content - posts under 140 characters typically see higher engagement",
        priority: :high
      }
    end
    
    # Hashtag optimization
    hashtag_count = count_hashtags(content)
    if hashtag_count == 0
      optimization_suggestions << {
        type: :hashtags,
        suggestion: "Add 2-3 relevant hashtags to increase discoverability",
        priority: :medium
      }
    elsif hashtag_count > 5
      optimization_suggestions << {
        type: :hashtags,
        suggestion: "Reduce hashtag count - too many hashtags can appear spammy",
        priority: :medium
      }
    end
    
    # Engagement optimization
    if engagement_rate < 0.015
      optimization_suggestions << {
        type: :engagement,
        suggestion: "Add a question or call-to-action to encourage user interaction",
        priority: :high
      }
    end
    
    # Click-through optimization
    if click_rate < 0.01 && has_link?(content)
      optimization_suggestions << {
        type: :cta,
        suggestion: "Strengthen your call-to-action to improve click-through rates",
        priority: :medium
      }
    end
    
    optimization_suggestions
  end

  def validate_content(content, request)
    platform = request.channel_metadata[:platform] || 'twitter'
    platform_config = PLATFORM_LIMITS[platform.to_sym]
    
    errors = []
    
    # Length validation
    if content.length > platform_config[:max_length]
      errors << "Content exceeds #{platform} maximum length of #{platform_config[:max_length]} characters"
    end
    
    # Hashtag validation
    hashtag_count = count_hashtags(content)
    if hashtag_count > platform_config[:max_hashtags]
      errors << "Too many hashtags for #{platform} (#{hashtag_count}/#{platform_config[:max_hashtags]})"
    end
    
    # Mention validation
    mention_count = count_mentions(content)
    if mention_count > platform_config[:max_mentions]
      errors << "Too many mentions for #{platform} (#{mention_count}/#{platform_config[:max_mentions]})"
    end
    
    # Platform-specific validations
    case platform.to_sym
    when :linkedin
      if request.tone != 'professional' && !%w[friendly conversational].include?(request.tone)
        errors << "LinkedIn content should maintain professional tone"
      end
    when :instagram
      if !has_visual_elements?(content) && !request.media_suggestions&.any?
        errors << "Instagram posts typically require visual elements"
      end
    when :tiktok
      if content.length > 50 && !has_trendy_language?(content)
        errors << "TikTok content should be concise and use trendy language"
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

  protected

  def determine_platform_constraints
    # If no platform specified, use Twitter as default
    base_constraints = default_constraints
    
    # Update with platform-specific constraints in preprocess_request
    base_constraints
  end

  def validate_social_media_request!(request)
    platform = request.channel_metadata[:platform]
    
    unless platform && PLATFORM_LIMITS.key?(platform.to_sym)
      raise InvalidContentRequestError, "Valid platform must be specified: #{PLATFORM_LIMITS.keys.join(', ')}"
    end
    
    if request.content_type.blank?
      raise InvalidContentRequestError, "Content type is required for social media posts"
    end
  end

  def build_social_media_prompt(request, platform, platform_config)
    context = request.to_ai_context
    
    prompt_parts = []
    prompt_parts << "Create engaging #{platform} content for #{request.content_type}."
    prompt_parts << "Brand context: #{format_brand_context(context[:brand_context])}"
    
    # Add platform-specific requirements
    prompt_parts << "Platform requirements:"
    prompt_parts << "- Maximum #{platform_config[:max_length]} characters"
    prompt_parts << "- Maximum #{platform_config[:max_hashtags]} hashtags"
    prompt_parts << "- Optimal length: #{platform_config[:optimal_length_range].join('-')} characters"
    
    # Add platform-specific guidance
    case platform.to_sym
    when :twitter
      prompt_parts << "- Use concise, impactful language"
      prompt_parts << "- Consider thread potential for longer topics"
    when :linkedin
      prompt_parts << "- Maintain professional tone while being engaging"
      prompt_parts << "- Include industry insights or career advice"
    when :instagram
      prompt_parts << "- Write caption that complements visual content"
      prompt_parts << "- Use storytelling approach"
    when :facebook
      prompt_parts << "- Encourage community interaction"
      prompt_parts << "- Use conversational tone"
    when :tiktok
      prompt_parts << "- Use trendy, youth-oriented language"
      prompt_parts << "- Keep it short and attention-grabbing"
    end
    
    # Add content requirements
    if request.requirements.any?
      prompt_parts << "Must include: #{request.requirements.join(', ')}"
    end
    
    # Add target audience context
    if request.target_audience.any?
      prompt_parts << "Target audience: #{format_target_audience(request.target_audience)}"
    end
    
    # Add campaign context
    if request.campaign_context.any?
      prompt_parts << "Campaign context: #{format_campaign_context(request.campaign_context)}"
    end
    
    prompt_parts << "Content prompt: #{request.prompt}"
    
    # Add output format instructions
    prompt_parts << "\nFormat your response as follows:"
    prompt_parts << "CONTENT: [main post content]"
    if platform_config[:max_hashtags] > 0
      prompt_parts << "HASHTAGS: [relevant hashtags separated by spaces]"
    end
    if context[:optimization_goals].include?('conversion') || request.requirements.include?('call_to_action')
      prompt_parts << "CTA: [call to action if appropriate]"
    end
    prompt_parts << "TONE: [tone analysis of the content]"
    
    prompt_parts.join("\n")
  end

  def extract_content_from_ai_response(ai_response)
    # Parse structured AI response
    content_match = ai_response.match(/CONTENT:\s*(.+?)(?=\n(?:HASHTAGS|CTA|TONE|$))/m)
    return ai_response unless content_match
    
    content_match[1].strip
  end

  def format_for_platform(content, platform, request)
    formatted_content = content.dup
    
    case platform.to_sym
    when :twitter
      # Add thread indicators if content is long
      if formatted_content.length > 200 && request.variant_context[:strategy] != :length_variation
        formatted_content = create_twitter_thread(formatted_content)
      end
    when :linkedin
      # Add professional formatting
      formatted_content = add_linkedin_formatting(formatted_content)
    when :instagram
      # Optimize for visual storytelling
      formatted_content = add_instagram_formatting(formatted_content, request)
    when :facebook
      # Optimize for engagement
      formatted_content = add_facebook_engagement_elements(formatted_content)
    end
    
    formatted_content
  end

  def extract_social_elements(content, platform_config)
    full_text = content.dup
    
    # Extract hashtags
    hashtags = content.scan(/#\w+/).map { |tag| tag[1..-1] }
    
    # Extract mentions
    mentions = content.scan(/@\w+/).map { |mention| mention[1..-1] }
    
    # Extract potential CTA
    cta = extract_call_to_action(content)
    
    # Generate title (first line or sentence)
    title = content.split(/[.\n]/).first&.strip
    title = title[0..50] + "..." if title && title.length > 50
    
    {
      title: title,
      hashtags: hashtags.take(platform_config[:max_hashtags]),
      mentions: mentions.take(platform_config[:max_mentions]),
      cta: cta
    }
  end

  def build_social_media_metadata(platform, elements, request)
    {
      platform: platform,
      hashtag_count: elements[:hashtags].size,
      mention_count: elements[:mentions].size,
      has_cta: elements[:cta].present?,
      optimal_length: PLATFORM_LIMITS[platform.to_sym][:optimal_length_range],
      posting_recommendations: generate_posting_recommendations(platform, request),
      engagement_hooks: identify_engagement_hooks(request.content)
    }
  end

  def calculate_max_tokens(platform_config)
    # Rough estimation: characters to tokens ratio
    (platform_config[:max_length] / 3.5).ceil + 50 # Buffer for formatting
  end

  def determine_creativity_level(request)
    case request.tone
    when 'playful', 'creative'
      0.8
    when 'professional', 'formal'
      0.5
    else
      0.7
    end
  end

  def format_brand_context(brand_context)
    parts = []
    parts << "Brand: #{brand_context[:name]}" if brand_context[:name]
    parts << "Industry: #{brand_context[:industry]}" if brand_context[:industry]
    parts << "Voice: #{brand_context[:voice]}" if brand_context[:voice]
    parts.join(", ")
  end

  def format_target_audience(target_audience)
    parts = []
    parts << "Age: #{target_audience[:age_range]}" if target_audience[:age_range]
    parts << "Interests: #{target_audience[:interests]&.join(', ')}" if target_audience[:interests]
    parts << "Demographics: #{target_audience[:demographics]}" if target_audience[:demographics]
    parts.join(", ")
  end

  def format_campaign_context(campaign_context)
    parts = []
    parts << "Campaign: #{campaign_context[:name]}" if campaign_context[:name]
    parts << "Goal: #{campaign_context[:objective]}" if campaign_context[:objective]
    parts << "Timeline: #{campaign_context[:timeline]}" if campaign_context[:timeline]
    parts.join(", ")
  end

  # Platform-specific formatting methods
  def create_twitter_thread(content)
    # Split long content into tweets
    sentences = content.split(/(?<=[.!?])\s+/)
    tweets = []
    current_tweet = ""
    
    sentences.each do |sentence|
      if (current_tweet + sentence).length <= 250 # Leave room for thread indicators
        current_tweet += sentence + " "
      else
        tweets << current_tweet.strip if current_tweet.present?
        current_tweet = sentence + " "
      end
    end
    
    tweets << current_tweet.strip if current_tweet.present?
    
    # Add thread indicators
    if tweets.size > 1
      tweets.each_with_index do |tweet, index|
        tweets[index] = "#{index + 1}/#{tweets.size} #{tweet}"
      end
      
      # Return first tweet for main content, store others in metadata
      tweets.first
    else
      content
    end
  end

  def add_linkedin_formatting(content)
    # Add line breaks for readability
    formatted = content.gsub(/\. /, ".\n\n")
    
    # Add professional call-to-action if missing
    unless has_call_to_action?(formatted)
      formatted += "\n\nWhat are your thoughts on this? Share your experiences in the comments."
    end
    
    formatted
  end

  def add_instagram_formatting(content, request)
    # Add spacing for readability
    formatted = content.gsub(/\. /, ".\n\n")
    
    # Add visual content suggestions if not present
    unless has_visual_elements?(formatted)
      if request.media_suggestions.empty?
        request.media_suggestions << suggest_visual_content(request.content_type)
      end
    end
    
    formatted
  end

  def add_facebook_engagement_elements(content)
    # Add engagement question if missing and content is not question-based
    unless content.include?('?') || has_call_to_action?(content)
      engagement_questions = [
        "What do you think?",
        "Have you experienced this too?",
        "Tag someone who needs to see this!",
        "Share your thoughts in the comments!"
      ]
      
      content += "\n\n" + engagement_questions.sample
    end
    
    content
  end

  # Utility methods
  def count_hashtags(content)
    content.scan(/#\w+/).size
  end

  def count_mentions(content)
    content.scan(/@\w+/).size
  end

  def has_link?(content)
    content.match?(/https?:\/\/\S+/)
  end

  def has_visual_elements?(content)
    visual_keywords = %w[photo image video picture visual see look watch]
    visual_keywords.any? { |keyword| content.downcase.include?(keyword) }
  end

  def has_trendy_language?(content)
    trendy_words = %w[vibe mood energy iconic literally obsessed fr periodt no cap]
    trendy_words.any? { |word| content.downcase.include?(word) }
  end

  def extract_call_to_action(content)
    cta_patterns = [
      /(?:learn more|get started|sign up|contact us|buy now|shop now|discover|try now|click link|swipe up)/i,
      /(?:comment|share|like|follow|subscribe|join|tag)/i
    ]
    
    cta_patterns.each do |pattern|
      match = content.match(pattern)
      return match[0] if match
    end
    
    nil
  end

  def generate_posting_recommendations(platform, request)
    recommendations = []
    
    case platform.to_sym
    when :twitter
      recommendations << "Best posting times: 9 AM, 1-3 PM, 5 PM EST"
      recommendations << "Use 1-2 hashtags for optimal engagement"
    when :linkedin
      recommendations << "Best posting times: Tuesday-Thursday, 8-10 AM EST"
      recommendations << "Include industry insights for better reach"
    when :instagram
      recommendations << "Best posting times: 11 AM-1 PM, 7-9 PM EST"
      recommendations << "Use high-quality visuals and relevant hashtags"
    when :facebook
      recommendations << "Best posting times: 1-3 PM, Wednesday-Friday"
      recommendations << "Ask questions to boost engagement"
    end
    
    recommendations
  end

  def identify_engagement_hooks(content)
    hooks = []
    
    hooks << "question" if content.include?('?')
    hooks << "call_to_action" if has_call_to_action?(content)
    hooks << "controversy" if has_controversial_elements?(content)
    hooks << "personal_story" if has_personal_elements?(content)
    hooks << "statistics" if has_statistics?(content)
    
    hooks
  end

  def suggest_visual_content(content_type)
    suggestions = {
      'promotional' => 'Product showcase or behind-the-scenes photo',
      'educational' => 'Infographic or step-by-step visual guide',
      'behind_scenes' => 'Team photo or workspace shot',
      'announcement' => 'Branded graphic with key information',
      'user_generated' => 'Customer photo or testimonial graphic'
    }
    
    suggestions[content_type] || 'Relevant branded visual content'
  end

  def has_controversial_elements?(content)
    # Simple check for potentially controversial content
    controversial_keywords = %w[debate argument controversial opinion unpopular]
    controversial_keywords.any? { |keyword| content.downcase.include?(keyword) }
  end

  def has_personal_elements?(content)
    personal_keywords = %w[I my we our experience story journey learned]
    personal_keywords.any? { |keyword| content.downcase.include?(keyword) }
  end

  def has_statistics?(content)
    content.match?(/\d+%|\d+\s*(?:percent|times|x|fold|increase|decrease)/)
  end

  def calculate_channel_engagement_factors(response, request)
    score = 0.0
    content = response.content
    
    # Platform-specific engagement factors
    platform = request.channel_metadata[:platform]&.to_sym
    
    case platform
    when :twitter
      score += 0.1 if content.length <= 140 # Optimal Twitter length
      score += 0.1 if count_hashtags(content) <= 2 # Not overusing hashtags
    when :linkedin
      score += 0.1 if content.length >= 150 # Longer content performs better
      score += 0.1 if content.include?('?') # Questions drive engagement
    when :instagram
      score += 0.1 if count_hashtags(content) >= 5 # Hashtags important on Instagram
      score += 0.1 if has_visual_elements?(content) # Visual content crucial
    when :facebook
      score += 0.1 if content.include?('?') # Questions drive engagement
      score += 0.1 if content.length <= 80 # Shorter posts perform better
    end
    
    score
  end
end