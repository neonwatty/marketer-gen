# frozen_string_literal: true

class CrmLead < ApplicationRecord
  # Lead lifecycle stages
  LIFECYCLE_STAGES = %w[
    subscriber
    lead
    marketing_qualified_lead
    sales_qualified_lead
    opportunity
    customer
    evangelist
    other
  ].freeze

  # Lead statuses (common across platforms)
  LEAD_STATUSES = %w[
    new
    open
    in_progress
    contacted
    qualified
    unqualified
    converted
    closed
    nurturing
    recycled
  ].freeze

  # Lead sources
  LEAD_SOURCES = %w[
    web
    email
    social_media
    paid_advertising
    organic_search
    referral
    event
    webinar
    content_download
    demo_request
    contact_form
    phone_call
    partner
    other
  ].freeze

  # Associations
  belongs_to :crm_integration
  belongs_to :brand
  has_many :crm_analytics, through: :crm_integration

  # Validations
  validates :crm_id, presence: true, uniqueness: { scope: :crm_integration_id }
  validates :email, format: { with: URI::MailTo::EMAIL_REGEXP }, allow_blank: true
  validates :lifecycle_stage, inclusion: { in: LIFECYCLE_STAGES }, allow_blank: true
  validates :status, inclusion: { in: LEAD_STATUSES }, allow_blank: true
  validates :source, inclusion: { in: LEAD_SOURCES }, allow_blank: true

  # Scopes
  scope :marketing_qualified, -> { where(marketing_qualified: true) }
  scope :sales_qualified, -> { where(sales_qualified: true) }
  scope :converted, -> { where(converted: true) }
  scope :unconverted, -> { where(converted: false) }
  scope :by_lifecycle_stage, ->(stage) { where(lifecycle_stage: stage) }
  scope :by_status, ->(status) { where(status: status) }
  scope :by_source, ->(source) { where(source: source) }
  scope :recent, -> { where("created_at > ?", 30.days.ago) }
  scope :synced_recently, -> { where("last_synced_at > ?", 1.day.ago) }

  # Campaign attribution scopes
  scope :attributed_to_campaign, ->(campaign_id) { where(original_campaign: campaign_id) }
  scope :first_touch_campaign, ->(campaign_id) { where(first_touch_campaign_id: campaign_id) }
  scope :last_touch_campaign, ->(campaign_id) { where(last_touch_campaign_id: campaign_id) }

  # Callbacks
  before_validation :normalize_email
  before_save :calculate_qualification_dates
  after_update :track_lifecycle_progression, if: :saved_change_to_lifecycle_stage?

  # Lead qualification
  def qualified?
    marketing_qualified? || sales_qualified?
  end

  def marketing_qualified?
    marketing_qualified && mql_date.present?
  end

  def sales_qualified?
    sales_qualified && sql_date.present?
  end

  def mark_marketing_qualified!
    return if marketing_qualified?

    update!(
      marketing_qualified: true,
      mql_date: Time.current,
      lifecycle_stage: "marketing_qualified_lead"
    )
  end

  def mark_sales_qualified!
    return if sales_qualified?

    update!(
      sales_qualified: true,
      sql_date: Time.current,
      lifecycle_stage: "sales_qualified_lead"
    )
  end

  def mark_converted!(contact_id: nil, opportunity_id: nil, account_id: nil)
    return if converted?

    update!(
      converted: true,
      converted_at: Time.current,
      converted_contact_id: contact_id,
      converted_opportunity_id: opportunity_id,
      converted_account_id: account_id,
      lifecycle_stage: "customer"
    )
  end

  # Lead scoring and grading
  def calculate_lead_score
    score = 0

    # Demographics scoring
    score += 10 if company.present?
    score += 5 if title.present?
    score += 15 if annual_revenue.present? && annual_revenue > 1_000_000
    score += 10 if number_of_employees.present? && number_of_employees > 50

    # Engagement scoring
    score += 20 if marketing_qualified?
    score += 30 if sales_qualified?
    score += 25 if converted?

    # Source scoring
    score += case source
    when "demo_request", "contact_form"
      30
    when "content_download", "webinar"
      20
    when "organic_search", "referral"
      15
    when "social_media", "email"
      10
    else
      5
    end

    score
  end

  def assign_lead_grade
    score = calculate_lead_score

    case score
    when 80..Float::INFINITY
      "A+"
    when 70..79
      "A"
    when 60..69
      "B+"
    when 50..59
      "B"
    when 40..49
      "C+"
    when 30..39
      "C"
    when 20..29
      "D"
    else
      "F"
    end
  end

  # Time-based metrics
  def time_to_mql
    return nil unless mql_date.present?

    (mql_date - crm_created_at) / 1.hour if crm_created_at.present?
  end

  def time_to_sql
    return nil unless sql_date.present?

    base_time = mql_date.presence || crm_created_at
    return nil unless base_time.present?

    (sql_date - base_time) / 1.hour
  end

  def time_to_conversion
    return nil unless converted_at.present?

    base_time = sql_date.presence || mql_date.presence || crm_created_at
    return nil unless base_time.present?

    (converted_at - base_time) / 1.hour
  end

  # Attribution helpers
  def has_campaign_attribution?
    original_campaign.present? || first_touch_campaign_id.present?
  end

  def attribution_summary
    {
      original_source: original_source,
      original_medium: original_medium,
      original_campaign: original_campaign,
      first_touch_campaign: first_touch_campaign_id,
      last_touch_campaign: last_touch_campaign_id,
      utm_parameters: utm_parameters
    }.compact
  end

  # Lead progression tracking
  def lifecycle_progression_score
    stages = LIFECYCLE_STAGES
    current_index = stages.index(lifecycle_stage) || 0
    max_index = stages.length - 1

    return 0 if max_index == 0

    (current_index.to_f / max_index * 100).round(2)
  end

  def days_in_current_stage
    return 0 unless lifecycle_stage.present?

    stage_entry_date = case lifecycle_stage
    when "marketing_qualified_lead"
      mql_date
    when "sales_qualified_lead"
      sql_date
    when "customer"
      converted_at
    else
      crm_created_at
    end

    return 0 unless stage_entry_date.present?

    (Time.current - stage_entry_date) / 1.day
  end

  # Full name helper
  def full_name
    [ first_name, last_name ].compact.join(" ").presence || "Unknown"
  end

  # Contact information
  def primary_contact_info
    email.presence || phone.presence || "No contact info"
  end

  # Data quality score
  def data_completeness_score
    total_fields = 10
    completed_fields = 0

    completed_fields += 1 if first_name.present?
    completed_fields += 1 if last_name.present?
    completed_fields += 1 if email.present?
    completed_fields += 1 if phone.present?
    completed_fields += 1 if company.present?
    completed_fields += 1 if title.present?
    completed_fields += 1 if source.present?
    completed_fields += 1 if industry.present?
    completed_fields += 1 if annual_revenue.present?
    completed_fields += 1 if number_of_employees.present?

    (completed_fields.to_f / total_fields * 100).round(2)
  end

  # Sync status
  def sync_status
    return "never_synced" if last_synced_at.blank?
    return "recently_synced" if last_synced_at > 1.hour.ago
    return "synced" if last_synced_at > 1.day.ago

    "needs_sync"
  end

  def needs_sync?
    last_synced_at.blank? || last_synced_at < 1.day.ago
  end

  private

  def normalize_email
    return unless email.present?

    self.email = email.strip.downcase
  end

  def calculate_qualification_dates
    # Set MQL date if becoming marketing qualified
    if marketing_qualified_changed? && marketing_qualified? && mql_date.blank?
      self.mql_date = Time.current
    end

    # Set SQL date if becoming sales qualified
    if sales_qualified_changed? && sales_qualified? && sql_date.blank?
      self.sql_date = Time.current
    end

    # Update lead score and grade
    self.lead_score = calculate_lead_score.to_s
    self.lead_grade = assign_lead_grade
  end

  def track_lifecycle_progression
    return unless lifecycle_stage_before_last_save.present?

    # Log lifecycle stage changes for analytics
    Rails.logger.info "Lead #{id} progressed from #{lifecycle_stage_before_last_save} to #{lifecycle_stage}"

    # Trigger any lifecycle stage-specific actions
    case lifecycle_stage
    when "marketing_qualified_lead"
      mark_marketing_qualified! unless marketing_qualified?
    when "sales_qualified_lead"
      mark_sales_qualified! unless sales_qualified?
    when "customer"
      mark_converted! unless converted?
    end
  end
end
