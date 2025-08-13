# ActiveRecord model for content generation responses
# Contains generated content with metadata and quality metrics
class ContentResponse < ApplicationRecord
  # Associations
  belongs_to :content_request

  # Validations
  validates :generated_content, presence: true
  validates :generation_status, presence: true, inclusion: { 
    in: %w[pending in_progress completed failed draft], 
    message: "must be a valid status" 
  }

  # Serialized attributes for JSON storage
  serialize :response_metadata, coder: JSON

  # Scopes
  scope :completed, -> { where(generation_status: 'completed') }
  scope :pending, -> { where(generation_status: 'pending') }
  scope :failed, -> { where(generation_status: 'failed') }

  # Default values
  before_validation :set_defaults

  def set_defaults
    self.generation_status ||= 'pending'
  end

  # Content preview (truncated version)
  def preview(max_length: 100)
    return generated_content if generated_content.length <= max_length
    "#{generated_content[0...max_length-3]}..."
  end

  # Check if content is completed
  def completed?
    generation_status == 'completed'
  end

  # Check if content is pending
  def pending?
    generation_status == 'pending'
  end

  # Check if content failed to generate
  def failed?
    generation_status == 'failed'
  end

  # Get word count of generated content
  def word_count
    return 0 unless generated_content.present?
    generated_content.split.size
  end

  # Get character count of generated content
  def character_count
    return 0 unless generated_content.present?
    generated_content.length
  end

  # Alias for compatibility with adapters
  def content
    generated_content
  end

  # Virtual attributes that work with JSON metadata
  def channel_type
    response_metadata&.dig('channel_type')
  end

  def channel_type=(value)
    metadata = response_metadata.is_a?(Hash) ? response_metadata : {}
    metadata['channel_type'] = value
    self.response_metadata = metadata
  end

  def channel_specific_data
    response_metadata&.dig('channel_specific_data') || {}
  end

  def channel_specific_data=(value)
    metadata = response_metadata.is_a?(Hash) ? response_metadata : {}
    metadata['channel_specific_data'] = value
    self.response_metadata = metadata
  end

  def quality_score
    response_metadata&.dig('quality_score')
  end

  def quality_score=(value)
    metadata = response_metadata.is_a?(Hash) ? response_metadata : {}
    metadata['quality_score'] = value
    self.response_metadata = metadata
  end

  def engagement_prediction
    response_metadata&.dig('engagement_prediction')
  end

  def engagement_prediction=(value)
    metadata = response_metadata.is_a?(Hash) ? response_metadata : {}
    metadata['engagement_prediction'] = value
    self.response_metadata = metadata
  end

  def model_used
    response_metadata&.dig('model_used')
  end

  def model_used=(value)
    metadata = response_metadata.is_a?(Hash) ? response_metadata : {}
    metadata['model_used'] = value
    self.response_metadata = metadata
  end

  def request_id
    response_metadata&.dig('request_id') || content_request_id
  end

  def request_id=(value)
    metadata = response_metadata.is_a?(Hash) ? response_metadata : {}
    metadata['request_id'] = value
    self.response_metadata = metadata
  end

  def optimization_suggestions
    response_metadata&.dig('optimization_suggestions') || []
  end

  def optimization_suggestions=(value)
    metadata = response_metadata.is_a?(Hash) ? response_metadata : {}
    metadata['optimization_suggestions'] = value
    self.response_metadata = metadata
  end

  def generation_stats
    response_metadata&.dig('generation_stats') || {}
  end

  def generation_stats=(value)
    metadata = response_metadata.is_a?(Hash) ? response_metadata : {}
    metadata['generation_stats'] = value
    self.response_metadata = metadata
  end
end