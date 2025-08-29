# frozen_string_literal: true

# Service for providing intelligent form defaults and suggestions based on user context
class SmartDefaultsService < ApplicationService
  def initialize(user, context = {})
    @user = user
    @context = context
  end

  def campaign_plan_defaults
    {
      suggested_names: generate_campaign_name_suggestions,
      suggested_descriptions: generate_description_suggestions,
      suggested_campaign_types: prioritized_campaign_types,
      suggested_objectives: prioritized_objectives,
      suggested_target_audiences: generate_target_audience_suggestions,
      suggested_budgets: generate_budget_suggestions,
      suggested_timelines: generate_timeline_suggestions,
      prefilled_brand_context: get_brand_context_prefill
    }
  end

  def journey_defaults
    {
      suggested_names: generate_journey_name_suggestions,
      suggested_target_audiences: generate_target_audience_suggestions,
      suggested_steps: generate_journey_step_suggestions
    }
  end

  def user_onboarding_progress
    {
      completed_steps: calculate_completed_onboarding_steps,
      next_suggested_action: determine_next_action,
      completion_percentage: calculate_completion_percentage,
      missing_essentials: identify_missing_essentials
    }
  end

  private

  def generate_campaign_name_suggestions
    current_month = Date.current.strftime("%B")
    current_year = Date.current.year
    
    base_suggestions = [
      "#{current_month} #{current_year} Marketing Campaign",
      "Q#{((Date.current.month - 1) / 3) + 1} #{current_year} Initiative",
      "Holiday Season Campaign #{current_year}",
      "Product Launch Campaign",
      "Brand Awareness Drive #{current_month}",
      "Lead Generation Campaign #{current_month}",
      "Customer Retention Initiative"
    ]

    # Personalize based on user's company if available
    if @user.company.present?
      company_suggestions = [
        "#{@user.company} #{current_month} Campaign",
        "#{@user.company} Growth Initiative #{current_year}"
      ]
      base_suggestions = company_suggestions + base_suggestions
    end

    # Add suggestions based on previous campaigns
    if recent_campaigns.any?
      pattern_suggestions = extract_naming_patterns
      base_suggestions = pattern_suggestions + base_suggestions
    end

    base_suggestions.uniq.first(5)
  end

  def generate_description_suggestions
    [
      "A comprehensive marketing campaign designed to achieve our strategic objectives",
      "Multi-channel campaign focused on driving engagement and conversions",
      "Strategic initiative to increase brand awareness and market presence",
      "Targeted campaign to generate qualified leads and drive sales growth",
      "Customer-centric campaign to improve retention and lifetime value"
    ]
  end

  def prioritized_campaign_types
    # Prioritize based on user's industry and previous campaigns
    user_patterns = recent_campaigns.group(:campaign_type).count
    
    if user_patterns.any?
      # Return types in order of user preference
      prioritized = user_patterns.keys.sort_by { |type| -user_patterns[type] }
      remaining = CampaignPlan::CAMPAIGN_TYPES - prioritized
      prioritized + remaining
    else
      # Default prioritization for new users
      %w[brand_awareness lead_generation product_launch sales_promotion customer_retention event_marketing]
    end
  end

  def prioritized_objectives
    # Similar logic for objectives
    user_patterns = recent_campaigns.group(:objective).count
    
    if user_patterns.any?
      prioritized = user_patterns.keys.sort_by { |obj| -user_patterns[obj] }
      remaining = CampaignPlan::OBJECTIVES - prioritized
      prioritized + remaining
    else
      %w[brand_awareness lead_generation sales_growth customer_acquisition customer_retention market_expansion]
    end
  end

  def generate_target_audience_suggestions
    suggestions = []
    
    # Based on previous campaigns
    previous_audiences = recent_campaigns.pluck(:target_audience).compact.uniq
    suggestions.concat(previous_audiences.first(3))
    
    # Industry-specific suggestions
    if @user.company.present?
      industry_suggestions = [
        "Small to medium-sized businesses",
        "Enterprise customers",
        "Young professionals (25-35)",
        "Decision-makers and executives",
        "Tech-savvy consumers",
        "Budget-conscious families"
      ]
      suggestions.concat(industry_suggestions)
    end

    # Generic helpful suggestions
    suggestions.concat([
      "Adults aged 25-45 with household income $50k+",
      "Business owners and entrepreneurs",
      "Marketing professionals and decision-makers",
      "Parents with children ages 5-17",
      "College graduates in urban areas"
    ])

    suggestions.uniq.first(8)
  end

  def generate_budget_suggestions
    previous_budgets = recent_campaigns.pluck(:budget_constraints).compact.uniq
    
    suggestions = previous_budgets.first(3) + [
      "$10,000 - $25,000 total campaign budget",
      "$25,000 - $50,000 for comprehensive multi-channel approach",
      "$5,000 - $10,000 for focused digital campaign",
      "Limited budget - focus on organic and low-cost channels",
      "$50,000+ for major product launch or rebrand"
    ]
    
    suggestions.uniq.first(5)
  end

  def generate_timeline_suggestions
    current_month = Date.current.strftime("%B")
    next_month = (Date.current + 1.month).strftime("%B")
    
    [
      "Launch within 2-3 weeks, run for 6-8 weeks",
      "#{current_month} planning, #{next_month} launch and execution",
      "Quick 2-week sprint campaign",
      "90-day comprehensive campaign rollout",
      "Launch by month-end, evaluate after 30 days"
    ]
  end

  def get_brand_context_prefill
    brand_identity = @user.active_brand_identity
    return nil unless brand_identity

    context_summary = []
    context_summary << "Brand Voice: #{brand_identity.brand_voice}" if brand_identity.brand_voice.present?
    context_summary << "Key Messages: #{brand_identity.messaging_framework}" if brand_identity.messaging_framework.present?
    context_summary << "Restrictions: #{brand_identity.restrictions}" if brand_identity.restrictions.present?
    
    context_summary.join("\n") if context_summary.any?
  end

  def calculate_completed_onboarding_steps
    completed = []
    completed << :profile_setup if profile_completed?
    completed << :brand_identity if brand_identity_created?
    completed << :first_campaign if first_campaign_created?
    completed << :first_journey if first_journey_created?
    completed << :content_generation if content_generated?
    completed
  end

  def determine_next_action
    return :complete_profile unless profile_completed?
    return :create_brand_identity unless brand_identity_created?
    return :create_first_campaign unless first_campaign_created?
    return :generate_campaign_plan if has_draft_campaigns?
    return :create_first_journey unless first_journey_created?
    return :generate_content unless content_generated?
    :explore_features
  end

  def calculate_completion_percentage
    total_steps = 5  # profile_setup, brand_identity, first_campaign, first_journey, content_generation
    completed_steps = calculate_completed_onboarding_steps.count
    (completed_steps.to_f / total_steps * 100).round
  end

  def identify_missing_essentials
    missing = []
    missing << { step: :profile, title: "Complete Profile", description: "Add your company and role information" } unless profile_completed?
    missing << { step: :brand_identity, title: "Create Brand Identity", description: "Set up your brand voice and guidelines" } unless brand_identity_created?
    missing << { step: :first_campaign, title: "Create First Campaign", description: "Build your first marketing campaign plan" } unless first_campaign_created?
    missing
  end

  def recent_campaigns
    @recent_campaigns ||= @user.campaign_plans.limit(10).order(created_at: :desc)
  end

  def extract_naming_patterns
    names = recent_campaigns.pluck(:name)
    # Extract common patterns and suggest variations
    # This is a simplified version - could be much more sophisticated
    patterns = names.map { |name| name.gsub(/\d{4}/, "#{Date.current.year}") }
    patterns.uniq.first(2)
  end

  def profile_completed?
    @user.company.present? && @user.role.present?
  end

  def brand_identity_created?
    @user.brand_identities.exists?
  end

  def first_campaign_created?
    @user.campaign_plans.exists?
  end

  def first_journey_created?
    @user.journeys.exists?
  end

  def content_generated?
    # Check if user has generated any content
    if @user.respond_to?(:generated_contents)
      @user.generated_contents.exists? || @user.campaign_plans.where.not(generated_summary: nil).exists?
    else
      @user.campaign_plans.where.not(generated_summary: nil).exists?
    end
  end

  def has_draft_campaigns?
    @user.campaign_plans.where(status: 'draft').exists?
  end

  def generate_journey_name_suggestions
    current_month = Date.current.strftime("%B")
    current_year = Date.current.year
    
    [
      "#{current_month} Customer Journey",
      "Product Discovery Journey #{current_year}",
      "Lead Nurturing Journey",
      "Customer Onboarding Flow",
      "Retention Journey #{current_month}",
      "Purchase Journey Mapping"
    ]
  end

  def generate_journey_step_suggestions
    [
      "Awareness Stage",
      "Consideration Phase", 
      "Decision Point",
      "Purchase Action",
      "Post-Purchase Follow-up",
      "Loyalty Building"
    ]
  end
end