class AddBrandForeignKeyToJourneys < ActiveRecord::Migration[8.0]
  def change
    # Change brand_id from string to integer and add foreign key
    remove_column :journeys, :brand_id, :string
    add_reference :journeys, :brand, null: true, foreign_key: true
  end
end
