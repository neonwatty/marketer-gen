# ContentMerge model - Records merge operations between content versions
# Tracks merge history, conflicts, and resolution strategies
class ContentMerge < ApplicationRecord
  belongs_to :source_version, class_name: 'ContentVersion'
  belongs_to :target_version, class_name: 'ContentVersion'
  belongs_to :source_branch, class_name: 'ContentBranch', optional: true
  belongs_to :target_branch, class_name: 'ContentBranch', optional: true
  # Author tracking - can be extended when User model is added
  # belongs_to :author, class_name: 'User', optional: true

  validates :merge_strategy, presence: true
  validates :source_version, presence: true
  validates :target_version, presence: true

  # Merge strategies
  enum :merge_strategy, {
    auto: 0,          # Automatic merge when no conflicts
    manual: 1,        # Manual conflict resolution
    ours: 2,          # Keep our version on conflicts
    theirs: 3,        # Keep their version on conflicts
    union: 4,         # Combine both versions
    three_way: 5      # Three-way merge with base
  }

  # Merge status
  enum :status, {
    pending: 0,
    completed: 1,
    failed: 2,
    conflicted: 3,
    aborted: 4
  }

  serialize :conflicts_data, coder: JSON
  serialize :resolution_data, coder: JSON
  serialize :merge_metadata, coder: JSON

  scope :successful, -> { where(status: :completed) }
  scope :by_author, ->(author) { where(author: author) }
  scope :recent, -> { order(created_at: :desc) }

  def initialize(attributes = {})
    super(attributes)
    self.conflicts_data ||= []
    self.resolution_data ||= {}
    self.merge_metadata ||= {}
  end

  # Merge execution
  def execute_merge!
    transaction do
      merger = ContentMerger.new(
        find_base_version,
        source_version,
        target_version,
        merge_strategy
      )
      
      result = merger.merge
      
      if result.has_conflicts?
        self.status = :conflicted
        self.conflicts_data = result.conflicts
        self.conflict_count = result.conflicts.size
        
        # Create conflicted version for manual resolution
        conflicted_version = create_conflicted_version(result)
        self.target_version = conflicted_version
      else
        self.status = :completed
        self.resolution_data = result.resolution_steps
        self.merge_metadata = result.metadata
        
        # Update target version with merged content
        update_target_with_merged_content(result)
      end
      
      self.completed_at = Time.current
      save!
      
      self
    end
  rescue => e
    self.status = :failed
    self.merge_metadata = { error: e.message, backtrace: e.backtrace.first(10) }
    save!
    raise e
  end

  def resolve_conflicts!(resolution_map, author = nil)
    unless conflicted?
      raise ContentVersioningError, "Merge is not in conflicted state"
    end
    
    transaction do
      # Apply manual conflict resolutions
      resolved_content = apply_conflict_resolutions(resolution_map)
      
      # Create new version with resolved content
      resolved_version = ContentVersion.create!(
        content_item: target_version.content_item,
        content_data: resolved_content,
        content_type: target_version.content_type,
        commit_message: "Resolve merge conflicts: #{source_version.branch&.name} -> #{target_version.branch&.name}",
        author: author || self.author,
        parent: target_version,
        branch: target_version.branch,
        metadata: {
          merge_resolution: true,
          source_merge: id,
          resolved_conflicts: resolution_map.keys
        }
      )
      
      resolved_version.commit!("Merge conflict resolution", author)
      
      # Update this merge record
      self.target_version = resolved_version
      self.status = :completed
      self.resolution_data = resolution_map
      self.completed_at = Time.current
      save!
      
      # Update branch head
      target_version.branch&.update!(head_version: resolved_version)
      
      resolved_version
    end
  end

  def abort_merge!
    transaction do
      self.status = :aborted
      self.completed_at = Time.current
      save!
      
      # Clean up any conflicted versions
      if conflicted? && target_version&.status == 'conflicted'
        target_version.destroy
      end
    end
  end

  # Analysis and reporting
  def merge_summary
    {
      id: id,
      source: {
        version: source_version.version_number,
        hash: source_version.version_hash[0..7],
        branch: source_branch&.name || source_version.branch&.name
      },
      target: {
        version: target_version.version_number,
        hash: target_version.version_hash[0..7],
        branch: target_branch&.name || target_version.branch&.name
      },
      strategy: merge_strategy,
      status: status,
      conflicts: conflict_count || 0,
      author: author&.name,
      created_at: created_at,
      completed_at: completed_at
    }
  end

  def conflict_summary
    return [] unless conflicted? && conflicts_data.present?
    
    conflicts_data.map do |conflict|
      {
        field: conflict['field'],
        type: conflict['type'],
        description: conflict['description'],
        source_value: conflict['source_value'],
        target_value: conflict['target_value'],
        suggested_resolution: conflict['suggested_resolution']
      }
    end
  end

  def resolution_summary
    return {} unless completed? && resolution_data.present?
    
    {
      strategy_used: merge_strategy,
      fields_merged: resolution_data.keys,
      resolution_details: resolution_data,
      merge_statistics: calculate_merge_statistics
    }
  end

  # Validation and checks
  def can_auto_merge?
    merger = ContentMerger.new(
      find_base_version,
      source_version,
      target_version,
      :auto
    )
    
    !merger.has_conflicts?
  end

  def preview_merge
    merger = ContentMerger.new(
      find_base_version,
      source_version,
      target_version,
      merge_strategy
    )
    
    merger.preview
  end

  def validate_merge_feasibility
    errors = []
    
    # Check if versions are compatible
    if source_version.content_type != target_version.content_type
      errors << "Content types don't match: #{source_version.content_type} vs #{target_version.content_type}"
    end
    
    # Check if merge would create cycles
    if source_version.is_ancestor_of?(target_version)
      errors << "Cannot merge ancestor into descendant"
    end
    
    # Check branch permissions
    if target_branch&.protected? && !target_branch.can_user_push?(author)
      errors << "No permission to merge into protected branch: #{target_branch.name}"
    end
    
    errors
  end

  private

  def find_base_version
    source_version.common_ancestor_with(target_version)
  end

  def create_conflicted_version(merge_result)
    ContentVersion.create!(
      content_item: target_version.content_item,
      content_data: merge_result.partial_merged_content,
      content_type: target_version.content_type,
      commit_message: "Merge conflict: #{source_version.branch&.name} -> #{target_version.branch&.name}",
      author: author,
      parent: target_version,
      branch: target_version.branch,
      status: :conflicted,
      metadata: {
        merge_conflict: true,
        source_version: source_version.version_hash,
        conflict_markers: merge_result.conflict_markers
      }
    )
  end

  def update_target_with_merged_content(merge_result)
    target_version.update!(
      content_data: merge_result.merged_content,
      metadata: target_version.metadata.merge({
        merged_from: source_version.version_hash,
        merge_strategy: merge_strategy,
        merge_timestamp: Time.current.iso8601
      })
    )
  end

  def apply_conflict_resolutions(resolution_map)
    resolved_content = target_version.content_data.deep_dup
    
    resolution_map.each do |field, resolution|
      case resolution['strategy']
      when 'ours'
        resolved_content[field] = target_version.content_data[field]
      when 'theirs'
        resolved_content[field] = source_version.content_data[field]
      when 'manual'
        resolved_content[field] = resolution['value']
      when 'union'
        # Combine both values intelligently
        resolved_content[field] = combine_field_values(
          target_version.content_data[field],
          source_version.content_data[field],
          field
        )
      end
    end
    
    resolved_content
  end

  def combine_field_values(target_value, source_value, field)
    # Intelligent combination based on field type
    if target_value.is_a?(String) && source_value.is_a?(String)
      # For text fields, combine with clear separation
      "#{target_value}\n\n#{source_value}"
    elsif target_value.is_a?(Array) && source_value.is_a?(Array)
      # For arrays, merge and deduplicate
      (target_value + source_value).uniq
    elsif target_value.is_a?(Hash) && source_value.is_a?(Hash)
      # For hashes, deep merge
      target_value.deep_merge(source_value)
    else
      # Default to target value
      target_value
    end
  end

  def calculate_merge_statistics
    return {} unless completed?
    
    stats = {
      fields_changed: 0,
      lines_added: 0,
      lines_removed: 0,
      conflicts_resolved: conflict_count || 0
    }
    
    # Calculate field changes
    source_content = source_version.content_data
    target_content = target_version.content_data
    
    all_fields = (source_content.keys + target_content.keys).uniq
    
    all_fields.each do |field|
      if source_content[field] != target_content[field]
        stats[:fields_changed] += 1
        
        # Estimate line changes for text fields
        if source_content[field].is_a?(String) && target_content[field].is_a?(String)
          source_lines = source_content[field].lines.count
          target_lines = target_content[field].lines.count
          
          if target_lines > source_lines
            stats[:lines_added] += (target_lines - source_lines)
          else
            stats[:lines_removed] += (source_lines - target_lines)
          end
        end
      end
    end
    
    stats
  end
end