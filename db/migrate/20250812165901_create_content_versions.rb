class CreateContentVersions < ActiveRecord::Migration[8.0]
  def change
    create_table :content_versions do |t|
      t.references :content_item, polymorphic: true, null: false, index: true
      t.references :parent, null: true, foreign_key: { to_table: :content_versions }
      t.text :content_data, null: false
      t.string :content_type, null: false
      t.text :commit_message, null: false
      t.integer :version_number, null: false
      t.string :version_hash, null: false
      t.integer :status, default: 0, null: false
      t.datetime :committed_at
      t.text :metadata
      t.integer :author_id, null: true
      t.references :branch, null: true, foreign_key: { to_table: :content_branches }

      t.timestamps
    end

    add_index :content_versions, :version_hash, unique: true
    add_index :content_versions, [:content_item_type, :content_item_id, :version_number], 
              name: 'index_content_versions_on_content_item_and_version'
    add_index :content_versions, [:branch_id, :committed_at]
    add_index :content_versions, :status
  end
end
