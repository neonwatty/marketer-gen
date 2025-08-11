class AIJobStatus < ApplicationRecord
  belongs_to :generation_request, class_name: 'AIGenerationRequest'
  
  enum :status, {
    queued: 'queued',
    processing: 'processing', 
    completed: 'completed',
    failed: 'failed',
    cancelled: 'cancelled'
  }
  
  # Serialize JSON field
  serialize :progress_data, coder: JSON
  
  validates :job_id, presence: true
  validates :status, presence: true
  
  scope :recent, -> { order(updated_at: :desc) }
  scope :by_status, ->(status) { where(status: status) }
  scope :for_job, ->(job_id) { where(job_id: job_id) }
  
  def progress_percentage
    return 0 unless progress_data.is_a?(Hash)
    progress_data.dig('progress_percentage') || 0
  end
  
  def error_message
    return nil unless failed?
    progress_data.dig('error_message')
  end
  
  def processing_duration
    started_at = progress_data.dig('started_at')
    completed_at = progress_data.dig('completed_at') || progress_data.dig('failed_at')
    
    return nil unless started_at && completed_at
    
    Time.parse(completed_at) - Time.parse(started_at)
  rescue ArgumentError
    nil
  end
end
