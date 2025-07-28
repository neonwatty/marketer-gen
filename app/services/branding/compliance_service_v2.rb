module Branding
  class ComplianceServiceV2
    include ActiveSupport::Configurable
    
    config_accessor :cache_store, default: Rails.cache
    config_accessor :broadcast_violations, default: true
    config_accessor :async_processing, default: true
    config_accessor :max_processing_time, default: 30.seconds
    
    attr_reader :brand, :content, :content_type, :options
    
    COMPLIANCE_LEVELS = {
      strict: { threshold: 0.95, tolerance: :none },
      standard: { threshold: 0.85, tolerance: :low },
      flexible: { threshold: 0.70, tolerance: :medium },
      advisory: { threshold: 0.50, tolerance: :high }
    }.freeze
    
    def initialize(brand, content, content_type = "general", options = {})
      @brand = brand
      @content = content
      @content_type = content_type
      @options = default_options.merge(options)
      @validators = []
      @results = {}
      
      setup_validators
    end
    
    def check_compliance
      start_time = Time.current
      
      # Run validations based on configuration
      if options[:async] && content_large?
        check_compliance_async
      else
        check_compliance_sync
      end
      
      # Compile results
      compile_results
      
      # Generate suggestions if requested
      if options[:generate_suggestions]
        @results[:suggestions] = generate_intelligent_suggestions
      end
      
      # Add metadata
      @results[:metadata] = {
        processing_time: Time.current - start_time,
        validators_used: @validators.map(&:class).map(&:name),
        compliance_level: options[:compliance_level],
        cached_results_used: @results[:cache_hits] || 0
      }
      
      @results
    rescue StandardError => e
      handle_error(e)
    end
    
    def validate_and_fix
      compliance_results = check_compliance
      
      return compliance_results if compliance_results[:compliant]
      
      # Attempt to auto-fix violations
      fix_results = auto_fix_violations(compliance_results[:violations])
      
      # Re-validate fixed content if changes were made
      if fix_results[:content_changed]
        @content = fix_results[:fixed_content]
        revalidation_results = check_compliance
        
        {
          original_results: compliance_results,
          fixes_applied: fix_results[:fixes],
          final_results: revalidation_results,
          fixed_content: fix_results[:fixed_content]
        }
      else
        compliance_results.merge(fixes_available: fix_results[:fixes])
      end
    end
    
    def check_specific_aspects(aspects)
      results = {}
      
      aspects.each do |aspect|
        validator = validator_for_aspect(aspect)
        next unless validator
        
        result = run_validator(validator)
        results[aspect] = result
      end
      
      compile_aspect_results(results)
    end
    
    def preview_fixes(violations = nil)
      violations ||= @results[:violations] || []
      
      suggestion_engine = Compliance::SuggestionEngine.new(brand, violations, @results)
      fixes = {}
      
      violations.each do |violation|
        fixes[violation[:id]] = suggestion_engine.generate_fix(violation, content)
      end
      
      fixes
    end
    
    private
    
    def default_options
      {
        compliance_level: :standard,
        async: config.async_processing,
        generate_suggestions: true,
        real_time_updates: config.broadcast_violations,
        cache_results: true,
        include_visual: content_type.include?("visual") || content_type.include?("image"),
        nlp_analysis_depth: :full,
        timeout: config.max_processing_time
      }
    end
    
    def setup_validators
      # Always include rule engine
      @validators << Compliance::RuleEngine.new(brand)
      
      # NLP analyzer for text content
      if has_text_content?
        @validators << Compliance::NlpAnalyzer.new(brand, content, options)
      end
      
      # Visual validator for visual content
      if options[:include_visual] && options[:visual_data]
        @validators << Compliance::VisualValidator.new(brand, content, options)
      end
      
      # Add custom validators if provided
      if options[:custom_validators]
        @validators.concat(options[:custom_validators])
      end
    end
    
    def check_compliance_sync
      @validators.each do |validator|
        result = run_validator(validator)
        merge_validator_results(result, validator)
      end
    end
    
    def check_compliance_async
      futures = @validators.map do |validator|
        Concurrent::Future.execute do
          run_validator(validator)
        end
      end
      
      # Wait for all validators with timeout
      futures.each_with_index do |future, index|
        if future.wait(options[:timeout])
          merge_validator_results(future.value, @validators[index])
        else
          @results[:errors] ||= []
          @results[:errors] << {
            validator: @validators[index].class.name,
            error: "Timeout exceeded"
          }
        end
      end
    end
    
    def run_validator(validator)
      cache_key = validator_cache_key(validator)
      
      if options[:cache_results] && cache_store
        cached = cache_store.fetch(cache_key, expires_in: 5.minutes) do
          run_validator_safely(validator)
        end
        
        @results[:cache_hits] ||= 0
        @results[:cache_hits] += 1 if cached[:cached]
        
        cached
      else
        run_validator_safely(validator)
      end
    end
    
    def run_validator_safely(validator)
      if validator.is_a?(Compliance::RuleEngine)
        # Rule engine has different interface
        context = {
          content_type: content_type,
          channel: options[:channel],
          audience: options[:audience]
        }
        validator.evaluate(content, context)
      else
        validator.validate
      end
    rescue StandardError => e
      {
        error: e.message,
        validator: validator.class.name,
        violations: [],
        suggestions: []
      }
    end
    
    def merge_validator_results(result, validator)
      return if result[:error]
      
      # Merge violations
      if result[:violations]
        @results[:violations] ||= []
        @results[:violations].concat(normalize_violations(result[:violations], validator))
      elsif result[:failed]
        # Handle RuleEngine format
        @results[:violations] ||= []
        @results[:violations].concat(convert_rule_failures(result[:failed]))
      end
      
      # Merge suggestions
      if result[:suggestions]
        @results[:suggestions] ||= []
        @results[:suggestions].concat(result[:suggestions])
      elsif result[:warnings]
        # Handle RuleEngine warnings as suggestions
        @results[:suggestions] ||= []
        @results[:suggestions].concat(convert_rule_warnings(result[:warnings]))
      end
      
      # Store analysis results
      if result[:analysis]
        @results[:analysis] ||= {}
        @results[:analysis][validator.class.name.demodulize.underscore] = result[:analysis]
      end
      
      # Track scores
      if result[:score]
        @results[:scores] ||= {}
        @results[:scores][validator.class.name.demodulize.underscore] = result[:score]
      end
    end
    
    def normalize_violations(violations, validator)
      violations.map.with_index do |violation, index|
        violation.merge(
          id: "#{validator.class.name.demodulize.underscore}_#{index}",
          validator_type: validator.class.name.demodulize.underscore
        )
      end
    end
    
    def convert_rule_failures(failures)
      failures.map do |failure|
        {
          id: failure[:rule_id],
          type: "rule_violation",
          severity: failure[:severity],
          message: failure[:message],
          details: failure[:details],
          validator_type: "rule_engine"
        }
      end
    end
    
    def convert_rule_warnings(warnings)
      warnings.map do |warning|
        {
          type: "rule_warning",
          message: warning[:message],
          details: warning[:details],
          priority: "low"
        }
      end
    end
    
    def compile_results
      violations = @results[:violations] || []
      suggestions = @results[:suggestions] || []
      
      # Calculate overall compliance
      compliance_level = COMPLIANCE_LEVELS[options[:compliance_level]]
      score = calculate_overall_score
      
      @results[:compliant] = violations.empty? || 
                             (score >= compliance_level[:threshold] && 
                              allows_violations?(violations, compliance_level))
      
      @results[:score] = score
      @results[:summary] = generate_summary(score, violations, suggestions)
      @results[:violations] = prioritize_violations(violations)
      @results[:suggestions] = deduplicate_suggestions(suggestions)
      
      # Broadcast if enabled
      broadcast_results if options[:real_time_updates]
      
      @results
    end
    
    def calculate_overall_score
      scores = @results[:scores] || {}
      return 1.0 if scores.empty?
      
      # Weight scores based on validator importance
      weights = {
        "rule_engine" => 0.4,
        "nlp_analyzer" => 0.35,
        "visual_validator" => 0.25
      }
      
      weighted_sum = 0.0
      total_weight = 0.0
      
      scores.each do |validator, score|
        weight = weights[validator] || 0.2
        weighted_sum += score * weight
        total_weight += weight
      end
      
      total_weight > 0 ? (weighted_sum / total_weight).round(3) : 0.0
    end
    
    def allows_violations?(violations, compliance_level)
      case compliance_level[:tolerance]
      when :none
        false
      when :low
        violations.none? { |v| %w[critical high].include?(v[:severity]) }
      when :medium
        violations.none? { |v| v[:severity] == "critical" }
      when :high
        true
      end
    end
    
    def generate_summary(score, violations, suggestions)
      severity_counts = violations.group_by { |v| v[:severity] }.transform_values(&:count)
      
      if violations.empty?
        "Content is fully compliant with brand guidelines (score: #{(score * 100).round}%)."
      elsif score >= 0.9
        "Content is highly compliant with minor issues (score: #{(score * 100).round}%)."
      elsif score >= 0.7
        "Content is moderately compliant. #{severity_counts.map { |s, c| "#{c} #{s}" }.join(', ')} violations found."
      elsif score >= 0.5
        "Content has compliance issues that should be addressed. #{violations.count} violations found."
      else
        "Content has significant compliance violations requiring major revisions."
      end
    end
    
    def prioritize_violations(violations)
      severity_order = { "critical" => 0, "high" => 1, "medium" => 2, "low" => 3 }
      
      violations.sort_by do |violation|
        [
          severity_order[violation[:severity]] || 4,
          violation[:type],
          violation[:message]
        ]
      end
    end
    
    def deduplicate_suggestions(suggestions)
      suggestions.uniq { |s| [s[:type], s[:message]] }
                .sort_by { |s| s[:priority] == "high" ? 0 : 1 }
    end
    
    def generate_intelligent_suggestions
      all_violations = @results[:violations] || []
      analysis_data = @results[:analysis] || {}
      
      suggestion_engine = Compliance::SuggestionEngine.new(brand, all_violations, analysis_data)
      suggestion_engine.generate_suggestions
    end
    
    def auto_fix_violations(violations)
      return { content_changed: false, fixes: [] } if violations.empty?
      
      suggestion_engine = Compliance::SuggestionEngine.new(brand, violations, @results[:analysis])
      fixed_content = content.dup
      fixes_applied = []
      
      # Apply fixes in order of severity
      violations.each do |violation|
        fix = suggestion_engine.generate_fix(violation, fixed_content)
        
        if fix[:confidence] > 0.7
          fixed_content = fix[:fixed_content]
          fixes_applied << {
            violation_id: violation[:id],
            fix_applied: fix[:changes_made],
            confidence: fix[:confidence]
          }
        end
      end
      
      {
        content_changed: fixes_applied.any?,
        fixed_content: fixed_content,
        fixes: fixes_applied
      }
    end
    
    def broadcast_results
      return unless config.broadcast_violations
      
      ActionCable.server.broadcast(
        "brand_compliance_#{brand.id}",
        {
          event: "compliance_check_complete",
          compliant: @results[:compliant],
          score: @results[:score],
          violations_count: (@results[:violations] || []).count,
          suggestions_count: (@results[:suggestions] || []).count
        }
      )
    end
    
    def validator_cache_key(validator)
      [
        "brand_compliance",
        brand.id,
        validator.class.name.underscore,
        Digest::MD5.hexdigest(content.to_s),
        content_type
      ].join(":")
    end
    
    def content_large?
      content.length > 10_000
    end
    
    def has_text_content?
      content.is_a?(String) && content.present?
    end
    
    def validator_for_aspect(aspect)
      case aspect
      when :tone, :readability, :sentiment, :brand_voice
        Compliance::NlpAnalyzer.new(brand, content, options)
      when :colors, :typography, :logo, :composition
        Compliance::VisualValidator.new(brand, content, options)
      when :rules, :guidelines
        Compliance::RuleEngine.new(brand)
      else
        nil
      end
    end
    
    def compile_aspect_results(aspect_results)
      {
        aspects_checked: aspect_results.keys,
        compliant: aspect_results.values.none? { |r| r[:violations]&.any? },
        results: aspect_results,
        summary: "Checked #{aspect_results.keys.join(', ')} aspects"
      }
    end
    
    def handle_error(error)
      Rails.logger.error "Compliance check error: #{error.message}"
      Rails.logger.error error.backtrace.join("\n")
      
      {
        compliant: false,
        error: error.message,
        error_type: error.class.name,
        violations: [],
        suggestions: [],
        score: 0.0,
        summary: "Compliance check failed due to an error"
      }
    end
  end
end