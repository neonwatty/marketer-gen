class CreatePerformanceThresholds < ActiveRecord::Migration[8.0]
  def change
    create_table :performance_thresholds do |t|
      t.string :metric_type, null: false
      t.string :metric_source, null: false
      t.string :context_filters, null: false # JSON string for filtering context
      
      # ML-Based Thresholds
      t.decimal :baseline_mean, precision: 15, scale: 6
      t.decimal :baseline_std_dev, precision: 15, scale: 6
      t.decimal :upper_threshold, precision: 15, scale: 6
      t.decimal :lower_threshold, precision: 15, scale: 6
      t.decimal :anomaly_threshold, precision: 15, scale: 6
      
      # Statistical Metadata
      t.integer :sample_size
      t.decimal :confidence_level, precision: 5, scale: 4, default: 0.95
      t.datetime :baseline_start_date
      t.datetime :baseline_end_date
      t.datetime :last_recalculated_at
      
      # Model Performance
      t.decimal :accuracy_score, precision: 5, scale: 4
      t.decimal :precision_score, precision: 5, scale: 4
      t.decimal :recall_score, precision: 5, scale: 4
      t.decimal :f1_score, precision: 5, scale: 4
      t.integer :true_positives, default: 0
      t.integer :false_positives, default: 0
      t.integer :true_negatives, default: 0
      t.integer :false_negatives, default: 0
      
      # Adaptive Learning
      t.boolean :auto_adjust, default: true
      t.integer :recalculation_frequency_hours, default: 24
      t.decimal :learning_rate, precision: 5, scale: 4, default: 0.1
      t.json :model_parameters
      
      # Context and Segmentation
      t.references :campaign, null: true, foreign_key: true
      t.references :journey, null: true, foreign_key: true
      t.string :audience_segment
      t.string :time_of_day_segment
      t.string :day_of_week_segment
      t.string :seasonality_segment
      
      t.timestamps
    end
    
    add_index :performance_thresholds, [:metric_type, :metric_source]
    add_index :performance_thresholds, :context_filters
    add_index :performance_thresholds, [:last_recalculated_at, :auto_adjust]
    add_index :performance_thresholds, [:accuracy_score, :metric_type]
    
    add_check_constraint :performance_thresholds, 'confidence_level >= 0.5 AND confidence_level <= 1.0', name: 'confidence_level_range'
    add_check_constraint :performance_thresholds, 'learning_rate >= 0.001 AND learning_rate <= 1.0', name: 'learning_rate_range'
  end
end
