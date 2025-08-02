class CreatePlanTemplates < ActiveRecord::Migration[8.0]
  def change
    create_table :plan_templates do |t|
      t.string :name
      t.references :user, null: false, foreign_key: true
      t.string :industry_type
      t.string :template_type
      t.text :description
      t.text :template_data
      t.text :default_channels
      t.text :messaging_themes
      t.text :success_metrics_template
      t.boolean :active
      t.boolean :is_public
      t.text :metadata

      t.timestamps
    end
  end
end
