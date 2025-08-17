# Data Persistence User Flow

## Overview
Comprehensive database operations and data integrity system using Prisma ORM with SQLite, featuring full CRUD operations, relationship management, and analytics tracking.

## Database Architecture

### Core Models
1. **User**: User accounts with role-based access
2. **Brand**: Brand guidelines, assets, and messaging
3. **Campaign**: Marketing campaigns with goals and status
4. **Journey**: Customer journey workflows with stages
5. **Content**: Marketing content with variants and metadata
6. **ContentTemplate**: Reusable content templates
7. **Analytics**: Performance tracking and metrics

### Relationships
- User → Brand (one-to-many)
- User → Campaign (one-to-many)
- Brand → Campaign (one-to-many)
- Campaign → Journey (one-to-many)
- Journey → Content (one-to-many)
- Campaign/Journey/Content → Analytics (one-to-many)

## Data Flow Scenarios

### 1. Database Initialization and Seeding
- **Action**: Fresh database setup
- **Process**:
  1. Run `prisma migrate dev --name init`
  2. Execute seed script with `npm run db:seed`
  3. Generate Prisma client
  4. Verify data integrity
- **Expected Results**:
  - All tables created with proper structure
  - Seed data populated (2 users, 3 brands, 5 campaigns, journeys, content)
  - Foreign key relationships established
  - Indexes created for performance

### 2. Campaign CRUD Operations
- **Create Campaign**:
  - API: `POST /api/campaigns`
  - Validates required fields (name, purpose, brandId)
  - Creates campaign with default status 'DRAFT'
  - Returns campaign with generated ID
- **Read Campaigns**:
  - API: `GET /api/campaigns`
  - Supports filtering, sorting, pagination
  - Includes related journey and content counts
  - Returns formatted campaign list
- **Update Campaign**:
  - API: `PUT /api/campaigns/[id]`
  - Validates ownership and permissions
  - Updates audit fields (updatedBy, updatedAt)
  - Preserves related data integrity
- **Delete Campaign**:
  - API: `DELETE /api/campaigns/[id]`
  - Implements soft delete (sets deletedAt)
  - Cascades to related journeys and content
  - Preserves analytics data for reporting

### 3. Journey and Content Management
- **Journey Creation**:
  - Created automatically with campaign
  - Uses predefined templates from seed data
  - Establishes proper foreign key relationships
  - Validates stage configuration JSON
- **Content Generation**:
  - Linked to specific journey stages
  - Supports multiple content types (email, social, ads)
  - Stores variants for A/B testing
  - Maintains content status workflow

### 4. Analytics Data Tracking
- **Event Recording**:
  - Records user interactions and campaign performance
  - Supports multiple event types (impression, click, conversion)
  - Stores metrics in JSON format
  - Maintains session and source tracking
- **Data Aggregation**:
  - Supports real-time metric calculations
  - Enables performance dashboard queries
  - Maintains historical data for reporting
  - Optimized with database indexes

## Technical Implementation

### Database Configuration
- **Provider**: SQLite for development, PostgreSQL for production
- **Client**: Prisma with custom output path (`src/generated/prisma`)
- **Connection**: Environment variable `DATABASE_URL`
- **Migration**: Version-controlled schema migrations

### Data Validation
- **Schema Level**: Prisma schema constraints and validations
- **Application Level**: Zod schemas for API validation
- **Database Level**: Foreign key constraints and unique indexes
- **Audit Trail**: Created/updated timestamps and user tracking

### Performance Optimizations
- **Indexing**: Strategic indexes on frequently queried fields
- **Query Optimization**: Efficient joins and select strategies
- **Connection Pooling**: Proper database connection management
- **Caching**: Strategic use of query caching where appropriate

## Test Scenarios

### Database Schema Validation
1. Verify all models exist with correct structure
2. Test foreign key constraint enforcement
3. Validate enum value restrictions
4. Test unique constraint violations
5. Verify default value assignments

### CRUD Operation Testing
1. **Create Operations**:
   - Test successful record creation
   - Validate required field enforcement
   - Test relationship establishment
   - Verify audit field population
2. **Read Operations**:
   - Test basic record retrieval
   - Validate relationship loading (include/select)
   - Test filtering and sorting
   - Verify pagination functionality
3. **Update Operations**:
   - Test partial updates
   - Validate optimistic locking
   - Test relationship updates
   - Verify audit trail updates
4. **Delete Operations**:
   - Test soft delete functionality
   - Validate cascade behavior
   - Test hard delete restrictions
   - Verify data integrity preservation

### Transaction and Concurrency Testing
1. Test multi-table transaction rollback
2. Validate concurrent access scenarios
3. Test deadlock prevention
4. Verify data consistency under load
5. Test connection pooling behavior

### Data Integrity Testing
1. Test foreign key constraint violations
2. Validate referential integrity
3. Test cascade delete behavior
4. Verify orphaned record prevention
5. Test data migration scenarios

### Performance Testing
1. Test query performance with large datasets
2. Validate index effectiveness
3. Test connection establishment time
4. Verify memory usage patterns
5. Test concurrent operation performance

## Expected Behaviors
- Database operations complete within acceptable time limits
- Data integrity maintained across all operations
- Proper error handling for constraint violations
- Audit trails accurately track all changes
- Soft delete preserves related data
- Performance remains stable under load
- Migrations execute successfully

## Error Handling
- **Database Connection**: Graceful handling of connection failures
- **Constraint Violations**: User-friendly error messages
- **Transaction Failures**: Proper rollback and error reporting
- **Migration Issues**: Safe migration rollback procedures
- **Data Corruption**: Detection and recovery mechanisms

## Backup and Recovery
- **Development**: Local SQLite file backups
- **Production**: Automated PostgreSQL backups
- **Migration Safety**: Pre-migration backups
- **Point-in-time Recovery**: Transaction log preservation
- **Disaster Recovery**: Cross-region backup strategies

## API Endpoints
```
GET    /api/campaigns              # List campaigns with filters
POST   /api/campaigns              # Create new campaign
GET    /api/campaigns/[id]         # Get campaign details
PUT    /api/campaigns/[id]         # Update campaign
DELETE /api/campaigns/[id]         # Soft delete campaign
POST   /api/campaigns/[id]/duplicate # Duplicate campaign
GET    /api/journeys               # List journeys
POST   /api/journeys               # Create journey
GET    /api/analytics              # Get analytics data
POST   /api/analytics              # Record analytics event
```

## Database Scripts
```bash
npm run db:migrate      # Run pending migrations
npm run db:seed         # Populate with seed data
npm run db:reset        # Reset and reseed database
npm run db:generate     # Generate Prisma client
npm run db:studio       # Open Prisma Studio
```

## Dependencies
- **Task 2.1**: Prisma setup ✅
- **Task 2.2**: Core models (User, Brand, Campaign) ✅
- **Task 2.3**: Journey and Content models ✅
- **Task 2.4**: Analytics model ✅
- **Task 2.5**: Migration and seed data ✅
- **Task 4.6**: Campaign CRUD operations ✅

## Related Files
- `prisma/schema.prisma` - Database schema definition
- `prisma/seed.ts` - Seed data script
- `src/lib/prisma.ts` - Database client configuration
- `src/app/api/campaigns/` - Campaign API routes
- `prisma/migrations/` - Database migration files