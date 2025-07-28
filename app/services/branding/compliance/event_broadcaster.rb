module Branding
  module Compliance
    class EventBroadcaster
      attr_reader :brand_id, :session_id, :user_id

      def initialize(brand_id, session_id = nil, user_id = nil)
        @brand_id = brand_id
        @session_id = session_id
        @user_id = user_id
      end

      def broadcast_validation_start(content_info = {})
        broadcast_event("validation_started", {
          content_type: content_info[:type],
          content_length: content_info[:length],
          validators: content_info[:validators]
        })
      end

      def broadcast_validator_progress(validator_name, progress)
        broadcast_event("validator_progress", {
          validator: validator_name,
          progress: progress,
          status: progress >= 1.0 ? "completed" : "in_progress"
        })
      end

      def broadcast_violation_detected(violation)
        broadcast_event("violation_detected", {
          violation: sanitize_violation(violation),
          timestamp: Time.current
        })
      end

      def broadcast_suggestion_generated(suggestion)
        broadcast_event("suggestion_generated", {
          suggestion: sanitize_suggestion(suggestion),
          timestamp: Time.current
        })
      end

      def broadcast_validation_complete(results)
        broadcast_event("validation_complete", {
          compliant: results[:compliant],
          score: results[:score],
          violations_count: results[:violations]&.count || 0,
          suggestions_count: results[:suggestions]&.count || 0,
          processing_time: results[:metadata]&.dig(:processing_time),
          summary: results[:summary]
        })
      end

      def broadcast_fix_applied(fix_info)
        broadcast_event("fix_applied", {
          violation_id: fix_info[:violation_id],
          fix_type: fix_info[:fix_type],
          confidence: fix_info[:confidence],
          preview: truncate_content(fix_info[:preview])
        })
      end

      def broadcast_error(error_info)
        broadcast_event("validation_error", {
          error_type: error_info[:type],
          message: error_info[:message],
          recoverable: error_info[:recoverable]
        })
      end

      private

      def broadcast_event(event_type, data)
        channels = determine_channels
        
        channels.each do |channel|
          ActionCable.server.broadcast(channel, {
            event: event_type,
            data: data,
            metadata: event_metadata
          })
        end
      rescue StandardError => e
        Rails.logger.error "Failed to broadcast compliance event: #{e.message}"
      end

      def determine_channels
        channels = []
        
        # Brand-wide channel
        channels << "brand_compliance_#{brand_id}"
        
        # Session-specific channel if available
        channels << "compliance_session_#{session_id}" if session_id
        
        # User-specific channel if available
        channels << "user_compliance_#{user_id}" if user_id
        
        channels
      end

      def event_metadata
        {
          brand_id: brand_id,
          session_id: session_id,
          user_id: user_id,
          timestamp: Time.current.iso8601,
          server_time: Time.current.to_f
        }
      end

      def sanitize_violation(violation)
        {
          id: violation[:id],
          type: violation[:type],
          severity: violation[:severity],
          message: violation[:message],
          validator: violation[:validator_type],
          position: violation[:position]
        }
      end

      def sanitize_suggestion(suggestion)
        {
          type: suggestion[:type],
          priority: suggestion[:priority],
          title: suggestion[:title],
          description: truncate_content(suggestion[:description]),
          effort_level: suggestion[:effort_level]
        }
      end

      def truncate_content(content, max_length = 200)
        return content if content.nil? || content.length <= max_length
        
        "#{content[0...max_length]}..."
      end
    end
  end
end