class PlanComment < ApplicationRecord
  belongs_to :campaign_plan
  belongs_to :user
  belongs_to :parent_comment, class_name: 'PlanComment', optional: true
  has_many :replies, class_name: 'PlanComment', foreign_key: 'parent_comment_id', dependent: :destroy
  belongs_to :resolved_by_user, class_name: 'User', optional: true
  
  COMMENT_TYPES = %w[general suggestion question concern approval_note].freeze
  PRIORITY_LEVELS = %w[low medium high critical].freeze
  
  validates :content, presence: true, length: { minimum: 5, maximum: 2000 }
  validates :section, presence: true
  validates :comment_type, inclusion: { in: COMMENT_TYPES }
  validates :priority, inclusion: { in: PRIORITY_LEVELS }
  
  # JSON serialization for complex data
  serialize :metadata, JSON
  serialize :mentioned_users, JSON
  
  scope :unresolved, -> { where(resolved: false) }
  scope :resolved, -> { where(resolved: true) }
  scope :top_level, -> { where(parent_comment_id: nil) }
  scope :replies, -> { where.not(parent_comment_id: nil) }
  scope :by_section, ->(section) { where(section: section) }
  scope :by_priority, ->(priority) { where(priority: priority) }
  scope :by_type, ->(type) { where(comment_type: type) }
  scope :recent, -> { order(created_at: :desc) }
  scope :with_replies, -> { includes(:replies, :user, :resolved_by_user) }
  
  before_validation :set_defaults, on: :create
  before_save :extract_mentions
  after_create :notify_mentioned_users
  
  def resolve!(resolver = nil)
    update!(
      resolved: true,
      resolved_at: Time.current,
      resolved_by_user: resolver || Current.user
    )
  end
  
  def unresolve!
    update!(
      resolved: false,
      resolved_at: nil,
      resolved_by_user: nil
    )
  end
  
  def reply(content:, user:, **options)
    replies.create!(
      content: content,
      user: user,
      campaign_plan: campaign_plan,
      section: section,
      comment_type: options[:comment_type] || 'general',
      priority: options[:priority] || 'low',
      line_number: line_number,
      metadata: options[:metadata] || {}
    )
  end
  
  def thread
    if parent_comment.present?
      parent_comment.thread
    else
      [self] + replies.includes(:user, :replies).order(:created_at)
    end
  end
  
  def thread_count
    if parent_comment.present?
      parent_comment.thread_count
    else
      replies.count + 1
    end
  end
  
  def top_level_comment
    parent_comment.present? ? parent_comment.top_level_comment : self
  end
  
  def mentions_user?(user)
    mentioned_users.include?(user.id) if mentioned_users.present?
  end
  
  def high_priority?
    %w[high critical].include?(priority)
  end
  
  def critical?
    priority == 'critical'
  end
  
  def suggestion?
    comment_type == 'suggestion'
  end
  
  def question?
    comment_type == 'question'
  end
  
  def concern?
    comment_type == 'concern'
  end
  
  def approval_note?
    comment_type == 'approval_note'
  end
  
  def age_in_days
    ((Time.current - created_at) / 1.day).round
  end
  
  def stale?
    age_in_days > 7 && !resolved?
  end
  
  def format_for_notification
    {
      id: id,
      content: content.truncate(100),
      section: section.humanize,
      comment_type: comment_type.humanize,
      priority: priority,
      user: user.name,
      created_at: created_at,
      line_number: line_number,
      campaign_plan: campaign_plan.name,
      url: Rails.application.routes.url_helpers.campaign_plan_path(campaign_plan, anchor: "comment-#{id}")
    }
  end
  
  private
  
  def set_defaults
    self.comment_type ||= 'general'
    self.priority ||= 'low'
    self.resolved ||= false
    self.metadata ||= {}
    self.mentioned_users ||= []
  end
  
  def extract_mentions
    # Extract @username mentions from content
    mentions = content.scan(/@(\w+)/).flatten
    
    if mentions.any?
      # Find users by username/email
      users = User.where(email_address: mentions.map { |m| "#{m}@" })
                  .or(User.where("name ILIKE ANY (ARRAY[?])", mentions.map { |m| "%#{m}%" }))
      
      self.mentioned_users = users.pluck(:id).uniq
    else
      self.mentioned_users = []
    end
  end
  
  def notify_mentioned_users
    return unless mentioned_users.any?
    
    # Send notifications to mentioned users
    User.where(id: mentioned_users).find_each do |user|
      # This would typically enqueue a job to send notification
      # For now, we'll just log it
      Rails.logger.info "Notifying user #{user.email_address} about mention in comment #{id}"
      
      # Example: NotifyMentionJob.perform_later(user, self)
    end
  end
end