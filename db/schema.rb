# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.0].define(version: 2025_08_12_225435) do
  create_table "active_storage_attachments", force: :cascade do |t|
    t.string "name", null: false
    t.string "record_type", null: false
    t.bigint "record_id", null: false
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.string "key", null: false
    t.string "filename", null: false
    t.string "content_type"
    t.text "metadata"
    t.string "service_name", null: false
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.datetime "created_at", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "ai_generation_requests", force: :cascade do |t|
    t.integer "campaign_id", null: false
    t.string "content_type"
    t.text "prompt_data"
    t.string "status"
    t.text "generated_content"
    t.text "metadata"
    t.string "webhook_url"
    t.datetime "completed_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["campaign_id"], name: "index_ai_generation_requests_on_campaign_id"
  end

  create_table "ai_job_statuses", force: :cascade do |t|
    t.integer "generation_request_id", null: false
    t.string "job_id"
    t.string "status"
    t.text "progress_data"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["generation_request_id"], name: "index_ai_job_statuses_on_generation_request_id"
  end

  create_table "brand_assets", force: :cascade do |t|
    t.string "file_type", null: false
    t.bigint "file_size"
    t.string "original_filename"
    t.json "metadata", default: {}, null: false
    t.text "extracted_text"
    t.string "scan_status", default: "pending"
    t.string "assetable_type", null: false
    t.integer "assetable_id", null: false
    t.string "content_type"
    t.string "checksum"
    t.string "purpose"
    t.boolean "active", default: true, null: false
    t.datetime "scanned_at"
    t.datetime "processed_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "text_extracted_at"
    t.text "text_extraction_error"
    t.integer "version_number", default: 1
    t.integer "parent_asset_id"
    t.boolean "is_current_version", default: true
    t.text "version_notes"
    t.index ["active"], name: "index_brand_assets_on_active"
    t.index ["assetable_type", "assetable_id", "file_type"], name: "idx_on_assetable_type_assetable_id_file_type_768c8523e2"
    t.index ["assetable_type", "assetable_id"], name: "index_brand_assets_on_assetable"
    t.index ["file_type"], name: "index_brand_assets_on_file_type"
    t.index ["parent_asset_id", "is_current_version"], name: "index_brand_assets_on_parent_asset_id_and_is_current_version"
    t.index ["parent_asset_id", "version_number"], name: "index_brand_assets_on_parent_asset_id_and_version_number", unique: true
    t.index ["parent_asset_id"], name: "index_brand_assets_on_parent_asset_id"
    t.index ["scan_status"], name: "index_brand_assets_on_scan_status"
  end

  create_table "brand_identities", force: :cascade do |t|
    t.string "name", null: false
    t.text "description"
    t.json "guidelines", default: {}, null: false
    t.json "messaging_frameworks", default: {}, null: false
    t.json "color_palette", default: {}, null: false
    t.json "typography", default: {}, null: false
    t.integer "version", default: 1, null: false
    t.boolean "active", default: true, null: false
    t.datetime "published_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "campaigns_count", default: 0, null: false
    t.integer "brand_assets_count", default: 0, null: false
    t.index ["active"], name: "index_brand_identities_on_active"
    t.index ["name", "version"], name: "index_brand_identities_on_name_and_version", unique: true
    t.index ["name"], name: "index_brand_identities_on_name", unique: true
    t.index ["published_at"], name: "index_brand_identities_on_published_at"
    t.index ["version"], name: "index_brand_identities_on_version"
  end

  create_table "campaigns", force: :cascade do |t|
    t.string "name"
    t.string "status"
    t.text "purpose"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "brand_identity_id"
    t.text "target_audience"
    t.integer "budget_cents"
    t.date "start_date"
    t.date "end_date"
    t.integer "customer_journeys_count", default: 0, null: false
    t.integer "content_assets_count", default: 0, null: false
    t.integer "brand_assets_count", default: 0, null: false
    t.index ["brand_identity_id"], name: "index_campaigns_on_brand_identity_id"
    t.index ["created_at"], name: "index_campaigns_on_created_at"
    t.index ["start_date"], name: "index_campaigns_on_start_date"
    t.index ["status", "start_date"], name: "index_campaigns_on_status_and_start_date"
    t.index ["status"], name: "index_campaigns_on_status"
  end

  create_table "content_assets", force: :cascade do |t|
    t.string "assetable_type", null: false
    t.integer "assetable_id", null: false
    t.string "content_type", null: false
    t.text "content"
    t.string "stage"
    t.string "channel", null: false
    t.json "metadata", default: {}, null: false
    t.string "status", default: "draft", null: false
    t.string "title", null: false
    t.text "description"
    t.integer "version", default: 1, null: false
    t.integer "file_size"
    t.string "mime_type"
    t.datetime "published_at"
    t.datetime "approved_at"
    t.integer "approved_by_id"
    t.integer "position", default: 0
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["approved_by_id"], name: "index_content_assets_on_approved_by_id"
    t.index ["assetable_type", "assetable_id", "channel"], name: "index_content_assets_on_assetable_and_channel"
    t.index ["assetable_type", "assetable_id", "status"], name: "index_content_assets_on_assetable_and_status"
    t.index ["assetable_type", "assetable_id"], name: "index_content_assets_on_assetable"
    t.index ["assetable_type", "assetable_id"], name: "index_content_assets_on_assetable_type_and_assetable_id"
    t.index ["channel", "status", "published_at"], name: "index_content_assets_on_channel_status_published"
    t.index ["channel"], name: "index_content_assets_on_channel"
    t.index ["content_type"], name: "index_content_assets_on_content_type"
    t.index ["position"], name: "index_content_assets_on_position"
    t.index ["published_at"], name: "index_content_assets_on_published_at"
    t.index ["stage"], name: "index_content_assets_on_stage"
    t.index ["status"], name: "index_content_assets_on_status"
  end

  create_table "content_branches", force: :cascade do |t|
    t.string "name", null: false
    t.string "content_item_type", null: false
    t.integer "content_item_id", null: false
    t.integer "source_version_id"
    t.integer "head_version_id"
    t.integer "author_id"
    t.integer "status", default: 0, null: false
    t.integer "branch_type", default: 0, null: false
    t.text "description"
    t.text "metadata"
    t.datetime "merged_at"
    t.datetime "deleted_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["branch_type"], name: "index_content_branches_on_branch_type"
    t.index ["content_item_type", "content_item_id", "name"], name: "index_content_branches_on_content_item_and_name", unique: true
    t.index ["content_item_type", "content_item_id"], name: "index_content_branches_on_content_item"
    t.index ["deleted_at"], name: "index_content_branches_on_deleted_at"
    t.index ["head_version_id"], name: "index_content_branches_on_head_version_id"
    t.index ["source_version_id"], name: "index_content_branches_on_source_version_id"
    t.index ["status"], name: "index_content_branches_on_status"
  end

  create_table "content_merges", force: :cascade do |t|
    t.integer "source_version_id", null: false
    t.integer "target_version_id", null: false
    t.integer "source_branch_id"
    t.integer "target_branch_id"
    t.integer "author_id"
    t.integer "merge_strategy", null: false
    t.integer "status", default: 0, null: false
    t.integer "conflict_count", default: 0
    t.text "conflicts_data"
    t.text "resolution_data"
    t.text "merge_metadata"
    t.datetime "completed_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["completed_at"], name: "index_content_merges_on_completed_at"
    t.index ["merge_strategy"], name: "index_content_merges_on_merge_strategy"
    t.index ["source_branch_id"], name: "index_content_merges_on_source_branch_id"
    t.index ["source_version_id", "target_version_id"], name: "index_content_merges_on_versions"
    t.index ["source_version_id"], name: "index_content_merges_on_source_version_id"
    t.index ["status"], name: "index_content_merges_on_status"
    t.index ["target_branch_id"], name: "index_content_merges_on_target_branch_id"
    t.index ["target_version_id"], name: "index_content_merges_on_target_version_id"
  end

  create_table "content_requests", force: :cascade do |t|
    t.string "campaign_name"
    t.string "content_type"
    t.string "platform"
    t.text "brand_context"
    t.string "campaign_goal"
    t.text "target_audience"
    t.string "tone"
    t.string "content_length"
    t.text "required_elements"
    t.text "restrictions"
    t.text "additional_context"
    t.text "request_metadata"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "content_responses", force: :cascade do |t|
    t.integer "content_request_id", null: false
    t.text "generated_content"
    t.string "generation_status"
    t.text "response_metadata"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["content_request_id"], name: "index_content_responses_on_content_request_id"
  end

  create_table "content_schedules", force: :cascade do |t|
    t.string "content_item_type", null: false
    t.integer "content_item_id", null: false
    t.integer "campaign_id", null: false
    t.string "channel"
    t.string "platform"
    t.datetime "scheduled_at"
    t.datetime "published_at"
    t.integer "status"
    t.integer "priority"
    t.string "frequency"
    t.text "recurrence_data"
    t.boolean "auto_publish"
    t.string "time_zone"
    t.text "metadata"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["campaign_id"], name: "index_content_schedules_on_campaign_id"
    t.index ["content_item_type", "content_item_id"], name: "index_content_schedules_on_content_item"
  end

  create_table "content_variants", force: :cascade do |t|
    t.integer "content_request_id", null: false
    t.string "name", null: false
    t.text "content", null: false
    t.string "strategy_type", null: false
    t.integer "variant_number", null: false
    t.decimal "performance_score", precision: 5, scale: 4, default: "0.0"
    t.string "status", default: "draft"
    t.text "metadata"
    t.text "differences_analysis"
    t.text "performance_data"
    t.text "tags"
    t.datetime "testing_started_at"
    t.datetime "testing_completed_at"
    t.datetime "archived_at"
    t.string "optimization_goal"
    t.string "target_audience"
    t.text "description"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["content_request_id", "variant_number"], name: "idx_on_content_request_id_variant_number_faba7a7a62", unique: true
    t.index ["content_request_id"], name: "index_content_variants_on_content_request_id"
    t.index ["performance_score"], name: "index_content_variants_on_performance_score"
    t.index ["status"], name: "index_content_variants_on_status"
    t.index ["strategy_type"], name: "index_content_variants_on_strategy_type"
  end

  create_table "content_versions", force: :cascade do |t|
    t.string "content_item_type", null: false
    t.integer "content_item_id", null: false
    t.integer "parent_id"
    t.text "content_data", null: false
    t.string "content_type", null: false
    t.text "commit_message", null: false
    t.integer "version_number", null: false
    t.string "version_hash", null: false
    t.integer "status", default: 0, null: false
    t.datetime "committed_at"
    t.text "metadata"
    t.integer "author_id"
    t.integer "branch_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["branch_id", "committed_at"], name: "index_content_versions_on_branch_id_and_committed_at"
    t.index ["branch_id"], name: "index_content_versions_on_branch_id"
    t.index ["content_item_type", "content_item_id", "version_number"], name: "index_content_versions_on_content_item_and_version"
    t.index ["content_item_type", "content_item_id"], name: "index_content_versions_on_content_item"
    t.index ["parent_id"], name: "index_content_versions_on_parent_id"
    t.index ["status"], name: "index_content_versions_on_status"
    t.index ["version_hash"], name: "index_content_versions_on_version_hash", unique: true
  end

  create_table "content_workflows", force: :cascade do |t|
    t.string "content_item_type", null: false
    t.integer "content_item_id", null: false
    t.string "current_stage"
    t.string "previous_stage"
    t.string "template_name"
    t.string "template_version"
    t.integer "status"
    t.integer "priority"
    t.integer "created_by_id"
    t.integer "updated_by_id"
    t.text "metadata"
    t.text "settings"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["content_item_type", "content_item_id"], name: "index_content_workflows_on_content_item"
  end

  create_table "customer_journeys", force: :cascade do |t|
    t.integer "campaign_id", null: false
    t.string "name", null: false
    t.text "description"
    t.json "stages", default: [], null: false
    t.json "content_types", default: [], null: false
    t.json "touchpoints", default: {}, null: false
    t.json "metrics", default: {}, null: false
    t.integer "position", default: 0
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["campaign_id", "created_at"], name: "index_customer_journeys_on_campaign_and_date"
    t.index ["campaign_id"], name: "index_customer_journeys_on_campaign_id"
    t.index ["name"], name: "index_customer_journeys_on_name"
    t.index ["position"], name: "index_customer_journeys_on_position"
  end

  create_table "journey_stages", force: :cascade do |t|
    t.integer "journey_id", null: false
    t.integer "position", null: false
    t.string "stage_type", null: false
    t.string "name", null: false
    t.text "description"
    t.text "content"
    t.json "configuration", default: {}, null: false
    t.integer "duration_days"
    t.string "status", default: "draft"
    t.boolean "is_active", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["is_active"], name: "index_journey_stages_on_is_active"
    t.index ["journey_id", "position"], name: "index_journey_stages_on_journey_id_and_position"
    t.index ["journey_id"], name: "index_journey_stages_on_journey_id"
    t.index ["stage_type"], name: "index_journey_stages_on_stage_type"
    t.index ["status"], name: "index_journey_stages_on_status"
  end

  create_table "journey_templates", force: :cascade do |t|
    t.string "name", null: false
    t.string "template_type", null: false
    t.string "category"
    t.json "template_data", default: {}, null: false
    t.text "description"
    t.boolean "is_active", default: true, null: false
    t.integer "usage_count", default: 0, null: false
    t.integer "version", default: 1, null: false
    t.string "author"
    t.json "variables", default: [], null: false
    t.json "metadata", default: {}, null: false
    t.string "tags"
    t.datetime "published_at"
    t.integer "parent_template_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["category"], name: "index_journey_templates_on_category"
    t.index ["name"], name: "index_journey_templates_on_name"
    t.index ["parent_template_id"], name: "index_journey_templates_on_parent_template_id"
    t.index ["template_type", "is_active"], name: "index_journey_templates_on_template_type_and_is_active"
    t.index ["usage_count"], name: "index_journey_templates_on_usage_count"
  end

  create_table "journeys", force: :cascade do |t|
    t.string "name", null: false
    t.string "template_type"
    t.text "purpose"
    t.text "goals"
    t.text "timing"
    t.text "audience"
    t.integer "campaign_id", null: false
    t.boolean "is_active", default: true, null: false
    t.integer "position", default: 0
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["campaign_id", "position"], name: "index_journeys_on_campaign_id_and_position"
    t.index ["campaign_id"], name: "index_journeys_on_campaign_id"
    t.index ["is_active"], name: "index_journeys_on_is_active"
    t.index ["template_type"], name: "index_journeys_on_template_type"
  end

  create_table "prompt_templates", force: :cascade do |t|
    t.string "name", null: false
    t.string "prompt_type", null: false
    t.text "system_prompt", null: false
    t.text "user_prompt", null: false
    t.json "variables", default: [], null: false
    t.json "default_values", default: {}, null: false
    t.text "description"
    t.string "category"
    t.integer "version", default: 1, null: false
    t.boolean "is_active", default: true, null: false
    t.integer "usage_count", default: 0, null: false
    t.integer "parent_template_id"
    t.json "metadata", default: {}, null: false
    t.string "tags"
    t.float "temperature", default: 0.7
    t.integer "max_tokens", default: 2000
    t.string "model_preferences"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "child_templates_count", default: 0, null: false
    t.index ["category"], name: "index_prompt_templates_on_category"
    t.index ["is_active", "prompt_type"], name: "index_prompt_templates_on_is_active_and_prompt_type"
    t.index ["is_active"], name: "index_prompt_templates_on_is_active"
    t.index ["name"], name: "index_prompt_templates_on_name"
    t.index ["parent_template_id"], name: "index_prompt_templates_on_parent_template_id"
    t.index ["prompt_type", "category"], name: "index_prompt_templates_on_prompt_type_and_category"
    t.index ["prompt_type"], name: "index_prompt_templates_on_prompt_type"
    t.index ["usage_count"], name: "index_prompt_templates_on_usage_count"
    t.index ["version"], name: "index_prompt_templates_on_version"
  end

  create_table "publishing_queues", force: :cascade do |t|
    t.integer "content_schedule_id", null: false
    t.string "batch_id"
    t.integer "processing_status"
    t.datetime "scheduled_for"
    t.datetime "attempted_at"
    t.datetime "completed_at"
    t.text "error_message"
    t.integer "retry_count"
    t.integer "max_retries"
    t.text "processing_metadata"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["content_schedule_id"], name: "index_publishing_queues_on_content_schedule_id"
  end

  create_table "solid_queue_blocked_executions", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.string "queue_name", null: false
    t.integer "priority", default: 0, null: false
    t.string "concurrency_key", null: false
    t.datetime "expires_at", null: false
    t.datetime "created_at", null: false
    t.index ["concurrency_key", "priority", "job_id"], name: "index_solid_queue_blocked_executions_for_release"
    t.index ["expires_at", "concurrency_key"], name: "index_solid_queue_blocked_executions_for_maintenance"
    t.index ["job_id"], name: "index_solid_queue_blocked_executions_on_job_id", unique: true
  end

  create_table "solid_queue_claimed_executions", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.bigint "process_id"
    t.datetime "created_at", null: false
    t.index ["job_id"], name: "index_solid_queue_claimed_executions_on_job_id", unique: true
    t.index ["process_id", "job_id"], name: "index_solid_queue_claimed_executions_on_process_id_and_job_id"
  end

  create_table "solid_queue_failed_executions", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.text "error"
    t.datetime "created_at", null: false
    t.index ["job_id"], name: "index_solid_queue_failed_executions_on_job_id", unique: true
  end

  create_table "solid_queue_jobs", force: :cascade do |t|
    t.string "queue_name", null: false
    t.string "class_name", null: false
    t.text "arguments"
    t.integer "priority", default: 0, null: false
    t.string "active_job_id"
    t.datetime "scheduled_at"
    t.datetime "finished_at"
    t.string "concurrency_key"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["active_job_id"], name: "index_solid_queue_jobs_on_active_job_id"
    t.index ["class_name"], name: "index_solid_queue_jobs_on_class_name"
    t.index ["finished_at"], name: "index_solid_queue_jobs_on_finished_at"
    t.index ["queue_name", "finished_at"], name: "index_solid_queue_jobs_for_filtering"
    t.index ["scheduled_at", "finished_at"], name: "index_solid_queue_jobs_for_alerting"
  end

  create_table "solid_queue_pauses", force: :cascade do |t|
    t.string "queue_name", null: false
    t.datetime "created_at", null: false
    t.index ["queue_name"], name: "index_solid_queue_pauses_on_queue_name", unique: true
  end

  create_table "solid_queue_processes", force: :cascade do |t|
    t.string "kind", null: false
    t.datetime "last_heartbeat_at", null: false
    t.bigint "supervisor_id"
    t.integer "pid", null: false
    t.string "hostname"
    t.text "metadata"
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.index ["last_heartbeat_at"], name: "index_solid_queue_processes_on_last_heartbeat_at"
    t.index ["name", "supervisor_id"], name: "index_solid_queue_processes_on_name_and_supervisor_id", unique: true
    t.index ["supervisor_id"], name: "index_solid_queue_processes_on_supervisor_id"
  end

  create_table "solid_queue_ready_executions", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.string "queue_name", null: false
    t.integer "priority", default: 0, null: false
    t.datetime "created_at", null: false
    t.index ["job_id"], name: "index_solid_queue_ready_executions_on_job_id", unique: true
    t.index ["priority", "job_id"], name: "index_solid_queue_poll_all"
    t.index ["queue_name", "priority", "job_id"], name: "index_solid_queue_poll_by_queue"
  end

  create_table "solid_queue_recurring_executions", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.string "task_key", null: false
    t.datetime "run_at", null: false
    t.datetime "created_at", null: false
    t.index ["job_id"], name: "index_solid_queue_recurring_executions_on_job_id", unique: true
    t.index ["task_key", "run_at"], name: "index_solid_queue_recurring_executions_on_task_key_and_run_at", unique: true
  end

  create_table "solid_queue_recurring_tasks", force: :cascade do |t|
    t.string "key", null: false
    t.string "schedule", null: false
    t.string "command", limit: 2048
    t.string "class_name"
    t.text "arguments"
    t.string "queue_name"
    t.integer "priority", default: 0
    t.boolean "static", default: true, null: false
    t.text "description"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["key"], name: "index_solid_queue_recurring_tasks_on_key", unique: true
    t.index ["static"], name: "index_solid_queue_recurring_tasks_on_static"
  end

  create_table "solid_queue_scheduled_executions", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.string "queue_name", null: false
    t.integer "priority", default: 0, null: false
    t.datetime "scheduled_at", null: false
    t.datetime "created_at", null: false
    t.index ["job_id"], name: "index_solid_queue_scheduled_executions_on_job_id", unique: true
    t.index ["scheduled_at", "priority", "job_id"], name: "index_solid_queue_dispatch_all"
  end

  create_table "solid_queue_semaphores", force: :cascade do |t|
    t.string "key", null: false
    t.integer "value", default: 1, null: false
    t.datetime "expires_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["expires_at"], name: "index_solid_queue_semaphores_on_expires_at"
    t.index ["key", "value"], name: "index_solid_queue_semaphores_on_key_and_value"
    t.index ["key"], name: "index_solid_queue_semaphores_on_key", unique: true
  end

  create_table "templates", force: :cascade do |t|
    t.string "name", null: false
    t.string "template_type", null: false
    t.string "category"
    t.json "template_data", default: {}, null: false
    t.boolean "is_active", default: true, null: false
    t.integer "usage_count", default: 0, null: false
    t.text "description"
    t.integer "version", default: 1, null: false
    t.integer "parent_template_id"
    t.string "author"
    t.json "variables", default: [], null: false
    t.json "metadata", default: {}, null: false
    t.datetime "published_at"
    t.string "tags"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "child_templates_count", default: 0, null: false
    t.index ["category"], name: "index_templates_on_category"
    t.index ["is_active", "template_type"], name: "index_templates_on_is_active_and_template_type"
    t.index ["is_active"], name: "index_templates_on_is_active"
    t.index ["name"], name: "index_templates_on_name"
    t.index ["parent_template_id", "version"], name: "index_templates_on_parent_and_version"
    t.index ["parent_template_id"], name: "index_templates_on_parent_template_id"
    t.index ["published_at"], name: "index_templates_on_published_at"
    t.index ["template_type", "category"], name: "index_templates_on_template_type_and_category"
    t.index ["template_type", "is_active", "usage_count"], name: "index_templates_on_type_active_usage"
    t.index ["template_type"], name: "index_templates_on_template_type"
    t.index ["usage_count"], name: "index_templates_on_usage_count"
    t.index ["version"], name: "index_templates_on_version"
  end

  create_table "workflow_assignments", force: :cascade do |t|
    t.integer "content_workflow_id", null: false
    t.integer "user_id"
    t.string "role"
    t.string "stage"
    t.integer "status"
    t.integer "assignment_type"
    t.datetime "assigned_at"
    t.integer "assigned_by_id"
    t.datetime "unassigned_at"
    t.integer "unassigned_by_id"
    t.datetime "expires_at"
    t.datetime "activated_at"
    t.integer "activated_by_id"
    t.datetime "suspended_at"
    t.integer "suspended_by_id"
    t.datetime "extended_at"
    t.integer "extended_by_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["content_workflow_id"], name: "index_workflow_assignments_on_content_workflow_id"
  end

  create_table "workflow_audit_entries", force: :cascade do |t|
    t.integer "content_workflow_id", null: false
    t.string "action"
    t.string "from_stage"
    t.string "to_stage"
    t.integer "performed_by_id"
    t.text "comment"
    t.text "metadata"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["content_workflow_id"], name: "index_workflow_audit_entries_on_content_workflow_id"
  end

  create_table "workflow_notifications", force: :cascade do |t|
    t.integer "user_id"
    t.integer "workflow_id", null: false
    t.string "notification_type"
    t.string "title"
    t.text "message"
    t.integer "priority"
    t.integer "status"
    t.datetime "read_at"
    t.datetime "clicked_at"
    t.integer "click_count"
    t.datetime "dismissed_at"
    t.datetime "archived_at"
    t.text "metadata"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["workflow_id"], name: "index_workflow_notifications_on_workflow_id"
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "ai_generation_requests", "campaigns"
  add_foreign_key "ai_job_statuses", "ai_generation_requests", column: "generation_request_id"
  add_foreign_key "brand_assets", "brand_assets", column: "parent_asset_id"
  add_foreign_key "campaigns", "brand_identities"
  add_foreign_key "content_branches", "content_versions", column: "head_version_id"
  add_foreign_key "content_branches", "content_versions", column: "source_version_id"
  add_foreign_key "content_merges", "content_branches", column: "source_branch_id"
  add_foreign_key "content_merges", "content_branches", column: "target_branch_id"
  add_foreign_key "content_merges", "content_versions", column: "source_version_id"
  add_foreign_key "content_merges", "content_versions", column: "target_version_id"
  add_foreign_key "content_responses", "content_requests"
  add_foreign_key "content_schedules", "campaigns"
  add_foreign_key "content_variants", "content_requests"
  add_foreign_key "content_versions", "content_branches", column: "branch_id"
  add_foreign_key "content_versions", "content_versions", column: "parent_id"
  add_foreign_key "customer_journeys", "campaigns"
  add_foreign_key "journey_stages", "journeys"
  add_foreign_key "journey_templates", "journey_templates", column: "parent_template_id"
  add_foreign_key "journeys", "campaigns"
  add_foreign_key "prompt_templates", "prompt_templates", column: "parent_template_id"
  add_foreign_key "publishing_queues", "content_schedules"
  add_foreign_key "solid_queue_blocked_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_claimed_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_failed_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_ready_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_recurring_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_scheduled_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "templates", "templates", column: "parent_template_id"
  add_foreign_key "workflow_assignments", "content_workflows"
  add_foreign_key "workflow_audit_entries", "content_workflows"
  add_foreign_key "workflow_notifications", "content_workflows", column: "workflow_id"
end
