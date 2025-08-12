class CreateContentBranches < ActiveRecord::Migration[8.0]
  def change
    create_table :content_branches do |t|
      t.string :name, null: false
      t.references :content_item, polymorphic: true, null: false, index: true
      t.references :source_version, null: true, foreign_key: { to_table: :content_versions }
      t.references :head_version, null: true, foreign_key: { to_table: :content_versions }
      t.integer :author_id, null: true
      t.integer :status, default: 0, null: false
      t.integer :branch_type, default: 0, null: false
      t.text :description
      t.text :metadata
      t.datetime :merged_at
      t.datetime :deleted_at

      t.timestamps
    end

    add_index :content_branches, [:content_item_type, :content_item_id, :name], 
              unique: true, name: 'index_content_branches_on_content_item_and_name'
    add_index :content_branches, :status
    add_index :content_branches, :branch_type
    add_index :content_branches, :deleted_at
  end
end
