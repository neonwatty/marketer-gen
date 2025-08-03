class CreateAlertInstances < ActiveRecord::Migration[8.0]
  def change
    create_table :alert_instances do |t|
      t.references :performance_alert, null: false, foreign_key: true
      t.string :status, null: false, default: 'active' # 'active', 'acknowledged', 'resolved', 'snoozed'
      t.string :severity, null: false # inherited from alert but can be escalated
      
      # Alert Context
      t.decimal :triggered_value, precision: 15, scale: 6
      t.decimal :threshold_value, precision: 15, scale: 6
      t.json :trigger_context # Additional context about what triggered the alert
      t.json :metric_data # Snapshot of metric data when alert triggered
      
      # Lifecycle Management
      t.datetime :triggered_at, null: false
      t.datetime :acknowledged_at
      t.datetime :resolved_at
      t.datetime :snoozed_until
      t.references :acknowledged_by, null: true, foreign_key: { to_table: :users }
      t.references :resolved_by, null: true, foreign_key: { to_table: :users }
      t.text :acknowledgment_note
      t.text :resolution_note
      
      # Notification Tracking
      t.json :notifications_sent # Track which notifications were sent and when
      t.json :notification_failures # Track any failed notifications
      t.boolean :escalated, default: false
      t.datetime :escalation_sent_at
      
      # Machine Learning Data
      t.decimal :anomaly_score, precision: 5, scale: 4 # 0.0 to 1.0
      t.json :ml_prediction_data
      t.boolean :false_positive, default: false # For ML training
      
      t.timestamps
    end
    
    add_index :alert_instances, [:status, :severity]
    add_index :alert_instances, :triggered_at
    add_index :alert_instances, [:snoozed_until, :status]
    add_index :alert_instances, [:escalated, :severity]
  end
end
