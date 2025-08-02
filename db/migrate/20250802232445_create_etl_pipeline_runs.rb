class CreateEtlPipelineRuns < ActiveRecord::Migration[8.0]
  def change
    create_table :etl_pipeline_runs do |t|
      t.string :pipeline_id, null: false
      t.string :source, null: false
      t.string :status, null: false
      t.datetime :started_at, null: false
      t.datetime :completed_at
      t.float :duration
      t.text :error_message
      t.json :error_backtrace
      t.json :metrics

      t.timestamps
    end

    # Strategic indexes for ETL performance monitoring
    add_index :etl_pipeline_runs, :pipeline_id
    add_index :etl_pipeline_runs, :source
    add_index :etl_pipeline_runs, :status
    add_index :etl_pipeline_runs, :started_at
    add_index :etl_pipeline_runs, [:source, :status]
    add_index :etl_pipeline_runs, [:started_at, :status]
    add_index :etl_pipeline_runs, [:source, :started_at]
  end
end
