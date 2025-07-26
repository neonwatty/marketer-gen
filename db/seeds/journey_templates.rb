# Journey Templates Seed Data
# This file creates pre-built journey templates for common marketing campaigns

templates = [
  {
    name: "B2B Lead Nurturing",
    description: "A comprehensive lead nurturing journey for B2B companies to convert prospects into customers",
    category: "b2b",
    campaign_type: "lead_generation",
    difficulty_level: "intermediate",
    estimated_duration_days: 21,
    template_data: {
      steps: [
        {
          id: "welcome-email",
          name: "Welcome Email",
          description: "Initial welcome email introducing your company and value proposition",
          stage: "awareness",
          content_type: "email",
          channel: "email",
          duration_days: 1,
          is_entry_point: true,
          config: {
            subject_line: "Welcome to [Company Name]",
            template_type: "welcome"
          }
        },
        {
          id: "educational-content",
          name: "Educational Content Series",
          description: "Share valuable industry insights and educational content",
          stage: "consideration",
          content_type: "blog_post",
          channel: "email",
          duration_days: 7,
          config: {
            content_theme: "industry_insights",
            frequency: "weekly"
          }
        },
        {
          id: "case-study",
          name: "Customer Success Case Study",
          description: "Showcase how your solution helped similar companies",
          stage: "consideration",
          content_type: "case_study",
          channel: "email",
          duration_days: 3,
          config: {
            case_study_type: "similar_industry"
          }
        },
        {
          id: "demo-invitation",
          name: "Product Demo Invitation",
          description: "Invite prospects to a personalized product demonstration",
          stage: "conversion",
          content_type: "email",
          channel: "email",
          duration_days: 5,
          config: {
            demo_type: "personalized",
            urgency_level: "medium"
          }
        },
        {
          id: "proposal-follow-up",
          name: "Proposal & Follow-up",
          description: "Send customized proposal and follow up for decision",
          stage: "conversion",
          content_type: "consultation",
          channel: "sales_call",
          duration_days: 5,
          is_exit_point: true,
          config: {
            proposal_type: "customized",
            follow_up_frequency: "3_days"
          }
        }
      ],
      transitions: [
        {
          from_step_id: "welcome-email",
          to_step_id: "educational-content",
          transition_type: "sequential",
          priority: 0
        },
        {
          from_step_id: "educational-content",
          to_step_id: "case-study",
          transition_type: "conditional",
          conditions: { "engagement_threshold" => 60 },
          priority: 0
        },
        {
          from_step_id: "educational-content",
          to_step_id: "demo-invitation",
          transition_type: "conditional",
          conditions: { "engagement_threshold" => 30 },
          priority: 1
        },
        {
          from_step_id: "case-study",
          to_step_id: "demo-invitation",
          transition_type: "sequential",
          priority: 0
        },
        {
          from_step_id: "demo-invitation",
          to_step_id: "proposal-follow-up",
          transition_type: "conditional",
          conditions: { "action_completed" => "demo_attended" },
          priority: 0
        }
      ]
    }
  },
  {
    name: "E-commerce Abandoned Cart Recovery",
    description: "Automated sequence to recover abandoned shopping carts and drive conversions",
    category: "ecommerce",
    campaign_type: "customer_retention",
    difficulty_level: "beginner",
    estimated_duration_days: 7,
    template_data: {
      steps: [
        {
          id: "cart-reminder",
          name: "Cart Reminder Email",
          description: "Gentle reminder about items left in shopping cart",
          stage: "conversion",
          content_type: "email",
          channel: "email",
          duration_days: 1,
          is_entry_point: true,
          config: {
            delay_hours: 2,
            include_cart_items: true
          }
        },
        {
          id: "incentive-offer",
          name: "Discount Incentive",
          description: "Offer a small discount to encourage completion",
          stage: "conversion",
          content_type: "email",
          channel: "email",
          duration_days: 2,
          config: {
            discount_percentage: 10,
            urgency_messaging: true
          }
        },
        {
          id: "social-proof",
          name: "Social Proof & Reviews",
          description: "Share customer reviews and social proof for cart items",
          stage: "conversion",
          content_type: "email",
          channel: "email",
          duration_days: 2,
          config: {
            include_reviews: true,
            social_proof_type: "customer_testimonials"
          }
        },
        {
          id: "final-urgency",
          name: "Final Urgency Call",
          description: "Last chance email with stronger incentive",
          stage: "conversion",
          content_type: "email",
          channel: "email",
          duration_days: 2,
          is_exit_point: true,
          config: {
            discount_percentage: 15,
            urgency_level: "high",
            scarcity_messaging: true
          }
        }
      ],
      transitions: [
        {
          from_step_id: "cart-reminder",
          to_step_id: "incentive-offer",
          transition_type: "conditional",
          conditions: { "action_completed" => "email_opened", "purchase_made" => false },
          priority: 0
        },
        {
          from_step_id: "incentive-offer",
          to_step_id: "social-proof",
          transition_type: "conditional",
          conditions: { "purchase_made" => false },
          priority: 0
        },
        {
          from_step_id: "social-proof",
          to_step_id: "final-urgency",
          transition_type: "conditional",
          conditions: { "purchase_made" => false },
          priority: 0
        }
      ]
    }
  },
  {
    name: "SaaS Trial Onboarding",
    description: "Guide new trial users through product features and drive conversion to paid plans",
    category: "saas",
    campaign_type: "email_nurture",
    difficulty_level: "intermediate",
    estimated_duration_days: 14,
    template_data: {
      steps: [
        {
          id: "welcome-setup",
          name: "Welcome & Setup Guide",
          description: "Welcome new trial users and guide them through initial setup",
          stage: "awareness",
          content_type: "email",
          channel: "email",
          duration_days: 1,
          is_entry_point: true,
          config: {
            setup_checklist: true,
            video_tutorial: true
          }
        },
        {
          id: "feature-demo-1",
          name: "Core Feature Demo",
          description: "Showcase the most important product features",
          stage: "consideration",
          content_type: "video",
          channel: "email",
          duration_days: 2,
          config: {
            feature_set: "core",
            interactive_demo: true
          }
        },
        {
          id: "use-case-examples",
          name: "Use Case Examples",
          description: "Show real-world use cases relevant to user's industry",
          stage: "consideration",
          content_type: "case_study",
          channel: "email",
          duration_days: 3,
          config: {
            personalized_by_industry: true
          }
        },
        {
          id: "feature-demo-2",
          name: "Advanced Features",
          description: "Introduce advanced features and integrations",
          stage: "consideration",
          content_type: "webinar",
          channel: "email",
          duration_days: 3,
          config: {
            feature_set: "advanced",
            live_demo: true
          }
        },
        {
          id: "success-milestone",
          name: "Success Milestone Celebration",
          description: "Celebrate user achievements and progress",
          stage: "consideration",
          content_type: "email",
          channel: "email",
          duration_days: 2,
          config: {
            milestone_tracking: true,
            achievement_badges: true
          }
        },
        {
          id: "conversion-offer",
          name: "Conversion Offer",
          description: "Present upgrade options with trial-specific incentives",
          stage: "conversion",
          content_type: "email",
          channel: "email",
          duration_days: 3,
          is_exit_point: true,
          config: {
            trial_discount: true,
            plan_comparison: true,
            urgency_messaging: true
          }
        }
      ],
      transitions: [
        {
          from_step_id: "welcome-setup",
          to_step_id: "feature-demo-1",
          transition_type: "sequential",
          priority: 0
        },
        {
          from_step_id: "feature-demo-1",
          to_step_id: "use-case-examples",
          transition_type: "conditional",
          conditions: { "engagement_threshold" => 40 },
          priority: 0
        },
        {
          from_step_id: "use-case-examples",
          to_step_id: "feature-demo-2",
          transition_type: "conditional",
          conditions: { "feature_usage" => "high" },
          priority: 0
        },
        {
          from_step_id: "use-case-examples",
          to_step_id: "success-milestone",
          transition_type: "conditional",
          conditions: { "feature_usage" => "medium" },
          priority: 1
        },
        {
          from_step_id: "feature-demo-2",
          to_step_id: "success-milestone",
          transition_type: "sequential",
          priority: 0
        },
        {
          from_step_id: "success-milestone",
          to_step_id: "conversion-offer",
          transition_type: "sequential",
          priority: 0
        }
      ]
    }
  },
  {
    name: "Nonprofit Donor Engagement",
    description: "Build lasting relationships with donors through storytelling and impact communication",
    category: "nonprofit",
    campaign_type: "customer_retention",
    difficulty_level: "beginner",
    estimated_duration_days: 30,
    template_data: {
      steps: [
        {
          id: "donation-thank-you",
          name: "Donation Thank You",
          description: "Immediate gratitude message acknowledging the donation",
          stage: "retention",
          content_type: "email",
          channel: "email",
          duration_days: 1,
          is_entry_point: true,
          config: {
            personalized_amount: true,
            immediate_send: true
          }
        },
        {
          id: "impact-story",
          name: "Impact Story",
          description: "Share a specific story showing how their donation makes a difference",
          stage: "retention",
          content_type: "blog_post",
          channel: "email",
          duration_days: 7,
          config: {
            story_type: "beneficiary_spotlight",
            include_photos: true
          }
        },
        {
          id: "behind-scenes",
          name: "Behind the Scenes",
          description: "Show the team and operations behind the mission",
          stage: "retention",
          content_type: "video",
          channel: "email",
          duration_days: 7,
          config: {
            content_type: "staff_spotlight",
            personal_touch: true
          }
        },
        {
          id: "impact-report",
          name: "Quarterly Impact Report",
          description: "Comprehensive report showing collective impact and achievements",
          stage: "retention",
          content_type: "ebook",
          channel: "email",
          duration_days: 7,
          config: {
            data_visualization: true,
            donor_recognition: true
          }
        },
        {
          id: "renewal-invitation",
          name: "Continued Support Invitation",
          description: "Invite for continued partnership and future giving opportunities",
          stage: "retention",
          content_type: "email",
          channel: "email",
          duration_days: 8,
          is_exit_point: true,
          config: {
            giving_options: true,
            recurring_donation_focus: true
          }
        }
      ],
      transitions: [
        {
          from_step_id: "donation-thank-you",
          to_step_id: "impact-story",
          transition_type: "sequential",
          priority: 0
        },
        {
          from_step_id: "impact-story",
          to_step_id: "behind-scenes",
          transition_type: "sequential",
          priority: 0
        },
        {
          from_step_id: "behind-scenes",
          to_step_id: "impact-report",
          transition_type: "sequential",
          priority: 0
        },
        {
          from_step_id: "impact-report",
          to_step_id: "renewal-invitation",
          transition_type: "sequential",
          priority: 0
        }
      ]
    }
  },
  {
    name: "Real Estate Lead Nurturing",
    description: "Guide potential home buyers through the property search and decision process",
    category: "real_estate",
    campaign_type: "lead_generation",
    difficulty_level: "intermediate",
    estimated_duration_days: 45,
    template_data: {
      steps: [
        {
          id: "property-alert-signup",
          name: "Property Alert Welcome",
          description: "Welcome new subscribers and set up property preferences",
          stage: "awareness",
          content_type: "email",
          channel: "email",
          duration_days: 1,
          is_entry_point: true,
          config: {
            preference_setup: true,
            search_criteria: true
          }
        },
        {
          id: "market-insights",
          name: "Local Market Insights",
          description: "Share valuable local market data and trends",
          stage: "consideration",
          content_type: "ebook",
          channel: "email",
          duration_days: 7,
          config: {
            market_data: true,
            neighborhood_focus: true
          }
        },
        {
          id: "buying-guide",
          name: "Home Buying Guide",
          description: "Comprehensive guide to the home buying process",
          stage: "consideration",
          content_type: "whitepaper",
          channel: "email",
          duration_days: 7,
          config: {
            step_by_step_process: true,
            local_regulations: true
          }
        },
        {
          id: "property-recommendations",
          name: "Curated Property Recommendations",
          description: "Send personalized property recommendations based on preferences",
          stage: "consideration",
          content_type: "email",
          channel: "email",
          duration_days: 14,
          config: {
            personalized_listings: true,
            frequency: "weekly"
          }
        },
        {
          id: "consultation-offer",
          name: "Free Consultation Offer",
          description: "Offer a free consultation to discuss specific needs",
          stage: "conversion",
          content_type: "consultation",
          channel: "sales_call",
          duration_days: 16,
          is_exit_point: true,
          config: {
            consultation_type: "needs_assessment",
            scheduling_integration: true
          }
        }
      ],
      transitions: [
        {
          from_step_id: "property-alert-signup",
          to_step_id: "market-insights",
          transition_type: "sequential",
          priority: 0
        },
        {
          from_step_id: "market-insights",
          to_step_id: "buying-guide",
          transition_type: "conditional",
          conditions: { "engagement_threshold" => 50 },
          priority: 0
        },
        {
          from_step_id: "market-insights",
          to_step_id: "property-recommendations",
          transition_type: "conditional",
          conditions: { "engagement_threshold" => 25 },
          priority: 1
        },
        {
          from_step_id: "buying-guide",
          to_step_id: "property-recommendations",
          transition_type: "sequential",
          priority: 0
        },
        {
          from_step_id: "property-recommendations",
          to_step_id: "consultation-offer",
          transition_type: "conditional",
          conditions: { "property_interest" => "high" },
          priority: 0
        }
      ]
    }
  }
]

puts "Creating journey templates..."

templates.each do |template_data|
  template = JourneyTemplate.find_or_create_by(name: template_data[:name]) do |t|
    t.description = template_data[:description]
    t.category = template_data[:category]
    t.campaign_type = template_data[:campaign_type]
    t.difficulty_level = template_data[:difficulty_level]
    t.estimated_duration_days = template_data[:estimated_duration_days]
    t.template_data = template_data[:template_data]
    t.is_active = true
    t.usage_count = 0
  end
  
  if template.persisted?
    puts "✓ Created template: #{template.name}"
  else
    puts "✗ Failed to create template: #{template_data[:name]} - #{template.errors.full_messages.join(', ')}"
  end
end

puts "Journey templates seeding completed!"