class AddProfileFieldsToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :full_name, :string
    add_column :users, :bio, :text
    add_column :users, :phone_number, :string
    add_column :users, :company, :string
    add_column :users, :job_title, :string
    add_column :users, :timezone, :string, default: "UTC"
    add_column :users, :notification_email, :boolean, default: true, null: false
    add_column :users, :notification_marketing, :boolean, default: true, null: false
    add_column :users, :notification_product, :boolean, default: true, null: false
  end
end
