module LlmIntegration
  class BrandSystemIntegration
    include ActiveModel::Model

    def initialize
      @brand_analysis_service = BrandAnalysisService.new
      @real_time_compliance_service = RealTimeBrandComplianceService.new
    end

    def get_brand_analysis(brand_id)
      brand = Brand.find(brand_id)

      # Get analysis from existing brand analysis service
      analysis_result = @brand_analysis_service.analyze_brand_voice(brand)

      {
        voice_analysis: format_voice_analysis(analysis_result),
        compliance_rules: extract_compliance_rules(brand),
        brand_metrics: extract_brand_metrics(brand),
        integration_status: :connected,
        last_analysis_date: analysis_result[:analyzed_at] || Time.current
      }
    rescue => e
      Rails.logger.error "Failed to integrate with brand analysis service: #{e.message}"
      {
        voice_analysis: {},
        compliance_rules: [],
        brand_metrics: {},
        integration_status: :failed,
        error: e.message
      }
    end

    def check_with_existing_system(content, brand)
      # Use existing compliance system to check content
      result = @real_time_compliance_service.check_compliance(
        content: content,
        brand: brand
      )

      # Convert to our expected format
      ComplianceResult.new(
        overall_score: result.score || 0.5,
        detailed_feedback: result.feedback || "No detailed feedback available",
        voice_compliance: result.voice_score || result.score || 0.5,
        tone_compliance: result.tone_score || result.score || 0.5,
        messaging_compliance: result.messaging_score || result.score || 0.5,
        violations: format_violations(result.violations || []),
        suggestions: result.suggestions || [],
        confidence_score: result.confidence || 0.8
      )
    rescue => e
      Rails.logger.error "Failed to check with existing compliance system: #{e.message}"

      # Return fallback result
      ComplianceResult.new(
        overall_score: 0.5,
        detailed_feedback: "Could not connect to existing compliance system",
        voice_compliance: 0.5,
        tone_compliance: 0.5,
        messaging_compliance: 0.5,
        violations: [],
        suggestions: [ "Manual review recommended due to system integration error" ],
        confidence_score: 0.3
      )
    end

    def sync_brand_voice_profile(brand)
      # Sync voice profile with existing brand analysis
      begin
        analysis = @brand_analysis_service.analyze_brand_voice(brand)

        # Find or create voice profile
        voice_profile = brand.brand_voice_profiles.first || LlmIntegration::BrandVoiceProfile.new(brand: brand)

        # Extract characteristics from existing analysis
        voice_characteristics = extract_voice_characteristics_from_analysis(analysis)

        voice_profile.update!(
          voice_characteristics: voice_characteristics,
          extracted_from_sources: [ "brand_analysis_service" ],
          confidence_score: calculate_sync_confidence(analysis),
          last_updated: Time.current
        )

        {
          success: true,
          voice_profile: voice_profile,
          sync_timestamp: Time.current
        }
      rescue => e
        Rails.logger.error "Failed to sync brand voice profile: #{e.message}"
        {
          success: false,
          error: e.message
        }
      end
    end

    def get_brand_guidelines_from_existing_system(brand)
      # Extract guidelines from existing brand analysis
      guidelines = []

      # Get from brand guidelines model
      brand.brand_guidelines.active.each do |guideline|
        guidelines << {
          category: guideline.category,
          content: guideline.content,
          priority: guideline.priority,
          source: "brand_guidelines_model"
        }
      end

      # Get from brand analysis if available
      if brand.latest_analysis
        analysis = brand.latest_analysis

        if analysis.voice_attributes.present?
          guidelines << {
            category: "voice",
            content: analysis.voice_attributes.to_s,
            priority: 1,
            source: "brand_analysis"
          }
        end
      end

      # Get from messaging framework
      if brand.messaging_framework
        framework = brand.messaging_framework

        if framework.unique_value_proposition.present?
          guidelines << {
            category: "messaging",
            content: "Unique Value Proposition: #{framework.unique_value_proposition}",
            priority: 1,
            source: "messaging_framework"
          }
        end
      end

      guidelines
    end

    def export_to_existing_system(generated_content)
      # Export generated content back to existing systems for tracking
      begin
        # This would integrate with existing content management systems
        # For now, we'll create compliance results in the existing system

        compliance_result = ComplianceResult.create!(
          brand: generated_content.brand,
          content_type: "llm_generated",
          compliance_score: generated_content.brand_compliance_score,
          voice_score: generated_content.brand_compliance_score,
          tone_score: generated_content.quality_score,
          details: {
            content_preview: generated_content.content[0..100],
            provider_used: generated_content.provider_used,
            generation_time: generated_content.generation_time,
            llm_integration_id: generated_content.id
          }
        )

        {
          success: true,
          compliance_result_id: compliance_result.id,
          exported_at: Time.current
        }
      rescue => e
        Rails.logger.error "Failed to export to existing system: #{e.message}"
        {
          success: false,
          error: e.message
        }
      end
    end

    private

    def format_voice_analysis(analysis_result)
      return {} unless analysis_result

      {
        voice_traits: analysis_result[:voice_traits] || [],
        tone_descriptors: analysis_result[:tone_descriptors] || [],
        communication_style: analysis_result[:communication_style] || "professional",
        confidence_score: analysis_result[:confidence] || 0.5,
        key_findings: analysis_result[:key_findings] || [],
        analyzed_at: analysis_result[:analyzed_at] || Time.current
      }
    end

    def extract_compliance_rules(brand)
      rules = []

      # Extract rules from brand guidelines
      brand.brand_guidelines.active.each do |guideline|
        case guideline.category
        when "voice"
          rules << {
            type: "voice_requirement",
            description: guideline.content,
            priority: guideline.priority || 1
          }
        when "tone"
          rules << {
            type: "tone_requirement",
            description: guideline.content,
            priority: guideline.priority || 1
          }
        when "restrictions"
          rules << {
            type: "content_restriction",
            description: guideline.content,
            priority: guideline.priority || 2
          }
        end
      end

      rules
    end

    def extract_brand_metrics(brand)
      metrics = {}

      # Get basic brand information
      metrics[:brand_age] = brand.created_at.present? ? ((Time.current - brand.created_at) / 1.year).round(1) : 0
      metrics[:guidelines_count] = brand.brand_guidelines.active.count
      metrics[:has_messaging_framework] = brand.messaging_framework.present?
      metrics[:has_voice_analysis] = brand.latest_analysis.present?

      # Get compliance history if available
      recent_compliance = brand.compliance_results.limit(10).average(:compliance_score)
      metrics[:avg_compliance_score] = recent_compliance || 0.0

      metrics
    end

    def format_violations(violations)
      violations.map do |violation|
        {
          type: violation[:type] || "general",
          severity: violation[:severity] || "medium",
          description: violation[:description] || violation.to_s,
          suggestion: violation[:suggestion]
        }
      end
    end

    def extract_voice_characteristics_from_analysis(analysis)
      characteristics = {}

      # Map from existing analysis format to our voice profile format
      characteristics["primary_traits"] = analysis[:voice_traits] || [ "professional" ]
      characteristics["tone_descriptors"] = analysis[:tone_descriptors] || [ "confident" ]
      characteristics["communication_style"] = analysis[:communication_style] || "professional"
      characteristics["brand_personality"] = analysis[:brand_personality] || "expert"

      # Add language preferences if available
      if analysis[:language_analysis].present?
        characteristics["language_preferences"] = {
          "complexity_level" => analysis[:language_analysis][:complexity] || "moderate",
          "vocabulary_style" => analysis[:language_analysis][:vocabulary] || "professional"
        }
      end

      characteristics
    end

    def calculate_sync_confidence(analysis)
      # Calculate confidence based on the completeness of the analysis
      confidence = 0.5 # Base confidence

      confidence += 0.2 if analysis[:voice_traits]&.any?
      confidence += 0.1 if analysis[:tone_descriptors]&.any?
      confidence += 0.1 if analysis[:communication_style].present?
      confidence += 0.1 if analysis[:confidence] && analysis[:confidence] > 0.7

      [ confidence, 1.0 ].min
    end

    # Simple ComplianceResult class for integration
    class ComplianceResult
      include ActiveModel::Model

      attr_accessor :overall_score, :detailed_feedback, :voice_compliance,
                    :tone_compliance, :messaging_compliance, :violations,
                    :suggestions, :confidence_score

      def initialize(attributes = {})
        attributes.each do |key, value|
          send("#{key}=", value) if respond_to?("#{key}=")
        end
      end
    end
  end
end
