# Campaign Management User Flow

## Overview
Comprehensive campaign management system featuring data table with sorting, filtering, pagination, search capabilities, and full CRUD operations.

## Entry Points
- **Primary**: `/dashboard/campaigns` - Main campaigns listing page
- **Secondary**: Dashboard campaign cards with "View All" action

## User Flow Steps

### 1. Campaign List Access
- **Action**: Navigate to `/dashboard/campaigns`
- **Expected Result**: Campaign DataTable loads with all campaigns
- **Components**:
  - DataTable with columns: name, status, journey type, progress, created date, modified date, actions
  - Search bar with debounced input
  - Filter dropdowns for status and journey type
  - Pagination controls with configurable page sizes

### 2. Campaign Search and Filtering
- **Actions**:
  - Enter search terms in search input
  - Select status filter (Draft, Active, Paused, Completed, Cancelled)
  - Filter by journey type
  - Adjust page size (5/10/20/50 items)
- **Expected Results**:
  - Debounced search updates results in real-time
  - Filters work independently and can be combined
  - Pagination updates based on filtered results
  - Loading states during filter operations

### 3. Table Interactions
- **Actions**:
  - Sort columns by clicking headers
  - Select individual campaigns via checkboxes
  - Select all campaigns with header checkbox
  - Use bulk actions (duplicate, archive, export)
- **Expected Results**:
  - Column sorting with visual indicators (arrows)
  - Row selection state management
  - Bulk action toolbar appears when items selected
  - Actions apply to selected campaigns only

### 4. Individual Campaign Actions
- **Actions**:
  - Click dropdown menu on campaign row
  - Select action: View, Edit, Duplicate, Archive
- **Expected Results**:
  - View: Navigate to campaign detail page
  - Edit: Open campaign edit form/wizard
  - Duplicate: Create copy with incremented name
  - Archive: Soft delete with status update

### 5. Campaign Creation
- **Action**: Click "Create Campaign" button
- **Expected Result**: Navigate to `/dashboard/campaigns/new` wizard

## Technical Implementation
- **Framework**: Shadcn DataTable with TanStack Table
- **State Management**: React Query for data fetching and caching
- **API Integration**: `/api/campaigns` endpoints
- **Optimistic Updates**: Immediate UI updates with rollback on failure

## Test Scenarios

### Data Table Functionality Test
1. Load campaigns page
2. Verify all columns display correctly
3. Test column sorting (ascending/descending)
4. Verify pagination controls work
5. Test page size changes

### Search and Filter Test
1. Enter search term and verify debounced behavior
2. Test status filter dropdown
3. Test journey type filter
4. Combine multiple filters
5. Clear filters and verify reset

### Selection and Bulk Actions Test
1. Select individual campaigns
2. Test select all functionality
3. Verify bulk action toolbar appears
4. Test bulk duplicate operation
5. Test bulk archive operation
6. Test bulk export functionality

### Individual Actions Test
1. Test View action navigation
2. Test Edit action (when implemented)
3. Test Duplicate action with optimistic updates
4. Test Archive action with status change
5. Verify loading states during actions

### Loading and Error States Test
1. Test initial loading skeleton
2. Test empty state when no campaigns
3. Test error handling for failed API calls
4. Test retry mechanisms
5. Verify toast notifications for actions

## Expected Behaviors
- Table loads within 3 seconds with skeleton states
- Search responds within 300ms of typing stop
- Filters apply immediately with loading indicators
- Bulk actions complete within 5 seconds
- Individual actions provide immediate feedback
- Error states show user-friendly messages
- Retry mechanisms work for failed operations

## API Endpoints
- `GET /api/campaigns` - Fetch campaigns with query parameters
- `POST /api/campaigns` - Create new campaign
- `PUT /api/campaigns/[id]` - Update campaign
- `DELETE /api/campaigns/[id]` - Soft delete campaign
- `POST /api/campaigns/[id]/duplicate` - Duplicate campaign

## Dependencies
- **Task 4.1**: Dashboard layout ✅
- **Task 4.3**: Campaign DataTable implementation ✅
- **Task 4.6**: Campaign CRUD operations ✅
- **Task 4.7**: Optimistic updates and loading states ✅

## Related Components
- `src/app/dashboard/campaigns/page.tsx`
- `src/components/features/dashboard/campaign-data-table.tsx`
- `src/components/features/dashboard/campaign-grid.tsx`
- `src/lib/api/campaigns.ts`
- `src/lib/hooks/use-campaigns.ts`