class Brand < ApplicationRecord
  include Branding::Compliance::CacheInvalidation
  
  belongs_to :user
  has_many :brand_assets, dependent: :destroy
  has_many :brand_guidelines, dependent: :destroy
  has_one :messaging_framework, dependent: :destroy
  has_many :brand_analyses, dependent: :destroy
  has_many :journeys
  has_many :compliance_results, dependent: :destroy
  has_many :social_media_integrations, dependent: :destroy
  has_many :social_media_metrics, through: :social_media_integrations
  has_many :email_integrations, dependent: :destroy
  has_many :email_campaigns, through: :email_integrations
  has_many :email_metrics, through: :email_integrations
  has_many :email_subscribers, through: :email_integrations
  has_many :email_automations, through: :email_integrations
  has_many :crm_integrations, dependent: :destroy
  has_many :crm_leads, through: :crm_integrations
  has_many :crm_opportunities, through: :crm_integrations
  has_many :crm_analytics, through: :crm_integrations

  # Validations
  validates :name, presence: true, uniqueness: { scope: :user_id }
  validates :user, presence: true

  # Scopes
  scope :active, -> { where(active: true) }
  scope :by_industry, ->(industry) { where(industry: industry) }

  # Callbacks
  after_create :create_default_messaging_framework

  # Methods
  def latest_analysis
    brand_analyses.order(created_at: :desc).first
  end

  def has_complete_brand_assets?
    brand_assets.where(processing_status: "completed").exists?
  end

  def guidelines_by_category(category)
    brand_guidelines.active.where(category: category).order(priority: :desc)
  end

  def primary_colors
    color_scheme["primary"] || []
  end

  def secondary_colors
    color_scheme["secondary"] || []
  end

  def font_families
    typography["font_families"] || {}
  end

  def brand_voice_attributes
    latest_analysis&.voice_attributes || {}
  end

  private

  def create_default_messaging_framework
    MessagingFramework.create!(brand: self)
  end
end
