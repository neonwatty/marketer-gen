# ActiveRecord model for content generation requests
# Contains all necessary information for generating channel-specific content
class ContentRequest < ApplicationRecord
  # Associations
  has_one :content_response, dependent: :destroy
  has_many :content_variants, dependent: :destroy
  
  # Validations
  validates :content_type, presence: true, inclusion: { 
    in: %w[social_media email ads landing_page video_script blog general], 
    message: "must be a supported channel type" 
  }
  validates :brand_context, presence: true
  validates :tone, inclusion: { 
    in: %w[professional casual friendly authoritative playful formal conversational], 
    allow_blank: true, message: "must be a valid tone" 
  }

  # Serialized attributes for JSON storage
  serialize :request_metadata, coder: JSON

  # Scopes
  scope :by_channel, ->(channel) { where(content_type: channel) }
  scope :recent, -> { order(created_at: :desc) }
  scope :completed, -> { joins(:content_response).where(content_responses: { generation_status: 'completed' }) }

  # Default values
  before_validation :set_defaults

  def set_defaults
    self.tone ||= 'professional'
    self.content_length ||= 'medium'
    self.campaign_goal ||= 'engagement'
  end

  # Utility methods
  def social_media?
    content_type == 'social_media'
  end

  def email?
    content_type == 'email'
  end

  def ad?
    content_type == 'ads'
  end

  def landing_page?
    content_type == 'landing_page'
  end

  def video_script?
    content_type == 'video_script'
  end

  def blog?
    content_type == 'blog'
  end

  # Generate prompt context for AI
  def to_ai_context
    {
      content_type: content_type,
      platform: platform,
      brand_context: brand_context,
      campaign_name: campaign_name,
      campaign_goal: campaign_goal,
      target_audience: target_audience,
      tone: tone,
      content_length: content_length,
      required_elements: required_elements,
      restrictions: restrictions,
      additional_context: additional_context
    }
  end

  # Generate a display name for the content request
  def display_name
    campaign_name.present? ? campaign_name : "Content ##{id}"
  end

  # Check if content has been generated
  def content_generated?
    content_response&.generated_content.present?
  end

  # Get content status
  def status
    return 'pending' unless content_response
    content_response.generation_status
  end
end