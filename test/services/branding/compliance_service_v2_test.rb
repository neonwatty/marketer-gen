require "test_helper"

module Branding
  class ComplianceServiceV2Test < ActiveSupport::TestCase
    setup do
      @user = users(:one)
      @brand = brands(:one)
      @content = "This is test content for our amazing product!"
      @service = ComplianceServiceV2.new(@brand, @content)
    end

    test "initializes with correct defaults" do
      assert_equal @brand, @service.brand
      assert_equal @content, @service.content
      assert_equal "general", @service.content_type
    end

    test "performs basic compliance check" do
      results = @service.check_compliance
      
      assert results.key?(:compliant)
      assert results.key?(:score)
      assert results.key?(:summary)
      assert results.key?(:violations)
      assert results.key?(:suggestions)
      assert results.key?(:metadata)
    end

    test "validates specific aspects" do
      aspects = [:tone, :readability]
      results = @service.check_specific_aspects(aspects)
      
      assert_equal aspects, results[:aspects_checked]
      aspects.each do |aspect|
        assert results[:results].key?(aspect)
      end
    end

    test "handles empty content" do
      service = ComplianceServiceV2.new(@brand, "")
      results = service.check_compliance
      
      assert_not results[:compliant]
      assert_equal 0.0, results[:score]
    end

    test "caches results when enabled" do
      Rails.cache.clear
      
      service = ComplianceServiceV2.new(@brand, @content, "general", cache_results: true)
      
      # First call should not use cache
      results1 = service.check_compliance
      assert_equal 0, results1[:metadata][:cached_results_used]
      
      # Second call should use cache
      service2 = ComplianceServiceV2.new(@brand, @content, "general", cache_results: true)
      results2 = service2.check_compliance
      assert results2[:metadata][:cached_results_used] > 0
    end

    test "applies different compliance levels" do
      levels = [:strict, :standard, :flexible, :advisory]
      
      levels.each do |level|
        service = ComplianceServiceV2.new(@brand, @content, "general", compliance_level: level)
        results = service.check_compliance
        assert_equal level, results[:metadata][:compliance_level]
      end
    end

    test "validates and fixes content" do
      # Add a banned word to trigger violation
      @brand.messaging_framework.update!(banned_words: ["amazing"])
      
      service = ComplianceServiceV2.new(@brand, @content)
      results = service.validate_and_fix
      
      assert results[:original_results]
      assert results[:fixes_applied]
      assert results[:final_results]
      assert results[:fixed_content]
    end

    test "handles visual content validation" do
      visual_data = {
        colors: {
          primary: ["#FF0000"],
          secondary: ["#00FF00"]
        },
        typography: {
          fonts: ["Arial"],
          legibility_score: 0.9
        }
      }
      
      service = ComplianceServiceV2.new(
        @brand,
        "Visual content",
        "image",
        { visual_data: visual_data, include_visual: true }
      )
      
      results = service.check_compliance
      assert results[:metadata][:validators_used].include?("Branding::Compliance::VisualValidator")
    end

    test "broadcasts violations when enabled" do
      service = ComplianceServiceV2.new(
        @brand,
        @content,
        "general",
        { real_time_updates: true }
      )
      
      # Mock ActionCable broadcast
      ActionCable.server.stubs(:broadcast).returns(nil)
      
      service.check_compliance
    end

    test "handles errors gracefully" do
      # Force an error by passing invalid options
      service = ComplianceServiceV2.new(@brand, @content, "general", compliance_level: :invalid)
      
      results = service.check_compliance
      assert_not results[:compliant]
      assert results.key?(:error) || results[:score] == 0.0
    end

    test "generates intelligent suggestions" do
      # Add violations to trigger suggestions
      @brand.messaging_framework.update!(banned_words: ["amazing", "product"])
      
      service = ComplianceServiceV2.new(@brand, @content)
      results = service.check_compliance
      
      assert results[:suggestions].any?
      suggestion = results[:suggestions].first
      assert suggestion[:type]
      assert suggestion[:priority]
      assert suggestion[:title]
    end

    test "respects async processing option" do
      large_content = "Large content " * 5000
      
      service = ComplianceServiceV2.new(
        @brand,
        large_content,
        "article",
        { async: true }
      )
      
      # Mock async processing
      assert_nothing_raised do
        service.check_compliance
      end
    end

    test "calculates compliance score correctly" do
      service = ComplianceServiceV2.new(@brand, @content)
      results = service.check_compliance
      
      assert results[:score].between?(0.0, 1.0)
      assert results[:score].is_a?(Float)
    end

    test "detects tone mismatches" do
      # Set brand tone expectation
      brand_analysis = brand_analyses(:one)
      brand_analysis.update!(
        voice_attributes: { "tone" => { "primary" => "formal" } }
      )
      
      casual_content = "Hey! Check out this cool stuff!"
      service = ComplianceServiceV2.new(@brand, casual_content)
      results = service.check_compliance
      
      tone_violations = results[:violations].select { |v| v[:type] == "tone_mismatch" }
      assert tone_violations.any?
    end

    test "validates readability standards" do
      complex_content = "The implementation of our comprehensive solution necessitates " * 10
      
      service = ComplianceServiceV2.new(@brand, complex_content)
      results = service.check_compliance
      
      # Should have readability-related feedback
      assert results[:analysis] || results[:suggestions].any?
    end

    test "handles multiple validators in parallel" do
      service = ComplianceServiceV2.new(
        @brand,
        @content,
        "marketing_copy",
        { async: false }
      )
      
      start_time = Time.current
      results = service.check_compliance
      processing_time = Time.current - start_time
      
      assert processing_time < 5.seconds
      assert results[:metadata][:validators_used].count >= 2
    end

    test "preview fixes for violations" do
      @brand.messaging_framework.update!(banned_words: ["amazing"])
      
      service = ComplianceServiceV2.new(@brand, @content)
      results = service.check_compliance
      
      violations = results[:violations]
      fixes = service.preview_fixes(violations)
      
      assert fixes.any?
      fixes.each do |violation_id, fix|
        assert fix[:fixed_content]
        assert fix[:confidence]
        assert fix[:changes_made]
      end
    end
  end
end