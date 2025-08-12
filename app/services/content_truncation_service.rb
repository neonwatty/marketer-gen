# Service for intelligent content truncation and expansion
# Provides multiple strategies for adapting content length while preserving meaning
class ContentTruncationService
  include ActiveModel::Model

  TRUNCATION_STRATEGIES = %i[smart sentence word hard preserve_hashtags preserve_mentions].freeze
  EXPANSION_STRATEGIES = %i[contextual engagement professional casual].freeze

  attr_accessor :content, :target_length, :strategy, :context

  def initialize(content:, target_length:, strategy: :smart, context: {})
    @content = content
    @target_length = target_length
    @strategy = strategy.to_sym
    @context = context || {}
    validate_inputs!
  end

  # Main truncation method
  def truncate
    return content if content.length <= target_length

    case strategy
    when :smart
      smart_truncate
    when :sentence
      sentence_truncate
    when :word
      word_truncate
    when :hard
      hard_truncate
    when :preserve_hashtags
      preserve_hashtags_truncate
    when :preserve_mentions
      preserve_mentions_truncate
    else
      smart_truncate
    end
  end

  # Main expansion method
  def expand(min_length, expansion_strategy: :contextual)
    return content if content.length >= min_length

    target_expansion = min_length - content.length

    case expansion_strategy
    when :contextual
      contextual_expand(target_expansion)
    when :engagement
      engagement_expand(target_expansion)
    when :professional
      professional_expand(target_expansion)
    when :casual
      casual_expand(target_expansion)
    else
      contextual_expand(target_expansion)
    end
  end

  # Analyze content structure for optimal truncation
  def analyze_structure
    {
      total_length: content.length,
      word_count: content.split.length,
      sentence_count: content.split(/[.!?]+/).length,
      paragraph_count: content.split(/\n\s*\n/).length,
      hashtag_count: content.scan(/#\w+/).length,
      mention_count: content.scan(/@\w+/).length,
      link_count: content.scan(/https?:\/\/[^\s]+/).length,
      sentences: extract_sentences,
      importance_scores: calculate_sentence_importance
    }
  end

  # Get truncation preview with multiple strategies
  def preview_truncations
    return {} if content.length <= target_length

    strategies = {}
    TRUNCATION_STRATEGIES.each do |strat|
      begin
        truncator = self.class.new(
          content: content,
          target_length: target_length,
          strategy: strat,
          context: context
        )
        strategies[strat] = {
          result: truncator.truncate,
          length: truncator.truncate.length,
          quality_score: calculate_quality_score(truncator.truncate)
        }
      rescue => e
        strategies[strat] = { error: e.message }
      end
    end
    strategies
  end

  private

  def validate_inputs!
    raise ArgumentError, "Content cannot be blank" if content.blank?
    raise ArgumentError, "Target length must be positive" if target_length <= 0
    raise ArgumentError, "Invalid strategy: #{strategy}" unless TRUNCATION_STRATEGIES.include?(strategy)
  end

  # Smart truncation preserves meaning and structure
  def smart_truncate
    structure = analyze_structure
    sentences = structure[:sentences]
    importance_scores = structure[:importance_scores]

    # Strategy 1: Try to preserve complete high-importance sentences
    preserved_content = preserve_important_sentences(sentences, importance_scores)
    return finalize_truncation(preserved_content) if preserved_content.length <= target_length

    # Strategy 2: Truncate at paragraph boundaries
    paragraphs = content.split(/\n\s*\n/)
    if paragraphs.length > 1
      truncated = preserve_paragraphs(paragraphs)
      return finalize_truncation(truncated) if truncated.length <= target_length
    end

    # Strategy 3: Truncate at sentence boundaries
    sentence_truncated = sentence_truncate
    return sentence_truncated if sentence_truncated.length <= target_length

    # Strategy 4: Fall back to word truncation
    word_truncate
  end

  def sentence_truncate
    sentences = extract_sentences.reject(&:blank?)
    return content if sentences.empty?

    truncated = ""
    sentences.each do |sentence|
      potential_content = truncated.empty? ? sentence : "#{truncated} #{sentence}"
      
      if potential_content.length <= target_length - 3 # Leave space for ellipsis
        truncated = potential_content
      else
        break
      end
    end

    # If we couldn't fit any sentences, fall back to word truncation
    return word_truncate if truncated.empty?

    finalize_truncation(truncated)
  end

  def word_truncate
    words = content.split
    truncated = ""
    
    words.each do |word|
      potential_content = truncated.empty? ? word : "#{truncated} #{word}"
      
      if potential_content.length <= target_length - 3 # Leave space for ellipsis
        truncated = potential_content
      else
        break
      end
    end

    finalize_truncation(truncated)
  end

  def hard_truncate
    return content if content.length <= target_length
    content[0...(target_length - 3)] + "..."
  end

  def preserve_hashtags_truncate
    hashtags = content.scan(/#\w+/)
    hashtag_text = hashtags.join(" ")
    hashtag_length = hashtag_text.length

    # Reserve space for hashtags
    available_length = target_length - hashtag_length - 4 # Space for separator and ellipsis

    if available_length <= 10
      # Not enough space for meaningful content + hashtags
      return smart_truncate
    end

    # Remove hashtags from content temporarily
    content_without_hashtags = content.gsub(/#\w+/, '').gsub(/\s+/, ' ').strip

    # Truncate the content without hashtags
    truncator = self.class.new(
      content: content_without_hashtags,
      target_length: available_length,
      strategy: :smart,
      context: context
    )
    truncated_content = truncator.truncate.gsub(/\.\.\.$/, '') # Remove ellipsis

    # Recombine with hashtags
    if hashtags.any?
      "#{truncated_content}... #{hashtag_text}"
    else
      finalize_truncation(truncated_content)
    end
  end

  def preserve_mentions_truncate
    mentions = content.scan(/@\w+/)
    mention_text = mentions.join(" ")
    mention_length = mention_text.length

    # Reserve space for mentions
    available_length = target_length - mention_length - 4 # Space for separator and ellipsis

    if available_length <= 10
      # Not enough space for meaningful content + mentions
      return smart_truncate
    end

    # Remove mentions from content temporarily
    content_without_mentions = content.gsub(/@\w+/, '').gsub(/\s+/, ' ').strip

    # Truncate the content without mentions
    truncator = self.class.new(
      content: content_without_mentions,
      target_length: available_length,
      strategy: :smart,
      context: context
    )
    truncated_content = truncator.truncate.gsub(/\.\.\.$/, '') # Remove ellipsis

    # Recombine with mentions
    if mentions.any?
      "#{truncated_content}... #{mention_text}"
    else
      finalize_truncation(truncated_content)
    end
  end

  # Content expansion methods
  def contextual_expand(target_expansion)
    brand_name = context[:brand_name] || context[:brand_context]&.dig(:name)
    industry = context[:industry] || context[:brand_context]&.dig(:industry)
    platform = context[:platform]

    expansions = build_contextual_expansions(brand_name, industry, platform)
    best_expansion = find_best_expansion(expansions, target_expansion)

    "#{content} #{best_expansion}"
  end

  def engagement_expand(target_expansion)
    platform = context[:platform]&.to_sym

    case platform
    when :twitter
      expansions = [
        "What do you think? Reply below! 🤔",
        "RT if you agree! 🔄",
        "Join the conversation 👇",
        "Share your thoughts! 💭",
        "Tag someone who needs to see this! 👥"
      ]
    when :instagram
      expansions = [
        "Double tap if you agree! ❤️",
        "Tag a friend who needs to see this! 👇",
        "Share your story in the comments! 💬",
        "What's your experience? Tell us below! 📝",
        "Save this post for later! 📌"
      ]
    when :linkedin
      expansions = [
        "What's your perspective on this? Share your thoughts in the comments.",
        "How has this impacted your work? I'd love to hear your experiences.",
        "What strategies have worked for you? Let's discuss below.",
        "Connect with me to continue this conversation.",
        "What would you add to this list? Comment below!"
      ]
    when :facebook
      expansions = [
        "What do you think? Comment below and share with friends!",
        "Share your experiences in the comments!",
        "Tag someone who would find this helpful!",
        "What's your take on this? Let's discuss!",
        "Share this with your network!"
      ]
    else
      expansions = [
        "What are your thoughts on this?",
        "Share your perspective!",
        "Let's discuss this further!",
        "What's your experience?",
        "Join the conversation!"
      ]
    end

    best_expansion = find_best_expansion(expansions, target_expansion)
    "#{content} #{best_expansion}"
  end

  def professional_expand(target_expansion)
    expansions = [
      "This aligns with current industry best practices and standards.",
      "Our research indicates this approach delivers measurable results.",
      "We're committed to providing valuable insights and solutions.",
      "Contact our team to learn more about implementing these strategies.",
      "We welcome the opportunity to discuss this further with your organization.",
      "This methodology has been validated through extensive industry experience.",
      "We continue to monitor developments in this space for our clients."
    ]

    best_expansion = find_best_expansion(expansions, target_expansion)
    "#{content} #{best_expansion}"
  end

  def casual_expand(target_expansion)
    expansions = [
      "Pretty cool stuff, right? 😊",
      "Hope this helps! Let me know what you think!",
      "This has been a game-changer for us!",
      "Can't wait to see how this works out!",
      "Really excited to share this with you all!",
      "This is something we're passionate about!",
      "Love hearing about your experiences with this!"
    ]

    best_expansion = find_best_expansion(expansions, target_expansion)
    "#{content} #{best_expansion}"
  end

  # Helper methods
  def extract_sentences
    # Split on sentence boundaries while preserving the punctuation
    sentences = content.split(/([.!?]+)/).each_slice(2).map(&:join)
    sentences.map(&:strip).reject(&:blank?)
  end

  def calculate_sentence_importance
    sentences = extract_sentences
    return [] if sentences.empty?

    importance_scores = sentences.map do |sentence|
      score = 0.0

      # Length factor (moderate length sentences are often more important)
      length_score = 1.0 - (sentence.length - 50).abs / 100.0
      score += [length_score, 0.0].max * 0.2

      # Position factor (first and last sentences often more important)
      position_index = sentences.index(sentence)
      if position_index == 0 || position_index == sentences.length - 1
        score += 0.3
      end

      # Keyword density (presence of important terms)
      important_terms = extract_important_terms
      term_matches = important_terms.count { |term| sentence.downcase.include?(term.downcase) }
      score += (term_matches.to_f / important_terms.length) * 0.3

      # Question factor (questions often engage readers)
      score += 0.1 if sentence.include?('?')

      # Call-to-action factor
      cta_patterns = /\b(learn|discover|find|get|try|start|contact|call|visit|click)\b/i
      score += 0.1 if sentence.match?(cta_patterns)

      [score, 0.0].max
    end

    importance_scores
  end

  def extract_important_terms
    brand_name = context[:brand_name] || context[:brand_context]&.dig(:name)
    industry = context[:industry] || context[:brand_context]&.dig(:industry)
    
    terms = []
    terms << brand_name if brand_name
    terms << industry if industry
    terms += context[:keywords] if context[:keywords].is_a?(Array)
    
    # Add common business terms
    terms += %w[solution service product customer client business growth success]
    
    terms.compact.uniq
  end

  def preserve_important_sentences(sentences, importance_scores)
    return "" if sentences.empty?

    # Pair sentences with their scores and sort by importance
    sentence_pairs = sentences.zip(importance_scores)
    sorted_pairs = sentence_pairs.sort_by { |_, score| -score }

    preserved_content = ""
    sorted_pairs.each do |sentence, _|
      potential_content = preserved_content.empty? ? sentence : "#{preserved_content} #{sentence}"
      
      if potential_content.length <= target_length - 3
        preserved_content = potential_content
      else
        break
      end
    end

    preserved_content
  end

  def preserve_paragraphs(paragraphs)
    truncated = ""
    
    paragraphs.each do |paragraph|
      potential_content = truncated.empty? ? paragraph : "#{truncated}\n\n#{paragraph}"
      
      if potential_content.length <= target_length - 3
        truncated = potential_content
      else
        break
      end
    end

    truncated
  end

  def build_contextual_expansions(brand_name, industry, platform)
    expansions = []

    if brand_name
      expansions << "Learn more about how #{brand_name} can help you achieve your goals."
      expansions << "#{brand_name} is committed to delivering exceptional results."
      expansions << "Contact #{brand_name} today to get started."
    end

    if industry
      expansions << "This approach is proven effective in the #{industry} industry."
      expansions << "Our #{industry} expertise ensures quality outcomes."
      expansions << "Stay ahead in the #{industry} landscape with our solutions."
    end

    case platform&.to_sym
    when :linkedin
      expansions << "Connect with me to continue this professional discussion."
      expansions << "I'd welcome the opportunity to explore this topic further with your team."
    when :twitter
      expansions << "Follow for more insights like this! 🚀"
      expansions << "More to come on this topic! Stay tuned 📡"
    when :instagram
      expansions << "Follow us for more content like this! ✨"
      expansions << "Check out our stories for behind-the-scenes content! 📸"
    end

    # Default expansions
    expansions += [
      "We're here to help you succeed in your endeavors.",
      "Discover the difference our approach can make for your organization.",
      "Let's work together to achieve exceptional results.",
      "Contact us to learn more about our comprehensive solutions."
    ]

    expansions.uniq
  end

  def find_best_expansion(expansions, target_expansion)
    # Find expansion that best fits the target length
    best_fit = expansions.find { |exp| exp.length <= target_expansion }
    
    # If no expansion fits exactly, find the closest one and truncate if necessary
    if best_fit.nil?
      shortest = expansions.min_by(&:length)
      if shortest.length <= target_expansion
        best_fit = shortest
      else
        # Truncate the shortest expansion
        available_length = target_expansion - 3 # Space for ellipsis
        best_fit = shortest[0...available_length] + "..."
      end
    end

    best_fit || "Learn more!"
  end

  def finalize_truncation(content)
    return content if content.length <= target_length

    # Final check and add ellipsis if needed
    if content.length > target_length - 3
      content = content[0...(target_length - 3)]
    end

    # Clean up any trailing punctuation before adding ellipsis
    content = content.gsub(/[.!?]+$/, '')
    "#{content}..."
  end

  def calculate_quality_score(truncated_content)
    original_word_count = content.split.length
    truncated_word_count = truncated_content.split.length
    
    # Base score from content retention
    retention_score = truncated_word_count.to_f / original_word_count
    
    # Bonus for preserving sentence structure
    structure_bonus = 0.0
    if truncated_content.match?(/[.!?]$/) || truncated_content.end_with?('...')
      structure_bonus = 0.1
    end
    
    # Bonus for preserving important elements
    element_bonus = 0.0
    if content.scan(/#\w+/).any? && truncated_content.scan(/#\w+/).any?
      element_bonus += 0.05
    end
    
    if content.scan(/@\w+/).any? && truncated_content.scan(/@\w+/).any?
      element_bonus += 0.05
    end
    
    [(retention_score + structure_bonus + element_bonus), 1.0].min
  end
end