class CreateBrandAssets < ActiveRecord::Migration[8.0]
  def change
    create_table :brand_assets do |t|
      t.string :file_type, null: false
      t.bigint :file_size
      t.string :original_filename
      t.json :metadata, default: {}, null: false
      t.text :extracted_text
      t.string :scan_status, default: 'pending'
      t.references :assetable, polymorphic: true, null: false, index: true
      t.string :content_type
      t.string :checksum
      t.string :purpose
      t.boolean :active, default: true, null: false
      t.datetime :scanned_at
      t.datetime :processed_at

      t.timestamps
    end

    add_index :brand_assets, [ :assetable_type, :assetable_id, :file_type ]
    add_index :brand_assets, :scan_status
    add_index :brand_assets, :file_type
    add_index :brand_assets, :active
  end
end
