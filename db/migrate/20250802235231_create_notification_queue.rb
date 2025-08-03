class CreateNotificationQueue < ActiveRecord::Migration[8.0]
  def change
    create_table :notification_queues do |t|
      t.references :alert_instance, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.string :channel, null: false # 'email', 'in_app', 'sms', 'slack', 'teams'
      t.string :status, null: false, default: 'pending' # 'pending', 'processing', 'sent', 'failed', 'cancelled'
      t.string :priority, null: false, default: 'medium' # 'critical', 'high', 'medium', 'low'
      
      # Message Content
      t.string :subject, null: false
      t.text :message, null: false
      t.json :template_data # Data for template rendering
      t.string :template_name
      
      # Channel-specific Data
      t.string :recipient_address # email address, phone number, etc.
      t.json :channel_config # Channel-specific configuration
      
      # Scheduling and Retry Logic
      t.datetime :scheduled_for, null: false
      t.datetime :sent_at
      t.integer :retry_count, default: 0
      t.integer :max_retries, default: 3
      t.datetime :next_retry_at
      t.json :retry_schedule # Custom retry schedule
      
      # Delivery Tracking
      t.string :external_id # ID from external service (Twilio, SendGrid, etc.)
      t.json :delivery_status # Status from external service
      t.text :failure_reason
      t.json :delivery_metadata
      
      # Aggregation and Batching
      t.string :batch_id # For batched notifications
      t.boolean :can_batch, default: true
      t.integer :batch_window_minutes, default: 5
      
      t.timestamps
    end
    
    add_index :notification_queues, [:status, :scheduled_for]
    add_index :notification_queues, [:priority, :scheduled_for]
    add_index :notification_queues, [:channel, :status]
    add_index :notification_queues, :batch_id
    add_index :notification_queues, [:next_retry_at, :status]
    add_index :notification_queues, :external_id
  end
end
