class CreateAbTests < ActiveRecord::Migration[8.0]
  def change
    create_table :ab_tests do |t|
      t.references :campaign, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.string :name, null: false
      t.text :description
      t.text :hypothesis
      t.string :test_type, default: 'conversion', null: false
      t.string :status, default: 'draft', null: false
      t.decimal :confidence_level, precision: 5, scale: 2, default: 95.0
      t.decimal :significance_threshold, precision: 5, scale: 2, default: 5.0
      t.datetime :start_date
      t.datetime :end_date
      t.integer :winner_variant_id
      t.json :metadata, default: {}
      t.json :settings, default: {}

      t.timestamps
    end
    
    add_index :ab_tests, [:campaign_id, :status]
    add_index :ab_tests, [:user_id, :status]
    add_index :ab_tests, :test_type
    add_index :ab_tests, :status
    add_index :ab_tests, :start_date
    add_index :ab_tests, :end_date
    add_index :ab_tests, [:campaign_id, :name], unique: true
  end
end
