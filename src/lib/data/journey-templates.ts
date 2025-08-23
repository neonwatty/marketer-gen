import {
  JourneyStageConfig,
  JourneyStageTypeValue,
  JourneyTemplate} from '@/lib/types/journey'

// Helper function to create stage configurations
const createStageConfig = (
  type: JourneyStageTypeValue,
  title: string,
  description: string,
  contentTypes: string[],
  messagingSuggestions: string[],
  position: { x: number; y: number },
  channels?: string[],
  objectives?: string[],
  duration?: number
): JourneyStageConfig => ({
  id: `stage-${Date.now()}-${Math.random().toString(36).substr(2, 9)}`,
  type,
  title,
  description,
  position,
  contentTypes,
  messagingSuggestions,
  channels: channels || [],
  objectives: objectives || [],
  metrics: [],
  duration: duration || 7,
  automations: [],
})

// SaaS Industry Templates
export const saasTemplates: Omit<JourneyTemplate, 'id' | 'createdAt' | 'updatedAt' | 'usageCount' | 'ratingCount'>[] = [
  {
    name: 'SaaS Free Trial Conversion',
    description: 'Convert free trial users into paying customers through strategic nurturing and value demonstration',
    industry: 'SAAS',
    category: 'CUSTOMER_ACQUISITION',
    isActive: true,
    isPublic: true,
    rating: 4.8,
    stages: [
      createStageConfig(
        'awareness',
        'Trial Signup',
        'Welcome new users and help them understand the product value',
        ['Welcome Email', 'Product Tour', 'Getting Started Guide'],
        [
          'Welcome to your free trial!',
          'Here\'s what you can achieve in the next 14 days',
          'Let us help you get started quickly',
        ],
        { x: 100, y: 100 },
        ['email', 'in_app'],
        ['Complete onboarding', 'First value realization'],
        1
      ),
      createStageConfig(
        'consideration',
        'Feature Discovery',
        'Guide users through key features and use cases',
        ['Feature Tutorials', 'Use Case Examples', 'Best Practices'],
        [
          'Discover how [Feature] can save you hours each week',
          'See how companies like yours use our platform',
          'Pro tip: Try this advanced workflow',
        ],
        { x: 400, y: 100 },
        ['email', 'in_app', 'webinars'],
        ['Feature adoption', 'Increased engagement'],
        3
      ),
      createStageConfig(
        'conversion',
        'Trial Extension & Upgrade',
        'Convert trial users with compelling upgrade offers and time-sensitive incentives',
        ['Upgrade Prompts', 'ROI Calculators', 'Limited-time Offers'],
        [
          'Your trial expires tomorrow - don\'t lose your progress',
          'Upgrade now and save 20% on your first year',
          'Based on your usage, you could save $X monthly',
        ],
        { x: 700, y: 100 },
        ['email', 'in_app', 'sales_outreach'],
        ['Convert to paid plan', 'Maximize trial value'],
        2
      ),
      createStageConfig(
        'retention',
        'New Customer Success',
        'Ensure successful onboarding and early value realization for new customers',
        ['Success Metrics', 'Check-in Calls', 'Advanced Training'],
        [
          'Congratulations on upgrading! Let\'s ensure your success',
          'You\'ve achieved [milestone] - here\'s what\'s next',
          'Join our advanced users community',
        ],
        { x: 1000, y: 100 },
        ['email', 'phone', 'community'],
        ['Reduce churn risk', 'Expand usage'],
        7
      ),
    ],
    metadata: {
      tags: ['saas', 'free-trial', 'conversion', 'onboarding'],
      difficulty: 'intermediate',
      estimatedDuration: 14,
      requiredChannels: ['email', 'in_app'],
      targetAudience: ['trial users', 'potential customers'],
      businessGoals: ['increase trial conversion', 'reduce time to value'],
      kpis: ['trial-to-paid conversion rate', 'time to first value', 'feature adoption rate'],
    },
    customizationConfig: {
      allowStageReordering: true,
      allowStageAddition: true,
      allowStageDeletion: false,
      editableFields: ['title', 'description', 'contentTypes', 'messagingSuggestions', 'duration'],
      requiredFields: ['title', 'description'],
    },
    defaultSettings: {
      timezone: 'UTC',
      workingHours: { start: '09:00', end: '17:00' },
      workingDays: [1, 2, 3, 4, 5],
      defaultChannels: ['email', 'in_app'],
      brandCompliance: true,
      autoOptimization: true,
      trackingSettings: {
        enableAnalytics: true,
        trackConversions: true,
        customEvents: ['trial_signup', 'feature_adoption', 'upgrade_completed'],
      },
    },
  },
  {
    name: 'SaaS Customer Onboarding',
    description: 'Comprehensive onboarding journey for new SaaS customers to ensure rapid value realization',
    industry: 'SAAS',
    category: 'CUSTOMER_ONBOARDING',
    isActive: true,
    isPublic: true,
    rating: 4.6,
    stages: [
      createStageConfig(
        'awareness',
        'Welcome & Setup',
        'Welcome new customers and guide initial account setup',
        ['Welcome Package', 'Setup Checklist', 'Account Configuration'],
        [
          'Welcome to the [Company] family!',
          'Complete your setup in 5 easy steps',
          'Your dedicated success manager is here to help',
        ],
        { x: 100, y: 100 },
        ['email', 'in_app'],
        ['Complete account setup', 'Meet success manager'],
        2
      ),
      createStageConfig(
        'consideration',
        'Core Feature Training',
        'Train users on essential features and workflows',
        ['Video Tutorials', 'Interactive Walkthroughs', 'Live Training Sessions'],
        [
          'Master the essentials with our getting started series',
          'Join tomorrow\'s live training session',
          'Practice with our interactive tutorials',
        ],
        { x: 400, y: 100 },
        ['email', 'webinars', 'in_app'],
        ['Core feature proficiency', 'First successful workflow'],
        5
      ),
      createStageConfig(
        'conversion',
        'Advanced Adoption',
        'Drive adoption of advanced features and best practices',
        ['Advanced Tutorials', 'Best Practice Guides', 'Power User Tips'],
        [
          'Ready to unlock advanced capabilities?',
          'Optimize your workflow with these pro tips',
          'Join our power users community',
        ],
        { x: 700, y: 100 },
        ['email', 'community', 'webinars'],
        ['Advanced feature adoption', 'Workflow optimization'],
        7
      ),
      createStageConfig(
        'retention',
        'Success Monitoring',
        'Monitor customer success and provide ongoing support',
        ['Success Reviews', 'Health Checks', 'Expansion Opportunities'],
        [
          'Let\'s review your first month\'s progress',
          'You\'re achieving great results! Here\'s how to do even more',
          'Based on your success, consider expanding to [feature/team]',
        ],
        { x: 1000, y: 100 },
        ['email', 'phone', 'in_person'],
        ['Customer health score improvement', 'Identify expansion opportunities'],
        14
      ),
    ],
    metadata: {
      tags: ['saas', 'onboarding', 'customer-success', 'training'],
      difficulty: 'beginner',
      estimatedDuration: 30,
      requiredChannels: ['email', 'in_app', 'webinars'],
      targetAudience: ['new customers', 'recently converted'],
      businessGoals: ['reduce time to value', 'increase product adoption', 'improve retention'],
      kpis: ['time to first value', 'feature adoption rate', 'customer health score', 'support ticket volume'],
    },
    customizationConfig: {
      allowStageReordering: false,
      allowStageAddition: true,
      allowStageDeletion: false,
      editableFields: ['title', 'description', 'duration', 'messagingSuggestions'],
      requiredFields: ['title', 'description'],
    },
    defaultSettings: {
      timezone: 'UTC',
      workingHours: { start: '08:00', end: '18:00' },
      workingDays: [1, 2, 3, 4, 5],
      defaultChannels: ['email', 'in_app', 'webinars'],
      brandCompliance: true,
      autoOptimization: true,
      trackingSettings: {
        enableAnalytics: true,
        trackConversions: true,
        customEvents: ['onboarding_completed', 'first_value_achieved', 'advanced_feature_used'],
      },
    },
  },
]

// E-commerce Industry Templates
export const ecommerceTemplates: Omit<JourneyTemplate, 'id' | 'createdAt' | 'updatedAt' | 'usageCount' | 'ratingCount'>[] = [
  {
    name: 'E-commerce Cart Recovery',
    description: 'Win back customers who abandoned their shopping carts with targeted messaging and incentives',
    industry: 'ECOMMERCE',
    category: 'WIN_BACK',
    isActive: true,
    isPublic: true,
    rating: 4.7,
    stages: [
      createStageConfig(
        'awareness',
        'Gentle Reminder',
        'Send a friendly reminder about items left in cart',
        ['Abandoned Cart Email', 'Product Images', 'Simple CTA'],
        [
          'Don\'t forget about these items in your cart',
          'Your cart is waiting for you',
          'Complete your purchase before items sell out',
        ],
        { x: 100, y: 100 },
        ['email'],
        ['Cart recovery', 'Purchase completion'],
        1
      ),
      createStageConfig(
        'consideration',
        'Social Proof & Reviews',
        'Build confidence with social proof and customer reviews',
        ['Customer Reviews', 'Social Proof', 'Trust Badges'],
        [
          'See what other customers love about these products',
          'Join thousands of satisfied customers',
          'Rated 5 stars by verified buyers',
        ],
        { x: 400, y: 100 },
        ['email'],
        ['Build trust', 'Address hesitations'],
        2
      ),
      createStageConfig(
        'conversion',
        'Incentive & Urgency',
        'Provide incentives and create urgency to complete purchase',
        ['Discount Codes', 'Limited-time Offers', 'Inventory Alerts'],
        [
          'Complete your order and save 10% - limited time',
          'Only 2 items left in stock!',
          'This discount expires in 24 hours',
        ],
        { x: 700, y: 100 },
        ['email', 'sms'],
        ['Convert abandoned carts', 'Clear inventory'],
        1
      ),
      createStageConfig(
        'advocacy',
        'Post-Purchase Follow-up',
        'Follow up after successful recovery to build loyalty',
        ['Thank You Message', 'Order Updates', 'Review Requests'],
        [
          'Thanks for completing your purchase!',
          'Your order is on its way',
          'How was your shopping experience?',
        ],
        { x: 1000, y: 100 },
        ['email', 'sms'],
        ['Build loyalty', 'Encourage reviews'],
        3
      ),
    ],
    metadata: {
      tags: ['ecommerce', 'cart-recovery', 'abandoned-cart', 'conversion'],
      difficulty: 'beginner',
      estimatedDuration: 7,
      requiredChannels: ['email'],
      targetAudience: ['cart abandoners', 'potential customers'],
      businessGoals: ['recover lost sales', 'increase conversion rate', 'reduce cart abandonment'],
      kpis: ['cart recovery rate', 'email open rate', 'conversion rate', 'revenue recovered'],
    },
    customizationConfig: {
      allowStageReordering: true,
      allowStageAddition: true,
      allowStageDeletion: true,
      editableFields: ['title', 'description', 'contentTypes', 'messagingSuggestions', 'duration'],
      requiredFields: ['title', 'description'],
    },
    defaultSettings: {
      timezone: 'UTC',
      workingHours: { start: '00:00', end: '23:59' },
      workingDays: [0, 1, 2, 3, 4, 5, 6],
      defaultChannels: ['email', 'sms'],
      brandCompliance: true,
      autoOptimization: true,
      trackingSettings: {
        enableAnalytics: true,
        trackConversions: true,
        customEvents: ['cart_recovered', 'email_opened', 'purchase_completed'],
      },
    },
  },
]

// Healthcare Industry Templates  
export const healthcareTemplates: Omit<JourneyTemplate, 'id' | 'createdAt' | 'updatedAt' | 'usageCount' | 'ratingCount'>[] = [
  {
    name: 'Patient Onboarding Journey',
    description: 'Comprehensive patient onboarding for healthcare providers to ensure smooth care transitions',
    industry: 'HEALTHCARE',
    category: 'CUSTOMER_ONBOARDING',
    isActive: true,
    isPublic: true,
    rating: 4.5,
    stages: [
      createStageConfig(
        'awareness',
        'Welcome & Registration',
        'Welcome new patients and complete initial registration process',
        ['Welcome Packet', 'Registration Forms', 'Insurance Verification'],
        [
          'Welcome to [Practice Name] - we\'re here to care for you',
          'Complete your registration to streamline your first visit',
          'Have your insurance information ready for verification',
        ],
        { x: 100, y: 100 },
        ['email', 'phone', 'portal'],
        ['Complete registration', 'Verify insurance'],
        3
      ),
      createStageConfig(
        'consideration',
        'Pre-Visit Preparation',
        'Prepare patients for their first appointment with necessary information',
        ['Appointment Reminders', 'Pre-Visit Instructions', 'Medical History Forms'],
        [
          'Your appointment is confirmed for [date] at [time]',
          'Please complete your medical history before your visit',
          'Here\'s what to expect during your first appointment',
        ],
        { x: 400, y: 100 },
        ['email', 'sms', 'phone'],
        ['Reduce no-shows', 'Streamline appointment process'],
        2
      ),
      createStageConfig(
        'conversion',
        'First Visit Experience',
        'Ensure positive first visit experience and establish care relationship',
        ['Check-in Process', 'Care Team Introduction', 'Treatment Plan Discussion'],
        [
          'Check in easily using our mobile app',
          'Meet your care team and ask any questions',
          'Your personalized treatment plan is ready for review',
        ],
        { x: 700, y: 100 },
        ['in_person', 'portal'],
        ['Successful first visit', 'Establish care plan'],
        1
      ),
      createStageConfig(
        'retention',
        'Ongoing Care Management',
        'Maintain ongoing relationship through follow-up care and health monitoring',
        ['Follow-up Appointments', 'Health Monitoring', 'Educational Resources'],
        [
          'How are you feeling since your last visit?',
          'It\'s time for your follow-up appointment',
          'Here are resources to support your health goals',
        ],
        { x: 1000, y: 100 },
        ['email', 'phone', 'portal'],
        ['Maintain patient relationship', 'Improve health outcomes'],
        30
      ),
    ],
    metadata: {
      tags: ['healthcare', 'patient-onboarding', 'care-management', 'appointments'],
      difficulty: 'intermediate',
      estimatedDuration: 45,
      requiredChannels: ['email', 'phone', 'portal'],
      targetAudience: ['new patients', 'healthcare seekers'],
      businessGoals: ['improve patient experience', 'reduce no-shows', 'increase patient retention'],
      kpis: ['patient satisfaction score', 'appointment attendance rate', 'patient retention rate'],
    },
    customizationConfig: {
      allowStageReordering: false,
      allowStageAddition: true,
      allowStageDeletion: false,
      editableFields: ['description', 'messagingSuggestions', 'duration'],
      requiredFields: ['title', 'description'],
    },
    defaultSettings: {
      timezone: 'UTC',
      workingHours: { start: '08:00', end: '17:00' },
      workingDays: [1, 2, 3, 4, 5],
      defaultChannels: ['email', 'phone', 'portal'],
      brandCompliance: true,
      autoOptimization: false, // Healthcare requires manual oversight
      trackingSettings: {
        enableAnalytics: true,
        trackConversions: true,
        customEvents: ['registration_completed', 'appointment_scheduled', 'first_visit_completed'],
      },
    },
  },
]

// Technology Industry Templates
export const technologyTemplates: Omit<JourneyTemplate, 'id' | 'createdAt' | 'updatedAt' | 'usageCount' | 'ratingCount'>[] = [
  {
    name: 'Product Launch Campaign',
    description: 'Comprehensive product launch journey for technology companies to maximize awareness and adoption',
    industry: 'TECHNOLOGY',
    category: 'PRODUCT_LAUNCH',
    isActive: true,
    isPublic: true,
    rating: 4.9,
    stages: [
      createStageConfig(
        'awareness',
        'Pre-Launch Buzz',
        'Build anticipation and awareness before product launch',
        ['Teaser Campaigns', 'Beta Program', 'Industry PR'],
        [
          'Something revolutionary is coming - be the first to know',
          'Join our exclusive beta program and shape the future',
          'Industry leaders are already talking about what\'s next',
        ],
        { x: 100, y: 100 },
        ['social_media', 'email', 'pr'],
        ['Build awareness', 'Generate buzz'],
        14
      ),
      createStageConfig(
        'consideration',
        'Launch Event',
        'Execute high-impact launch event and drive initial adoption',
        ['Launch Event', 'Live Demos', 'Press Coverage'],
        [
          'Join us live for the official product reveal',
          'See the product in action with interactive demos',
          'Read what industry experts are saying about our launch',
        ],
        { x: 400, y: 100 },
        ['webinars', 'social_media', 'pr'],
        ['Event attendance', 'Demo engagement'],
        3
      ),
      createStageConfig(
        'conversion',
        'Early Adoption Drive',
        'Convert interested prospects into early adopters with special offers',
        ['Early Bird Offers', 'Free Trials', 'Customer Success Stories'],
        [
          'Be an early adopter and save 30% for the first year',
          'Start your free trial and experience the difference',
          'Join innovative companies already using our solution',
        ],
        { x: 700, y: 100 },
        ['email', 'sales_outreach', 'webinars'],
        ['Drive early adoption', 'Convert leads'],
        7
      ),
      createStageConfig(
        'advocacy',
        'Success & Expansion',
        'Nurture early adopters into advocates and expand market reach',
        ['Success Stories', 'Referral Program', 'Community Building'],
        [
          'Share your success story with the community',
          'Refer a colleague and earn exclusive rewards',
          'Join our community of innovative users',
        ],
        { x: 1000, y: 100 },
        ['community', 'email', 'events'],
        ['Build advocacy', 'Expand market reach'],
        30
      ),
    ],
    metadata: {
      tags: ['technology', 'product-launch', 'innovation', 'early-adoption'],
      difficulty: 'advanced',
      estimatedDuration: 60,
      requiredChannels: ['email', 'social_media', 'webinars', 'pr'],
      targetAudience: ['tech decision makers', 'early adopters', 'industry influencers'],
      businessGoals: ['successful product launch', 'market penetration', 'thought leadership'],
      kpis: ['launch event attendance', 'trial signup rate', 'early adoption rate', 'media mentions'],
    },
    customizationConfig: {
      allowStageReordering: true,
      allowStageAddition: true,
      allowStageDeletion: false,
      editableFields: ['title', 'description', 'contentTypes', 'messagingSuggestions', 'duration'],
      requiredFields: ['title', 'description'],
    },
    defaultSettings: {
      timezone: 'UTC',
      workingHours: { start: '09:00', end: '18:00' },
      workingDays: [1, 2, 3, 4, 5],
      defaultChannels: ['email', 'social_media', 'webinars'],
      brandCompliance: true,
      autoOptimization: true,
      trackingSettings: {
        enableAnalytics: true,
        trackConversions: true,
        customEvents: ['launch_event_registered', 'demo_viewed', 'trial_started', 'early_adopter_converted'],
      },
    },
  },
]

// Compile all templates
export const allJourneyTemplates: Omit<JourneyTemplate, 'id' | 'createdAt' | 'updatedAt' | 'usageCount' | 'ratingCount'>[] = [
  ...saasTemplates,
  ...ecommerceTemplates,
  ...healthcareTemplates,
  ...technologyTemplates,
]

// Template seeding function
export const seedJourneyTemplates = async () => {
  const templates = allJourneyTemplates.map(template => ({
    ...template,
    usageCount: Math.floor(Math.random() * 500) + 10, // Random usage between 10-510
    ratingCount: Math.floor(Math.random() * 100) + 5, // Random rating count between 5-105
  }))

  return templates
}