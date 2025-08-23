class CreateContentAbTestVariants < ActiveRecord::Migration[8.0]
  def change
    create_table :content_ab_test_variants do |t|
      t.string :variant_name, null: false, limit: 255
      t.string :status, null: false, default: 'draft', limit: 50
      t.decimal :traffic_split, null: false, precision: 5, scale: 2
      t.integer :sample_size, default: 0
      t.text :metadata
      t.references :content_ab_test, null: false, foreign_key: true
      t.references :generated_content, null: false, foreign_key: true

      t.timestamps
    end

    add_index :content_ab_test_variants, :status
    add_index :content_ab_test_variants, [:content_ab_test_id, :status]
    add_index :content_ab_test_variants, [:content_ab_test_id, :variant_name], unique: true, name: 'index_ab_test_variants_on_test_and_name'
    add_index :content_ab_test_variants, [:generated_content_id, :content_ab_test_id], unique: true, name: 'index_ab_test_variants_on_content_and_test'
  end
end
