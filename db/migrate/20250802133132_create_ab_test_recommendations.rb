class CreateAbTestRecommendations < ActiveRecord::Migration[8.0]
  def change
    create_table :ab_test_recommendations do |t|
      t.references :ab_test, null: false, foreign_key: true
      t.string :recommendation_type
      t.text :content
      t.decimal :confidence_score
      t.string :status
      t.json :metadata

      t.timestamps
    end
  end
end
