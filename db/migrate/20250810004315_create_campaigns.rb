class CreateCampaigns < ActiveRecord::Migration[8.0]
  def change
    create_table :campaigns do |t|
      t.string :name
      t.string :status
      t.text :purpose

      t.timestamps
    end
  end
end
