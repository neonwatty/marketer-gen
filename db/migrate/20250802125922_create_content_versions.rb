class CreateContentVersions < ActiveRecord::Migration[8.0]
  def change
    create_table :content_versions do |t|
      t.references :content_repository, null: false, foreign_key: true
      t.references :author, null: false, foreign_key: { to_table: :users }
      t.text :body, null: false
      t.integer :version_number, null: false
      t.string :commit_hash, null: false
      t.text :commit_message

      t.timestamps
    end

    add_index :content_versions, [:content_repository_id, :version_number], unique: true
    add_index :content_versions, :commit_hash, unique: true
    add_index :content_versions, [:author_id, :created_at]
  end
end
