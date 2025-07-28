module Branding
  module Compliance
    class BaseValidator
      attr_reader :brand, :content, :options, :violations, :suggestions

      def initialize(brand, content, options = {})
        @brand = brand
        @content = content
        @options = options
        @violations = []
        @suggestions = []
      end

      def validate
        raise NotImplementedError, "Subclasses must implement validate method"
      end

      protected

      def add_violation(type:, severity:, message:, details: {}, rule_id: nil)
        violation = {
          validator: self.class.name.demodulize.underscore,
          type: type,
          severity: severity.to_s,
          message: message,
          details: details,
          rule_id: rule_id,
          timestamp: Time.current,
          position: detect_position(details)
        }
        
        @violations << violation
        broadcast_violation(violation) if options[:real_time]
      end

      def add_suggestion(type:, message:, details: {}, priority: "medium", rule_id: nil)
        suggestion = {
          validator: self.class.name.demodulize.underscore,
          type: type,
          message: message,
          details: details,
          priority: priority,
          rule_id: rule_id,
          timestamp: Time.current
        }
        
        @suggestions << suggestion
      end

      def detect_position(details)
        # Attempt to find position in content for the violation
        if details[:text].present?
          index = content.index(details[:text])
          { start: index, end: index + details[:text].length } if index
        end
      end

      def broadcast_violation(violation)
        ActionCable.server.broadcast(
          "brand_compliance_#{brand.id}",
          {
            event: "violation_detected",
            violation: violation
          }
        )
      end

      def cache_key(suffix = nil)
        key_parts = [
          "compliance",
          self.class.name.underscore,
          brand.id,
          Digest::MD5.hexdigest(content.to_s)[0..10]
        ]
        key_parts << suffix if suffix
        key_parts.join(":")
      end

      def cached_result(key, expires_in: 5.minutes)
        Rails.cache.fetch(cache_key(key), expires_in: expires_in) do
          yield
        end
      end

      def severity_weight(severity)
        case severity.to_s
        when "critical" then 1.0
        when "high" then 0.8
        when "medium" then 0.5
        when "low" then 0.3
        else 0.4
        end
      end
    end
  end
end