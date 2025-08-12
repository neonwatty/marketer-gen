# ContentBranch model - Git-like branching system for content development
# Manages parallel content development with branch isolation and merging
class ContentBranch < ApplicationRecord
  belongs_to :content_item, polymorphic: true, optional: true
  belongs_to :source_version, class_name: 'ContentVersion', optional: true
  belongs_to :head_version, class_name: 'ContentVersion', optional: true
  # Author tracking - can be extended when User model is added
  # belongs_to :author, class_name: 'User', optional: true

  has_many :content_versions, dependent: :destroy
  has_many :target_merges, class_name: 'ContentMerge', foreign_key: 'target_branch_id', dependent: :destroy
  has_many :source_merges, class_name: 'ContentMerge', foreign_key: 'source_branch_id', dependent: :destroy

  validates :name, presence: true, length: { minimum: 1, maximum: 100 }
  validates :name, format: { 
    with: /\A[a-zA-Z0-9\-_\/]+\z/, 
    message: "can only contain letters, numbers, hyphens, underscores, and forward slashes" 
  }
  validates :name, uniqueness: { scope: [:content_item_type, :content_item_id] }

  # Branch states
  enum :status, {
    active: 0,
    merged: 1,
    archived: 2,
    protected: 3,
    deleted: 4
  }

  # Branch types
  enum :branch_type, {
    main: 0,
    feature: 1,
    hotfix: 2,
    release: 3,
    experiment: 4,
    review: 5
  }

  scope :active_branches, -> { where(status: :active) }
  scope :by_author, ->(author) { where(author: author) }
  scope :main_branches, -> { where(branch_type: :main) }
  scope :feature_branches, -> { where(branch_type: :feature) }

  before_validation :set_default_branch_type, on: :create
  before_validation :normalize_branch_name
  after_create :create_initial_version, if: :should_create_initial_version?

  # Branch operations
  def self.create_main_branch(content_item, author = nil)
    create!(
      name: 'main',
      content_item: content_item,
      author: author,
      branch_type: :main,
      status: :active,
      description: 'Main development branch'
    )
  end

  def self.create_feature_branch(name, source_branch, author = nil)
    create!(
      name: "feature/#{name}",
      content_item: source_branch.content_item,
      source_version: source_branch.head_version,
      author: author,
      branch_type: :feature,
      status: :active,
      description: "Feature branch for #{name}"
    )
  end

  def checkout_new_version(content_data, commit_message, author = nil)
    transaction do
      new_version = ContentVersion.create!(
        content_item: content_item,
        content_data: content_data,
        content_type: head_version&.content_type || 'marketing_content',
        commit_message: commit_message,
        author: author,
        parent: head_version,
        branch: self
      )
      
      update!(head_version: new_version)
      new_version.commit!(commit_message, author)
      new_version
    end
  end

  def merge_into(target_branch, author = nil, options = {})
    strategy = options[:strategy] || :auto
    message = options[:message] || "Merge #{name} into #{target_branch.name}"
    
    unless head_version
      raise ContentVersioningError, "Cannot merge branch with no commits"
    end
    
    merge_result = head_version.merge_into(target_branch, author, strategy: strategy)
    
    # Update branch status if merge was successful
    if merge_result.success?
      update!(status: :merged, merged_at: Time.current)
    end
    
    merge_result
  end

  def rebase_onto(target_branch, author = nil)
    return false unless target_branch.head_version
    
    transaction do
      # Get all commits that are unique to this branch
      unique_commits = commits_ahead_of(target_branch)
      
      if unique_commits.empty?
        # Already up to date
        return true
      end
      
      # Create new versions on top of target branch
      new_head = target_branch.head_version
      
      unique_commits.reverse.each do |commit|
        new_version = ContentVersion.create!(
          content_item: content_item,
          content_data: commit.content_data,
          content_type: commit.content_type,
          commit_message: commit.commit_message,
          author: author || commit.author,
          parent: new_head,
          branch: self,
          metadata: commit.metadata.merge({
            rebased_from: commit.version_hash,
            rebase_operation: true
          })
        )
        
        new_version.commit!(commit.commit_message, author || commit.author)
        new_head = new_version
      end
      
      update!(head_version: new_head)
      true
    end
  rescue => e
    Rails.logger.error "Rebase failed: #{e.message}"
    false
  end

  def delete_branch!(force: false)
    if protected? && !force
      raise ContentVersioningError, "Cannot delete protected branch"
    end
    
    if name == 'main' && !force
      raise ContentVersioningError, "Cannot delete main branch"
    end
    
    transaction do
      update!(status: :deleted, deleted_at: Time.current)
      
      # Optionally archive versions
      if force
        content_versions.update_all(status: :archived)
      end
    end
  end

  def restore_branch!
    if deleted?
      update!(status: :active, deleted_at: nil)
      content_versions.update_all(status: :committed)
    end
  end

  # Branch information and analysis
  def commit_count
    return 0 unless head_version
    head_version.branch_history.count
  end

  def commits_ahead_of(other_branch)
    return [] unless head_version && other_branch.head_version
    
    # Find commits in this branch that are not in the other branch
    my_commits = head_version.branch_history
    other_commits = other_branch.head_version.branch_history
    
    my_commits - other_commits
  end

  def commits_behind(other_branch)
    return [] unless head_version && other_branch.head_version
    
    other_branch.commits_ahead_of(self)
  end

  def divergence_info(other_branch)
    ahead = commits_ahead_of(other_branch)
    behind = commits_behind(other_branch)
    
    {
      ahead_count: ahead.count,
      behind_count: behind.count,
      ahead_commits: ahead,
      behind_commits: behind,
      is_up_to_date: ahead.empty? && behind.empty?,
      can_fast_forward: ahead.empty? && behind.any?,
      requires_merge: ahead.any? && behind.any?
    }
  end

  def last_activity
    head_version&.committed_at || created_at
  end

  def is_stale?(days = 30)
    last_activity < days.days.ago
  end

  def has_uncommitted_changes?
    return false unless head_version
    head_version.status == 'draft'
  end

  def protection_rules
    return {} unless protected?
    
    metadata['protection_rules'] || {
      'require_review' => true,
      'require_status_checks' => false,
      'restrict_pushes' => true,
      'allowed_users' => []
    }
  end

  def can_user_push?(user)
    return true unless protected?
    return true if author == user
    
    rules = protection_rules
    return false if rules['restrict_pushes']
    
    allowed_users = rules['allowed_users'] || []
    allowed_users.include?(user.id) || allowed_users.include?(user.email)
  end

  # Branch statistics and insights
  def activity_summary
    versions = content_versions.committed.includes(:author)
    
    {
      total_commits: versions.count,
      unique_authors: versions.distinct.count(:author_id),
      first_commit: versions.minimum(:committed_at),
      last_commit: versions.maximum(:committed_at),
      avg_commits_per_day: calculate_avg_commits_per_day(versions),
      most_active_author: find_most_active_author(versions)
    }
  end

  def content_evolution
    versions = head_version&.branch_history || []
    
    evolution = versions.reverse.map.with_index do |version, index|
      {
        version_number: version.version_number,
        hash: version.version_hash[0..7],
        commit_message: version.commit_message,
        author: version.author&.name,
        timestamp: version.committed_at,
        changes_from_previous: index > 0 ? version.content_changed_fields(versions[index - 1]).count : 0
      }
    end
    
    evolution
  end

  # Export and visualization
  def to_branch_info
    {
      name: name,
      type: branch_type,
      status: status,
      description: description,
      author: author&.name,
      created_at: created_at,
      last_activity: last_activity,
      commit_count: commit_count,
      head_commit: head_version&.content_summary,
      is_protected: protected?,
      is_stale: is_stale?
    }
  end

  def generate_branch_graph
    return [] unless head_version
    
    # Generate a simple text-based branch visualization
    commits = head_version.branch_history.reverse
    
    commits.map.with_index do |commit, index|
      {
        position: index,
        hash: commit.version_hash[0..7],
        message: commit.commit_message,
        author: commit.author&.name || 'Unknown',
        timestamp: commit.committed_at&.strftime('%Y-%m-%d %H:%M') || 'Draft',
        branch_line: index == 0 ? '●' : '│'
      }
    end
  end

  private

  def set_default_branch_type
    if name == 'main'
      self.branch_type = :main
    elsif name.start_with?('feature/')
      self.branch_type = :feature
    elsif name.start_with?('hotfix/')
      self.branch_type = :hotfix
    elsif name.start_with?('release/')
      self.branch_type = :release
    else
      self.branch_type = :feature
    end
  end

  def normalize_branch_name
    return unless name.present?
    
    # Remove leading/trailing whitespace and normalize
    self.name = name.strip.downcase
    
    # Replace spaces with hyphens
    self.name = self.name.gsub(/\s+/, '-')
    
    # Remove invalid characters
    self.name = self.name.gsub(/[^a-zA-Z0-9\-_\/]/, '')
  end

  def should_create_initial_version?
    source_version.nil? && name == 'main'
  end

  def create_initial_version
    initial_version = ContentVersion.create!(
      content_item: content_item,
      content_data: { content: 'Initial content' },
      content_type: 'marketing_content',
      commit_message: 'Initial commit',
      author: author,
      branch: self
    )
    
    initial_version.commit!('Initial commit', author)
    update!(head_version: initial_version)
  end

  def calculate_avg_commits_per_day(versions)
    return 0 if versions.empty?
    
    first_commit = versions.minimum(:committed_at)
    last_commit = versions.maximum(:committed_at)
    
    return 0 unless first_commit && last_commit
    
    days = ((last_commit - first_commit) / 1.day).ceil
    days = 1 if days == 0
    
    versions.count.to_f / days
  end

  def find_most_active_author(versions)
    author_counts = versions.group(:author_id).count
    return nil if author_counts.empty?
    
    most_active_author_id = author_counts.max_by { |_author_id, count| count }.first
    User.find_by(id: most_active_author_id)&.name
  end
end