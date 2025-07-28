class BrandComplianceChannel < ApplicationCable::Channel
  def subscribed
    if brand = find_brand
      # Subscribe to brand-specific compliance updates
      stream_from "brand_compliance_#{brand.id}"
      
      # Subscribe to session-specific updates if session_id provided
      if params[:session_id].present?
        stream_from "compliance_session_#{params[:session_id]}"
      end
      
      # Send initial connection confirmation
      transmit(
        event: "subscription_confirmed",
        brand_id: brand.id,
        session_id: params[:session_id]
      )
    else
      reject
    end
  end

  def unsubscribed
    # Cleanup any ongoing compliance checks for this session
    if params[:session_id].present?
      cancel_session_jobs(params[:session_id])
    end
  end

  # Client can request compliance check
  def check_compliance(data)
    brand = find_brand
    return unless brand && authorized_to_check?(brand)

    content = data["content"]
    content_type = data["content_type"] || "general"
    options = build_check_options(data)

    # Validate input
    if content.blank?
      transmit_error("Content cannot be blank")
      return
    end

    # Start compliance check
    if data["async"] == false
      # Synchronous check for small content
      perform_sync_check(brand, content, content_type, options)
    else
      # Asynchronous check for larger content
      perform_async_check(brand, content, content_type, options)
    end
  end

  # Client can request specific aspect validation
  def validate_aspect(data)
    brand = find_brand
    return unless brand && authorized_to_check?(brand)

    aspect = data["aspect"]&.to_sym
    content = data["content"]
    
    unless %i[tone sentiment readability brand_voice colors typography].include?(aspect)
      transmit_error("Invalid aspect: #{aspect}")
      return
    end

    service = Branding::ComplianceServiceV2.new(brand, content, "general")
    result = service.check_specific_aspects([aspect])
    
    transmit(
      event: "aspect_validated",
      aspect: aspect,
      result: result[aspect]
    )
  rescue StandardError => e
    transmit_error("Validation failed: #{e.message}")
  end

  # Client can request fix preview
  def preview_fix(data)
    brand = find_brand
    return unless brand && authorized_to_check?(brand)

    violation_id = data["violation_id"]
    content = data["content"]
    
    # Find the violation in the current session
    violation = find_session_violation(violation_id)
    unless violation
      transmit_error("Violation not found")
      return
    end

    suggestion_engine = Branding::Compliance::SuggestionEngine.new(brand, [violation])
    fix = suggestion_engine.generate_fix(violation, content)
    
    transmit(
      event: "fix_preview",
      violation_id: violation_id,
      fix: fix
    )
  rescue StandardError => e
    transmit_error("Fix generation failed: #{e.message}")
  end

  # Client can get suggestions for specific violation
  def get_suggestions(data)
    brand = find_brand
    return unless brand && authorized_to_check?(brand)

    violation_ids = Array(data["violation_ids"])
    violations = find_session_violations(violation_ids)
    
    suggestion_engine = Branding::Compliance::SuggestionEngine.new(brand, violations)
    suggestions = suggestion_engine.generate_suggestions
    
    transmit(
      event: "suggestions_generated",
      violation_ids: violation_ids,
      suggestions: suggestions
    )
  rescue StandardError => e
    transmit_error("Suggestion generation failed: #{e.message}")
  end

  private

  def find_brand
    Brand.find_by(id: params[:brand_id])
  end

  def authorized_to_check?(brand)
    # Check if current user has permission to check compliance for this brand
    return true if brand.user_id == current_user&.id
    
    # Check team permissions
    current_user&.has_brand_permission?(brand, :check_compliance)
  end

  def build_check_options(data)
    {
      session_id: params[:session_id],
      user_id: current_user&.id,
      broadcast_events: true,
      compliance_level: data["compliance_level"]&.to_sym || :standard,
      channel: data["channel"],
      audience: data["audience"],
      generate_suggestions: data["generate_suggestions"] != false,
      visual_data: data["visual_data"]
    }
  end

  def perform_sync_check(brand, content, content_type, options)
    transmit(event: "check_started", mode: "sync")
    
    service = Branding::ComplianceServiceV2.new(brand, content, content_type, options)
    results = service.check_compliance
    
    # Store results in session cache
    cache_session_results(results)
    
    transmit(
      event: "check_complete",
      results: sanitize_results(results)
    )
  rescue StandardError => e
    transmit_error("Compliance check failed: #{e.message}")
  end

  def perform_async_check(brand, content, content_type, options)
    transmit(event: "check_started", mode: "async")
    
    job = BrandComplianceJob.perform_later(
      brand.id,
      content,
      content_type,
      options.merge(
        broadcast_events: true,
        session_id: params[:session_id]
      )
    )
    
    transmit(
      event: "job_queued",
      job_id: job.job_id
    )
  rescue StandardError => e
    transmit_error("Failed to queue compliance check: #{e.message}")
  end

  def cache_session_results(results)
    return unless params[:session_id]
    
    Rails.cache.write(
      "compliance_session:#{params[:session_id]}:results",
      results,
      expires_in: 1.hour
    )
  end

  def find_session_violation(violation_id)
    return unless params[:session_id]
    
    results = Rails.cache.read("compliance_session:#{params[:session_id]}:results")
    results&.dig(:violations)&.find { |v| v[:id] == violation_id }
  end

  def find_session_violations(violation_ids)
    return [] unless params[:session_id]
    
    results = Rails.cache.read("compliance_session:#{params[:session_id]}:results")
    violations = results&.dig(:violations) || []
    violations.select { |v| violation_ids.include?(v[:id]) }
  end

  def cancel_session_jobs(session_id)
    # Implementation would depend on job tracking system
    # This is a placeholder for canceling any ongoing jobs
  end

  def transmit_error(message)
    transmit(
      event: "error",
      message: message,
      timestamp: Time.current.iso8601
    )
  end

  def sanitize_results(results)
    # Remove any sensitive or unnecessary data before transmitting
    results.slice(
      :compliant,
      :score,
      :summary,
      :violations,
      :suggestions,
      :metadata
    ).deep_transform_values do |value|
      case value
      when ActiveRecord::Base
        value.id
      when Time, DateTime
        value.iso8601
      else
        value
      end
    end
  end
end