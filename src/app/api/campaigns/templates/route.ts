import '@/lib/types/auth'

import { NextRequest, NextResponse } from 'next/server'
import { getServerSession } from 'next-auth/next'

import { authOptions } from '@/lib/auth'
import { prisma } from '@/lib/db'
import {
  journeyTemplateRequestSchema} from '@/lib/validation/campaigns'

const JOURNEY_TEMPLATES = {
  'welcome-series': {
    name: 'Welcome Series',
    description: 'A multi-step welcome journey for new customers',
    stages: [
      {
        id: 'welcome-email',
        name: 'Welcome Email',
        type: 'email',
        delay: 0,
        conditions: [],
        content: {
          subject: 'Welcome to {{brand.name}}!',
          template: 'Welcome to our community! We\'re excited to have you on board.'
        }
      },
      {
        id: 'intro-guide',
        name: 'Introduction Guide',
        type: 'email',
        delay: 24, // hours
        conditions: [{ type: 'opened', target: 'welcome-email' }],
        content: {
          subject: 'Getting started with {{brand.name}}',
          template: 'Here\'s everything you need to know to get started.'
        }
      },
      {
        id: 'feature-highlight',
        name: 'Feature Highlight',
        type: 'email',
        delay: 72, // hours
        conditions: [{ type: 'clicked', target: 'intro-guide' }],
        content: {
          subject: 'Discover what makes {{brand.name}} special',
          template: 'Let us show you our most powerful features.'
        }
      }
    ]
  },
  'product-launch': {
    name: 'Product Launch',
    description: 'Multi-channel campaign for launching new products',
    stages: [
      {
        id: 'teaser-social',
        name: 'Teaser Social Post',
        type: 'social',
        delay: 0,
        conditions: [],
        content: {
          template: 'Something exciting is coming... 👀 #ComingSoon #{{brand.name}}'
        }
      },
      {
        id: 'announcement-email',
        name: 'Launch Announcement',
        type: 'email',
        delay: 24,
        conditions: [],
        content: {
          subject: 'Introducing {{product.name}} - Now Available!',
          template: 'We\'re thrilled to announce the launch of {{product.name}}!'
        }
      },
      {
        id: 'feature-demo',
        name: 'Feature Demo',
        type: 'video',
        delay: 48,
        conditions: [{ type: 'opened', target: 'announcement-email' }],
        content: {
          template: 'See {{product.name}} in action with this exclusive demo.'
        }
      }
    ]
  },
  're-engagement': {
    name: 'Re-engagement Series',
    description: 'Win back inactive customers with targeted messaging',
    stages: [
      {
        id: 'we-miss-you',
        name: 'We Miss You',
        type: 'email',
        delay: 0,
        conditions: [],
        content: {
          subject: 'We miss you at {{brand.name}}',
          template: 'It\'s been a while since we\'ve seen you. Here\'s what you\'ve missed.'
        }
      },
      {
        id: 'special-offer',
        name: 'Special Offer',
        type: 'email',
        delay: 72,
        conditions: [{ type: 'not-opened', target: 'we-miss-you' }],
        content: {
          subject: 'Just for you: {{discount}}% off your next purchase',
          template: 'Come back and enjoy this exclusive discount just for you.'
        }
      },
      {
        id: 'final-goodbye',
        name: 'Final Goodbye',
        type: 'email',
        delay: 168,
        conditions: [{ type: 'not-clicked', target: 'special-offer' }],
        content: {
          subject: 'One last message from {{brand.name}}',
          template: 'We understand if you want to move on. Here\'s how to unsubscribe.'
        }
      }
    ]
  },
  'abandoned-cart': {
    name: 'Abandoned Cart Recovery',
    description: 'Recover abandoned shopping carts with timely reminders',
    stages: [
      {
        id: 'cart-reminder',
        name: 'Cart Reminder',
        type: 'email',
        delay: 1,
        conditions: [],
        content: {
          subject: 'You left something in your cart',
          template: 'Don\'t forget about the items in your shopping cart!'
        }
      },
      {
        id: 'discount-incentive',
        name: 'Discount Incentive',
        type: 'email',
        delay: 24,
        conditions: [{ type: 'not-purchased', target: 'cart-reminder' }],
        content: {
          subject: '10% off your cart - Limited time!',
          template: 'Complete your purchase now and save 10% with code SAVE10.'
        }
      },
      {
        id: 'social-proof',
        name: 'Social Proof',
        type: 'email',
        delay: 72,
        conditions: [{ type: 'not-purchased', target: 'discount-incentive' }],
        content: {
          subject: 'Others are loving these items too',
          template: 'See why customers are raving about the items in your cart.'
        }
      }
    ]
  }
}

export async function GET() {
  try {
    const templates = Object.entries(JOURNEY_TEMPLATES).map(([key, template]) => ({
      id: key,
      ...template
    }))

    return NextResponse.json({ templates })
  } catch (error) {
    console.error('Error fetching journey templates:', error)
    return NextResponse.json(
      { error: 'Failed to fetch journey templates' },
      { status: 500 }
    )
  }
}

export async function POST(request: NextRequest) {
  try {
    const session = await getServerSession(authOptions)
    
    if (!session?.user?.id) {
      return NextResponse.json({ error: 'Unauthorized' }, { status: 401 })
    }

    const body = await request.json()
    
    // Validate request body
    const validation = journeyTemplateRequestSchema.safeParse(body)
    
    if (!validation.success) {
      return NextResponse.json(
        { error: 'Invalid request data', details: validation.error.format() },
        { status: 400 }
      )
    }

    const { templateId, campaignId, customizations } = validation.data

    const template = JOURNEY_TEMPLATES[templateId as keyof typeof JOURNEY_TEMPLATES]
    if (!template) {
      return NextResponse.json(
        { error: 'Template not found' },
        { status: 404 }
      )
    }

    // Verify the campaign exists and belongs to the user
    const campaign = await prisma.campaign.findUnique({
      where: {
        id: campaignId,
        userId: session.user.id,
        deletedAt: null
      }
    })

    if (!campaign) {
      return NextResponse.json(
        { error: 'Campaign not found or access denied' },
        { status: 404 }
      )
    }

    // Apply customizations to template stages
    const customizedStages = template.stages.map(stage => ({
      ...stage,
      ...customizations[stage.id] || {}
    }))

    // Create the journey with the template
    const journey = await prisma.journey.create({
      data: {
        campaignId,
        stages: customizedStages,
        status: 'DRAFT',
        createdBy: session.user.id,
        updatedBy: session.user.id
      },
      include: {
        campaign: {
          select: {
            id: true,
            name: true
          }
        }
      }
    })

    return NextResponse.json(journey, { status: 201 })
  } catch (error) {
    console.error('Error creating journey from template:', error)
    return NextResponse.json(
      { error: 'Failed to create journey from template' },
      { status: 500 }
    )
  }
}