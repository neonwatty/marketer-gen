# Service for handling platform-specific content formatting and validation
# Provides character limits, image specs, hashtag limits, and content optimization
class ContentFormattingService
  include ActiveModel::Model
  include ActiveModel::Attributes

  # Platform-specific constraints and requirements
  PLATFORM_CONSTRAINTS = {
    twitter: {
      max_length: 280,
      min_length: 10,
      max_hashtags: 30,
      max_mentions: 10,
      max_images: 4,
      image_formats: %w[jpg jpeg png gif webp],
      max_image_size: 5.megabytes,
      supports_threads: true,
      supports_polls: true,
      link_shortening: true
    },
    instagram: {
      max_length: 2200,
      min_length: 50,
      max_hashtags: 30,
      max_mentions: 20,
      max_images: 10,
      image_formats: %w[jpg jpeg png],
      max_image_size: 30.megabytes,
      supports_stories: true,
      supports_reels: true,
      aspect_ratios: ['1:1', '4:5', '16:9']
    },
    facebook: {
      max_length: 63206,
      min_length: 10,
      max_hashtags: 30,
      max_mentions: 50,
      max_images: 20,
      image_formats: %w[jpg jpeg png gif],
      max_image_size: 4.megabytes,
      supports_events: true,
      supports_polls: true
    },
    linkedin: {
      max_length: 3000,
      min_length: 25,
      max_hashtags: 5,
      max_mentions: 10,
      max_images: 9,
      image_formats: %w[jpg jpeg png gif],
      max_image_size: 100.megabytes,
      supports_documents: true,
      supports_polls: true,
      professional_tone: true
    },
    email: {
      subject_max_length: 78,
      subject_min_length: 10,
      body_max_length: 100000,
      body_min_length: 50,
      max_images: 20,
      image_formats: %w[jpg jpeg png gif],
      max_image_size: 10.megabytes,
      supports_html: true,
      supports_attachments: true
    },
    google_ads: {
      headline_max_length: 30,
      description_max_length: 90,
      path_max_length: 15,
      max_headlines: 15,
      max_descriptions: 4,
      image_formats: %w[jpg jpeg png gif],
      required_elements: ['headline', 'description', 'final_url']
    },
    facebook_ads: {
      headline_max_length: 40,
      description_max_length: 125,
      body_max_length: 125,
      max_images: 10,
      image_formats: %w[jpg jpeg png gif],
      max_image_size: 30.megabytes,
      required_elements: ['headline', 'description']
    },
    landing_page: {
      headline_max_length: 60,
      subheading_max_length: 160,
      body_max_length: 50000,
      meta_description_max_length: 160,
      supports_forms: true,
      supports_video: true,
      supports_testimonials: true
    }
  }.freeze

  # UTM parameter templates
  UTM_TEMPLATES = {
    social_media: {
      utm_medium: 'social',
      utm_campaign: '%{campaign_name}',
      utm_content: '%{content_type}_%{platform}'
    },
    email: {
      utm_medium: 'email',
      utm_campaign: '%{campaign_name}',
      utm_content: 'email_%{email_type}'
    },
    ads: {
      utm_medium: 'cpc',
      utm_campaign: '%{campaign_name}',
      utm_content: 'ad_%{ad_type}'
    }
  }.freeze

  attr_accessor :platform, :content_type, :campaign_context

  def initialize(platform:, content_type: nil, campaign_context: {})
    @platform = platform.to_sym
    @content_type = content_type
    @campaign_context = campaign_context || {}
    validate_platform!
  end

  # Main formatting method
  def format_content(content, options = {})
    formatted_content = content.dup
    constraints = platform_constraints

    # Apply character limits
    formatted_content = apply_character_limits(formatted_content, constraints, options)
    
    # Format hashtags and mentions
    formatted_content = format_hashtags_and_mentions(formatted_content, constraints)
    
    # Apply platform-specific formatting
    formatted_content = apply_platform_formatting(formatted_content, options)
    
    # Add UTM parameters to links
    formatted_content = add_utm_parameters(formatted_content, options)
    
    # Validate emoji and special characters
    formatted_content = handle_emoji_and_special_chars(formatted_content)

    {
      content: formatted_content,
      metadata: build_formatting_metadata(content, formatted_content, constraints),
      warnings: generate_warnings(formatted_content, constraints)
    }
  end

  # Content truncation with smart strategies
  def truncate_content(content, max_length, strategy: :smart)
    return content if content.length <= max_length

    case strategy
    when :smart
      smart_truncate(content, max_length)
    when :sentence
      sentence_truncate(content, max_length)
    when :word
      word_truncate(content, max_length)
    when :hard
      hard_truncate(content, max_length)
    else
      smart_truncate(content, max_length)
    end
  end

  # Content expansion strategies
  def expand_content(content, min_length, context = {})
    return content if content.length >= min_length

    target_expansion = min_length - content.length
    
    # Choose expansion strategy based on platform and content type
    case platform
    when :linkedin
      expand_with_professional_context(content, target_expansion, context)
    when :instagram
      expand_with_visual_context(content, target_expansion, context)
    when :twitter
      expand_with_engagement_context(content, target_expansion, context)
    else
      expand_with_general_context(content, target_expansion, context)
    end
  end

  # Link shortening and UTM management
  def process_links(content, options = {})
    link_pattern = /https?:\/\/[^\s]+/
    processed_content = content.dup
    
    content.scan(link_pattern) do |link|
      processed_link = link
      
      # Add UTM parameters
      if options[:add_utm]
        processed_link = add_utm_to_link(processed_link, options[:utm_context] || {})
      end
      
      # Shorten link if required by platform
      if should_shorten_links?
        processed_link = shorten_link(processed_link, options[:link_shortener])
      end
      
      processed_content.gsub!(link, processed_link)
    end
    
    processed_content
  end

  # Content validation against platform policies
  def validate_content(content)
    validation_results = {
      valid: true,
      errors: [],
      warnings: [],
      suggestions: []
    }

    constraints = platform_constraints
    
    # Check character limits
    validate_character_limits(content, constraints, validation_results)
    
    # Check hashtag and mention limits
    validate_hashtags_and_mentions(content, constraints, validation_results)
    
    # Check image requirements
    validate_image_requirements(content, constraints, validation_results)
    
    # Platform-specific validation
    validate_platform_specific_rules(content, validation_results)

    validation_results
  end

  # Get platform-specific content suggestions
  def get_content_suggestions(content_context = {})
    case platform
    when :twitter
      twitter_suggestions(content_context)
    when :instagram
      instagram_suggestions(content_context)
    when :linkedin
      linkedin_suggestions(content_context)
    when :facebook
      facebook_suggestions(content_context)
    when :email
      email_suggestions(content_context)
    else
      general_suggestions(content_context)
    end
  end

  private

  def platform_constraints
    PLATFORM_CONSTRAINTS[platform] || {}
  end

  def validate_platform!
    unless PLATFORM_CONSTRAINTS.key?(platform)
      raise ArgumentError, "Unsupported platform: #{platform}. Supported platforms: #{PLATFORM_CONSTRAINTS.keys.join(', ')}"
    end
  end

  # Character limit application
  def apply_character_limits(content, constraints, options)
    max_length = constraints[:max_length]
    min_length = constraints[:min_length]
    
    return content unless max_length || min_length

    if max_length && content.length > max_length
      truncation_strategy = options[:truncation_strategy] || :smart
      content = truncate_content(content, max_length, strategy: truncation_strategy)
    end

    if min_length && content.length < min_length
      content = expand_content(content, min_length, options[:expansion_context] || {})
    end

    content
  end

  # Smart truncation that preserves meaning
  def smart_truncate(content, max_length)
    return content if content.length <= max_length

    # Try to preserve complete sentences
    sentences = content.split(/[.!?]+/)
    truncated = ""
    
    sentences.each do |sentence|
      potential_length = truncated.length + sentence.length + 1
      if potential_length <= max_length - 3
        truncated += (truncated.empty? ? sentence : ". #{sentence}")
      else
        break
      end
    end

    # If we couldn't preserve any complete sentences, do word truncation
    if truncated.empty?
      return word_truncate(content, max_length)
    end

    # Add ellipsis if we truncated
    if truncated.length < content.length
      truncated += "..."
    end

    truncated
  end

  def sentence_truncate(content, max_length)
    return content if content.length <= max_length

    # Find the last complete sentence that fits
    truncated = content[0...max_length]
    last_sentence_end = truncated.rindex(/[.!?]/)
    
    if last_sentence_end && last_sentence_end > max_length * 0.6
      content[0..last_sentence_end]
    else
      word_truncate(content, max_length)
    end
  end

  def word_truncate(content, max_length)
    return content if content.length <= max_length

    words = content.split(' ')
    truncated = ""
    
    words.each do |word|
      potential_length = truncated.length + word.length + 1
      if potential_length <= max_length - 3
        truncated += (truncated.empty? ? word : " #{word}")
      else
        break
      end
    end

    truncated + "..."
  end

  def hard_truncate(content, max_length)
    return content if content.length <= max_length
    content[0...max_length-3] + "..."
  end

  # Content expansion methods
  def expand_with_professional_context(content, target_expansion, context)
    expansions = [
      "This aligns with industry best practices.",
      "Our expertise in #{context[:industry] || 'this field'} ensures quality results.",
      "Connect with us to learn more about our approach.",
      "We're committed to delivering exceptional value to our clients."
    ]
    
    add_expansion(content, target_expansion, expansions)
  end

  def expand_with_visual_context(content, target_expansion, context)
    expansions = [
      "Share your thoughts in the comments below! 💭",
      "Tag a friend who needs to see this! 👇",
      "Double tap if you agree! ❤️",
      "What's your experience with this? Tell us your story!"
    ]
    
    add_expansion(content, target_expansion, expansions)
  end

  def expand_with_engagement_context(content, target_expansion, context)
    expansions = [
      "What do you think? Reply and let us know!",
      "RT if you agree 🔄",
      "Join the conversation 👇",
      "Your thoughts? 🤔"
    ]
    
    add_expansion(content, target_expansion, expansions)
  end

  def expand_with_general_context(content, target_expansion, context)
    expansions = [
      "Learn more about our solutions and how they can benefit you.",
      "Contact us today to get started on your journey.",
      "Discover the difference our approach can make.",
      "We're here to help you achieve your goals."
    ]
    
    add_expansion(content, target_expansion, expansions)
  end

  def add_expansion(content, target_expansion, possible_expansions)
    selected_expansion = possible_expansions.sample
    
    if selected_expansion.length <= target_expansion
      "#{content} #{selected_expansion}"
    else
      # Truncate the expansion to fit
      available_space = target_expansion - 1 # Space for the space character
      truncated_expansion = selected_expansion[0...available_space-3] + "..."
      "#{content} #{truncated_expansion}"
    end
  end

  # Hashtag and mention formatting
  def format_hashtags_and_mentions(content, constraints)
    formatted_content = content.dup
    
    # Count existing hashtags and mentions
    hashtag_count = content.scan(/#\w+/).length
    mention_count = content.scan(/@\w+/).length
    
    max_hashtags = constraints[:max_hashtags] || Float::INFINITY
    max_mentions = constraints[:max_mentions] || Float::INFINITY
    
    # Remove excess hashtags
    if hashtag_count > max_hashtags
      hashtags = content.scan(/#\w+/)
      excess_hashtags = hashtags[max_hashtags..-1]
      excess_hashtags.each { |tag| formatted_content.gsub!(tag, '') }
    end
    
    # Remove excess mentions
    if mention_count > max_mentions
      mentions = content.scan(/@\w+/)
      excess_mentions = mentions[max_mentions..-1]
      excess_mentions.each { |mention| formatted_content.gsub!(mention, '') }
    end
    
    formatted_content.gsub(/\s+/, ' ').strip
  end

  # Platform-specific formatting
  def apply_platform_formatting(content, options)
    case platform
    when :twitter
      format_for_twitter(content, options)
    when :linkedin
      format_for_linkedin(content, options)
    when :instagram
      format_for_instagram(content, options)
    when :email
      format_for_email(content, options)
    else
      content
    end
  end

  def format_for_twitter(content, options)
    # Ensure line breaks are appropriate for Twitter
    content.gsub(/\n{3,}/, "\n\n")
  end

  def format_for_linkedin(content, options)
    # Add professional formatting
    if content.length > 600 && !content.include?("\n\n")
      # Add paragraph breaks for readability
      sentences = content.split('. ')
      if sentences.length > 3
        mid_point = sentences.length / 2
        sentences.insert(mid_point, "\n")
        content = sentences.join('. ').gsub('. \n', ".\n\n")
      end
    end
    content
  end

  def format_for_instagram(content, options)
    # Move hashtags to end if they're scattered throughout
    hashtags = content.scan(/#\w+/)
    content_without_hashtags = content.gsub(/#\w+/, '').gsub(/\s+/, ' ').strip
    
    if hashtags.any?
      "#{content_without_hashtags}\n\n#{hashtags.join(' ')}"
    else
      content
    end
  end

  def format_for_email(content, options)
    # Add proper email formatting
    if options[:email_type] == 'html'
      content.gsub(/\n/, '<br>')
    else
      content
    end
  end

  # UTM parameter management
  def add_utm_parameters(content, options)
    return content unless options[:add_utm]
    
    utm_context = options[:utm_context] || {}
    process_links(content, add_utm: true, utm_context: utm_context)
  end

  def add_utm_to_link(link, context)
    uri = URI.parse(link)
    existing_params = URI.decode_www_form(uri.query || '')
    
    # Get UTM template for content type
    utm_template = UTM_TEMPLATES[content_type&.to_sym] || UTM_TEMPLATES[:social_media]
    
    # Build UTM parameters
    utm_params = utm_template.map do |key, template|
      value = template % context.merge(
        platform: platform,
        content_type: content_type,
        campaign_name: campaign_context[:name] || 'campaign',
        email_type: context[:email_type] || 'newsletter',
        ad_type: context[:ad_type] || 'display'
      )
      [key.to_s, value]
    end
    
    # Merge with existing parameters
    all_params = existing_params + utm_params
    uri.query = URI.encode_www_form(all_params)
    
    uri.to_s
  rescue URI::InvalidURIError
    link # Return original link if parsing fails
  end

  def should_shorten_links?
    platform_constraints[:link_shortening] == true
  end

  def shorten_link(link, shortener = nil)
    # In a real implementation, this would integrate with a URL shortening service
    # For now, we'll just return the original link
    link
  end

  # Emoji and special character handling
  def handle_emoji_and_special_chars(content)
    case platform
    when :linkedin
      # LinkedIn is more conservative with emojis
      limit_emojis(content, max_emojis: 3)
    when :email
      # Email clients may not support all emojis
      convert_emojis_to_text(content)
    else
      content
    end
  end

  def limit_emojis(content, max_emojis:)
    emoji_pattern = /[\u{1f300}-\u{1f5ff}\u{1f600}-\u{1f64f}\u{1f680}-\u{1f6ff}\u{1f700}-\u{1f77f}\u{1f780}-\u{1f7ff}\u{1f800}-\u{1f8ff}\u{2600}-\u{26ff}\u{2700}-\u{27bf}]/
    emojis = content.scan(emoji_pattern)
    
    return content if emojis.length <= max_emojis
    
    excess_emojis = emojis[max_emojis..-1]
    modified_content = content.dup
    
    excess_emojis.each do |emoji|
      # Remove only the first occurrence to avoid removing all instances
      modified_content.sub!(emoji, '')
    end
    
    modified_content.gsub(/\s+/, ' ').strip
  end

  def convert_emojis_to_text(content)
    emoji_map = {
      '😀' => ':)',
      '😢' => ':(',
      '❤️' => '<3',
      '👍' => '(thumbs up)',
      '👎' => '(thumbs down)'
    }
    
    modified_content = content.dup
    emoji_map.each { |emoji, text| modified_content.gsub!(emoji, text) }
    modified_content
  end

  # Validation methods
  def validate_character_limits(content, constraints, results)
    if constraints[:max_length] && content.length > constraints[:max_length]
      results[:errors] << "Content exceeds maximum length of #{constraints[:max_length]} characters (current: #{content.length})"
      results[:valid] = false
    end
    
    if constraints[:min_length] && content.length < constraints[:min_length]
      results[:warnings] << "Content is below recommended minimum length of #{constraints[:min_length]} characters (current: #{content.length})"
    end
  end

  def validate_hashtags_and_mentions(content, constraints, results)
    hashtag_count = content.scan(/#\w+/).length
    mention_count = content.scan(/@\w+/).length
    
    if constraints[:max_hashtags] && hashtag_count > constraints[:max_hashtags]
      results[:errors] << "Too many hashtags: #{hashtag_count} (max: #{constraints[:max_hashtags]})"
      results[:valid] = false
    end
    
    if constraints[:max_mentions] && mention_count > constraints[:max_mentions]
      results[:errors] << "Too many mentions: #{mention_count} (max: #{constraints[:max_mentions]})"
      results[:valid] = false
    end
  end

  def validate_image_requirements(content, constraints, results)
    # This would be extended to validate actual image attachments
    # For now, we'll just check if the platform supports images
    if content.include?('[image]') && !constraints[:max_images]
      results[:warnings] << "Platform may not support images"
    end
  end

  def validate_platform_specific_rules(content, results)
    case platform
    when :linkedin
      validate_linkedin_rules(content, results)
    when :twitter
      validate_twitter_rules(content, results)
    when :email
      validate_email_rules(content, results)
    end
  end

  def validate_linkedin_rules(content, results)
    if content.downcase.include?('buy now') || content.downcase.include?('click here')
      results[:warnings] << "Overly promotional language may reduce reach on LinkedIn"
    end
  end

  def validate_twitter_rules(content, results)
    if content.scan(/@\w+/).length > 2
      results[:suggestions] << "Consider reducing mentions to improve readability"
    end
  end

  def validate_email_rules(content, results)
    if content.include?('URGENT') || content.include?('ACT NOW')
      results[:warnings] << "All-caps promotional language may trigger spam filters"
    end
  end

  # Metadata and warnings
  def build_formatting_metadata(original_content, formatted_content, constraints)
    {
      original_length: original_content.length,
      formatted_length: formatted_content.length,
      truncated: formatted_content.length < original_content.length,
      expanded: formatted_content.length > original_content.length,
      platform: platform,
      constraints_applied: constraints.keys,
      hashtag_count: formatted_content.scan(/#\w+/).length,
      mention_count: formatted_content.scan(/@\w+/).length,
      link_count: formatted_content.scan(/https?:\/\/[^\s]+/).length
    }
  end

  def generate_warnings(content, constraints)
    warnings = []
    
    # Check if content is close to limits
    if constraints[:max_length]
      usage_percent = (content.length.to_f / constraints[:max_length]) * 100
      if usage_percent > 90
        warnings << "Content is using #{usage_percent.round}% of character limit"
      end
    end
    
    # Platform-specific warnings
    case platform
    when :twitter
      if content.scan(/https?:\/\/[^\s]+/).length > 1
        warnings << "Multiple links may reduce engagement on Twitter"
      end
    when :instagram
      if content.scan(/#\w+/).length < 5
        warnings << "Consider adding more hashtags for better discoverability on Instagram"
      end
    end
    
    warnings
  end

  # Platform-specific suggestions
  def twitter_suggestions(context)
    [
      "Keep it concise and engaging",
      "Use relevant hashtags (max 2-3 per tweet)",
      "Include a call-to-action",
      "Consider using a thread for longer content",
      "Engage with replies and mentions"
    ]
  end

  def instagram_suggestions(context)
    [
      "Use high-quality visuals",
      "Include relevant hashtags (up to 30)",
      "Write engaging captions with personality",
      "Use Instagram Stories for behind-the-scenes content",
      "Encourage user-generated content"
    ]
  end

  def linkedin_suggestions(context)
    [
      "Maintain a professional tone",
      "Share industry insights and expertise",
      "Use data and statistics to support your points",
      "Engage in meaningful conversations",
      "Limit promotional content to 20% of posts"
    ]
  end

  def facebook_suggestions(context)
    [
      "Use varied content types (text, images, videos)",
      "Post at optimal times for your audience",
      "Encourage comments and shares",
      "Share behind-the-scenes content",
      "Use Facebook Groups for community building"
    ]
  end

  def email_suggestions(context)
    [
      "Write compelling subject lines",
      "Keep paragraphs short and scannable",
      "Include clear call-to-action buttons",
      "Personalize content when possible",
      "Test different send times and frequencies"
    ]
  end

  def general_suggestions(context)
    [
      "Know your audience and tailor content accordingly",
      "Use clear and concise language",
      "Include relevant calls-to-action",
      "Maintain consistent brand voice",
      "Monitor performance and adjust strategy"
    ]
  end
end