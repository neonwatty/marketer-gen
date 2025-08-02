class PlanTemplate < ApplicationRecord
  belongs_to :user
  has_many :campaign_plans, dependent: :nullify

  INDUSTRY_TYPES = %w[B2B E-commerce SaaS Events Healthcare Education Finance Technology Manufacturing].freeze
  TEMPLATE_TYPES = %w[strategic tactical operational seasonal campaign_specific].freeze

  validates :name, presence: true, uniqueness: { scope: :user_id }
  validates :industry_type, inclusion: { in: INDUSTRY_TYPES }
  validates :template_type, inclusion: { in: TEMPLATE_TYPES }
  validates :template_data, presence: true
  validates :description, presence: true

  # JSON serialization for template structure
  serialize :template_data, coder: JSON
  serialize :metadata, coder: JSON
  serialize :default_channels, coder: JSON
  serialize :messaging_themes, coder: JSON
  serialize :success_metrics_template, coder: JSON

  scope :for_industry, ->(industry) { where(industry_type: industry) }
  scope :by_type, ->(type) { where(template_type: type) }
  scope :active, -> { where(active: true) }
  scope :public_templates, -> { where(is_public: true) }
  scope :user_templates, ->(user_id) { where(user_id: user_id) }

  before_validation :set_defaults, on: :create

  def self.b2b_template
    find_or_create_by(name: "B2B Lead Generation Template", industry_type: "B2B") do |template|
      template.user = User.first # System template
      template.template_type = "strategic"
      template.description = "Comprehensive B2B lead generation campaign template"
      template.template_data = default_b2b_structure
      template.default_channels = [ "linkedin", "email", "content_marketing", "webinars" ]
      template.messaging_themes = [ "roi", "efficiency", "expertise", "trust" ]
      template.is_public = true
      template.active = true
    end
  end

  def self.ecommerce_template
    find_or_create_by(name: "E-commerce Conversion Template", industry_type: "E-commerce") do |template|
      template.user = User.first # System template
      template.template_type = "tactical"
      template.description = "High-conversion e-commerce campaign template"
      template.template_data = default_ecommerce_structure
      template.default_channels = [ "social_media", "paid_search", "email", "display_ads" ]
      template.messaging_themes = [ "urgency", "value", "social_proof", "benefits" ]
      template.is_public = true
      template.active = true
    end
  end

  def self.saas_template
    find_or_create_by(name: "SaaS Product Launch Template", industry_type: "SaaS") do |template|
      template.user = User.first # System template
      template.template_type = "strategic"
      template.description = "Product launch template for SaaS companies"
      template.template_data = default_saas_structure
      template.default_channels = [ "product_marketing", "content_marketing", "community", "partnerships" ]
      template.messaging_themes = [ "innovation", "productivity", "scalability", "user_experience" ]
      template.is_public = true
      template.active = true
    end
  end

  def self.events_template
    find_or_create_by(name: "Event Promotion Template", industry_type: "Events") do |template|
      template.user = User.first # System template
      template.template_type = "tactical"
      template.description = "Comprehensive event promotion and management template"
      template.template_data = default_events_structure
      template.default_channels = [ "event_marketing", "partnerships", "social_media", "email" ]
      template.messaging_themes = [ "networking", "learning", "exclusivity", "value" ]
      template.is_public = true
      template.active = true
    end
  end

  def apply_to_campaign(campaign)
    campaign_plan_data = template_data.deep_dup

    # Customize template data for specific campaign
    campaign_plan_data["campaign_name"] = campaign.name
    campaign_plan_data["campaign_type"] = campaign.campaign_type
    campaign_plan_data["target_audience"]["persona"] = campaign.persona.name if campaign.persona

    campaign_plan_data
  end

  def clone_for_user(target_user)
    new_template = self.dup
    new_template.user = target_user
    new_template.name = "#{name} (Copy)"
    new_template.is_public = false
    new_template.save!
    new_template
  end

  def usage_count
    campaign_plans.count
  end

  def activate!
    update!(active: true)
  end

  def deactivate!
    update!(active: false)
  end

  private

  def set_defaults
    self.active = true if active.nil?
    self.is_public = false if is_public.nil?
    self.metadata ||= {}
  end

  def self.default_b2b_structure
    {
      strategic_rationale: {
        market_analysis: "B2B market targeting decision makers",
        competitive_advantage: "Solution-focused approach",
        value_proposition: "ROI-driven messaging"
      },
      target_audience: {
        primary_persona: "Business decision makers",
        company_size: "Mid to enterprise",
        job_titles: [ "CTO", "VP Marketing", "Director" ]
      },
      messaging_framework: {
        primary_message: "Drive business efficiency",
        supporting_messages: [ "Proven ROI", "Expert support", "Scalable solution" ]
      },
      channel_strategy: [ "linkedin", "email", "content_marketing", "webinars" ],
      timeline_phases: [
        { phase: "awareness", duration_weeks: 4, activities: [ "content creation", "LinkedIn ads" ] },
        { phase: "consideration", duration_weeks: 6, activities: [ "webinars", "case studies" ] },
        { phase: "decision", duration_weeks: 4, activities: [ "demos", "sales calls" ] }
      ],
      success_metrics: {
        awareness: { reach: 50000, engagement_rate: 3.0 },
        consideration: { leads: 200, mql_conversion: 25 },
        decision: { sql: 50, close_rate: 15 }
      },
      sales_cycle_consideration: "6-12 month sales cycle typical",
      budget_considerations: "Higher cost per lead, higher lifetime value"
    }
  end

  def self.default_ecommerce_structure
    {
      strategic_rationale: {
        market_analysis: "Consumer e-commerce focused on conversion",
        competitive_advantage: "Optimized conversion funnel",
        value_proposition: "Value and convenience messaging"
      },
      target_audience: {
        primary_persona: "Online shoppers",
        demographics: "Age 25-55, mobile-first",
        behavior: "Price-conscious, comparison shoppers"
      },
      messaging_framework: {
        primary_message: "Best value for your needs",
        supporting_messages: [ "Free shipping", "Easy returns", "Customer reviews" ]
      },
      channel_strategy: [ "social_media", "paid_search", "email", "display_ads" ],
      timeline_phases: [
        { phase: "awareness", duration_weeks: 2, activities: [ "social ads", "influencer content" ] },
        { phase: "consideration", duration_weeks: 2, activities: [ "retargeting", "email nurture" ] },
        { phase: "conversion", duration_weeks: 1, activities: [ "special offers", "urgency messaging" ] }
      ],
      success_metrics: {
        awareness: { impressions: 1000000, reach: 200000 },
        consideration: { website_visits: 50000, cart_adds: 5000 },
        conversion: { purchases: 1000, revenue: 50000 }
      },
      conversion_optimization_tactics: "A/B testing, urgency messaging, social proof",
      seasonal_considerations: "Holiday seasons, back-to-school periods"
    }
  end

  def self.default_saas_structure
    {
      strategic_rationale: {
        market_analysis: "SaaS market focused on user adoption",
        competitive_advantage: "Product-led growth strategy",
        value_proposition: "Productivity and innovation messaging"
      },
      target_audience: {
        primary_persona: "Software users and buyers",
        company_size: "SMB to enterprise",
        use_cases: "Productivity, collaboration, automation"
      },
      messaging_framework: {
        primary_message: "Transform your workflow",
        supporting_messages: [ "Easy to use", "Powerful features", "Great support" ]
      },
      channel_strategy: [ "product_marketing", "content_marketing", "community", "partnerships" ],
      timeline_phases: [
        { phase: "pre_launch", duration_weeks: 4, activities: [ "beta testing", "content creation" ] },
        { phase: "launch", duration_weeks: 2, activities: [ "product hunt", "press release" ] },
        { phase: "growth", duration_weeks: 8, activities: [ "user onboarding", "feature promotion" ] }
      ],
      success_metrics: {
        pre_launch: { beta_signups: 500, feedback_score: 4.5 },
        launch: { signups: 2000, activation_rate: 30 },
        growth: { monthly_active_users: 5000, retention_rate: 80 }
      },
      user_onboarding_considerations: "Progressive disclosure, guided tours, success milestones",
      product_market_fit: "Continuous user feedback integration"
    }
  end

  def self.default_events_structure
    {
      strategic_rationale: {
        market_analysis: "Event-driven networking and learning",
        competitive_advantage: "Exclusive access and networking",
        value_proposition: "Learning and networking opportunities"
      },
      target_audience: {
        primary_persona: "Industry professionals",
        interests: "Professional development, networking",
        motivation: "Learning, career advancement, connections"
      },
      messaging_framework: {
        primary_message: "Connect, learn, grow",
        supporting_messages: [ "Expert speakers", "Networking opportunities", "Exclusive access" ]
      },
      channel_strategy: [ "event_marketing", "partnerships", "social_media", "email" ],
      timeline_phases: [
        { phase: "pre_event", duration_weeks: 8, activities: [ "speaker announcements", "early bird" ] },
        { phase: "during_event", duration_weeks: 1, activities: [ "live coverage", "networking" ] },
        { phase: "post_event", duration_weeks: 2, activities: [ "follow-up", "content sharing" ] }
      ],
      success_metrics: {
        pre_event: { registrations: 1000, early_bird: 400 },
        during_event: { attendance: 800, engagement_score: 8.5 },
        post_event: { follow_up_rate: 60, content_shares: 500 }
      },
      pre_during_post_event_phases: "Comprehensive event lifecycle management",
      networking_facilitation: "Structured networking opportunities"
    }
  end
end
