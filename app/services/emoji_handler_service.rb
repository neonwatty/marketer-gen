# Service for handling emoji and special character processing across platforms
# Provides emoji validation, conversion, and platform-specific optimization
class EmojiHandlerService
  include ActiveModel::Model

  # Platform-specific emoji handling rules
  PLATFORM_RULES = {
    twitter: {
      max_emojis: 10,
      supports_unicode: true,
      supports_custom: false,
      emoji_sentiment_boost: true,
      recommended_emojis: %w[🔥 💯 🚀 ❤️ 🤔 👀 💪 🎯 ✨ 🌟],
      avoid_emojis: %w[🍆 🍑 💦] # Potentially inappropriate
    },
    instagram: {
      max_emojis: 30,
      supports_unicode: true,
      supports_custom: false,
      emoji_sentiment_boost: true,
      hashtag_emojis_allowed: true,
      recommended_emojis: %w[❤️ 😍 📸 ✨ 🌟 💖 🔥 💯 🎉 🙌 📷 🌈 💕 🎨 🌸],
      avoid_emojis: []
    },
    linkedin: {
      max_emojis: 3,
      supports_unicode: true,
      supports_custom: false,
      professional_only: true,
      emoji_sentiment_boost: false,
      recommended_emojis: %w[💼 📊 💡 🎯 ✅ 📈 🔗 🌐 💪 🚀],
      avoid_emojis: %w[😂 🤣 🥳 🍻 🎉] # Too casual for professional context
    },
    facebook: {
      max_emojis: 20,
      supports_unicode: true,
      supports_custom: false,
      emoji_sentiment_boost: true,
      reactions_available: %w[👍 ❤️ 😆 😮 😢 😡],
      recommended_emojis: %w[❤️ 😊 👍 🎉 💙 🌟 😍 💕 🙌 🔥],
      avoid_emojis: []
    },
    email: {
      max_emojis: 5,
      supports_unicode: false, # Many email clients have poor emoji support
      emoji_to_text: true,
      recommended_alternatives: {
        '😊' => ':)',
        '😢' => ':(',
        '❤️' => '<3',
        '👍' => '(thumbs up)',
        '👎' => '(thumbs down)',
        '🎉' => '(celebration)',
        '🔥' => '(fire)',
        '💯' => '100%',
        '✅' => '(checkmark)',
        '❌' => '(x)'
      }
    },
    sms: {
      max_emojis: 5,
      supports_unicode: true,
      character_count_impact: true, # Emojis count as multiple characters
      recommended_emojis: %w[😊 👍 ❤️ 🎉 ✅],
      avoid_emojis: [] # Most modern SMS supports emojis well
    }
  }.freeze

  # Emoji categories for content optimization
  EMOJI_CATEGORIES = {
    emotions: {
      positive: %w[😊 😄 😃 🙂 😁 🥰 😍 🤗 😌 😎 🤩 🥳],
      negative: %w[😢 😞 😔 😟 😕 😤 😠 😡 🤬 😰 😨 😱],
      neutral: %w[😐 😑 🙄 🤔 🤨 😯 😮 😲 🤐 😶]
    },
    business: %w[💼 📊 📈 📉 💰 💵 💸 🏆 🎯 📋 📝 💡 🔍 📞 📧 🏢],
    celebration: %w[🎉 🎊 🥳 🎈 🎂 🍾 🥂 🏆 🎁 🎪 🎭 🎨],
    nature: %w[🌟 ⭐ 🌙 ☀️ 🌈 🌸 🌺 🌻 🌷 🌹 🌿 🍀 🌱 🌳],
    objects: %w[📱 💻 📺 📷 📸 🎥 🎬 📹 🎧 🎤 📻 ⌚ 💎 👑],
    food: %w[🍕 🍔 🍟 🌮 🍜 🍝 🍣 🍰 🧁 🍪 ☕ 🍷 🥂 🍻],
    travel: %w[✈️ 🚗 🚕 🚙 🚌 🚎 🏨 🗺️ 🧳 📍 🌍 🌎 🌏],
    sports: %w[⚽ 🏀 🏈 ⚾ 🎾 🏐 🏓 🥊 🏋️ 🏃 🚴 🏊],
    technology: %w[💻 📱 🖥️ ⌨️ 🖱️ 💿 📀 🔌 🔋 💡 🔬 🔭]
  }.freeze

  # Unicode ranges for emoji detection
  EMOJI_UNICODE_RANGES = [
    (0x1F600..0x1F64F), # Emoticons
    (0x1F300..0x1F5FF), # Misc Symbols and Pictographs
    (0x1F680..0x1F6FF), # Transport and Map
    (0x1F1E0..0x1F1FF), # Regional indicators (flags)
    (0x2600..0x26FF),   # Misc symbols
    (0x2700..0x27BF),   # Dingbats
    (0xFE00..0xFE0F),   # Variation selectors
    (0x1F900..0x1F9FF), # Supplemental Symbols and Pictographs
    (0x1F018..0x1F270)  # Various symbols
  ].freeze

  attr_accessor :platform, :content_type, :brand_guidelines

  def initialize(platform:, content_type: nil, brand_guidelines: {})
    @platform = platform.to_sym
    @content_type = content_type
    @brand_guidelines = brand_guidelines || {}
    validate_platform!
  end

  # Main emoji processing method
  def process_emojis(content, options = {})
    platform_rules = get_platform_rules
    
    result = {
      original_content: content,
      processed_content: content.dup,
      emojis_found: extract_emojis(content),
      emojis_removed: [],
      emojis_converted: [],
      emojis_added: [],
      warnings: [],
      suggestions: []
    }

    # Apply platform-specific processing
    result[:processed_content] = apply_platform_rules(result[:processed_content], platform_rules, result)
    
    # Apply brand guidelines
    result[:processed_content] = apply_brand_guidelines(result[:processed_content], result)
    
    # Generate suggestions for emoji optimization
    result[:suggestions] = generate_emoji_suggestions(result[:processed_content], platform_rules)
    
    result
  end

  # Validate emoji usage for platform
  def validate_emoji_usage(content)
    platform_rules = get_platform_rules
    emojis = extract_emojis(content)
    
    validation_result = {
      valid: true,
      errors: [],
      warnings: [],
      emoji_count: emojis.length,
      emojis_by_category: categorize_emojis(emojis)
    }

    # Check emoji count limits
    if platform_rules[:max_emojis] && emojis.length > platform_rules[:max_emojis]
      validation_result[:valid] = false
      validation_result[:errors] << "Too many emojis: #{emojis.length} (max: #{platform_rules[:max_emojis]})"
    end

    # Check for inappropriate emojis
    inappropriate_emojis = emojis & (platform_rules[:avoid_emojis] || [])
    if inappropriate_emojis.any?
      validation_result[:warnings] << "Potentially inappropriate emojis for #{platform}: #{inappropriate_emojis.join(', ')}"
    end

    # Platform-specific validation
    validate_platform_specific_rules(content, emojis, platform_rules, validation_result)

    validation_result
  end

  # Suggest emojis based on content and platform
  def suggest_emojis(content, options = {})
    platform_rules = get_platform_rules
    content_sentiment = analyze_content_sentiment(content)
    content_topics = extract_content_topics(content)
    
    suggestions = {
      recommended: [],
      sentiment_based: [],
      topic_based: [],
      platform_optimized: platform_rules[:recommended_emojis] || []
    }

    # Sentiment-based suggestions
    case content_sentiment
    when :positive
      suggestions[:sentiment_based] = EMOJI_CATEGORIES[:emotions][:positive].sample(3)
    when :negative
      suggestions[:sentiment_based] = EMOJI_CATEGORIES[:emotions][:negative].sample(2)
    else
      suggestions[:sentiment_based] = EMOJI_CATEGORIES[:emotions][:neutral].sample(2)
    end

    # Topic-based suggestions
    content_topics.each do |topic|
      if EMOJI_CATEGORIES[topic]
        suggestions[:topic_based] += EMOJI_CATEGORIES[topic].sample(2)
      end
    end

    # Combine and deduplicate
    all_suggestions = (suggestions[:sentiment_based] + suggestions[:topic_based] + suggestions[:platform_optimized]).uniq
    
    # Filter based on platform rules
    filtered_suggestions = filter_suggestions_by_platform(all_suggestions, platform_rules)
    
    suggestions[:recommended] = filtered_suggestions.first(platform_rules[:max_emojis] || 5)
    suggestions
  end

  # Convert emojis to text alternatives
  def convert_emojis_to_text(content)
    platform_rules = get_platform_rules
    return content unless platform_rules[:emoji_to_text]

    converted_content = content.dup
    conversion_map = platform_rules[:recommended_alternatives] || default_emoji_to_text_map
    
    conversion_map.each do |emoji, text_alternative|
      converted_content.gsub!(emoji, text_alternative)
    end

    converted_content
  end

  # Optimize emoji placement in content
  def optimize_emoji_placement(content, options = {})
    emojis = extract_emojis(content)
    return content if emojis.empty?

    platform_rules = get_platform_rules
    
    case options[:strategy] || :balanced
    when :front_loaded
      move_emojis_to_front(content, emojis)
    when :end_loaded
      move_emojis_to_end(content, emojis)
    when :distributed
      distribute_emojis_evenly(content, emojis)
    when :balanced
      balance_emoji_placement(content, emojis, platform_rules)
    else
      content
    end
  end

  # Generate emoji analytics report
  def analyze_emoji_performance(content_samples)
    analysis = {
      total_content_pieces: content_samples.length,
      emoji_usage_stats: {},
      performance_correlation: {},
      platform_specific_insights: {},
      recommendations: []
    }

    # Analyze emoji usage patterns
    all_emojis = content_samples.flat_map { |content| extract_emojis(content) }
    emoji_frequency = all_emojis.tally
    
    analysis[:emoji_usage_stats] = {
      total_emojis_used: all_emojis.length,
      unique_emojis: emoji_frequency.keys.length,
      most_used_emojis: emoji_frequency.sort_by { |_, count| -count }.first(10).to_h,
      emoji_categories_used: categorize_emojis(emoji_frequency.keys)
    }

    # Generate platform-specific insights
    platform_rules = get_platform_rules
    analysis[:platform_specific_insights] = generate_platform_insights(emoji_frequency, platform_rules)

    # Generate recommendations
    analysis[:recommendations] = generate_optimization_recommendations(analysis[:emoji_usage_stats], platform_rules)

    analysis
  end

  private

  def validate_platform!
    unless PLATFORM_RULES.key?(platform)
      raise ArgumentError, "Unsupported platform: #{platform}. Supported platforms: #{PLATFORM_RULES.keys.join(', ')}"
    end
  end

  def get_platform_rules
    PLATFORM_RULES[platform] || {}
  end

  # Extract all emojis from content
  def extract_emojis(content)
    emoji_pattern = build_emoji_regex
    content.scan(emoji_pattern).flatten.compact.uniq
  end

  # Build regex pattern for emoji detection
  def build_emoji_regex
    unicode_ranges = EMOJI_UNICODE_RANGES.map do |range|
      "\\u{#{range.first.to_s(16)}-#{range.last.to_s(16)}}"
    end.join('|')
    
    Regexp.new("[#{unicode_ranges}]", Regexp::EXTENDED)
  end

  # Apply platform-specific emoji rules
  def apply_platform_rules(content, platform_rules, result)
    processed_content = content.dup

    # Remove excess emojis if over limit
    if platform_rules[:max_emojis]
      processed_content = limit_emoji_count(processed_content, platform_rules[:max_emojis], result)
    end

    # Remove inappropriate emojis
    if platform_rules[:avoid_emojis]&.any?
      processed_content = remove_inappropriate_emojis(processed_content, platform_rules[:avoid_emojis], result)
    end

    # Convert emojis to text if required
    if platform_rules[:emoji_to_text]
      processed_content = convert_emojis_to_text_with_tracking(processed_content, platform_rules, result)
    end

    # Apply professional filter for LinkedIn
    if platform_rules[:professional_only]
      processed_content = apply_professional_filter(processed_content, result)
    end

    processed_content
  end

  # Limit emoji count while preserving the most important ones
  def limit_emoji_count(content, max_count, result)
    emojis = extract_emojis(content)
    return content if emojis.length <= max_count

    # Prioritize emojis based on importance
    prioritized_emojis = prioritize_emojis(emojis, content)
    emojis_to_remove = emojis[max_count..-1] || []
    
    processed_content = content.dup
    emojis_to_remove.each do |emoji|
      # Remove only the first occurrence to avoid removing all instances
      processed_content.sub!(emoji, '')
      result[:emojis_removed] << emoji
    end

    # Clean up extra whitespace
    processed_content.gsub(/\s+/, ' ').strip
  end

  # Remove emojis that are inappropriate for the platform
  def remove_inappropriate_emojis(content, avoid_list, result)
    processed_content = content.dup
    
    avoid_list.each do |emoji|
      if processed_content.include?(emoji)
        processed_content.gsub!(emoji, '')
        result[:emojis_removed] << emoji
        result[:warnings] << "Removed inappropriate emoji for #{platform}: #{emoji}"
      end
    end

    processed_content.gsub(/\s+/, ' ').strip
  end

  # Convert emojis to text with result tracking
  def convert_emojis_to_text_with_tracking(content, platform_rules, result)
    conversion_map = platform_rules[:recommended_alternatives] || default_emoji_to_text_map
    processed_content = content.dup
    
    conversion_map.each do |emoji, text_alternative|
      if processed_content.include?(emoji)
        processed_content.gsub!(emoji, text_alternative)
        result[:emojis_converted] << { emoji: emoji, alternative: text_alternative }
      end
    end

    processed_content
  end

  # Apply professional emoji filter
  def apply_professional_filter(content, result)
    professional_emojis = EMOJI_CATEGORIES[:business]
    casual_emojis = EMOJI_CATEGORIES[:emotions][:positive] - professional_emojis
    
    processed_content = content.dup
    casual_emojis.each do |emoji|
      if processed_content.include?(emoji)
        processed_content.gsub!(emoji, '')
        result[:emojis_removed] << emoji
        result[:warnings] << "Removed casual emoji for professional context: #{emoji}"
      end
    end

    processed_content.gsub(/\s+/, ' ').strip
  end

  # Apply brand-specific emoji guidelines
  def apply_brand_guidelines(content, result)
    return content if brand_guidelines.empty?

    processed_content = content.dup

    # Apply brand emoji allowlist
    if brand_guidelines[:allowed_emojis]
      all_emojis = extract_emojis(content)
      unauthorized_emojis = all_emojis - brand_guidelines[:allowed_emojis]
      
      unauthorized_emojis.each do |emoji|
        processed_content.gsub!(emoji, '')
        result[:emojis_removed] << emoji
        result[:warnings] << "Removed emoji not in brand guidelines: #{emoji}"
      end
    end

    # Apply brand emoji blocklist
    if brand_guidelines[:blocked_emojis]
      brand_guidelines[:blocked_emojis].each do |emoji|
        if processed_content.include?(emoji)
          processed_content.gsub!(emoji, '')
          result[:emojis_removed] << emoji
          result[:warnings] << "Removed blocked emoji per brand guidelines: #{emoji}"
        end
      end
    end

    processed_content.gsub(/\s+/, ' ').strip
  end

  # Prioritize emojis based on context and platform
  def prioritize_emojis(emojis, content)
    platform_rules = get_platform_rules
    
    scored_emojis = emojis.map do |emoji|
      score = 0.0
      
      # Platform recommendation boost
      if platform_rules[:recommended_emojis]&.include?(emoji)
        score += 3.0
      end
      
      # Category relevance
      emoji_categories = find_emoji_categories(emoji)
      score += emoji_categories.length * 0.5
      
      # Position in content (earlier = higher priority)
      position = content.index(emoji) || content.length
      score += (1.0 - (position.to_f / content.length)) * 2.0
      
      [emoji, score]
    end
    
    scored_emojis.sort_by { |_, score| -score }.map(&:first)
  end

  # Find which categories an emoji belongs to
  def find_emoji_categories(emoji)
    categories = []
    EMOJI_CATEGORIES.each do |category, emoji_list|
      if emoji_list.is_a?(Hash)
        emoji_list.each do |subcategory, sublist|
          categories << "#{category}_#{subcategory}" if sublist.include?(emoji)
        end
      elsif emoji_list.include?(emoji)
        categories << category.to_s
      end
    end
    categories
  end

  # Categorize a list of emojis
  def categorize_emojis(emojis)
    categorized = Hash.new { |h, k| h[k] = [] }
    
    emojis.each do |emoji|
      categories = find_emoji_categories(emoji)
      if categories.empty?
        categorized[:uncategorized] << emoji
      else
        categories.each { |category| categorized[category] << emoji }
      end
    end
    
    categorized
  end

  # Platform-specific validation rules
  def validate_platform_specific_rules(content, emojis, platform_rules, validation_result)
    case platform
    when :linkedin
      validate_linkedin_emoji_rules(content, emojis, validation_result)
    when :email
      validate_email_emoji_rules(content, emojis, validation_result)
    when :instagram
      validate_instagram_emoji_rules(content, emojis, validation_result)
    end
  end

  def validate_linkedin_emoji_rules(content, emojis, validation_result)
    casual_emojis = emojis & EMOJI_CATEGORIES[:emotions][:positive]
    if casual_emojis.any?
      validation_result[:warnings] << "Consider using professional emojis on LinkedIn: #{casual_emojis.join(', ')}"
    end
  end

  def validate_email_emoji_rules(content, emojis, validation_result)
    if emojis.any?
      validation_result[:warnings] << "Emojis may not display correctly in all email clients. Consider text alternatives."
    end
  end

  def validate_instagram_emoji_rules(content, emojis, validation_result)
    if emojis.length < 3
      validation_result[:warnings] << "Consider adding more emojis for better Instagram engagement"
    end
  end

  # Content analysis methods
  def analyze_content_sentiment(content)
    positive_words = %w[great amazing awesome excellent wonderful fantastic love happy excited]
    negative_words = %w[bad terrible awful horrible disappointing sad angry frustrated]
    
    content_words = content.downcase.split(/\W+/)
    positive_count = content_words.count { |word| positive_words.include?(word) }
    negative_count = content_words.count { |word| negative_words.include?(word) }
    
    if positive_count > negative_count
      :positive
    elsif negative_count > positive_count
      :negative
    else
      :neutral
    end
  end

  def extract_content_topics(content)
    topic_keywords = {
      business: %w[business company corporate professional meeting project strategy revenue profit growth],
      technology: %w[tech technology software app digital online innovation ai artificial intelligence],
      food: %w[food restaurant cooking recipe meal dinner lunch breakfast],
      travel: %w[travel vacation trip journey adventure destination flight hotel],
      sports: %w[sports game match team player training fitness exercise workout],
      celebration: %w[celebration party birthday anniversary achievement success milestone]
    }
    
    content_words = content.downcase.split(/\W+/)
    detected_topics = []
    
    topic_keywords.each do |topic, keywords|
      if keywords.any? { |keyword| content_words.include?(keyword) }
        detected_topics << topic
      end
    end
    
    detected_topics
  end

  # Emoji suggestion filtering
  def filter_suggestions_by_platform(suggestions, platform_rules)
    filtered = suggestions.dup
    
    # Remove inappropriate emojis
    if platform_rules[:avoid_emojis]
      filtered -= platform_rules[:avoid_emojis]
    end
    
    # Apply professional filter
    if platform_rules[:professional_only]
      casual_emojis = EMOJI_CATEGORIES[:emotions][:positive] - EMOJI_CATEGORIES[:business]
      filtered -= casual_emojis
    end
    
    filtered
  end

  # Default emoji to text conversion map
  def default_emoji_to_text_map
    {
      '😊' => ':)',
      '😢' => ':(',
      '❤️' => '<3',
      '👍' => '(thumbs up)',
      '👎' => '(thumbs down)',
      '🎉' => '(celebration)',
      '🔥' => '(fire)',
      '💯' => '100%',
      '✅' => '(checkmark)',
      '❌' => '(x)',
      '💡' => '(lightbulb)',
      '📈' => '(chart up)',
      '📉' => '(chart down)',
      '🚀' => '(rocket)',
      '⭐' => '(star)'
    }
  end

  # Emoji placement optimization methods
  def move_emojis_to_front(content, emojis)
    content_without_emojis = content.dup
    emojis.each { |emoji| content_without_emojis.gsub!(emoji, '') }
    content_without_emojis = content_without_emojis.gsub(/\s+/, ' ').strip
    
    "#{emojis.join(' ')} #{content_without_emojis}"
  end

  def move_emojis_to_end(content, emojis)
    content_without_emojis = content.dup
    emojis.each { |emoji| content_without_emojis.gsub!(emoji, '') }
    content_without_emojis = content_without_emojis.gsub(/\s+/, ' ').strip
    
    "#{content_without_emojis} #{emojis.join(' ')}"
  end

  def distribute_emojis_evenly(content, emojis)
    words = content.split(/\s+/)
    content_without_emojis = content.dup
    emojis.each { |emoji| content_without_emojis.gsub!(emoji, '') }
    clean_words = content_without_emojis.split(/\s+/)
    
    return content if clean_words.length < 2
    
    positions = (0...clean_words.length).step(clean_words.length / [emojis.length, 1].max).to_a
    
    result_words = clean_words.dup
    emojis.each_with_index do |emoji, index|
      position = positions[index] || result_words.length
      result_words.insert(position + index, emoji)
    end
    
    result_words.join(' ')
  end

  def balance_emoji_placement(content, emojis, platform_rules)
    # For platforms that benefit from emoji engagement, place some at the end
    if platform_rules[:emoji_sentiment_boost]
      move_emojis_to_end(content, emojis)
    else
      # For professional platforms, distribute more evenly
      distribute_emojis_evenly(content, emojis)
    end
  end

  # Analytics and insights
  def generate_platform_insights(emoji_frequency, platform_rules)
    insights = {}
    
    # Check alignment with platform recommendations
    recommended_used = emoji_frequency.keys & (platform_rules[:recommended_emojis] || [])
    insights[:platform_alignment] = {
      recommended_emojis_used: recommended_used,
      alignment_percentage: recommended_used.length.to_f / (platform_rules[:recommended_emojis]&.length || 1) * 100
    }
    
    # Check for inappropriate usage
    inappropriate_used = emoji_frequency.keys & (platform_rules[:avoid_emojis] || [])
    insights[:inappropriate_usage] = inappropriate_used
    
    insights
  end

  def generate_optimization_recommendations(usage_stats, platform_rules)
    recommendations = []
    
    # Emoji count recommendations
    if platform_rules[:max_emojis]
      avg_emoji_count = usage_stats[:total_emojis_used].to_f / usage_stats[:total_content_pieces]
      if avg_emoji_count > platform_rules[:max_emojis]
        recommendations << "Reduce emoji usage to stay within platform limits (#{platform_rules[:max_emojis]} max)"
      elsif avg_emoji_count < platform_rules[:max_emojis] * 0.5
        recommendations << "Consider using more emojis to increase engagement (up to #{platform_rules[:max_emojis]})"
      end
    end
    
    # Platform-specific recommendations
    case platform
    when :instagram
      if usage_stats[:total_emojis_used] < 5
        recommendations << "Instagram performs better with more emojis - consider adding more visual elements"
      end
    when :linkedin
      business_emojis_used = usage_stats[:emoji_categories_used][:business] || []
      if business_emojis_used.empty?
        recommendations << "Use professional emojis like 💼 📊 💡 to maintain LinkedIn's professional tone"
      end
    when :email
      if usage_stats[:total_emojis_used] > 0
        recommendations << "Consider replacing emojis with text alternatives for better email client compatibility"
      end
    end
    
    recommendations
  end

  # Emoji suggestion generation
  def generate_emoji_suggestions(content, platform_rules)
    suggestions = []
    current_emojis = extract_emojis(content)
    max_additional = (platform_rules[:max_emojis] || 10) - current_emojis.length
    
    return suggestions if max_additional <= 0
    
    # Content-based suggestions
    content_sentiment = analyze_content_sentiment(content)
    content_topics = extract_content_topics(content)
    
    case content_sentiment
    when :positive
      suggestions << "Add celebration emojis: #{EMOJI_CATEGORIES[:celebration].sample(2).join(' ')}"
    when :negative
      suggestions << "Consider neutral emojis to balance tone: #{EMOJI_CATEGORIES[:emotions][:neutral].sample(2).join(' ')}"
    end
    
    content_topics.each do |topic|
      if EMOJI_CATEGORIES[topic]
        topic_emojis = EMOJI_CATEGORIES[topic].sample([max_additional, 2].min)
        suggestions << "Add #{topic}-related emojis: #{topic_emojis.join(' ')}"
      end
    end
    
    # Platform-specific suggestions
    if platform_rules[:recommended_emojis]
      unused_recommended = platform_rules[:recommended_emojis] - current_emojis
      if unused_recommended.any?
        suggested_emojis = unused_recommended.sample([max_additional, 3].min)
        suggestions << "Try platform-optimized emojis: #{suggested_emojis.join(' ')}"
      end
    end
    
    suggestions.uniq
  end
end