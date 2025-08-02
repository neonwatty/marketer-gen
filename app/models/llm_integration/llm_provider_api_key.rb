module LlmIntegration
  class LlmProviderApiKey < ApplicationRecord
    self.table_name = "llm_provider_api_keys"

    # Constants
    PROVIDER_NAMES = %i[openai anthropic cohere huggingface].freeze

    # Validations
    validates :provider_name, presence: true, inclusion: {
      in: PROVIDER_NAMES.map(&:to_s),
      message: "%{value} is not a valid provider"
    }
    validates :key_name, presence: true
    validates :encrypted_api_key, presence: true
    validates :key_permissions, presence: true
    validates :usage_quota, presence: true
    validates :active, inclusion: { in: [ true, false ] }
    validate :usage_quota_structure

    # Serialization
    serialize :key_permissions, coder: JSON #type: Array
    serialize :usage_quota, coder: JSON
    serialize :current_usage, coder: JSON

    # Encrypts the API key
    encrypts :encrypted_api_key

    # Enums
    enum provider_name: PROVIDER_NAMES.each_with_object({}) { |name, hash| hash[name] = name.to_s }

    # Scopes
    scope :active, -> { where(active: true) }
    scope :by_provider, ->(provider) { where(provider_name: provider) }
    scope :expiring_soon, ->(within: 30.days) { where("expires_at <= ?", within.from_now) }
    scope :recently_used, -> { where("last_used_at > ?", 24.hours.ago) }

    # Callbacks
    before_validation :set_defaults, on: :create
    before_save :reset_usage_if_new_month

    # Class methods
    def self.primary_key_for_provider(provider)
      by_provider(provider).active.where(key_name: "primary_key").first
    end

    def self.rotate_all_keys!
      active.find_each(&:rotate_key!)
    end

    # Instance methods
    def expired?
      expires_at && expires_at < Time.current
    end

    def expires_soon?(within: 30.days)
      expires_at && expires_at <= within.from_now
    end

    def rotate_key(new_encrypted_key = nil)
      new_key = new_encrypted_key || generate_new_key
      old_key = encrypted_api_key

      update!(
        encrypted_api_key: new_key,
        rotated_at: Time.current,
        previous_key_hash: Digest::SHA256.hexdigest(old_key)
      )

      new_key
    end

    def rotate_key!
      rotate_key
    end

    def record_usage(requests: 0, tokens: 0)
      self.current_usage ||= {}
      self.current_usage["requests"] = (current_usage["requests"] || 0) + requests
      self.current_usage["tokens"] = (current_usage["tokens"] || 0) + tokens
      self.last_used_at = Time.current
      save!
    end

    def quota_exceeded?(type = nil)
      return false unless usage_quota.present? && current_usage.present?

      if type
        quota_limit = usage_quota["monthly_#{type}"]
        current_use = current_usage[type.to_s] || 0
        quota_limit && current_use >= quota_limit
      else
        quota_exceeded?(:requests) || quota_exceeded?(:tokens)
      end
    end

    def quota_remaining(type)
      return nil unless usage_quota.present?

      quota_limit = usage_quota["monthly_#{type}"]
      current_use = (current_usage&.dig(type.to_s) || 0)

      return nil unless quota_limit
      [ quota_limit - current_use, 0 ].max
    end

    def usage_percentage(type)
      return 0.0 unless usage_quota.present?

      quota_limit = usage_quota["monthly_#{type}"]
      current_use = (current_usage&.dig(type.to_s) || 0)

      return 0.0 unless quota_limit && quota_limit > 0
      [ (current_use.to_f / quota_limit * 100), 100.0 ].min
    end

    def has_permission?(permission)
      key_permissions.include?(permission.to_s)
    end

    def add_permission(permission)
      return if has_permission?(permission)

      self.key_permissions = (key_permissions + [ permission.to_s ]).uniq
      save!
    end

    def remove_permission(permission)
      self.key_permissions = key_permissions - [ permission.to_s ]
      save!
    end

    def usage_summary
      {
        provider: provider_name,
        key_name: key_name,
        active: active,
        expires_at: expires_at,
        last_used: last_used_at,
        requests: {
          used: current_usage&.dig("requests") || 0,
          quota: usage_quota["monthly_requests"],
          remaining: quota_remaining(:requests),
          percentage: usage_percentage(:requests)
        },
        tokens: {
          used: current_usage&.dig("tokens") || 0,
          quota: usage_quota["monthly_tokens"],
          remaining: quota_remaining(:tokens),
          percentage: usage_percentage(:tokens)
        }
      }
    end

    def deactivate!
      update!(active: false, deactivated_at: Time.current)
    end

    def activate!
      update!(active: true, activated_at: Time.current)
    end

    def reset_usage!
      update!(
        current_usage: {},
        usage_reset_at: Time.current
      )
    end

    def is_primary_key?
      key_name == "primary_key"
    end

    def cost_estimate_this_month
      tokens_used = current_usage&.dig("tokens") || 0

      # Rough cost estimation per provider (per 1000 tokens)
      cost_per_1k_tokens = case provider_name.to_sym
      when :openai then 0.03
      when :anthropic then 0.015
      when :cohere then 0.002
      when :huggingface then 0.0
      else 0.01
      end

      (tokens_used / 1000.0) * cost_per_1k_tokens
    end

    def estimated_monthly_cost
      return 0.0 unless usage_quota["monthly_tokens"]

      cost_per_1k_tokens = case provider_name.to_sym
      when :openai then 0.03
      when :anthropic then 0.015
      when :cohere then 0.002
      when :huggingface then 0.0
      else 0.01
      end

      (usage_quota["monthly_tokens"] / 1000.0) * cost_per_1k_tokens
    end

    private

    def set_defaults
      self.active = true if active.nil?
      self.current_usage ||= {}
      self.key_permissions ||= []
    end

    def usage_quota_structure
      return unless usage_quota.present?

      unless usage_quota.is_a?(Hash)
        errors.add(:usage_quota, "must be a hash")
        return
      end

      required_keys = %w[monthly_requests monthly_tokens]

      required_keys.each do |key|
        value = usage_quota[key]
        unless value.is_a?(Numeric) && value > 0
          errors.add(:usage_quota, "#{key} must be a positive number")
        end
      end
    end

    def reset_usage_if_new_month
      return unless usage_reset_at

      if usage_reset_at.beginning_of_month < Time.current.beginning_of_month
        self.current_usage = {}
        self.usage_reset_at = Time.current
      end
    end

    def generate_new_key
      # This would integrate with the actual provider's key generation
      # For now, return a placeholder
      "rotated_key_#{SecureRandom.alphanumeric(32)}"
    end
  end
end
