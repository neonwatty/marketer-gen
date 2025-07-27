class ActivityCleanupJob < ApplicationJob
  queue_as :low
  
  def perform
    # Get retention period from configuration
    retention_days = Rails.application.config.activity_tracking.retention_days || 90
    cutoff_date = retention_days.days.ago
    
    # Log the cleanup operation
    ActivityLogger.log(:info, "Starting activity cleanup", {
      retention_days: retention_days,
      cutoff_date: cutoff_date
    })
    
    # Delete old activities in batches to avoid locking the table
    total_deleted = 0
    
    loop do
      deleted_count = Activity
        .where("occurred_at < ?", cutoff_date)
        .where(suspicious: false) # Keep suspicious activities longer
        .limit(1000)
        .delete_all
      
      total_deleted += deleted_count
      
      break if deleted_count < 1000
      
      # Small delay to prevent database overload
      sleep 0.1
    end
    
    # Clean up old user activities (if using the separate model)
    if defined?(UserActivity)
      UserActivity.where("performed_at < ?", cutoff_date).delete_all
    end
    
    # Log completion
    ActivityLogger.log(:info, "Activity cleanup completed", {
      total_deleted: total_deleted,
      cutoff_date: cutoff_date
    })
    
    # Run database optimization
    optimize_database_tables
  end
  
  private
  
  def optimize_database_tables
    # Optimize the activities table after bulk deletion
    if ActiveRecord::Base.connection.adapter_name == 'PostgreSQL'
      ActiveRecord::Base.connection.execute('VACUUM ANALYZE activities')
    elsif ActiveRecord::Base.connection.adapter_name.include?('SQLite')
      ActiveRecord::Base.connection.execute('VACUUM')
    end
  rescue => e
    Rails.logger.error "Failed to optimize database: #{e.message}"
  end
end