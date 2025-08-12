# Journey Validator Service for validating marketing campaign journeys
# Ensures journey integrity, completeness, and adherence to business rules
class JourneyValidator
  include ActiveModel::Model
  include ActiveModel::Attributes

  # Validation types
  VALIDATION_TYPES = %w[
    completeness
    field_requirements
    stage_dependencies
    business_rules
    audience_overlap
    timing_constraints
    logical_flow
    content_consistency
  ].freeze

  # Severity levels for validation results
  SEVERITY_LEVELS = %w[info warning error critical].freeze

  # Stage type requirements
  STAGE_TYPE_REQUIREMENTS = {
    'Awareness' => {
      required_fields: %w[name description duration_days],
      min_duration: 1,
      max_duration: 30,
      content_types: %w[blog_post social_media advertisement],
      audience_required: true
    },
    'Consideration' => {
      required_fields: %w[name description duration_days],
      min_duration: 3,
      max_duration: 60,
      content_types: %w[whitepaper case_study webinar email],
      audience_required: true
    },
    'Conversion' => {
      required_fields: %w[name description duration_days],
      min_duration: 1,
      max_duration: 14,
      content_types: %w[landing_page email infographic],
      audience_required: true,
      requires_cta: true
    },
    'Retention' => {
      required_fields: %w[name description duration_days],
      min_duration: 7,
      max_duration: 180,
      content_types: %w[newsletter email social_media],
      audience_required: false
    },
    'Advocacy' => {
      required_fields: %w[name description duration_days],
      min_duration: 14,
      max_duration: 365,
      content_types: %w[social_media case_study],
      audience_required: false
    }
  }.freeze

  # Business rules configuration
  BUSINESS_RULES = {
    min_stages: 2,
    max_stages: 10,
    max_total_duration: 365, # days
    min_total_duration: 3,   # days
    required_stage_types: %w[Awareness Conversion], # Must have at least these
    stage_sequence_rules: {
      'Awareness' => { can_follow: [], can_precede: %w[Consideration Conversion] },
      'Consideration' => { can_follow: %w[Awareness], can_precede: %w[Conversion Retention] },
      'Conversion' => { can_follow: %w[Awareness Consideration], can_precede: %w[Retention Advocacy] },
      'Retention' => { can_follow: %w[Conversion], can_precede: %w[Advocacy] },
      'Advocacy' => { can_follow: %w[Conversion Retention], can_precede: [] }
    },
    max_stage_type_occurrences: {
      'Awareness' => 2,
      'Consideration' => 3,
      'Conversion' => 2,
      'Retention' => 3,
      'Advocacy' => 2
    }
  }.freeze

  class ValidationError < StandardError; end
  class InvalidConfigurationError < ValidationError; end

  attribute :validation_types, :string, default: -> { VALIDATION_TYPES }
  attribute :strict_mode, :boolean, default: false
  attribute :warning_as_error, :boolean, default: false
  attribute :check_audience_overlap, :boolean, default: true
  attribute :custom_business_rules, :string, default: -> { {} }

  attr_reader :validation_results, :overall_status, :validation_summary

  def initialize(attributes = {})
    super(attributes)
    @validation_results = []
    @overall_status = 'unknown'
    @validation_summary = {}
    validate_configuration!
  end

  # Main validation method - validates a complete journey
  def validate_journey(journey, options = {})
    return validation_error("Journey cannot be nil") unless journey

    reset_validation_state
    @journey = journey
    @options = options
    @stages = journey.journey_stages.ordered.includes(:content_assets)

    # Run all requested validation types
    validation_types.each do |validation_type|
      begin
        case validation_type
        when 'completeness'
          validate_completeness
        when 'field_requirements'
          validate_field_requirements
        when 'stage_dependencies'
          validate_stage_dependencies
        when 'business_rules'
          validate_business_rules
        when 'audience_overlap'
          validate_audience_overlap if check_audience_overlap
        when 'timing_constraints'
          validate_timing_constraints
        when 'logical_flow'
          validate_logical_flow
        when 'content_consistency'
          validate_content_consistency
        end
      rescue => error
        add_result(
          type: validation_type,
          status: 'error',
          severity: 'critical',
          message: "Validation failed: #{error.message}",
          details: { error_class: error.class.name }
        )
      end
    end

    # Generate overall assessment
    generate_validation_summary
  end

  # Quick validation - returns true/false
  def valid?(journey, options = {})
    result = validate_journey(journey, options)
    result[:overall_status] == 'pass'
  end

  # Get validation results by severity
  def results_by_severity(severity)
    @validation_results.select { |result| result[:severity] == severity }
  end

  # Get critical issues that must be addressed
  def critical_issues
    results_by_severity('critical')
  end

  # Get all errors (critical + error)
  def errors
    @validation_results.select { |result| %w[critical error].include?(result[:severity]) }
  end

  # Get all warnings
  def warnings
    results_by_severity('warning')
  end

  # Get recommendations for improvement
  def recommendations
    @validation_results.map { |result| result[:recommendation] }.compact.uniq
  end

  # Get stage-specific validation results
  def stage_results(stage_id)
    @validation_results.select { |result| result[:stage_id] == stage_id }
  end

  private

  def validate_configuration!
    if validation_types.empty?
      raise InvalidConfigurationError, "At least one validation type must be specified"
    end
    
    invalid_types = validation_types - VALIDATION_TYPES
    if invalid_types.any?
      raise InvalidConfigurationError, "Invalid validation types: #{invalid_types.join(', ')}"
    end
  end

  def reset_validation_state
    @validation_results = []
    @overall_status = 'unknown'
    @validation_summary = {}
  end

  # Journey completeness validation
  def validate_completeness
    completeness_issues = []
    completeness_score = 100

    # Check if journey has basic information
    if @journey.name.blank?
      completeness_issues << "Journey name is required"
      completeness_score -= 20
    end

    if @journey.purpose.blank?
      completeness_issues << "Journey purpose is not defined"
      completeness_score -= 15
    end

    if @journey.audience.blank?
      completeness_issues << "Target audience is not specified"
      completeness_score -= 15
    end

    # Check stage completeness
    if @stages.empty?
      completeness_issues << "Journey has no stages"
      completeness_score -= 50
    else
      incomplete_stages = @stages.select { |stage| stage.name.blank? || stage.description.blank? }
      if incomplete_stages.any?
        completeness_issues << "#{incomplete_stages.count} stages are incomplete (missing name or description)"
        completeness_score -= incomplete_stages.count * 10
      end

      # Check for stages without duration
      stages_without_duration = @stages.select { |stage| stage.duration_days.nil? || stage.duration_days <= 0 }
      if stages_without_duration.any?
        completeness_issues << "#{stages_without_duration.count} stages missing duration"
        completeness_score -= stages_without_duration.count * 5
      end
    end

    add_result(
      type: 'completeness',
      status: completeness_score >= 70 ? 'pass' : 'fail',
      severity: completeness_score < 50 ? 'critical' : (completeness_score < 70 ? 'error' : 'info'),
      message: completeness_issues.any? ? completeness_issues.join('; ') : 'Journey completeness is acceptable',
      score: completeness_score,
      details: {
        total_stages: @stages.count,
        incomplete_stages: incomplete_stages&.count || 0,
        missing_duration_stages: stages_without_duration&.count || 0
      },
      recommendation: completeness_issues.any? ? generate_completeness_recommendations(completeness_issues) : nil
    )
  end

  # Field requirements validation for each stage type
  def validate_field_requirements
    @stages.each do |stage|
      stage_requirements = STAGE_TYPE_REQUIREMENTS[stage.stage_type]
      next unless stage_requirements

      field_issues = []
      field_score = 100

      # Check required fields
      stage_requirements[:required_fields].each do |field|
        if stage.send(field).blank?
          field_issues << "Missing required field: #{field.humanize}"
          field_score -= 25
        end
      end

      # Check duration constraints
      if stage.duration_days
        min_duration = stage_requirements[:min_duration]
        max_duration = stage_requirements[:max_duration]

        if stage.duration_days < min_duration
          field_issues << "Duration too short (min: #{min_duration} days)"
          field_score -= 15
        end

        if stage.duration_days > max_duration
          field_issues << "Duration too long (max: #{max_duration} days)"
          field_score -= 10
        end
      end

      # Check audience requirement
      if stage_requirements[:audience_required] && stage_audience_missing?(stage)
        field_issues << "Audience targeting is required for #{stage.stage_type} stages"
        field_score -= 20
      end

      # Check CTA requirement for conversion stages
      if stage_requirements[:requires_cta] && stage_cta_missing?(stage)
        field_issues << "Call-to-action is required for #{stage.stage_type} stages"
        field_score -= 25
      end

      add_result(
        type: 'field_requirements',
        status: field_score >= 80 ? 'pass' : (field_score >= 60 ? 'warning' : 'fail'),
        severity: field_score < 60 ? 'error' : (field_score < 80 ? 'warning' : 'info'),
        message: field_issues.any? ? "#{stage.name}: #{field_issues.join('; ')}" : "#{stage.name} field requirements met",
        score: field_score,
        stage_id: stage.id,
        stage_name: stage.name,
        details: {
          stage_type: stage.stage_type,
          required_fields: stage_requirements[:required_fields],
          duration_constraints: { min: stage_requirements[:min_duration], max: stage_requirements[:max_duration] }
        },
        recommendation: field_issues.any? ? generate_field_requirements_recommendations(stage, field_issues) : nil
      )
    end
  end

  # Stage dependency validation
  def validate_stage_dependencies
    dependency_issues = []
    dependency_score = 100

    # Check logical sequence based on stage types
    stage_sequence = @stages.map(&:stage_type)
    
    @stages.each_with_index do |stage, index|
      stage_rules = BUSINESS_RULES[:stage_sequence_rules][stage.stage_type]
      next unless stage_rules

      # Check if stage can follow the previous stage
      if index > 0
        previous_stage_type = @stages[index - 1].stage_type
        can_follow = stage_rules[:can_follow]
        
        if can_follow.any? && !can_follow.include?(previous_stage_type)
          dependency_issues << "#{stage.stage_type} stage '#{stage.name}' cannot directly follow #{previous_stage_type} stage"
          dependency_score -= 20
        end
      end

      # Check if stage can precede the next stage
      if index < @stages.length - 1
        next_stage_type = @stages[index + 1].stage_type
        can_precede = stage_rules[:can_precede]
        
        if can_precede.any? && !can_precede.include?(next_stage_type)
          dependency_issues << "#{stage.stage_type} stage '#{stage.name}' cannot directly precede #{next_stage_type} stage"
          dependency_score -= 20
        end
      end
    end

    # Check for timing conflicts (stages that overlap inappropriately)
    timing_conflicts = check_timing_conflicts
    if timing_conflicts.any?
      dependency_issues.concat(timing_conflicts)
      dependency_score -= timing_conflicts.length * 15
    end

    add_result(
      type: 'stage_dependencies',
      status: dependency_score >= 80 ? 'pass' : 'fail',
      severity: dependency_score < 60 ? 'error' : (dependency_score < 80 ? 'warning' : 'info'),
      message: dependency_issues.any? ? dependency_issues.join('; ') : 'Stage dependencies are valid',
      score: dependency_score,
      details: {
        stage_sequence: stage_sequence,
        timing_conflicts_count: timing_conflicts.length
      },
      recommendation: dependency_issues.any? ? generate_dependency_recommendations(dependency_issues) : nil
    )
  end

  # Business rules validation
  def validate_business_rules
    business_issues = []
    business_score = 100
    rules = BUSINESS_RULES.merge(custom_business_rules)

    # Check minimum and maximum stages
    stage_count = @stages.count
    
    if stage_count < rules[:min_stages]
      business_issues << "Journey has too few stages (#{stage_count}, minimum: #{rules[:min_stages]})"
      business_score -= 30
    end

    if stage_count > rules[:max_stages]
      business_issues << "Journey has too many stages (#{stage_count}, maximum: #{rules[:max_stages]})"
      business_score -= 20
    end

    # Check total duration
    total_duration = @stages.sum(&:duration_days)
    
    if total_duration < rules[:min_total_duration]
      business_issues << "Journey duration too short (#{total_duration} days, minimum: #{rules[:min_total_duration]})"
      business_score -= 25
    end

    if total_duration > rules[:max_total_duration]
      business_issues << "Journey duration too long (#{total_duration} days, maximum: #{rules[:max_total_duration]})"
      business_score -= 15
    end

    # Check required stage types
    present_stage_types = @stages.map(&:stage_type).uniq
    missing_required_types = rules[:required_stage_types] - present_stage_types
    
    if missing_required_types.any?
      business_issues << "Missing required stage types: #{missing_required_types.join(', ')}"
      business_score -= missing_required_types.length * 25
    end

    # Check stage type occurrence limits
    stage_type_counts = @stages.group(:stage_type).count
    rules[:max_stage_type_occurrences].each do |stage_type, max_count|
      if stage_type_counts[stage_type].to_i > max_count
        business_issues << "Too many #{stage_type} stages (#{stage_type_counts[stage_type]}, maximum: #{max_count})"
        business_score -= 15
      end
    end

    add_result(
      type: 'business_rules',
      status: business_score >= 70 ? 'pass' : 'fail',
      severity: business_score < 50 ? 'critical' : (business_score < 70 ? 'error' : 'info'),
      message: business_issues.any? ? business_issues.join('; ') : 'Business rules compliance is acceptable',
      score: business_score,
      details: {
        stage_count: stage_count,
        total_duration: total_duration,
        present_stage_types: present_stage_types,
        stage_type_counts: stage_type_counts,
        rules_applied: rules.keys
      },
      recommendation: business_issues.any? ? generate_business_rules_recommendations(business_issues) : nil
    )
  end

  # Audience overlap validation
  def validate_audience_overlap
    return unless check_audience_overlap

    overlap_issues = []
    overlap_score = 100

    # Check if journey has defined audience
    if @journey.audience.blank?
      overlap_issues << "Journey audience not defined - cannot validate overlap"
      overlap_score -= 50
    else
      # Check for stages with conflicting audience requirements
      audience_conflicts = check_audience_conflicts
      if audience_conflicts.any?
        overlap_issues.concat(audience_conflicts)
        overlap_score -= audience_conflicts.length * 20
      end

      # Check for appropriate audience progression
      audience_progression_issues = check_audience_progression
      if audience_progression_issues.any?
        overlap_issues.concat(audience_progression_issues)
        overlap_score -= audience_progression_issues.length * 15
      end
    end

    add_result(
      type: 'audience_overlap',
      status: overlap_score >= 80 ? 'pass' : (overlap_score >= 60 ? 'warning' : 'fail'),
      severity: overlap_score < 60 ? 'warning' : 'info',
      message: overlap_issues.any? ? overlap_issues.join('; ') : 'Audience overlap validation passed',
      score: overlap_score,
      details: {
        journey_audience: @journey.audience&.truncate(100),
        audience_defined: @journey.audience.present?
      },
      recommendation: overlap_issues.any? ? generate_audience_recommendations(overlap_issues) : nil
    )
  end

  # Timing constraints validation
  def validate_timing_constraints
    timing_issues = []
    timing_score = 100

    # Check for unrealistic timing patterns
    @stages.each_with_index do |stage, index|
      # Check if stage duration is realistic for stage type
      stage_requirements = STAGE_TYPE_REQUIREMENTS[stage.stage_type]
      if stage_requirements && stage.duration_days
        if stage.stage_type == 'Conversion' && stage.duration_days > 7
          timing_issues << "#{stage.name}: Conversion stages typically should be 7 days or less"
          timing_score -= 10
        elsif stage.stage_type == 'Awareness' && stage.duration_days < 3
          timing_issues << "#{stage.name}: Awareness stages typically need at least 3 days"
          timing_score -= 10
        end
      end

      # Check for timing progression issues
      if index > 0
        previous_stage = @stages[index - 1]
        if stage.stage_type == 'Conversion' && previous_stage.stage_type == 'Awareness' && previous_stage.duration_days < 7
          timing_issues << "Insufficient time between Awareness and Conversion stages"
          timing_score -= 15
        end
      end
    end

    # Check overall journey pacing
    if @stages.count > 3
      average_duration = @stages.sum(&:duration_days).to_f / @stages.count
      if average_duration < 2
        timing_issues << "Journey pacing may be too fast (average #{average_duration.round(1)} days per stage)"
        timing_score -= 15
      elsif average_duration > 30
        timing_issues << "Journey pacing may be too slow (average #{average_duration.round(1)} days per stage)"
        timing_score -= 10
      end
    end

    add_result(
      type: 'timing_constraints',
      status: timing_score >= 80 ? 'pass' : 'warning',
      severity: timing_score < 70 ? 'warning' : 'info',
      message: timing_issues.any? ? timing_issues.join('; ') : 'Timing constraints are acceptable',
      score: timing_score,
      details: {
        total_duration: @stages.sum(&:duration_days),
        average_duration_per_stage: (@stages.sum(&:duration_days).to_f / [@stages.count, 1].max).round(1),
        stage_durations: @stages.map { |s| { name: s.name, duration: s.duration_days } }
      },
      recommendation: timing_issues.any? ? generate_timing_recommendations(timing_issues) : nil
    )
  end

  # Logical flow validation
  def validate_logical_flow
    flow_issues = []
    flow_score = 100

    # Check for proper funnel progression
    funnel_order = %w[Awareness Consideration Conversion Retention Advocacy]
    stage_types = @stages.map(&:stage_type)

    # Ensure stages follow a logical marketing funnel order
    last_funnel_position = -1
    stage_types.each_with_index do |stage_type, index|
      funnel_position = funnel_order.index(stage_type)
      next unless funnel_position

      if funnel_position < last_funnel_position
        stage_name = @stages[index].name
        flow_issues << "#{stage_type} stage '#{stage_name}' appears out of sequence in marketing funnel"
        flow_score -= 20
      end
      
      last_funnel_position = [last_funnel_position, funnel_position].max
    end

    # Check for logical content progression
    content_progression_issues = check_content_progression
    if content_progression_issues.any?
      flow_issues.concat(content_progression_issues)
      flow_score -= content_progression_issues.length * 10
    end

    # Check for duplicate stage positioning
    position_duplicates = @stages.group(:position).having('COUNT(*) > 1').count
    if position_duplicates.any?
      flow_issues << "Duplicate stage positions found: #{position_duplicates.keys.join(', ')}"
      flow_score -= 30
    end

    add_result(
      type: 'logical_flow',
      status: flow_score >= 80 ? 'pass' : 'fail',
      severity: flow_score < 60 ? 'error' : (flow_score < 80 ? 'warning' : 'info'),
      message: flow_issues.any? ? flow_issues.join('; ') : 'Logical flow is acceptable',
      score: flow_score,
      details: {
        funnel_progression: stage_types,
        expected_funnel_order: funnel_order,
        position_duplicates: position_duplicates.any?
      },
      recommendation: flow_issues.any? ? generate_flow_recommendations(flow_issues) : nil
    )
  end

  # Content consistency validation
  def validate_content_consistency
    consistency_issues = []
    consistency_score = 100

    # Check for content asset consistency across stages
    content_types_by_stage = @stages.map do |stage|
      {
        stage: stage,
        content_types: stage.content_assets.pluck(:content_type).uniq
      }
    end

    # Check if stages have appropriate content types for their stage type
    content_types_by_stage.each do |stage_info|
      stage = stage_info[:stage]
      content_types = stage_info[:content_types]
      expected_types = STAGE_TYPE_REQUIREMENTS.dig(stage.stage_type, :content_types) || []

      if content_types.empty? && expected_types.any?
        consistency_issues << "#{stage.name}: No content assets defined"
        consistency_score -= 15
      elsif content_types.any?
        unexpected_types = content_types - expected_types
        if unexpected_types.any?
          consistency_issues << "#{stage.name}: Unexpected content types: #{unexpected_types.join(', ')}"
          consistency_score -= 10
        end
      end
    end

    # Check for brand consistency (if brand identity is available)
    if @journey.brand_identity.present?
      brand_consistency_issues = check_brand_consistency
      if brand_consistency_issues.any?
        consistency_issues.concat(brand_consistency_issues)
        consistency_score -= brand_consistency_issues.length * 5
      end
    end

    add_result(
      type: 'content_consistency',
      status: consistency_score >= 80 ? 'pass' : 'warning',
      severity: consistency_score < 70 ? 'warning' : 'info',
      message: consistency_issues.any? ? consistency_issues.join('; ') : 'Content consistency is acceptable',
      score: consistency_score,
      details: {
        stages_with_content: content_types_by_stage.select { |s| s[:content_types].any? }.count,
        total_content_assets: @stages.sum { |s| s.content_assets.count },
        brand_identity_present: @journey.brand_identity.present?
      },
      recommendation: consistency_issues.any? ? generate_consistency_recommendations(consistency_issues) : nil
    )
  end

  # Helper methods for specific validation checks

  def stage_audience_missing?(stage)
    # Check if stage configuration has audience targeting
    stage_config = stage.configuration || {}
    stage_config['audience'].blank? && @journey.audience.blank?
  end

  def stage_cta_missing?(stage)
    # Check if stage has call-to-action in content or configuration
    stage_config = stage.configuration || {}
    content_has_cta = stage.content_assets.any? { |asset| 
      asset.content.to_s.downcase.match?(/\b(buy|order|click|visit|call|contact|subscribe|sign up)\b/)
    }
    
    !content_has_cta && stage_config['call_to_action'].blank?
  end

  def check_timing_conflicts
    conflicts = []
    
    # This would be more sophisticated in a real implementation
    # checking for stages that might have overlapping execution times
    # or unrealistic transitions
    
    conflicts
  end

  def check_audience_conflicts
    conflicts = []
    
    # Check for stages that target conflicting audiences
    # This is a simplified check - real implementation would be more sophisticated
    
    conflicts
  end

  def check_audience_progression
    progression_issues = []
    
    # Check if audience becomes more targeted/specific as journey progresses
    # This is a placeholder for more sophisticated audience analysis
    
    progression_issues
  end

  def check_content_progression
    progression_issues = []
    
    # Check if content becomes more specific/targeted as journey progresses
    content_counts = @stages.map { |s| s.content_assets.count }
    
    # Simple check: conversion stages should have content
    @stages.each do |stage|
      if stage.stage_type == 'Conversion' && stage.content_assets.empty?
        progression_issues << "#{stage.name}: Conversion stages should have content assets"
      end
    end
    
    progression_issues
  end

  def check_brand_consistency
    consistency_issues = []
    
    # This would check brand guidelines compliance across content assets
    # Placeholder for more sophisticated brand consistency checking
    
    consistency_issues
  end

  # Recommendation generators

  def generate_completeness_recommendations(issues)
    recommendations = []
    
    issues.each do |issue|
      case issue
      when /name is required/
        recommendations << "Add a descriptive name for the journey"
      when /purpose/
        recommendations << "Define the business purpose and goals for this journey"
      when /audience/
        recommendations << "Specify the target audience for this journey"
      when /no stages/
        recommendations << "Add at least #{BUSINESS_RULES[:min_stages]} stages to create a complete journey"
      when /incomplete/
        recommendations << "Complete all stage information including names and descriptions"
      when /duration/
        recommendations << "Set realistic durations for all stages"
      end
    end
    
    recommendations.uniq
  end

  def generate_field_requirements_recommendations(stage, issues)
    recommendations = []
    
    issues.each do |issue|
      case issue
      when /Missing required field/
        recommendations << "Complete all required fields for #{stage.stage_type} stages"
      when /Duration too short/
        recommendations << "Increase stage duration to meet minimum requirements"
      when /Duration too long/
        recommendations << "Consider breaking long stages into smaller phases"
      when /Audience targeting/
        recommendations << "Define specific audience targeting for this stage"
      when /Call-to-action/
        recommendations << "Add a clear call-to-action for conversion optimization"
      end
    end
    
    recommendations.uniq
  end

  def generate_dependency_recommendations(issues)
    ["Review stage sequence and ensure logical flow",
     "Adjust stage order to follow marketing funnel progression",
     "Consider adding transition stages if needed"]
  end

  def generate_business_rules_recommendations(issues)
    recommendations = []
    
    issues.each do |issue|
      case issue
      when /too few stages/
        recommendations << "Add more stages to create a complete customer journey"
      when /too many stages/
        recommendations << "Consolidate stages or split into multiple journeys"
      when /duration too short/
        recommendations << "Extend stage durations for better customer engagement"
      when /duration too long/
        recommendations << "Shorten journey duration or split into phases"
      when /Missing required stage types/
        recommendations << "Add required stage types for a complete marketing funnel"
      when /Too many.*stages/
        recommendations << "Reduce duplicate stage types or consolidate similar stages"
      end
    end
    
    recommendations.uniq
  end

  def generate_audience_recommendations(issues)
    ["Define clear audience targeting for the journey",
     "Ensure audience progression from broad to specific",
     "Validate audience segments are compatible across stages"]
  end

  def generate_timing_recommendations(issues)
    ["Review stage durations for realistic customer progression",
     "Ensure adequate time between awareness and conversion",
     "Balance journey pacing for optimal engagement"]
  end

  def generate_flow_recommendations(issues)
    ["Reorder stages to follow marketing funnel progression",
     "Ensure logical content progression from awareness to conversion",
     "Fix duplicate stage positions"]
  end

  def generate_consistency_recommendations(issues)
    ["Add appropriate content assets for each stage type",
     "Ensure content types match stage objectives",
     "Maintain brand consistency across all content"]
  end

  # Summary generation

  def generate_validation_summary
    critical_count = results_by_severity('critical').length
    error_count = results_by_severity('error').length
    warning_count = results_by_severity('warning').length
    
    @overall_status = if critical_count > 0 || (warning_as_error && warning_count > 0)
      'fail'
    elsif error_count > 0
      'fail'
    elsif warning_count > 3
      'warning'
    else
      'pass'
    end

    @validation_summary = {
      overall_status: @overall_status,
      total_validations: @validation_results.length,
      critical_issues: critical_count,
      errors: error_count,
      warnings: warning_count,
      validation_results: @validation_results,
      recommendations: recommendations,
      summary: generate_summary_message(@overall_status, critical_count, error_count, warning_count),
      journey_info: {
        id: @journey.id,
        name: @journey.name,
        stage_count: @stages.count,
        total_duration: @stages.sum(&:duration_days),
        stage_types: @stages.map(&:stage_type).uniq
      }
    }
  end

  def generate_summary_message(status, critical_count, error_count, warning_count)
    case status
    when 'pass'
      "Journey validation passed successfully. #{warning_count > 0 ? "#{warning_count} warnings to consider." : ''}"
    when 'warning'
      "Journey validation passed with #{warning_count} warnings. Review recommended before publishing."
    when 'fail'
      message = "Journey validation failed"
      issues = []
      issues << "#{critical_count} critical issues" if critical_count > 0
      issues << "#{error_count} errors" if error_count > 0
      message += " with #{issues.join(' and ')}" if issues.any?
      message + ". Revisions required before use."
    end
  end

  # Utility methods

  def add_result(result_hash)
    @validation_results << result_hash.merge(
      timestamp: Time.current,
      validator_version: '1.0'
    )
  end

  def validation_error(message)
    {
      overall_status: 'error',
      error: message,
      validation_results: [],
      recommendations: ["Fix validation error: #{message}"]
    }
  end
end