module LlmIntegration
  class ConversationSession < ApplicationRecord
    self.table_name = "conversation_sessions"

    # Constants
    SESSION_TYPES = %i[campaign_setup content_optimization brand_consultation general_inquiry].freeze
    STATUSES = %i[active paused completed abandoned expired].freeze

    # Associations
    belongs_to :user
    belongs_to :brand
    has_many :conversation_messages, dependent: :destroy

    # Validations
    validates :session_type, presence: true, inclusion: {
      in: SESSION_TYPES.map(&:to_s),
      message: "%{value} is not a valid session type"
    }
    validates :status, presence: true, inclusion: {
      in: STATUSES.map(&:to_s),
      message: "%{value} is not a valid status"
    }
    validates :context, presence: true
    validates :started_at, presence: true
    validates :last_activity_at, presence: true

    # Serialization
    serialize :context, coder: JSON

    # Enums
    enum session_type: SESSION_TYPES.each_with_object({}) { |type, hash| hash[type] = type.to_s }
    enum status: STATUSES.each_with_object({}) { |status, hash| hash[status] = status.to_s }

    # Scopes
    scope :for_user, ->(user) { where(user: user) }
    scope :for_brand, ->(brand) { where(brand: brand) }
    scope :active_sessions, -> { where(status: :active) }
    scope :recent, -> { order(last_activity_at: :desc) }
    scope :expired_sessions, -> { where("last_activity_at < ?", 2.hours.ago) }

    # Callbacks
    before_validation :set_defaults, on: :create
    after_update :check_expiration

    # Instance methods
    def expired?
      last_activity_at < 2.hours.ago
    end

    def duration
      return nil unless started_at
      end_time = completed_at || last_activity_at || Time.current
      end_time - started_at
    end

    def touch_activity!
      update_column(:last_activity_at, Time.current)
    end

    def add_to_context(key, value)
      context[key.to_s] = value
      save!
    end

    def get_from_context(key)
      context[key.to_s]
    end

    def extract_requirements
      context.dig("extracted_requirements") || {}
    end

    def conversation_stage
      context.dig("conversation_stage") || "initial"
    end

    def set_conversation_stage(stage)
      add_to_context("conversation_stage", stage)
    end

    def discussed_topics
      context.dig("discussed_topics") || []
    end

    def add_discussed_topic(topic)
      topics = discussed_topics
      topics << topic unless topics.include?(topic)
      add_to_context("discussed_topics", topics)
    end

    def completion_percentage
      case session_type.to_sym
      when :campaign_setup
        calculate_campaign_setup_completion
      when :content_optimization
        calculate_content_optimization_completion
      when :brand_consultation
        calculate_brand_consultation_completion
      else
        0.0
      end
    end

    def next_suggested_questions
      case conversation_stage
      when "initial"
        initial_questions
      when "gathering_requirements"
        requirement_questions
      when "clarifying_details"
        clarification_questions
      when "finalizing"
        finalization_questions
      else
        []
      end
    end

    def can_be_resumed?
      %w[active paused].include?(status) && !expired?
    end

    def mark_as_completed!(completion_data = {})
      update!(
        status: :completed,
        completed_at: Time.current,
        completion_data: completion_data
      )
    end

    def mark_as_abandoned!
      update!(
        status: :abandoned,
        abandoned_at: Time.current
      )
    end

    def pause!
      update!(
        status: :paused,
        paused_at: Time.current
      )
    end

    def resume!
      update!(
        status: :active,
        resumed_at: Time.current,
        last_activity_at: Time.current
      )
    end

    def session_summary
      {
        id: id,
        type: session_type,
        status: status,
        duration: duration,
        completion: completion_percentage,
        stage: conversation_stage,
        topics: discussed_topics,
        requirements: extract_requirements,
        message_count: conversation_messages.count
      }
    end

    def generate_transcript
      messages = conversation_messages.order(:created_at)

      transcript = "Conversation Session ##{id}\n"
      transcript += "Type: #{session_type.humanize}\n"
      transcript += "Date: #{started_at.strftime('%B %d, %Y at %I:%M %p')}\n"
      transcript += "Duration: #{duration_in_words}\n\n"

      messages.each do |message|
        timestamp = message.created_at.strftime("%I:%M %p")
        transcript += "[#{timestamp}] #{message.sender_type.humanize}: #{message.content}\n\n"
      end

      transcript
    end

    private

    def set_defaults
      self.started_at ||= Time.current
      self.last_activity_at ||= Time.current
      self.status ||= :active
      self.context ||= {}
    end

    def check_expiration
      if last_activity_at_changed? && expired?
        update_column(:status, :expired) unless completed? || abandoned?
      end
    end

    def calculate_campaign_setup_completion
      required_fields = %w[campaign_type target_audience budget_range timeline objectives]
      completed_fields = required_fields.count { |field| extract_requirements[field].present? }
      (completed_fields.to_f / required_fields.length * 100).round(2)
    end

    def calculate_content_optimization_completion
      required_fields = %w[content_type optimization_goals target_metrics brand_guidelines]
      completed_fields = required_fields.count { |field| extract_requirements[field].present? }
      (completed_fields.to_f / required_fields.length * 100).round(2)
    end

    def calculate_brand_consultation_completion
      required_fields = %w[consultation_type specific_questions brand_challenges desired_outcomes]
      completed_fields = required_fields.count { |field| extract_requirements[field].present? }
      (completed_fields.to_f / required_fields.length * 100).round(2)
    end

    def initial_questions
      case session_type.to_sym
      when :campaign_setup
        [
          "What type of campaign would you like to create?",
          "Who is your target audience?",
          "What's your primary campaign objective?"
        ]
      when :content_optimization
        [
          "What type of content would you like to optimize?",
          "What specific improvements are you looking for?",
          "What metrics are most important to you?"
        ]
      else
        [
          "How can I help you today?",
          "What would you like to accomplish?",
          "Do you have any specific questions about your brand?"
        ]
      end
    end

    def requirement_questions
      # Context-specific questions based on what's already been discussed
      []
    end

    def clarification_questions
      # Questions to clarify previously provided information
      []
    end

    def finalization_questions
      [
        "Is there anything else you'd like to add or modify?",
        "Are you ready to proceed with these requirements?",
        "Would you like to review the summary before we continue?"
      ]
    end

    def duration_in_words
      return "0 minutes" unless duration

      total_minutes = (duration / 60).round
      hours = total_minutes / 60
      minutes = total_minutes % 60

      if hours > 0
        "#{hours} hour#{'s' if hours != 1}#{minutes > 0 ? " and #{minutes} minute#{'s' if minutes != 1}" : ''}"
      else
        "#{minutes} minute#{'s' if minutes != 1}"
      end
    end
  end
end
