class CreateBrandAssets < ActiveRecord::Migration[8.0]
  def change
    create_table :brand_assets do |t|
      t.references :brand, null: false, foreign_key: true
      t.string :asset_type, null: false
      t.json :metadata, default: {}
      t.string :original_filename
      t.string :content_type
      t.text :extracted_text
      t.json :extracted_data, default: {}
      t.string :processing_status, default: "pending"
      t.datetime :processed_at

      t.timestamps
    end

    add_index :brand_assets, :asset_type
    add_index :brand_assets, :processing_status
    add_index :brand_assets, [:brand_id, :asset_type]
  end
end
