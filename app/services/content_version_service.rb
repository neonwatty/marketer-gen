# frozen_string_literal: true

# Service for managing content versioning, comparison, and audit operations
class ContentVersionService < ApplicationService
  
  # Compare two content versions and return detailed differences
  def self.compare_versions(version1, version2)
    new(version1, version2).compare_versions
  end
  
  # Create a rollback version from a target version
  def self.rollback_content(current_content, target_version, user, reason = nil)
    new(current_content, target_version, user, reason).rollback_content
  end
  
  # Get comprehensive version history with analytics
  def self.version_analytics(content)
    new(content).version_analytics
  end
  
  # Cleanup old versions based on retention policy
  def self.cleanup_old_versions(retention_days = 90)
    new.cleanup_old_versions(retention_days)
  end
  
  # Get content diff with highlighting
  def self.content_diff(old_content, new_content)
    new.content_diff(old_content, new_content)
  end
  
  def initialize(content1 = nil, content2 = nil, user = nil, reason = nil)
    @content1 = content1
    @content2 = content2
    @user = user
    @reason = reason
  end
  
  def compare_versions
    
    return { success: false, error: "Both versions required for comparison" } unless @content1 && @content2
    
    begin
      comparison = @content1.compare_with_version(@content2)
      
      # Add detailed text diff for body content
      if comparison[:body_content][:changed]
        comparison[:body_content][:diff] = content_diff(
          comparison[:body_content][:old],
          comparison[:body_content][:new]
        )
      end
      
      # Add detailed text diff for title
      if comparison[:title][:changed]
        comparison[:title][:diff] = content_diff(
          comparison[:title][:old],
          comparison[:title][:new]
        )
      end
      
      # Add summary statistics
      comparison[:summary] = {
        total_fields_changed: comparison.count { |_, v| v.is_a?(Hash) && v[:changed] },
        version_gap: (@content1.version_number - @content2.version_number).abs,
        time_between_versions: (@content1.created_at - @content2.created_at).abs,
        significance: determine_change_significance(comparison)
      }
      
      { success: true, data: comparison }
    rescue => error
      { success: false, error: "Version comparison failed: #{error.message}" }
    end
  end
  
  def rollback_content
    
    return { success: false, error: "Current content, target version, and user required" } unless @content1 && @content2 && @user
    return { success: false, error: "Cannot rollback to same or newer version" } if @content2.version_number >= @content1.version_number
    
    begin
      rollback_version = @content1.rollback_to_version!(@content2, @user, @reason)
      
      { success: true, data: {
        rollback_version: rollback_version,
        message: "Successfully rolled back to version #{@content2.version_number}",
        changes: rollback_version.compare_with_version(@content1)
      } }
    rescue => error
      { success: false, error: "Rollback failed: #{error.message}" }
    end
  end
  
  def version_analytics
    
    return { success: false, error: "Content required for analytics" } unless @content1
    
    begin
      history = @content1.version_history_chain
      audit_logs = @content1.audit_logs.recent.limit(50)
      version_logs = @content1.version_logs.recent.limit(50)
      
      analytics = {
        total_versions: history.length,
        version_timeline: history.map do |version|
          {
            version_number: version.version_number,
            created_at: version.created_at,
            creator: version.created_by.full_name,
            status: version.status,
            word_count: version.word_count,
            changes_summary: version.metadata&.dig('change_summary')
          }
        end,
        version_activity: {
          total_actions: audit_logs.count,
          unique_contributors: audit_logs.distinct.count(:user_id),
          most_active_user: audit_logs.group(:user_id).count.max_by { |_, count| count }&.first,
          action_distribution: audit_logs.group(:action).count,
          recent_activity: audit_logs.limit(10).map do |log|
            {
              action: log.action_description,
              user: log.user.full_name,
              timestamp: log.created_at,
              changes: log.changes_summary
            }
          end
        },
        content_evolution: analyze_content_evolution(history),
        approval_workflow: analyze_approval_workflow(history, audit_logs)
      }
      
      { success: true, data: analytics }
    rescue => error
      { success: false, error: "Analytics generation failed: #{error.message}" }
    end
  end
  
  def cleanup_old_versions(retention_days)
    
    begin
      cutoff_date = retention_days.days.ago
      
      # Find versions older than retention period, excluding:
      # - Original versions (original_content_id is nil)
      # - Latest versions of each content
      # - Published versions
      # - Versions with significant status changes
      
      old_versions = GeneratedContent.joins(:audit_logs)
                                   .where('generated_contents.created_at < ?', cutoff_date)
                                   .where.not(original_content_id: nil)
                                   .where.not(status: 'published')
                                   .where.not(id: GeneratedContent.group(:original_content_id).maximum(:id).values)
      
      cleanup_stats = {
        total_found: old_versions.count,
        cleaned_up: 0,
        preserved: 0,
        errors: []
      }
      
      old_versions.find_each do |version|
        begin
          # Check if this version has significant changes or approvals
          if has_significant_history?(version)
            cleanup_stats[:preserved] += 1
          else
            version.audit_logs.destroy_all
            version.version_logs.destroy_all
            version.destroy
            cleanup_stats[:cleaned_up] += 1
          end
        rescue => error
          cleanup_stats[:errors] << { version_id: version.id, error: error.message }
        end
      end
      
      { success: true, data: cleanup_stats }
    rescue => error
      { success: false, error: "Cleanup failed: #{error.message}" }
    end
  end
  
  def content_diff(old_text, new_text)
    return nil unless old_text && new_text
    
    # Simple word-based diff
    old_words = old_text.split(/\s+/)
    new_words = new_text.split(/\s+/)
    
    # Calculate differences using a simple approach
    {
      old_length: old_words.length,
      new_length: new_words.length,
      added_words: new_words - old_words,
      removed_words: old_words - new_words,
      common_words: old_words & new_words,
      similarity_percentage: calculate_similarity_percentage(old_text, new_text)
    }
  end
  
  private
  
  def determine_change_significance(comparison)
    significant_changes = 0
    significant_changes += 1 if comparison[:title][:changed]
    significant_changes += 1 if comparison[:body_content][:changed]
    significant_changes += 1 if comparison[:content_type][:changed]
    significant_changes += 1 if comparison[:status][:changed]
    
    case significant_changes
    when 0
      'none'
    when 1
      'minor'
    when 2..3
      'moderate'
    else
      'major'
    end
  end
  
  def analyze_content_evolution(history)
    return {} if history.length < 2
    
    evolution = {
      word_count_trend: [],
      status_progression: [],
      format_changes: [],
      approval_timeline: []
    }
    
    history.each_with_index do |version, index|
      evolution[:word_count_trend] << {
        version: version.version_number,
        word_count: version.word_count,
        change: index > 0 ? version.word_count - history[index-1].word_count : 0
      }
      
      evolution[:status_progression] << {
        version: version.version_number,
        status: version.status,
        timestamp: version.created_at
      }
      
      if index > 0 && version.format_variant != history[index-1].format_variant
        evolution[:format_changes] << {
          version: version.version_number,
          from: history[index-1].format_variant,
          to: version.format_variant,
          timestamp: version.created_at
        }
      end
      
      if version.approved?
        evolution[:approval_timeline] << {
          version: version.version_number,
          approved_by: version.approver&.full_name,
          approved_at: version.metadata&.dig('approved_at')
        }
      end
    end
    
    evolution
  end
  
  def analyze_approval_workflow(history, audit_logs)
    approvals = audit_logs.where(action: 'approve')
    rejections = audit_logs.where(action: 'update').where("metadata ->> 'rejection_reason' IS NOT NULL")
    
    {
      total_approvals: approvals.count,
      total_rejections: rejections.count,
      approval_rate: history.count { |v| v.approved? }.to_f / history.length,
      average_approval_time: calculate_average_approval_time(history),
      workflow_efficiency: calculate_workflow_efficiency(history, audit_logs),
      approvers: approvals.joins(:user).distinct.pluck('users.email_address'),
      rejection_reasons: rejections.pluck(Arel.sql("metadata ->> 'rejection_reason'")).compact
    }
  end
  
  def calculate_average_approval_time(history)
    approved_versions = history.select(&:approved?)
    return 0 if approved_versions.empty?
    
    total_time = approved_versions.sum do |version|
      created_at = version.created_at
      approved_at = version.metadata&.dig('approved_at')
      approved_at && created_at ? Time.parse(approved_at.to_s) - created_at : 0
    end
    
    total_time / approved_versions.length
  end
  
  def calculate_workflow_efficiency(history, audit_logs)
    # Calculate efficiency based on time from creation to approval
    workflow_events = audit_logs.where(action: %w[create approve update])
    
    return 0 if workflow_events.empty?
    
    efficiency_score = 0
    workflow_events.group_by(&:generated_content_id).each do |_, events|
      creation = events.find { |e| e.action == 'create' }
      approval = events.find { |e| e.action == 'approve' }
      
      if creation && approval
        time_to_approval = approval.created_at - creation.created_at
        # Shorter time = higher efficiency (inverse relationship)
        efficiency_score += 1.0 / (time_to_approval / 1.day + 1)
      end
    end
    
    efficiency_score / workflow_events.group_by(&:generated_content_id).count
  end
  
  def calculate_similarity_percentage(text1, text2)
    return 100.0 if text1 == text2
    return 0.0 if text1.blank? || text2.blank?
    
    # Simple character-based similarity
    longer = [text1.length, text2.length].max
    shorter = [text1.length, text2.length].min
    
    return 0.0 if longer == 0
    
    ((shorter.to_f / longer) * 100).round(2)
  end
  
  def has_significant_history?(version)
    # Preserve versions that have been approved, published, or have significant audit events
    return true if version.approved? || version.published?
    
    significant_actions = %w[approve publish rollback]
    version.audit_logs.where(action: significant_actions).exists?
  end
end