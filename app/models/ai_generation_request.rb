class AIGenerationRequest < ApplicationRecord
  belongs_to :campaign
  has_many :ai_job_statuses, foreign_key: :generation_request_id, dependent: :destroy
  
  enum :status, {
    pending: 'pending',
    processing: 'processing',
    completed: 'completed',
    failed: 'failed',
    review: 'review'
  }
  
  enum :content_type, {
    social_media_post: 'social_media_post',
    ad_copy: 'ad_copy',
    email_content: 'email_content',
    landing_page: 'landing_page',
    blog_post: 'blog_post',
    campaign_strategy: 'campaign_strategy'
  }
  
  # Serialize JSON fields
  serialize :prompt_data, coder: JSON
  serialize :metadata, coder: JSON
  
  validates :content_type, presence: true
  validates :status, presence: true
  validates :prompt_data, presence: true
  
  scope :recent, -> { order(created_at: :desc) }
  scope :by_status, ->(status) { where(status: status) }
  scope :by_content_type, ->(type) { where(content_type: type) }
  
  def enqueue_generation_job
    job = AIGenerationJob.perform_later(id, content_type, prompt_data)
    
    # Create initial job status record
    ai_job_statuses.create!(
      job_id: job.job_id,
      status: 'queued',
      progress_data: { 
        queued_at: Time.current.iso8601,
        job_class: 'AIGenerationJob'
      }
    )
    
    job
  end
  
  def current_job_status
    ai_job_statuses.order(:updated_at).last
  end
  
  def processing_time
    return nil unless completed_at && created_at
    completed_at - created_at
  end
end
