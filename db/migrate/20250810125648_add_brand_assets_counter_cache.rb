class AddBrandAssetsCounterCache < ActiveRecord::Migration[8.0]
  def change
    add_column :brand_identities, :brand_assets_count, :integer, default: 0, null: false
    add_column :campaigns, :brand_assets_count, :integer, default: 0, null: false

    # Reset counter caches for existing records
    reversible do |dir|
      dir.up do
        BrandIdentity.find_each { |brand| BrandIdentity.reset_counters(brand.id, :brand_assets) }
        Campaign.find_each { |campaign| Campaign.reset_counters(campaign.id, :brand_assets) }
      end
    end
  end
end
