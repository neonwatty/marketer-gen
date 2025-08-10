class AddTextExtractionFieldsToBrandAssets < ActiveRecord::Migration[8.0]
  def change
    add_column :brand_assets, :text_extracted_at, :datetime
    add_column :brand_assets, :text_extraction_error, :text
  end
end
