class JourneyStep < ApplicationRecord
  belongs_to :journey

  STEP_TYPES = %w[email social_post content_piece webinar event landing_page automation custom].freeze
  CHANNELS = %w[email social_media website blog video podcast webinar event sms push_notification].freeze

  validates :title, presence: true, length: { maximum: 255 }
  validates :description, length: { maximum: 1000 }
  validates :step_type, presence: true, inclusion: { in: STEP_TYPES }
  validates :channel, inclusion: { in: CHANNELS }, allow_blank: true
  validates :sequence_order, presence: true, numericality: { greater_than_or_equal_to: 0 }

  validates :sequence_order, uniqueness: { scope: :journey_id, message: "must be unique within the journey" }

  serialize :settings, coder: JSON

  scope :ordered, -> { order(:sequence_order) }
  scope :by_type, ->(type) { where(step_type: type) }
  scope :by_channel, ->(channel) { where(channel: channel) }

  before_validation :set_next_sequence_order, on: :create, if: -> { sequence_order.blank? }

  def next_step
    journey.journey_steps.where('sequence_order > ?', sequence_order).order(:sequence_order).first
  end

  def previous_step
    journey.journey_steps.where('sequence_order < ?', sequence_order).order(sequence_order: :desc).first
  end

  def first_step?
    sequence_order == 0
  end

  def last_step?
    next_step.nil?
  end

  private


  def set_next_sequence_order
    # Query the database directly to get the actual max sequence order
    max_order = JourneyStep.where(journey_id: journey_id).maximum(:sequence_order) || -1
    self.sequence_order = max_order + 1
  end
end
