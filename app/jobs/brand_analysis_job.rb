class BrandAnalysisJob < ApplicationJob
  queue_as :low_priority
  
  retry_on StandardError, wait: :exponentially_longer, attempts: 3

  def perform(analysis_id)
    analysis = BrandAnalysis.find(analysis_id)
    brand = analysis.brand
    
    # Initialize service with options from analysis metadata
    options = {
      llm_provider: analysis.analysis_data['llm_provider'],
      temperature: analysis.analysis_data['temperature'] || 0.7
    }
    
    service = Branding::AnalysisService.new(brand, nil, options)
    
    # Perform the actual analysis
    if service.perform_analysis(analysis)
      Rails.logger.info "Successfully analyzed brand #{brand.id} - Analysis #{analysis.id}"
      
      # Notify user or trigger follow-up actions
      BrandAnalysisNotificationJob.perform_later(brand, analysis.id)
      
      # Trigger content generation suggestions if enabled
      if brand.auto_generate_suggestions?
        ContentSuggestionJob.perform_later(brand, analysis.id)
      end
    else
      Rails.logger.error "Failed to analyze brand #{brand.id} - Analysis #{analysis.id}"
      
      # Notify user of failure
      BrandAnalysisNotificationJob.perform_later(brand, analysis.id, failed: true)
    end
  rescue ActiveRecord::RecordNotFound => e
    Rails.logger.error "Analysis not found: #{analysis_id} - #{e.message}"
  rescue StandardError => e
    Rails.logger.error "Brand analysis error: #{e.message}\n#{e.backtrace.join("\n")}"
    
    # Mark analysis as failed if we can
    if defined?(analysis) && analysis
      analysis.mark_as_failed!("Job error: #{e.message}")
    end
    
    raise # Re-raise for retry logic
  end
end