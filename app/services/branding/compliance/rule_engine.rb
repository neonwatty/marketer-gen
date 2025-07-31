module Branding
  module Compliance
    class RuleEngine
      attr_reader :brand, :rules_cache

      RULE_PRIORITIES = {
        mandatory: 100,
        critical: 90,
        high: 70,
        medium: 50,
        low: 30,
        optional: 10
      }.freeze

      def initialize(brand)
        @brand = brand
        @rules_cache = {}
        load_rules
      end

      def evaluate(content, context = {})
        results = {
          passed: [],
          failed: [],
          warnings: [],
          score: 0.0
        }

        # Get applicable rules based on context
        applicable_rules = filter_rules_by_context(context)
        
        # Evaluate rules in priority order
        applicable_rules.each do |rule|
          result = evaluate_rule(rule, content, context)
          
          case result[:status]
          when :passed
            results[:passed] << result
          when :failed
            results[:failed] << result
          when :warning
            results[:warnings] << result
          end
        end

        # Calculate compliance score
        results[:score] = calculate_score(results, applicable_rules)
        results[:rule_conflicts] = detect_conflicts(results[:failed])
        
        results
      end

      def get_rules_for_category(category)
        @rules_cache[category] || []
      end

      def add_dynamic_rule(rule_definition)
        rule = build_rule(rule_definition)
        category = rule[:category] || "dynamic"
        
        @rules_cache[category] ||= []
        @rules_cache[category] << rule
        
        # Sort by priority
        @rules_cache[category].sort_by! { |r| -r[:priority] }
      end

      def build_rule(rule_definition)
        {
          id: rule_definition[:id] || "dynamic_#{SecureRandom.hex(8)}",
          source: "dynamic",
          category: rule_definition[:category] || "general",
          type: rule_definition[:type],
          content: rule_definition[:content],
          priority: rule_definition[:priority] || 50,
          mandatory: rule_definition[:mandatory] || false,
          metadata: rule_definition[:metadata] || {},
          evaluator: rule_definition[:evaluator] || ->(content, _context) { true }
        }
      end

      private

      def load_rules
        # Try to load from cache first
        cached_rules = Rails.cache.read("compiled_rules:#{brand.id}")
        
        if cached_rules.present?
          # Restore cached rules and regenerate evaluators
          @rules_cache = cached_rules
          restore_evaluators
        else
          # Load fresh rules
          load_brand_guidelines
          load_global_rules
          load_industry_rules if brand.industry.present?
          cache_compiled_rules
        end
      end

      def load_brand_guidelines
        brand.brand_guidelines.active.each do |guideline|
          rule = {
            id: "brand_#{guideline.id}",
            source: "brand_guideline",
            category: guideline.category,
            type: guideline.rule_type,
            content: guideline.rule_content,
            priority: calculate_priority(guideline),
            mandatory: guideline.mandatory?,
            metadata: guideline.metadata || {},
            evaluator: build_evaluator(guideline)
          }
          
          category = guideline.category || "general"
          @rules_cache[category] ||= []
          @rules_cache[category] << rule
        end
      end

      def load_global_rules
        # Load system-wide compliance rules
        global_rules = [
          {
            id: "global_profanity",
            category: "content",
            type: "must_not",
            content: "Content must not contain profanity",
            priority: RULE_PRIORITIES[:critical],
            mandatory: true,
            evaluator: ->(content, _context) { !contains_profanity?(content) }
          },
          {
            id: "global_legal",
            category: "legal",
            type: "must",
            content: "Content must include required legal disclaimers",
            priority: RULE_PRIORITIES[:high],
            mandatory: true,
            evaluator: ->(content, context) { check_legal_requirements(content, context) }
          },
          {
            id: "global_accessibility",
            category: "accessibility",
            type: "should",
            content: "Content should follow accessibility guidelines",
            priority: RULE_PRIORITIES[:medium],
            mandatory: false,
            evaluator: ->(content, context) { check_accessibility(content, context) }
          }
        ]
        
        global_rules.each do |rule|
          category = rule[:category]
          @rules_cache[category] ||= []
          @rules_cache[category] << rule
        end
      end

      def load_industry_rules
        # Load industry-specific compliance rules without caching the Proc objects
        industry_rules = case brand.industry
        when "healthcare"
          load_healthcare_rules
        when "finance"
          load_finance_rules
        when "technology"
          load_technology_rules
        else
          []
        end
        
        industry_rules.each do |rule|
          category = rule[:category]
          @rules_cache[category] ||= []
          @rules_cache[category] << rule
        end
      end

      def build_evaluator(guideline)
        case guideline.rule_type
        when "must", "do"
          ->(content, _context) { content_matches_positive_rule?(content, guideline) }
        when "must_not", "dont", "avoid"
          ->(content, _context) { !content_matches_negative_rule?(content, guideline) }
        when "should", "prefer"
          ->(content, _context) { content_follows_suggestion?(content, guideline) }
        else
          ->(content, _context) { true }
        end
      end

      def evaluate_rule(rule, content, context)
        begin
          passed = rule[:evaluator].call(content, context)
          
          {
            rule_id: rule[:id],
            status: determine_status(passed, rule),
            message: build_message(passed, rule),
            severity: determine_severity(rule),
            details: {
              rule_type: rule[:type],
              category: rule[:category],
              mandatory: rule[:mandatory]
            }
          }
        rescue StandardError => e
          Rails.logger.error "Rule evaluation error: #{e.message}"
          {
            rule_id: rule[:id],
            status: :error,
            message: "Error evaluating rule: #{rule[:content]}",
            severity: "low",
            error: e.message
          }
        end
      end

      def determine_status(passed, rule)
        if passed
          :passed
        elsif rule[:mandatory]
          :failed
        else
          :warning
        end
      end

      def determine_severity(rule)
        if rule[:mandatory]
          priority_to_severity(rule[:priority])
        else
          "low"
        end
      end

      def priority_to_severity(priority)
        case priority
        when 90..100 then "critical"
        when 70..89 then "high"
        when 50..69 then "medium"
        else "low"
        end
      end

      def calculate_priority(guideline)
        base_priority = guideline.priority * 10
        
        # Boost priority for mandatory rules
        base_priority += 20 if guideline.mandatory?
        
        # Cap at maximum
        [base_priority, 100].min
      end

      def filter_rules_by_context(context)
        all_rules = @rules_cache.values.flatten
        
        # Filter based on content type
        if context[:content_type].present?
          all_rules = all_rules.select do |rule|
            rule[:metadata].blank? ||
            rule[:metadata][:content_types].blank? ||
            rule[:metadata][:content_types].include?(context[:content_type])
          end
        end
        
        # Filter based on channel
        if context[:channel].present?
          all_rules = all_rules.select do |rule|
            rule[:metadata].blank? ||
            rule[:metadata][:channels].blank? ||
            rule[:metadata][:channels].include?(context[:channel])
          end
        end
        
        # Sort by priority
        all_rules.sort_by { |rule| -rule[:priority] }
      end

      def calculate_score(results, total_rules)
        return 1.0 if total_rules.empty?
        
        # Weight rules by priority
        total_weight = 0.0
        passed_weight = 0.0
        
        results[:passed].each do |result|
          rule = find_rule(result[:rule_id])
          weight = rule[:priority] / 100.0
          total_weight += weight
          passed_weight += weight
        end
        
        results[:failed].each do |result|
          rule = find_rule(result[:rule_id])
          weight = rule[:priority] / 100.0
          total_weight += weight
        end
        
        results[:warnings].each do |result|
          rule = find_rule(result[:rule_id])
          weight = rule[:priority] / 100.0
          total_weight += weight
          passed_weight += weight * 0.5 # Partial credit for warnings
        end
        
        return 0.0 if total_weight == 0
        
        (passed_weight / total_weight).round(3)
      end

      def detect_conflicts(failed_results)
        conflicts = []
        
        failed_results.each_with_index do |result1, i|
          failed_results[(i+1)..-1].each do |result2|
            if rules_conflict?(result1, result2)
              conflicts << {
                rule1: result1[:rule_id],
                rule2: result2[:rule_id],
                type: "contradiction",
                resolution: suggest_resolution(result1, result2)
              }
            end
          end
        end
        
        conflicts
      end

      def rules_conflict?(result1, result2)
        rule1 = find_rule(result1[:rule_id])
        rule2 = find_rule(result2[:rule_id])
        
        return false unless rule1 && rule2
        
        # Check for contradictory rules
        (rule1[:type] == "must" && rule2[:type] == "dont") ||
        (rule1[:type] == "dont" && rule2[:type] == "must") ||
        (rule1[:type] == "must" && rule2[:type] == "must_not") ||
        (rule1[:type] == "must_not" && rule2[:type] == "must")
      end

      def suggest_resolution(result1, result2)
        rule1 = find_rule(result1[:rule_id])
        rule2 = find_rule(result2[:rule_id])
        
        # Higher priority rule takes precedence
        if rule1[:priority] > rule2[:priority]
          "Follow rule #{rule1[:id]} (higher priority)"
        elsif rule2[:priority] > rule1[:priority]
          "Follow rule #{rule2[:id]} (higher priority)"
        else
          "Review both rules and update priorities"
        end
      end

      def find_rule(rule_id)
        @rules_cache.values.flatten.find { |rule| rule[:id] == rule_id }
      end

      def cache_compiled_rules
        # Create a serializable version of rules cache without Proc evaluators
        serializable_cache = {}
        @rules_cache.each do |category, rules|
          serializable_cache[category] = rules.map do |rule|
            rule.except(:evaluator) # Remove non-serializable Proc evaluators
          end
        end
        
        Rails.cache.write(
          "compiled_rules:#{brand.id}",
          serializable_cache,
          expires_in: 1.hour
        )
      end

      def restore_evaluators
        @rules_cache.each do |category, rules|
          rules.each do |rule|
            next if rule[:evaluator].present? # Skip if evaluator already exists
            
            # Regenerate evaluator based on rule type and source
            rule[:evaluator] = case rule[:source]
            when "brand_guideline"
              build_evaluator_for_cached_rule(rule)
            else
              build_global_evaluator(rule)
            end
          end
        end
      end

      def build_evaluator_for_cached_rule(rule)
        case rule[:type]
        when "must", "do"
          ->(content, _context) { content_matches_positive_rule_cached?(content, rule) }
        when "must_not", "dont", "avoid"
          ->(content, _context) { !content_matches_negative_rule_cached?(content, rule) }
        when "should", "prefer"
          ->(content, _context) { content_follows_suggestion_cached?(content, rule) }
        else
          ->(content, _context) { true }
        end
      end

      def build_global_evaluator(rule)
        case rule[:id]
        when "global_profanity"
          ->(content, _context) { !contains_profanity?(content) }
        when "global_legal"
          ->(content, context) { check_legal_requirements(content, context) }
        when "global_accessibility"
          ->(content, context) { check_accessibility(content, context) }
        when "healthcare_hipaa"
          ->(content, _context) { !contains_phi?(content) }
        when "finance_disclaimer"
          ->(content, context) { contains_required_disclaimer?(content, context) }
        when "tech_accuracy"
          ->(content, _context) { validate_technical_accuracy(content) }
        else
          ->(content, _context) { true }
        end
      end

      # Helper methods for rule evaluation
      def content_matches_positive_rule?(content, guideline)
        keywords = extract_keywords(guideline.rule_content)
        content_lower = content.downcase
        
        keywords.any? { |keyword| content_lower.include?(keyword.downcase) }
      end

      def content_matches_negative_rule?(content, guideline)
        keywords = extract_keywords(guideline.rule_content)
        content_lower = content.downcase
        
        keywords.any? { |keyword| content_lower.include?(keyword.downcase) }
      end

      def content_follows_suggestion?(content, guideline)
        # More lenient check for suggestions
        keywords = extract_keywords(guideline.rule_content)
        content_lower = content.downcase
        
        matching_keywords = keywords.count { |keyword| content_lower.include?(keyword.downcase) }
        matching_keywords >= (keywords.length * 0.3) # 30% match threshold
      end

      def extract_keywords(text)
        stop_words = %w[the a an and or but in on at to for of with as by that which who whom whose when where why how]
        
        text.downcase
            .split(/\W+/)
            .reject { |word| stop_words.include?(word) || word.length < 3 }
            .uniq
      end

      def contains_profanity?(content)
        # Implement profanity detection
        profanity_list = Rails.cache.fetch("profanity_list", expires_in: 1.day) do
          # Load from database or external service
          %w[badword1 badword2] # Placeholder
        end
        
        content_lower = content.downcase
        profanity_list.any? { |word| content_lower.include?(word) }
      end

      def check_legal_requirements(content, context)
        # Check for required legal disclaimers based on context
        true # Placeholder
      end

      def check_accessibility(content, context)
        # Check accessibility guidelines
        true # Placeholder
      end

      def build_message(passed, rule)
        if passed
          "Complies with: #{rule[:content]}"
        else
          "Violates: #{rule[:content]}"
        end
      end

      # Industry-specific rule loaders
      def load_healthcare_rules
        [
          {
            id: "healthcare_hipaa",
            category: "legal",
            type: "must_not",
            content: "Must not disclose protected health information",
            priority: RULE_PRIORITIES[:critical],
            mandatory: true,
            evaluator: ->(content, _context) { !contains_phi?(content) }
          }
        ]
      end

      def load_finance_rules
        [
          {
            id: "finance_disclaimer",
            category: "legal",
            type: "must",
            content: "Must include investment risk disclaimer",
            priority: RULE_PRIORITIES[:critical],
            mandatory: true,
            evaluator: ->(content, context) { contains_required_disclaimer?(content, context) }
          }
        ]
      end

      def load_technology_rules
        [
          {
            id: "tech_accuracy",
            category: "content",
            type: "must",
            content: "Technical specifications must be accurate",
            priority: RULE_PRIORITIES[:high],
            mandatory: true,
            evaluator: ->(content, _context) { validate_technical_accuracy(content) }
          }
        ]
      end

      def contains_phi?(content)
        # Check for protected health information patterns
        false # Placeholder
      end

      def contains_required_disclaimer?(content, context)
        # Check for required disclaimers
        true # Placeholder
      end

      def validate_technical_accuracy(content)
        # Validate technical claims
        true # Placeholder
      end

      # Cached rule evaluation methods (work with rule hashes instead of guideline objects)
      def content_matches_positive_rule_cached?(content, rule)
        keywords = extract_keywords(rule[:content])
        content_lower = content.downcase
        
        keywords.any? { |keyword| content_lower.include?(keyword.downcase) }
      end

      def content_matches_negative_rule_cached?(content, rule)
        keywords = extract_keywords(rule[:content])
        content_lower = content.downcase
        
        keywords.any? { |keyword| content_lower.include?(keyword.downcase) }
      end

      def content_follows_suggestion_cached?(content, rule)
        # More lenient check for suggestions
        keywords = extract_keywords(rule[:content])
        content_lower = content.downcase
        
        matching_keywords = keywords.count { |keyword| content_lower.include?(keyword.downcase) }
        matching_keywords >= (keywords.length * 0.3) # 30% match threshold
      end
    end
  end
end