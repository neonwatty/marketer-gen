class CreateContentAbTests < ActiveRecord::Migration[8.0]
  def change
    create_table :content_ab_tests do |t|
      t.string :test_name, null: false, limit: 255
      t.string :status, null: false, default: 'draft', limit: 50
      t.string :primary_goal, null: false, limit: 50
      t.string :confidence_level, null: false, default: '95', limit: 10
      t.decimal :traffic_allocation, null: false, precision: 5, scale: 2, default: 100.0
      t.integer :minimum_sample_size, null: false, default: 100
      t.integer :test_duration_days, null: false, default: 14
      t.datetime :start_date
      t.datetime :end_date
      t.boolean :statistical_significance, default: false
      t.string :winner_variant_id, limit: 100
      t.text :description
      t.text :secondary_goals
      t.text :audience_segments
      t.text :metadata
      t.references :campaign_plan, null: false, foreign_key: true
      t.references :created_by, null: false, foreign_key: { to_table: :users }
      t.references :control_content, null: false, foreign_key: { to_table: :generated_contents }

      t.timestamps
    end

    add_index :content_ab_tests, :status
    add_index :content_ab_tests, :primary_goal
    add_index :content_ab_tests, [:campaign_plan_id, :status]
    add_index :content_ab_tests, [:start_date, :end_date]
    add_index :content_ab_tests, :test_name, unique: true
  end
end
