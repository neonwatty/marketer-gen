class Journey < ApplicationRecord
  belongs_to :user
  belongs_to :campaign, optional: true
  belongs_to :brand, optional: true
  has_one :persona, through: :campaign
  has_many :journey_steps, dependent: :destroy
  has_many :step_transitions, through: :journey_steps
  has_many :journey_executions, dependent: :destroy
  has_many :suggestion_feedbacks, dependent: :destroy
  has_many :journey_insights, dependent: :destroy
  has_many :journey_analytics, class_name: 'JourneyAnalytics', dependent: :destroy
  has_many :conversion_funnels, dependent: :destroy
  has_many :journey_metrics, dependent: :destroy
  has_many :ab_test_variants, dependent: :destroy
  has_many :ab_tests, through: :ab_test_variants
  
  STATUSES = %w[draft published archived].freeze
  CAMPAIGN_TYPES = %w[
    product_launch
    brand_awareness
    lead_generation
    customer_retention
    seasonal_promotion
    content_marketing
    email_nurture
    social_media
    event_promotion
    custom
  ].freeze
  
  STAGES = %w[awareness consideration conversion retention advocacy].freeze
  
  validates :name, presence: true
  validates :status, inclusion: { in: STATUSES }
  validates :campaign_type, inclusion: { in: CAMPAIGN_TYPES }, allow_blank: true
  
  scope :draft, -> { where(status: 'draft') }
  scope :published, -> { where(status: 'published') }
  scope :archived, -> { where(status: 'archived') }
  scope :active, -> { where(status: %w[draft published]) }
  
  def publish!
    update!(status: 'published', published_at: Time.current)
  end
  
  def archive!
    update!(status: 'archived', archived_at: Time.current)
  end
  
  def published?
    status == 'published'
  end
  
  def duplicate
    dup.tap do |new_journey|
      new_journey.name = "#{name} (Copy)"
      new_journey.status = 'draft'
      new_journey.published_at = nil
      new_journey.archived_at = nil
      new_journey.save!
      
      journey_steps.each do |step|
        new_step = step.dup
        new_step.journey = new_journey
        new_step.save!
      end
    end
  end
  
  def total_steps
    journey_steps.count
  end
  
  def steps_by_stage
    journey_steps.group(:stage).count
  end
  
  def to_json_export
    {
      name: name,
      description: description,
      campaign_type: campaign_type,
      target_audience: target_audience,
      goals: goals,
      metadata: metadata,
      settings: settings,
      steps: journey_steps.includes(:transitions_from, :transitions_to).map(&:to_json_export)
    }
  end
  
  # Analytics methods
  def current_analytics(period = 'daily')
    journey_analytics.order(period_start: :desc).first
  end
  
  def analytics_summary(days = 30)
    start_date = days.days.ago
    end_date = Time.current
    
    analytics = journey_analytics.where(period_start: start_date..end_date)
    
    return {} if analytics.empty?
    
    {
      total_executions: analytics.sum(:total_executions),
      completed_executions: analytics.sum(:completed_executions),
      abandoned_executions: analytics.sum(:abandoned_executions),
      average_conversion_rate: analytics.average(:conversion_rate)&.round(2) || 0,
      average_engagement_score: analytics.average(:engagement_score)&.round(2) || 0,
      period_days: days
    }
  end
  
  def funnel_performance(funnel_name = 'default', days = 7)
    start_date = days.days.ago
    end_date = Time.current
    
    ConversionFunnel.funnel_overview(id, funnel_name, start_date, end_date)
  end
  
  def compare_with_journey(other_journey_id, metrics = JourneyMetric::CORE_METRICS)
    JourneyMetric.compare_journey_metrics(id, other_journey_id, metrics)
  end
  
  def performance_trends(periods = 7)
    JourneyAnalytics.calculate_trends(id, periods)
  end
  
  def is_ab_test_variant?
    ab_test_variants.any?
  end
  
  def ab_test_status
    return 'not_in_test' unless is_ab_test_variant?
    
    test = ab_tests.active.first
    return 'no_active_test' unless test
    
    variant = ab_test_variants.joins(:ab_test).where(ab_tests: { id: test.id }).first
    return 'unknown_variant' unless variant
    
    {
      test_name: test.name,
      variant_name: variant.name,
      is_control: variant.is_control?,
      test_status: test.status,
      traffic_percentage: variant.traffic_percentage
    }
  end
  
  def persona_context
    return {} unless campaign&.persona
    
    campaign.persona.to_campaign_context
  end
  
  def campaign_context
    return {} unless campaign
    
    campaign.to_analytics_context
  end
  
  def calculate_metrics!(period = 'daily')
    JourneyMetric.calculate_and_store_metrics(self, period)
  end
  
  def create_conversion_funnel!(period_start = 1.week.ago, period_end = Time.current, funnel_name = 'default')
    ConversionFunnel.create_journey_funnel(self, period_start, period_end, funnel_name)
    ConversionFunnel.calculate_funnel_metrics(id, funnel_name, period_start, period_end)
  end
  
  def latest_performance_score
    latest_analytics = current_analytics
    return 0 unless latest_analytics
    
    # Weighted performance score
    conversion_weight = 0.4
    engagement_weight = 0.3
    completion_weight = 0.3
    
    (latest_analytics.conversion_rate * conversion_weight +
     latest_analytics.engagement_score * engagement_weight +
     (latest_analytics.completed_executions.to_f / [latest_analytics.total_executions, 1].max * 100) * completion_weight).round(1)
  end
  
  # Brand compliance analytics methods
  def brand_compliance_summary(days = 30)
    return {} unless brand_id.present?
    
    JourneyInsight.brand_compliance_summary(id, days)
  end
  
  def brand_compliance_by_step(days = 30)
    return {} unless brand_id.present?
    
    JourneyInsight.brand_compliance_by_step(id, days)
  end
  
  def brand_violations_breakdown(days = 30)
    return {} unless brand_id.present?
    
    JourneyInsight.brand_violations_breakdown(id, days)
  end
  
  def latest_brand_compliance_score
    return 1.0 unless brand_id.present?
    
    latest_compliance = journey_insights
                        .brand_compliance
                        .order(calculated_at: :desc)
                        .first
    
    latest_compliance&.data&.dig('score') || 1.0
  end
  
  def brand_compliance_trend(days = 30)
    return 'stable' unless brand_id.present?
    
    compliance_insights = journey_insights
                          .brand_compliance
                          .where('calculated_at >= ?', days.days.ago)
                          .order(calculated_at: :desc)
    
    return 'stable' if compliance_insights.count < 3
    
    scores = compliance_insights.map { |insight| insight.data['score'] }.compact
    JourneyInsight.calculate_score_trend(scores)
  end
  
  def overall_brand_health_score
    return 1.0 unless brand_id.present?
    
    compliance_summary = brand_compliance_summary(30)
    return 1.0 if compliance_summary.empty?
    
    # Calculate overall brand health based on multiple factors
    compliance_score = compliance_summary[:average_score] || 1.0
    compliance_rate = (compliance_summary[:compliance_rate] || 100) / 100.0
    violation_penalty = [compliance_summary[:total_violations] * 0.05, 0.5].min
    
    # Weighted brand health score
    health_score = (compliance_score * 0.6) + (compliance_rate * 0.4) - violation_penalty
    [health_score, 0.0].max.round(3)
  end
  
  def brand_compliance_alerts
    return [] unless brand_id.present?
    
    alerts = []
    summary = brand_compliance_summary(7)  # Last 7 days
    
    if summary.present?
      # Alert for low average score
      if summary[:average_score] < 0.7
        alerts << {
          type: 'low_compliance_score',
          severity: 'high',
          message: "Average brand compliance score is #{(summary[:average_score] * 100).round(1)}%",
          recommendation: 'Review content against brand guidelines'
        }
      end
      
      # Alert for declining trend
      if brand_compliance_trend(7) == 'declining'
        alerts << {
          type: 'declining_compliance',
          severity: 'medium',
          message: 'Brand compliance trend is declining',
          recommendation: 'Investigate recent content changes'
        }
      end
      
      # Alert for high violation count
      if summary[:total_violations] > 10
        alerts << {
          type: 'high_violations',
          severity: 'medium',
          message: "#{summary[:total_violations]} brand violations in the last 7 days",
          recommendation: 'Review and fix flagged content'
        }
      end
    end
    
    alerts
  end

  # Brand-compliant content generation
  def generate_brand_compliant_content(generation_request)
    return { success: false, error: "No brand associated with journey" } unless brand_id.present?
    return { success: false, error: "No messaging framework available" } unless brand.messaging_framework.present?
    
    # Generate base content using messaging framework
    messaging_framework = brand.messaging_framework
    
    # Create brand-compliant content based on request
    case generation_request[:content_type]
    when 'email'
      generate_brand_compliant_email(generation_request, messaging_framework)
    when 'blog_post'
      generate_brand_compliant_blog_post(generation_request, messaging_framework)
    when 'social_post'
      generate_brand_compliant_social_post(generation_request, messaging_framework)
    else
      generate_generic_brand_compliant_content(generation_request, messaging_framework)
    end
  end

  private

  def generate_brand_compliant_email(request, messaging_framework)
    # Professional email generation with brand compliance
    subject_templates = [
      "Important Update About Our Services",
      "Exclusive Insights for Our Valued Customers",
      "Enhancing Your Experience with Our Solutions"
    ]
    
    body_templates = [
      "We are pleased to inform you about our latest service enhancements. Our commitment to excellence drives us to deliver innovative solutions that provide measurable value to your organization.",
      "Thank you for being a valued customer. We continue to enhance our platform to better serve your needs and deliver the exceptional results you expect from our partnership.",
      "Our team is committed to providing you with the highest quality service. We have implemented new features designed to improve your experience and help you achieve your business objectives."
    ]
    
    # Apply brand-specific customization
    subject = customize_content_for_brand(subject_templates.sample, messaging_framework)
    body = customize_content_for_brand(body_templates.sample, messaging_framework)
    
    # Validate compliance
    compliance_score = messaging_framework.validate_message_realtime("#{subject} #{body}")[:validation_score]
    
    {
      success: true,
      content: {
        subject: subject,
        body: body
      },
      compliance_score: compliance_score,
      brand_alignment: calculate_brand_alignment(subject + " " + body, messaging_framework)
    }
  end

  def generate_brand_compliant_blog_post(request, messaging_framework)
    title = "Innovation in #{request[:audience] || 'Business'}: Delivering Excellence Through Strategic Solutions"
    content = "Our commitment to innovation and customer success drives everything we do. Through strategic partnerships and cutting-edge solutions, we deliver measurable results that help organizations achieve their most important objectives."
    
    title = customize_content_for_brand(title, messaging_framework)
    content = customize_content_for_brand(content, messaging_framework)
    
    compliance_score = messaging_framework.validate_message_realtime("#{title} #{content}")[:validation_score]
    
    {
      success: true,
      content: {
        title: title,
        body: content
      },
      compliance_score: compliance_score,
      brand_alignment: calculate_brand_alignment(title + " " + content, messaging_framework)
    }
  end

  def generate_brand_compliant_social_post(request, messaging_framework)
    templates = [
      "Committed to delivering excellence in every interaction. #Innovation #Excellence",
      "Strategic solutions that drive measurable results for our clients. #Results #Partnership",
      "Innovation meets reliability in our comprehensive platform. #Innovation #Reliability"
    ]
    
    content = customize_content_for_brand(templates.sample, messaging_framework)
    compliance_score = messaging_framework.validate_message_realtime(content)[:validation_score]
    
    {
      success: true,
      content: {
        body: content
      },
      compliance_score: compliance_score,
      brand_alignment: calculate_brand_alignment(content, messaging_framework)
    }
  end

  def generate_generic_brand_compliant_content(request, messaging_framework)
    content = "We are committed to delivering innovative solutions that provide exceptional value. Our professional approach ensures reliable results that help you achieve your objectives."
    content = customize_content_for_brand(content, messaging_framework)
    
    compliance_score = messaging_framework.validate_message_realtime(content)[:validation_score]
    
    {
      success: true,
      content: {
        body: content
      },
      compliance_score: compliance_score,
      brand_alignment: calculate_brand_alignment(content, messaging_framework)
    }
  end

  def customize_content_for_brand(content, messaging_framework)
    # Incorporate approved phrases if available
    if messaging_framework.approved_phrases.present?
      # Replace generic terms with approved phrases
      approved_phrase = messaging_framework.approved_phrases.sample
      content = content.gsub(/excellent|great|good/, approved_phrase) if approved_phrase
    end
    
    # Adjust tone based on brand attributes
    if messaging_framework.tone_attributes.present?
      tone = messaging_framework.tone_attributes
      
      if tone["formality"] == "formal"
        content = content.gsub(/we're/, "we are").gsub(/don't/, "do not")
      end
      
      if tone["style"] == "professional"
        content = content.gsub(/awesome|great/, "excellent").gsub(/amazing/, "exceptional")
      end
    end
    
    content
  end

  def calculate_brand_alignment(content, messaging_framework)
    validation = messaging_framework.validate_message_realtime(content)
    {
      score: validation[:validation_score],
      violations: validation[:rule_violations].count,
      suggestions_count: validation[:suggestions].count
    }
  end
end
