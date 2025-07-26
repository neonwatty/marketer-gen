class StepExecution < ApplicationRecord
  belongs_to :journey_execution
  belongs_to :journey_step
  
  STATUSES = %w[pending in_progress completed failed skipped].freeze
  
  validates :status, inclusion: { in: STATUSES }
  
  scope :completed, -> { where(status: 'completed') }
  scope :failed, -> { where(status: 'failed') }
  scope :pending, -> { where(status: 'pending') }
  scope :in_progress, -> { where(status: 'in_progress') }
  
  def start!
    update!(status: 'in_progress', started_at: Time.current)
  end
  
  def complete!(result = {})
    update!(
      status: 'completed',
      completed_at: Time.current,
      result_data: result_data.merge(result)
    )
  end
  
  def fail!(reason = nil)
    data = result_data.dup
    data['failure_reason'] = reason if reason
    data['failed_at'] = Time.current
    
    update!(
      status: 'failed',
      completed_at: Time.current,
      result_data: data
    )
  end
  
  def skip!(reason = nil)
    data = result_data.dup
    data['skip_reason'] = reason if reason
    data['skipped_at'] = Time.current
    
    update!(
      status: 'skipped',
      completed_at: Time.current,
      result_data: data
    )
  end
  
  def duration
    return 0 unless started_at && completed_at
    completed_at - started_at
  end
  
  def add_result(key, value)
    data = result_data.dup
    data[key.to_s] = value
    update!(result_data: data)
  end
  
  def get_result(key)
    result_data[key.to_s]
  end
  
  def success?
    status == 'completed'
  end
  
  def failed?
    status == 'failed'
  end
  
  def pending?
    status == 'pending'
  end
  
  def in_progress?
    status == 'in_progress'
  end
end
