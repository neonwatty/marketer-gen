class CreateBrandGuidelines < ActiveRecord::Migration[8.0]
  def change
    create_table :brand_guidelines do |t|
      t.references :brand, null: false, foreign_key: true
      t.string :rule_type, null: false
      t.text :rule_content, null: false
      t.integer :priority, default: 0
      t.string :category # voice, tone, visual, messaging, etc.
      t.boolean :active, default: true
      t.json :examples, default: {}
      t.json :metadata, default: {}

      t.timestamps
    end

    add_index :brand_guidelines, :rule_type
    add_index :brand_guidelines, :category
    add_index :brand_guidelines, :priority
    add_index :brand_guidelines, [:brand_id, :active]
    add_index :brand_guidelines, [:brand_id, :rule_type]
  end
end
