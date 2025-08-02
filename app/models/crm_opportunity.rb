# frozen_string_literal: true

class CrmOpportunity < ApplicationRecord
  # Opportunity stages (common across platforms)
  OPPORTUNITY_STAGES = %w[
    prospecting
    qualification
    needs_analysis
    value_proposition
    id_decision_makers
    perception_analysis
    proposal_price_quote
    negotiation_review
    closed_won
    closed_lost
  ].freeze

  # Opportunity types
  OPPORTUNITY_TYPES = %w[
    new_business
    existing_business
    renewal
    upgrade
    cross_sell
    upsell
  ].freeze

  # Currency codes (ISO 4217)
  CURRENCIES = %w[USD EUR GBP JPY CAD AUD CHF CNY].freeze

  # Associations
  belongs_to :crm_integration
  belongs_to :brand
  has_many :crm_analytics, through: :crm_integration

  # Validations
  validates :crm_id, presence: true, uniqueness: { scope: :crm_integration_id }
  validates :name, presence: true, length: { maximum: 500 }
  validates :currency, inclusion: { in: CURRENCIES }, allow_blank: true
  validates :stage, inclusion: { in: OPPORTUNITY_STAGES }, allow_blank: true
  validates :type, inclusion: { in: OPPORTUNITY_TYPES }, allow_blank: true
  validates :amount, numericality: { greater_than_or_equal_to: 0 }, allow_blank: true
  validates :probability, numericality: { in: 0..100 }, allow_blank: true

  # Scopes
  scope :open, -> { where(is_closed: false) }
  scope :closed, -> { where(is_closed: true) }
  scope :won, -> { where(is_won: true) }
  scope :lost, -> { where(is_won: false, is_closed: true) }
  scope :by_stage, ->(stage) { where(stage: stage) }
  scope :by_owner, ->(owner_id) { where(owner_id: owner_id) }
  scope :by_pipeline, ->(pipeline_id) { where(pipeline_id: pipeline_id) }
  scope :closing_this_month, -> { where(close_date: Date.current.beginning_of_month..Date.current.end_of_month) }
  scope :closing_this_quarter, -> { where(close_date: Date.current.beginning_of_quarter..Date.current.end_of_quarter) }
  scope :recent, -> { where("created_at > ?", 30.days.ago) }
  scope :high_value, -> { where("amount > ?", 50000) }

  # Campaign attribution scopes
  scope :attributed_to_campaign, ->(campaign_id) { where(original_campaign: campaign_id) }
  scope :by_lead_source, ->(source) { where(lead_source: source) }

  # Callbacks
  before_save :calculate_pipeline_metrics
  before_save :determine_close_status
  after_update :track_stage_progression, if: :saved_change_to_stage?
  after_update :track_close_metrics, if: :saved_change_to_is_closed?

  # Opportunity status
  def open?
    !is_closed?
  end

  def closed?
    is_closed?
  end

  def won?
    is_closed? && is_won?
  end

  def lost?
    is_closed? && !is_won?
  end

  # Stage progression
  def stage_index
    OPPORTUNITY_STAGES.index(stage) || 0
  end

  def stage_progress_percentage
    return 0 if stage.blank?

    index = stage_index
    total_stages = OPPORTUNITY_STAGES.length - 1

    return 100 if stage == "closed_won"
    return 0 if stage == "closed_lost"

    (index.to_f / total_stages * 100).round(2)
  end

  def next_stage
    return nil if closed?

    current_index = stage_index
    next_index = current_index + 1

    return nil if next_index >= OPPORTUNITY_STAGES.length

    OPPORTUNITY_STAGES[next_index]
  end

  def previous_stage
    current_index = stage_index
    return nil if current_index <= 0

    OPPORTUNITY_STAGES[current_index - 1]
  end

  def advance_stage!
    next_stage_name = next_stage
    return false unless next_stage_name

    update!(stage: next_stage_name, stage_changed_at: Time.current)
  end

  # Pipeline velocity calculations
  def days_in_pipeline
    return 0 unless crm_created_at.present?

    end_date = closed? ? closed_at : Time.current
    ((end_date - crm_created_at) / 1.day).round
  end

  def days_in_current_stage
    return 0 unless stage_changed_at.present?

    ((Time.current - stage_changed_at) / 1.day).round
  end

  def average_stage_duration
    return 0 if total_days_in_pipeline.blank? || stage_index == 0

    total_days_in_pipeline.to_f / stage_index
  end

  def pipeline_velocity_score
    return 0 unless amount.present? && days_in_pipeline > 0

    # Velocity = Deal Value / Days in Pipeline
    (amount / days_in_pipeline).round(2)
  end

  def time_to_close_projection
    return nil if closed? || stage_index == 0

    remaining_stages = OPPORTUNITY_STAGES.length - stage_index - 1
    avg_duration = average_stage_duration

    return nil if avg_duration == 0

    (remaining_stages * avg_duration).round
  end

  # Financial calculations
  def weighted_amount
    return 0 unless amount.present? && probability.present?

    (amount * probability / 100).round(2)
  end

  def deal_size_category
    return "unknown" unless amount.present?

    case amount
    when 0...10_000
      "small"
    when 10_000...50_000
      "medium"
    when 50_000...250_000
      "large"
    else
      "enterprise"
    end
  end

  def revenue_potential_score
    return 0 unless amount.present?

    base_score = case deal_size_category
    when "small" then 25
    when "medium" then 50
    when "large" then 75
    when "enterprise" then 100
    else 0
    end

    # Adjust for probability
    probability_multiplier = (probability || 50) / 100.0
    (base_score * probability_multiplier).round(2)
  end

  # Attribution and source tracking
  def has_campaign_attribution?
    original_campaign.present? || first_touch_campaign_id.present?
  end

  def attribution_summary
    {
      lead_source: lead_source,
      original_source: original_source,
      original_medium: original_medium,
      original_campaign: original_campaign,
      first_touch_campaign: first_touch_campaign_id,
      last_touch_campaign: last_touch_campaign_id,
      utm_parameters: utm_parameters
    }.compact
  end

  # Lead source analysis
  def high_intent_source?
    %w[demo_request contact_form referral].include?(lead_source)
  end

  def digital_source?
    %w[organic_search paid_advertising social_media email content_download].include?(lead_source)
  end

  # Conversion metrics
  def calculate_conversion_probability
    score = 0

    # Stage-based scoring
    stage_scores = {
      "prospecting" => 10,
      "qualification" => 20,
      "needs_analysis" => 35,
      "value_proposition" => 50,
      "id_decision_makers" => 65,
      "perception_analysis" => 75,
      "proposal_price_quote" => 85,
      "negotiation_review" => 95
    }

    score += stage_scores[stage] || 0

    # Source quality scoring
    score += 15 if high_intent_source?
    score += 10 if has_campaign_attribution?

    # Deal characteristics
    score += 5 if amount.present? && amount > 25_000
    score += 10 if owner_id.present?

    # Time factor (deals that move quickly are more likely to close)
    if days_in_pipeline > 0
      velocity_factor = case days_in_pipeline
      when 0..30 then 10
      when 31..60 then 5
      when 61..90 then 0
      else -10
      end
      score += velocity_factor
    end

    [ score, 100 ].min
  end

  # Performance metrics
  def performance_score
    score = 0

    # Pipeline position
    score += stage_progress_percentage * 0.3

    # Deal value
    score += revenue_potential_score * 0.4

    # Pipeline velocity
    velocity_score = pipeline_velocity_score
    if velocity_score > 0
      velocity_points = [ velocity_score / 1000 * 10, 30 ].min  # Cap at 30 points
      score += velocity_points
    end

    score.round(2)
  end

  # Risk assessment
  def risk_factors
    risks = []

    risks << "stalled_in_stage" if days_in_current_stage > 30
    risks << "long_sales_cycle" if days_in_pipeline > 120
    risks << "low_probability" if probability.present? && probability < 25
    risks << "no_owner_assigned" if owner_id.blank?
    risks << "no_close_date" if close_date.blank?
    risks << "overdue" if close_date.present? && close_date < Date.current && !closed?

    risks
  end

  def risk_level
    risk_count = risk_factors.length

    case risk_count
    when 0..1 then "low"
    when 2..3 then "medium"
    else "high"
    end
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

  def calculate_pipeline_metrics
    # Update days in current stage if stage changed
    if stage_changed?
      self.stage_changed_at = Time.current
      self.previous_stage = stage_was if stage_was.present?
    end

    # Calculate total days in pipeline
    self.total_days_in_pipeline = days_in_pipeline if crm_created_at.present?

    # Update pipeline velocity score
    self.pipeline_velocity_score = pipeline_velocity_score if amount.present?

    # Update deal size score
    self.deal_size_score = revenue_potential_score
  end

  def determine_close_status
    # Auto-set close status based on stage
    case stage
    when "closed_won"
      self.is_closed = true
      self.is_won = true
      self.closed_at ||= Time.current
    when "closed_lost"
      self.is_closed = true
      self.is_won = false
      self.closed_at ||= Time.current
    end

    # Calculate days to close if closing
    if is_closed_changed? && is_closed? && crm_created_at.present?
      close_time = closed_at || Time.current
      self.days_to_close = ((close_time - crm_created_at) / 1.day).round
    end
  end

  def track_stage_progression
    return unless stage_before_last_save.present?

    Rails.logger.info "Opportunity #{id} progressed from #{stage_before_last_save} to #{stage}"

    # Update stage-specific metrics
    self.days_in_current_stage = 0  # Reset counter for new stage
  end

  def track_close_metrics
    return unless is_closed?

    Rails.logger.info "Opportunity #{id} closed - Won: #{is_won?}, Amount: #{amount}"

    # Update conversion rate if this came from a lead
    if lead_id.present?
      # Find and update the associated lead conversion status
      lead = crm_integration.crm_leads.find_by(crm_id: lead_id)
      lead&.mark_converted!(opportunity_id: crm_id) if is_won?
    end
  end
end
