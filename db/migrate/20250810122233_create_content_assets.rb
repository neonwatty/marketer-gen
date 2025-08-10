class CreateContentAssets < ActiveRecord::Migration[8.0]
  def change
    create_table :content_assets do |t|
      t.references :assetable, polymorphic: true, null: false
      t.string :content_type, null: false
      t.text :content
      t.string :stage
      t.string :channel, null: false
      t.json :metadata, null: false, default: {}
      t.string :status, null: false, default: 'draft'
      t.string :title, null: false
      t.text :description
      t.integer :version, null: false, default: 1
      t.integer :file_size
      t.string :mime_type
      t.datetime :published_at
      t.datetime :approved_at
      t.references :approved_by, null: true, foreign_key: false
      t.integer :position, default: 0

      t.timestamps
    end

    # Add indexes for performance
    add_index :content_assets, [:assetable_type, :assetable_id]
    add_index :content_assets, :content_type
    add_index :content_assets, :channel
    add_index :content_assets, :status
    add_index :content_assets, :stage
    add_index :content_assets, :published_at
    add_index :content_assets, :position
    add_index :content_assets, [:assetable_type, :assetable_id, :channel], name: 'index_content_assets_on_assetable_and_channel'
  end
end
