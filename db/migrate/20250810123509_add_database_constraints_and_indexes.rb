class AddDatabaseConstraintsAndIndexes < ActiveRecord::Migration[8.0]
  def change
    # Add foreign key constraints that weren't added yet
    add_foreign_key :campaigns, :brand_identities, column: :brand_identity_id

    # Add composite indexes for better query performance
    add_index :customer_journeys, [ :campaign_id, :created_at ], name: 'index_customer_journeys_on_campaign_and_date'
    add_index :content_assets, [ :assetable_type, :assetable_id, :status ], name: 'index_content_assets_on_assetable_and_status'
    add_index :content_assets, [ :channel, :status, :published_at ], name: 'index_content_assets_on_channel_status_published'
    add_index :templates, [ :template_type, :is_active, :usage_count ], name: 'index_templates_on_type_active_usage'
    add_index :templates, [ :parent_template_id, :version ], name: 'index_templates_on_parent_and_version'

    # Add unique constraints where appropriate (skip campaign name uniqueness for now)
    add_index :brand_identities, [ :name, :version ], unique: true, name: 'index_brand_identities_on_name_and_version'

    # Add check constraints for data integrity (SQLite doesn't support check constraints, so we'll handle in validations)

    # Add counter cache columns for performance
    add_column :campaigns, :customer_journeys_count, :integer, default: 0, null: false
    add_column :campaigns, :content_assets_count, :integer, default: 0, null: false
    add_column :brand_identities, :campaigns_count, :integer, default: 0, null: false
    add_column :templates, :child_templates_count, :integer, default: 0, null: false

    # Update existing counter caches
    Campaign.find_each do |campaign|
      Campaign.reset_counters(campaign.id, :customer_journeys, :content_assets)
    end

    BrandIdentity.find_each do |brand_identity|
      BrandIdentity.reset_counters(brand_identity.id, :campaigns)
    end

    Template.find_each do |template|
      Template.reset_counters(template.id, :child_templates)
    end
  end

  def down
    # Remove foreign keys
    remove_foreign_key :campaigns, :brand_identities

    # Remove composite indexes
    remove_index :customer_journeys, name: 'index_customer_journeys_on_campaign_and_date'
    remove_index :content_assets, name: 'index_content_assets_on_assetable_and_status'
    remove_index :content_assets, name: 'index_content_assets_on_channel_status_published'
    remove_index :templates, name: 'index_templates_on_type_active_usage'
    remove_index :templates, name: 'index_templates_on_parent_and_version'

    # Remove unique constraints
    remove_index :brand_identities, name: 'index_brand_identities_on_name_and_version'

    # Remove counter cache columns
    remove_column :campaigns, :customer_journeys_count
    remove_column :campaigns, :content_assets_count
    remove_column :brand_identities, :campaigns_count
    remove_column :templates, :child_templates_count
  end
end
