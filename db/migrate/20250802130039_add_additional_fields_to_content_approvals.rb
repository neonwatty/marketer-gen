class AddAdditionalFieldsToContentApprovals < ActiveRecord::Migration[8.0]
  def change
    add_column :content_approvals, :approver_comments, :text
    add_column :content_approvals, :approved_at, :datetime
    add_column :content_approvals, :rejected_at, :datetime
    add_column :content_approvals, :reviewed_at, :datetime
  end
end
