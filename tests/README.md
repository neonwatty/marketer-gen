# AI Workflow Playwright Test Suite

Comprehensive end-to-end testing suite for AI-powered marketing platform workflows using Playwright.

## 🎯 **Overview**

This test suite validates all AI-powered features in the marketing platform through realistic user workflows. Each test script serves as both functional validation and living documentation of AI capabilities.

## 📋 **Test Coverage**

### **Core AI Workflows**
1. **Campaign Plan Generation** - Tests AI strategy creation and comprehensive planning
2. **Social Media Content Creation** - Validates platform-specific content optimization
3. **Email Campaign Content** - Tests email structure, personalization, and CTA optimization
4. **Journey Creation with AI Suggestions** - Validates customer journey recommendations
5. **Brand Identity AI Processing** - Tests brand voice extraction and application
6. **Campaign Intelligence** - Validates market analysis and competitive intelligence
7. **Content Optimization & Variants** - Tests improvement suggestions and A/B variants
8. **API Integration** - Tests programmatic content generation endpoints

### **Test Infrastructure**
- **Authentication Helper** - User creation and session management
- **Test Data Factory** - Realistic test data generation
- **AI Validators** - Content quality and compliance validation
- **Wait Helpers** - Smart waiting for AI processing

## 🚀 **Quick Start**

### **Prerequisites**
```bash
# Install Node.js and npm
npm install

# Install Playwright
npm install @playwright/test
npx playwright install

# Ensure Rails app is running
rails server
```

### **Environment Setup**
```bash
# Set test environment variables
export NODE_ENV=test
export RAILS_ENV=test
export LLM_ENABLED=true
export USE_REAL_LLM=true  # Set to false for mock testing
export OPENAI_API_KEY=your-api-key-here
```

### **Run All Tests**
```bash
# Run complete AI workflow test suite
npx playwright test tests/ai-workflows/

# Run specific workflow
npx playwright test tests/ai-workflows/test-campaign-generation.spec.js

# Run with UI mode for debugging
npx playwright test --ui
```

## 📊 **Test Structure**

### **Individual Test Files**

#### **Campaign Plan Generation** (`test-campaign-generation.spec.js`)
```javascript
// Tests core AI campaign strategy generation
- Full workflow: Create campaign → Generate plan → Verify content
- Error handling and timeout scenarios
- Concurrent generation testing
- Data persistence validation
```

#### **Social Media Content** (`test-social-content.spec.js`)
```javascript
// Tests platform-specific social content generation
- Platform optimization (Twitter, LinkedIn, Facebook, Instagram)
- Format variants (short, medium, long)
- Campaign context integration
- Content quality validation
```

#### **Email Campaigns** (`test-email-content.spec.js`)
```javascript
// Tests email campaign generation and optimization
- Email structure validation (greeting, body, CTA, closing)
- Personalization and segmentation
- A/B variant creation
- Professional formatting standards
```

#### **Journey AI Suggestions** (`test-journey-ai.spec.js`)
```javascript
// Tests customer journey recommendations
- AI step suggestions based on campaign type
- Content type recommendations per stage
- Channel optimization suggestions
- Audience-specific adaptations
```

#### **Brand Processing** (`test-brand-processing.spec.js`)
```javascript
// Tests brand voice extraction and application
- Brand guideline processing
- Voice characteristic extraction
- Content compliance validation
- Multi-brand management
```

#### **Campaign Intelligence** (`test-campaign-intelligence.spec.js`)
```javascript
// Tests market analysis and strategic recommendations
- Competitive analysis generation
- Market opportunity identification
- Performance predictions
- Strategic optimization recommendations
```

#### **Content Optimization** (`test-content-optimization.spec.js`)
```javascript
// Tests content improvement and variant generation
- Performance optimization suggestions
- A/B testing variant creation
- Platform-specific optimization
- Content scoring and metrics
```

#### **API Integration** (`test-api-integration.spec.js`)
```javascript
// Tests programmatic content generation
- All API endpoints (/social_media, /email, /ad_copy, /landing_page)
- Authentication and authorization
- Parameter validation
- Error handling and rate limiting
```

## 🔧 **Configuration**

### **Playwright Configuration** (`playwright.config.js`)
```javascript
module.exports = {
  testDir: './tests',
  timeout: 180000, // 3 minutes for AI processing
  expect: { timeout: 30000 },
  use: {
    baseURL: 'http://localhost:3000',
    screenshot: 'only-on-failure',
    video: 'retain-on-failure'
  },
  projects: [
    { name: 'AI Workflows', testDir: './tests/ai-workflows' }
  ]
};
```

### **Test Environment Variables**
```bash
# Required for AI testing
LLM_ENABLED=true
USE_REAL_LLM=true
OPENAI_API_KEY=sk-your-key-here

# Optional configuration
LLM_REQUEST_TIMEOUT=30
LLM_MAX_RETRIES=3
DEFAULT_LLM_PROVIDER=openai

# Test-specific settings
TEST_USER_EMAIL_DOMAIN=example.com
TEST_CLEANUP_ENABLED=true
```

## 📈 **Running Specific Test Scenarios**

### **Quick Smoke Test**
```bash
# Test core AI functionality only
npx playwright test tests/ai-workflows/test-campaign-generation.spec.js -g "should complete full campaign generation workflow"
```

### **API-Only Testing**
```bash
# Test all API endpoints
npx playwright test tests/ai-workflows/test-api-integration.spec.js
```

### **Brand Context Testing**
```bash
# Test brand processing and application
npx playwright test tests/ai-workflows/test-brand-processing.spec.js
```

### **Content Quality Testing**
```bash
# Test content generation quality across all types
npx playwright test tests/ai-workflows/ -g "validation"
```

## 🐛 **Debugging and Troubleshooting**

### **Common Issues**

#### **AI Processing Timeouts**
```bash
# Increase timeout for slow AI responses
npx playwright test --timeout=300000  # 5 minutes
```

#### **Authentication Failures**
```bash
# Check session cookies and CSRF tokens
npx playwright test --headed --debug
```

#### **API Key Issues**
```bash
# Verify API key has proper permissions
curl -H "Authorization: Bearer $OPENAI_API_KEY" https://api.openai.com/v1/models
```

### **Debug Mode**
```bash
# Run with browser visible and step-through debugging
npx playwright test --debug tests/ai-workflows/test-campaign-generation.spec.js
```

### **Screenshots and Videos**
```bash
# Capture screenshots on failure (automatic)
# Videos saved to test-results/ directory
npx playwright show-report
```

## 📋 **Test Data Management**

### **Automatic Cleanup**
- Tests automatically clean up created campaigns, content, and brand identities
- Failed tests may leave orphaned data - check manually if needed

### **Test Data Factory**
```javascript
// Generate realistic test data
const campaignData = TestDataFactory.generateCampaignPlan();
const brandData = TestDataFactory.generateBrandIdentity();
const contentData = TestDataFactory.generateContent();
```

### **Brand Guidelines Sample**
```javascript
// Generate realistic brand guidelines for testing
const guidelines = TestDataFactory.generateBrandGuidelinesText();
```

## ✅ **Validation and Quality Checks**

### **Content Quality Validation**
```javascript
// Automatic validation of generated content
const validation = AIValidators.validateSocialMediaContent(content, platform);
const emailValidation = AIValidators.validateEmailContent(emailContent);
const brandValidation = AIValidators.validateBrandConsistency(content, brandContext);
```

### **Performance Metrics**
- Content generation time tracking
- API response time monitoring  
- Success/failure rate calculation
- Content quality scoring

## 🎯 **Expected Outcomes**

### **Successful Test Run Should Show**
- ✅ All AI workflows complete without errors
- ✅ Generated content meets quality standards
- ✅ Brand consistency maintained across all content
- ✅ Platform-specific optimizations applied
- ✅ API endpoints respond correctly
- ✅ Error scenarios handled gracefully

### **Test Metrics**
- **Campaign Generation**: 90%+ success rate within 2 minutes
- **Content Quality**: 95%+ content passes validation
- **Brand Consistency**: 100% brand voice application
- **API Performance**: <5 second response time average
- **Error Handling**: Graceful failure with user feedback

## 🚀 **CI/CD Integration**

### **GitHub Actions Example**
```yaml
- name: Run AI Workflow Tests
  run: |
    npm install
    npx playwright install
    npx playwright test tests/ai-workflows/
  env:
    LLM_ENABLED: true
    USE_REAL_LLM: false  # Use mocks in CI
    OPENAI_API_KEY: ${{ secrets.OPENAI_API_KEY }}
```

### **Test Reporting**
```bash
# Generate HTML report
npx playwright test --reporter=html

# Generate JUnit XML for CI
npx playwright test --reporter=junit
```

## 🔄 **Maintenance**

### **Updating Tests**
- Update test data factory when new content types added
- Modify validators when AI output format changes
- Add new test cases for new AI features

### **Performance Monitoring**
- Monitor AI response times
- Track content quality trends
- Review error rates and patterns

**This comprehensive test suite ensures your AI-powered marketing platform works flawlessly across all workflows, providing confidence in AI integration quality and reliability.**