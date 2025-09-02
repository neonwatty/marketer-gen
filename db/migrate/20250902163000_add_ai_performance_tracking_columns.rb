class AddAiPerformanceTrackingColumns < ActiveRecord::Migration[7.2]
  def change
    # Add AI performance tracking to journeys (skip existing columns)
    add_column :journeys, :ai_performance_score, :float unless column_exists?(:journeys, :ai_performance_score)
    add_column :journeys, :last_ai_analysis, :datetime unless column_exists?(:journeys, :last_ai_analysis)
    add_column :journeys, :ai_insights, :json unless column_exists?(:journeys, :ai_insights)
    add_column :journeys, :ai_learning_data, :json unless column_exists?(:journeys, :ai_learning_data)
    # ai_applied_count and ai_optimization_enabled already exist
    
    # Add performance tracking to journey steps (skip existing columns)
    add_column :journey_steps, :performance_metrics, :json unless column_exists?(:journey_steps, :performance_metrics)
    add_column :journey_steps, :last_performance_update, :datetime unless column_exists?(:journey_steps, :last_performance_update)
    # ai_metadata already exists
    add_column :journey_steps, :stage, :string unless column_exists?(:journey_steps, :stage)
    
    # Add indexes for performance queries (skip existing)
    add_index :journeys, :last_ai_analysis unless index_exists?(:journeys, :last_ai_analysis)
    # ai_optimization_enabled, ai_generated, and brand_compliance_score indexes already exist
  end
end