class CreateAbTestTemplates < ActiveRecord::Migration[8.0]
  def change
    create_table :ab_test_templates do |t|
      t.references :user, null: false, foreign_key: true
      t.string :name
      t.text :description
      t.string :template_type
      t.json :configuration

      t.timestamps
    end
  end
end
