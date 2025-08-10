# Marketing Campaign Platform - Database Schema Design

## Overview

This document defines the comprehensive database schema for the Rails 8 marketing campaign platform. The schema supports campaign creation, customer journey management, brand identity storage, content asset management, and templating functionality.

## Database Technology

- **Database**: SQLite3 (development/test), PostgreSQL recommended for production
- **ORM**: ActiveRecord 8.0
- **Migration System**: Rails migrations with versioning

## Schema Design Principles

### Naming Conventions
- Tables: plural, snake_case (`campaigns`, `customer_journeys`)
- Columns: snake_case (`created_at`, `journey_stage`)
- Foreign keys: `{model}_id` format (`campaign_id`, `brand_identity_id`)
- Indexes: `index_{table}_{column(s)}` format

### Relationships
- Use foreign key constraints where appropriate
- Polymorphic associations for flexible content relationships
- Junction tables for many-to-many relationships
- Cascading deletes for dependent records

## Entity Relationship Diagram (ERD)

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│    campaigns    │────┤ customer_journeys│────│  content_assets │
│                 │    │                  │    │                 │
│ • id (PK)       │    │ • id (PK)        │    │ • id (PK)       │
│ • name          │    │ • campaign_id(FK)│    │ • assetable_id  │
│ • status        │    │ • name           │    │ • assetable_type│
│ • purpose       │    │ • stages (JSON)  │    │ • asset_type    │
│ • brand_id (FK) │    │ • template_id(FK)│    │ • content (JSON)│
│ • created_at    │    │ • created_at     │    │ • file_url      │
│ • updated_at    │    │ • updated_at     │    │ • metadata(JSON)│
└─────────────────┘    └──────────────────┘    │ • created_at    │
         │                       │               │ • updated_at    │
         │                       │               └─────────────────┘
         │              ┌────────▼────────┐               │
         │              │   templates     │               │
         │              │                 │               │
         │              │ • id (PK)       │               │
         │              │ • name          │               │
         │              │ • template_type │               │
         │              │ • content (JSON)│               │
         │              │ • created_at    │               │
         │              │ • updated_at    │               │
         │              └─────────────────┘               │
         │                                                 │
         └──────────────┐                ┌─────────────────┘
                        │                │
              ┌─────────▼────────┐      │
              │  brand_identities│      │
              │                  │      │
              │ • id (PK)        │      │
              │ • name           │      │
              │ • guidelines(JSON)│     │
              │ • messaging(JSON) │      │
              │ • color_palette   │      │
              │ • typography      │      │
              │ • logo_url        │      │
              │ • created_at      │      │
              │ • updated_at      │      │
              └───────────────────┘      │
                                         │
                    (polymorphic)────────┘
```

## Table Definitions

### 1. campaigns

Core campaign management table (already exists, may need updates).

```sql
CREATE TABLE campaigns (
  id INTEGER PRIMARY KEY,
  name VARCHAR(100) NOT NULL,
  status VARCHAR(20) NOT NULL DEFAULT 'draft',
  purpose TEXT NOT NULL,
  brand_identity_id INTEGER,
  target_audience TEXT,
  budget_cents INTEGER,
  start_date DATE,
  end_date DATE,
  created_at DATETIME NOT NULL,
  updated_at DATETIME NOT NULL,
  
  FOREIGN KEY (brand_identity_id) REFERENCES brand_identities(id)
);

-- Indexes
CREATE INDEX index_campaigns_on_status ON campaigns(status);
CREATE INDEX index_campaigns_on_brand_identity_id ON campaigns(brand_identity_id);
CREATE INDEX index_campaigns_on_start_date ON campaigns(start_date);
CREATE INDEX index_campaigns_on_created_at ON campaigns(created_at);
```

**Columns:**
- `id`: Primary key
- `name`: Campaign name (3-100 chars)
- `status`: enum ['draft', 'active', 'paused', 'completed', 'archived']
- `purpose`: Campaign description/purpose (10-500 chars)
- `brand_identity_id`: Foreign key to brand_identities
- `target_audience`: JSON or text describing target demographics
- `budget_cents`: Budget in cents for financial calculations
- `start_date`: Campaign start date
- `end_date`: Campaign end date
- `created_at`, `updated_at`: Standard Rails timestamps

### 2. customer_journeys

Defines customer journey stages and content mapping for campaigns.

```sql
CREATE TABLE customer_journeys (
  id INTEGER PRIMARY KEY,
  campaign_id INTEGER NOT NULL,
  name VARCHAR(100) NOT NULL,
  description TEXT,
  stages JSON NOT NULL,
  template_id INTEGER,
  is_active BOOLEAN DEFAULT true,
  created_at DATETIME NOT NULL,
  updated_at DATETIME NOT NULL,
  
  FOREIGN KEY (campaign_id) REFERENCES campaigns(id) ON DELETE CASCADE,
  FOREIGN KEY (template_id) REFERENCES templates(id)
);

-- Indexes
CREATE INDEX index_customer_journeys_on_campaign_id ON customer_journeys(campaign_id);
CREATE INDEX index_customer_journeys_on_template_id ON customer_journeys(template_id);
CREATE INDEX index_customer_journeys_on_is_active ON customer_journeys(is_active);
```

**Columns:**
- `id`: Primary key
- `campaign_id`: Foreign key to campaigns
- `name`: Journey name (e.g., "New Customer Onboarding")
- `description`: Optional journey description
- `stages`: JSON array of journey stages with metadata
- `template_id`: Optional foreign key to journey templates
- `is_active`: Boolean flag for active journeys
- `created_at`, `updated_at`: Standard Rails timestamps

**stages JSON Structure:**
```json
[
  {
    "name": "Awareness",
    "order": 1,
    "duration_days": 7,
    "channels": ["email", "social", "web"],
    "content_types": ["blog_post", "social_media", "landing_page"],
    "trigger_conditions": {},
    "success_metrics": ["impressions", "clicks"]
  },
  {
    "name": "Consideration", 
    "order": 2,
    "duration_days": 14,
    "channels": ["email", "retargeting"],
    "content_types": ["email_sequence", "product_demo"],
    "trigger_conditions": {"previous_stage_completed": true},
    "success_metrics": ["engagement_rate", "demo_requests"]
  }
]
```

### 3. brand_identities

Centralized brand identity and guidelines storage.

```sql
CREATE TABLE brand_identities (
  id INTEGER PRIMARY KEY,
  name VARCHAR(100) NOT NULL,
  description TEXT,
  guidelines JSON,
  messaging_framework JSON,
  color_palette JSON,
  typography JSON,
  logo_url VARCHAR(500),
  brand_assets JSON,
  created_at DATETIME NOT NULL,
  updated_at DATETIME NOT NULL
);

-- Indexes
CREATE INDEX index_brand_identities_on_name ON brand_identities(name);
CREATE INDEX index_brand_identities_on_created_at ON brand_identities(created_at);
```

**Columns:**
- `id`: Primary key
- `name`: Brand name (e.g., "Company Brand 2024")
- `description`: Brand description
- `guidelines`: JSON storing brand guidelines and rules
- `messaging_framework`: JSON with key messages, tone, voice
- `color_palette`: JSON with hex codes and color names
- `typography`: JSON with font families and sizing
- `logo_url`: URL to primary logo file
- `brand_assets`: JSON with additional asset references
- `created_at`, `updated_at`: Standard Rails timestamps

**guidelines JSON Structure:**
```json
{
  "tone_of_voice": "friendly, professional, approachable",
  "key_messages": ["Quality first", "Customer focused"],
  "do_not_use": ["aggressive language", "technical jargon"],
  "target_emotions": ["trust", "excitement", "confidence"],
  "brand_personality": ["innovative", "reliable", "caring"]
}
```

### 4. content_assets

Polymorphic content storage for various asset types across the platform.

```sql
CREATE TABLE content_assets (
  id INTEGER PRIMARY KEY,
  assetable_type VARCHAR(50) NOT NULL,
  assetable_id INTEGER NOT NULL,
  asset_type VARCHAR(50) NOT NULL,
  title VARCHAR(200),
  content JSON,
  file_url VARCHAR(1000),
  file_size INTEGER,
  content_type VARCHAR(100),
  metadata JSON,
  status VARCHAR(20) DEFAULT 'draft',
  created_at DATETIME NOT NULL,
  updated_at DATETIME NOT NULL
);

-- Indexes
CREATE INDEX index_content_assets_on_assetable ON content_assets(assetable_type, assetable_id);
CREATE INDEX index_content_assets_on_asset_type ON content_assets(asset_type);
CREATE INDEX index_content_assets_on_status ON content_assets(status);
CREATE INDEX index_content_assets_on_created_at ON content_assets(created_at);
```

**Columns:**
- `id`: Primary key
- `assetable_type`: Polymorphic type (Campaign, CustomerJourney, BrandIdentity, Template)
- `assetable_id`: Polymorphic ID
- `asset_type`: Type of content ['email', 'social_media', 'blog_post', 'landing_page', 'ad_copy', 'image', 'video', 'document']
- `title`: Asset title/headline
- `content`: JSON storing structured content data
- `file_url`: URL to associated file (images, videos, documents)
- `file_size`: File size in bytes
- `content_type`: MIME type of file
- `metadata`: JSON with additional asset metadata
- `status`: enum ['draft', 'review', 'approved', 'published', 'archived']
- `created_at`, `updated_at`: Standard Rails timestamps

**content JSON Structure (Email Example):**
```json
{
  "subject_line": "Welcome to our platform!",
  "preview_text": "Get started with your first campaign",
  "html_content": "<html>...</html>",
  "text_content": "Welcome...",
  "variables": ["{{first_name}}", "{{company}}"],
  "call_to_action": {
    "text": "Get Started",
    "url": "https://app.example.com/onboarding"
  }
}
```

### 5. templates

Reusable templates for journeys, campaigns, and content.

```sql
CREATE TABLE templates (
  id INTEGER PRIMARY KEY,
  name VARCHAR(100) NOT NULL,
  description TEXT,
  template_type VARCHAR(50) NOT NULL,
  category VARCHAR(50),
  content JSON NOT NULL,
  is_public BOOLEAN DEFAULT false,
  usage_count INTEGER DEFAULT 0,
  created_at DATETIME NOT NULL,
  updated_at DATETIME NOT NULL
);

-- Indexes
CREATE INDEX index_templates_on_template_type ON templates(template_type);
CREATE INDEX index_templates_on_category ON templates(category);
CREATE INDEX index_templates_on_is_public ON templates(is_public);
CREATE INDEX index_templates_on_usage_count ON templates(usage_count);
```

**Columns:**
- `id`: Primary key
- `name`: Template name
- `description`: Template description
- `template_type`: enum ['journey_template', 'content_template', 'campaign_template']
- `category`: Template category (e.g., 'onboarding', 'product_launch', 'retention')
- `content`: JSON storing template structure and content
- `is_public`: Boolean for template visibility
- `usage_count`: Track template usage for popularity
- `created_at`, `updated_at`: Standard Rails timestamps

## ActiveRecord Model Associations

### Campaign Model
```ruby
class Campaign < ApplicationRecord
  belongs_to :brand_identity, optional: true
  has_many :customer_journeys, dependent: :destroy
  has_many :content_assets, as: :assetable, dependent: :destroy
end
```

### CustomerJourney Model
```ruby
class CustomerJourney < ApplicationRecord
  belongs_to :campaign
  belongs_to :template, optional: true
  has_many :content_assets, as: :assetable, dependent: :destroy
end
```

### BrandIdentity Model
```ruby
class BrandIdentity < ApplicationRecord
  has_many :campaigns, dependent: :nullify
  has_many :content_assets, as: :assetable, dependent: :destroy
end
```

### ContentAsset Model
```ruby
class ContentAsset < ApplicationRecord
  belongs_to :assetable, polymorphic: true
end
```

### Template Model
```ruby
class Template < ApplicationRecord
  has_many :customer_journeys, dependent: :nullify
  has_many :content_assets, as: :assetable, dependent: :destroy
end
```

## Database Performance Considerations

### Indexing Strategy
1. **Primary Keys**: Automatic indexes on all `id` columns
2. **Foreign Keys**: Indexes on all foreign key columns for join performance
3. **Status Columns**: Indexes on frequently queried status fields
4. **Timestamps**: Indexes on `created_at` for chronological queries
5. **Polymorphic**: Composite index on `(assetable_type, assetable_id)`

### Query Optimization
1. **JSON Queries**: Use PostgreSQL JSON operators for complex JSON queries in production
2. **Pagination**: Implement cursor-based pagination for large datasets
3. **Eager Loading**: Use `includes()` to avoid N+1 queries
4. **Caching**: Implement Rails caching for frequently accessed brand identities

### Storage Considerations
1. **JSON Columns**: Efficient for flexible schemas, validated at application level
2. **File Storage**: Use Rails Active Storage for file uploads in production
3. **Large Text**: Consider separate tables for very large content (>64KB)

## Data Integrity Constraints

### Validations (Application Level)
1. **Campaign**: Name presence/length, status enum validation
2. **CustomerJourney**: Stages JSON format validation
3. **BrandIdentity**: Name uniqueness within scope
4. **ContentAsset**: Asset type enum validation
5. **Template**: Template type enum validation

### Database Constraints
1. **Foreign Key Constraints**: Ensure referential integrity
2. **NOT NULL Constraints**: On required fields
3. **Check Constraints**: For enum-like values (where supported)
4. **Unique Constraints**: On natural keys where appropriate

## Migration Strategy

### Phase 1: Core Schema
1. Update existing `campaigns` table with new columns
2. Create `brand_identities` table
3. Create `customer_journeys` table

### Phase 2: Content Management
1. Create `content_assets` table with polymorphic associations
2. Create `templates` table
3. Add foreign key constraints and indexes

### Phase 3: Optimization
1. Add performance indexes based on usage patterns
2. Add database-level constraints where appropriate
3. Implement data archival strategies

## Security Considerations

1. **Data Encryption**: Sensitive brand data should be encrypted at rest
2. **Access Control**: Implement role-based access at application level
3. **Audit Logging**: Track changes to critical brand and campaign data
4. **Input Validation**: Strict validation of JSON content to prevent injection
5. **File Upload Security**: Validate file types and scan uploads

## Backup and Recovery

1. **Regular Backups**: Implement automated database backups
2. **Point-in-Time Recovery**: Essential for production environments
3. **Data Retention**: Define policies for campaign and asset data retention
4. **Disaster Recovery**: Multi-region backup strategy for critical data

---

This schema provides a solid foundation for the marketing campaign platform while maintaining flexibility for future enhancements and scaling requirements.