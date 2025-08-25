class CreateBrandVariants < ActiveRecord::Migration[8.0]
  def change
    create_table :brand_variants do |t|
      # Foreign key associations
      t.references :user, null: false, foreign_key: true
      t.references :brand_identity, null: false, foreign_key: true
      t.references :persona, null: true, foreign_key: true
      
      # Basic attributes
      t.string :name, null: false
      t.text :description, null: false
      t.string :adaptation_context, null: false
      t.string :adaptation_type, null: false
      t.string :status, null: false, default: 'draft'
      t.integer :priority, null: false, default: 0
      t.integer :usage_count, null: false, default: 0
      
      # Performance tracking
      t.decimal :effectiveness_score, precision: 4, scale: 2
      t.datetime :last_used_at
      t.datetime :last_measured_at
      t.datetime :activated_at
      t.datetime :archived_at
      t.datetime :testing_started_at
      
      # JSON fields for complex data structures
      t.json :adaptation_rules
      t.json :brand_voice_adjustments
      t.json :messaging_variations
      t.json :visual_guidelines
      t.json :channel_specifications
      t.json :audience_targeting
      t.json :performance_metrics
      t.json :a_b_test_results
      
      t.timestamps
    end
    
    # Indexes for performance
    add_index :brand_variants, [:user_id, :brand_identity_id]
    add_index :brand_variants, [:user_id, :status]
    add_index :brand_variants, [:adaptation_context, :adaptation_type]
    add_index :brand_variants, :effectiveness_score
    add_index :brand_variants, :priority
    add_index :brand_variants, :last_used_at
    add_index :brand_variants, [:name, :user_id, :brand_identity_id], unique: true, name: 'index_brand_variants_unique_name_per_user_brand'
  end
end
