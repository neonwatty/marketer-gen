# ContentMerger service - Handles three-way merging of content versions
# Implements Git-like merge algorithms with conflict detection and resolution
class ContentMerger
  include ActiveModel::Model

  attr_reader :base_version, :source_version, :target_version, :strategy
  attr_accessor :merged_content, :conflicts, :resolution_steps, :metadata

  # Merge conflict types
  CONFLICT_TYPES = {
    content: 'Content modification conflict',
    addition: 'Addition conflict',
    deletion: 'Deletion conflict',
    type: 'Type change conflict',
    structure: 'Structure conflict'
  }.freeze

  def initialize(base_version, source_version, target_version, strategy = :auto)
    @base_version = base_version
    @source_version = source_version
    @target_version = target_version
    @strategy = strategy.to_sym
    @conflicts = []
    @resolution_steps = {}
    @metadata = {}
    @merged_content = {}
  end

  def merge
    case strategy
    when :auto
      auto_merge
    when :ours
      ours_strategy
    when :theirs
      theirs_strategy
    when :union
      union_strategy
    when :three_way
      three_way_merge
    else
      auto_merge
    end
    
    ContentMergeResult.new(
      merged_content: merged_content,
      conflicts: conflicts,
      resolution_steps: resolution_steps,
      metadata: metadata,
      strategy: strategy
    )
  end

  def preview
    # Non-destructive preview of merge result
    original_conflicts = @conflicts.dup
    original_merged = @merged_content.dup
    
    result = merge
    
    # Restore original state
    @conflicts = original_conflicts
    @merged_content = original_merged
    
    result
  end

  def has_conflicts?
    return @conflicts.any? if @conflicts.any?
    
    # Quick conflict detection without full merge
    detect_conflicts_only
    @conflicts.any?
  end

  private

  def auto_merge
    three_way_merge
    
    # If conflicts exist, try to auto-resolve simple ones
    if conflicts.any?
      auto_resolve_simple_conflicts
    end
  end

  def three_way_merge
    @merged_content = target_version.content_data.deep_dup
    
    return unless base_version # Handle case where no common ancestor
    
    base_content = base_version.content_data
    source_content = source_version.content_data
    target_content = target_version.content_data
    
    # Get all fields that exist in any version
    all_fields = [base_content, source_content, target_content].flat_map(&:keys).uniq
    
    all_fields.each do |field|
      merge_field(field, base_content, source_content, target_content)
    end
    
    @metadata[:merge_type] = 'three_way'
    @metadata[:base_version] = base_version&.version_hash
  end

  def merge_field(field, base_content, source_content, target_content)
    base_value = base_content[field]
    source_value = source_content[field]
    target_value = target_content[field]
    
    # Determine what changed
    source_changed = source_value != base_value
    target_changed = target_value != base_value
    
    if !source_changed && !target_changed
      # No changes, keep target value
      @merged_content[field] = target_value
      @resolution_steps[field] = { action: :no_change, reason: 'No modifications' }
      
    elsif source_changed && !target_changed
      # Only source changed, use source value
      @merged_content[field] = source_value
      @resolution_steps[field] = { action: :use_source, reason: 'Only source modified' }
      
    elsif !source_changed && target_changed
      # Only target changed, keep target value
      @merged_content[field] = target_value
      @resolution_steps[field] = { action: :use_target, reason: 'Only target modified' }
      
    elsif source_value == target_value
      # Both changed to same value, no conflict
      @merged_content[field] = source_value
      @resolution_steps[field] = { action: :both_same, reason: 'Both changed to same value' }
      
    else
      # Both changed to different values - conflict!
      handle_field_conflict(field, base_value, source_value, target_value)
    end
  end

  def handle_field_conflict(field, base_value, source_value, target_value)
    conflict = {
      field: field,
      type: determine_conflict_type(base_value, source_value, target_value),
      description: build_conflict_description(field, base_value, source_value, target_value),
      base_value: base_value,
      source_value: source_value,
      target_value: target_value,
      suggested_resolution: suggest_resolution(field, base_value, source_value, target_value)
    }
    
    @conflicts << conflict
    
    # For now, use target value as placeholder in merged content
    # This will be replaced when conflicts are resolved
    @merged_content[field] = create_conflict_marker(field, source_value, target_value)
    @resolution_steps[field] = { action: :conflict, conflict_id: @conflicts.size - 1 }
  end

  def determine_conflict_type(base_value, source_value, target_value)
    if base_value.nil?
      :addition
    elsif source_value.nil? || target_value.nil?
      :deletion
    elsif base_value.class != source_value.class || base_value.class != target_value.class
      :type
    elsif base_value.is_a?(Hash) || source_value.is_a?(Hash) || target_value.is_a?(Hash)
      :structure
    else
      :content
    end
  end

  def build_conflict_description(field, base_value, source_value, target_value)
    case determine_conflict_type(base_value, source_value, target_value)
    when :addition
      "Both versions added content to field '#{field}'"
    when :deletion
      "One version deleted field '#{field}' while the other modified it"
    when :type
      "Field '#{field}' type changed differently in both versions"
    when :structure
      "Structural changes conflict in field '#{field}'"
    else
      "Content modified differently in field '#{field}'"
    end
  end

  def suggest_resolution(field, base_value, source_value, target_value)
    # Provide intelligent suggestions based on content analysis
    
    if field == 'content' || field == 'body' || field == 'description'
      # For main content fields, suggest manual review
      return { strategy: :manual, reason: 'Content requires manual review' }
    end
    
    if source_value.to_s.length > target_value.to_s.length
      # Suggest the longer version (assuming more complete)
      return { strategy: :theirs, reason: 'Source version is more comprehensive' }
    elsif target_value.to_s.length > source_value.to_s.length
      return { strategy: :ours, reason: 'Target version is more comprehensive' }
    end
    
    # Default to manual resolution
    { strategy: :manual, reason: 'Requires manual decision' }
  end

  def create_conflict_marker(field, source_value, target_value)
    "<<<<<<< HEAD (target)\n#{target_value}\n=======\n#{source_value}\n>>>>>>> source"
  end

  def auto_resolve_simple_conflicts
    auto_resolved = []
    
    @conflicts.each_with_index do |conflict, index|
      resolution = attempt_auto_resolution(conflict)
      
      if resolution
        field = conflict[:field]
        @merged_content[field] = resolution[:value]
        @resolution_steps[field] = {
          action: :auto_resolved,
          strategy: resolution[:strategy],
          reason: resolution[:reason]
        }
        auto_resolved << index
      end
    end
    
    # Remove auto-resolved conflicts
    auto_resolved.reverse.each { |index| @conflicts.delete_at(index) }
    
    @metadata[:auto_resolved_count] = auto_resolved.size
  end

  def attempt_auto_resolution(conflict)
    field = conflict[:field]
    source_value = conflict[:source_value]
    target_value = conflict[:target_value]
    
    # Auto-resolve empty additions
    if source_value.blank? && target_value.present?
      return { value: target_value, strategy: :target, reason: 'Source is empty' }
    elsif target_value.blank? && source_value.present?
      return { value: source_value, strategy: :source, reason: 'Target is empty' }
    end
    
    # Auto-resolve numeric conflicts by taking the larger value
    if field.match?(/count|number|quantity|amount/) && 
       source_value.is_a?(Numeric) && target_value.is_a?(Numeric)
      larger_value = [source_value, target_value].max
      strategy = larger_value == source_value ? :source : :target
      return { value: larger_value, strategy: strategy, reason: 'Using larger numeric value' }
    end
    
    # Auto-resolve array conflicts by merging
    if source_value.is_a?(Array) && target_value.is_a?(Array)
      merged_array = (source_value + target_value).uniq
      return { value: merged_array, strategy: :union, reason: 'Merged arrays and removed duplicates' }
    end
    
    nil # Cannot auto-resolve
  end

  def ours_strategy
    @merged_content = target_version.content_data.deep_dup
    @resolution_steps = {}
    
    target_version.content_data.each_key do |field|
      @resolution_steps[field] = { action: :use_ours, reason: 'Ours strategy selected' }
    end
    
    @metadata[:merge_type] = 'ours'
  end

  def theirs_strategy
    @merged_content = source_version.content_data.deep_dup
    @resolution_steps = {}
    
    source_version.content_data.each_key do |field|
      @resolution_steps[field] = { action: :use_theirs, reason: 'Theirs strategy selected' }
    end
    
    @metadata[:merge_type] = 'theirs'
  end

  def union_strategy
    @merged_content = target_version.content_data.deep_dup
    @resolution_steps = {}
    
    source_version.content_data.each do |field, source_value|
      target_value = target_version.content_data[field]
      
      if target_value.nil?
        @merged_content[field] = source_value
        @resolution_steps[field] = { action: :add_from_source, reason: 'Field only in source' }
      elsif source_value != target_value
        @merged_content[field] = union_merge_values(target_value, source_value)
        @resolution_steps[field] = { action: :union_merge, reason: 'Combined both values' }
      else
        @resolution_steps[field] = { action: :no_change, reason: 'Values identical' }
      end
    end
    
    @metadata[:merge_type] = 'union'
  end

  def union_merge_values(target_value, source_value)
    if target_value.is_a?(Array) && source_value.is_a?(Array)
      (target_value + source_value).uniq
    elsif target_value.is_a?(Hash) && source_value.is_a?(Hash)
      target_value.deep_merge(source_value)
    elsif target_value.is_a?(String) && source_value.is_a?(String)
      "#{target_value}\n\n#{source_value}"
    else
      [target_value, source_value].compact
    end
  end

  def detect_conflicts_only
    return unless base_version
    
    base_content = base_version.content_data
    source_content = source_version.content_data
    target_content = target_version.content_data
    
    all_fields = [base_content, source_content, target_content].flat_map(&:keys).uniq
    
    all_fields.each do |field|
      base_value = base_content[field]
      source_value = source_content[field]
      target_value = target_content[field]
      
      # Quick conflict check
      source_changed = source_value != base_value
      target_changed = target_value != base_value
      
      if source_changed && target_changed && source_value != target_value
        @conflicts << {
          field: field,
          type: :content,
          description: "Conflict in field '#{field}'"
        }
      end
    end
  end
end

# Result class for merge operations
class ContentMergeResult
  include ActiveModel::Model
  
  attr_accessor :merged_content, :conflicts, :resolution_steps, :metadata, :strategy
  
  def initialize(attributes = {})
    super(attributes)
    @conflicts ||= []
    @resolution_steps ||= {}
    @metadata ||= {}
  end
  
  def has_conflicts?
    conflicts.any?
  end
  
  def success?
    !has_conflicts?
  end
  
  def conflict_count
    conflicts.size
  end
  
  def partial_merged_content
    # Return content with conflict markers for manual resolution
    merged_content
  end
  
  def conflict_markers
    conflicts.map do |conflict|
      {
        field: conflict[:field],
        marker: "<<<<<<< HEAD\n#{conflict[:target_value]}\n=======\n#{conflict[:source_value]}\n>>>>>>> source"
      }
    end
  end
  
  def summary
    {
      success: success?,
      conflicts: conflict_count,
      strategy: strategy,
      fields_merged: resolution_steps.size,
      auto_resolved: metadata[:auto_resolved_count] || 0
    }
  end
end

# Custom error class for versioning operations
class ContentVersioningError < StandardError; end