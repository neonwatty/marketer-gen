class AddEnhancedBrandAssetFields < ActiveRecord::Migration[8.0]
  def change
    add_column :brand_assets, :external_url, :string
    add_column :brand_assets, :file_size, :bigint
    add_column :brand_assets, :virus_scan_status, :string, default: 'pending'
    add_column :brand_assets, :upload_progress, :integer, default: 0
    add_column :brand_assets, :chunk_count, :integer
    add_column :brand_assets, :chunks_uploaded, :integer, default: 0
    
    add_index :brand_assets, :external_url
    add_index :brand_assets, :virus_scan_status
  end
end
