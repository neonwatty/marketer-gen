# Temporary Playwright E2E Tests

## Quick Start

### Prerequisites
1. Ensure your Next.js application is running on port 3000:
   ```bash
   npm run dev
   ```

2. Install Playwright if not already installed:
   ```bash
   npx playwright install
   ```

### Run All Tests
```bash
npx playwright test tests/temp/
```

### Run Individual Test Files
```bash
# Campaign Components (new dashboard components)
npx playwright test tests/temp/campaign-components.spec.ts

# Auth Error Handling (improved error handling)
npx playwright test tests/temp/auth-error-handling.spec.ts

# Dashboard Exports (new component exports)
npx playwright test tests/temp/dashboard-exports.spec.ts

# Priority Prop Changes (Next.js Image updates)
npx playwright test tests/temp/priority-prop-changes.spec.ts

# Integration Tests (overall system testing)
npx playwright test tests/temp/integration-changes.spec.ts
```

### Run with UI (for debugging)
```bash
npx playwright test tests/temp/ --headed
```

### Generate HTML Report
```bash
npx playwright test tests/temp/ --reporter=html
npx playwright show-report
```

## What These Tests Verify

### ✅ Campaign Components
- New CampaignCard, CampaignGrid, and CampaignCardSkeleton components
- User interactions (dropdowns, actions)
- Responsive design and accessibility
- Loading states and error handling

### ✅ Auth Error Handling
- Improved database error handling in auth.ts
- Graceful fallback when role fetching fails
- Session continuity during database issues
- Error logging without user impact

### ✅ Dashboard Exports
- New component exports from dashboard/index.ts
- Type safety for Campaign and CampaignMetrics interfaces
- Component integration and prop handling
- Module system compatibility

### ✅ Priority Prop Changes
- Next.js Image priority prop syntax (priority vs priority={true})
- Performance improvements
- Cross-browser compatibility
- SEO and accessibility maintenance

### ✅ Integration Testing
- End-to-end user journeys with all changes
- Cross-component interactions
- Performance under various conditions
- Error recovery and resilience

## Test Status and Notes

### ⚠️ Important Notes
1. **Mock Data**: Some tests expect specific data structures that may not exist yet
2. **Test IDs**: Tests require `data-testid` attributes to be added to components
3. **API Endpoints**: Some tests may need mock API endpoints
4. **Database**: Auth tests assume database connectivity

### 🔧 Required Component Updates
Add these `data-testid` attributes to your components:

```tsx
// CampaignCard.tsx
<Card data-testid="campaign-card">
  <CardTitle data-testid="campaign-title">
  <Badge data-testid="status-badge">
  <Button data-testid="more-options-button">
  <DropdownMenuContent data-testid="campaign-dropdown-menu">
  <div data-testid="engagement-metric">
  <div data-testid="conversion-metric">
  <div data-testid="content-metric">
  <div data-testid="progress-bar">
  <div data-testid="last-updated">

// CampaignGrid.tsx
<div data-testid="campaign-grid">
<div data-testid="campaigns-empty-state">

// CampaignCardSkeleton.tsx
<div data-testid="campaign-card-skeleton">
<div data-testid="campaign-skeleton-grid">
```

### 🧪 Test Results Interpretation

#### ✅ Passing Tests
- Functionality works as expected
- Components render correctly
- User interactions function properly
- Error handling is robust

#### ⚠️ Skipped Tests
- Required test data or selectors not available
- API endpoints not implemented
- Optional features not yet built

#### ❌ Failing Tests
- May indicate missing implementations
- Could reveal integration issues
- Might need mock data adjustments

## Next Steps

### 1. Review Test Results
```bash
npx playwright test tests/temp/ --reporter=list
```

### 2. Add Missing Test IDs
Update components with required `data-testid` attributes

### 3. Implement Missing Features
- Add campaign data loading
- Implement dropdown actions
- Set up proper loading states

### 4. Move Successful Tests
Move validated tests to permanent test directories:
```bash
# Example
mv tests/temp/campaign-components.spec.ts tests/e2e/
```

### 5. Clean Up
```bash
rm -rf tests/temp/
```

## Troubleshooting

### Common Issues

#### Test Timeouts
```bash
# Increase timeout
npx playwright test tests/temp/ --timeout=60000
```

#### Server Not Running
```bash
# Make sure dev server is running
npm run dev
# Then run tests
npx playwright test tests/temp/
```

#### Missing Selectors
- Check that components have required `data-testid` attributes
- Verify component structure matches test expectations

#### Database Errors
- Ensure database is accessible
- Check that auth configuration is correct
- Verify environment variables are set

### Debug Mode
```bash
# Run single test with debug
npx playwright test tests/temp/campaign-components.spec.ts --debug

# Run with verbose output
npx playwright test tests/temp/ --reporter=verbose
```

## Test Coverage

These tests provide comprehensive coverage for:
- ✅ Component rendering and functionality
- ✅ User interaction flows
- ✅ Error handling and recovery
- ✅ Performance characteristics
- ✅ Accessibility compliance
- ✅ Cross-browser compatibility
- ✅ Responsive design
- ✅ Integration between components

## Contributing

When modifying these tests:
1. Keep test names descriptive
2. Use appropriate selectors (prefer `data-testid`)
3. Include both positive and negative test cases
4. Test error conditions and edge cases
5. Maintain cross-browser compatibility
6. Document any new requirements or dependencies