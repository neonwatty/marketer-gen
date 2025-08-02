class CreateContentArchives < ActiveRecord::Migration[8.0]
  def change
    create_table :content_archives do |t|
      t.references :content_repository, null: false, foreign_key: true
      t.references :archived_by, null: false, foreign_key: { to_table: :users }
      t.references :restored_by, null: true, foreign_key: { to_table: :users }
      t.text :archive_reason
      t.integer :archive_level
      t.integer :status
      t.string :retention_period

      t.timestamps
    end
  end
end
