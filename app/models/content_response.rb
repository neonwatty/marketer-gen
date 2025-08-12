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
end