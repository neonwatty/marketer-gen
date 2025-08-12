class CreateContentVariants < ActiveRecord::Migration[8.0]
  def change
    create_table :content_variants do |t|
      t.references :content_request, null: false, foreign_key: true
      t.string :name, null: false
      t.text :content, null: false
      t.string :strategy_type, null: false
      t.integer :variant_number, null: false
      t.decimal :performance_score, precision: 5, scale: 4, default: 0.0
      t.string :status, default: 'draft'
      t.text :metadata
      t.text :differences_analysis
      t.text :performance_data
      t.text :tags
      t.datetime :testing_started_at
      t.datetime :testing_completed_at
      t.datetime :archived_at
      t.string :optimization_goal
      t.string :target_audience
      t.text :description

      t.timestamps
    end

    add_index :content_variants, :status
    add_index :content_variants, :strategy_type
    add_index :content_variants, :performance_score
    add_index :content_variants, [:content_request_id, :variant_number], unique: true
  end
end
