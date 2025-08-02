class ContentRepository < ApplicationRecord
  belongs_to :user, class_name: "User"
  belongs_to :campaign, optional: true
  has_many :content_versions, dependent: :destroy
  has_many :content_tags, dependent: :destroy
  has_many :content_approvals, dependent: :destroy
  has_many :content_permissions, dependent: :destroy
  has_many :content_revisions, dependent: :destroy

  validates :title, presence: true
  validates :content_type, presence: true
  validates :format, presence: true
  validates :storage_path, presence: true
  validates :file_hash, presence: true
  
  # Virtual attributes for form handling
  attr_accessor :body

  enum :status, {
    draft: 0,
    review: 1,
    approved: 2,
    published: 3,
    archived: 4,
    rejected: 5
  }

  enum :content_type, {
    email_template: 0,
    social_post: 1,
    blog_post: 2,
    landing_page: 3,
    advertisement: 4,
    newsletter: 5,
    campaign_brief: 6,
    marketing_copy: 7
  }

  enum :format, {
    html: 0,
    markdown: 1,
    plain_text: 2,
    json: 3,
    xml: 4
  }

  scope :by_campaign, ->(campaign_id) { where(campaign_id: campaign_id) }
  scope :by_user, ->(user_id) { where(user_id: user_id) }
  scope :by_content_type, ->(type) { where(content_type: type) }
  scope :by_status, ->(status) { where(status: status) }
  scope :recent, -> { order(created_at: :desc) }
  scope :accessible_by, ->(user) { where(user: user) } # Simple access control - can be enhanced
  scope :published_content, -> { where(status: 'published') }
  scope :needs_review, -> { where(status: 'review') }

  before_create :generate_file_hash
  before_create :set_storage_path

  def current_version
    content_versions.order(:version_number).last
  end

  def create_version!(body:, author:, commit_message: nil)
    version_number = (current_version&.version_number || 0) + 1
    content_versions.create!(
      body: body,
      version_number: version_number,
      author: author,
      commit_message: commit_message
    )
  end

  def total_versions
    content_versions.count
  end

  def can_be_archived?
    %w[published approved].include?(status)
  end

  def can_be_published?
    status == "approved"
  end

  private

  def generate_file_hash
    content_to_hash = [ title, body, content_type, format ].join("|")
    self.file_hash = Digest::SHA256.hexdigest(content_to_hash + Time.current.to_i.to_s)
  end

  def set_storage_path
    self.storage_path = "content/#{Date.current.year}/#{Date.current.month}/#{file_hash}"
  end
end
