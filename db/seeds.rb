# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).

puts "🌱 Seeding database..."

# Clear existing data in development/test
if Rails.env.development? || Rails.env.test?
  puts "🧹 Cleaning existing data..."
  ContentAsset.destroy_all
  CustomerJourney.destroy_all
  Campaign.destroy_all
  Template.destroy_all
  BrandIdentity.destroy_all
end

# Create Brand Identities
puts "🎨 Creating Brand Identities..."

acme_corp = BrandIdentity.create!(
  name: "Acme Corporation",
  description: "Leading provider of innovative business solutions",
  active: true,
  version: 1,
  color_palette: {
    primary: "#2563EB",
    secondary: "#64748B",
    accent: "#F59E0B",
    additional: ["#10B981", "#EF4444", "#8B5CF6"]
  },
  typography: {
    primary_font: {
      family: "Inter, sans-serif",
      weights: [400, 500, 600, 700]
    },
    secondary_font: {
      family: "Merriweather, serif",
      weights: [400, 700]
    },
    font_sizes: {
      small: "14px",
      medium: "16px",
      large: "24px",
      xlarge: "36px"
    }
  },
  guidelines: {
    logo_usage: {
      minimum_size: "24px",
      clear_space: "Equal to half the logo height",
      do_not: "Do not stretch, rotate, or change colors"
    },
    color_usage: {
      accessibility: {
        contrast_ratio: "4.5:1 minimum",
        colorblind_safe: true
      }
    }
  },
  messaging_frameworks: {
    voice: {
      tone: "Professional yet approachable",
      personality: ["Confident", "Innovative", "Trustworthy"]
    },
    key_messages: [
      "Innovation drives everything we do",
      "Your success is our priority",
      "Excellence in every solution"
    ],
    values: ["Innovation", "Integrity", "Excellence", "Collaboration"]
  },
  published_at: 1.month.ago
)

tech_startup = BrandIdentity.create!(
  name: "TechFlow Startup",
  description: "Cutting-edge technology solutions for modern businesses",
  active: false,
  version: 2,
  color_palette: {
    primary: "#7C3AED",
    secondary: "#1F2937",
    accent: "#06D6A0"
  },
  typography: {
    primary_font: {
      family: "Poppins, sans-serif",
      weights: [300, 400, 600, 700]
    }
  },
  guidelines: {
    logo_usage: {
      minimum_size: "20px",
      clear_space: "Logo width"
    }
  },
  messaging_frameworks: {
    voice: {
      tone: "Modern and energetic"
    },
    key_messages: ["Technology simplified", "Future-ready solutions"],
    values: ["Innovation", "Speed", "Reliability"]
  }
)

creative_agency = BrandIdentity.create!(
  name: "Creative Minds Agency",
  description: "Award-winning creative solutions",
  active: true,
  version: 1,
  color_palette: {
    primary: "#EC4899",
    secondary: "#F3F4F6",
    accent: "#FCD34D"
  },
  typography: {
    primary_font: {
      family: "Montserrat, sans-serif"
    },
    secondary_font: {
      family: "Playfair Display, serif"
    }
  },
  guidelines: {
    logo_usage: {
      minimum_size: "32px"
    }
  },
  messaging_frameworks: {
    voice: {
      tone: "Creative and inspiring"
    },
    key_messages: ["Creativity meets strategy", "Your vision, our expertise"]
  },
  published_at: 2.weeks.ago
)

# Create Campaigns
puts "📢 Creating Campaigns..."

summer_launch = Campaign.create!(
  name: "Summer Product Launch 2024",
  purpose: "Introduce our new summer collection to drive Q3 sales growth and increase brand awareness among millennials",
  status: "active",
  brand_identity: acme_corp,
  target_audience: {
    demographics: {
      age_range: "25-40",
      income: "$50k-$100k",
      interests: ["lifestyle", "technology", "sustainability"]
    },
    personas: ["tech-savvy professional", "eco-conscious consumer"]
  }.to_json,
  budget_cents: 5000000, # $50,000
  start_date: 1.week.from_now,
  end_date: 3.months.from_now
)

holiday_campaign = Campaign.create!(
  name: "Holiday Spectacular 2024",
  purpose: "Drive end-of-year sales through integrated digital and traditional marketing channels",
  status: "draft",
  brand_identity: creative_agency,
  target_audience: {
    demographics: {
      age_range: "30-55",
      income: "$75k+",
      interests: ["luxury", "family", "experiences"]
    }
  }.to_json,
  budget_cents: 7500000, # $75,000
  start_date: 2.months.from_now,
  end_date: 4.months.from_now
)

startup_awareness = Campaign.create!(
  name: "TechFlow Brand Awareness Campaign",
  purpose: "Establish brand presence in the competitive tech market and generate initial customer base",
  status: "completed",
  brand_identity: tech_startup,
  target_audience: {
    demographics: {
      age_range: "28-45",
      job_roles: ["CTO", "Engineering Manager", "Tech Lead"],
      company_size: "50-500 employees"
    }
  }.to_json,
  budget_cents: 2500000, # $25,000
  start_date: 6.months.ago,
  end_date: 3.months.ago
)

paused_campaign = Campaign.create!(
  name: "Paused Marketing Initiative",
  purpose: "Testing campaign pause functionality and workflow management",
  status: "paused",
  brand_identity: acme_corp,
  budget_cents: 1000000, # $10,000
  start_date: 1.month.ago,
  end_date: 2.months.from_now
)

# Create Customer Journeys
puts "🛤️  Creating Customer Journeys..."

awareness_journey = CustomerJourney.create!(
  campaign: summer_launch,
  name: "Summer Product Discovery Journey",
  description: "Multi-stage journey from initial awareness through purchase decision",
  position: 0,
  stages: [
    {
      id: "stage-1",
      name: "Awareness",
      description: "Customer discovers our brand through social media or search",
      duration_days: 7,
      position: 0,
      created_at: "2024-08-01T10:00:00Z"
    },
    {
      id: "stage-2",
      name: "Interest",
      description: "Customer visits website and browses products",
      duration_days: 14,
      position: 1,
      created_at: "2024-08-01T10:00:00Z"
    },
    {
      id: "stage-3",
      name: "Consideration",
      description: "Customer compares products and reads reviews",
      duration_days: 7,
      position: 2,
      created_at: "2024-08-01T10:00:00Z"
    },
    {
      id: "stage-4",
      name: "Purchase",
      description: "Customer makes a purchase decision",
      duration_days: 1,
      position: 3,
      created_at: "2024-08-01T10:00:00Z"
    }
  ],
  touchpoints: {
    "stage-1" => [
      {
        id: "tp-1",
        channel: "social_media",
        description: "Instagram product discovery ad",
        created_at: "2024-08-01T10:00:00Z"
      }
    ],
    "stage-2" => [
      {
        id: "tp-2",
        channel: "web",
        description: "Website landing page visit",
        created_at: "2024-08-01T10:00:00Z"
      },
      {
        id: "tp-3",
        channel: "email",
        description: "Welcome email sequence",
        created_at: "2024-08-01T10:00:00Z"
      }
    ]
  },
  content_types: ["social_media", "email", "blog_post", "landing_page"],
  metrics: {
    conversion_rate: 12.5,
    avg_journey_duration: 21,
    drop_off_points: ["stage-2"],
    last_updated: "2024-08-10T12:00:00Z"
  }
)

b2b_journey = CustomerJourney.create!(
  campaign: startup_awareness,
  name: "B2B Lead Nurturing Journey",
  description: "Journey for converting business leads into qualified prospects",
  position: 0,
  stages: [
    {
      id: "lead-capture",
      name: "Lead Capture",
      description: "Visitor downloads whitepaper or attends webinar",
      duration_days: 1,
      position: 0,
      created_at: "2024-06-01T09:00:00Z"
    },
    {
      id: "qualification",
      name: "Lead Qualification",
      description: "Automated scoring and qualification process",
      duration_days: 3,
      position: 1,
      created_at: "2024-06-01T09:00:00Z"
    },
    {
      id: "nurturing",
      name: "Lead Nurturing",
      description: "Educational content and personalized outreach",
      duration_days: 30,
      position: 2,
      created_at: "2024-06-01T09:00:00Z"
    },
    {
      id: "sales-ready",
      name: "Sales Ready",
      description: "Lead is ready for sales team engagement",
      duration_days: 7,
      position: 3,
      created_at: "2024-06-01T09:00:00Z"
    }
  ],
  touchpoints: {
    "lead-capture" => [
      {
        id: "webinar-tp",
        channel: "webinar",
        description: "Technical webinar registration",
        created_at: "2024-06-01T09:00:00Z"
      }
    ],
    "nurturing" => [
      {
        id: "email-sequence",
        channel: "email",
        description: "5-part educational email series",
        created_at: "2024-06-01T09:00:00Z"
      }
    ]
  },
  content_types: ["webinar", "email", "whitepaper", "case_study"],
  metrics: {
    lead_score_avg: 75,
    qualified_rate: 8.5,
    sales_conversion: 15.0
  }
)

puts "✅ Database seeded successfully!"

seed_stats = {
  "Brand Identities" => BrandIdentity.count,
  "Campaigns" => Campaign.count,
  "Customer Journeys" => CustomerJourney.count,
  "Content Assets" => ContentAsset.count,
  "Templates" => Template.count
}

puts "\n📊 Seed Summary:"
seed_stats.each do |model, count|
  puts "  #{model}: #{count}"
end
