# AI Workflow Manual Test Guide

This guide provides step-by-step instructions for manually performing each AI-powered workflow test to verify functionality for users.

## 1. API Integration Test
**Purpose:** Verify programmatic AI content generation endpoints work correctly

### Steps to Test:
1. **Setup:** Create and login with a test user account
2. **Test Social Media API:**
   - Send POST request to `/api/v1/content_generation/social_media`
   - Include platform-specific parameters (Twitter, LinkedIn, Facebook)
   - Verify response contains generated content and metadata
   - Check character count matches platform limits
3. **Test Email API:**
   - Send POST request to `/api/v1/content_generation/email`
   - Include email parameters (subject, body, audience)
   - Verify response structure and content quality
4. **Test Campaign API:**
   - Send POST request to `/api/v1/campaign_generation`
   - Include campaign objectives and target audience
   - Verify complete campaign plan generation
5. **Validate:** Check all responses have proper structure, success status, and AI-generated content

---

## 2. Brand Processing Test
**Purpose:** Test AI-powered brand voice extraction and guideline processing

### Steps to Test:
1. **Create Brand Identity:**
   - Navigate to `/brand_identities/new`
   - Fill in brand name, industry, voice tone, and target audience
   - Paste brand guidelines text in the guidelines field
2. **Process Brand Materials:**
   - Submit form to create brand identity
   - Wait for AI processing to analyze brand voice
   - Verify brand voice extraction appears
3. **Validate AI Analysis:**
   - Check for tone analysis results
   - Verify key messaging points extraction
   - Confirm brand personality traits identification
   - Review competitive positioning analysis
4. **Test Voice Application:**
   - Generate content using this brand identity
   - Verify content matches brand voice guidelines

---

## 3. Campaign Generation Test
**Purpose:** Test complete AI-powered campaign strategy generation

### Steps to Test:
1. **Create New Campaign:**
   - Navigate to `/campaign_plans`
   - Click "New Campaign"
   - Fill in campaign name and description
2. **Configure Campaign Parameters:**
   - Select campaign type (awareness/conversion/retention)
   - Choose objective (increase_brand_awareness, drive_sales, etc.)
   - Enter target audience description
   - Set budget constraints
3. **Generate Campaign Plan:**
   - Submit form to trigger AI generation
   - Wait for processing (up to 2 minutes)
4. **Verify Generated Elements:**
   - Check for strategic recommendations
   - Review channel mix suggestions
   - Validate content calendar generation
   - Confirm budget allocation recommendations
   - Verify KPI and success metrics definition

---

## 4. Campaign Intelligence Test
**Purpose:** Test AI market analysis and competitive intelligence generation

### Steps to Test:
1. **Create Campaign:**
   - Create a new campaign plan with awareness objective
   - Navigate to campaign intelligence section (`/campaign_plans/{id}/intelligence`)
2. **Generate Market Analysis:**
   - Click "Generate Analysis" or "Generate Intelligence"
   - Wait for AI processing to complete
3. **Verify Analysis Sections:**
   - **Competitive Analysis:** Check for competitor insights
   - **Market Trends:** Verify industry trend identification
   - **Audience Insights:** Review demographic and psychographic analysis
   - **Opportunity Identification:** Check for market gap analysis
4. **Test Recommendations:**
   - Review strategic recommendations
   - Verify tactical suggestions are actionable
   - Check alignment with campaign objectives

---

## 5. Content Optimization Test
**Purpose:** Test AI content improvement and A/B variant generation

### Steps to Test:
1. **Create Base Content:**
   - Navigate to `/generated_contents/new`
   - Enter basic, unoptimized content
   - Select content type (social_post)
   - Submit to create content
2. **Optimize Content:**
   - Click "Optimize" or "Optimize Content" button
   - Wait for AI optimization analysis
3. **Review Optimization Suggestions:**
   - Check headline improvements
   - Review CTA enhancements
   - Verify engagement hook suggestions
4. **Generate A/B Variants:**
   - Click "Generate Variants"
   - Review 3-5 different versions
   - Check each variant targets different angles
5. **Apply Optimizations:**
   - Select and apply suggested improvements
   - Compare before/after versions

---

## 6. Email Content Test
**Purpose:** Test complete email campaign generation with AI

### Steps to Test:
1. **Navigate to Content Creation:**
   - Go to `/generated_contents/new`
   - Select "email" as content type
2. **Configure Email Parameters:**
   - Enter campaign title
   - Select format variant (short/medium/long)
   - Leave body content blank for AI generation
3. **Generate Email Content:**
   - Click "Generate Content"
   - Wait for AI processing (up to 60 seconds)
4. **Verify Email Components:**
   - **Subject Line:** Check for compelling, action-oriented subject
   - **Preview Text:** Verify preview text is optimized
   - **Email Body:** 
     - Opening hook engagement
     - Clear value proposition
     - Structured content sections
     - Strong call-to-action
   - **Personalization:** Check for merge tags and dynamic content
5. **Test Variants:**
   - Generate multiple subject line options
   - Create different email lengths
   - Test various tones (professional, casual, urgent)

---

## 7. Customer Journey AI Test
**Purpose:** Test AI-powered journey mapping and step recommendations

### Steps to Test:
1. **Create New Journey:**
   - Navigate to `/journeys/new`
   - Enter journey name and description
   - Select journey type (onboarding, purchase, retention)
2. **Get AI Suggestions:**
   - Click "Get AI Suggestions" button
   - Wait for AI to analyze journey type
3. **Review Suggested Steps:**
   - Check for logical journey progression
   - Verify touchpoint recommendations
   - Review timing suggestions between steps
4. **Apply and Customize:**
   - Select relevant suggested steps
   - Add journey to system
   - Verify step sequencing
5. **Test Journey Optimization:**
   - Review AI-suggested improvements
   - Check for bottleneck identification
   - Verify conversion optimization tips

---

## 8. Social Media Content Test
**Purpose:** Test platform-specific social content generation

### Steps to Test:
1. **Create Campaign Context:**
   - First create a campaign plan for context
   - Navigate to content creation within campaign
2. **Test Each Platform:**
   
   **Twitter/X:**
   - Select Twitter as platform
   - Generate content
   - Verify 280 character limit compliance
   - Check for hashtag suggestions
   - Verify thread creation for longer content
   
   **LinkedIn:**
   - Select LinkedIn platform
   - Generate professional tone content
   - Verify 3000 character optimization
   - Check for industry-specific language
   
   **Facebook:**
   - Select Facebook platform
   - Generate engaging content
   - Verify optimal length (40-80 characters)
   - Check for emoji usage suggestions
   
   **Instagram:**
   - Select Instagram platform
   - Generate visual-first content
   - Verify hashtag recommendations (up to 30)
   - Check for caption formatting

3. **Verify Platform Optimization:**
   - Character count compliance
   - Platform-specific features (hashtags, mentions, emojis)
   - Tone appropriate for platform audience
   - Engagement elements (questions, CTAs)

---

## Common Validation Points

### For All AI-Generated Content:
- ✅ Content is relevant to input parameters
- ✅ No placeholder text (Lorem ipsum)
- ✅ Proper grammar and spelling
- ✅ Appropriate tone for audience
- ✅ Clear call-to-action when applicable
- ✅ Brand voice consistency (if brand identity provided)

### Performance Expectations:
- Generation time: 30-120 seconds
- Response should include metadata (word count, service used)
- Error handling for invalid inputs
- Graceful degradation if AI service unavailable

### Quality Metrics:
- Readability score appropriate for audience
- Sentiment alignment with campaign objectives
- Keyword density for SEO (where applicable)
- Engagement potential based on platform best practices