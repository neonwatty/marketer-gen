import { PrismaClient } from '../src/generated/prisma'

const prisma = new PrismaClient()

async function main() {
  console.log('🌱 Starting database seeding...')

  // Create test users
  console.log('👤 Creating users...')
  const user1 = await prisma.user.create({
    data: {
      email: 'john@acmecorp.com',
      name: 'John Smith',
      role: 'ADMIN',
    },
  })

  const user2 = await prisma.user.create({
    data: {
      email: 'sarah@techstartup.com',
      name: 'Sarah Johnson',
      role: 'USER',
    },
  })

  // Create brands with comprehensive brand profiles
  console.log('🏢 Creating brands...')
  const brand1 = await prisma.brand.create({
    data: {
      name: 'ACME Corporation',
      description: 'Leading provider of enterprise software solutions',
      industry: 'Technology',
      website: 'https://acmecorp.com',
      tagline: 'Excellence in Every Solution',
      mission: 'Innovating for tomorrow, delivering today',
      vision: 'To be the world\'s most trusted technology partner',
      values: ['Innovation', 'Quality', 'Customer Success', 'Integrity'],
      personality: ['Professional', 'Trustworthy', 'Innovative', 'Results-oriented'],
      voiceDescription: 'Confident and knowledgeable with a professional yet approachable tone',
      toneAttributes: {
        formal: 7,
        friendly: 6,
        authoritative: 8,
        innovative: 9,
        trustworthy: 9
      },
      communicationStyle: 'Clear, direct, and solution-focused',
      messagingFramework: {
        primary: 'Trusted by industry leaders',
        secondary: ['Innovative solutions that scale', 'Your success is our priority'],
        support: ['Proven track record', 'Expert team', 'Comprehensive support']
      },
      brandPillars: ['Innovation', 'Reliability', 'Excellence', 'Partnership'],
      targetAudience: {
        primary: 'Enterprise decision makers aged 35-55',
        secondary: 'IT professionals and technology leaders',
        demographics: {
          age_range: '35-55',
          job_titles: ['CTO', 'IT Director', 'VP Technology', 'Enterprise Architect'],
          company_size: '500+ employees',
          industry: ['Technology', 'Finance', 'Healthcare', 'Manufacturing']
        }
      },
      competitivePosition: 'Premium B2B solutions provider with unmatched reliability',
      brandPromise: 'Delivering enterprise-grade solutions that scale with your business',
      complianceRules: {
        'logo_usage': 'Minimum clear space must be maintained around logo',
        'color_usage': 'Primary colors only for brand identity, secondary for accents',
        'tone_guidelines': 'Always maintain professional, confident tone'
      },
      usageGuidelines: {
        'do': ['Use primary logo on white backgrounds', 'Maintain consistent spacing', 'Use approved color palette'],
        'dont': ['Stretch or distort logo', 'Use unapproved colors', 'Alter typography']
      },
      restrictedTerms: ['cheap', 'basic', 'simple', 'easy'],
      userId: user1.id,
      createdBy: user1.id,
    },
  })

  const brand2 = await prisma.brand.create({
    data: {
      name: 'TechFlow Startup',
      description: 'Democratizing technology for small businesses',
      industry: 'Technology',
      website: 'https://techflowstartup.com',
      tagline: 'Simplifying Success',
      mission: 'Democratizing technology for small businesses',
      vision: 'Every small business should have access to enterprise-level technology',
      values: ['Accessibility', 'Innovation', 'Community', 'Empowerment'],
      personality: ['Friendly', 'Approachable', 'Helpful', 'Energetic'],
      voiceDescription: 'Supportive and understanding with a friendly, encouraging tone',
      toneAttributes: {
        formal: 4,
        friendly: 9,
        authoritative: 6,
        innovative: 8,
        trustworthy: 8
      },
      communicationStyle: 'Conversational, supportive, and action-oriented',
      messagingFramework: {
        primary: 'Technology made simple',
        secondary: ['Growing together', 'Your partner in success'],
        support: ['Affordable solutions', 'Easy to use', 'Always here to help']
      },
      brandPillars: ['Simplicity', 'Affordability', 'Support', 'Growth'],
      targetAudience: {
        primary: 'Small business owners aged 30-50',
        secondary: 'Entrepreneurs and solopreneurs',
        demographics: {
          age_range: '30-50',
          job_titles: ['Business Owner', 'Entrepreneur', 'Founder', 'Manager'],
          company_size: '1-50 employees',
          industry: ['Retail', 'Services', 'Consulting', 'E-commerce']
        }
      },
      competitivePosition: 'Affordable tech solutions for SMBs',
      brandPromise: 'Making enterprise technology accessible and affordable for every small business',
      complianceRules: {
        'tone_guidelines': 'Always maintain friendly, supportive tone - never condescending',
        'imagery_guidelines': 'Use diverse, authentic imagery showing real small business scenarios'
      },
      usageGuidelines: {
        'do': ['Use warm, approachable language', 'Show real business scenarios', 'Emphasize simplicity'],
        'dont': ['Use technical jargon', 'Appear corporate or cold', 'Overwhelm with features']
      },
      restrictedTerms: ['enterprise', 'complex', 'advanced', 'sophisticated'],
      userId: user2.id,
      createdBy: user2.id,
    },
  })

  const brand3 = await prisma.brand.create({
    data: {
      name: 'EcoGreen Solutions',
      description: 'Premium eco-friendly products for conscious consumers',
      industry: 'Consumer Goods',
      website: 'https://ecogreensolutions.com',
      tagline: 'Naturally Better',
      mission: 'Creating sustainable solutions for a better planet',
      vision: 'A world where every choice contributes to environmental healing',
      values: ['Sustainability', 'Transparency', 'Impact', 'Authenticity'],
      personality: ['Authentic', 'Responsible', 'Forward-thinking', 'Inspiring'],
      voiceDescription: 'Passionate and knowledgeable with an inspiring, authentic tone',
      toneAttributes: {
        formal: 5,
        friendly: 7,
        authoritative: 7,
        innovative: 8,
        trustworthy: 9
      },
      communicationStyle: 'Inspiring, educational, and action-oriented',
      messagingFramework: {
        primary: 'Sustainability without compromise',
        secondary: ['Every choice makes a difference', 'Building a better tomorrow'],
        support: ['Science-backed solutions', 'Transparent practices', 'Proven impact']
      },
      brandPillars: ['Sustainability', 'Quality', 'Transparency', 'Impact'],
      targetAudience: {
        primary: 'Environmentally conscious consumers aged 25-45',
        secondary: 'Eco-minded families and professionals',
        demographics: {
          age_range: '25-45',
          job_titles: ['Professional', 'Parent', 'Educator', 'Healthcare Worker'],
          company_size: 'Individual consumers',
          industry: ['Any - environmental focus']
        }
      },
      competitivePosition: 'Premium eco-friendly product leader with proven environmental impact',
      brandPromise: 'Products that are better for you and better for the planet',
      complianceRules: {
        'sustainability_claims': 'All environmental claims must be verified and documented',
        'imagery_guidelines': 'Use only authentic, natural imagery - no greenwashing'
      },
      usageGuidelines: {
        'do': ['Use natural, authentic imagery', 'Back up claims with data', 'Show real environmental impact'],
        'dont': ['Make unsubstantiated claims', 'Use artificial or fake imagery', 'Greenwash messaging']
      },
      restrictedTerms: ['artificial', 'synthetic', 'chemical', 'wasteful'],
      userId: user1.id,
      createdBy: user1.id,
    },
  })

  // Create brand assets for the brands
  console.log('🎨 Creating brand assets...')
  
  // ACME Corporation Assets
  const acmeLogoAsset = await prisma.brandAsset.create({
    data: {
      brandId: brand1.id,
      name: 'ACME Corporation Primary Logo',
      description: 'Main horizontal logo for ACME Corporation',
      type: 'LOGO',
      category: 'Primary Identity',
      fileUrl: '/assets/brands/acme/logo-primary.svg',
      fileName: 'acme-logo-primary.svg',
      fileSize: 15420,
      mimeType: 'image/svg+xml',
      metadata: {
        dimensions: '400x120',
        colorMode: 'RGB',
        hasTransparency: true
      },
      tags: ['logo', 'primary', 'horizontal', 'svg'],
      version: '1.0',
      createdBy: user1.id,
    },
  })

  const acmeColorPalette = await prisma.colorPalette.create({
    data: {
      brandId: brand1.id,
      name: 'ACME Primary Color Palette',
      description: 'Main brand colors for ACME Corporation',
      colors: [
        { name: 'ACME Blue', hex: '#1E40AF', rgb: '30, 64, 175', usage: 'Primary brand color' },
        { name: 'Light Blue', hex: '#3B82F6', rgb: '59, 130, 246', usage: 'Secondary actions' },
        { name: 'Accent Blue', hex: '#93C5FD', rgb: '147, 197, 253', usage: 'Backgrounds and accents' },
        { name: 'Dark Gray', hex: '#1F2937', rgb: '31, 41, 55', usage: 'Text and headers' },
        { name: 'Medium Gray', hex: '#6B7280', rgb: '107, 114, 128', usage: 'Body text' },
        { name: 'Light Gray', hex: '#D1D5DB', rgb: '209, 213, 219', usage: 'Borders and dividers' }
      ],
      isPrimary: true,
      createdBy: user1.id,
    },
  })

  const acmeTypography = await prisma.typography.create({
    data: {
      brandId: brand1.id,
      name: 'ACME Primary Font - Inter',
      description: 'Primary typeface for ACME Corporation',
      fontFamily: 'Inter',
      fontWeight: '400',
      fontSize: '16px',
      lineHeight: '1.5',
      letterSpacing: '0',
      usage: 'Primary font for all text content',
      isPrimary: true,
      fallbackFonts: ['system-ui', 'sans-serif'],
      createdBy: user1.id,
    },
  })

  // TechFlow Startup Assets
  const techflowBrandAsset = await prisma.brandAsset.create({
    data: {
      brandId: brand2.id,
      name: 'TechFlow Brand Guidelines',
      description: 'Complete brand guidelines document',
      type: 'BRAND_GUIDELINES',
      category: 'Documentation',
      fileUrl: '/assets/brands/techflow/brand-guidelines.pdf',
      fileName: 'techflow-brand-guidelines.pdf',
      fileSize: 2845600,
      mimeType: 'application/pdf',
      metadata: {
        pages: 24,
        version: '2.1'
      },
      tags: ['guidelines', 'documentation', 'brand'],
      version: '2.1',
      createdBy: user2.id,
    },
  })

  const techflowColorPalette = await prisma.colorPalette.create({
    data: {
      brandId: brand2.id,
      name: 'TechFlow Energetic Palette',
      description: 'Vibrant color palette reflecting innovation and energy',
      colors: [
        { name: 'TechFlow Green', hex: '#10B981', rgb: '16, 185, 129', usage: 'Primary brand color' },
        { name: 'Light Green', hex: '#34D399', rgb: '52, 211, 153', usage: 'Call-to-action buttons' },
        { name: 'Mint Green', hex: '#A7F3D0', rgb: '167, 243, 208', usage: 'Backgrounds and highlights' },
        { name: 'Charcoal', hex: '#374151', rgb: '55, 65, 81', usage: 'Headers and important text' },
        { name: 'Gray', hex: '#9CA3AF', rgb: '156, 163, 175', usage: 'Supporting text' },
        { name: 'Off White', hex: '#F3F4F6', rgb: '243, 244, 246', usage: 'Backgrounds' }
      ],
      isPrimary: true,
      createdBy: user2.id,
    },
  })

  // EcoGreen Solutions Assets
  const ecoLogo = await prisma.brandAsset.create({
    data: {
      brandId: brand3.id,
      name: 'EcoGreen Leaf Logo',
      description: 'Iconic leaf logo representing natural solutions',
      type: 'LOGO',
      category: 'Primary Identity',
      fileUrl: '/assets/brands/ecogreen/logo-leaf.svg',
      fileName: 'ecogreen-logo-leaf.svg',
      fileSize: 8950,
      mimeType: 'image/svg+xml',
      metadata: {
        dimensions: '300x300',
        colorMode: 'RGB',
        hasTransparency: true,
        symbolism: 'Leaf represents growth and sustainability'
      },
      tags: ['logo', 'leaf', 'nature', 'sustainable'],
      version: '1.0',
      createdBy: user1.id,
    },
  })

  const ecoColorPalette = await prisma.colorPalette.create({
    data: {
      brandId: brand3.id,
      name: 'EcoGreen Natural Palette',
      description: 'Earth-inspired colors reflecting sustainability',
      colors: [
        { name: 'Forest Green', hex: '#059669', rgb: '5, 150, 105', usage: 'Primary brand color' },
        { name: 'Bright Green', hex: '#34D399', rgb: '52, 211, 153', usage: 'Accents and highlights' },
        { name: 'Mint', hex: '#D1FAE5', rgb: '209, 250, 229', usage: 'Soft backgrounds' },
        { name: 'Earth Brown', hex: '#92400E', rgb: '146, 64, 14', usage: 'Natural contrast' },
        { name: 'Warm Yellow', hex: '#F59E0B', rgb: '245, 158, 11', usage: 'Energy and optimism' },
        { name: 'Light Cream', hex: '#FDE68A', rgb: '253, 230, 138', usage: 'Warm backgrounds' }
      ],
      isPrimary: true,
      createdBy: user1.id,
    },
  })

  // Create campaigns with different statuses
  console.log('📈 Creating campaigns...')
  const campaign1 = await prisma.campaign.create({
    data: {
      name: 'Q1 Product Launch Campaign',
      purpose: 'Launch new enterprise software solution',
      brandId: brand1.id,
      userId: user1.id,
      status: 'ACTIVE',
      createdBy: user1.id,
      startDate: new Date('2025-01-01'),
      endDate: new Date('2025-03-31'),
      goals: {
        primary: 'Generate 500 qualified leads',
        secondary: ['Increase brand awareness by 25%', 'Drive 10,000 website visits'],
        metrics: {
          lead_target: 500,
          awareness_lift: 25,
          website_visits: 10000,
          conversion_rate: 0.03
        }
      }
    },
  })

  const campaign2 = await prisma.campaign.create({
    data: {
      name: 'Small Business Growth Series',
      purpose: 'Educational content series for SMB audience',
      brandId: brand2.id,
      userId: user2.id,
      status: 'DRAFT',
      createdBy: user2.id,
      goals: {
        primary: 'Build thought leadership',
        secondary: ['Grow email list by 1000 subscribers', 'Increase social media following'],
        metrics: {
          email_subscribers: 1000,
          social_followers: 500,
          content_engagement: 0.05
        }
      }
    },
  })

  const campaign3 = await prisma.campaign.create({
    data: {
      name: 'Sustainability Awareness Drive',
      purpose: 'Educate consumers about sustainable choices',
      brandId: brand3.id,
      userId: user1.id,
      status: 'ACTIVE',
      createdBy: user1.id,
      startDate: new Date('2025-02-01'),
      endDate: new Date('2025-04-30'),
      goals: {
        primary: 'Increase eco-product sales by 40%',
        secondary: ['Build community of eco-advocates', 'Improve brand perception'],
        metrics: {
          sales_increase: 40,
          community_members: 2000,
          sentiment_score: 8.5
        }
      }
    },
  })

  const campaign4 = await prisma.campaign.create({
    data: {
      name: 'Customer Success Stories',
      purpose: 'Showcase customer achievements',
      brandId: brand1.id,
      userId: user1.id,
      status: 'COMPLETED',
      createdBy: user1.id,
      startDate: new Date('2024-10-01'),
      endDate: new Date('2024-12-31'),
      goals: {
        primary: 'Build social proof and credibility',
        secondary: ['Generate referrals', 'Improve customer retention'],
        metrics: {
          case_studies: 12,
          referrals: 25,
          retention_rate: 95
        }
      }
    },
  })

  const campaign5 = await prisma.campaign.create({
    data: {
      name: 'Holiday Promotion 2025',
      purpose: 'Seasonal promotional campaign',
      brandId: brand2.id,
      userId: user2.id,
      status: 'PAUSED',
      createdBy: user2.id,
      goals: {
        primary: 'Increase Q4 revenue by 30%',
        secondary: ['Clear seasonal inventory', 'Acquire new customers'],
        metrics: {
          revenue_increase: 30,
          inventory_clearance: 80,
          new_customers: 200
        }
      }
    },
  })

  // Create journeys with detailed stages
  console.log('🗺️ Creating journeys...')
  const journey1 = await prisma.journey.create({
    data: {
      campaignId: campaign1.id,
      status: 'ACTIVE',
      createdBy: user1.id,
      stages: [
        {
          id: 'stage_1',
          name: 'Awareness',
          order: 1,
          description: 'Generate initial awareness through content marketing',
          duration_days: 14,
          triggers: ['blog_post_view', 'social_media_click'],
          content_types: ['BLOG_POST', 'SOCIAL_POST'],
          automation_rules: {
            entry_criteria: ['visited_website'],
            exit_criteria: ['downloaded_whitepaper', 'requested_demo']
          }
        },
        {
          id: 'stage_2',
          name: 'Consideration',
          order: 2,
          description: 'Nurture leads with educational content',
          duration_days: 21,
          triggers: ['whitepaper_download', 'webinar_registration'],
          content_types: ['EMAIL', 'VIDEO_SCRIPT'],
          automation_rules: {
            entry_criteria: ['downloaded_content'],
            exit_criteria: ['demo_requested', 'pricing_page_visit']
          }
        },
        {
          id: 'stage_3',
          name: 'Decision',
          order: 3,
          description: 'Convert qualified leads to customers',
          duration_days: 7,
          triggers: ['demo_completed', 'proposal_sent'],
          content_types: ['EMAIL', 'LANDING_PAGE'],
          automation_rules: {
            entry_criteria: ['demo_attended'],
            exit_criteria: ['contract_signed', 'deal_lost']
          }
        }
      ]
    },
  })

  const journey2 = await prisma.journey.create({
    data: {
      campaignId: campaign2.id,
      status: 'DRAFT',
      createdBy: user2.id,
      stages: [
        {
          id: 'stage_1',
          name: 'Discovery',
          order: 1,
          description: 'Attract small business owners seeking growth advice',
          duration_days: 7,
          triggers: ['content_view', 'newsletter_signup'],
          content_types: ['BLOG_POST', 'NEWSLETTER'],
          automation_rules: {
            entry_criteria: ['organic_search', 'social_referral'],
            exit_criteria: ['email_subscribed']
          }
        },
        {
          id: 'stage_2',
          name: 'Engagement',
          order: 2,
          description: 'Deliver valuable business growth insights',
          duration_days: 30,
          triggers: ['email_open', 'content_share'],
          content_types: ['EMAIL', 'INFOGRAPHIC'],
          automation_rules: {
            entry_criteria: ['newsletter_subscribed'],
            exit_criteria: ['high_engagement_score']
          }
        }
      ]
    },
  })

  const journey3 = await prisma.journey.create({
    data: {
      campaignId: campaign3.id,
      status: 'ACTIVE',
      createdBy: user1.id,
      stages: [
        {
          id: 'stage_1',
          name: 'Education',
          order: 1,
          description: 'Educate about environmental impact',
          duration_days: 10,
          triggers: ['sustainability_content_view'],
          content_types: ['BLOG_POST', 'INFOGRAPHIC'],
          automation_rules: {
            entry_criteria: ['eco_interest_indicator'],
            exit_criteria: ['sustainability_score_threshold']
          }
        },
        {
          id: 'stage_2',
          name: 'Action',
          order: 2,
          description: 'Encourage sustainable product adoption',
          duration_days: 14,
          triggers: ['product_view', 'calculator_use'],
          content_types: ['EMAIL', 'LANDING_PAGE'],
          automation_rules: {
            entry_criteria: ['education_completed'],
            exit_criteria: ['product_purchased', 'subscription_created']
          }
        }
      ]
    },
  })

  // Create content pieces with variants
  console.log('📝 Creating content...')
  const content1 = await prisma.content.create({
    data: {
      journeyId: journey1.id,
      type: 'EMAIL',
      status: 'PUBLISHED',
      createdBy: user1.id,
      content: JSON.stringify({
        subject: 'Transform Your Enterprise Operations Today',
        preheader: 'Discover how industry leaders are achieving 40% efficiency gains',
        body: `
          <p>Hello {{first_name}},</p>
          
          <p>Are you ready to revolutionize how your enterprise operates? 
          Leading companies are achieving remarkable results with our latest solution:</p>
          
          <ul>
            <li>40% increase in operational efficiency</li>
            <li>60% reduction in manual processes</li>
            <li>25% improvement in team productivity</li>
          </ul>
          
          <p>Join the innovation leaders who trust ACME Corporation to deliver excellence.</p>
          
          <a href="{{demo_link}}" style="background: #1E40AF; color: white; padding: 12px 24px; text-decoration: none; border-radius: 6px;">
            Schedule Your Demo
          </a>
          
          <p>Best regards,<br>
          The ACME Team</p>
        `,
        cta_text: 'Schedule Your Demo',
        cta_url: '{{demo_link}}'
      }),
      variants: [
        {
          name: 'Version A - Benefits Focus',
          subject: 'Transform Your Enterprise Operations Today',
          primary_cta: 'Schedule Your Demo',
          variation_type: 'benefit_focused'
        },
        {
          name: 'Version B - Urgency Focus',
          subject: 'Limited Time: Enterprise Transformation Offer',
          primary_cta: 'Claim Your Spot',
          variation_type: 'urgency_focused'
        }
      ],
      metadata: {
        target_audience: 'enterprise_decision_makers',
        send_time: '09:00 AM',
        timezone: 'EST',
        personalization_fields: ['first_name', 'company_name', 'demo_link'],
        tracking_enabled: true,
        ab_test_percentage: 50
      }
    },
  })

  const content2 = await prisma.content.create({
    data: {
      journeyId: journey2.id,
      type: 'BLOG_POST',
      status: 'APPROVED',
      createdBy: user2.id,
      content: JSON.stringify({
        title: '5 Proven Strategies to Scale Your Small Business in 2025',
        slug: '5-proven-strategies-scale-small-business-2025',
        excerpt: 'Discover the essential strategies that successful small businesses use to achieve sustainable growth and overcome common scaling challenges.',
        body: `
          <h1>5 Proven Strategies to Scale Your Small Business in 2025</h1>
          
          <p>Growing a small business requires more than just hard work—it demands strategic thinking and proven methodologies...</p>
          
          <h2>1. Leverage Technology for Automation</h2>
          <p>Smart automation can free up 20+ hours per week for strategic work...</p>
          
          <h2>2. Build Strategic Partnerships</h2>
          <p>Collaborative partnerships can expand your reach without additional overhead...</p>
          
          <h2>3. Focus on Customer Retention</h2>
          <p>It costs 5x more to acquire new customers than retain existing ones...</p>
          
          <h2>4. Develop Scalable Systems</h2>
          <p>Document your processes now to avoid bottlenecks later...</p>
          
          <h2>5. Invest in Your Team</h2>
          <p>Your people are your greatest asset for sustainable growth...</p>
          
          <h2>Ready to Transform Your Business?</h2>
          <p>TechFlow Startup provides the tools and guidance you need to implement these strategies effectively.</p>
        `,
        featured_image: '/images/blog/small-business-scaling-2025.jpg',
        tags: ['growth', 'small business', 'strategy', 'automation', 'scaling'],
        reading_time: 8,
        author: 'Sarah Johnson'
      }),
      variants: [
        {
          name: 'Standard Version',
          title: '5 Proven Strategies to Scale Your Small Business in 2025',
          focus: 'comprehensive_guide'
        },
        {
          name: 'Quick Tips Version',
          title: 'Quick Wins: 5 Small Business Scaling Strategies',
          focus: 'actionable_tips'
        }
      ],
      metadata: {
        seo_title: '5 Proven Small Business Scaling Strategies for 2025 | TechFlow',
        meta_description: 'Learn 5 proven strategies to scale your small business in 2025. Expert tips on automation, partnerships, retention, systems, and team development.',
        canonical_url: '/blog/5-proven-strategies-scale-small-business-2025',
        publish_date: '2025-02-01T09:00:00Z',
        category: 'Growth Strategy',
        content_type: 'educational'
      }
    },
  })

  const content3 = await prisma.content.create({
    data: {
      journeyId: journey3.id,
      type: 'INFOGRAPHIC',
      status: 'DRAFT',
      createdBy: user1.id,
      content: JSON.stringify({
        title: 'Your Daily Impact: Small Changes, Big Results',
        sections: [
          {
            title: 'Morning Routine',
            items: [
              'Use a reusable water bottle - Save 167 plastic bottles/year',
              'Choose sustainable transport - Reduce 2.6 tons CO2/year',
              'Digital receipts only - Save 11.2 million trees annually'
            ]
          },
          {
            title: 'At Work',
            items: [
              'Go paperless - Save 400 lbs paper/person/year',
              'Energy-efficient devices - Reduce 30% electricity use',
              'Sustainable lunch choices - Cut 1,000 lbs CO2/year'
            ]
          },
          {
            title: 'Evening Impact',
            items: [
              'LED lighting - 75% less energy consumption',
              'Eco-friendly products - Support circular economy',
              'Mindful consumption - Reduce waste by 40%'
            ]
          }
        ],
        call_to_action: {
          text: 'Start Your Sustainable Journey Today',
          url: '/products/eco-starter-kit',
          description: 'Get our complete eco-friendly starter kit'
        },
        design_notes: {
          color_scheme: 'earth_tones',
          style: 'modern_minimalist',
          icons: 'line_style',
          layout: 'vertical_timeline'
        }
      }),
      variants: [
        {
          name: 'Detailed Stats Version',
          focus: 'statistics_heavy',
          target: 'data_driven_audience'
        },
        {
          name: 'Simple Actions Version',
          focus: 'actionable_steps',
          target: 'beginner_eco_audience'
        }
      ],
      metadata: {
        dimensions: '800x2400',
        format: 'PNG',
        social_optimized: true,
        print_ready: false,
        accessibility_alt_text: 'Infographic showing daily sustainable actions and their environmental impact',
        usage_rights: 'internal_and_social_media'
      }
    },
  })

  // Create content templates
  console.log('📋 Creating content templates...')
  const template1 = await prisma.contentTemplate.create({
    data: {
      type: 'EMAIL',
      category: 'Welcome Series',
      createdBy: user1.id,
      template: JSON.stringify({
        subject: 'Welcome to {{brand_name}}, {{first_name}}!',
        preheader: 'We\'re excited to have you join our community',
        body: `
          <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
            <h1 style="color: {{brand_primary_color}};">Welcome to {{brand_name}}!</h1>
            
            <p>Hi {{first_name}},</p>
            
            <p>Thank you for joining the {{brand_name}} community! We're thrilled to have you on board and can't wait to help you {{value_proposition}}.</p>
            
            <div style="background: #f8f9fa; padding: 20px; border-radius: 8px; margin: 20px 0;">
              <h2>What's Next?</h2>
              <ul>
                <li>{{next_step_1}}</li>
                <li>{{next_step_2}}</li>
                <li>{{next_step_3}}</li>
              </ul>
            </div>
            
            <p>If you have any questions, don't hesitate to reach out. We're here to help!</p>
            
            <a href="{{getting_started_link}}" style="background: {{brand_primary_color}}; color: white; padding: 12px 24px; text-decoration: none; border-radius: 6px; display: inline-block; margin: 20px 0;">
              {{cta_text}}
            </a>
            
            <p>Best regards,<br>
            The {{brand_name}} Team</p>
          </div>
        `
      }),
      variables: {
        required: ['brand_name', 'first_name', 'brand_primary_color', 'value_proposition', 'cta_text'],
        optional: ['next_step_1', 'next_step_2', 'next_step_3', 'getting_started_link'],
        defaults: {
          cta_text: 'Get Started',
          getting_started_link: '/getting-started'
        }
      }
    },
  })

  const template2 = await prisma.contentTemplate.create({
    data: {
      type: 'SOCIAL_POST',
      category: 'Product Announcement',
      createdBy: user2.id,
      template: JSON.stringify({
        platforms: ['twitter', 'linkedin', 'facebook'],
        content: {
          short: '🚀 Exciting news! {{product_name}} is here to {{main_benefit}}. {{cta_hashtag}} {{link}}',
          medium: '🎉 We\'re thrilled to announce {{product_name}}! \n\n✨ {{main_benefit}}\n🔥 {{key_feature_1}}\n💡 {{key_feature_2}}\n\n{{cta_text}} {{link}}\n\n{{hashtags}}',
          long: '🚀 Big announcement: {{product_name}} is officially here!\n\nAfter months of development and testing, we\'re excited to share a solution that {{main_benefit}}.\n\n🌟 Key highlights:\n• {{key_feature_1}}\n• {{key_feature_2}}\n• {{key_feature_3}}\n\n{{social_proof}}\n\n{{cta_text}} {{link}}\n\n{{hashtags}}'
        },
        media: {
          image_style: '{{brand_visual_style}}',
          video_length: '{{video_duration}}',
          aspect_ratios: ['1:1', '16:9', '9:16']
        }
      }),
      variables: {
        required: ['product_name', 'main_benefit', 'link'],
        optional: ['key_feature_1', 'key_feature_2', 'key_feature_3', 'social_proof', 'hashtags', 'cta_text'],
        defaults: {
          cta_text: 'Learn more:',
          hashtags: '#Innovation #NewProduct #TechNews'
        }
      }
    },
  })

  const template3 = await prisma.contentTemplate.create({
    data: {
      type: 'BLOG_POST',
      category: 'How-To Guide',
      createdBy: user1.id,
      template: JSON.stringify({
        structure: {
          title: 'How to {{main_action}}: {{benefit_promise}}',
          excerpt: 'Learn {{skill_description}} with our step-by-step guide. {{outcome_promise}} in {{timeframe}}.',
          introduction: 'Introduction paragraph explaining {{problem_statement}} and how this guide will help {{target_audience}} achieve {{desired_outcome}}.',
          sections: [
            {
              heading: 'Understanding {{topic_basics}}',
              content: 'Explanation of fundamental concepts...'
            },
            {
              heading: 'Step-by-Step Process',
              content: 'Detailed walkthrough with {{step_count}} actionable steps...'
            },
            {
              heading: 'Common Mistakes to Avoid',
              content: 'Warning about typical pitfalls and how to prevent them...'
            },
            {
              heading: 'Tools and Resources',
              content: 'Recommended tools and additional resources...'
            },
            {
              heading: 'Conclusion and Next Steps',
              content: 'Summary and guidance on what to do next...'
            }
          ]
        },
        seo: {
          title_template: 'How to {{main_action}} | {{brand_name}} {{current_year}} Guide',
          meta_description: 'Complete guide on {{main_action}}. {{benefit_promise}} with expert tips and {{step_count}} proven steps. {{cta_text}}',
          keywords: ['{{main_keyword}}', '{{secondary_keyword_1}}', '{{secondary_keyword_2}}']
        }
      }),
      variables: {
        required: ['main_action', 'benefit_promise', 'target_audience', 'desired_outcome'],
        optional: ['timeframe', 'step_count', 'problem_statement', 'skill_description', 'outcome_promise'],
        defaults: {
          timeframe: 'just a few steps',
          step_count: '5',
          cta_text: 'Get started today!'
        }
      }
    },
  })

  // Create sample analytics data
  console.log('📊 Creating analytics data...')
  const analyticsData = [
    {
      campaignId: campaign1.id,
      journeyId: journey1.id,
      contentId: content1.id,
      eventType: 'IMPRESSION' as const,
      metrics: { count: 5420, cost: 245.50, cpm: 45.30 },
      source: 'google_ads',
      timestamp: new Date('2025-02-01T09:00:00Z'),
      createdBy: user1.id
    },
    {
      campaignId: campaign1.id,
      journeyId: journey1.id,
      contentId: content1.id,
      eventType: 'CLICK' as const,
      metrics: { count: 324, cost: 67.80, cpc: 0.21, ctr: 0.0598 },
      source: 'google_ads',
      timestamp: new Date('2025-02-01T10:30:00Z'),
      createdBy: user1.id
    },
    {
      campaignId: campaign1.id,
      journeyId: journey1.id,
      contentId: content1.id,
      eventType: 'CONVERSION' as const,
      metrics: { count: 12, revenue: 18500.00, conversion_rate: 0.037 },
      source: 'website',
      timestamp: new Date('2025-02-01T14:15:00Z'),
      createdBy: user1.id
    },
    {
      campaignId: campaign3.id,
      journeyId: journey3.id,
      contentId: content3.id,
      eventType: 'VIEW' as const,
      metrics: { count: 2890, engagement_time: 145, bounce_rate: 0.23 },
      source: 'organic_social',
      timestamp: new Date('2025-02-02T11:00:00Z'),
      createdBy: user1.id
    },
    {
      campaignId: campaign2.id,
      journeyId: journey2.id,
      contentId: content2.id,
      eventType: 'SHARE' as const,
      metrics: { count: 156, viral_coefficient: 1.8, reach_amplification: 2340 },
      source: 'social_media',
      timestamp: new Date('2025-02-02T16:45:00Z'),
      createdBy: user2.id
    }
  ]

  for (const data of analyticsData) {
    await prisma.analytics.create({ data })
  }

  console.log('✅ Database seeding completed successfully!')
  console.log(`
📊 Seeding Summary:
- 👤 Users: 2
- 🏢 Brands: 3 (with comprehensive profiles)
- 🎨 Brand Assets: 4
- 🎨 Color Palettes: 3
- 📝 Typography: 1
- 📈 Campaigns: 5
- 🗺️ Journeys: 3
- 📝 Content: 3
- 📋 Templates: 3
- 📊 Analytics: ${analyticsData.length}
  `)
}

main()
  .catch((e) => {
    console.error('❌ Error during seeding:', e)
    process.exit(1)
  })
  .finally(async () => {
    await prisma.$disconnect()
  })