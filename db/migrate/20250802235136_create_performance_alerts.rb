class CreatePerformanceAlerts < ActiveRecord::Migration[8.0]
  def change
    create_table :performance_alerts do |t|
      t.string :name, null: false
      t.text :description
      t.string :metric_type, null: false # 'conversion_rate', 'click_rate', 'cost_per_acquisition', etc.
      t.string :metric_source, null: false # 'google_ads', 'facebook', 'email', etc.
      t.string :alert_type, null: false # 'threshold', 'anomaly', 'trend', 'comparison'
      t.string :severity, null: false, default: 'medium' # 'critical', 'high', 'medium', 'low'
      t.string :status, null: false, default: 'active' # 'active', 'paused', 'disabled'
      
      # Threshold Configuration
      t.decimal :threshold_value, precision: 15, scale: 6
      t.string :threshold_operator # 'greater_than', 'less_than', 'equals', 'not_equals'
      t.integer :threshold_duration_minutes, default: 5 # How long threshold must be breached
      
      # ML and Anomaly Detection
      t.boolean :use_ml_thresholds, default: false
      t.json :ml_model_config # Configuration for ML model
      t.decimal :anomaly_sensitivity, precision: 3, scale: 2, default: 0.95
      t.integer :baseline_period_days, default: 30
      
      # Conditional Logic
      t.json :conditions # Complex conditional rules
      t.json :filters # Additional filters for data
      
      # Notification Settings
      t.json :notification_channels # ['email', 'in_app', 'sms', 'slack', 'teams']
      t.json :notification_settings # Channel-specific settings
      t.integer :cooldown_minutes, default: 60 # Prevent alert spam
      t.integer :max_alerts_per_hour, default: 5
      
      # Targeting
      t.references :user, null: false, foreign_key: true
      t.references :campaign, null: true, foreign_key: true
      t.references :journey, null: true, foreign_key: true
      t.json :user_roles # Target specific user roles
      
      # Metadata
      t.json :metadata
      t.datetime :last_triggered_at
      t.datetime :last_checked_at
      t.integer :trigger_count, default: 0
      
      t.timestamps
    end
    
    add_index :performance_alerts, [:metric_type, :metric_source]
    add_index :performance_alerts, [:status, :last_checked_at]
    add_index :performance_alerts, :severity
  end
end
