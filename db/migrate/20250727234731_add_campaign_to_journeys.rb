class AddCampaignToJourneys < ActiveRecord::Migration[8.0]
  def change
    add_reference :journeys, :campaign, null: true, foreign_key: true
    add_index :journeys, [:campaign_id, :status]
  end
end
