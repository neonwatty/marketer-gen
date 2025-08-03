class AddDashboardLayoutToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :dashboard_layout, :string
  end
end
