class DemoAnalytic < ApplicationRecord
  belongs_to :user, optional: true
  has_many :demo_progresses, dependent: :destroy

  validates :workflow_key, presence: true, inclusion: { in: TourGeneratorService::WORKFLOW_CONFIGS.keys }
  validates :started_at, presence: true
  validates :steps_completed, :total_steps, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :completion_rate, numericality: { in: 0.0..1.0 }, allow_nil: true

  scope :completed, -> { where.not(completed_at: nil) }
  scope :incomplete, -> { where(completed_at: nil) }
  scope :for_workflow, ->(workflow_key) { where(workflow_key: workflow_key) }
  scope :recent, -> { order(started_at: :desc) }

  before_save :calculate_completion_rate
  before_save :calculate_duration

  def completed?
    completed_at.present?
  end

  def completion_percentage
    return 0 if total_steps.zero?
    (steps_completed.to_f / total_steps * 100).round(1)
  end

  def workflow_info
    TourGeneratorService::WORKFLOW_CONFIGS[workflow_key]
  end

  private

  def calculate_completion_rate
    return unless total_steps.present? && steps_completed.present?
    self.completion_rate = total_steps.zero? ? 0.0 : steps_completed.to_f / total_steps
  end

  def calculate_duration
    return unless started_at.present? && completed_at.present?
    self.duration = (completed_at - started_at).to_i
  end
end
