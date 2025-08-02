class CreateContentRevisions < ActiveRecord::Migration[8.0]
  def change
    create_table :content_revisions do |t|
      t.references :content_repository, null: false, foreign_key: true
      t.references :revised_by, null: false, foreign_key: { to_table: :users }
      t.text :content_before
      t.text :content_after
      t.text :revision_reason
      t.integer :revision_type
      t.integer :status
      t.integer :revision_number

      t.timestamps
    end
  end
end
