class AddAdditionalFieldsToContentRevisions < ActiveRecord::Migration[8.0]
  def change
    add_column :content_revisions, :changes_summary, :text
    add_reference :content_revisions, :approved_by, null: true, foreign_key: { to_table: :users }
    add_column :content_revisions, :approved_at, :datetime
    add_reference :content_revisions, :rejected_by, null: true, foreign_key: { to_table: :users }
    add_column :content_revisions, :rejected_at, :datetime
    add_column :content_revisions, :applied_at, :datetime
    add_column :content_revisions, :approval_comments, :text
    add_column :content_revisions, :rejection_comments, :text
  end
end
