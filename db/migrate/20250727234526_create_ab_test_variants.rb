class CreateAbTestVariants < ActiveRecord::Migration[8.0]
  def change
    create_table :ab_test_variants do |t|
      t.references :ab_test, null: false, foreign_key: true
      t.references :journey, null: false, foreign_key: true
      t.string :name, null: false
      t.text :description
      t.string :variant_type, default: 'treatment', null: false
      t.decimal :traffic_percentage, precision: 5, scale: 2, default: 50.0
      t.boolean :is_control, default: false
      t.integer :total_visitors, default: 0
      t.integer :conversions, default: 0
      t.decimal :conversion_rate, precision: 5, scale: 2, default: 0.0
      t.decimal :confidence_interval, precision: 5, scale: 2, default: 0.0
      t.json :metadata, default: {}

      t.timestamps
    end
    
    add_index :ab_test_variants, [:ab_test_id, :name], unique: true
    add_index :ab_test_variants, [:ab_test_id, :is_control]
    add_index :ab_test_variants, :variant_type
    add_index :ab_test_variants, :conversion_rate
    add_index :ab_test_variants, :traffic_percentage
  end
end
