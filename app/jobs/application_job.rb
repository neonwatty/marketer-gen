class ApplicationJob < ActiveJob::Base
  # Automatically retry jobs that encountered a deadlock
  retry_on ActiveRecord::Deadlocked, wait: 5.seconds, attempts: 3

  # Most jobs are safe to ignore if the underlying records are no longer available
  discard_on ActiveJob::DeserializationError
  
  # Retry on database connection issues
  retry_on ActiveRecord::ConnectionNotEstablished, wait: 10.seconds, attempts: 3
  
  # Global error tracking
  rescue_from StandardError do |error|
    Rails.logger.error "Job #{self.class.name} failed: #{error.message}"
    Rails.logger.error error.backtrace.join("\n")
    raise error
  end
end
