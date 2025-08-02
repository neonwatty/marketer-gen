class AddAdditionalFieldsToContentPermissions < ActiveRecord::Migration[8.0]
  def change
    add_reference :content_permissions, :granted_by, null: true, foreign_key: { to_table: :users }
    add_reference :content_permissions, :revoked_by, null: true, foreign_key: { to_table: :users }
    add_column :content_permissions, :granted_at, :datetime
    add_column :content_permissions, :revoked_at, :datetime
    add_column :content_permissions, :expires_at, :datetime
    add_column :content_permissions, :revocation_reason, :text
    add_reference :content_permissions, :restored_by, null: true, foreign_key: { to_table: :users }
    add_column :content_permissions, :restored_at, :datetime
    add_column :content_permissions, :restoration_reason, :text
  end
end
