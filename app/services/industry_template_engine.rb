class IndustryTemplateEngine
  def initialize(campaign)
    @campaign = campaign
  end

  def generate_b2b_template
    {
      industry_type: "B2B",
      channels: ["linkedin", "email", "content_marketing", "webinars"],
      messaging_themes: ["roi", "efficiency", "expertise", "trust"],
      strategic_rationale: {
        market_analysis: "B2B market targeting business decision makers with longer sales cycles",
        competitive_advantage: "Solution-focused approach emphasizing ROI and business value",
        value_proposition: "ROI-driven messaging that addresses business pain points",
        target_market_characteristics: "Enterprise and mid-market companies seeking efficiency gains"
      },
      target_audience: {
        primary_persona: "Business decision makers and influencers",
        job_titles: ["CTO", "VP Marketing", "Director of Operations", "Business Owner"],
        company_size: "50-1000 employees",
        decision_criteria: ["ROI", "Scalability", "Reliability", "Support quality"],
        buying_process: "Committee-based with multiple stakeholders"
      },
      messaging_framework: {
        primary_message: "Drive measurable business results and efficiency",
        supporting_messages: [
          "Proven ROI with detailed case studies",
          "Expert implementation and ongoing support",
          "Scalable solution that grows with your business"
        ],
        proof_points: [
          "Customer success stories with quantified results",
          "Industry certifications and compliance",
          "Expert team with years of experience"
        ],
        objection_handling: {
          "Budget concerns" => "ROI analysis showing cost savings within 6 months",
          "Implementation complexity" => "Proven methodology with dedicated support team",
          "Integration challenges" => "Seamless integration with existing systems"
        }
      },
      channel_strategy: {
        linkedin: {
          strategy: "Target decision makers with thought leadership content",
          content_types: ["Industry insights", "Case studies", "Executive interviews"],
          success_metrics: { "connection_rate" => 15, "engagement_rate" => 4, "lead_quality" => "High" }
        },
        email: {
          strategy: "Nurture leads with educational content and case studies",
          content_types: ["Industry reports", "Webinar invitations", "Product demos"],
          success_metrics: { "open_rate" => 28, "click_rate" => 5, "conversion_rate" => 3 }
        },
        content_marketing: {
          strategy: "Establish thought leadership and educate target market",
          content_types: ["White papers", "Blog posts", "Industry reports"],
          success_metrics: { "organic_traffic" => 15000, "lead_generation" => 200, "engagement" => 6 }
        },
        webinars: {
          strategy: "Educate prospects and demonstrate expertise",
          content_types: ["Educational sessions", "Product demos", "Panel discussions"],
          success_metrics: { "registration_rate" => 12, "attendance_rate" => 65, "conversion_rate" => 8 }
        }
      },
      timeline_phases: [
        {
          phase: "Foundation & Research",
          duration_weeks: 3,
          objectives: ["Market research", "Competitive analysis", "Persona validation"],
          activities: ["Stakeholder interviews", "Market research", "Content audit"],
          deliverables: ["Research report", "Persona profiles", "Competitive analysis"]
        },
        {
          phase: "Content & Asset Development",
          duration_weeks: 4,
          objectives: ["Create educational content", "Develop sales assets", "Build campaign materials"],
          activities: ["Content creation", "Asset development", "Sales enablement"],
          deliverables: ["Content library", "Sales materials", "Campaign assets"]
        },
        {
          phase: "Launch & Awareness",
          duration_weeks: 6,
          objectives: ["Generate awareness", "Build thought leadership", "Attract prospects"],
          activities: ["Content distribution", "LinkedIn campaigns", "PR outreach"],
          deliverables: ["Published content", "Campaign launch", "Media coverage"]
        },
        {
          phase: "Engagement & Nurturing",
          duration_weeks: 8,
          objectives: ["Nurture leads", "Build relationships", "Educate prospects"],
          activities: ["Email nurturing", "Webinar series", "Sales enablement"],
          deliverables: ["Qualified leads", "Engaged prospects", "Sales pipeline"]
        },
        {
          phase: "Conversion & Optimization",
          duration_weeks: 6,
          objectives: ["Convert leads", "Optimize performance", "Scale results"],
          activities: ["Sales acceleration", "Campaign optimization", "Performance analysis"],
          deliverables: ["Closed deals", "Optimized campaigns", "Performance insights"]
        }
      ],
      success_metrics: {
        awareness: { reach: 75000, engagement_rate: 4.2, brand_recognition: 15 },
        consideration: { leads: 300, mql_rate: 35, content_engagement: 7 },
        conversion: { sql: 75, close_rate: 18, deal_size: 25000 },
        retention: { expansion_rate: 25, nps_score: 65, churn_rate: 5 }
      },
      sales_cycle_consideration: "6-18 month sales cycle with multiple touchpoints and stakeholders",
      budget_allocation: {
        content_creation: 25,
        digital_advertising: 30,
        events_webinars: 20,
        sales_enablement: 15,
        tools_technology: 10
      },
      kpis_specific_to_industry: [
        "Sales cycle length",
        "Deal size",
        "Customer lifetime value",
        "Cost per SQL",
        "Pipeline velocity"
      ]
    }
  end

  def generate_ecommerce_template
    {
      industry_type: "E-commerce",
      channels: ["social_media", "paid_search", "email", "display_ads"],
      messaging_themes: ["urgency", "value", "social_proof", "benefits"],
      strategic_rationale: {
        market_analysis: "Consumer e-commerce market focused on conversion optimization",
        competitive_advantage: "Optimized customer experience and value proposition",
        value_proposition: "Best value and convenience for online shoppers",
        target_market_characteristics: "Price-conscious consumers who research before buying"
      },
      target_audience: {
        primary_persona: "Online shoppers and deal seekers",
        demographics: "Age 25-55, household income $40k-$100k",
        shopping_behavior: "Research-driven, price-comparison, mobile-first",
        motivations: ["Save money", "Convenience", "Quality products", "Fast delivery"],
        pain_points: ["Shipping costs", "Return policies", "Product quality concerns"]
      },
      messaging_framework: {
        primary_message: "Get the best value with confidence and convenience",
        supporting_messages: [
          "Lowest prices with price match guarantee",
          "Free shipping and easy returns",
          "Thousands of satisfied customer reviews"
        ],
        value_propositions: [
          "Competitive pricing with regular deals",
          "Fast, reliable delivery",
          "Quality guarantee with easy returns"
        ],
        urgency_tactics: ["Limited time offers", "Flash sales", "Low stock alerts"]
      },
      channel_strategy: {
        social_media: {
          strategy: "Build community and showcase products through user-generated content",
          platforms: ["Instagram", "Facebook", "TikTok", "Pinterest"],
          content_types: ["Product showcases", "User reviews", "Behind-the-scenes"],
          success_metrics: { "engagement_rate" => 6, "reach" => 250000, "social_commerce_conversion" => 3 }
        },
        paid_search: {
          strategy: "Capture high-intent shoppers with targeted product ads",
          platforms: ["Google Ads", "Bing Ads"],
          content_types: ["Product ads", "Shopping campaigns", "Search ads"],
          success_metrics: { "ctr" => 4, "conversion_rate" => 8, "roas" => 400 }
        },
        email: {
          strategy: "Nurture customers with personalized offers and recommendations",
          content_types: ["Welcome series", "Abandoned cart", "Product recommendations"],
          success_metrics: { "open_rate" => 22, "click_rate" => 3.5, "revenue_per_email" => 12 }
        },
        display_ads: {
          strategy: "Retarget visitors and build awareness among lookalike audiences",
          platforms: ["Google Display", "Facebook", "Programmatic"],
          content_types: ["Product retargeting", "Brand awareness", "Lookalike campaigns"],
          success_metrics: { "ctr" => 0.8, "conversion_rate" => 2, "cpm" => 5 }
        }
      },
      timeline_phases: [
        {
          phase: "Pre-Launch Preparation",
          duration_weeks: 2,
          objectives: ["Set up tracking", "Create assets", "Prepare inventory"],
          activities: ["Analytics setup", "Creative development", "Inventory planning"],
          deliverables: ["Tracking implementation", "Campaign assets", "Inventory ready"]
        },
        {
          phase: "Soft Launch & Testing",
          duration_weeks: 1,
          objectives: ["Test campaigns", "Validate tracking", "Optimize performance"],
          activities: ["Campaign testing", "Performance monitoring", "Quick optimizations"],
          deliverables: ["Tested campaigns", "Performance baseline", "Initial optimizations"]
        },
        {
          phase: "Full Campaign Launch",
          duration_weeks: 3,
          objectives: ["Drive awareness", "Generate traffic", "Build momentum"],
          activities: ["Multi-channel launch", "PR and social", "Influencer outreach"],
          deliverables: ["Live campaigns", "Brand awareness", "Traffic growth"]
        },
        {
          phase: "Optimization & Scaling",
          duration_weeks: 4,
          objectives: ["Optimize performance", "Scale successful campaigns", "Improve ROI"],
          activities: ["A/B testing", "Bid optimization", "Creative iteration"],
          deliverables: ["Optimized campaigns", "Improved metrics", "Scaled spending"]
        },
        {
          phase: "Retention & Loyalty",
          duration_weeks: 2,
          objectives: ["Retain customers", "Drive repeat purchases", "Build loyalty"],
          activities: ["Email nurturing", "Loyalty programs", "Customer service"],
          deliverables: ["Retention campaigns", "Loyalty program", "Customer satisfaction"]
        }
      ],
      success_metrics: {
        awareness: { impressions: 2000000, reach: 500000, brand_searches: 25 },
        consideration: { website_visits: 100000, product_views: 250000, cart_adds: 8000 },
        conversion: { purchases: 2000, conversion_rate: 2.5, average_order_value: 75 },
        retention: { repeat_purchase_rate: 35, customer_lifetime_value: 200, retention_rate: 60 }
      },
      conversion_optimization_tactics: [
        "A/B testing product pages",
        "Cart abandonment emails",
        "Exit-intent popups",
        "Social proof widgets",
        "Urgency and scarcity messaging"
      ],
      budget_allocation: {
        paid_advertising: 50,
        content_creation: 15,
        email_marketing: 10,
        influencer_partnerships: 15,
        tools_analytics: 10
      },
      seasonal_considerations: {
        "Holiday seasons" => "Increased budget and promotional focus",
        "Back-to-school" => "Relevant product promotion and timing",
        "Summer/Winter sales" => "Seasonal inventory and messaging"
      }
    }
  end

  def generate_saas_template
    {
      industry_type: "SaaS",
      channels: ["product_marketing", "content_marketing", "community", "partnerships"],
      messaging_themes: ["innovation", "productivity", "scalability", "user_experience"],
      strategic_rationale: {
        market_analysis: "SaaS market focused on user adoption and product-led growth",
        competitive_advantage: "Superior user experience and product innovation",
        value_proposition: "Productivity and efficiency through innovative software solutions",
        target_market_characteristics: "Growing companies seeking digital transformation"
      },
      target_audience: {
        primary_persona: "Software users and technology buyers",
        job_titles: ["Product Manager", "Engineering Lead", "Operations Director", "CTO"],
        company_size: "10-500 employees",
        tech_savviness: "High technical proficiency",
        pain_points: ["Manual processes", "Tool fragmentation", "Scalability challenges"],
        motivations: ["Automate workflows", "Improve efficiency", "Scale operations"]
      },
      messaging_framework: {
        primary_message: "Transform your workflow with innovative, scalable solutions",
        supporting_messages: [
          "Intuitive design that your team will love",
          "Powerful features that scale with your business",
          "World-class support and customer success"
        ],
        value_propositions: [
          "Reduce manual work by 80%",
          "Scale operations without adding headcount",
          "Integrate seamlessly with existing tools"
        ],
        differentiation: [
          "Superior user experience",
          "Advanced automation capabilities",
          "Comprehensive integration ecosystem"
        ]
      },
      channel_strategy: {
        product_marketing: {
          strategy: "Product-led growth with freemium model and in-app messaging",
          tactics: ["Free trial optimization", "In-app onboarding", "Feature announcements"],
          success_metrics: { "trial_conversion" => 25, "activation_rate" => 60, "feature_adoption" => 40 }
        },
        content_marketing: {
          strategy: "Educational content that showcases product value and use cases",
          content_types: ["How-to guides", "Use case studies", "Industry insights"],
          success_metrics: { "organic_traffic" => 25000, "content_mql" => 150, "engagement" => 8 }
        },
        community: {
          strategy: "Build engaged user community for support, feedback, and advocacy",
          platforms: ["Slack community", "User forum", "Social groups"],
          success_metrics: { "community_size" => 5000, "engagement_rate" => 25, "support_resolution" => 80 }
        },
        partnerships: {
          strategy: "Strategic partnerships for integrations and co-marketing",
          types: ["Integration partners", "Reseller network", "Technology alliances"],
          success_metrics: { "partner_leads" => 100, "integration_usage" => 35, "partner_revenue" => 20 }
        }
      },
      timeline_phases: [
        {
          phase: "Pre-Launch Beta",
          duration_weeks: 6,
          objectives: ["Validate product-market fit", "Gather user feedback", "Refine positioning"],
          activities: ["Beta user recruitment", "Feedback collection", "Product iteration"],
          deliverables: ["Beta program", "User feedback", "Product improvements"]
        },
        {
          phase: "Public Launch",
          duration_weeks: 2,
          objectives: ["Generate buzz", "Drive sign-ups", "Establish market presence"],
          activities: ["Launch campaign", "PR outreach", "Community building"],
          deliverables: ["Launch execution", "Media coverage", "Initial user base"]
        },
        {
          phase: "Growth & Adoption",
          duration_weeks: 12,
          objectives: ["Scale user acquisition", "Improve onboarding", "Drive feature adoption"],
          activities: ["Growth experiments", "Onboarding optimization", "Feature marketing"],
          deliverables: ["Growth metrics", "Optimized onboarding", "Feature adoption"]
        },
        {
          phase: "Expansion & Retention",
          duration_weeks: 8,
          objectives: ["Drive account expansion", "Improve retention", "Build advocacy"],
          activities: ["Upsell campaigns", "Customer success", "Referral programs"],
          deliverables: ["Expansion revenue", "Retention improvement", "User advocacy"]
        }
      ],
      success_metrics: {
        awareness: { website_visitors: 50000, brand_searches: 15, social_mentions: 500 },
        consideration: { trial_signups: 2500, demo_requests: 300, content_downloads: 800 },
        conversion: { paid_conversions: 625, conversion_rate: 25, average_deal_size: 2400 },
        retention: { monthly_churn: 3, expansion_revenue: 120, nps_score: 55 }
      },
      user_onboarding_considerations: [
        "Progressive disclosure of features",
        "Interactive product tours",
        "Quick wins and success milestones",
        "Contextual help and support",
        "User behavior tracking and optimization"
      ],
      budget_allocation: {
        product_development: 30,
        content_marketing: 25,
        community_building: 15,
        partnerships: 15,
        paid_acquisition: 15
      },
      product_market_fit_indicators: [
        "40% of users active weekly",
        "High NPS score (50+)",
        "Organic growth rate >20%",
        "Low churn rate (<5%)",
        "Strong word-of-mouth referrals"
      ]
    }
  end

  def generate_events_template
    {
      industry_type: "Events",
      channels: ["event_marketing", "partnerships", "social_media", "email"],
      messaging_themes: ["networking", "learning", "exclusivity", "value"],
      strategic_rationale: {
        market_analysis: "Event industry focused on networking, learning, and professional development",
        competitive_advantage: "Unique networking opportunities and expert content",
        value_proposition: "Connect, learn, and grow with industry leaders and peers",
        target_market_characteristics: "Professionals seeking growth and networking opportunities"
      },
      target_audience: {
        primary_persona: "Industry professionals and decision makers",
        demographics: "Age 28-55, mid to senior level professionals",
        motivations: ["Professional development", "Networking", "Industry insights", "Career advancement"],
        pain_points: ["Limited networking opportunities", "Staying current", "Finding quality events"],
        event_preferences: ["High-quality speakers", "Relevant topics", "Good networking", "Convenient timing"]
      },
      messaging_framework: {
        primary_message: "Connect with industry leaders and transform your professional growth",
        supporting_messages: [
          "Learn from the best minds in the industry",
          "Network with like-minded professionals",
          "Gain exclusive insights and actionable strategies"
        ],
        value_propositions: [
          "Access to industry experts and thought leaders",
          "Structured networking with qualified professionals",
          "Practical insights you can implement immediately"
        ],
        social_proof: [
          "Previous attendee testimonials",
          "Speaker credentials and achievements",
          "Partner and sponsor endorsements"
        ]
      },
      channel_strategy: {
        event_marketing: {
          strategy: "Multi-touchpoint campaign across pre, during, and post-event phases",
          tactics: ["Speaker announcements", "Early bird promotions", "Partner promotion"],
          success_metrics: { "registration_rate" => 15, "attendance_rate" => 75, "satisfaction_score" => 4.5 }
        },
        partnerships: {
          strategy: "Leverage partner networks and sponsor relationships for promotion",
          types: ["Industry associations", "Media partners", "Corporate sponsors"],
          success_metrics: { "partner_registrations" => 30, "sponsor_satisfaction" => 90, "media_coverage" => 10 }
        },
        social_media: {
          strategy: "Build buzz and engagement through speaker and attendee content",
          platforms: ["LinkedIn", "Twitter", "Industry forums"],
          content_types: ["Speaker spotlights", "Event teasers", "Live updates"],
          success_metrics: { "social_registrations" => 25, "engagement_rate" => 8, "social_reach" => 100000 }
        },
        email: {
          strategy: "Nurture prospects through educational content and event updates",
          content_types: ["Speaker announcements", "Agenda reveals", "Networking previews"],
          success_metrics: { "open_rate" => 35, "click_rate" => 8, "email_conversions" => 12 }
        }
      },
      timeline_phases: [
        {
          phase: "Planning & Speaker Recruitment",
          duration_weeks: 12,
          objectives: ["Secure venue", "Recruit speakers", "Plan agenda"],
          activities: ["Venue booking", "Speaker outreach", "Agenda development"],
          deliverables: ["Confirmed venue", "Speaker lineup", "Event agenda"]
        },
        {
          phase: "Early Marketing & Partnerships",
          duration_weeks: 8,
          objectives: ["Build awareness", "Secure partnerships", "Launch early bird"],
          activities: ["Partner outreach", "Early bird campaign", "Content creation"],
          deliverables: ["Partnership agreements", "Early bird launch", "Marketing materials"]
        },
        {
          phase: "Registration Drive",
          duration_weeks: 6,
          objectives: ["Drive registrations", "Build momentum", "Engage prospects"],
          activities: ["Full marketing campaign", "Speaker promotion", "Social engagement"],
          deliverables: ["Registration targets", "Media coverage", "Social buzz"]
        },
        {
          phase: "Final Push & Preparation",
          duration_weeks: 2,
          objectives: ["Final registrations", "Event preparation", "Attendee engagement"],
          activities: ["Last-minute promotion", "Event setup", "Attendee communication"],
          deliverables: ["Final attendance", "Event readiness", "Attendee engagement"]
        },
        {
          phase: "Event Execution",
          duration_weeks: 1,
          objectives: ["Flawless execution", "Attendee satisfaction", "Content capture"],
          activities: ["Event management", "Live coverage", "Networking facilitation"],
          deliverables: ["Successful event", "Content assets", "Attendee satisfaction"]
        },
        {
          phase: "Post-Event Follow-up",
          duration_weeks: 4,
          objectives: ["Maintain engagement", "Gather feedback", "Plan next event"],
          activities: ["Follow-up campaigns", "Feedback collection", "Content distribution"],
          deliverables: ["Post-event engagement", "Event feedback", "Future planning"]
        }
      ],
      success_metrics: {
        awareness: { brand_mentions: 1000, website_traffic: 25000, social_reach: 200000 },
        consideration: { registrations: 800, early_bird: 320, waitlist: 100 },
        conversion: { attendance: 600, attendance_rate: 75, vip_upgrades: 50 },
        engagement: { satisfaction_score: 4.6, networking_connections: 2500, content_shares: 800 },
        retention: { repeat_attendance: 40, referral_rate: 35, follow_up_engagement: 60 }
      },
      pre_during_post_event_phases: {
        pre_event: {
          duration: "16 weeks before event",
          key_activities: ["Planning", "Marketing", "Registration"],
          success_metrics: ["Registration targets", "Partner engagement", "Social buzz"]
        },
        during_event: {
          duration: "Event day(s)",
          key_activities: ["Event execution", "Live coverage", "Networking"],
          success_metrics: ["Attendance rate", "Satisfaction scores", "Social engagement"]
        },
        post_event: {
          duration: "4 weeks after event",
          key_activities: ["Follow-up", "Content distribution", "Planning next event"],
          success_metrics: ["Follow-up engagement", "Content consumption", "Future event interest"]
        }
      },
      budget_allocation: {
        venue_logistics: 35,
        speaker_fees: 20,
        marketing_promotion: 25,
        technology_av: 10,
        catering_hospitality: 10
      },
      networking_facilitation: [
        "Structured networking sessions",
        "Mobile app for attendee connections",
        "Industry-specific meetups",
        "VIP networking opportunities",
        "Post-event online community"
      ]
    }
  end
end