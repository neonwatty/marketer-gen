# Test Workflows Documentation

This directory contains comprehensive user flow documentation for the marketing platform application.

## Overview

The marketing platform is built with Next.js, TypeScript, Shadcn UI, and Prisma, featuring a complete campaign management system with journey builder, dashboard interface, and robust data persistence.

## Available User Flows

### 1. [Dashboard Overview](./dashboard-overview.md)
Main dashboard functionality with responsive navigation, campaign overview cards, and quick access features.

**Key Features:**
- Responsive sidebar navigation
- Campaign overview cards with metrics
- Search functionality and user menu
- Mobile-first responsive design

### 2. [Campaign Management](./campaign-management.md)
Comprehensive campaign CRUD operations with data table, filtering, and bulk actions.

**Key Features:**
- DataTable with sorting, filtering, pagination
- Search and status filtering
- Bulk operations (duplicate, archive, export)
- Optimistic updates with rollback

### 3. [Campaign Creation](./campaign-creation.md)
Multi-step wizard for campaign creation with template selection and validation.

**Key Features:**
- 5-step wizard with progress indicator
- 6 predefined journey templates
- Form validation with React Hook Form and Zod
- Save as draft functionality

### 4. [Journey Builder](./journey-builder.md)
Interactive journey visualization and editing with React Flow integration.

**Key Features:**
- Drag-and-drop stage management
- Custom journey stage nodes
- Stage configuration panel
- Zoom controls and minimap

### 5. [Data Persistence](./data-persistence.md)
Database operations and data integrity using Prisma ORM with comprehensive CRUD operations.

**Key Features:**
- Complete database schema with relationships
- Transaction support and soft delete
- Analytics tracking and audit trails
- Migration and seed data management

### 6. [Authentication Ready](./authentication-ready.md)
Authentication system infrastructure prepared but deferred for MVP accessibility.

**Key Features:**
- NextAuth.js integration ready
- Auth components and context providers built
- Protected route infrastructure (currently disabled)
- Full auth system ready for activation

### 7. [Error Handling](./error-handling.md)
Comprehensive error handling and loading states with React Query integration.

**Key Features:**
- Error boundaries with fallback UI
- Toast notifications for user feedback
- Optimistic updates with rollback
- Skeleton loaders and empty states

### 8. [Brand Management Foundation](./brand-management.md)
Database foundation for brand identity management with rich data structures.

**Key Features:**
- Comprehensive brand data models
- JSON-based guidelines, assets, and messaging storage
- Seed data with realistic brand profiles
- Ready for content generation integration

## Implementation Status

### ✅ Completed Features
- **Task 1**: Next.js project setup with TypeScript and Shadcn UI
- **Task 2**: Complete database schema and Prisma setup
- **Task 3**: Authentication system infrastructure (deferred)
- **Task 4**: Journey template system and builder interface

### 🚧 In Progress
- **Task 4**: Journey Template System (subtasks completed, main task in-progress)

### 📋 Pending Implementation
- **Task 5**: Brand Identity Management System
- **Task 6**: LLM Integration and Content Generation Engine
- **Task 7**: Campaign Summary and Planning Dashboard
- **Task 8**: Content Management and Version Control System
- **Task 9**: Platform Integration Framework
- **Task 10**: Performance Analytics and Optimization Dashboard

## Testing Instructions

### Prerequisites
1. Node.js 18+ installed
2. Database setup complete (SQLite for development)
3. Dependencies installed with `npm install`

### Running the Application
```bash
# Start development server
npm run dev

# Run database migrations
npm run db:migrate

# Seed database with test data
npm run db:seed

# Run tests
npm test
```

### Key Test Routes
- **Dashboard**: `/dashboard`
- **Campaigns**: `/dashboard/campaigns`
- **New Campaign**: `/dashboard/campaigns/new`
- **Journey Demo**: `/demo/journey`

### Database Management
```bash
# Reset and reseed database
npm run db:reset

# Open Prisma Studio
npm run db:studio

# Generate Prisma client
npm run db:generate
```

## Architecture Overview

### Technology Stack
- **Frontend**: Next.js 14+ with App Router, TypeScript, Shadcn UI
- **Database**: Prisma ORM with SQLite (dev) / PostgreSQL (prod)
- **Styling**: Tailwind CSS with custom theme
- **State Management**: React Query for server state
- **Forms**: React Hook Form with Zod validation
- **UI Components**: Shadcn UI with Radix UI primitives

### Project Structure
```
src/
├── app/                    # Next.js App Router pages
├── components/            
│   ├── ui/                # Shadcn UI components
│   ├── features/          # Feature-specific components
│   └── layouts/           # Layout components
├── lib/                   # Utility functions and configurations
│   ├── api/              # API client and utilities
│   ├── hooks/            # Custom React hooks
│   ├── providers/        # Context providers
│   └── validation/       # Zod schemas
└── generated/             # Generated files (Prisma client)
```

## Performance Metrics

### Expected Performance
- **Page Load**: < 3 seconds for dashboard
- **Navigation**: < 500ms between routes
- **API Responses**: < 2 seconds for CRUD operations
- **Search**: < 300ms for debounced search
- **Form Submission**: < 5 seconds for campaign creation

### Optimization Features
- React Query caching for API responses
- Optimistic updates for immediate feedback
- Skeleton loaders for perceived performance
- Efficient database queries with proper indexing
- Responsive images and asset optimization

## Contributing

When adding new features or workflows:

1. **Document User Flows**: Create detailed user flow documentation
2. **Test Scenarios**: Include comprehensive test scenarios
3. **Expected Behaviors**: Define clear expected behaviors
4. **Dependencies**: List all dependencies and related components
5. **API Endpoints**: Document relevant API endpoints
6. **Error Handling**: Include error handling considerations

## Support and Resources

- **Database**: Use `npm run db:studio` to inspect database
- **Component Library**: Visit [Shadcn UI](https://ui.shadcn.com/) for component documentation
- **API Documentation**: Check `/api` route files for endpoint details