class CreateContentPermissions < ActiveRecord::Migration[8.0]
  def change
    create_table :content_permissions do |t|
      t.references :content_repository, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.integer :permission_type
      t.boolean :active
      t.references :granted_by, null: true, foreign_key: { to_table: :users }
      t.references :revoked_by, null: true, foreign_key: { to_table: :users }

      t.timestamps
    end
  end
end
