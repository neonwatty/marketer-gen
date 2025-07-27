class SuggestionFeedback < ApplicationRecord
  belongs_to :journey
  belongs_to :journey_step
  belongs_to :user

  FEEDBACK_TYPES = %w[
    suggestion_quality
    relevance
    usefulness
    timing
    channel_fit
    content_appropriateness
    implementation_ease
    expected_results
  ].freeze

  validates :feedback_type, inclusion: { in: FEEDBACK_TYPES }
  validates :rating, numericality: { in: 1..5 }, allow_nil: true
  validates :selected, inclusion: { in: [true, false] }

  scope :positive, -> { where('rating >= ?', 4) }
  scope :negative, -> { where('rating <= ?', 2) }
  scope :selected, -> { where(selected: true) }
  scope :by_feedback_type, ->(type) { where(feedback_type: type) }
  scope :recent, -> { where('created_at >= ?', 30.days.ago) }

  # Scopes for analytics
  scope :for_content_type, ->(content_type) {
    joins(:journey_step).where(journey_steps: { content_type: content_type })
  }
  
  scope :for_stage, ->(stage) {
    joins(:journey_step).where(journey_steps: { stage: stage })
  }

  scope :for_channel, ->(channel) {
    joins(:journey_step).where(journey_steps: { channel: channel })
  }

  # Class methods for analytics
  def self.average_rating_by_type
    group(:feedback_type).average(:rating)
  end

  def self.selection_rate_by_content_type
    joins(:journey_step)
      .group('journey_steps.content_type')
      .group(:selected)
      .count
      .transform_keys { |key| key.is_a?(Array) ? { content_type: key[0], selected: key[1] } : key }
  end

  def self.selection_rate_by_stage
    joins(:journey_step)
      .group('journey_steps.stage')
      .group(:selected)
      .count
      .transform_keys { |key| key.is_a?(Array) ? { stage: key[0], selected: key[1] } : key }
  end

  def self.top_performing_suggestions(limit = 10)
    where(selected: true)
      .group(:suggested_step_id)
      .order('COUNT(*) DESC')
      .limit(limit)
      .count
  end

  def self.feedback_trends(days = 30)
    where('created_at >= ?', days.days.ago)
      .group_by_day(:created_at)
      .group(:feedback_type)
      .average(:rating)
  end

  # Instance methods
  def positive?
    rating && rating >= 4
  end

  def negative?
    rating && rating <= 2
  end

  def neutral?
    rating && rating == 3
  end

  def suggested_step_data
    metadata['suggested_step_data']
  end

  def ai_provider
    metadata['provider']
  end

  def feedback_timestamp
    metadata['timestamp']
  end

  # Validation helpers
  def validate_rating_for_feedback_type
    case feedback_type
    when 'suggestion_quality', 'relevance', 'usefulness'
      errors.add(:rating, "is required for #{feedback_type}") if rating.blank?
    end
  end

  private

  validate :validate_rating_for_feedback_type
end