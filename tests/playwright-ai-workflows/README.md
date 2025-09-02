# Playwright E2E Test Suite

This directory contains comprehensive end-to-end tests for the Marketer Gen NextJS application using Playwright.

## Generated Test Files

### Core Functionality Tests

1. **dashboard-navigation.spec.ts**
   - Tests main dashboard layout and structure
   - Validates sidebar navigation functionality
   - Checks active navigation states
   - Tests responsive design behavior
   - Verifies breadcrumb navigation

2. **dashboard-header.spec.ts**
   - Tests header component functionality
   - Validates search functionality (desktop/mobile)
   - Tests notifications and user menu
   - Checks responsive header behavior
   - Validates accessibility attributes

3. **breadcrumb-navigation.spec.ts**
   - Tests breadcrumb component across all pages
   - Validates hierarchical navigation
   - Tests breadcrumb link functionality
   - Checks accessibility compliance
   - Tests mobile breadcrumb behavior

4. **responsive-design.spec.ts**
   - Tests across multiple viewport sizes
   - Validates mobile, tablet, and desktop layouts
   - Checks touch target sizes on mobile
   - Tests text overflow handling
   - Validates consistent spacing

5. **auth-integration.spec.ts**
   - Tests protected route behavior (MVP mode)
   - Validates authentication context providers
   - Tests user menu functionality
   - Checks session handling
   - Tests direct URL access

6. **ui-components.spec.ts**
   - Tests Shadcn/ui component integration
   - Validates Button, Input, Avatar, Badge components
   - Tests DropdownMenu and Sidebar components
   - Checks component accessibility
   - Tests component interactions

7. **seo-metadata.spec.ts**
   - Tests page titles and meta descriptions
   - Validates Open Graph and Twitter Card metadata
   - Checks canonical URLs and structured data
   - Tests dynamic metadata for different pages
   - Validates security headers

8. **performance.spec.ts**
   - Tests page load performance
   - Measures Core Web Vitals
   - Checks resource loading efficiency
   - Tests navigation performance
   - Validates mobile performance

## Setup Instructions

### 1. Install Playwright

```bash
npm install --save-dev @playwright/test
npx playwright install
```

### 2. Add Test Scripts to package.json

```json
{
  "scripts": {
    "test:e2e": "playwright test",
    "test:e2e:headed": "playwright test --headed",
    "test:e2e:ui": "playwright test --ui",
    "test:e2e:debug": "playwright test --debug",
    "test:e2e:report": "playwright show-report"
  }
}
```

### 3. Move Configuration Files

```bash
# Move the config to root directory
mv tests/temp/playwright.config.ts ./playwright.config.ts

# Create permanent tests directory
mkdir -p tests/e2e

# Move test files to permanent location
mv tests/temp/*.spec.ts tests/e2e/
```

### 4. Update Playwright Config

Update the `playwright.config.ts` file to point to the correct test directory:

```typescript
export default defineConfig({
  testDir: './tests/e2e',
  // ... rest of config
});
```

## Running Tests

### Development Server Required

Make sure your Next.js development server is running:

```bash
npm run dev
```

### Run All Tests

```bash
npm run test:e2e
```

### Run Specific Test Files

```bash
# Test navigation only
npx playwright test dashboard-navigation

# Test responsive design
npx playwright test responsive-design

# Test performance
npx playwright test performance
```

### Run with Browser UI

```bash
npm run test:e2e:headed
```

### Debug Tests

```bash
npm run test:e2e:debug
```

### View Test Reports

```bash
npm run test:e2e:report
```

## Test Coverage Analysis

### Critical User Workflows Covered

1. **Dashboard Access & Navigation**
   - ✅ Main dashboard page loading
   - ✅ Sidebar navigation between sections
   - ✅ Breadcrumb navigation
   - ✅ Mobile responsive navigation

2. **Header Functionality**
   - ✅ Search functionality (desktop/mobile)
   - ✅ User menu interactions
   - ✅ Notifications display
   - ✅ Responsive header behavior

3. **Authentication Flow**
   - ✅ Protected route access (MVP mode)
   - ✅ User context initialization
   - ✅ Session handling
   - ✅ User menu functionality

4. **UI Component Integration**
   - ✅ Shadcn/ui component rendering
   - ✅ Component interactions
   - ✅ Accessibility compliance
   - ✅ Responsive component behavior

5. **Performance & SEO**
   - ✅ Page load performance
   - ✅ Core Web Vitals
   - ✅ SEO metadata
   - ✅ Mobile performance

### Missing E2E Test Coverage Areas

Based on the current implementation, the following areas need E2E tests once implemented:

#### Campaign Management (Task 4.2-4.6)
- Campaign overview cards display
- Campaign listing with DataTable
- Campaign creation wizard
- Campaign CRUD operations
- Optimistic UI updates

#### Future Features
- Analytics dashboard
- Audience management
- Template system
- Settings pages
- Journey visualization
- API integration testing

## Browser Coverage

Tests run on:
- ✅ Desktop Chrome
- ✅ Desktop Firefox
- ✅ Desktop Safari
- ✅ Mobile Chrome (Pixel 5)
- ✅ Mobile Safari (iPhone 12)

## Best Practices Followed

1. **Page Object Pattern**: Tests use consistent selectors and patterns
2. **Wait Strategies**: Proper use of `waitForLoadState` and `waitForURL`
3. **Assertions**: Comprehensive assertions for visibility, content, and behavior
4. **Accessibility**: Tests include accessibility checks and keyboard navigation
5. **Performance**: Performance budgets and Core Web Vitals monitoring
6. **Cross-browser**: Tests run across multiple browsers and devices
7. **Error Handling**: Tests handle edge cases and error scenarios

## Maintenance Notes

### When Adding New Features
1. Add corresponding E2E tests in the appropriate spec file
2. Update this README with new test coverage
3. Consider performance impact of new features
4. Test accessibility of new components

### When Modifying Existing Features
1. Update corresponding test assertions
2. Verify selectors still work
3. Check responsive behavior changes
4. Update performance expectations if needed

### Regular Maintenance
1. Review test stability and flakiness
2. Update browser versions in CI
3. Monitor performance budgets
4. Review accessibility compliance

## CI/CD Integration

Recommended GitHub Actions workflow:

```yaml
name: E2E Tests
on: [push, pull_request]
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: actions/setup-node@v3
      - run: npm ci
      - run: npm run build
      - run: npx playwright install --with-deps
      - run: npm run test:e2e
      - uses: actions/upload-artifact@v3
        if: always()
        with:
          name: playwright-report
          path: playwright-report/
```

## Cleanup Instructions

To remove temporary test files:

```bash
rm -rf tests/temp
```

To move tests to permanent location:

```bash
mkdir -p tests/e2e
mv tests/temp/*.spec.ts tests/e2e/
mv tests/temp/playwright.config.ts ./
rm -rf tests/temp
```