class CreateReportDistributionLists < ActiveRecord::Migration[8.0]
  def change
    create_table :report_distribution_lists do |t|
      t.string :name, null: false
      t.text :description
      t.text :email_addresses
      t.json :roles, default: []
      t.json :user_ids, default: []
      t.boolean :is_active, default: true
      t.boolean :auto_sync_roles, default: false
      t.references :user, null: false, foreign_key: true
      t.references :brand, null: false, foreign_key: true

      t.timestamps
    end

    add_index :report_distribution_lists, [:brand_id, :name], unique: true
    add_index :report_distribution_lists, :is_active
    add_index :report_distribution_lists, :auto_sync_roles
  end
end
