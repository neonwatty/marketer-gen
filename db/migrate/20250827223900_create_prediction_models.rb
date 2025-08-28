class CreatePredictionModels < ActiveRecord::Migration[8.0]
  def change
    create_table :prediction_models do |t|
      t.string :name, null: false
      t.string :prediction_type, null: false
      t.string :model_type, null: false
      t.string :status, null: false, default: 'draft'
      t.integer :version, null: false
      t.decimal :accuracy_score, precision: 5, scale: 3, null: false, default: 0.0
      t.decimal :confidence_level, precision: 5, scale: 3, null: false, default: 0.0
      
      # Foreign key associations
      t.references :campaign_plan, null: false, foreign_key: true
      t.references :created_by, null: false, foreign_key: { to_table: :users }
      t.references :trained_by, null: true, foreign_key: { to_table: :users }
      t.references :activated_by, null: true, foreign_key: { to_table: :users }
      
      # Training timestamps
      t.timestamp :training_started_at
      t.timestamp :training_completed_at
      t.timestamp :training_failed_at
      t.timestamp :activated_at
      t.timestamp :deprecated_at
      
      # Usage statistics
      t.integer :prediction_count, default: 0
      t.timestamp :last_prediction_at
      
      # Error tracking
      t.text :error_message
      
      # JSON data fields
      t.json :training_data
      t.json :model_parameters
      t.json :feature_importance
      t.json :validation_metrics
      t.json :prediction_results
      t.json :metadata
      
      t.timestamps
      
      # Indexes for performance
      t.index [:campaign_plan_id, :prediction_type], name: 'idx_prediction_models_on_campaign_and_type'
      t.index [:campaign_plan_id, :prediction_type, :version], unique: true, name: 'idx_prediction_models_unique_version'
      t.index [:status]
      t.index [:prediction_type]
      t.index [:accuracy_score]
      t.index [:created_at]
    end
  end
end
