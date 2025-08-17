# Campaign Creation Wizard User Flow

## Overview
Multi-step campaign creation wizard with form validation, journey template selection, audience targeting, goal setting, and review functionality.

## Entry Points
- **Primary**: `/dashboard/campaigns/new` - Direct navigation to wizard
- **Secondary**: "Create Campaign" button from campaigns list or dashboard

## User Flow Steps

### 1. Wizard Entry and Navigation
- **Action**: Navigate to `/dashboard/campaigns/new`
- **Expected Result**: Wizard loads with step 1 (Basic Info) active
- **Components**:
  - Progress indicator showing 5 steps
  - Step navigation with current step highlighted
  - Form validation using React Hook Form and Zod
  - Save as draft functionality throughout

### 2. Step 1: Basic Information
- **Fields**:
  - Campaign name (required)
  - Description (optional)
  - Duration (start date, end date)
- **Actions**:
  - Form validation on blur and submit
  - "Next" button to proceed
  - "Save as Draft" option
- **Expected Results**:
  - Real-time validation feedback
  - Required field indicators
  - Smooth transition to next step

### 3. Step 2: Journey Template Selection
- **Options**: 6 predefined journey templates:
  - Product Launch
  - Lead Generation Funnel
  - Re-engagement Campaign
  - User Onboarding
  - Upsell Campaign
  - Email Nurture Series
- **Actions**:
  - Preview template cards with descriptions
  - Select single template (radio selection)
  - View template details and stages
- **Expected Results**:
  - Template preview shows journey stages
  - Selection updates wizard state
  - Template data persists through navigation

### 4. Step 3: Target Audience (Optional)
- **Fields**:
  - Demographics (age, location, interests)
  - Audience segments
  - Estimated audience size
- **Actions**:
  - Optional field completion
  - Audience size estimation
  - Skip option available
- **Expected Results**:
  - Form accepts optional input
  - Audience size calculations display
  - Can proceed without completion

### 5. Step 4: Goals & KPIs
- **Fields**:
  - Conversion goals (awareness, leads, sales)
  - Budget allocation
  - Success metrics and targets
- **Actions**:
  - Goal selection with preset options
  - Budget input with validation
  - Metric threshold setting
- **Expected Results**:
  - Goal presets populate fields
  - Budget calculations update dynamically
  - Target metrics validate against realistic ranges

### 6. Step 5: Review and Confirmation
- **Content**:
  - Summary of all wizard steps
  - Campaign configuration overview
  - Journey template details
  - Audience and goals summary
- **Actions**:
  - Edit any section (navigate back to step)
  - Save as draft with current state
  - Create campaign (submit to API)
- **Expected Results**:
  - Complete campaign summary displays
  - Back navigation preserves all data
  - Successful creation redirects to campaign detail

## Technical Implementation
- **Framework**: Multi-step form with React Hook Form
- **Validation**: Zod schemas for each step
- **State Persistence**: Local state management between steps
- **UI Components**: Shadcn Form, Card, Button, Select, Input components
- **API Integration**: POST `/api/campaigns` on final submission

## Test Scenarios

### Wizard Navigation Test
1. Load wizard at step 1
2. Progress through all steps sequentially
3. Navigate back to previous steps
4. Verify data persistence during navigation
5. Test step validation before proceeding

### Form Validation Test
1. Test required field validation on step 1
2. Submit empty forms and verify error messages
3. Test email format validation where applicable
4. Verify Zod schema enforcement
5. Test form reset functionality

### Template Selection Test
1. View all 6 journey templates
2. Test template preview functionality
3. Select different templates and verify state
4. Verify template data structure preservation
5. Test template details display

### Draft Functionality Test
1. Fill partial form data
2. Save as draft at each step
3. Verify draft data persistence
4. Test draft restoration on page reload
5. Test draft vs. final submission

### Campaign Creation Test
1. Complete entire wizard workflow
2. Submit campaign creation
3. Verify API call with correct data structure
4. Test success/error handling
5. Verify redirect to campaign detail page

### Error Handling Test
1. Test form validation errors
2. Test API submission failures
3. Test network connectivity issues
4. Verify error message display
5. Test retry mechanisms

## Expected Behaviors
- Wizard loads within 2 seconds
- Step transitions are smooth (< 500ms)
- Form validation provides immediate feedback
- Draft saves complete within 1 second
- Final submission completes within 5 seconds
- Error states provide clear user guidance
- Data persists during browser refresh (draft mode)

## Form Data Structure
```typescript
interface CampaignWizardData {
  basicInfo: {
    name: string;
    description?: string;
    startDate: Date;
    endDate: Date;
  };
  template: {
    id: string;
    name: string;
    stages: JourneyStage[];
  };
  audience?: {
    demographics: object;
    segments: string[];
    estimatedSize: number;
  };
  goals: {
    type: 'awareness' | 'leads' | 'sales';
    budget: number;
    metrics: object;
  };
}
```

## Dependencies
- **Task 4.1**: Dashboard layout ✅
- **Task 4.4**: Campaign creation wizard ✅
- **Task 4.6**: Campaign CRUD operations ✅
- React Hook Form and Zod validation libraries

## Related Components
- `src/app/dashboard/campaigns/new/page.tsx`
- `src/components/features/campaigns/campaign-wizard.tsx`
- `src/components/features/campaigns/wizard-steps/`
- `src/components/ui/progress.tsx`
- `src/lib/validation/campaign-schemas.ts`