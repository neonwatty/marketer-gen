# Brand-Journey Integration System Usage Guide

## Overview

The brand-journey integration system provides seamless integration between brand guidelines and journey content generation, validation, and analytics. This system ensures all journey content adheres to brand standards while providing real-time feedback and automated compliance enhancements.

## Core Components

### 1. Enhanced JourneySuggestionEngine

The suggestion engine now includes brand context in all AI-generated suggestions:

```ruby
# Generate brand-aware suggestions
engine = JourneySuggestionEngine.new(
  journey: journey,
  user: user,
  current_step: step,
  provider: :openai
)

# Suggestions automatically include brand compliance scoring
suggestions = engine.generate_suggestions(
  stage: 'awareness',
  content_type: 'email'
)

# Each suggestion now includes:
# - brand_compliance_score (0.0-1.0)
# - compliance_warnings (if any)
# - brand_enhancements (specific recommendations)
```

### 2. Journey::BrandComplianceService

Comprehensive brand compliance checking for journey content:

```ruby
# Check compliance for a journey step
compliance_service = Journey::BrandComplianceService.new(
  journey: journey,
  step: step,
  content: "Your content here",
  context: { channel: 'email', audience: 'professionals' }
)

# Full compliance check
result = compliance_service.check_compliance
# Returns: { compliant: true/false, score: 0.95, violations: [], suggestions: [] }

# Quick pre-generation check
quick_result = compliance_service.pre_generation_check("Suggested content")
# Returns: { allowed: true/false, score: 0.85, violations: [] }

# Auto-fix violations
fixed_result = compliance_service.auto_fix_violations
# Returns: { fixed_content: "Improved content", fixes_applied: [...] }

# Get recommendations
recommendations = compliance_service.get_recommendations
# Returns: { recommendations: [...], priority_fixes: [...], estimated_improvement: 0.15 }
```

### 3. Enhanced JourneyStep Model

Journey steps now include built-in brand compliance methods:

```ruby
step = journey.journey_steps.first

# Check brand compliance
compliance = step.check_brand_compliance
puts "Compliance score: #{compliance[:score]}"

# Quick compliance check
score = step.quick_compliance_score  # Returns 0.0-1.0

# Check if compliant
is_compliant = step.brand_compliant?  # Returns true/false

# Get violations and suggestions
violations = step.compliance_violations
suggestions = step.compliance_suggestions

# Auto-fix compliance issues
fix_result = step.auto_fix_compliance_issues
if fix_result[:fixed]
  puts "Content was automatically improved"
end

# Check specific messaging
allowed = step.messaging_compliant?("Hey there!")  # false if brand is formal

# Get applicable brand guidelines
guidelines = step.applicable_brand_guidelines
```

### 4. Journey Analytics with Brand Compliance

Enhanced journey analytics include comprehensive brand tracking:

```ruby
# Brand compliance summary
summary = journey.brand_compliance_summary(30)  # Last 30 days
puts "Average compliance: #{summary[:average_score]}"
puts "Compliance trend: #{summary[:score_trend]}"

# Compliance by step
step_compliance = journey.brand_compliance_by_step(30)
step_compliance.each do |step_id, data|
  puts "Step #{step_id}: #{data[:average_score]} compliance"
end

# Violation breakdown
violations = journey.brand_violations_breakdown(30)
puts "Most common violation: #{violations[:by_category].max_by(&:last)}"

# Overall brand health
health_score = journey.overall_brand_health_score
puts "Brand health: #{(health_score * 100).round(1)}%"

# Get brand compliance alerts
alerts = journey.brand_compliance_alerts
alerts.each do |alert|
  puts "#{alert[:severity].upcase}: #{alert[:message]}"
end
```

### 5. Brand Integration Service (Advanced Orchestration)

The integration service provides high-level orchestration of brand-journey operations:

```ruby
service = Journey::BrandIntegrationService.new(journey: journey, user: user)

# Generate brand-aware suggestions
result = service.orchestrate_brand_journey_flow(
  operation: :generate_suggestions,
  filters: { stage: 'consideration' },
  current_step: current_step
)

# Validate all journey content
validation = service.orchestrate_brand_journey_flow(
  operation: :validate_content,
  compliance_options: { compliance_level: :strict }
)

# Auto-enhance compliance across journey
enhancement = service.orchestrate_brand_journey_flow(
  operation: :auto_enhance_compliance,
  low_compliance_only: true
)

# Analyze brand performance
analysis = service.orchestrate_brand_journey_flow(
  operation: :analyze_brand_performance,
  period_days: 30
)

# Sync with updated brand guidelines
sync_result = service.orchestrate_brand_journey_flow(
  operation: :sync_brand_updates,
  updated_guidelines: [guideline_id_1, guideline_id_2]
)

# Check integration health
health = service.integration_health_check
```

## Simple Facade Usage

For common operations, use the `BrandJourneyOrchestrator` facade:

```ruby
# Generate brand-aware suggestions
suggestions = BrandJourneyOrchestrator.generate_brand_aware_suggestions(
  journey: journey,
  filters: { content_type: 'email' }
)

# Validate journey compliance
validation = BrandJourneyOrchestrator.validate_journey_brand_compliance(
  journey: journey
)

# Quick compliance check
quick_check = BrandJourneyOrchestrator.quick_compliance_check(journey: journey)
puts "Overall compliance: #{quick_check[:compliance_rate]}%"

# Check integration status
status = BrandJourneyOrchestrator.brand_integration_status(journey: journey)
puts "Integration status: #{status[:status]}"
```

## Real-time Features

### ActionCable Integration

The system broadcasts real-time updates for compliance changes:

```javascript
// Subscribe to journey compliance updates
consumer.subscriptions.create({
  channel: "JourneyComplianceChannel",
  journey_id: journeyId
}, {
  received(data) {
    if (data.event === 'compliance_check_complete') {
      updateComplianceUI(data.compliant, data.score);
    }
  }
});

// Subscribe to individual step compliance
consumer.subscriptions.create({
  channel: "JourneyStepComplianceChannel", 
  step_id: stepId
}, {
  received(data) {
    if (data.event === 'compliance_updated') {
      updateStepCompliance(data.compliance_score);
    }
  }
});
```

### Automatic Validation

Journey steps automatically validate brand compliance on save:

```ruby
# This will trigger brand compliance validation
step.update!(description: "New content that may violate brand guidelines")

# Validation errors will include brand compliance issues
if step.errors.any?
  step.errors[:description].each do |error|
    puts "Brand compliance issue: #{error}"
  end
end
```

## Configuration

Configure the brand integration system:

```ruby
# Configure JourneySuggestionEngine defaults
JourneySuggestionEngine.configure do |config|
  config.default_provider = :anthropic
  config.cache_ttl = 2.hours
end

# Configure BrandComplianceService
Journey::BrandComplianceService.configure do |config|
  config.default_compliance_level = :standard
  config.cache_results = true
  config.async_processing = false
  config.broadcast_violations = true
end

# Configure BrandIntegrationService
Journey::BrandIntegrationService.configure do |config|
  config.enable_real_time_validation = true
  config.enable_auto_suggestions = true
  config.compliance_check_threshold = 0.7
  config.auto_fix_enabled = false  # Enable with caution
end
```

## Integration with Existing Workflows

### Controller Integration

```ruby
class JourneyStepsController < ApplicationController
  def create
    @step = @journey.journey_steps.build(step_params)
    
    if @step.save
      # Automatic brand compliance check happens via callbacks
      compliance_score = @step.quick_compliance_score
      
      if compliance_score < 0.7
        flash[:warning] = "Content may not fully comply with brand guidelines"
      end
      
      redirect_to @journey
    else
      # Brand compliance errors are included in @step.errors
      render :new
    end
  end
  
  def check_compliance
    compliance = @step.check_brand_compliance
    render json: {
      compliant: compliance[:compliant],
      score: compliance[:score],
      violations: compliance[:violations]
    }
  end
end
```

### Background Jobs

```ruby
class BrandComplianceJob < ApplicationJob
  def perform(journey_id)
    journey = Journey.find(journey_id)
    
    # Run comprehensive brand analysis
    result = BrandJourneyOrchestrator.analyze_brand_performance(
      journey: journey,
      period_days: 30
    )
    
    # Send summary email if there are alerts
    if result[:alerts].any?
      BrandComplianceMailer.alert_summary(journey.user, result).deliver_now
    end
  end
end
```

## Analytics and Reporting

### Brand Health Dashboard Data

```ruby
def brand_health_data(journey)
  {
    overall_health: journey.overall_brand_health_score,
    compliance_trend: journey.brand_compliance_trend(30),
    step_compliance: journey.brand_compliance_by_step(30),
    violation_breakdown: journey.brand_violations_breakdown(30),
    alerts: journey.brand_compliance_alerts,
    recent_checks: journey.journey_insights.brand_compliance.recent(7).count
  }
end
```

### Compliance Reports

```ruby
class BrandComplianceReport
  def initialize(journey, period_days = 30)
    @journey = journey
    @period = period_days
  end
  
  def generate
    {
      summary: @journey.brand_compliance_summary(@period),
      trends: compliance_trends,
      recommendations: compliance_recommendations,
      step_analysis: step_by_step_analysis
    }
  end
  
  private
  
  def compliance_trends
    JourneyInsight.brand_compliance_summary(@journey.id, @period)
  end
  
  def compliance_recommendations
    service = Journey::BrandIntegrationService.new(journey: @journey)
    analysis = service.orchestrate_brand_journey_flow(
      operation: :analyze_brand_performance,
      period_days: @period
    )
    analysis[:recommendations]
  end
  
  def step_by_step_analysis
    @journey.journey_steps.map do |step|
      {
        step_name: step.name,
        compliance_score: step.quick_compliance_score,
        violations: step.compliance_violations.length,
        last_check: step.latest_compliance_check&.calculated_at
      }
    end
  end
end
```

This integration system provides comprehensive brand compliance management while maintaining the flexibility and performance of the existing journey system. All features are backward compatible and can be gradually adopted based on your needs.