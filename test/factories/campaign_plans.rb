FactoryBot.define do
  factory :campaign_plan do
    association :campaign
    association :user
    
    name { "Test Campaign Plan" }
    strategic_rationale { "Comprehensive strategic rationale with detailed market analysis and competitive positioning" }
    target_audience { "Enterprise decision makers, technical influencers, and key stakeholders in technology organizations" }
    messaging_framework { "Professional, results-driven messaging that emphasizes innovation, reliability, and measurable business outcomes" }
    channel_strategy { "Multi-channel approach leveraging email marketing, social media engagement, content marketing, paid search, and webinar programs" }
    timeline_phases { "12-week implementation with distinct phases: Research & Planning (2 weeks), Content Creation (3 weeks), Campaign Launch (1 week), Optimization (4 weeks), Analysis & Reporting (2 weeks)" }
    success_metrics { "Primary KPIs: 500 qualified leads (40% weight), $2M pipeline revenue (30% weight), 25% brand awareness increase (30% weight). Secondary KPIs: 15% email engagement, 50K website traffic, 1M social reach" }
    budget_allocation { "Total budget allocation across channels: Email (25%), Social Media (20%), Content Marketing (30%), Paid Search (15%), Display Ads (10%)" }
    creative_approach { "Modern, professional visual design with emphasis on data visualization, customer success stories, and thought leadership positioning" }
    market_analysis { "Comprehensive competitive analysis, market sizing, and opportunity assessment for enterprise technology segment" }
    status { "draft" }
    plan_type { "comprehensive" }
    version { 1.0 }
  end

  factory :plan_revision do
    association :campaign_plan
    association :user
    
    revision_number { 1.0 }
    change_summary { "Initial revision with strategic updates and optimizations" }
    plan_data { { "revision_type" => "strategic_update" } }
  end

  factory :plan_comment do
    association :campaign_plan
    association :user
    
    comment_text { "Strategic feedback on campaign approach and execution" }
    section { "strategic_rationale" }
    metadata { { "comment_type" => "strategic_feedback" } }
  end

  factory :plan_template do
    association :user
    
    name { "Standard Campaign Template" }
    description { "Template for standard marketing campaigns" }
    template_data do
      {
        "strategic_framework" => "Standard strategic approach",
        "default_channels" => ["email", "social_media", "content_marketing"],
        "default_metrics" => ["leads", "conversions", "engagement"]
      }
    end
    category { "marketing" }
    is_public { false }
  end
end