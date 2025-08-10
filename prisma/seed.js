const { PrismaClient } = require('@prisma/client')
const prisma = new PrismaClient()

async function main() {
  console.log('🌱 Starting database seed...')

  // Create test users
  console.log('Creating users...')
  const user1 = await prisma.user.upsert({
    where: { email: 'john@example.com' },
    update: {},
    create: {
      email: 'john@example.com',
      name: 'John Doe'
    }
  })

  const user2 = await prisma.user.upsert({
    where: { email: 'sarah@example.com' },
    update: {},
    create: {
      email: 'sarah@example.com',
      name: 'Sarah Wilson'
    }
  })

  // Create brands
  console.log('Creating brands...')
  const techBrand = await prisma.brand.upsert({
    where: { id: 'brand-tech-startup' },
    update: {},
    create: {
      id: 'brand-tech-startup',
      name: 'TechFlow Solutions',
      description: 'AI-powered productivity tools for modern teams',
      logoUrl: 'https://example.com/logos/techflow.png',
      primaryColor: '#3B82F6',
      secondaryColor: '#1E40AF',
      fontFamily: 'Inter, sans-serif',
      brandGuidelines: JSON.stringify({
        mission: 'Simplify complex workflows with AI',
        values: ['Innovation', 'Simplicity', 'Reliability'],
        personality: ['Professional', 'Modern', 'Approachable']
      }),
      voiceAndTone: JSON.stringify({
        voice: ['Clear', 'Confident', 'Helpful'],
        tone: 'Professional yet friendly, technical but accessible',
        doNotUse: ['Jargon', 'Overly complex terms', 'Aggressive language']
      }),
      targetAudience: JSON.stringify({
        primary: 'Tech-savvy professionals aged 25-45',
        secondary: 'Small to medium business owners',
        demographics: {
          age: '25-45',
          occupation: 'Tech professionals, managers, entrepreneurs',
          challenges: 'Workflow inefficiency, team collaboration'
        }
      }),
      brandAssets: JSON.stringify({
        logoVariants: ['primary', 'white', 'dark', 'icon-only'],
        colorPalette: {
          primary: '#3B82F6',
          secondary: '#1E40AF',
          accent: '#F59E0B',
          neutral: '#6B7280'
        },
        typography: {
          heading: 'Inter Bold',
          body: 'Inter Regular',
          accent: 'Inter Medium'
        }
      }),
      userId: user1.id
    }
  })

  const fashionBrand = await prisma.brand.upsert({
    where: { id: 'brand-eco-fashion' },
    update: {},
    create: {
      id: 'brand-eco-fashion',
      name: 'GreenThread',
      description: 'Sustainable fashion for conscious consumers',
      logoUrl: 'https://example.com/logos/greenthread.png',
      primaryColor: '#10B981',
      secondaryColor: '#059669',
      fontFamily: 'Playfair Display, serif',
      brandGuidelines: JSON.stringify({
        mission: 'Make sustainable fashion accessible and stylish',
        values: ['Sustainability', 'Quality', 'Transparency'],
        personality: ['Eco-conscious', 'Stylish', 'Authentic']
      }),
      voiceAndTone: JSON.stringify({
        voice: ['Warm', 'Inspiring', 'Authentic'],
        tone: 'Passionate about sustainability, inspiring yet approachable',
        doNotUse: ['Greenwashing', 'Corporate speak', 'Guilt-inducing language']
      }),
      targetAudience: JSON.stringify({
        primary: 'Environmentally conscious millennials and Gen Z',
        secondary: 'Fashion-forward professionals',
        demographics: {
          age: '22-40',
          values: 'Sustainability, ethical consumption',
          interests: 'Fashion, environment, social causes'
        }
      }),
      brandAssets: JSON.stringify({
        logoVariants: ['primary', 'white', 'dark', 'leaf-icon'],
        colorPalette: {
          primary: '#10B981',
          secondary: '#059669',
          accent: '#F59E0B',
          earth: '#92400E'
        },
        typography: {
          heading: 'Playfair Display Bold',
          body: 'Source Sans Pro Regular',
          accent: 'Source Sans Pro Semi Bold'
        }
      }),
      userId: user2.id
    }
  })

  // Create templates
  console.log('Creating templates...')
  const emailTemplate = await prisma.template.upsert({
    where: { id: 'template-welcome-email' },
    update: {},
    create: {
      id: 'template-welcome-email',
      name: 'Welcome Email Template',
      description: 'Onboarding email template for new subscribers',
      type: 'CONTENT',
      category: 'email',
      structure: JSON.stringify({
        sections: [
          { type: 'header', content: '{{brand_name}} welcomes you!' },
          { type: 'intro', content: 'Thank you for joining {{brand_name}}. We\'re excited to have you!' },
          { type: 'body', content: '{{welcome_message}}' },
          { type: 'cta', content: 'Get Started', link: '{{onboarding_link}}' },
          { type: 'footer', content: 'Best regards,\\nThe {{brand_name}} Team' }
        ]
      }),
      variables: JSON.stringify({
        required: ['brand_name', 'welcome_message', 'onboarding_link'],
        optional: ['user_name', 'special_offer']
      }),
      styling: JSON.stringify({
        colors: {
          primary: '{{brand_primary_color}}',
          secondary: '{{brand_secondary_color}}',
          text: '#333333',
          background: '#FFFFFF'
        },
        fonts: {
          heading: '{{brand_heading_font}}',
          body: '{{brand_body_font}}'
        },
        layout: {
          maxWidth: '600px',
          padding: '20px',
          borderRadius: '8px'
        }
      })
    }
  })

  const journeyTemplate = await prisma.template.upsert({
    where: { id: 'template-onboarding-journey' },
    update: {},
    create: {
      id: 'template-onboarding-journey',
      name: 'Customer Onboarding Journey',
      description: 'Multi-step onboarding journey for new customers',
      type: 'JOURNEY',
      category: 'onboarding',
      structure: JSON.stringify({
        stages: [
          {
            id: 'welcome',
            name: 'Welcome Stage',
            duration: '1 day',
            actions: ['send_welcome_email', 'create_user_profile']
          },
          {
            id: 'education',
            name: 'Education Stage',
            duration: '3 days',
            actions: ['send_tutorial_series', 'track_engagement']
          },
          {
            id: 'activation',
            name: 'Activation Stage',
            duration: '7 days',
            actions: ['send_feature_tips', 'prompt_first_action']
          }
        ]
      }),
      variables: JSON.stringify({
        required: ['user_segment', 'product_type'],
        optional: ['referral_source', 'signup_date']
      }),
      styling: JSON.stringify({
        theme: 'professional',
        colorScheme: 'brand-aligned',
        layout: 'sequential'
      })
    }
  })

  // Create campaigns
  console.log('Creating campaigns...')
  const techCampaign = await prisma.campaign.upsert({
    where: { id: 'campaign-product-launch' },
    update: {},
    create: {
      id: 'campaign-product-launch',
      name: 'AI Assistant Product Launch',
      description: 'Launch campaign for our new AI assistant feature',
      status: 'ACTIVE',
      goals: JSON.stringify({
        primary: 'Generate 1000 signups for AI assistant beta',
        secondary: ['Increase brand awareness', 'Generate product feedback'],
        metrics: ['signup_rate', 'engagement_rate', 'feedback_score']
      }),
      targetKPIs: JSON.stringify({
        signups: { target: 1000, current: 247 },
        conversion_rate: { target: 0.15, current: 0.12 },
        engagement_rate: { target: 0.25, current: 0.18 }
      }),
      timeline: JSON.stringify({
        start_date: '2024-01-15',
        end_date: '2024-02-28',
        phases: [
          { name: 'Teaser', duration: '1 week' },
          { name: 'Launch', duration: '2 weeks' },
          { name: 'Follow-up', duration: '3 weeks' }
        ]
      }),
      budget: 15000.0,
      brandId: techBrand.id
    }
  })

  const fashionCampaign = await prisma.campaign.upsert({
    where: { id: 'campaign-spring-collection' },
    update: {},
    create: {
      id: 'campaign-spring-collection',
      name: 'Sustainable Spring Collection',
      description: 'Promote our new eco-friendly spring fashion line',
      status: 'DRAFT',
      goals: JSON.stringify({
        primary: 'Drive 500 pre-orders for spring collection',
        secondary: ['Build email list', 'Increase social media following'],
        metrics: ['pre_order_count', 'email_signups', 'social_followers']
      }),
      targetKPIs: JSON.stringify({
        pre_orders: { target: 500, current: 0 },
        email_signups: { target: 2000, current: 1200 },
        social_growth: { target: 0.20, current: 0.08 }
      }),
      timeline: JSON.stringify({
        start_date: '2024-02-01',
        end_date: '2024-04-30',
        phases: [
          { name: 'Pre-launch', duration: '3 weeks' },
          { name: 'Launch', duration: '4 weeks' },
          { name: 'Sustain', duration: '5 weeks' }
        ]
      }),
      budget: 8500.0,
      brandId: fashionBrand.id
    }
  })

  // Create journeys
  console.log('Creating journeys...')
  const onboardingJourney = await prisma.journey.upsert({
    where: { id: 'journey-ai-onboarding' },
    update: {},
    create: {
      id: 'journey-ai-onboarding',
      name: 'AI Assistant Onboarding',
      description: 'Guided onboarding for new AI assistant users',
      status: 'ACTIVE',
      stages: JSON.stringify([
        {
          id: 'setup',
          name: 'Account Setup',
          order: 1,
          duration: '5 minutes',
          actions: ['create_profile', 'set_preferences', 'connect_tools']
        },
        {
          id: 'tutorial',
          name: 'Interactive Tutorial',
          order: 2,
          duration: '15 minutes',
          actions: ['show_features', 'first_task', 'get_feedback']
        },
        {
          id: 'activation',
          name: 'First Success',
          order: 3,
          duration: '1 week',
          actions: ['complete_first_project', 'invite_team', 'share_success']
        }
      ]),
      triggers: JSON.stringify({
        entry: ['user_signup', 'beta_access_granted'],
        progression: ['stage_completion', 'time_delay', 'user_action'],
        exit: ['journey_completion', 'user_inactivity', 'opt_out']
      }),
      conditions: JSON.stringify({
        entry_requirements: ['verified_email', 'accepted_terms'],
        progression_rules: ['previous_stage_complete', 'engagement_threshold'],
        personalization: ['user_role', 'company_size', 'use_case']
      }),
      campaignId: techCampaign.id,
      templateId: journeyTemplate.id
    }
  })

  const fashionJourney = await prisma.journey.upsert({
    where: { id: 'journey-spring-promo' },
    update: {},
    create: {
      id: 'journey-spring-promo',
      name: 'Spring Collection Promotion',
      description: 'Multi-channel promotion for spring collection launch',
      status: 'DRAFT',
      stages: JSON.stringify([
        {
          id: 'awareness',
          name: 'Build Awareness',
          order: 1,
          duration: '2 weeks',
          actions: ['social_teasers', 'influencer_outreach', 'email_announcement']
        },
        {
          id: 'consideration',
          name: 'Drive Consideration',
          order: 2,
          duration: '2 weeks',
          actions: ['product_showcases', 'sustainability_content', 'early_bird_offer']
        },
        {
          id: 'conversion',
          name: 'Convert to Sales',
          order: 3,
          duration: '3 weeks',
          actions: ['limited_time_discount', 'social_proof', 'urgency_messaging']
        }
      ]),
      triggers: JSON.stringify({
        entry: ['campaign_launch', 'seasonal_timing'],
        progression: ['engagement_threshold', 'time_progression'],
        exit: ['purchase_made', 'campaign_end']
      }),
      conditions: JSON.stringify({
        targeting: ['eco_conscious_segment', 'fashion_interested'],
        personalization: ['past_purchases', 'engagement_history', 'size_preferences']
      }),
      campaignId: fashionCampaign.id,
      templateId: journeyTemplate.id
    }
  })

  // Create content
  console.log('Creating content...')
  const welcomeEmail = await prisma.content.upsert({
    where: { id: 'content-welcome-email-ai' },
    update: {},
    create: {
      id: 'content-welcome-email-ai',
      title: 'Welcome to TechFlow AI Assistant',
      description: 'Onboarding email for new AI assistant users',
      type: 'EMAIL',
      status: 'APPROVED',
      content: `Subject: Welcome to the future of productivity! 🚀

Hi {{user_name}},

Welcome to TechFlow AI Assistant! We're thrilled to have you join thousands of professionals who are already transforming their workflows with AI.

Your AI assistant is ready to help you:
✨ Automate repetitive tasks
📊 Analyze data instantly  
💡 Generate creative solutions
🤝 Collaborate more effectively

Ready to get started? Click below to take your first steps:

[Start Your AI Journey →]

Questions? Reply to this email - we're here to help!

Best regards,
The TechFlow Team

P.S. Keep an eye out for our weekly AI productivity tips!`,
      version: 1,
      language: 'en',
      format: 'html',
      approvalStatus: 'APPROVED',
      prompt: 'Create a welcome email for new AI assistant users that highlights key benefits and encourages first use',
      generatedBy: 'claude-3.5-sonnet',
      generationCost: 0.05,
      journeyId: onboardingJourney.id,
      templateId: emailTemplate.id
    }
  })

  const socialPost = await prisma.content.upsert({
    where: { id: 'content-spring-social-teaser' },
    update: {},
    create: {
      id: 'content-spring-social-teaser',
      title: 'Spring Collection Teaser Post',
      description: 'Social media teaser for sustainable spring collection',
      type: 'SOCIAL_POST',
      status: 'GENERATED',
      content: `🌱 Something beautiful is growing... 

Our most sustainable collection yet is almost here. Made from 100% organic cotton and recycled materials, these pieces prove that fashion can be both stylish AND planet-friendly.

Can you guess what's coming? 👀

Drop a 🌿 if you're ready for conscious fashion that doesn't compromise on style.

#SustainableFashion #EcoFriendly #ComingSoon #GreenThread`,
      version: 1,
      language: 'en',
      format: 'text',
      fileUrl: 'https://example.com/social-images/spring-teaser.jpg',
      thumbnailUrl: 'https://example.com/social-images/spring-teaser-thumb.jpg',
      approvalStatus: 'PENDING',
      prompt: 'Create an engaging social media teaser post for a sustainable spring fashion collection that builds anticipation',
      generatedBy: 'gpt-4',
      generationCost: 0.03,
      journeyId: fashionJourney.id,
      templateId: null
    }
  })

  // Create analytics data
  console.log('Creating analytics data...')
  await prisma.analytics.createMany({
    data: [
      {
        eventType: 'EMAIL_OPEN',
        eventName: 'welcome_email_open',
        views: 1,
        engagementRate: 0.45,
        userAgent: 'Mozilla/5.0 (iPhone; CPU iPhone OS 15_0 like Mac OS X)',
        country: 'US',
        region: 'California',
        deviceType: 'mobile',
        browserType: 'safari',
        campaignId: techCampaign.id,
        journeyId: onboardingJourney.id,
        contentId: welcomeEmail.id
      },
      {
        eventType: 'CLICK',
        eventName: 'cta_button_click',
        clicks: 1,
        conversions: 1,
        clickThroughRate: 0.12,
        conversionRate: 0.08,
        userAgent: 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
        country: 'US',
        region: 'New York',
        deviceType: 'desktop',
        browserType: 'chrome',
        campaignId: techCampaign.id,
        journeyId: onboardingJourney.id,
        contentId: welcomeEmail.id
      },
      {
        eventType: 'CAMPAIGN_START',
        eventName: 'ai_assistant_launch',
        impressionCount: 15000,
        reachCount: 12500,
        cost: 850.0,
        campaignId: techCampaign.id
      },
      {
        eventType: 'VIEW',
        eventName: 'social_post_view',
        views: 2500,
        likes: 125,
        shares: 18,
        comments: 34,
        engagementRate: 0.07,
        country: 'UK',
        deviceType: 'mobile',
        campaignId: fashionCampaign.id,
        journeyId: fashionJourney.id,
        contentId: socialPost.id
      }
    ]
  })

  console.log('✅ Seed data created successfully!')
  console.log(`Created:
  - 2 Users
  - 2 Brands  
  - 2 Templates
  - 2 Campaigns
  - 2 Journeys
  - 2 Content items
  - 4 Analytics records`)
}

main()
  .catch((e) => {
    console.error('❌ Seed failed:')
    console.error(e)
    process.exit(1)
  })
  .finally(async () => {
    await prisma.$disconnect()
  })