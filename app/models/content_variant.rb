# ActiveRecord model for content variants used in A/B testing
# Each variant represents a different version of content for testing performance
class ContentVariant < ApplicationRecord
  # Associations
  belongs_to :content_request
  has_many :variant_performance_metrics, dependent: :destroy
  has_many :ab_test_results, dependent: :destroy

  # Validations
  validates :content, presence: true
  validates :name, presence: true
  validates :variant_number, presence: true, 
            numericality: { greater_than: 0 },
            uniqueness: { scope: :content_request_id }
  validates :status, presence: true, inclusion: { 
    in: %w[draft active testing completed archived], 
    message: "must be a valid status" 
  }
  validates :strategy_type, presence: true, inclusion: {
    in: %w[tone_variation structure_variation cta_variation length_variation 
           headline_variation emotional_appeal format_variation platform_optimization
           engagement_optimization conversion_optimization competitive_positioning],
    message: "must be a valid strategy type"
  }

  # Serialized attributes for JSON storage
  serialize :metadata, coder: JSON
  serialize :differences_analysis, coder: JSON
  serialize :performance_data, coder: JSON
  serialize :tags, coder: JSON

  # Scopes
  scope :active, -> { where(status: 'active') }
  scope :testing, -> { where(status: 'testing') }
  scope :completed, -> { where(status: 'completed') }
  scope :by_strategy, ->(strategy) { where(strategy_type: strategy) }
  scope :high_performance, -> { where('performance_score > ?', 0.7) }
  scope :recent, -> { order(created_at: :desc) }

  # Callbacks
  before_validation :set_defaults
  after_create :update_variant_counter

  # Instance methods

  # Check if variant is currently being tested
  def testing?
    status == 'testing'
  end

  # Check if variant is ready for testing
  def ready_for_testing?
    status == 'active' && content.present? && performance_score.present?
  end

  # Check if variant has completed testing
  def testing_completed?
    status == 'completed'
  end

  # Get formatted strategy name
  def strategy_name
    strategy_type.humanize
  end

  # Calculate content differences from original
  def content_differences_summary
    return "No differences recorded" unless differences_analysis.present?

    differences_analysis.map do |diff|
      "#{diff['type'].humanize}: #{diff['description']}"
    end.join('; ')
  end

  # Get performance metrics summary
  def performance_summary
    return {} unless performance_data.present?

    {
      engagement_rate: performance_data['engagement_rate'] || 0,
      click_through_rate: performance_data['click_through_rate'] || 0,
      conversion_rate: performance_data['conversion_rate'] || 0,
      total_impressions: performance_data['total_impressions'] || 0,
      last_updated: performance_data['last_updated']
    }
  end

  # Update performance data
  def update_performance_data(new_data)
    current_data = performance_data || {}
    updated_data = current_data.merge(new_data)
    updated_data['last_updated'] = Time.current.iso8601
    
    update(performance_data: updated_data)
  end

  # Calculate predicted performance metrics
  def predicted_metrics
    base_engagement = 0.05
    base_ctr = 0.02
    base_conversion = 0.01
    
    score_multiplier = performance_score || 0.5
    
    {
      predicted_engagement: (base_engagement * score_multiplier).round(4),
      predicted_ctr: (base_ctr * score_multiplier).round(4),
      predicted_conversion: (base_conversion * score_multiplier).round(4),
      confidence_interval: calculate_confidence_interval
    }
  end

  # Get variant tags as array
  def tag_list
    tags.is_a?(Array) ? tags : (tags.present? ? [tags] : [])
  end

  # Set variant tags from array or string
  def tag_list=(new_tags)
    self.tags = case new_tags
               when Array
                 new_tags.map(&:strip).reject(&:blank?)
               when String
                 new_tags.split(',').map(&:strip).reject(&:blank?)
               else
                 []
               end
  end

  # Add a tag to the variant
  def add_tag(tag)
    current_tags = tag_list
    current_tags << tag.strip unless current_tags.include?(tag.strip)
    self.tags = current_tags
    save
  end

  # Remove a tag from the variant
  def remove_tag(tag)
    current_tags = tag_list
    current_tags.delete(tag.strip)
    self.tags = current_tags
    save
  end

  # Check if variant has a specific tag
  def has_tag?(tag)
    tag_list.include?(tag.strip)
  end

  # Get content statistics
  def content_stats
    return {} unless content.present?

    words = content.split(/\W+/).reject(&:blank?)
    sentences = content.split(/[.!?]+/).reject(&:blank?)
    
    {
      character_count: content.length,
      word_count: words.length,
      sentence_count: sentences.length,
      average_sentence_length: sentences.empty? ? 0 : words.length.to_f / sentences.length,
      readability_score: calculate_readability_score
    }
  end

  # Analyze content elements
  def content_analysis
    return {} unless content.present?

    {
      has_question: content.include?('?'),
      has_cta: has_call_to_action?,
      has_emotional_language: has_emotional_language?,
      has_urgency: has_urgency_language?,
      has_social_proof: has_social_proof?,
      has_numbers: content.match?(/\d+/),
      tone: analyze_tone,
      sentiment: analyze_sentiment
    }
  end

  # Compare with another variant
  def compare_with(other_variant)
    return {} unless other_variant.is_a?(ContentVariant)

    {
      performance_difference: (performance_score || 0) - (other_variant.performance_score || 0),
      length_difference: content.length - other_variant.content.length,
      strategy_comparison: {
        this_strategy: strategy_type,
        other_strategy: other_variant.strategy_type,
        same_strategy: strategy_type == other_variant.strategy_type
      },
      content_similarity: calculate_content_similarity(other_variant.content),
      winner: determine_winner(other_variant)
    }
  end

  # Start A/B testing for this variant
  def start_testing!
    update!(status: 'testing', testing_started_at: Time.current)
    create_ab_test_record
  end

  # Complete A/B testing for this variant
  def complete_testing!(results = {})
    update!(
      status: 'completed',
      testing_completed_at: Time.current,
      final_performance_data: results
    )
  end

  # Archive this variant
  def archive!
    update!(status: 'archived', archived_at: Time.current)
  end

  # Duplicate this variant
  def duplicate!
    new_variant = self.dup
    new_variant.name = "#{name} (Copy)"
    new_variant.variant_number = content_request.content_variants.count + 1
    new_variant.status = 'draft'
    new_variant.performance_score = nil
    new_variant.performance_data = {}
    new_variant.testing_started_at = nil
    new_variant.testing_completed_at = nil
    
    new_variant.save!
    new_variant
  end

  # Class methods
  class << self
    # Find variants ready for testing
    def ready_for_testing
      where(status: 'active').where.not(performance_score: nil)
    end

    # Get performance statistics for all variants
    def performance_statistics
      {
        total_variants: count,
        active_variants: active.count,
        testing_variants: testing.count,
        completed_variants: completed.count,
        average_performance_score: average(:performance_score)&.round(3),
        highest_performance_score: maximum(:performance_score),
        lowest_performance_score: minimum(:performance_score)
      }
    end

    # Get strategy distribution
    def strategy_distribution
      group(:strategy_type).count
    end

    # Find top performing variants
    def top_performers(limit = 5)
      where.not(performance_score: nil)
           .order(performance_score: :desc)
           .limit(limit)
    end

    # Get variants by performance tier
    def by_performance_tier(tier)
      case tier.to_sym
      when :high
        where('performance_score > ?', 0.7)
      when :medium
        where(performance_score: 0.4..0.7)
      when :low
        where('performance_score < ?', 0.4)
      else
        all
      end
    end
  end

  private

  def set_defaults
    self.status ||= 'draft'
    self.performance_score ||= 0.0
    self.metadata ||= {}
    self.performance_data ||= {}
    self.differences_analysis ||= []
    self.tags ||= []
    
    # Generate default name if not provided
    if name.blank? && strategy_type.present? && variant_number.present?
      self.name = "#{strategy_type.humanize} - Variant #{variant_number}"
    end
  end

  def update_variant_counter
    # Update the content request's variant count
    content_request.increment!(:variants_count) if content_request.respond_to?(:variants_count)
  end

  def calculate_confidence_interval
    score = performance_score || 0.5
    margin = 0.1 * (1 - score) # Lower confidence for lower scores
    
    {
      lower: [score - margin, 0.0].max,
      upper: [score + margin, 1.0].min
    }
  end

  def calculate_readability_score
    sentences = content.split(/[.!?]+/).reject(&:blank?)
    words = content.split(/\W+/).reject(&:blank?)
    
    return 0.5 if sentences.empty? || words.empty?
    
    avg_sentence_length = words.length.to_f / sentences.length
    
    # Ideal sentence length is around 15-20 words
    if avg_sentence_length.between?(15, 20)
      1.0
    else
      1.0 - [(avg_sentence_length - 17.5).abs / 17.5, 1.0].min
    end
  end

  def has_call_to_action?
    cta_patterns = [
      /\b(learn more|get started|sign up|contact us|buy now|try now|discover|download)\b/i,
      /\b(click|call|visit|shop|order|book|register|subscribe)\b/i
    ]
    
    cta_patterns.any? { |pattern| content.match?(pattern) }
  end

  def has_emotional_language?
    emotional_words = %w[amazing incredible fantastic love hate exciting thrilling wonderful terrible]
    content_words = content.downcase.split(/\W+/)
    (content_words & emotional_words).any?
  end

  def has_urgency_language?
    urgency_words = %w[urgent now today immediately limited time hurry deadline expires soon]
    content_words = content.downcase.split(/\W+/)
    (content_words & urgency_words).any?
  end

  def has_social_proof?
    social_proof_indicators = %w[customers clients users testimonial review rating thousand million trusted]
    content_words = content.downcase.split(/\W+/)
    (content_words & social_proof_indicators).any?
  end

  def analyze_tone
    professional_indicators = %w[professional expertise experience solution quality service]
    casual_indicators = %w[hey cool awesome great fun easy simple]
    urgent_indicators = %w[urgent now immediately limited time act fast]
    
    content_words = content.downcase.split(/\W+/)
    
    professional_score = (content_words & professional_indicators).length
    casual_score = (content_words & casual_indicators).length
    urgent_score = (content_words & urgent_indicators).length
    
    scores = { professional: professional_score, casual: casual_score, urgent: urgent_score }
    scores.max_by { |_, score| score }&.first || :neutral
  end

  def analyze_sentiment
    positive_words = %w[great amazing excellent wonderful fantastic love excited happy]
    negative_words = %w[bad terrible awful horrible disappointing sad angry frustrated]
    
    content_words = content.downcase.split(/\W+/)
    
    positive_count = (content_words & positive_words).length
    negative_count = (content_words & negative_words).length
    
    if positive_count > negative_count
      :positive
    elsif negative_count > positive_count
      :negative
    else
      :neutral
    end
  end

  def calculate_content_similarity(other_content)
    return 0.0 unless other_content.present?
    
    # Simple word-based similarity calculation
    words1 = content.downcase.split(/\W+/).reject(&:blank?)
    words2 = other_content.downcase.split(/\W+/).reject(&:blank?)
    
    return 0.0 if words1.empty? || words2.empty?
    
    common_words = words1 & words2
    total_words = (words1 + words2).uniq.length
    
    common_words.length.to_f / total_words
  end

  def determine_winner(other_variant)
    my_score = performance_score || 0
    other_score = other_variant.performance_score || 0
    
    if my_score > other_score + 0.05 # Require significant difference
      :this_variant
    elsif other_score > my_score + 0.05
      :other_variant
    else
      :tie
    end
  end

  def create_ab_test_record
    ab_test_results.create!(
      test_name: "AB Test - #{name}",
      started_at: Time.current,
      status: 'running',
      control_variant: content_request.content_variants.where(variant_number: 1).first,
      metadata: {
        strategy_type: strategy_type,
        initial_performance_score: performance_score
      }
    )
  end
end