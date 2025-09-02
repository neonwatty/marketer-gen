class AddAiJourneyTables < ActiveRecord::Migration[8.0]
  def change
    # Table for storing AI-generated journey suggestions
    create_table :journey_ai_suggestions do |t|
      t.references :journey, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.references :brand_identity, foreign_key: true
      t.string :suggestion_type, null: false
      t.json :content, default: {}
      t.json :brand_compliance_score, default: {}
      t.json :brand_elements_used, default: {}
      t.decimal :confidence_score, precision: 3, scale: 2
      t.string :user_feedback # accepted, rejected, modified
      t.boolean :applied, default: false
      t.json :performance_metrics, default: {}
      t.string :llm_model_used
      t.text :prompt_hash # For caching
      
      t.timestamps
      
      t.index [:journey_id, :created_at]
      t.index [:user_id, :suggestion_type]
      t.index :prompt_hash
    end

    # Table for tracking brand content performance
    create_table :brand_content_performance do |t|
      t.references :brand_identity, foreign_key: true
      t.references :generated_content, foreign_key: true
      t.references :journey_step, foreign_key: true
      t.decimal :compliance_score, precision: 3, scale: 2
      t.json :engagement_metrics, default: {}
      t.json :conversion_metrics, default: {}
      t.json :brand_elements_performance, default: {}
      
      t.timestamps
      
      t.index [:brand_identity_id, :created_at]
      t.index :compliance_score
    end

    # Table for journey learning data
    create_table :journey_learning_data do |t|
      t.references :journey, null: false, foreign_key: true
      t.json :performance_data, default: {}
      t.json :patterns_identified, default: {}
      t.json :recommendations_generated, default: {}
      t.integer :successful_conversions, default: 0
      t.integer :total_interactions, default: 0
      t.decimal :conversion_rate, precision: 5, scale: 2
      
      t.timestamps
      
      t.index [:journey_id, :created_at]
      t.index :conversion_rate
    end

    # Add AI-related columns to existing tables
    add_column :journey_steps, :ai_generated, :boolean, default: false
    add_column :journey_steps, :brand_compliance_score, :decimal, precision: 3, scale: 2
    add_column :journey_steps, :ai_performance_score, :decimal, precision: 3, scale: 2
    add_column :journey_steps, :ai_metadata, :json, default: {}
    
    add_column :journeys, :ai_optimization_enabled, :boolean, default: false
    add_column :journeys, :ai_suggestions_count, :integer, default: 0
    add_column :journeys, :ai_applied_count, :integer, default: 0
    add_column :journeys, :brand_consistency_score, :decimal, precision: 3, scale: 2
    
    # Indexes for performance
    add_index :journey_steps, :ai_generated
    add_index :journey_steps, :brand_compliance_score
    add_index :journeys, :ai_optimization_enabled
    add_index :journeys, :brand_consistency_score
  end
end
