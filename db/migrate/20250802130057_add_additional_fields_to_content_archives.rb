class AddAdditionalFieldsToContentArchives < ActiveRecord::Migration[8.0]
  def change
    add_column :content_archives, :storage_location, :string
    add_column :content_archives, :metadata_backup, :text
    add_column :content_archives, :metadata_backup_location, :string
    add_column :content_archives, :archived_content_body, :text
    add_column :content_archives, :retention_expires_at, :datetime
    add_column :content_archives, :restore_requested_at, :datetime
    add_column :content_archives, :restore_reason, :text
    add_column :content_archives, :restored_at, :datetime
    add_column :content_archives, :auto_delete_on_expiry, :boolean
    add_column :content_archives, :metadata_preservation, :boolean
    add_column :content_archives, :failure_reason, :text
    add_reference :content_archives, :retention_extended_by, null: true, foreign_key: { to_table: :users }
    add_column :content_archives, :retention_extended_at, :datetime
    add_column :content_archives, :retention_extension_reason, :text
  end
end
