# ContentVersion model - Git-like versioning system for content
# Tracks content changes over time with branching, merging, and commit history
class ContentVersion < ApplicationRecord
  belongs_to :content_item, polymorphic: true, optional: true
  belongs_to :parent, class_name: 'ContentVersion', optional: true
  # Author tracking - can be extended when User model is added
  # belongs_to :author, class_name: 'User', optional: true
  belongs_to :branch, class_name: 'ContentBranch', optional: true

  has_many :children, class_name: 'ContentVersion', foreign_key: 'parent_id', dependent: :destroy
  has_many :merge_commits, class_name: 'ContentMerge', foreign_key: 'target_version_id', dependent: :destroy
  has_many :source_merges, class_name: 'ContentMerge', foreign_key: 'source_version_id', dependent: :destroy

  # Content fields
  validates :content_data, presence: true
  validates :commit_message, presence: true, length: { minimum: 3, maximum: 500 }
  validates :version_hash, presence: true, uniqueness: true
  validates :content_type, presence: true

  # Version tracking
  before_validation :generate_version_hash, on: :create
  before_validation :set_version_number, on: :create
  before_create :validate_parent_branch_consistency

  scope :on_branch, ->(branch_name) { joins(:branch).where(content_branches: { name: branch_name }) }
  scope :by_author, ->(author) { where(author: author) }
  scope :chronological, -> { order(:created_at) }
  scope :reverse_chronological, -> { order(created_at: :desc) }
  scope :heads, -> { where.not(id: ContentVersion.select(:parent_id).where.not(parent_id: nil)) }

  # Content types supported
  CONTENT_TYPES = %w[
    marketing_content
    social_media_post 
    email_campaign
    ad_copy
    blog_post
    landing_page
    video_script
  ].freeze

  validates :content_type, inclusion: { in: CONTENT_TYPES }

  # Version states
  enum :status, {
    draft: 0,
    committed: 1,
    merged: 2,
    archived: 3,
    conflicted: 4
  }

  # Serialized content data
  serialize :content_data, coder: JSON
  serialize :metadata, coder: JSON

  def initialize(attributes = {})
    super(attributes)
    self.metadata ||= {}
    self.content_data ||= {}
  end

  # Git-like operations
  def commit!(message, author = nil)
    transaction do
      self.commit_message = message
      self.author = author if author
      self.committed_at = Time.current
      self.status = :committed
      save!
      
      # Update branch head if this is on a branch
      if branch&.head_version != self
        branch.update!(head_version: self)
      end
    end
    self
  end

  def create_branch(branch_name, author = nil)
    ContentBranch.create!(
      name: branch_name,
      source_version: self,
      head_version: self,
      author: author || self.author,
      content_item: content_item
    )
  end

  def merge_into(target_branch, author = nil, strategy: :auto)
    target_version = target_branch.head_version
    
    # Check if merge is necessary
    if target_version == self
      return ContentMergeResult.new(status: :up_to_date, target_version: target_version)
    end
    
    if is_ancestor_of?(target_version)
      # Fast-forward merge possible
      return fast_forward_merge(target_branch, author)
    end
    
    # Three-way merge required
    three_way_merge(target_version, author, strategy)
  end

  def rollback_to!
    transaction do
      # Create new version that reverts to this content
      new_version = self.class.create!(
        content_item: content_item,
        content_data: content_data.deep_dup,
        content_type: content_type,
        commit_message: "Rollback to version #{version_number}",
        author: author,
        parent: branch&.head_version,
        branch: branch,
        metadata: metadata.merge({
          rollback_to: version_hash,
          rollback_from: branch&.head_version&.version_hash
        })
      )
      
      new_version.commit!("Rollback to #{version_hash[0..7]}")
      new_version
    end
  end

  def diff_with(other_version)
    ContentDiff.new(self, other_version).generate
  end

  def get_content_field(field_name)
    content_data[field_name.to_s]
  end

  def set_content_field(field_name, value)
    self.content_data = content_data.merge(field_name.to_s => value)
  end

  def content_summary
    {
      version: version_number,
      hash: version_hash[0..7],
      message: commit_message,
      author: author_id ? "User #{author_id}" : 'System',
      timestamp: committed_at || created_at,
      branch: branch&.name || 'detached',
      status: status
    }
  end

  # History and ancestry
  def ancestors
    ancestors_list = []
    current = self.parent
    
    while current
      ancestors_list << current
      current = current.parent
    end
    
    ancestors_list
  end

  def descendants
    descendants_list = []
    queue = children.to_a
    
    while queue.any?
      current = queue.shift
      descendants_list << current
      queue.concat(current.children.to_a)
    end
    
    descendants_list
  end

  def is_ancestor_of?(other_version)
    other_version.ancestors.include?(self)
  end

  def common_ancestor_with(other_version)
    my_ancestors = [self] + ancestors
    other_ancestors = [other_version] + other_version.ancestors
    
    my_ancestors.find { |ancestor| other_ancestors.include?(ancestor) }
  end

  def branch_history
    history = []
    current = self
    
    while current
      history << current
      current = current.parent
    end
    
    history
  end

  # Content comparison
  def has_changes_from?(other_version)
    return true unless other_version
    content_data != other_version.content_data
  end

  def content_changed_fields(other_version)
    return content_data.keys if other_version.nil?
    
    changed_fields = []
    
    content_data.each do |key, value|
      if other_version.content_data[key] != value
        changed_fields << key
      end
    end
    
    # Check for removed fields
    other_version.content_data.each do |key, _value|
      unless content_data.key?(key)
        changed_fields << key
      end
    end
    
    changed_fields.uniq
  end

  # Content validation
  def validate_content_integrity
    errors = []
    
    # Basic structure validation
    unless content_data.is_a?(Hash)
      errors << "Content data must be a hash"
    end
    
    # Content type specific validation
    case content_type
    when 'marketing_content', 'social_media_post'
      errors << "Missing content text" unless content_data['content']&.present?
    when 'email_campaign'
      errors << "Missing subject line" unless content_data['subject']&.present?
      errors << "Missing email body" unless content_data['body']&.present?
    when 'ad_copy'
      errors << "Missing headline" unless content_data['headline']&.present?
      errors << "Missing description" unless content_data['description']&.present?
    end
    
    errors
  end

  # Export and serialization
  def to_content_hash
    {
      version: version_number,
      hash: version_hash,
      content: content_data,
      metadata: {
        commit_message: commit_message,
        author: author&.name,
        committed_at: committed_at,
        branch: branch&.name,
        parent_hash: parent&.version_hash,
        status: status
      }
    }
  end

  def self.from_content_hash(hash_data, content_item = nil)
    new(
      content_item: content_item,
      content_data: hash_data[:content] || {},
      content_type: hash_data[:content_type] || 'marketing_content',
      commit_message: hash_data.dig(:metadata, :commit_message) || 'Imported content',
      metadata: hash_data[:metadata] || {}
    )
  end

  private

  def generate_version_hash
    return if version_hash.present?
    
    # Create deterministic hash based on content and metadata
    hash_input = {
      content: content_data,
      parent_hash: parent&.version_hash,
      timestamp: Time.current.to_f,
      content_type: content_type
    }.to_json
    
    self.version_hash = Digest::SHA256.hexdigest(hash_input)
  end

  def set_version_number
    return if version_number.present?
    
    if parent
      self.version_number = parent.version_number + 1
    else
      # Find the highest version number for this content item
      max_version = self.class.where(content_item: content_item).maximum(:version_number) || 0
      self.version_number = max_version + 1
    end
  end

  def validate_parent_branch_consistency
    return unless parent && branch
    
    # Ensure parent is on the same branch or verify valid branching
    if parent.branch && parent.branch != branch
      # This is a cross-branch operation, validate it's intentional
      unless metadata['cross_branch_operation']
        errors.add(:parent, "Parent version is on different branch: #{parent.branch.name}")
        throw :abort
      end
    end
  end

  def fast_forward_merge(target_branch, author)
    # Move the target branch head to this version
    target_branch.update!(head_version: self)
    
    ContentMergeResult.new(
      status: :fast_forward,
      target_version: self,
      merge_commit: nil
    )
  end

  def three_way_merge(target_version, author, strategy)
    base_version = common_ancestor_with(target_version)
    
    unless base_version
      return ContentMergeResult.new(
        status: :no_common_ancestor,
        conflicts: ["No common ancestor found between versions"]
      )
    end
    
    # Perform three-way merge
    merge_result = ContentMerger.new(base_version, self, target_version, strategy).merge
    
    if merge_result.has_conflicts?
      # Create conflicted version
      conflicted_version = create_conflicted_version(target_version, merge_result, author)
      
      ContentMergeResult.new(
        status: :conflicted,
        target_version: conflicted_version,
        conflicts: merge_result.conflicts
      )
    else
      # Create successful merge commit
      merge_commit = create_merge_commit(target_version, merge_result, author)
      
      ContentMergeResult.new(
        status: :merged,
        target_version: merge_commit,
        merge_commit: merge_commit
      )
    end
  end

  def create_conflicted_version(target_version, merge_result, author)
    self.class.create!(
      content_item: content_item,
      content_data: merge_result.merged_content,
      content_type: content_type,
      commit_message: "Merge conflict: #{branch&.name} -> #{target_version.branch&.name}",
      author: author,
      parent: target_version,
      branch: target_version.branch,
      status: :conflicted,
      metadata: {
        merge_source: version_hash,
        merge_target: target_version.version_hash,
        conflicts: merge_result.conflicts
      }
    )
  end

  def create_merge_commit(target_version, merge_result, author)
    merge_commit = self.class.create!(
      content_item: content_item,
      content_data: merge_result.merged_content,
      content_type: content_type,
      commit_message: "Merge #{branch&.name} into #{target_version.branch&.name}",
      author: author,
      parent: target_version,
      branch: target_version.branch,
      status: :merged,
      metadata: {
        merge_source: version_hash,
        merge_target: target_version.version_hash,
        merge_strategy: merge_result.strategy
      }
    )
    
    # Update branch head
    target_version.branch&.update!(head_version: merge_commit)
    
    # Record merge in ContentMerge table
    ContentMerge.create!(
      source_version: self,
      target_version: merge_commit,
      merge_strategy: merge_result.strategy,
      author: author
    )
    
    merge_commit
  end
end