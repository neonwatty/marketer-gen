module Api
  module V1
    class BrandComplianceController < ApplicationController
      before_action :authenticate_user!
      before_action :set_brand
      before_action :authorize_brand_access

      # POST /api/v1/brands/:brand_id/compliance/check
      def check
        content = compliance_params[:content]
        content_type = compliance_params[:content_type] || "general"
        
        if content.blank?
          render json: { error: "Content is required" }, status: :unprocessable_entity
          return
        end

        options = build_compliance_options
        
        # Use async processing for large content
        if content.length > 10_000 && params[:sync] != "true"
          job = BrandComplianceJob.perform_later(
            @brand.id,
            content,
            content_type,
            options.merge(
              user_id: current_user.id,
              notify: params[:notify] == "true",
              store_results: true
            )
          )
          
          render json: {
            status: "processing",
            job_id: job.job_id,
            message: "Compliance check queued for processing"
          }, status: :accepted
        else
          service = Branding::ComplianceServiceV2.new(@brand, content, content_type, options)
          results = service.check_compliance
          
          # Store results if requested
          store_results(results) if params[:store_results] == "true"
          
          render json: format_compliance_results(results)
        end
      rescue StandardError => e
        render json: { error: e.message }, status: :internal_server_error
      end

      # POST /api/v1/brands/:brand_id/compliance/validate_aspect
      def validate_aspect
        aspect = params[:aspect]&.to_sym
        content = compliance_params[:content]
        
        unless %i[tone sentiment readability brand_voice colors typography logo composition].include?(aspect)
          render json: { error: "Invalid aspect: #{aspect}" }, status: :unprocessable_entity
          return
        end

        service = Branding::ComplianceServiceV2.new(@brand, content, "general", build_compliance_options)
        results = service.check_specific_aspects([aspect])
        
        render json: {
          aspect: aspect,
          results: results[aspect],
          timestamp: Time.current
        }
      rescue StandardError => e
        render json: { error: e.message }, status: :internal_server_error
      end

      # POST /api/v1/brands/:brand_id/compliance/preview_fix
      def preview_fix
        violation = params[:violation]
        content = compliance_params[:content]
        
        unless violation.present?
          render json: { error: "Violation data is required" }, status: :unprocessable_entity
          return
        end

        suggestion_engine = Branding::Compliance::SuggestionEngine.new(@brand, [violation])
        fix = suggestion_engine.generate_fix(violation, content)
        
        render json: {
          violation_id: violation[:id],
          fix: fix,
          alternatives: suggestion_engine.suggest_alternatives(
            content[0..100],
            { content_type: params[:content_type], audience: params[:audience] }
          )
        }
      rescue StandardError => e
        render json: { error: e.message }, status: :internal_server_error
      end

      # GET /api/v1/brands/:brand_id/compliance/history
      def history
        results = @brand.compliance_results
                       .by_content_type(params[:content_type])
                       .recent
                       .page(params[:page])
                       .per(params[:per_page] || 20)
        
        render json: {
          results: results.map { |r| format_history_result(r) },
          pagination: {
            current_page: results.current_page,
            total_pages: results.total_pages,
            total_count: results.total_count
          },
          statistics: {
            average_score: results.average_score,
            compliance_rate: results.compliance_rate,
            common_violations: @brand.compliance_results.common_violations(5)
          }
        }
      end

      # POST /api/v1/brands/:brand_id/compliance/validate_and_fix
      def validate_and_fix
        content = compliance_params[:content]
        content_type = compliance_params[:content_type] || "general"
        
        service = Branding::ComplianceServiceV2.new(@brand, content, content_type, build_compliance_options)
        results = service.validate_and_fix
        
        render json: {
          original_compliant: results[:original_results][:compliant],
          original_score: results[:original_results][:score],
          fixes_applied: results[:fixes_applied],
          final_compliant: results[:final_results][:compliant],
          final_score: results[:final_results][:score],
          fixed_content: results[:fixed_content]
        }
      rescue StandardError => e
        render json: { error: e.message }, status: :internal_server_error
      end

      private

      def set_brand
        @brand = Brand.find(params[:brand_id])
      rescue ActiveRecord::RecordNotFound
        render json: { error: "Brand not found" }, status: :not_found
      end

      def authorize_brand_access
        unless @brand.user_id == current_user.id || current_user.has_brand_permission?(@brand, :check_compliance)
          render json: { error: "Unauthorized" }, status: :forbidden
        end
      end

      def compliance_params
        params.permit(:content, :content_type, :visual_data => {})
      end

      def build_compliance_options
        {
          compliance_level: (params[:compliance_level] || "standard").to_sym,
          generate_suggestions: params[:suggestions] != "false",
          channel: params[:channel],
          audience: params[:audience],
          cache_results: params[:cache] != "false",
          visual_data: params[:visual_data]
        }
      end

      def store_results(results)
        ComplianceResult.create!(
          brand: @brand,
          content_type: params[:content_type] || "general",
          content_hash: Digest::SHA256.hexdigest(compliance_params[:content]),
          compliant: results[:compliant],
          score: results[:score],
          violations_count: results[:violations]&.count || 0,
          violations_data: results[:violations] || [],
          suggestions_data: results[:suggestions] || [],
          analysis_data: results[:analysis] || {},
          metadata: results[:metadata] || {}
        )
      rescue StandardError => e
        Rails.logger.error "Failed to store compliance results: #{e.message}"
      end

      def format_compliance_results(results)
        {
          compliant: results[:compliant],
          score: results[:score],
          summary: results[:summary],
          violations: format_violations(results[:violations]),
          suggestions: format_suggestions(results[:suggestions]),
          metadata: {
            processing_time: results[:metadata][:processing_time],
            validators_used: results[:metadata][:validators_used],
            compliance_level: results[:metadata][:compliance_level],
            timestamp: Time.current
          }
        }
      end

      def format_violations(violations)
        return [] unless violations
        
        violations.map do |violation|
          {
            id: violation[:id],
            type: violation[:type],
            severity: violation[:severity],
            message: violation[:message],
            validator: violation[:validator_type],
            position: violation[:position],
            details: violation[:details]
          }
        end
      end

      def format_suggestions(suggestions)
        return [] unless suggestions
        
        suggestions.map do |suggestion|
          {
            type: suggestion[:type],
            priority: suggestion[:priority],
            title: suggestion[:title],
            description: suggestion[:description],
            actions: suggestion[:specific_actions],
            effort: suggestion[:effort_level],
            estimated_time: suggestion[:estimated_time]
          }
        end
      end

      def format_history_result(result)
        {
          id: result.id,
          content_type: result.content_type,
          compliant: result.compliant,
          score: result.score,
          violations_count: result.violations_count,
          high_severity_count: result.high_severity_violations.count,
          created_at: result.created_at,
          processing_time: result.processing_time_seconds
        }
      end
    end
  end
end
