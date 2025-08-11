# Journey Templates Seeds
puts "Creating journey templates..."

# Lead Nurturing Template
lead_nurturing_template = JourneyTemplate.create!(
  name: "B2B Lead Nurturing Campaign",
  template_type: "lead_nurturing",
  category: "b2b",
  description: "A comprehensive lead nurturing journey for B2B prospects",
  author: "Marketing Team",
  tags: "b2b, leads, nurturing, email",
  template_data: {
    purpose: "Guide prospects through awareness to consideration phases",
    goals: "Increase lead qualification rate by 40% and improve lead-to-customer conversion",
    timing: "30-day nurturing sequence with multiple touchpoints",
    audience: "B2B prospects who have shown initial interest",
    stages: [
      {
        name: "Welcome & Introduction",
        stage_type: "Awareness",
        description: "Introduce company value proposition and build initial rapport",
        content: "Welcome email series with company introduction and value proposition",
        duration_days: 3,
        configuration: {
          channels: ["email", "social_media"],
          automation_triggers: ["form_submission", "content_download"],
          success_metrics: ["open_rate", "click_rate", "engagement_score"]
        }
      },
      {
        name: "Educational Content Delivery",
        stage_type: "Awareness",
        description: "Provide valuable industry insights and educational content",
        content: "Weekly educational content including whitepapers, case studies, and industry reports",
        duration_days: 14,
        configuration: {
          channels: ["email", "blog_post", "webinar"],
          automation_triggers: ["email_engagement", "website_visit"],
          success_metrics: ["content_downloads", "time_on_site", "repeat_visits"]
        }
      },
      {
        name: "Product Demonstration",
        stage_type: "Consideration", 
        description: "Showcase product capabilities and benefits",
        content: "Product demo videos, feature comparisons, and use case examples",
        duration_days: 7,
        configuration: {
          channels: ["email", "video", "webinar"],
          automation_triggers: ["demo_request", "pricing_page_visit"],
          success_metrics: ["demo_attendance", "trial_signups", "sales_qualified_leads"]
        }
      },
      {
        name: "Social Proof & Testimonials",
        stage_type: "Consideration",
        description: "Build trust through customer success stories",
        content: "Customer testimonials, case studies, and success metrics",
        duration_days: 5,
        configuration: {
          channels: ["email", "case_study", "video"],
          automation_triggers: ["demo_completion", "proposal_request"],
          success_metrics: ["engagement_rate", "referral_requests", "proposal_requests"]
        }
      },
      {
        name: "Sales Handoff",
        stage_type: "Conversion",
        description: "Facilitate smooth transition to sales team",
        content: "Personalized outreach and sales team introduction",
        duration_days: 1,
        configuration: {
          channels: ["email", "phone"],
          automation_triggers: ["high_lead_score", "multiple_touchpoints"],
          success_metrics: ["sales_meetings_booked", "proposals_sent", "deals_closed"]
        }
      }
    ]
  },
  variables: [
    {
      name: "company_name",
      type: "string",
      required: true,
      description: "Name of the prospect's company"
    },
    {
      name: "industry",
      type: "string", 
      required: true,
      description: "Industry vertical of the prospect"
    },
    {
      name: "lead_source",
      type: "string",
      required: false,
      description: "Source where the lead originated"
    },
    {
      name: "lead_score_threshold",
      type: "number",
      required: false,
      default_value: 75,
      description: "Minimum lead score for sales handoff"
    }
  ],
  metadata: {
    created_by: "system",
    industry_focus: ["technology", "manufacturing", "professional_services"],
    typical_conversion_rate: "15-20%",
    average_cycle_length: "30 days"
  }
)

# Customer Retention Template
customer_retention_template = JourneyTemplate.create!(
  name: "Customer Retention & Expansion",
  template_type: "customer_retention", 
  category: "saas",
  description: "Keep existing customers engaged and drive expansion opportunities",
  author: "Customer Success Team",
  tags: "retention, expansion, upsell, customer success",
  template_data: {
    purpose: "Maximize customer lifetime value through engagement and expansion",
    goals: "Reduce churn by 25% and increase expansion revenue by 30%",
    timing: "Ongoing quarterly engagement with expansion checkpoints",
    audience: "Existing customers with active subscriptions",
    stages: [
      {
        name: "Onboarding Excellence",
        stage_type: "Retention",
        description: "Ensure successful product adoption and early value realization",
        content: "Comprehensive onboarding sequence with training materials and success metrics",
        duration_days: 30,
        configuration: {
          channels: ["email", "webinar", "documentation"],
          automation_triggers: ["account_creation", "first_login"],
          success_metrics: ["feature_adoption", "time_to_first_value", "support_tickets"]
        }
      },
      {
        name: "Regular Health Checks",
        stage_type: "Retention",
        description: "Monitor account health and proactively address issues",
        content: "Monthly check-ins, usage reports, and optimization recommendations",
        duration_days: 60,
        configuration: {
          channels: ["email", "phone", "dashboard"],
          automation_triggers: ["usage_decline", "support_increase", "scheduled_intervals"],
          success_metrics: ["health_score", "feature_usage", "support_satisfaction"]
        }
      },
      {
        name: "Value Expansion Discovery", 
        stage_type: "Advocacy",
        description: "Identify opportunities for account expansion and additional value",
        content: "Business review sessions, ROI analysis, and growth planning",
        duration_days: 15,
        configuration: {
          channels: ["email", "video_call", "presentation"],
          automation_triggers: ["high_usage", "positive_feedback", "contract_renewal_window"],
          success_metrics: ["expansion_opportunities", "additional_users", "feature_requests"]
        }
      },
      {
        name: "Loyalty & Advocacy Program",
        stage_type: "Advocacy",
        description: "Convert satisfied customers into brand advocates",
        content: "Referral programs, case study opportunities, and community engagement",
        duration_days: 30,
        configuration: {
          channels: ["email", "community", "events"],
          automation_triggers: ["high_satisfaction", "long_tenure", "success_metrics_achieved"],
          success_metrics: ["referrals_generated", "testimonials_provided", "community_participation"]
        }
      }
    ]
  },
  variables: [
    {
      name: "subscription_tier",
      type: "string",
      required: true,
      description: "Current subscription level of the customer"
    },
    {
      name: "account_value",
      type: "number",
      required: true,
      description: "Annual contract value of the customer"
    },
    {
      name: "health_score",
      type: "number",
      required: false,
      description: "Current customer health score (0-100)"
    },
    {
      name: "renewal_date",
      type: "date",
      required: true,
      description: "Next contract renewal date"
    }
  ]
)

# Product Launch Template
product_launch_template = JourneyTemplate.create!(
  name: "Product Launch Campaign",
  template_type: "product_launch",
  category: "b2c",
  description: "Comprehensive product launch journey from pre-launch buzz to post-launch follow-up",
  author: "Product Marketing Team",
  tags: "product launch, announcement, marketing, awareness",
  template_data: {
    purpose: "Generate excitement and drive adoption for new product launches",
    goals: "Achieve 10,000 sign-ups in first month and 500 early adopter customers",
    timing: "8-week campaign from pre-launch through post-launch follow-up",
    audience: "Target customers and early technology adopters",
    stages: [
      {
        name: "Pre-Launch Teasers",
        stage_type: "Awareness",
        description: "Build anticipation with sneak peeks and early access opportunities",
        content: "Teaser content, behind-the-scenes videos, and early access sign-ups",
        duration_days: 14,
        configuration: {
          channels: ["social_media", "email", "blog_post"],
          automation_triggers: ["campaign_start"],
          success_metrics: ["sign_ups", "social_shares", "email_opens"]
        }
      },
      {
        name: "Official Launch Announcement",
        stage_type: "Awareness", 
        description: "Formal product announcement with full feature reveal",
        content: "Launch announcement, product demos, and media coverage",
        duration_days: 3,
        configuration: {
          channels: ["email", "social_media", "press_release", "webinar"],
          automation_triggers: ["launch_date"],
          success_metrics: ["website_traffic", "demo_requests", "media_mentions"]
        }
      },
      {
        name: "Feature Deep Dives",
        stage_type: "Consideration",
        description: "Detailed exploration of product capabilities and benefits",
        content: "Feature tutorials, use case examples, and comparison guides",
        duration_days: 10,
        configuration: {
          channels: ["blog_post", "video", "webinar", "email"],
          automation_triggers: ["demo_view", "feature_interest"],
          success_metrics: ["content_engagement", "trial_starts", "feature_adoption"]
        }
      },
      {
        name: "Early Adopter Incentives",
        stage_type: "Conversion",
        description: "Special offers and incentives for early customers",
        content: "Limited-time offers, exclusive bonuses, and early adopter perks",
        duration_days: 7,
        configuration: {
          channels: ["email", "landing_page", "social_media"],
          automation_triggers: ["trial_completion", "high_engagement"],
          success_metrics: ["conversion_rate", "revenue_generated", "customer_acquisition"]
        }
      },
      {
        name: "Post-Launch Optimization",
        stage_type: "Retention",
        description: "Gather feedback and optimize based on early user experiences",
        content: "Feedback surveys, success stories, and product improvements",
        duration_days: 21,
        configuration: {
          channels: ["email", "survey", "community"],
          automation_triggers: ["customer_onboard", "usage_milestones"],
          success_metrics: ["customer_satisfaction", "product_improvements", "retention_rate"]
        }
      }
    ]
  },
  variables: [
    {
      name: "product_name",
      type: "string", 
      required: true,
      description: "Name of the product being launched"
    },
    {
      name: "launch_date",
      type: "date",
      required: true,
      description: "Official product launch date"
    },
    {
      name: "target_signups",
      type: "number",
      required: false,
      default_value: 10000,
      description: "Target number of sign-ups for launch campaign"
    },
    {
      name: "early_adopter_discount",
      type: "number",
      required: false,
      default_value: 20,
      description: "Discount percentage for early adopters"
    }
  ]
)

# Publish all templates
[lead_nurturing_template, customer_retention_template, product_launch_template].each(&:publish!)

puts "Created #{JourneyTemplate.count} journey templates successfully!"