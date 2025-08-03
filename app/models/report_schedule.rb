# frozen_string_literal: true

# ReportSchedule model for automated report generation and delivery
# Handles scheduling, email distribution, and automation
class ReportSchedule < ApplicationRecord
  belongs_to :custom_report
  belongs_to :user
  
  has_many :report_exports, dependent: :destroy
  
  validates :schedule_type, presence: true, inclusion: { 
    in: %w[manual daily weekly monthly quarterly yearly custom] 
  }
  validates :cron_expression, presence: true, if: -> { schedule_type == 'custom' }
  validates :export_formats, presence: true
  
  validate :valid_cron_expression, if: -> { schedule_type == 'custom' }
  validate :valid_export_formats
  validate :valid_email_recipients
  
  scope :active, -> { where(is_active: true) }
  scope :due_for_execution, -> { where('next_run_at <= ?', Time.current) }
  scope :by_schedule_type, ->(type) { where(schedule_type: type) }
  
  before_validation :set_defaults
  before_save :calculate_next_run_time
  
  # Execute this scheduled report
  def execute!
    return false unless ready_for_execution?
    
    start_time = Time.current
    
    begin
      # Generate exports for each format
      exports = export_formats.map do |format|
        ReportGenerationJob.perform_now(
          custom_report_id: custom_report.id,
          export_format: format,
          schedule_id: id,
          user_id: user.id
        )
      end
      
      # Send email if recipients are configured
      send_scheduled_report_email(exports) if should_send_email?
      
      # Update schedule tracking
      update!(
        last_run_at: start_time,
        last_success_at: Time.current,
        next_run_at: calculate_next_run_time_value,
        run_count: run_count + 1,
        last_error: nil
      )
      
      true
    rescue StandardError => e
      update!(
        last_run_at: start_time,
        last_error: e.message,
        next_run_at: calculate_next_run_time_value
      )
      false
    end
  end
  
  # Check if schedule is ready for execution
  def ready_for_execution?
    is_active? && (next_run_at && next_run_at <= Time.current)
  end
  
  # Get email recipient list
  def email_recipient_list
    recipients = []
    
    # Add direct email addresses
    if email_recipients.present?
      recipients.concat(email_recipients.split(/[,\n]/).map(&:strip).reject(&:blank?))
    end
    
    # Add distribution list emails
    distribution_lists.each do |list_id|
      list = ReportDistributionList.find_by(id: list_id)
      next unless list&.is_active?
      
      if list.email_addresses.present?
        recipients.concat(list.email_addresses.split(/[,\n]/).map(&:strip).reject(&:blank?))
      end
      
      # Add user emails from roles
      if list.auto_sync_roles? && list.roles.any?
        role_users = User.where(role: list.roles)
        recipients.concat(role_users.pluck(:email))
      end
      
      # Add specific user emails
      if list.user_ids.any?
        user_emails = User.where(id: list.user_ids).pluck(:email)
        recipients.concat(user_emails)
      end
    end
    
    recipients.uniq.reject(&:blank?)
  end
  
  # Preview next few execution times
  def preview_execution_times(count = 5)
    times = []
    current_time = next_run_at || Time.current
    
    count.times do
      times << current_time
      current_time = calculate_next_run_time_from(current_time)
    end
    
    times
  end
  
  # Get human-readable schedule description
  def schedule_description
    case schedule_type
    when 'daily'
      'Every day'
    when 'weekly'
      'Every week'
    when 'monthly'
      'Every month'
    when 'quarterly'
      'Every quarter'
    when 'yearly'
      'Every year'
    when 'custom'
      "Custom (#{cron_expression})"
    else
      'Manual'
    end
  end
  
  private
  
  def set_defaults
    self.export_formats ||= ['pdf']
    self.distribution_lists ||= []
    self.is_active = true if is_active.nil?
    self.run_count ||= 0
  end
  
  def calculate_next_run_time
    self.next_run_at = calculate_next_run_time_value if schedule_type != 'manual'
  end
  
  def calculate_next_run_time_value
    calculate_next_run_time_from(last_run_at || Time.current)
  end
  
  def calculate_next_run_time_from(from_time)
    case schedule_type
    when 'daily'
      from_time + 1.day
    when 'weekly'
      from_time + 1.week
    when 'monthly'
      from_time + 1.month
    when 'quarterly'
      from_time + 3.months
    when 'yearly'
      from_time + 1.year
    when 'custom'
      # Simple cron parsing - in production, use a proper cron parser
      parse_cron_expression(from_time)
    else
      nil
    end
  end
  
  def parse_cron_expression(from_time)
    # Simplified cron parsing for common patterns
    # In production, use the 'chronic' gem or similar
    case cron_expression
    when /^0 \d{1,2} \* \* \*$/ # Daily at specific hour
      hour = cron_expression.split[1].to_i
      from_time.beginning_of_day + hour.hours + 1.day
    when /^0 \d{1,2} \* \* [0-6]$/ # Weekly on specific day
      from_time + 1.week
    else
      from_time + 1.day # Default fallback
    end
  end
  
  def should_send_email?
    email_recipient_list.any?
  end
  
  def send_scheduled_report_email(exports)
    ReportMailer.scheduled_report(
      schedule: self,
      exports: exports,
      recipients: email_recipient_list
    ).deliver_now
  end
  
  def valid_cron_expression
    return unless cron_expression.present?
    
    # Basic cron validation - in production, use a proper cron validator
    parts = cron_expression.split
    unless parts.length == 5
      errors.add(:cron_expression, 'must have 5 parts (minute hour day month weekday)')
    end
  end
  
  def valid_export_formats
    return unless export_formats.present?
    
    valid_formats = %w[pdf excel csv powerpoint]
    invalid_formats = export_formats - valid_formats
    
    if invalid_formats.any?
      errors.add(:export_formats, "contains invalid formats: #{invalid_formats.join(', ')}")
    end
  end
  
  def valid_email_recipients
    return unless email_recipients.present?
    
    emails = email_recipients.split(/[,\n]/).map(&:strip).reject(&:blank?)
    invalid_emails = emails.reject { |email| email.match?(/\A[\w+\-.]+@[a-z\d\-]+(\.[a-z\d\-]+)*\.[a-z]+\z/i) }
    
    if invalid_emails.any?
      errors.add(:email_recipients, "contains invalid email addresses: #{invalid_emails.join(', ')}")
    end
  end
end
