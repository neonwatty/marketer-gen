class Persona < ApplicationRecord
  belongs_to :user
  has_many :campaigns, dependent: :destroy
  has_many :journeys, through: :campaigns
  
  validates :name, presence: true, uniqueness: { scope: :user_id }
  validates :description, presence: true
  
  # Demographic fields
  DEMOGRAPHIC_FIELDS = %w[
    age_range gender location income_level education_level 
    employment_status family_status occupation
  ].freeze
  
  # Behavior fields
  BEHAVIOR_FIELDS = %w[
    online_activity purchase_behavior social_media_usage 
    content_preferences communication_preferences device_usage
  ].freeze
  
  # Preference fields  
  PREFERENCE_FIELDS = %w[
    brand_loyalty price_sensitivity channel_preferences 
    messaging_tone content_types shopping_habits
  ].freeze
  
  # Psychographic fields
  PSYCHOGRAPHIC_FIELDS = %w[
    values personality_traits lifestyle interests 
    attitudes motivations goals pain_points
  ].freeze
  
  scope :active, -> { joins(:campaigns).where(campaigns: { status: ['active', 'published'] }).distinct }
  
  def display_name
    name
  end
  
  def age_range
    demographics['age_range']
  end
  
  def primary_channel
    preferences['channel_preferences']&.first
  end
  
  def total_campaigns
    campaigns.count
  end
  
  def active_campaigns
    campaigns.where(status: ['active', 'published']).count
  end
  
  def demographics_summary
    return 'No demographics data' if demographics.blank?
    
    summary = []
    summary << "Age: #{demographics['age_range']}" if demographics['age_range'].present?
    summary << "Location: #{demographics['location']}" if demographics['location'].present?
    summary << "Income: #{demographics['income_level']}" if demographics['income_level'].present?
    
    summary.any? ? summary.join(', ') : 'Limited demographics data'
  end
  
  def behavior_summary
    return 'No behavior data' if behaviors.blank?
    
    summary = []
    summary << "Online: #{behaviors['online_activity']}" if behaviors['online_activity'].present?
    summary << "Purchase: #{behaviors['purchase_behavior']}" if behaviors['purchase_behavior'].present?
    summary << "Social: #{behaviors['social_media_usage']}" if behaviors['social_media_usage'].present?
    
    summary.any? ? summary.join(', ') : 'Limited behavior data'
  end
  
  def to_campaign_context
    {
      name: name,
      description: description,
      demographics: demographics_summary,
      behaviors: behavior_summary,
      preferences: preferences['messaging_tone'] || 'neutral',
      channels: preferences['channel_preferences'] || []
    }
  end
end