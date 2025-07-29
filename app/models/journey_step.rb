class JourneyStep < ApplicationRecord
  belongs_to :journey
  has_many :step_executions, dependent: :destroy
  has_many :transitions_from, class_name: 'StepTransition', foreign_key: 'from_step_id', dependent: :destroy
  has_many :transitions_to, class_name: 'StepTransition', foreign_key: 'to_step_id', dependent: :destroy
  has_many :next_steps, through: :transitions_from, source: :to_step
  has_many :previous_steps, through: :transitions_to, source: :from_step
  
  STEP_TYPES = %w[
    blog_post
    email_sequence
    social_media
    lead_magnet
    webinar
    case_study
    sales_call
    demo
    trial_offer
    onboarding
    newsletter
    feedback_survey
  ].freeze
  
  CONTENT_TYPES = %w[
    email
    blog_post
    social_post
    landing_page
    video
    webinar
    ebook
    case_study
    whitepaper
    infographic
    podcast
    advertisement
    survey
    demo
    consultation
  ].freeze
  
  CHANNELS = %w[
    email
    website
    facebook
    instagram
    twitter
    linkedin
    youtube
    google_ads
    display_ads
    sms
    push_notification
    direct_mail
    event
    sales_call
  ].freeze
  
  validates :name, presence: true
  validates :stage, inclusion: { in: Journey::STAGES }
  validates :position, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :content_type, inclusion: { in: CONTENT_TYPES }, allow_blank: true
  validates :channel, inclusion: { in: CHANNELS }, allow_blank: true
  validates :duration_days, numericality: { greater_than: 0 }, allow_blank: true
  
  # Brand compliance validations
  validate :validate_brand_compliance, if: :should_validate_brand_compliance?
  
  scope :by_position, -> { order(:position) }
  scope :by_stage, ->(stage) { where(stage: stage) }
  scope :entry_points, -> { where(is_entry_point: true) }
  scope :exit_points, -> { where(is_exit_point: true) }
  
  before_create :set_position
  after_destroy :reorder_positions
  
  # Brand compliance callbacks
  before_save :check_real_time_compliance, if: :should_check_compliance?
  after_update :broadcast_compliance_status, if: :saved_change_to_description?
  
  def move_to_position(new_position)
    return if new_position == position
    
    transaction do
      if new_position < position
        journey.journey_steps
          .where(position: new_position...position)
          .update_all('position = position + 1')
      else
        journey.journey_steps
          .where(position: (position + 1)..new_position)
          .update_all('position = position - 1')
      end
      
      update!(position: new_position)
    end
  end
  
  def add_transition_to(to_step, conditions = {})
    transition_type = conditions.present? ? 'conditional' : 'sequential'
    transitions_from.create!(
      to_step: to_step,
      conditions: conditions,
      transition_type: transition_type
    )
  end
  
  def remove_transition_to(to_step)
    transitions_from.where(to_step: to_step).destroy_all
  end
  
  def can_transition_to?(step)
    next_steps.include?(step)
  end
  
  def evaluate_conditions(context = {})
    return true if conditions.blank?
    
    conditions.all? do |key, value|
      case key
      when 'min_engagement_score'
        context['engagement_score'].to_i >= value.to_i
      when 'completed_action'
        context['completed_actions']&.include?(value)
      when 'time_since_last_action'
        context['time_since_last_action'].to_i >= value.to_i
      else
        true
      end
    end
  end
  
  def to_json_export
    {
      name: name,
      description: description,
      stage: stage,
      position: position,
      content_type: content_type,
      channel: channel,
      duration_days: duration_days,
      config: config,
      conditions: conditions,
      metadata: metadata,
      is_entry_point: is_entry_point,
      is_exit_point: is_exit_point,
      transitions: transitions_from.map { |t| { to: t.to_step.name, conditions: t.conditions } }
    }
  end
  
  # Brand compliance methods
  def check_brand_compliance(options = {})
    return no_brand_result unless has_brand?
    
    compliance_service = Journey::BrandComplianceService.new(
      journey: journey,
      step: self,
      content: compilable_content,
      context: build_compliance_context
    )
    
    compliance_service.check_compliance(options)
  end
  
  def brand_compliant?(threshold = nil)
    return true unless has_brand?
    
    compliance_service = Journey::BrandComplianceService.new(
      journey: journey,
      step: self,
      content: compilable_content,
      context: build_compliance_context
    )
    
    compliance_service.meets_minimum_compliance?(threshold)
  end
  
  def quick_compliance_score
    return 1.0 unless has_brand?
    
    compliance_service = Journey::BrandComplianceService.new(
      journey: journey,
      step: self,
      content: compilable_content,
      context: build_compliance_context
    )
    
    compliance_service.quick_score
  end
  
  def compliance_violations
    return [] unless has_brand?
    
    result = check_brand_compliance
    result[:violations] || []
  end
  
  def compliance_suggestions
    return [] unless has_brand?
    
    compliance_service = Journey::BrandComplianceService.new(
      journey: journey,
      step: self,
      content: compilable_content,
      context: build_compliance_context
    )
    
    recommendations = compliance_service.get_recommendations
    recommendations[:recommendations] || []
  end
  
  def auto_fix_compliance_issues
    return { fixed: false, content: compilable_content } unless has_brand?
    
    compliance_service = Journey::BrandComplianceService.new(
      journey: journey,
      step: self,
      content: compilable_content,
      context: build_compliance_context
    )
    
    fix_results = compliance_service.auto_fix_violations
    
    if fix_results[:fixed_content].present?
      # Update description with fixed content if auto-fix was successful
      update_column(:description, fix_results[:fixed_content])
      { fixed: true, content: fix_results[:fixed_content], fixes: fix_results[:fixes_applied] }
    else
      { fixed: false, content: compilable_content, available_fixes: fix_results[:fixes_available] }
    end
  end
  
  def messaging_compliant?(message_text = nil)
    return true unless has_brand?
    
    content_to_check = message_text || compilable_content
    
    compliance_service = Journey::BrandComplianceService.new(
      journey: journey,
      step: self,
      content: content_to_check,
      context: build_compliance_context
    )
    
    compliance_service.messaging_allowed?(content_to_check)
  end
  
  def applicable_brand_guidelines
    return [] unless has_brand?
    
    compliance_service = Journey::BrandComplianceService.new(
      journey: journey,
      step: self,
      content: compilable_content,
      context: build_compliance_context
    )
    
    compliance_service.applicable_brand_rules
  end
  
  def brand_context
    return {} unless has_brand?
    
    {
      brand_id: journey.brand.id,
      brand_name: journey.brand.name,
      industry: journey.brand.industry,
      has_messaging_framework: journey.brand.messaging_framework.present?,
      has_guidelines: journey.brand.brand_guidelines.active.any?,
      compliance_level: determine_compliance_level
    }
  end
  
  def latest_compliance_check
    journey.journey_insights
           .where(insights_type: 'brand_compliance')
           .where("data->>'step_id' = ?", id.to_s)
           .order(calculated_at: :desc)
           .first
  end
  
  def compliance_history(days = 30)
    journey.journey_insights
           .where(insights_type: 'brand_compliance')
           .where("data->>'step_id' = ?", id.to_s)
           .where('calculated_at >= ?', days.days.ago)
           .order(calculated_at: :desc)
  end
  
  private
  
  def set_position
    if position.nil? || position == 0
      max_position = journey.journey_steps.where.not(id: id).maximum(:position) || -1
      self.position = max_position + 1
    end
  end
  
  def reorder_positions
    journey.journey_steps.where('position > ?', position).update_all('position = position - 1')
  end
  
  # Brand compliance private methods
  def should_validate_brand_compliance?
    has_brand? && 
    (description_changed? || name_changed?) && 
    !skip_brand_validation? &&
    compilable_content.present?
  end
  
  def should_check_compliance?
    has_brand? && 
    (will_save_change_to_description? || will_save_change_to_name?) &&
    !skip_compliance_check?
  end
  
  def validate_brand_compliance
    return unless compilable_content.present?
    
    compliance_service = Journey::BrandComplianceService.new(
      journey: journey,
      step: self,
      content: compilable_content,
      context: build_compliance_context
    )
    
    # Quick validation check
    result = compliance_service.pre_generation_check(compilable_content)
    
    unless result[:allowed]
      violations = result[:violations] || []
      if violations.any?
        critical_violations = violations.select { |v| v[:severity] == 'critical' }
        if critical_violations.any?
          errors.add(:description, "Content violates critical brand guidelines: #{critical_violations.map { |v| v[:message] }.join(', ')}")
        else
          # Add warnings for non-critical violations
          errors.add(:description, "Content may violate brand guidelines: #{violations.first[:message]}") if violations.any?
        end
      end
    end
  end
  
  def check_real_time_compliance
    return unless compilable_content.present?
    
    # Store compliance check in metadata for later reference
    compliance_score = quick_compliance_score
    self.metadata ||= {}
    self.metadata['last_compliance_check'] = {
      score: compliance_score,
      checked_at: Time.current.iso8601,
      compliant: compliance_score >= 0.7
    }
    
    # Log warning for low compliance scores
    if compliance_score < 0.5
      Rails.logger.warn "Journey step #{id} has low brand compliance score: #{compliance_score}"
    end
  end
  
  def broadcast_compliance_status
    return unless has_brand?
    
    # Broadcast real-time compliance status update
    ActionCable.server.broadcast(
      "journey_step_compliance_#{id}",
      {
        event: 'compliance_updated',
        step_id: id,
        journey_id: journey.id,
        brand_id: journey.brand.id,
        compliance_score: quick_compliance_score,
        timestamp: Time.current
      }
    )
  rescue => e
    Rails.logger.error "Failed to broadcast compliance status: #{e.message}"
  end
  
  def has_brand?
    journey&.brand_id.present?
  end
  
  def compilable_content
    # Combine name and description for compliance checking
    content_parts = [name, description].compact
    content_parts.join(". ").strip
  end
  
  def build_compliance_context
    {
      step_id: id,
      step_name: name,
      content_type: content_type,
      channel: channel,
      stage: stage,
      position: position,
      is_entry_point: is_entry_point,
      is_exit_point: is_exit_point,
      journey_context: {
        campaign_type: journey.campaign_type,
        target_audience: journey.target_audience,
        goals: journey.goals
      }
    }
  end
  
  def determine_compliance_level
    # Determine compliance level based on step characteristics
    if is_entry_point? || stage == 'awareness'
      :strict  # Entry points need strict brand compliance
    elsif %w[conversion retention].include?(stage)
      :standard  # Important stages need standard compliance
    else
      :flexible  # Other stages can be more flexible
    end
  end
  
  def skip_brand_validation?
    # Allow skipping validation in certain contexts
    metadata&.dig('skip_brand_validation') == true ||
    Rails.env.test? && metadata&.dig('test_skip_validation') == true
  end
  
  def skip_compliance_check?
    # Allow skipping real-time compliance checks
    metadata&.dig('skip_compliance_check') == true ||
    Rails.env.test? && metadata&.dig('test_skip_compliance') == true
  end
  
  def no_brand_result
    {
      compliant: true,
      score: 1.0,
      summary: "No brand associated with journey",
      violations: [],
      suggestions: [],
      step_context: {
        step_id: id,
        no_brand: true
      }
    }
  end
end
