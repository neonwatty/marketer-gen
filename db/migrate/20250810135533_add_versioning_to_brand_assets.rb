class AddVersioningToBrandAssets < ActiveRecord::Migration[8.0]
  def change
    add_column :brand_assets, :version_number, :integer, default: 1
    add_column :brand_assets, :parent_asset_id, :integer
    add_column :brand_assets, :is_current_version, :boolean, default: true
    add_column :brand_assets, :version_notes, :text

    add_index :brand_assets, :parent_asset_id
    add_index :brand_assets, [ :parent_asset_id, :version_number ], unique: true
    add_index :brand_assets, [ :parent_asset_id, :is_current_version ]

    # Add foreign key constraint
    add_foreign_key :brand_assets, :brand_assets, column: :parent_asset_id
  end
end
