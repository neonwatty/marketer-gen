# frozen_string_literal: true

# Model for tracking data synchronization operations and maintaining sync state
class SyncRecord < ApplicationRecord
  belongs_to :platform_connection
  
  SYNC_TYPES = %w[full_sync delta_sync conflict_resolution manual_sync].freeze
  STATUSES = %w[pending in_progress completed failed conflict_detected].freeze
  DIRECTIONS = %w[inbound outbound bidirectional].freeze

  validates :sync_type, presence: true, inclusion: { in: SYNC_TYPES }
  validates :status, inclusion: { in: STATUSES }
  validates :direction, inclusion: { in: DIRECTIONS }
  validates :external_id, presence: true
  validates :entity_type, presence: true

  serialize :local_data, coder: JSON
  serialize :external_data, coder: JSON
  serialize :metadata, coder: JSON
  serialize :conflict_data, coder: JSON

  scope :pending, -> { where(status: 'pending') }
  scope :in_progress, -> { where(status: 'in_progress') }
  scope :completed, -> { where(status: 'completed') }
  scope :failed, -> { where(status: 'failed') }
  scope :with_conflicts, -> { where(status: 'conflict_detected') }
  scope :for_entity_type, ->(type) { where(entity_type: type) }
  scope :for_platform, ->(platform) { joins(:platform_connection).where(platform_connections: { platform: platform }) }
  scope :recent, -> { where('created_at > ?', 24.hours.ago) }

  before_create :set_defaults

  def platform
    platform_connection.platform
  end

  def pending?
    status == 'pending'
  end

  def in_progress?
    status == 'in_progress'
  end

  def completed?
    status == 'completed'
  end

  def failed?
    status == 'failed'
  end

  def has_conflict?
    status == 'conflict_detected'
  end

  def mark_in_progress!
    update!(
      status: 'in_progress',
      started_at: Time.current,
      metadata: (metadata || {}).merge(processing_started: Time.current)
    )
  end

  def mark_completed!(result_data = nil)
    update!(
      status: 'completed',
      completed_at: Time.current,
      metadata: (metadata || {}).merge(
        completed: Time.current,
        result: result_data
      )
    )
  end

  def mark_failed!(error_message, error_data = nil)
    update!(
      status: 'failed',
      error_message: error_message,
      completed_at: Time.current,
      metadata: (metadata || {}).merge(
        error: error_message,
        error_data: error_data,
        failed_at: Time.current
      )
    )
  end

  def mark_conflict!(conflict_details)
    update!(
      status: 'conflict_detected',
      conflict_data: conflict_details,
      metadata: (metadata || {}).merge(
        conflict_detected_at: Time.current,
        requires_manual_resolution: true
      )
    )
  end

  def sync_duration
    return nil unless started_at && completed_at
    completed_at - started_at
  end

  def data_changed?
    return false if local_data.blank? || external_data.blank?
    local_data != external_data
  end

  def conflict_resolution_required?
    has_conflict? && conflict_data.present?
  end

  def get_conflict_summary
    return nil unless conflict_resolution_required?
    
    {
      entity: "#{entity_type}##{external_id}",
      platform: platform,
      conflicts: conflict_data.dig('conflicts') || [],
      local_version: conflict_data.dig('local_version'),
      external_version: conflict_data.dig('external_version'),
      detected_at: conflict_data.dig('detected_at')
    }
  end

  def retry_sync!
    return false unless failed?
    
    update!(
      status: 'pending',
      error_message: nil,
      retry_count: (retry_count || 0) + 1,
      metadata: (metadata || {}).merge(
        retried_at: Time.current,
        previous_error: error_message
      )
    )
  end

  def can_retry?
    failed? && (retry_count || 0) < 3
  end

  def hash_data(data)
    return nil if data.blank?
    Digest::SHA256.hexdigest(data.to_json.to_s)
  end

  def data_fingerprint
    return nil unless local_data.present? || external_data.present?
    
    {
      local: hash_data(local_data),
      external: hash_data(external_data)
    }
  end

  private

  def set_defaults
    self.status ||= 'pending'
    self.direction ||= 'bidirectional'
    self.metadata ||= {}
    self.retry_count ||= 0
  end
end