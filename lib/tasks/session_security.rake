namespace :session_security do
  desc "Clean up expired and suspicious sessions"
  task cleanup: :environment do
    puts "Starting session cleanup..."
    SessionCleanupJob.perform_now
    puts "Session cleanup completed."
  end
  
  desc "Show session statistics"
  task stats: :environment do
    total_sessions = Session.count
    active_sessions = Session.active.count
    expired_sessions = Session.expired.count
    suspicious_sessions = Session.suspicious_sessions.count
    
    puts "Session Statistics:"
    puts "  Total sessions: #{total_sessions}"
    puts "  Active sessions: #{active_sessions}"
    puts "  Expired sessions: #{expired_sessions}"
    puts "  Suspicious sessions: #{suspicious_sessions}"
    
    # User statistics
    users_with_sessions = User.joins(:sessions).distinct.count
    total_users = User.count
    
    puts "\nUser Statistics:"
    puts "  Total users: #{total_users}"
    puts "  Users with active sessions: #{users_with_sessions}"
    
    # Recent activity
    recent_sessions = Session.where('created_at > ?', 24.hours.ago).count
    puts "\nRecent Activity:"
    puts "  Sessions created in last 24 hours: #{recent_sessions}"
  end
  
  desc "Audit suspicious sessions"
  task audit: :environment do
    puts "Auditing suspicious sessions..."
    
    Session.suspicious_sessions.find_each do |session|
      puts "Suspicious session found:"
      puts "  ID: #{session.id}"
      puts "  User: #{session.user.email_address}"
      puts "  IP: #{session.ip_address}"
      puts "  User Agent: #{session.user_agent&.truncate(100)}"
      puts "  Created: #{session.created_at}"
      puts "  Updated: #{session.updated_at}"
      puts "  ---"
    end
    
    puts "Audit completed."
  end
  
  desc "Force cleanup of all expired sessions"
  task force_cleanup: :environment do
    puts "Force cleaning up all expired sessions..."
    
    expired_count = Session.expired.count
    Session.expired.destroy_all
    
    puts "Removed #{expired_count} expired sessions."
  end
  
  desc "Setup periodic cleanup (for production)"
  task setup_periodic: :environment do
    if Rails.env.production?
      puts "Setting up periodic session cleanup..."
      
      # Schedule cleanup job to run every hour
      # This would typically be done with a cron job or background job scheduler
      puts "Add this to your crontab or job scheduler:"
      puts "0 * * * * cd #{Rails.root} && bundle exec rails session_security:cleanup"
      
    else
      puts "Periodic cleanup is only recommended for production environment."
    end
  end
end