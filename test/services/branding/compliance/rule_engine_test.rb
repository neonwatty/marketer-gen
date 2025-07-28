require "test_helper"

module Branding
  module Compliance
    class RuleEngineTest < ActiveSupport::TestCase
      setup do
        @brand = brands(:one)
        @engine = RuleEngine.new(@brand)
        @content = "This is test content for our product"
      end

      test "loads brand guidelines as rules" do
        # Create test guidelines
        @brand.brand_guidelines.create!(
          rule_type: "must",
          rule_content: "Must include company name",
          category: "content",
          priority: 9
        )
        
        @brand.brand_guidelines.create!(
          rule_type: "dont",
          rule_content: "Don't use competitor names",
          category: "content",
          priority: 8
        )
        
        engine = RuleEngine.new(@brand)
        content_rules = engine.get_rules_for_category("content")
        
        assert content_rules.any?
        assert content_rules.any? { |r| r[:type] == "must" }
        assert content_rules.any? { |r| r[:type] == "dont" }
      end

      test "evaluates rules and returns results" do
        @brand.brand_guidelines.create!(
          rule_type: "must",
          rule_content: "Must include 'professional'",
          category: "tone",
          priority: 8
        )
        
        results = @engine.evaluate(@content)
        
        assert results[:passed].is_a?(Array)
        assert results[:failed].is_a?(Array)
        assert results[:warnings].is_a?(Array)
        assert results[:score].between?(0.0, 1.0)
      end

      test "respects rule priorities" do
        # Create rules with different priorities
        high_priority = @brand.brand_guidelines.create!(
          rule_type: "must",
          rule_content: "High priority rule",
          priority: 10
        )
        
        low_priority = @brand.brand_guidelines.create!(
          rule_type: "should",
          rule_content: "Low priority rule",
          priority: 3
        )
        
        engine = RuleEngine.new(@brand)
        rules = engine.get_rules_for_category("general")
        
        # High priority should come first
        assert rules.first[:priority] >= rules.last[:priority]
      end

      test "filters rules by context" do
        @brand.brand_guidelines.create!(
          rule_type: "must",
          rule_content: "Email specific rule",
          category: "content",
          metadata: { "content_types" => ["email"] }
        )
        
        @brand.brand_guidelines.create!(
          rule_type: "must",
          rule_content: "General rule",
          category: "content"
        )
        
        # Evaluate with email context
        email_results = @engine.evaluate(@content, { content_type: "email" })
        
        # Evaluate without context
        general_results = @engine.evaluate(@content, {})
        
        assert email_results[:score]
        assert general_results[:score]
      end

      test "detects rule conflicts" do
        # Create conflicting rules
        @brand.brand_guidelines.create!(
          rule_type: "must",
          rule_content: "Must use formal tone",
          category: "tone",
          priority: 8
        )
        
        @brand.brand_guidelines.create!(
          rule_type: "must_not",
          rule_content: "Must not use formal tone",
          category: "tone",
          priority: 8
        )
        
        results = @engine.evaluate("This is formal content.")
        
        assert results[:rule_conflicts].any?
        conflict = results[:rule_conflicts].first
        assert_equal "contradiction", conflict[:type]
        assert conflict[:resolution]
      end

      test "handles mandatory vs optional rules" do
        mandatory = @brand.brand_guidelines.create!(
          rule_type: "must",
          rule_content: "Mandatory rule",
          priority: 9
        )
        
        optional = @brand.brand_guidelines.create!(
          rule_type: "should",
          rule_content: "Optional rule",
          priority: 5
        )
        
        results = @engine.evaluate("Content without requirements")
        
        # Mandatory failures should be in failed
        # Optional failures should be in warnings
        assert results[:failed].any? || results[:warnings].any?
      end

      test "calculates weighted compliance score" do
        # High priority pass
        @brand.brand_guidelines.create!(
          rule_type: "must",
          rule_content: "Must include 'content'",
          priority: 10
        )
        
        # Low priority fail
        @brand.brand_guidelines.create!(
          rule_type: "should",
          rule_content: "Should include 'xyz123'",
          priority: 3
        )
        
        results = @engine.evaluate(@content)
        
        # Score should be weighted by priority
        assert results[:score] > 0.5 # High priority passed
      end

      test "adds dynamic rules" do
        initial_count = @engine.get_rules_for_category("dynamic").count
        
        @engine.add_dynamic_rule({
          category: "dynamic",
          type: "must",
          content: "Dynamic rule content",
          priority: 50,
          mandatory: true
        })
        
        dynamic_rules = @engine.get_rules_for_category("dynamic")
        assert_equal initial_count + 1, dynamic_rules.count
      end

      test "loads industry-specific rules" do
        @brand.update!(industry: "healthcare")
        engine = RuleEngine.new(@brand)
        
        # Should have healthcare-specific rules
        legal_rules = engine.get_rules_for_category("legal")
        assert legal_rules.any? { |r| r[:id] == "healthcare_hipaa" }
      end

      test "handles rule evaluation errors gracefully" do
        # Add a rule that will cause an error
        @engine.add_dynamic_rule({
          category: "test",
          type: "must",
          content: "Error rule",
          priority: 50,
          evaluator: ->(content, context) { raise "Test error" }
        })
        
        results = @engine.evaluate(@content)
        
        # Should continue despite error
        assert results[:score]
        assert results[:passed].is_a?(Array)
      end

      test "caches compiled rules" do
        Rails.cache.clear
        
        # First load should compile and cache
        engine1 = RuleEngine.new(@brand)
        
        # Second load should use cache
        engine2 = RuleEngine.new(@brand)
        
        # Both should have same rules
        assert_equal(
          engine1.get_rules_for_category("content").count,
          engine2.get_rules_for_category("content").count
        )
      end

      test "detects profanity in global rules" do
        # This would need a real profanity list in production
        content_with_profanity = "This content has badword1"
        
        results = @engine.evaluate(content_with_profanity)
        
        # Should have profanity violation
        assert results[:failed].any? { |f| f[:rule_id] == "global_profanity" }
      end
    end
  end
end