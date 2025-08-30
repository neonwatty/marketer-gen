# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).

# Create Users from test fixtures
puts "Creating Users..."

password_digest = BCrypt::Password.create("password")

users_data = [
  {
    email_address: "user1@example.com",
    password_digest: password_digest,
    role: "marketer",
    first_name: "Test",
    last_name: "User"
  },
  {
    email_address: "user_one@example.com",
    password_digest: password_digest,
    role: "marketer",
    first_name: "Test",
    last_name: "User"
  },
  {
    email_address: "user2@example.com",
    password_digest: password_digest,
    role: "team_member",
    first_name: "Second",
    last_name: "User"
  },
  {
    email_address: "user_two@example.com",
    password_digest: password_digest,
    role: "team_member",
    first_name: "Second",
    last_name: "User"
  },
  {
    email_address: "marketer@example.com",
    password_digest: password_digest,
    role: "marketer",
    first_name: "Mark",
    last_name: "Eter"
  },
  {
    email_address: "team@example.com",
    password_digest: password_digest,
    role: "team_member",
    first_name: "Team",
    last_name: "Member"
  },
  {
    email_address: "admin@example.com",
    password_digest: password_digest,
    role: "admin",
    first_name: "Admin",
    last_name: "User"
  },
  {
    email_address: "user3@example.com",
    password_digest: password_digest,
    role: "team_member",
    first_name: "Third",
    last_name: "User"
  }
]

users_data.each do |user_attrs|
  User.find_or_create_by!(email_address: user_attrs[:email_address]) do |user|
    user.password_digest = user_attrs[:password_digest]
    user.role = user_attrs[:role]
    user.first_name = user_attrs[:first_name]
    user.last_name = user_attrs[:last_name]
  end
end

puts "✓ Users created successfully!"

# Journey Templates for different campaign types
puts "Creating Journey Templates..."

# Product Launch Campaign Template
product_launch_data = {
  stages: ['awareness', 'consideration', 'conversion', 'retention'],
  metadata: {
    timeline: '12-16 weeks',
    key_metrics: ['reach', 'engagement', 'conversion_rate', 'retention_rate'],
    target_audience: 'New product prospects and existing customers',
    description: 'Comprehensive template for launching new products with multi-stage engagement'
  },
  steps: [
    # Awareness Stage
    {
      title: 'Pre-Launch Teaser Campaign',
      description: 'Build anticipation with sneak peeks and countdown content',
      step_type: 'social_post',
      channel: 'social_media',
      stage: 'awareness',
      content: {
        type: 'teaser_content',
        format: 'image_carousel',
        messaging: 'Coming soon - revolutionary new solution'
      },
      settings: {
        frequency: 'daily',
        duration: '2_weeks',
        platforms: ['instagram', 'linkedin', 'twitter']
      }
    },
    {
      title: 'PR & Media Outreach',
      description: 'Generate earned media coverage and thought leadership',
      step_type: 'content_piece',
      channel: 'website',
      stage: 'awareness',
      content: {
        type: 'press_release',
        format: 'article',
        messaging: 'Industry innovation and market disruption'
      },
      settings: {
        target_outlets: ['trade_publications', 'tech_blogs', 'industry_media']
      }
    },
    # Consideration Stage
    {
      title: 'Product Demo Video Series',
      description: 'Show product features and benefits through engaging demos',
      step_type: 'content_piece',
      channel: 'video',
      stage: 'consideration',
      content: {
        type: 'product_demo',
        format: 'video_series',
        messaging: 'See how it works and transforms workflows'
      },
      settings: {
        video_length: '3-5_minutes',
        series_count: 5,
        hosting_platform: 'youtube'
      }
    },
    {
      title: 'Customer Success Stories',
      description: 'Share beta user testimonials and case studies',
      step_type: 'content_piece',
      channel: 'website',
      stage: 'consideration',
      content: {
        type: 'testimonial',
        format: 'case_study',
        messaging: 'Real results from early adopters'
      },
      settings: {
        story_count: 3,
        include_metrics: true
      }
    },
    # Conversion Stage
    {
      title: 'Launch Week Email Campaign',
      description: 'Drive immediate action with launch offers and urgency',
      step_type: 'email',
      channel: 'email',
      stage: 'conversion',
      content: {
        type: 'promotional',
        format: 'email_sequence',
        messaging: 'Limited-time launch pricing and exclusive bonuses'
      },
      settings: {
        sequence_length: 5,
        discount_percentage: 20,
        time_limit: '7_days'
      }
    },
    {
      title: 'Landing Page Optimization',
      description: 'Convert visitors with compelling launch page experience',
      step_type: 'landing_page',
      channel: 'website',
      stage: 'conversion',
      content: {
        type: 'conversion_focused',
        format: 'single_page',
        messaging: 'Clear value proposition with social proof'
      },
      settings: {
        include_video: true,
        testimonial_count: 6,
        cta_variations: 3
      }
    },
    # Retention Stage
    {
      title: 'Onboarding Email Series',
      description: 'Ensure successful product adoption and usage',
      step_type: 'automation',
      channel: 'email',
      stage: 'retention',
      content: {
        type: 'educational',
        format: 'drip_sequence',
        messaging: 'Get the most value from your new solution'
      },
      settings: {
        trigger: 'post_purchase',
        sequence_length: 7,
        interval: 'every_2_days'
      }
    },
    {
      title: 'Customer Support Resources',
      description: 'Provide comprehensive help documentation and support',
      step_type: 'content_piece',
      channel: 'website',
      stage: 'retention',
      content: {
        type: 'educational',
        format: 'knowledge_base',
        messaging: 'Everything you need for success'
      },
      settings: {
        include_video_tutorials: true,
        faq_sections: 5,
        live_chat_enabled: true
      }
    }
  ]
}

JourneyTemplate.find_or_create_by!(
  name: 'Product Launch Campaign',
  campaign_type: 'awareness'
) do |template|
  template.description = 'Comprehensive template for launching new products with awareness building, consideration nurturing, conversion optimization, and retention focus'
  template.template_data = product_launch_data
  template.is_default = true
  template.category = 'acquisition'
  template.industry = 'general'
  template.complexity_level = 'intermediate'
  template.prerequisites = 'Product development completed, marketing assets ready, basic marketing team in place'
end

# Lead Generation Campaign Template
lead_generation_data = {
  stages: ['awareness', 'consideration', 'conversion', 'retention'],
  metadata: {
    timeline: '8-12 weeks',
    key_metrics: ['lead_quality', 'conversion_rate', 'cost_per_lead', 'nurture_engagement'],
    target_audience: 'B2B prospects and decision makers',
    description: 'Systematic approach to generating and nurturing qualified leads'
  },
  steps: [
    # Awareness Stage
    {
      title: 'SEO Content Marketing',
      description: 'Create valuable content to attract organic search traffic',
      step_type: 'content_piece',
      channel: 'blog',
      stage: 'awareness',
      content: {
        type: 'educational',
        format: 'blog_posts',
        messaging: 'Solve problems and establish thought leadership'
      },
      settings: {
        publish_frequency: 'weekly',
        target_keywords: 10,
        content_length: '1500-2000_words'
      }
    },
    {
      title: 'Social Media Thought Leadership',
      description: 'Share insights and engage with industry communities',
      step_type: 'social_post',
      channel: 'social_media',
      stage: 'awareness',
      content: {
        type: 'thought_leadership',
        format: 'mixed_content',
        messaging: 'Industry insights and expert commentary'
      },
      settings: {
        platforms: ['linkedin', 'twitter'],
        post_frequency: 'daily',
        engagement_strategy: 'community_building'
      }
    },
    # Consideration Stage
    {
      title: 'Educational Webinar Series',
      description: 'Deliver in-depth expertise to build trust and capture leads',
      step_type: 'webinar',
      channel: 'webinar',
      stage: 'consideration',
      content: {
        type: 'educational',
        format: 'live_presentation',
        messaging: 'Deep expertise and actionable insights'
      },
      settings: {
        series_length: 4,
        duration: '45_minutes',
        registration_required: true,
        follow_up_sequence: true
      }
    },
    {
      title: 'Gated Whitepaper Content',
      description: 'Offer valuable research and insights in exchange for contact info',
      step_type: 'content_piece',
      channel: 'website',
      stage: 'consideration',
      content: {
        type: 'research',
        format: 'whitepaper',
        messaging: 'Exclusive industry research and best practices'
      },
      settings: {
        gate_required: true,
        form_fields: ['name', 'email', 'company', 'role'],
        download_tracking: true
      }
    },
    # Conversion Stage
    {
      title: 'High-Converting Landing Pages',
      description: 'Create focused pages for each lead magnet and offer',
      step_type: 'landing_page',
      channel: 'website',
      stage: 'conversion',
      content: {
        type: 'conversion_focused',
        format: 'single_page',
        messaging: 'Clear value exchange and benefit-focused copy'
      },
      settings: {
        variant_count: 3,
        form_optimization: true,
        social_proof_included: true
      }
    },
    {
      title: 'Lead Qualification Forms',
      description: 'Capture lead information with progressive profiling',
      step_type: 'automation',
      channel: 'website',
      stage: 'conversion',
      content: {
        type: 'data_capture',
        format: 'multi_step_form',
        messaging: 'Personalized consultation and solution matching'
      },
      settings: {
        progressive_profiling: true,
        lead_scoring: true,
        crm_integration: true
      }
    },
    # Retention Stage
    {
      title: 'Lead Nurture Email Sequence',
      description: 'Maintain engagement and move leads through the sales funnel',
      step_type: 'automation',
      channel: 'email',
      stage: 'retention',
      content: {
        type: 'nurture',
        format: 'drip_sequence',
        messaging: 'Continued value delivery and trust building'
      },
      settings: {
        sequence_length: 10,
        send_frequency: 'weekly',
        behavioral_triggers: true,
        personalization: 'high'
      }
    },
    {
      title: 'Sales Follow-up Coordination',
      description: 'Coordinate with sales team for qualified lead handoff',
      step_type: 'automation',
      channel: 'email',
      stage: 'retention',
      content: {
        type: 'sales_enablement',
        format: 'personalized_outreach',
        messaging: 'Warm introduction and next steps'
      },
      settings: {
        lead_scoring_threshold: 75,
        sales_notification: true,
        meeting_scheduling: true
      }
    }
  ]
}

JourneyTemplate.find_or_create_by!(
  name: 'Lead Generation Campaign',
  campaign_type: 'consideration'
) do |template|
  template.description = 'Systematic approach to generating and nurturing qualified leads through content marketing, webinars, and automated nurture sequences'
  template.template_data = lead_generation_data
  template.is_default = true
  template.category = 'acquisition'
  template.industry = 'b2b'
  template.complexity_level = 'intermediate'
  template.prerequisites = 'Content creation capability, CRM system, email marketing platform, basic SEO knowledge'
end

# Re-Engagement Campaign Template
re_engagement_data = {
  stages: ['awareness', 'consideration', 'conversion', 'retention'],
  metadata: {
    timeline: '6-8 weeks',
    key_metrics: ['reactivation_rate', 'engagement_lift', 'churn_reduction', 'ltv_recovery'],
    target_audience: 'Lapsed customers and inactive subscribers',
    description: 'Win back inactive customers and rebuild engagement'
  },
  steps: [
    # Awareness Stage
    {
      title: 'Win-Back Email Campaign',
      description: 'Reconnect with lapsed customers using personalized messaging',
      step_type: 'email',
      channel: 'email',
      stage: 'awareness',
      content: {
        type: 'reactivation',
        format: 'personalized_email',
        messaging: 'We miss you - discover what you\'ve been missing'
      },
      settings: {
        personalization: 'high',
        send_time_optimization: true,
        subject_line_testing: true
      }
    },
    {
      title: 'Customer Feedback Survey',
      description: 'Understand why customers became inactive and what would bring them back',
      step_type: 'automation',
      channel: 'email',
      stage: 'awareness',
      content: {
        type: 'feedback',
        format: 'survey',
        messaging: 'Help us improve - your feedback matters'
      },
      settings: {
        survey_length: 'short',
        incentive_offered: true,
        response_tracking: true
      }
    },
    # Consideration Stage
    {
      title: 'Personalized Special Offers',
      description: 'Provide targeted incentives based on previous behavior',
      step_type: 'email',
      channel: 'email',
      stage: 'consideration',
      content: {
        type: 'promotional',
        format: 'personalized_offer',
        messaging: 'Exclusive comeback offer just for you'
      },
      settings: {
        behavior_based_targeting: true,
        dynamic_discount: true,
        offer_expiration: '7_days'
      }
    },
    {
      title: 'Product Update Highlights',
      description: 'Showcase new features and improvements since they were last active',
      step_type: 'content_piece',
      channel: 'email',
      stage: 'consideration',
      content: {
        type: 'product_update',
        format: 'feature_showcase',
        messaging: 'See what\'s new and improved'
      },
      settings: {
        visual_content: true,
        interactive_elements: true,
        benefit_focused: true
      }
    },
    # Conversion Stage
    {
      title: 'Limited-Time Incentive Campaign',
      description: 'Create urgency with time-sensitive offers and bonuses',
      step_type: 'email',
      channel: 'email',
      stage: 'conversion',
      content: {
        type: 'urgent_offer',
        format: 'countdown_campaign',
        messaging: 'Last chance - exclusive reactivation bonus'
      },
      settings: {
        countdown_timer: true,
        bonus_value: 'high',
        scarcity_messaging: true
      }
    },
    {
      title: 'Simplified Return Process',
      description: 'Remove friction and make it easy to re-engage',
      step_type: 'landing_page',
      channel: 'website',
      stage: 'conversion',
      content: {
        type: 'reactivation',
        format: 'streamlined_page',
        messaging: 'Welcome back - pick up where you left off'
      },
      settings: {
        one_click_reactivation: true,
        account_restoration: true,
        immediate_access: true
      }
    },
    # Retention Stage
    {
      title: 'Onboarding Refresh Series',
      description: 'Re-introduce features and best practices to ensure success',
      step_type: 'automation',
      channel: 'email',
      stage: 'retention',
      content: {
        type: 're_onboarding',
        format: 'educational_sequence',
        messaging: 'Get the most from your return'
      },
      settings: {
        sequence_length: 5,
        feature_focused: true,
        success_metrics: true
      }
    },
    {
      title: 'Loyalty Program Enrollment',
      description: 'Provide ongoing value and incentives to prevent future churn',
      step_type: 'automation',
      channel: 'email',
      stage: 'retention',
      content: {
        type: 'loyalty',
        format: 'program_invitation',
        messaging: 'Exclusive benefits for valued customers'
      },
      settings: {
        tier_based_rewards: true,
        points_system: true,
        exclusive_access: true
      }
    }
  ]
}

JourneyTemplate.find_or_create_by!(
  name: 'Re-Engagement Campaign',
  campaign_type: 'retention'
) do |template|
  template.description = 'Win back inactive customers and rebuild engagement through personalized outreach, special offers, and improved onboarding'
  template.template_data = re_engagement_data
  template.is_default = true
  template.category = 'retention'
  template.industry = 'general'
  template.complexity_level = 'beginner'
  template.prerequisites = 'Customer database with activity tracking, email marketing platform'
end

# Brand Awareness Campaign Template
brand_awareness_data = {
  stages: ['awareness', 'consideration', 'conversion', 'retention'],
  metadata: {
    timeline: '12-24 weeks',
    key_metrics: ['brand_recall', 'share_of_voice', 'sentiment_score', 'reach_frequency'],
    target_audience: 'Broad market audience and brand prospects',
    description: 'Build brand recognition and preference through storytelling and community engagement'
  },
  steps: [
    # Awareness Stage
    {
      title: 'Social Media Brand Campaign',
      description: 'Create consistent brand presence across social platforms',
      step_type: 'social_post',
      channel: 'social_media',
      stage: 'awareness',
      content: {
        type: 'brand_content',
        format: 'mixed_media',
        messaging: 'Authentic brand story and values'
      },
      settings: {
        content_pillars: ['brand_story', 'behind_scenes', 'values', 'community'],
        posting_frequency: 'daily',
        visual_consistency: true
      }
    },
    {
      title: 'Influencer Partnership Program',
      description: 'Collaborate with relevant influencers to expand brand reach',
      step_type: 'social_post',
      channel: 'social_media',
      stage: 'awareness',
      content: {
        type: 'influencer_content',
        format: 'collaborative_posts',
        messaging: 'Authentic endorsements and brand integration'
      },
      settings: {
        influencer_tier: 'micro_macro_mix',
        campaign_type: 'brand_awareness',
        content_rights: 'repurposing_allowed'
      }
    },
    # Consideration Stage
    {
      title: 'Brand Storytelling Content Series',
      description: 'Share compelling narratives about brand purpose and impact',
      step_type: 'content_piece',
      channel: 'video',
      stage: 'consideration',
      content: {
        type: 'storytelling',
        format: 'video_series',
        messaging: 'Emotional connection and brand purpose'
      },
      settings: {
        series_theme: 'brand_purpose',
        episode_count: 6,
        emotional_appeal: 'high'
      }
    },
    {
      title: 'Community Building Initiative',
      description: 'Foster brand community through engagement and user-generated content',
      step_type: 'social_post',
      channel: 'social_media',
      stage: 'consideration',
      content: {
        type: 'community',
        format: 'interactive_content',
        messaging: 'Join our community and be part of something bigger'
      },
      settings: {
        hashtag_campaign: true,
        user_generated_content: true,
        community_challenges: true
      }
    },
    # Conversion Stage
    {
      title: 'Brand Experience Events',
      description: 'Create memorable brand interactions through events and activations',
      step_type: 'event',
      channel: 'event',
      stage: 'conversion',
      content: {
        type: 'experiential',
        format: 'brand_activation',
        messaging: 'Immersive brand experience and product trial'
      },
      settings: {
        event_type: 'hybrid',
        experience_focus: 'brand_immersion',
        social_sharing: true
      }
    },
    {
      title: 'Referral and Word-of-Mouth Program',
      description: 'Leverage satisfied customers to spread brand awareness',
      step_type: 'automation',
      channel: 'email',
      stage: 'conversion',
      content: {
        type: 'referral',
        format: 'program_enrollment',
        messaging: 'Share the brand you love with friends'
      },
      settings: {
        referral_incentive: 'mutual_benefit',
        tracking_system: 'automated',
        social_sharing_tools: true
      }
    },
    # Retention Stage
    {
      title: 'Brand Advocate Program',
      description: 'Turn customers into active brand advocates and ambassadors',
      step_type: 'automation',
      channel: 'email',
      stage: 'retention',
      content: {
        type: 'advocacy',
        format: 'ambassador_program',
        messaging: 'Become a brand ambassador and earn exclusive benefits'
      },
      settings: {
        tier_system: true,
        exclusive_perks: true,
        co_creation_opportunities: true
      }
    },
    {
      title: 'User-Generated Content Campaigns',
      description: 'Encourage and showcase customer-created brand content',
      step_type: 'social_post',
      channel: 'social_media',
      stage: 'retention',
      content: {
        type: 'user_generated',
        format: 'campaign_showcase',
        messaging: 'Celebrate customer creativity and brand love'
      },
      settings: {
        content_contest: true,
        feature_policy: 'permission_based',
        reward_system: 'recognition_rewards'
      }
    }
  ]
}

JourneyTemplate.find_or_create_by!(
  name: 'Brand Awareness Campaign',
  campaign_type: 'upsell_cross_sell'
) do |template|
  template.description = 'Build brand recognition and preference through storytelling, community engagement, and authentic customer advocacy'
  template.template_data = brand_awareness_data
  template.is_default = true
  template.category = 'engagement'
  template.industry = 'general'
  template.complexity_level = 'advanced'
  template.prerequisites = 'Strong brand identity, social media presence, content creation team, community management capability'
end

puts "✓ Journey Templates created successfully!"
