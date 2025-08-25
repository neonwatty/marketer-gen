class BrandIdentity < ApplicationRecord
  belongs_to :user
  has_many :brand_variants, dependent: :destroy
  
  has_many_attached :brand_materials
  has_many_attached :logo_files
  has_many_attached :style_guides
  
  STATUSES = %w[draft processing active archived].freeze
  
  validates :name, presence: true, uniqueness: { scope: :user_id }
  validates :status, inclusion: { in: STATUSES }
  validates :description, length: { maximum: 1000 }
  validates :brand_voice, length: { maximum: 2000 }
  validates :tone_guidelines, length: { maximum: 2000 }
  validates :messaging_framework, length: { maximum: 3000 }
  validates :restrictions, length: { maximum: 1500 }
  
  validate :brand_materials_validation
  
  scope :active, -> { where(is_active: true) }
  scope :by_status, ->(status) { where(status: status) }
  
  serialize :processed_guidelines, coder: JSON
  
  def draft?
    status == 'draft'
  end
  
  def processing?
    status == 'processing'
  end
  
  def active?
    status == 'active'
  end
  
  def archived?
    status == 'archived'
  end
  
  def activate!
    transaction do
      user.brand_identities.where.not(id: id).update_all(is_active: false)
      update!(is_active: true, status: 'active')
    end
  end
  
  def deactivate!
    update!(is_active: false, status: 'draft')
  end
  
  def process_materials!
    update!(status: 'processing')
    BrandMaterialsProcessorJob.perform_later(self)
  end
  
  def processed_guidelines_summary
    return {} unless processed_guidelines.present?
    
    {
      voice_extracted: processed_guidelines.dig('voice').present?,
      tone_extracted: processed_guidelines.dig('tone').present?,
      restrictions_extracted: processed_guidelines.dig('restrictions').present?,
      messaging_extracted: processed_guidelines.dig('messaging').present?,
      files_processed: processed_guidelines.dig('files_processed', 'count') || 0
    }
  end
  
  private
  
  def brand_materials_validation
    return unless brand_materials.attached?
    
    brand_materials.each do |material|
      if material.blob.byte_size > 10.megabytes
        errors.add(:brand_materials, 'files must be less than 10MB each')
      end
      
      allowed_types = %w[
        application/pdf
        application/msword
        application/vnd.openxmlformats-officedocument.wordprocessingml.document
        text/plain
        image/jpeg
        image/png
        image/gif
        image/webp
        image/svg+xml
      ]
      
      unless material.blob.content_type.in?(allowed_types)
        errors.add(:brand_materials, 'must be PDF, Word, text, or image files')
      end
    end
  end
end
