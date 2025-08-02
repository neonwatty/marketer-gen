class CreateContentRepositories < ActiveRecord::Migration[8.0]
  def change
    create_table :content_repositories do |t|
      t.string :title, null: false
      t.text :body
      t.integer :content_type, null: false
      t.integer :format, null: false
      t.string :storage_path, null: false
      t.string :file_hash, null: false
      t.integer :status, default: 0
      t.references :user, null: false, foreign_key: true
      t.references :campaign, null: true, foreign_key: true
      t.references :content_category, null: true, foreign_key: true

      t.timestamps
    end

    add_index :content_repositories, :file_hash, unique: true
    add_index :content_repositories, [:content_type, :status]
    add_index :content_repositories, [:user_id, :created_at]
  end
end
