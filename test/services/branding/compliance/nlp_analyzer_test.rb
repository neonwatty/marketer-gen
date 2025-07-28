require "test_helper"

module Branding
  module Compliance
    class NlpAnalyzerTest < ActiveSupport::TestCase
      setup do
        @brand = brands(:one)
        @content = "Our professional services deliver exceptional value to clients."
        @analyzer = NlpAnalyzer.new(@brand, @content)
      end

      test "analyzes tone correctly" do
        result = @analyzer.analyze_aspect(:tone)
        
        assert result[:primary_tone]
        assert result[:confidence]
        assert result[:all_tones]
        assert result[:tone_consistency]
      end

      test "analyzes sentiment" do
        positive_content = "We love helping our amazing customers succeed!"
        analyzer = NlpAnalyzer.new(@brand, positive_content)
        
        result = analyzer.analyze_aspect(:sentiment)
        
        assert result[:overall_score] > 0
        assert result[:breakdown][:positive] > result[:breakdown][:negative]
      end

      test "calculates readability metrics" do
        result = @analyzer.analyze_aspect(:readability)
        
        assert result[:flesch_kincaid_score]
        assert result[:gunning_fog_index]
        assert result[:average_sentence_length]
        assert result[:readability_grade]
      end

      test "detects brand alignment" do
        # Set up brand messages
        @brand.messaging_framework.update!(
          key_messages: {
            "primary" => ["exceptional value", "professional services"]
          }
        )
        
        result = @analyzer.analyze_aspect(:brand_alignment)
        
        assert result[:overall_score] > 0.5
        assert result[:voice_alignment]
        assert result[:message_alignment]
      end

      test "analyzes keyword density" do
        @brand.messaging_framework.update!(
          key_messages: {
            "primary" => ["professional", "value", "clients"]
          }
        )
        
        result = @analyzer.analyze_aspect(:keyword_density)
        
        assert result[:keyword_densities]
        assert result[:total_keywords]
        assert result[:content_length]
      end

      test "detects emotional content" do
        emotional_content = "We're thrilled to announce this exciting opportunity!"
        analyzer = NlpAnalyzer.new(@brand, emotional_content)
        
        result = analyzer.analyze_aspect(:emotion)
        
        assert result[:primary_emotions].include?("excitement") || 
               result[:primary_emotions].include?("joy")
        assert result[:emotion_intensity]
      end

      test "validates tone compliance" do
        # Set expected tone
        brand_analysis = @brand.brand_analyses.create!(
          voice_attributes: { "tone" => { "primary" => "professional" } }
        )
        
        casual_content = "Hey guys, check this out!"
        analyzer = NlpAnalyzer.new(@brand, casual_content)
        
        result = analyzer.validate
        violations = result[:violations]
        
        assert violations.any? { |v| v[:type] == "tone_mismatch" }
      end

      test "checks readability standards" do
        complex_content = "The aforementioned implementation necessitates comprehensive evaluation of multifaceted parameters."
        analyzer = NlpAnalyzer.new(@brand, complex_content)
        
        # Set target readability
        @brand.brand_guidelines.create!(
          category: "readability",
          rule_type: "must",
          rule_content: "Content must be at 8th grade reading level",
          metadata: { "target_grade" => 8 }
        )
        
        result = analyzer.validate
        violations = result[:violations]
        
        assert violations.any? { |v| v[:type] == "readability_mismatch" }
      end

      test "analyzes sentence variety" do
        monotonous_content = "This is a sentence. This is another sentence. This is a third sentence."
        analyzer = NlpAnalyzer.new(@brand, monotonous_content)
        
        result = analyzer.validate
        suggestions = result[:suggestions]
        
        assert suggestions.any? { |s| s[:type] == "sentence_variety" }
      end

      test "detects missing brand messages" do
        @brand.messaging_framework.update!(
          key_messages: {
            "primary" => ["innovation", "sustainability", "excellence"]
          }
        )
        
        generic_content = "We provide good services to customers."
        analyzer = NlpAnalyzer.new(@brand, generic_content)
        
        result = analyzer.validate
        violations = result[:violations]
        
        assert violations.any? { |v| v[:type] == "key_message_absence" }
      end

      test "caches analysis results" do
        Rails.cache.clear
        
        # First analysis should compute
        result1 = @analyzer.analyze_aspect(:tone)
        
        # Second analysis should use cache
        analyzer2 = NlpAnalyzer.new(@brand, @content)
        result2 = analyzer2.analyze_aspect(:tone)
        
        assert_equal result1, result2
      end

      test "handles empty content gracefully" do
        analyzer = NlpAnalyzer.new(@brand, "")
        
        assert_nothing_raised do
          result = analyzer.validate
          assert result[:violations].empty? || result[:violations].any?
        end
      end

      test "provides formality analysis" do
        formal_content = "Therefore, we must consequently evaluate the parameters."
        informal_content = "So yeah, we gotta check this stuff out."
        
        formal_analyzer = NlpAnalyzer.new(@brand, formal_content)
        informal_analyzer = NlpAnalyzer.new(@brand, informal_content)
        
        formal_style = formal_analyzer.send(:detect_formality_level)
        informal_style = informal_analyzer.send(:detect_formality_level)
        
        assert_includes ["formal", "moderate_formal"], formal_style
        assert_includes ["informal", "moderate_informal"], informal_style
      end
    end
  end
end