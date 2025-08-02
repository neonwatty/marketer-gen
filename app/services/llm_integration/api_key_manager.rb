module LlmIntegration
  class ApiKeyManager
    include ActiveModel::Model

    def initialize
      @encryption_service = Rails.application.key_generator.generate_key("llm_api_keys")
    end

    def valid_key?(provider, api_key)
      return false unless api_key.present?

      case provider.to_sym
      when :openai
        api_key.start_with?("sk-") && api_key.length > 20
      when :anthropic
        api_key.length > 20 # Anthropic keys don't have a standard prefix
      when :cohere
        api_key.length > 20
      when :huggingface
        api_key.blank? || api_key.start_with?("hf_")
      else
        api_key.length > 10
      end
    end

    def rotate_key(provider, new_key)
      # Find or create API key record
      api_key_record = LlmIntegration::LlmProviderApiKey.find_or_initialize_by(
        provider_name: provider,
        key_name: "primary_key"
      )

      # Validate new key
      unless valid_key?(provider, new_key)
        raise ArgumentError, "Invalid API key format for provider #{provider}"
      end

      # Store previous key for rollback if needed
      previous_key = api_key_record.encrypted_api_key

      # Update with new key
      api_key_record.update!(
        encrypted_api_key: new_key,
        rotated_at: Time.current,
        previous_key_hash: previous_key ? Digest::SHA256.hexdigest(previous_key) : nil,
        active: true
      )

      # Test the new key
      test_result = test_key_validity(provider, new_key)

      unless test_result[:valid]
        # Rollback if test fails and we had a previous key
        if previous_key
          api_key_record.update!(encrypted_api_key: previous_key)
          raise StandardError, "New API key failed validation: #{test_result[:error]}"
        else
          api_key_record.update!(active: false)
          raise StandardError, "New API key failed validation and no previous key to rollback to"
        end
      end

      new_key
    end

    def current_key(provider)
      api_key_record = LlmIntegration::LlmProviderApiKey
        .active
        .find_by(provider_name: provider, key_name: "primary_key")

      api_key_record&.encrypted_api_key
    end

    def set_key_expiry(provider, expiry_date)
      api_key_record = LlmIntegration::LlmProviderApiKey.find_by(
        provider_name: provider,
        key_name: "primary_key"
      )

      if api_key_record
        api_key_record.update!(expires_at: expiry_date)
      else
        raise ArgumentError, "No API key found for provider #{provider}"
      end
    end

    def key_expires_soon?(provider, within: 30.days)
      api_key_record = LlmIntegration::LlmProviderApiKey.find_by(
        provider_name: provider,
        key_name: "primary_key"
      )

      return false unless api_key_record&.expires_at

      api_key_record.expires_at <= within.from_now
    end

    def get_key_status(provider)
      api_key_record = LlmIntegration::LlmProviderApiKey.find_by(
        provider_name: provider,
        key_name: "primary_key"
      )

      return { exists: false } unless api_key_record

      {
        exists: true,
        active: api_key_record.active,
        expires_at: api_key_record.expires_at,
        expires_soon: api_key_record.expires_soon?,
        last_used: api_key_record.last_used_at,
        usage_summary: api_key_record.usage_summary,
        rotated_at: api_key_record.rotated_at
      }
    end

    def list_all_keys
      LlmIntegration::LlmProviderApiKey.includes(:provider).map do |key_record|
        {
          provider: key_record.provider_name,
          key_name: key_record.key_name,
          active: key_record.active,
          expires_at: key_record.expires_at,
          last_used: key_record.last_used_at,
          usage_summary: key_record.usage_summary
        }
      end
    end

    def deactivate_key(provider, key_name = "primary_key")
      api_key_record = LlmIntegration::LlmProviderApiKey.find_by(
        provider_name: provider,
        key_name: key_name
      )

      if api_key_record
        api_key_record.deactivate!
        true
      else
        false
      end
    end

    def create_backup_key(provider, backup_key)
      # Validate backup key
      unless valid_key?(provider, backup_key)
        raise ArgumentError, "Invalid backup API key format for provider #{provider}"
      end

      # Create backup key record
      LlmIntegration::LlmProviderApiKey.create!(
        provider_name: provider,
        key_name: "backup_key",
        encrypted_api_key: backup_key,
        key_permissions: [ "chat:completions" ], # Basic permissions
        usage_quota: default_usage_quota,
        active: true
      )
    end

    def failover_to_backup(provider)
      primary_key = LlmIntegration::LlmProviderApiKey.find_by(
        provider_name: provider,
        key_name: "primary_key"
      )

      backup_key = LlmIntegration::LlmProviderApiKey.find_by(
        provider_name: provider,
        key_name: "backup_key"
      )

      return false unless backup_key

      # Deactivate primary and promote backup
      primary_key&.deactivate!

      # Create new primary from backup
      LlmIntegration::LlmProviderApiKey.create!(
        provider_name: provider,
        key_name: "primary_key",
        encrypted_api_key: backup_key.encrypted_api_key,
        key_permissions: backup_key.key_permissions,
        usage_quota: backup_key.usage_quota,
        active: true
      )

      backup_key.destroy!
      true
    end

    private

    def test_key_validity(provider, api_key)
      case provider.to_sym
      when :openai
        test_openai_key(api_key)
      when :anthropic
        test_anthropic_key(api_key)
      when :cohere
        test_cohere_key(api_key)
      when :huggingface
        test_huggingface_key(api_key)
      else
        { valid: true, error: nil } # Default to valid for unknown providers
      end
    end

    def test_openai_key(api_key)
      auth = LlmIntegration::Authentication::OpenAIAuth.new(api_key)
      result = auth.test_connection

      {
        valid: result[:success],
        error: result[:error]
      }
    rescue => e
      {
        valid: false,
        error: "Connection test failed: #{e.message}"
      }
    end

    def test_anthropic_key(api_key)
      auth = LlmIntegration::Authentication::AnthropicAuth.new(api_key)
      result = auth.test_connection

      {
        valid: result[:success],
        error: result[:error]
      }
    rescue => e
      {
        valid: false,
        error: "Connection test failed: #{e.message}"
      }
    end

    def test_cohere_key(api_key)
      auth = LlmIntegration::Authentication::CohereAuth.new(api_key)
      result = auth.test_connection

      {
        valid: result[:success],
        error: result[:error]
      }
    rescue => e
      {
        valid: false,
        error: "Connection test failed: #{e.message}"
      }
    end

    def test_huggingface_key(api_key)
      auth = LlmIntegration::Authentication::HuggingFaceAuth.new(api_key)
      result = auth.test_connection

      {
        valid: result[:success],
        error: result[:error]
      }
    rescue => e
      {
        valid: false,
        error: "Connection test failed: #{e.message}"
      }
    end

    def default_usage_quota
      {
        "monthly_requests" => 10000,
        "monthly_tokens" => 1000000
      }
    end
  end
end
