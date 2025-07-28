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

ActiveRecord::Schema[8.0].define(version: 2025_07_27_234731) do
  create_table "ab_test_variants", force: :cascade do |t|
    t.integer "ab_test_id", null: false
    t.integer "journey_id", null: false
    t.string "name", null: false
    t.text "description"
    t.string "variant_type", default: "treatment", null: false
    t.decimal "traffic_percentage", precision: 5, scale: 2, default: "50.0"
    t.boolean "is_control", default: false
    t.integer "total_visitors", default: 0
    t.integer "conversions", default: 0
    t.decimal "conversion_rate", precision: 5, scale: 2, default: "0.0"
    t.decimal "confidence_interval", precision: 5, scale: 2, default: "0.0"
    t.json "metadata", default: {}
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["ab_test_id", "is_control"], name: "index_ab_test_variants_on_ab_test_id_and_is_control"
    t.index ["ab_test_id", "name"], name: "index_ab_test_variants_on_ab_test_id_and_name", unique: true
    t.index ["ab_test_id"], name: "index_ab_test_variants_on_ab_test_id"
    t.index ["conversion_rate"], name: "index_ab_test_variants_on_conversion_rate"
    t.index ["journey_id"], name: "index_ab_test_variants_on_journey_id"
    t.index ["traffic_percentage"], name: "index_ab_test_variants_on_traffic_percentage"
    t.index ["variant_type"], name: "index_ab_test_variants_on_variant_type"
  end

  create_table "ab_tests", force: :cascade do |t|
    t.integer "campaign_id", null: false
    t.integer "user_id", null: false
    t.string "name", null: false
    t.text "description"
    t.text "hypothesis"
    t.string "test_type", default: "conversion", null: false
    t.string "status", default: "draft", null: false
    t.decimal "confidence_level", precision: 5, scale: 2, default: "95.0"
    t.decimal "significance_threshold", precision: 5, scale: 2, default: "5.0"
    t.datetime "start_date"
    t.datetime "end_date"
    t.integer "winner_variant_id"
    t.json "metadata", default: {}
    t.json "settings", default: {}
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["campaign_id", "name"], name: "index_ab_tests_on_campaign_id_and_name", unique: true
    t.index ["campaign_id", "status"], name: "index_ab_tests_on_campaign_id_and_status"
    t.index ["campaign_id"], name: "index_ab_tests_on_campaign_id"
    t.index ["end_date"], name: "index_ab_tests_on_end_date"
    t.index ["start_date"], name: "index_ab_tests_on_start_date"
    t.index ["status"], name: "index_ab_tests_on_status"
    t.index ["test_type"], name: "index_ab_tests_on_test_type"
    t.index ["user_id", "status"], name: "index_ab_tests_on_user_id_and_status"
    t.index ["user_id"], name: "index_ab_tests_on_user_id"
  end

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

  create_table "activities", force: :cascade do |t|
    t.integer "user_id", null: false
    t.string "action", null: false
    t.string "controller", null: false
    t.string "request_path"
    t.string "request_method"
    t.string "ip_address"
    t.text "user_agent"
    t.string "session_id"
    t.integer "response_status"
    t.float "response_time"
    t.text "metadata"
    t.datetime "occurred_at", null: false
    t.string "referrer"
    t.boolean "suspicious", default: false
    t.string "device_type"
    t.string "browser_name"
    t.string "os_name"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["action"], name: "index_activities_on_action"
    t.index ["ip_address"], name: "index_activities_on_ip_address"
    t.index ["occurred_at"], name: "index_activities_on_occurred_at"
    t.index ["session_id"], name: "index_activities_on_session_id"
    t.index ["suspicious"], name: "index_activities_on_suspicious"
    t.index ["user_id", "occurred_at"], name: "index_activities_on_user_id_and_occurred_at"
    t.index ["user_id"], name: "index_activities_on_user_id"
  end

  create_table "admin_audit_logs", force: :cascade do |t|
    t.integer "user_id", null: false
    t.string "action"
    t.string "auditable_type"
    t.integer "auditable_id"
    t.text "change_details"
    t.string "ip_address"
    t.string "user_agent"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_admin_audit_logs_on_user_id"
  end

  create_table "campaigns", force: :cascade do |t|
    t.string "name", null: false
    t.text "description"
    t.integer "persona_id", null: false
    t.integer "user_id", null: false
    t.string "status", default: "draft", null: false
    t.string "campaign_type"
    t.text "goals"
    t.json "target_metrics", default: {}
    t.json "metadata", default: {}
    t.json "settings", default: {}
    t.datetime "started_at"
    t.datetime "ended_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["campaign_type"], name: "index_campaigns_on_campaign_type"
    t.index ["ended_at"], name: "index_campaigns_on_ended_at"
    t.index ["persona_id", "status"], name: "index_campaigns_on_persona_id_and_status"
    t.index ["persona_id"], name: "index_campaigns_on_persona_id"
    t.index ["started_at"], name: "index_campaigns_on_started_at"
    t.index ["user_id", "name"], name: "index_campaigns_on_user_id_and_name", unique: true
    t.index ["user_id", "status"], name: "index_campaigns_on_user_id_and_status"
    t.index ["user_id"], name: "index_campaigns_on_user_id"
  end

  create_table "conversion_funnels", force: :cascade do |t|
    t.integer "journey_id", null: false
    t.integer "campaign_id", null: false
    t.integer "user_id", null: false
    t.string "funnel_name", null: false
    t.string "stage", null: false
    t.integer "stage_order", null: false
    t.integer "visitors", default: 0
    t.integer "conversions", default: 0
    t.decimal "conversion_rate", precision: 5, scale: 2, default: "0.0"
    t.decimal "drop_off_rate", precision: 5, scale: 2, default: "0.0"
    t.datetime "period_start", null: false
    t.datetime "period_end", null: false
    t.json "metadata", default: {}
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["campaign_id", "period_start"], name: "index_conversion_funnels_on_campaign_id_and_period_start"
    t.index ["campaign_id"], name: "index_conversion_funnels_on_campaign_id"
    t.index ["conversion_rate"], name: "index_conversion_funnels_on_conversion_rate"
    t.index ["funnel_name", "stage_order"], name: "index_conversion_funnels_on_funnel_name_and_stage_order"
    t.index ["journey_id", "funnel_name", "stage_order"], name: "index_conversion_funnels_on_journey_funnel_stage"
    t.index ["journey_id"], name: "index_conversion_funnels_on_journey_id"
    t.index ["period_start"], name: "index_conversion_funnels_on_period_start"
    t.index ["stage"], name: "index_conversion_funnels_on_stage"
    t.index ["user_id", "period_start"], name: "index_conversion_funnels_on_user_id_and_period_start"
    t.index ["user_id"], name: "index_conversion_funnels_on_user_id"
  end

  create_table "journey_analytics", force: :cascade do |t|
    t.integer "journey_id", null: false
    t.integer "campaign_id", null: false
    t.integer "user_id", null: false
    t.datetime "period_start", null: false
    t.datetime "period_end", null: false
    t.integer "total_executions", default: 0
    t.integer "completed_executions", default: 0
    t.integer "abandoned_executions", default: 0
    t.float "average_completion_time", default: 0.0
    t.decimal "conversion_rate", precision: 5, scale: 2, default: "0.0"
    t.decimal "engagement_score", precision: 5, scale: 2, default: "0.0"
    t.json "metrics", default: {}
    t.json "metadata", default: {}
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["campaign_id", "period_start"], name: "index_journey_analytics_on_campaign_id_and_period_start"
    t.index ["campaign_id"], name: "index_journey_analytics_on_campaign_id"
    t.index ["conversion_rate"], name: "index_journey_analytics_on_conversion_rate"
    t.index ["engagement_score"], name: "index_journey_analytics_on_engagement_score"
    t.index ["journey_id", "period_start"], name: "index_journey_analytics_on_journey_id_and_period_start"
    t.index ["journey_id"], name: "index_journey_analytics_on_journey_id"
    t.index ["period_end"], name: "index_journey_analytics_on_period_end"
    t.index ["period_start"], name: "index_journey_analytics_on_period_start"
    t.index ["user_id", "period_start"], name: "index_journey_analytics_on_user_id_and_period_start"
    t.index ["user_id"], name: "index_journey_analytics_on_user_id"
  end

  create_table "journey_executions", force: :cascade do |t|
    t.integer "journey_id", null: false
    t.integer "user_id", null: false
    t.integer "current_step_id"
    t.string "status", default: "initialized", null: false
    t.datetime "started_at"
    t.datetime "completed_at"
    t.datetime "paused_at"
    t.json "execution_context", default: {}
    t.json "metadata", default: {}
    t.text "completion_notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["completed_at"], name: "index_journey_executions_on_completed_at"
    t.index ["current_step_id"], name: "index_journey_executions_on_current_step_id"
    t.index ["journey_id"], name: "index_journey_executions_on_journey_id"
    t.index ["started_at"], name: "index_journey_executions_on_started_at"
    t.index ["status"], name: "index_journey_executions_on_status"
    t.index ["user_id", "journey_id"], name: "index_journey_executions_on_user_id_and_journey_id", unique: true
    t.index ["user_id"], name: "index_journey_executions_on_user_id"
  end

  create_table "journey_insights", force: :cascade do |t|
    t.integer "journey_id", null: false
    t.string "insights_type", null: false
    t.json "data", default: {}
    t.datetime "calculated_at", null: false
    t.datetime "expires_at"
    t.json "metadata", default: {}
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["calculated_at"], name: "index_journey_insights_on_calculated_at"
    t.index ["created_at"], name: "index_journey_insights_on_created_at"
    t.index ["expires_at"], name: "index_journey_insights_on_expires_at"
    t.index ["insights_type"], name: "index_journey_insights_on_insights_type"
    t.index ["journey_id", "insights_type"], name: "index_journey_insights_on_journey_id_and_insights_type"
    t.index ["journey_id"], name: "index_journey_insights_on_journey_id"
  end

  create_table "journey_metrics", force: :cascade do |t|
    t.integer "journey_id", null: false
    t.integer "campaign_id", null: false
    t.integer "user_id", null: false
    t.string "metric_name", null: false
    t.decimal "metric_value", precision: 10, scale: 4, default: "0.0"
    t.string "metric_type", null: false
    t.string "aggregation_period", null: false
    t.datetime "calculated_at", null: false
    t.json "metadata", default: {}
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["aggregation_period"], name: "index_journey_metrics_on_aggregation_period"
    t.index ["calculated_at"], name: "index_journey_metrics_on_calculated_at"
    t.index ["campaign_id", "metric_name"], name: "index_journey_metrics_on_campaign_id_and_metric_name"
    t.index ["campaign_id"], name: "index_journey_metrics_on_campaign_id"
    t.index ["journey_id", "metric_name", "aggregation_period"], name: "index_journey_metrics_on_journey_metric_period"
    t.index ["journey_id"], name: "index_journey_metrics_on_journey_id"
    t.index ["metric_name", "calculated_at"], name: "index_journey_metrics_on_metric_name_and_calculated_at"
    t.index ["metric_type"], name: "index_journey_metrics_on_metric_type"
    t.index ["user_id", "calculated_at"], name: "index_journey_metrics_on_user_id_and_calculated_at"
    t.index ["user_id"], name: "index_journey_metrics_on_user_id"
  end

  create_table "journey_steps", force: :cascade do |t|
    t.integer "journey_id", null: false
    t.string "name", null: false
    t.text "description"
    t.string "stage", null: false
    t.integer "position", default: 0, null: false
    t.string "content_type"
    t.string "channel"
    t.integer "duration_days", default: 1
    t.json "config", default: {}
    t.json "conditions", default: {}
    t.json "metadata", default: {}
    t.boolean "is_entry_point", default: false
    t.boolean "is_exit_point", default: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["channel"], name: "index_journey_steps_on_channel"
    t.index ["content_type"], name: "index_journey_steps_on_content_type"
    t.index ["journey_id", "position"], name: "index_journey_steps_on_journey_id_and_position"
    t.index ["journey_id", "stage"], name: "index_journey_steps_on_journey_id_and_stage"
    t.index ["journey_id"], name: "index_journey_steps_on_journey_id"
    t.index ["stage"], name: "index_journey_steps_on_stage"
  end

  create_table "journey_templates", force: :cascade do |t|
    t.string "name", null: false
    t.text "description"
    t.string "category", null: false
    t.string "campaign_type"
    t.boolean "is_active", default: true
    t.integer "usage_count", default: 0
    t.json "template_data", default: {}
    t.json "metadata", default: {}
    t.string "thumbnail_url"
    t.integer "estimated_duration_days"
    t.string "difficulty_level"
    t.text "best_practices"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.decimal "version", precision: 5, scale: 2, default: "1.0", null: false
    t.integer "original_template_id"
    t.decimal "parent_version", precision: 5, scale: 2
    t.text "version_notes"
    t.boolean "is_published_version", default: true, null: false
    t.index ["campaign_type"], name: "index_journey_templates_on_campaign_type"
    t.index ["category", "is_active"], name: "index_journey_templates_on_category_and_is_active"
    t.index ["category"], name: "index_journey_templates_on_category"
    t.index ["is_active"], name: "index_journey_templates_on_is_active"
    t.index ["is_published_version"], name: "index_journey_templates_on_is_published_version"
    t.index ["original_template_id", "version"], name: "index_journey_templates_on_original_template_id_and_version", unique: true
    t.index ["original_template_id"], name: "index_journey_templates_on_original_template_id"
    t.index ["usage_count"], name: "index_journey_templates_on_usage_count"
  end

  create_table "journeys", force: :cascade do |t|
    t.integer "user_id", null: false
    t.string "name", null: false
    t.text "description"
    t.string "status", default: "draft", null: false
    t.string "brand_id"
    t.string "campaign_type"
    t.text "target_audience"
    t.text "goals"
    t.json "metadata", default: {}
    t.json "settings", default: {}
    t.datetime "published_at"
    t.datetime "archived_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "campaign_id"
    t.index ["brand_id"], name: "index_journeys_on_brand_id"
    t.index ["campaign_id", "status"], name: "index_journeys_on_campaign_id_and_status"
    t.index ["campaign_id"], name: "index_journeys_on_campaign_id"
    t.index ["campaign_type"], name: "index_journeys_on_campaign_type"
    t.index ["published_at"], name: "index_journeys_on_published_at"
    t.index ["status"], name: "index_journeys_on_status"
    t.index ["user_id", "status"], name: "index_journeys_on_user_id_and_status"
    t.index ["user_id"], name: "index_journeys_on_user_id"
  end

  create_table "personas", force: :cascade do |t|
    t.string "name", null: false
    t.text "description"
    t.json "demographics", default: {}
    t.json "behaviors", default: {}
    t.json "preferences", default: {}
    t.json "psychographics", default: {}
    t.integer "user_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_personas_on_name"
    t.index ["user_id", "name"], name: "index_personas_on_user_id_and_name", unique: true
    t.index ["user_id"], name: "index_personas_on_user_id"
  end

  create_table "sessions", force: :cascade do |t|
    t.integer "user_id", null: false
    t.string "ip_address"
    t.string "user_agent"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "last_active_at", default: -> { "CURRENT_TIMESTAMP" }
    t.datetime "expires_at", default: -> { "CURRENT_TIMESTAMP" }, null: false
    t.index ["expires_at"], name: "index_sessions_on_expires_at"
    t.index ["user_id"], name: "index_sessions_on_user_id"
  end

  create_table "step_executions", force: :cascade do |t|
    t.integer "journey_execution_id", null: false
    t.integer "journey_step_id", null: false
    t.datetime "started_at"
    t.datetime "completed_at"
    t.string "status", default: "pending"
    t.json "context", default: {}
    t.json "result_data", default: {}
    t.text "notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["journey_execution_id", "journey_step_id"], name: "index_step_executions_on_execution_and_step"
    t.index ["journey_execution_id"], name: "index_step_executions_on_journey_execution_id"
    t.index ["journey_step_id"], name: "index_step_executions_on_journey_step_id"
    t.index ["started_at"], name: "index_step_executions_on_started_at"
    t.index ["status"], name: "index_step_executions_on_status"
  end

  create_table "step_transitions", force: :cascade do |t|
    t.integer "from_step_id", null: false
    t.integer "to_step_id", null: false
    t.json "conditions", default: {}
    t.integer "priority", default: 0
    t.string "transition_type", default: "sequential"
    t.json "metadata", default: {}
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["from_step_id", "to_step_id"], name: "index_step_transitions_on_from_step_id_and_to_step_id", unique: true
    t.index ["from_step_id"], name: "index_step_transitions_on_from_step_id"
    t.index ["priority"], name: "index_step_transitions_on_priority"
    t.index ["to_step_id"], name: "index_step_transitions_on_to_step_id"
    t.index ["transition_type"], name: "index_step_transitions_on_transition_type"
  end

  create_table "suggestion_feedbacks", force: :cascade do |t|
    t.integer "journey_id", null: false
    t.integer "journey_step_id", null: false
    t.integer "suggested_step_id"
    t.integer "user_id", null: false
    t.string "feedback_type", null: false
    t.integer "rating", limit: 1
    t.boolean "selected", default: false, null: false
    t.text "context"
    t.json "metadata", default: {}
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["created_at"], name: "index_suggestion_feedbacks_on_created_at"
    t.index ["journey_id", "user_id"], name: "index_suggestion_feedbacks_on_journey_id_and_user_id"
    t.index ["journey_id"], name: "index_suggestion_feedbacks_on_journey_id"
    t.index ["journey_step_id", "feedback_type"], name: "idx_on_journey_step_id_feedback_type_3de956939d"
    t.index ["journey_step_id"], name: "index_suggestion_feedbacks_on_journey_step_id"
    t.index ["rating"], name: "index_suggestion_feedbacks_on_rating"
    t.index ["selected"], name: "index_suggestion_feedbacks_on_selected"
    t.index ["suggested_step_id"], name: "index_suggestion_feedbacks_on_suggested_step_id"
    t.index ["user_id"], name: "index_suggestion_feedbacks_on_user_id"
    t.check_constraint "rating >= 1 AND rating <= 5", name: "rating_range"
  end

  create_table "user_activities", force: :cascade do |t|
    t.integer "user_id", null: false
    t.string "action"
    t.string "controller_name"
    t.string "action_name"
    t.string "resource_type"
    t.integer "resource_id"
    t.string "ip_address"
    t.text "user_agent"
    t.text "request_params"
    t.json "metadata"
    t.datetime "performed_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_user_activities_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "email_address", null: false
    t.string "password_digest", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "role", default: 0, null: false
    t.string "full_name"
    t.text "bio"
    t.string "phone_number"
    t.string "company"
    t.string "job_title"
    t.string "timezone", default: "UTC"
    t.boolean "notification_email", default: true, null: false
    t.boolean "notification_marketing", default: true, null: false
    t.boolean "notification_product", default: true, null: false
    t.datetime "locked_at"
    t.string "lock_reason"
    t.datetime "suspended_at"
    t.text "suspension_reason"
    t.integer "suspended_by_id"
    t.index ["email_address"], name: "index_users_on_email_address", unique: true
    t.index ["role"], name: "index_users_on_role"
    t.index ["suspended_at"], name: "index_users_on_suspended_at"
  end

  add_foreign_key "ab_test_variants", "ab_tests"
  add_foreign_key "ab_test_variants", "journeys"
  add_foreign_key "ab_tests", "campaigns"
  add_foreign_key "ab_tests", "users"
  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "activities", "users"
  add_foreign_key "admin_audit_logs", "users"
  add_foreign_key "campaigns", "personas"
  add_foreign_key "campaigns", "users"
  add_foreign_key "conversion_funnels", "campaigns"
  add_foreign_key "conversion_funnels", "journeys"
  add_foreign_key "conversion_funnels", "users"
  add_foreign_key "journey_analytics", "campaigns"
  add_foreign_key "journey_analytics", "journeys"
  add_foreign_key "journey_analytics", "users"
  add_foreign_key "journey_executions", "journey_steps", column: "current_step_id"
  add_foreign_key "journey_executions", "journeys"
  add_foreign_key "journey_executions", "users"
  add_foreign_key "journey_insights", "journeys"
  add_foreign_key "journey_metrics", "campaigns"
  add_foreign_key "journey_metrics", "journeys"
  add_foreign_key "journey_metrics", "users"
  add_foreign_key "journey_steps", "journeys"
  add_foreign_key "journey_templates", "journey_templates", column: "original_template_id"
  add_foreign_key "journeys", "campaigns"
  add_foreign_key "journeys", "users"
  add_foreign_key "personas", "users"
  add_foreign_key "sessions", "users"
  add_foreign_key "step_executions", "journey_executions"
  add_foreign_key "step_executions", "journey_steps"
  add_foreign_key "step_transitions", "journey_steps", column: "from_step_id"
  add_foreign_key "step_transitions", "journey_steps", column: "to_step_id"
  add_foreign_key "suggestion_feedbacks", "journey_steps"
  add_foreign_key "suggestion_feedbacks", "journeys"
  add_foreign_key "suggestion_feedbacks", "users"
  add_foreign_key "user_activities", "users"
  add_foreign_key "users", "users", column: "suspended_by_id"
end
