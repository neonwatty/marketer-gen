# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).

# Create Users from test fixtures
puts "Creating Users..."

password_digest = BCrypt::Password.create("password")

# Add demo user at the beginning
users_data = [
  {
    email_address: "demo@example.com",
    password_digest: password_digest,
    role: "marketer",
    first_name: "Demo",
    last_name: "User"
  },
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

# =============================================================================
# DEMO USER COMPLETE SETUP
# =============================================================================

puts "\n" + "="*60
puts "Setting up DEMO USER with complete example data..."
puts "="*60 + "\n"

# Get or create demo user
demo_user = User.find_by(email_address: "demo@example.com")

if demo_user
  puts "Found demo user: #{demo_user.email_address}"
  
  # =============================================================================
  # BRAND IDENTITY SETUP
  # =============================================================================
  
  puts "\n📁 Creating Brand Identity for demo user..."
  
  # Create main brand identity
  brand_identity = BrandIdentity.find_or_create_by!(
    user: demo_user,
    name: "TechFlow Solutions"
  ) do |brand|
    brand.description = "Leading B2B SaaS platform for workflow automation and digital transformation. We help enterprises streamline operations and boost productivity."
    brand.brand_voice = "Professional, innovative, and approachable. We speak with authority about technology while remaining accessible to all skill levels."
    brand.tone_guidelines = "Confident but not arrogant. Educational without being condescending. Focus on solutions and outcomes. Use data to support claims."
    brand.messaging_framework = "Core Message: Automate Today, Innovate Tomorrow. Value Props: 70% reduction in manual tasks, Enterprise-grade security, Seamless integrations, Expert support 24/7. Primary Colors: #0066CC (TechFlow Blue), #FF6B35 (Innovation Orange)"
    brand.restrictions = "Do not use competitor names negatively. Avoid technical jargon in marketing materials. No unsubstantiated claims. Maintain professional tone in all communications."
    brand.is_active = true
    brand.status = 'active'
    brand.processed_guidelines = {
      'voice' => {
        'professional' => 'Expert authority in field',
        'approachable' => 'Friendly and accessible',
        'clear' => 'Simple explanations for complex concepts'
      },
      'tone' => {
        'marketing' => 'Enthusiastic and inspiring',
        'support' => 'Patient and thorough',
        'sales' => 'Consultative and solution-focused'
      },
      'restrictions' => [
        'No competitor disparagement',
        'Avoid excessive jargon',
        'Substantiate all claims',
        'Professional tone required'
      ],
      'messaging' => {
        'tagline' => 'Automate Today, Innovate Tomorrow',
        'value_propositions' => [
          '70% reduction in manual work',
          'Enterprise-grade security',
          'Seamless integrations',
          '24/7 expert support'
        ]
      },
      'files_processed' => {
        'count' => 3
      }
    }
  end
  
  # Attach brand materials if files exist
  if File.exist?(Rails.root.join('public', 'demo_assets', 'brand_guidelines.txt'))
    ['brand_guidelines.txt', 'voice_tone_guide.txt', 'style_guide.txt'].each do |filename|
      file_path = Rails.root.join('public', 'demo_assets', filename)
      if File.exist?(file_path) && !brand_identity.brand_materials.any? { |m| m.filename.to_s == filename }
        brand_identity.brand_materials.attach(
          io: File.open(file_path),
          filename: filename,
          content_type: 'text/plain'
        )
        puts "  ✓ Attached #{filename}"
      end
    end
  end
  
  puts "  ✓ Brand Identity created: #{brand_identity.name}"
  
  # =============================================================================
  # JOURNEYS SETUP
  # =============================================================================
  
  puts "\n🚀 Creating Journeys for demo user..."
  
  # Journey 1: Active Product Launch
  journey1 = Journey.find_or_create_by!(
    user: demo_user,
    name: "Q1 2025 Product Launch"
  ) do |j|
    j.description = "Launch campaign for our new AI-powered analytics feature"
    j.campaign_type = 'awareness'
    j.status = 'active'
    j.template_type = 'custom'
    j.stages = ['pre-launch', 'launch week', 'post-launch', 'retention']
    j.metadata = {
      'start_date' => '2025-01-15',
      'end_date' => '2025-04-15',
      'budget' => 50000,
      'target_reach' => 100000
    }
  end
  
  # Add journey steps
  [
    { title: 'Teaser Campaign', description: 'Social media teasers', sequence_order: 1, status: 'completed', stage: 'pre-launch', step_type: 'social_post', channel: 'social_media' },
    { title: 'Email Announcement', description: 'Launch announcement to subscribers', sequence_order: 2, status: 'completed', stage: 'launch week', step_type: 'email', channel: 'email' },
    { title: 'Product Demo Webinar', description: 'Live demonstration', sequence_order: 3, status: 'active', stage: 'launch week', step_type: 'webinar', channel: 'webinar' },
    { title: 'Customer Onboarding', description: 'New user onboarding sequence', sequence_order: 4, status: 'draft', stage: 'post-launch', step_type: 'email', channel: 'email' }
  ].each do |step_data|
    JourneyStep.find_or_create_by!(
      journey: journey1,
      title: step_data[:title]
    ) do |step|
      step.description = step_data[:description]
      step.sequence_order = step_data[:sequence_order]
      step.status = step_data[:status]
      step.step_type = step_data[:step_type]
      step.channel = step_data[:channel]
      step.settings = { 'stage' => step_data[:stage] }
    end
  end
  
  puts "  ✓ Created journey: #{journey1.name} (#{journey1.journey_steps.count} steps)"
  
  # Journey 2: Completed Lead Generation
  journey2 = Journey.find_or_create_by!(
    user: demo_user,
    name: "Winter Lead Generation Campaign"
  ) do |j|
    j.description = "Q4 2024 lead generation campaign - Successfully generated 500+ qualified leads"
    j.campaign_type = 'consideration'
    j.status = 'completed'
    j.template_type = 'email'
    j.stages = ['awareness', 'nurture', 'qualification', 'handoff']
    j.metadata = {
      'completion_date' => '2024-12-31',
      'leads_generated' => 523,
      'conversion_rate' => '12.5%'
    }
  end
  
  puts "  ✓ Created journey: #{journey2.name}"
  
  # Journey 3: Draft Re-engagement
  journey3 = Journey.find_or_create_by!(
    user: demo_user,
    name: "Customer Win-Back Initiative"
  ) do |j|
    j.description = "Re-engage dormant customers from 2024"
    j.campaign_type = 'retention'
    j.status = 'draft'
    j.template_type = 'email'
    j.stages = ['analysis', 'outreach', 'incentive', 'follow-up']
  end
  
  puts "  ✓ Created journey: #{journey3.name}"
  
  # =============================================================================
  # CAMPAIGN PLANS SETUP
  # =============================================================================
  
  puts "\n📋 Creating Campaign Plans for demo user..."
  
  # Campaign Plan 1: Completed Product Launch
  campaign1 = CampaignPlan.find_or_create_by!(
    user: demo_user,
    name: "Q1 2025 AI Analytics Launch"
  ) do |plan|
    plan.description = "Comprehensive launch campaign for our new AI-powered analytics feature targeting enterprise customers"
    plan.campaign_type = 'product_launch'
    plan.objective = 'customer_acquisition'
    plan.status = 'completed'
    plan.approval_status = 'approved'
    plan.target_audience = 'Enterprise IT decision makers, Data analysts, CTOs at companies with 500+ employees'
    plan.budget_constraints = '50000'
    plan.timeline_constraints = '3 months (Jan-Mar 2025)'
    plan.brand_context = brand_identity.id.to_s
    plan.generated_summary = "Launch our revolutionary AI analytics feature to enterprise market through multi-channel campaign focusing on ROI and competitive advantages."
    plan.generated_strategy = {
      'positioning' => 'Market leader in AI-powered business intelligence',
      'key_messages' => ['70% faster insights', 'No-code AI models', 'Enterprise security'],
      'channels' => ['Email', 'LinkedIn', 'Webinars', 'Content marketing'],
      'tactics' => [
        'Pre-launch teasers',
        'Launch week blitz',
        'Customer success stories',
        'Competitive comparisons'
      ]
    }
    plan.generated_timeline = {
      'phases' => [
        { 'name' => 'Pre-launch', 'duration' => '4 weeks', 'activities' => ['Teasers', 'Email warmup'] },
        { 'name' => 'Launch', 'duration' => '1 week', 'activities' => ['Announcement', 'Webinar', 'PR'] },
        { 'name' => 'Amplification', 'duration' => '6 weeks', 'activities' => ['Content series', 'Case studies'] },
        { 'name' => 'Conversion', 'duration' => '2 weeks', 'activities' => ['Offers', 'Follow-up'] }
      ]
    }
    plan.generated_assets = [
      'Launch announcement email',
      'Product demo video',
      'Comparison guide',
      'ROI calculator',
      'Case study template'
    ]
    plan.approved_by = demo_user
    plan.approved_at = 1.week.ago
  end
  
  puts "  ✓ Created campaign plan: #{campaign1.name}"
  
  # Campaign Plan 2: In Progress Lead Gen
  campaign2 = CampaignPlan.find_or_create_by!(
    user: demo_user,
    name: "Spring 2025 Lead Generation"
  ) do |plan|
    plan.description = "Generate 1000 qualified B2B leads through content marketing and webinars"
    plan.campaign_type = 'lead_generation'
    plan.objective = 'lead_generation'
    plan.status = 'completed'
    plan.approval_status = 'approved'
    plan.target_audience = 'Mid-market B2B companies in technology and finance sectors'
    plan.budget_constraints = '30000'
    plan.timeline_constraints = '2 months'
    plan.generated_summary = "Multi-touch lead generation campaign leveraging educational content and thought leadership."
    plan.generated_strategy = {
      'approach' => 'Educational content funnel',
      'lead_magnets' => ['Industry report', 'ROI calculator', 'Best practices guide'],
      'nurture_sequence' => '10-email automation',
      'qualification_criteria' => ['Company size', 'Budget', 'Timeline', 'Authority']
    }
  end
  
  puts "  ✓ Created campaign plan: #{campaign2.name}"
  
  # Campaign Plan 3: Draft Brand Awareness
  campaign3 = CampaignPlan.find_or_create_by!(
    user: demo_user,
    name: "2025 Brand Awareness Initiative"
  ) do |plan|
    plan.description = "Increase brand recognition and thought leadership position in the market"
    plan.campaign_type = 'brand_awareness'
    plan.objective = 'brand_awareness'
    plan.status = 'draft'
    plan.approval_status = 'draft'
    plan.target_audience = 'Tech industry professionals and business leaders'
    plan.budget_constraints = '75000'
    plan.timeline_constraints = '6 months'
  end
  
  puts "  ✓ Created campaign plan: #{campaign3.name}"
  
  # =============================================================================
  # GENERATED CONTENT SETUP
  # =============================================================================
  
  puts "\n✍️  Creating Generated Content examples..."
  
  # Email Content 1: Welcome Series
  content1 = GeneratedContent.find_or_create_by!(
    campaign_plan: campaign1,
    created_by: demo_user,
    title: "Welcome to TechFlow - Your Journey Starts Here"
  ) do |content|
    content.content_type = 'email'
    content.format_variant = 'standard'
    content.status = 'published'
    content.version_number = 1
    content.body_content = "Subject: Welcome to TechFlow! 🚀 Your automation journey begins now\n\nDear [First Name],\n\nThank you for joining TechFlow Solutions! You've just taken the first step toward transforming how your team works.\n\nOver the next few days, we'll show you how to:\n✅ Set up your first automation in under 5 minutes\n✅ Connect your existing tools seamlessly\n✅ Save hours of manual work every week\n\nYour Success Checklist:\n1. Complete your profile setup (2 min)\n2. Connect your first integration (3 min)\n3. Create your first automation (5 min)\n\nNeed help getting started? Our team is here for you 24/7.\n\nBest regards,\nThe TechFlow Team\n\nP.S. Reply to this email with any questions - we read and respond to every message!"
    content.metadata = {
      'campaign' => 'onboarding',
      'performance' => { 'open_rate' => '68%', 'click_rate' => '24%' }
    }
  end
  
  puts "  ✓ Created content: #{content1.title}"
  
  # Social Media Content
  content2 = GeneratedContent.find_or_create_by!(
    campaign_plan: campaign1,
    created_by: demo_user,
    title: "LinkedIn Launch Announcement"
  ) do |content|
    content.content_type = 'social_post'
    content.format_variant = 'medium'
    content.status = 'approved'
    content.version_number = 2
    content.body_content = "🎉 Big News! Introducing TechFlow AI Analytics\n\nWe're thrilled to announce our most requested feature is now live!\n\n🤖 What's New:\n• AI-powered insights in seconds, not hours\n• No-code predictive models anyone can build\n• Real-time anomaly detection\n• Natural language queries - just ask your data\n\n💡 Early customers are seeing:\n• 70% reduction in analysis time\n• 3x more insights discovered\n• 50% improvement in forecast accuracy\n\nSee it in action → [link]\n\n#AI #Analytics #DataScience #Innovation #B2B #SaaS"
    content.approved_by_id = demo_user.id
    content.metadata = {
      'platform' => 'linkedin',
      'engagement' => { 'likes' => 245, 'shares' => 67, 'comments' => 23 }
    }
  end
  
  puts "  ✓ Created content: #{content2.title}"
  
  # Blog Article
  content3 = GeneratedContent.find_or_create_by!(
    campaign_plan: campaign2,
    created_by: demo_user,
    title: "The Complete Guide to Workflow Automation in 2025"
  ) do |content|
    content.content_type = 'blog_article'
    content.format_variant = 'long'
    content.status = 'published'
    content.version_number = 1
    content.body_content = "# The Complete Guide to Workflow Automation in 2025\n\n## Introduction\n\nIn today's fast-paced business environment, workflow automation isn't just a luxury—it's a necessity. Companies that embrace automation are seeing unprecedented gains in productivity, accuracy, and employee satisfaction.\n\n## What is Workflow Automation?\n\nWorkflow automation uses technology to complete repetitive tasks without human intervention. By connecting your tools and creating intelligent workflows, you can focus on strategic work while routine tasks handle themselves.\n\n## Key Benefits\n\n### 1. Time Savings\nThe average knowledge worker spends 60% of their time on repetitive tasks. Automation can reclaim up to 70% of this time, freeing your team for creative and strategic work.\n\n### 2. Error Reduction\nManual data entry has an error rate of 1-5%. Automated workflows reduce this to nearly zero, ensuring data accuracy across all systems.\n\n### 3. Scalability\nAutomated workflows scale effortlessly. Whether processing 10 or 10,000 transactions, the effort remains the same.\n\n## Getting Started with Automation\n\n### Step 1: Identify Repetitive Tasks\nStart by documenting tasks that:\n- Occur regularly\n- Follow consistent rules\n- Involve data transfer between systems\n- Take significant time but require little decision-making\n\n### Step 2: Map Your Current Process\nDocument each step in your current workflow. This helps identify:\n- Bottlenecks\n- Unnecessary steps\n- Optimization opportunities\n\n### Step 3: Choose the Right Tools\nLook for automation platforms that offer:\n- No-code/low-code interfaces\n- Pre-built integrations\n- Scalability\n- Security compliance\n\n## Real-World Success Stories\n\n### Case Study 1: TechCorp\nTechCorp automated their invoice processing, reducing processing time from 3 days to 30 minutes and eliminating late payment fees.\n\n### Case Study 2: Marketing Pro\nMarketing Pro automated their lead nurturing, increasing qualified leads by 150% while reducing manual effort by 80%.\n\n## Common Automation Mistakes to Avoid\n\n1. **Automating broken processes** - Fix the process first, then automate\n2. **Over-complicating workflows** - Start simple and iterate\n3. **Neglecting testing** - Always test thoroughly before full deployment\n4. **Forgetting the human element** - Keep humans in the loop for exceptions\n\n## The Future of Automation\n\nAs we move through 2025, expect to see:\n- AI-enhanced automation that learns and adapts\n- Voice-activated workflow triggers\n- Predictive automation that anticipates needs\n- Deeper integration with emerging technologies\n\n## Conclusion\n\nWorkflow automation is no longer optional—it's essential for staying competitive. Start small, measure results, and scale gradually. The journey to full automation begins with a single workflow.\n\n**Ready to start automating?** Contact our team for a personalized automation assessment."
    content.metadata = {
      'seo_keywords' => ['workflow automation', 'business automation', 'productivity'],
      'read_time' => '8 minutes',
      'performance' => { 'views' => 3420, 'avg_time_on_page' => '6:45' }
    }
  end
  
  puts "  ✓ Created content: #{content3.title}"
  
  # Ad Copy
  content4 = GeneratedContent.find_or_create_by!(
    campaign_plan: campaign1,
    created_by: demo_user,
    title: "Google Ads - AI Analytics Launch"
  ) do |content|
    content.content_type = 'ad_copy'
    content.format_variant = 'short'
    content.status = 'approved'
    content.version_number = 3
    content.body_content = "Headline 1: AI Analytics in Seconds\nHeadline 2: No Code Required\nHeadline 3: Enterprise Ready\n\nDescription 1: Transform your data into insights with TechFlow AI. Get predictions, detect anomalies, and make better decisions—all without writing code.\n\nDescription 2: Join 500+ companies already using TechFlow to automate analytics. Start free trial today. Setup in 5 minutes."
    content.approved_by_id = demo_user.id
    content.metadata = {
      'platform' => 'google_ads',
      'performance' => { 'ctr' => '3.2%', 'conversions' => 47 }
    }
  end
  
  puts "  ✓ Created content: #{content4.title}"
  
  # Landing Page Copy
  content5 = GeneratedContent.find_or_create_by!(
    campaign_plan: campaign2,
    created_by: demo_user,
    title: "Lead Magnet Landing Page - ROI Calculator"
  ) do |content|
    content.content_type = 'landing_page'
    content.format_variant = 'standard'
    content.status = 'published'
    content.version_number = 1
    content.body_content = "# Calculate Your Automation ROI in 60 Seconds\n\n## See How Much Time and Money You Could Save\n\nEvery minute your team spends on repetitive tasks is a minute not spent on growth. Our ROI calculator shows you exactly what automation could mean for your bottom line.\n\n### What You'll Discover:\n✓ Hours saved per week through automation\n✓ Annual cost savings potential\n✓ ROI timeline for your investment\n✓ Custom recommendations for your industry\n\n### Trusted by 500+ Companies\n\n\"We saved 30 hours per week and saw ROI in just 2 months.\" - Sarah J., Operations Director\n\n### Get Your Free ROI Report\n\n[Form]\nFirst Name*\nLast Name*\nWork Email*\nCompany Name*\nTeam Size*\nIndustry*\n\n[CTA Button: Calculate My ROI →]\n\n### What Happens Next?\n1. Instant ROI calculation based on your inputs\n2. Personalized automation roadmap\n3. Free consultation with our automation experts\n4. No credit card required\n\n### Privacy Promise\nYour information is secure and will never be shared. Unsubscribe anytime."
    content.metadata = {
      'conversion_rate' => '24%',
      'form_completions' => 892
    }
  end
  
  puts "  ✓ Created content: #{content5.title}"
  
  # More content pieces
  content6 = GeneratedContent.find_or_create_by!(
    campaign_plan: campaign2,
    created_by: demo_user,
    title: "Webinar Follow-up Email"
  ) do |content|
    content.content_type = 'email'
    content.format_variant = 'medium'
    content.status = 'in_review'
    content.version_number = 2
    content.body_content = "Subject: Your webinar recording + exclusive bonus inside\n\nHi [First Name],\n\nThank you for attending our webinar 'Automating Your Way to 10x Growth'!\n\nAs promised, here are your resources:\n\n📹 Webinar Recording: [Link]\n📊 Slide Deck: [Link]\n📝 Automation Checklist: [Link]\n\n**Exclusive Attendee Bonus:**\nGet 30% off TechFlow Pro for the next 48 hours with code WEBINAR30\n\n[Claim Your Discount]\n\nKey Takeaways from Today:\n• The 5-step automation framework\n• How CompanyX saved $2M with workflow automation\n• Quick wins you can implement this week\n\nQuestions? Reply to this email or book a 1-on-1 demo: [Calendar Link]\n\nBest,\nThe TechFlow Team"
  end
  
  puts "  ✓ Created content: #{content6.title}"
  
  # =============================================================================
  # PERSONAS SETUP
  # =============================================================================
  
  puts "\n👥 Creating Personas for demo user..."
  
  persona1 = Persona.find_or_create_by!(
    user: demo_user,
    name: "Enterprise IT Decision Maker"
  ) do |p|
    p.description = "Senior IT executives at large enterprises responsible for digital transformation initiatives"
    p.demographics = { 'age_range' => '35-55', 'job_titles' => ['CTO', 'VP of IT', 'IT Director'], 'company_size' => '1000+' }
    p.characteristics = { 'motivations' => ['Innovation', 'Efficiency', 'ROI'], 'challenges' => ['Legacy systems', 'Change management'] }
    p.behavioral_traits = { 'decision_style' => 'Analytical', 'buying_process' => 'Committee-based', 'research_heavy' => true }
    p.goals = ['Modernize tech stack', 'Reduce operational costs', 'Improve team productivity']
    p.pain_points = ['Integration complexity', 'Security concerns', 'Budget constraints']
    p.preferred_channels = ['Email', 'LinkedIn', 'Webinars', 'Whitepapers']
    p.content_preferences = { 'format' => 'detailed', 'tone' => 'professional', 'evidence' => 'data-driven' }
    p.is_active = true
  end
  
  puts "  ✓ Created persona: #{persona1.name}"
  
  persona2 = Persona.find_or_create_by!(
    user: demo_user,
    name: "Mid-Market Operations Manager"
  ) do |p|
    p.description = "Operations professionals at growing companies looking to scale efficiently"
    p.demographics = { 'age_range' => '28-45', 'job_titles' => ['Operations Manager', 'Process Manager'], 'company_size' => '100-1000' }
    p.characteristics = { 'motivations' => ['Efficiency', 'Growth', 'Team success'], 'challenges' => ['Limited resources', 'Scaling issues'] }
    p.behavioral_traits = { 'decision_style' => 'Practical', 'buying_process' => 'Team-input', 'values' => ['ROI', 'Ease of use'] }
    p.goals = ['Streamline operations', 'Reduce manual work', 'Improve accuracy']
    p.pain_points = ['Too many manual processes', 'Data silos', 'Lack of visibility']
    p.preferred_channels = ['Email', 'Blog', 'Case studies', 'Product demos']
    p.content_preferences = { 'format' => 'practical', 'tone' => 'straightforward', 'evidence' => 'case-studies' }
    p.is_active = true
  end
  
  puts "  ✓ Created persona: #{persona2.name}"
  
  puts "\n" + "="*60
  puts "✅ DEMO USER SETUP COMPLETE!"
  puts "="*60
  puts "\nDemo user credentials:"
  puts "  Email: demo@example.com"
  puts "  Password: password"
  puts "\nCreated:"
  puts "  • 1 Brand Identity (TechFlow Solutions)"
  puts "  • 3 Journeys (various stages)"
  puts "  • 3 Campaign Plans"
  puts "  • 6 Generated Content pieces"
  puts "  • 2 Personas"
  puts "\nYou can now log in and explore all features with realistic data!"
else
  puts "⚠️  Demo user not found. Please ensure demo@example.com exists."
end
