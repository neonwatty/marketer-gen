module LlmIntegration
  class ContentGenerationRequest < ApplicationRecord
    self.table_name = "content_generation_requests"

    # Constants
    CONTENT_TYPES = %i[
      email_subject email_body social_post ad_copy landing_page_headline
      blog_title blog_post product_description marketing_copy
    ].freeze

    PRIORITIES = %i[low medium high urgent].freeze

    STATUSES = %i[pending processing completed failed cancelled].freeze

    # Associations
    belongs_to :brand
    belongs_to :user
    has_many :generated_contents, dependent: :destroy
    has_one :latest_generated_content, -> { order(created_at: :desc) },
            class_name: "LlmIntegration::GeneratedContent"

    # Validations
    validates :content_type, presence: true, inclusion: {
      in: CONTENT_TYPES.map(&:to_s),
      message: "%{value} is not a valid content type"
    }
    validates :prompt_template, presence: true
    validates :prompt_variables, presence: true
    validates :status, presence: true, inclusion: {
      in: STATUSES.map(&:to_s),
      message: "%{value} is not a valid status"
    }
    validates :priority, presence: true, inclusion: {
      in: PRIORITIES.map(&:to_s),
      message: "%{value} is not a valid priority"
    }
    validates :provider_preference, inclusion: {
      in: %w[openai anthropic cohere huggingface auto],
      allow_blank: true
    }

    # Serialization
    serialize :prompt_variables, coder: JSON
    serialize :generation_parameters, coder: JSON

    # Enums (for better querying)
    enum status: STATUSES.each_with_object({}) { |status, hash| hash[status] = status.to_s }
    enum priority: PRIORITIES.each_with_object({}) { |priority, hash| hash[priority] = priority.to_s }
    enum content_type: CONTENT_TYPES.each_with_object({}) { |type, hash| hash[type] = type.to_s }

    # Scopes
    scope :for_brand, ->(brand) { where(brand: brand) }
    scope :by_priority, ->(priority) { where(priority: priority) }
    scope :recent, -> { order(created_at: :desc) }
    scope :high_priority, -> { where(priority: %w[high urgent]) }

    # Callbacks
    before_create :set_defaults
    after_update :track_status_changes

    # Instance methods
    def rendered_prompt
      return prompt_template unless prompt_variables.present?

      rendered = prompt_template.dup
      prompt_variables.each do |key, value|
        rendered.gsub!("{{#{key}}}", value.to_s)
      end
      rendered
    end

    def estimated_completion_time
      case priority.to_sym
      when :urgent then 5.minutes
      when :high then 15.minutes
      when :medium then 1.hour
      when :low then 4.hours
      else 1.hour
      end
    end

    def can_retry?
      failed? && retry_count < 3
    end

    def increment_retry_count!
      update!(retry_count: retry_count + 1)
    end

    def mark_as_processing!
      update!(status: :processing, started_at: Time.current)
    end

    def mark_as_completed!
      update!(status: :completed, completed_at: Time.current)
    end

    def mark_as_failed!(error_message = nil)
      update!(
        status: :failed,
        failed_at: Time.current,
        error_message: error_message
      )
    end

    def processing_duration
      return nil unless started_at && completed_at
      completed_at - started_at
    end

    private

    def set_defaults
      self.priority ||= :medium
      self.status ||= :pending
      self.retry_count ||= 0
      self.generation_parameters ||= {}
    end

    def track_status_changes
      if saved_change_to_status?
        case status.to_sym
        when :processing
          self.started_at = Time.current unless started_at
        when :completed
          self.completed_at = Time.current unless completed_at
        when :failed
          self.failed_at = Time.current unless failed_at
        end
        save! if changed?
      end
    end
  end
end
