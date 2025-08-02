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
  validate :validate_messaging_compliance, if: :should_validate_messaging_compliance?
  
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
    
    return no_brand_result unless journey.brand.messaging_framework.present?
    
    result = journey.brand.messaging_framework.validate_journey_step(self)
    
    {
      compliant: result[:approved_for_journey],
      score: result[:validation_score],
      summary: result[:approved_for_journey] ? "Content meets brand standards" : "Content violates brand compliance",
      violations: result[:violations] || [],
      suggestions: result[:suggestions] || [],
      step_context: build_compliance_context
    }
  end
  
  def brand_compliant?(threshold = nil)
    return true unless has_brand?
    
    return true unless journey.brand.messaging_framework.present?
    
    result = journey.brand.messaging_framework.validate_journey_step(self)
    threshold ||= 0.7
    
    result[:validation_score] >= threshold
  end
  
  def quick_compliance_score
    return 1.0 unless has_brand?
    
    return 1.0 unless journey.brand.messaging_framework.present?
    
    result = journey.brand.messaging_framework.validate_journey_step(self)
    result[:validation_score] || 1.0
  end
  
  def compliance_violations
    return [] unless has_brand?
    
    result = check_brand_compliance
    result[:violations] || []
  end
  
  def compliance_suggestions
    return [] unless has_brand?
    
    return [] unless journey.brand.messaging_framework.present?
    
    result = journey.brand.messaging_framework.validate_journey_step(self)
    result[:suggestions] || []
  end
  
  def auto_fix_compliance_issues
    return { fixed: false, content: compilable_content } unless has_brand?
    
    return { fixed: false, content: compilable_content } unless journey.brand.messaging_framework.present?
    
    # Simple auto-fix: remove banned words and replace with approved phrases
    messaging_framework = journey.brand.messaging_framework
    fixed_content = compilable_content.dup
    fixes_applied = []
    
    # Remove banned words
    if messaging_framework.banned_words.present?
      messaging_framework.banned_words.each do |banned_word|
        if fixed_content.downcase.include?(banned_word.downcase)
          fixed_content.gsub!(/\b#{Regexp.escape(banned_word)}\b/i, "")
          fixes_applied << "Removed banned word: #{banned_word}"
        end
      end
    end
    
    # Add approved phrases if available
    if messaging_framework.approved_phrases.present? && fixes_applied.any?
      approved_phrase = messaging_framework.approved_phrases.sample
      fixed_content += " #{approved_phrase}"
      fixes_applied << "Added approved phrase: #{approved_phrase}"
    end
    
    if fixes_applied.any?
      update_column(:description, fixed_content.strip)
      { fixed: true, content: fixed_content.strip, fixes: fixes_applied }
    else
      { fixed: false, content: compilable_content }
    end
  end
  
  def messaging_compliant?(message_text = nil)
    return true unless has_brand?
    
    return true unless journey.brand.messaging_framework.present?
    
    content_to_check = message_text || compilable_content
    result = journey.brand.messaging_framework.validate_message_realtime(content_to_check)
    
    result[:validation_score] >= 0.7
  end
  
  def applicable_brand_guidelines
    return [] unless has_brand?
    
    journey.brand.brand_guidelines.active.order(priority: :desc).limit(10)
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

  def should_validate_messaging_compliance?
    has_brand? && 
    journey.brand.messaging_framework.present? &&
    (config_changed? || description_changed? || name_changed?) && 
    !skip_brand_validation? &&
    compilable_content.present?
  end

  def validate_messaging_compliance
    return unless journey.brand.messaging_framework.present?
    
    result = journey.brand.messaging_framework.validate_journey_step(self)
    
    unless result[:approved_for_journey]
      violations = result[:violations] || []
      if violations.any?
        errors.add(:content, "violates brand compliance rules: #{violations.join(', ')}")
      else
        errors.add(:content, "does not meet brand compliance standards (score: #{result[:validation_score]})")
      end
    end
  end
  
  def should_check_compliance?
    has_brand? && 
    (will_save_change_to_description? || will_save_change_to_name?) &&
    !skip_compliance_check?
  end
  
  def validate_brand_compliance
    return unless compilable_content.present?
    
    # Use messaging framework for simpler validation instead of complex service
    return unless journey.brand.messaging_framework.present?
    
    result = journey.brand.messaging_framework.validate_journey_step(self)
    
    unless result[:approved_for_journey]
      violations = result[:violations] || []
      if violations.any?
        errors.add(:description, "Content violates brand guidelines: #{violations.join(', ')}")
      else
        errors.add(:description, "Content does not meet brand compliance standards (score: #{result[:validation_score]})")
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
    
    # Add config hash data if present
    if config.is_a?(Hash)
      content_parts << config['subject'] if config['subject'].present?
      content_parts << config['body'] if config['body'].present?
      content_parts << config['title'] if config['title'].present?
    end
    
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
