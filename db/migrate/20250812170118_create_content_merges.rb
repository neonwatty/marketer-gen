class CreateContentMerges < ActiveRecord::Migration[8.0]
  def change
    create_table :content_merges do |t|
      t.references :source_version, null: false, foreign_key: { to_table: :content_versions }
      t.references :target_version, null: false, foreign_key: { to_table: :content_versions }
      t.references :source_branch, null: true, foreign_key: { to_table: :content_branches }
      t.references :target_branch, null: true, foreign_key: { to_table: :content_branches }
      t.integer :author_id, null: true
      t.integer :merge_strategy, null: false
      t.integer :status, default: 0, null: false
      t.integer :conflict_count, default: 0
      t.text :conflicts_data
      t.text :resolution_data
      t.text :merge_metadata
      t.datetime :completed_at

      t.timestamps
    end

    add_index :content_merges, [:source_version_id, :target_version_id], 
              name: 'index_content_merges_on_versions'
    add_index :content_merges, :status
    add_index :content_merges, :merge_strategy
    add_index :content_merges, :completed_at
  end
end
