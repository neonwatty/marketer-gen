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

ActiveRecord::Schema[8.0].define(version: 2025_08_02_235252) do
  create_table "ab_test_configurations", force: :cascade do |t|
    t.integer "ab_test_id", null: false
    t.string "configuration_type"
    t.json "settings"
    t.boolean "is_active"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["ab_test_id"], name: "index_ab_test_configurations_on_ab_test_id"
  end

  create_table "ab_test_metrics", force: :cascade do |t|
    t.integer "ab_test_id", null: false
    t.string "metric_name"
    t.decimal "value"
    t.datetime "timestamp"
    t.json "metadata"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["ab_test_id"], name: "index_ab_test_metrics_on_ab_test_id"
  end

  create_table "ab_test_recommendations", force: :cascade do |t|
    t.integer "ab_test_id", null: false
    t.string "recommendation_type"
    t.text "content"
    t.decimal "confidence_score"
    t.string "status"
    t.json "metadata"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["ab_test_id"], name: "index_ab_test_recommendations_on_ab_test_id"
  end

  create_table "ab_test_results", force: :cascade do |t|
    t.integer "ab_test_id", null: false
    t.string "event_type"
    t.decimal "value"
    t.decimal "confidence"
    t.json "metadata"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["ab_test_id"], name: "index_ab_test_results_on_ab_test_id"
  end

  create_table "ab_test_templates", force: :cascade do |t|
    t.integer "user_id", null: false
    t.string "name"
    t.text "description"
    t.string "template_type"
    t.json "configuration"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_ab_test_templates_on_user_id"
  end

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

  create_table "alert_instances", force: :cascade do |t|
    t.integer "performance_alert_id", null: false
    t.string "status", default: "active", null: false
    t.string "severity", null: false
    t.decimal "triggered_value", precision: 15, scale: 6
    t.decimal "threshold_value", precision: 15, scale: 6
    t.json "trigger_context"
    t.json "metric_data"
    t.datetime "triggered_at", null: false
    t.datetime "acknowledged_at"
    t.datetime "resolved_at"
    t.datetime "snoozed_until"
    t.integer "acknowledged_by_id"
    t.integer "resolved_by_id"
    t.text "acknowledgment_note"
    t.text "resolution_note"
    t.json "notifications_sent"
    t.json "notification_failures"
    t.boolean "escalated", default: false
    t.datetime "escalation_sent_at"
    t.decimal "anomaly_score", precision: 5, scale: 4
    t.json "ml_prediction_data"
    t.boolean "false_positive", default: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["acknowledged_by_id"], name: "index_alert_instances_on_acknowledged_by_id"
    t.index ["escalated", "severity"], name: "index_alert_instances_on_escalated_and_severity"
    t.index ["performance_alert_id"], name: "index_alert_instances_on_performance_alert_id"
    t.index ["resolved_by_id"], name: "index_alert_instances_on_resolved_by_id"
    t.index ["snoozed_until", "status"], name: "index_alert_instances_on_snoozed_until_and_status"
    t.index ["status", "severity"], name: "index_alert_instances_on_status_and_severity"
    t.index ["triggered_at"], name: "index_alert_instances_on_triggered_at"
  end

  create_table "brand_analyses", force: :cascade do |t|
    t.integer "brand_id", null: false
    t.json "analysis_data", default: {}
    t.json "extracted_rules", default: {}
    t.json "voice_attributes", default: {}
    t.json "brand_values", default: []
    t.json "messaging_pillars", default: []
    t.json "visual_guidelines", default: {}
    t.string "analysis_status", default: "pending"
    t.datetime "analyzed_at"
    t.float "confidence_score"
    t.text "analysis_notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["analysis_status"], name: "index_brand_analyses_on_analysis_status"
    t.index ["brand_id", "created_at"], name: "index_brand_analyses_on_brand_id_and_created_at"
    t.index ["brand_id"], name: "index_brand_analyses_on_brand_id"
  end

  create_table "brand_assets", force: :cascade do |t|
    t.integer "brand_id", null: false
    t.string "asset_type", null: false
    t.json "metadata", default: {}
    t.string "original_filename"
    t.string "content_type"
    t.text "extracted_text"
    t.json "extracted_data", default: {}
    t.string "processing_status", default: "pending"
    t.datetime "processed_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "external_url"
    t.bigint "file_size"
    t.string "virus_scan_status", default: "pending"
    t.integer "upload_progress", default: 0
    t.integer "chunk_count"
    t.integer "chunks_uploaded", default: 0
    t.index ["asset_type"], name: "index_brand_assets_on_asset_type"
    t.index ["brand_id", "asset_type"], name: "index_brand_assets_on_brand_id_and_asset_type"
    t.index ["brand_id"], name: "index_brand_assets_on_brand_id"
    t.index ["external_url"], name: "index_brand_assets_on_external_url"
    t.index ["processing_status"], name: "index_brand_assets_on_processing_status"
    t.index ["virus_scan_status"], name: "index_brand_assets_on_virus_scan_status"
  end

  create_table "brand_guidelines", force: :cascade do |t|
    t.integer "brand_id", null: false
    t.string "rule_type", null: false
    t.text "rule_content", null: false
    t.integer "priority", default: 0
    t.string "category"
    t.boolean "active", default: true
    t.json "examples", default: {}
    t.json "metadata", default: {}
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["brand_id", "active"], name: "index_brand_guidelines_on_brand_id_and_active"
    t.index ["brand_id", "rule_type"], name: "index_brand_guidelines_on_brand_id_and_rule_type"
    t.index ["brand_id"], name: "index_brand_guidelines_on_brand_id"
    t.index ["category"], name: "index_brand_guidelines_on_category"
    t.index ["priority"], name: "index_brand_guidelines_on_priority"
    t.index ["rule_type"], name: "index_brand_guidelines_on_rule_type"
  end

  create_table "brands", force: :cascade do |t|
    t.string "name", null: false
    t.text "description"
    t.integer "user_id", null: false
    t.json "settings", default: {}
    t.string "industry"
    t.string "website"
    t.json "color_scheme", default: {}
    t.json "typography", default: {}
    t.boolean "active", default: true
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["active"], name: "index_brands_on_active"
    t.index ["industry"], name: "index_brands_on_industry"
    t.index ["user_id", "name"], name: "index_brands_on_user_id_and_name", unique: true
    t.index ["user_id"], name: "index_brands_on_user_id"
  end

  create_table "campaign_intake_sessions", force: :cascade do |t|
    t.integer "user_id", null: false
    t.integer "campaign_id"
    t.string "thread_id", null: false
    t.string "status"
    t.json "context"
    t.json "messages"
    t.datetime "started_at"
    t.datetime "completed_at"
    t.float "estimated_completion_time"
    t.float "actual_completion_time"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["campaign_id"], name: "index_campaign_intake_sessions_on_campaign_id"
    t.index ["status"], name: "index_campaign_intake_sessions_on_status"
    t.index ["user_id", "thread_id"], name: "index_campaign_intake_sessions_on_user_id_and_thread_id", unique: true
    t.index ["user_id"], name: "index_campaign_intake_sessions_on_user_id"
  end

  create_table "campaign_plans", force: :cascade do |t|
    t.string "name"
    t.integer "campaign_id", null: false
    t.integer "user_id", null: false
    t.string "status"
    t.string "plan_type"
    t.text "strategic_rationale"
    t.text "target_audience"
    t.text "messaging_framework"
    t.text "channel_strategy"
    t.text "timeline_phases"
    t.text "success_metrics"
    t.text "budget_allocation"
    t.text "creative_approach"
    t.text "market_analysis"
    t.decimal "version"
    t.datetime "approved_at"
    t.integer "approved_by"
    t.datetime "rejected_at"
    t.integer "rejected_by"
    t.text "rejection_reason"
    t.datetime "submitted_at"
    t.datetime "archived_at"
    t.text "metadata"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["campaign_id"], name: "index_campaign_plans_on_campaign_id"
    t.index ["user_id"], name: "index_campaign_plans_on_user_id"
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

  create_table "compliance_results", force: :cascade do |t|
    t.integer "brand_id", null: false
    t.string "content_type"
    t.string "content_hash"
    t.boolean "compliant"
    t.decimal "score", precision: 5, scale: 3
    t.integer "violations_count", default: 0
    t.json "violations_data", default: []
    t.json "suggestions_data", default: []
    t.json "analysis_data", default: {}
    t.json "metadata", default: {}
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["brand_id", "content_type"], name: "index_compliance_results_on_brand_id_and_content_type"
    t.index ["brand_id"], name: "index_compliance_results_on_brand_id"
    t.index ["compliant"], name: "index_compliance_results_on_compliant"
    t.index ["content_hash"], name: "index_compliance_results_on_content_hash"
    t.index ["created_at"], name: "index_compliance_results_on_created_at"
  end

  create_table "content_approvals", force: :cascade do |t|
    t.integer "content_repository_id", null: false
    t.integer "workflow_id", null: false
    t.integer "user_id", null: false
    t.integer "assigned_approver_id", null: false
    t.integer "approval_step"
    t.integer "status"
    t.integer "step_order"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["assigned_approver_id"], name: "index_content_approvals_on_assigned_approver_id"
    t.index ["content_repository_id"], name: "index_content_approvals_on_content_repository_id"
    t.index ["user_id"], name: "index_content_approvals_on_user_id"
    t.index ["workflow_id"], name: "index_content_approvals_on_workflow_id"
  end

  create_table "content_archives", force: :cascade do |t|
    t.integer "content_repository_id", null: false
    t.integer "archived_by_id", null: false
    t.integer "restored_by_id", null: false
    t.text "archive_reason"
    t.integer "archive_level"
    t.integer "status"
    t.string "retention_period"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "storage_location"
    t.text "metadata_backup"
    t.string "metadata_backup_location"
    t.text "archived_content_body"
    t.datetime "retention_expires_at"
    t.datetime "restore_requested_at"
    t.text "restore_reason"
    t.datetime "restored_at"
    t.boolean "auto_delete_on_expiry"
    t.boolean "metadata_preservation"
    t.text "failure_reason"
    t.integer "retention_extended_by_id"
    t.datetime "retention_extended_at"
    t.text "retention_extension_reason"
    t.index ["archived_by_id"], name: "index_content_archives_on_archived_by_id"
    t.index ["content_repository_id"], name: "index_content_archives_on_content_repository_id"
    t.index ["restored_by_id"], name: "index_content_archives_on_restored_by_id"
    t.index ["retention_extended_by_id"], name: "index_content_archives_on_retention_extended_by_id"
  end

  create_table "content_categories", force: :cascade do |t|
    t.string "name"
    t.string "slug"
    t.text "description"
    t.integer "parent_id", null: false
    t.integer "hierarchy_level"
    t.string "hierarchy_path"
    t.boolean "active"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["parent_id"], name: "index_content_categories_on_parent_id"
  end

  create_table "content_permissions", force: :cascade do |t|
    t.integer "content_repository_id", null: false
    t.integer "user_id", null: false
    t.integer "permission_type"
    t.boolean "active"
    t.integer "granted_by_id", null: false
    t.integer "revoked_by_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["content_repository_id"], name: "index_content_permissions_on_content_repository_id"
    t.index ["granted_by_id"], name: "index_content_permissions_on_granted_by_id"
    t.index ["revoked_by_id"], name: "index_content_permissions_on_revoked_by_id"
    t.index ["user_id"], name: "index_content_permissions_on_user_id"
  end

  create_table "content_repositories", force: :cascade do |t|
    t.string "title", null: false
    t.text "body"
    t.integer "content_type", null: false
    t.integer "format", null: false
    t.string "storage_path", null: false
    t.string "file_hash", null: false
    t.integer "status", default: 0
    t.integer "user_id", null: false
    t.integer "campaign_id"
    t.integer "content_category_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["campaign_id"], name: "index_content_repositories_on_campaign_id"
    t.index ["content_category_id"], name: "index_content_repositories_on_content_category_id"
    t.index ["content_type", "status"], name: "index_content_repositories_on_content_type_and_status"
    t.index ["file_hash"], name: "index_content_repositories_on_file_hash", unique: true
    t.index ["user_id", "created_at"], name: "index_content_repositories_on_user_id_and_created_at"
    t.index ["user_id"], name: "index_content_repositories_on_user_id"
  end

  create_table "content_revisions", force: :cascade do |t|
    t.integer "content_repository_id", null: false
    t.integer "revised_by_id", null: false
    t.text "content_before"
    t.text "content_after"
    t.text "revision_reason"
    t.integer "revision_type"
    t.integer "status"
    t.integer "revision_number"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["content_repository_id"], name: "index_content_revisions_on_content_repository_id"
    t.index ["revised_by_id"], name: "index_content_revisions_on_revised_by_id"
  end

  create_table "content_tags", force: :cascade do |t|
    t.integer "content_repository_id", null: false
    t.integer "user_id", null: false
    t.string "tag_name"
    t.integer "tag_type"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["content_repository_id"], name: "index_content_tags_on_content_repository_id"
    t.index ["user_id"], name: "index_content_tags_on_user_id"
  end

  create_table "content_versions", force: :cascade do |t|
    t.integer "content_repository_id", null: false
    t.integer "author_id", null: false
    t.text "body", null: false
    t.integer "version_number", null: false
    t.string "commit_hash", null: false
    t.text "commit_message"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["author_id", "created_at"], name: "index_content_versions_on_author_id_and_created_at"
    t.index ["author_id"], name: "index_content_versions_on_author_id"
    t.index ["commit_hash"], name: "index_content_versions_on_commit_hash", unique: true
    t.index ["content_repository_id", "version_number"], name: "idx_on_content_repository_id_version_number_2ae3dc1c28", unique: true
    t.index ["content_repository_id"], name: "index_content_versions_on_content_repository_id"
  end

  create_table "content_workflows", force: :cascade do |t|
    t.integer "content_repository_id", null: false
    t.integer "created_by_id", null: false
    t.string "name"
    t.integer "status"
    t.boolean "parallel_approval"
    t.boolean "auto_progression"
    t.integer "step_timeout_hours"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["content_repository_id"], name: "index_content_workflows_on_content_repository_id"
    t.index ["created_by_id"], name: "index_content_workflows_on_created_by_id"
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

  create_table "crm_analytics", force: :cascade do |t|
    t.integer "crm_integration_id", null: false
    t.integer "brand_id", null: false
    t.date "analytics_date", null: false
    t.string "metric_type", limit: 100, null: false
    t.integer "total_leads"
    t.integer "new_leads"
    t.integer "marketing_qualified_leads"
    t.integer "sales_qualified_leads"
    t.integer "converted_leads"
    t.decimal "lead_conversion_rate", precision: 5, scale: 2
    t.decimal "mql_conversion_rate", precision: 5, scale: 2
    t.decimal "sql_conversion_rate", precision: 5, scale: 2
    t.integer "total_opportunities"
    t.integer "new_opportunities"
    t.integer "closed_opportunities"
    t.integer "won_opportunities"
    t.integer "lost_opportunities"
    t.decimal "opportunity_win_rate", precision: 5, scale: 2
    t.decimal "total_opportunity_value", precision: 15, scale: 2
    t.decimal "won_opportunity_value", precision: 15, scale: 2
    t.decimal "average_deal_size", precision: 15, scale: 2
    t.decimal "pipeline_velocity", precision: 10, scale: 2
    t.decimal "average_sales_cycle_days", precision: 8, scale: 2
    t.decimal "pipeline_value", precision: 15, scale: 2
    t.integer "pipeline_count"
    t.decimal "weighted_pipeline_value", precision: 15, scale: 2
    t.string "top_performing_campaign", limit: 255
    t.decimal "campaign_attributed_revenue", precision: 15, scale: 2
    t.integer "campaign_attributed_leads"
    t.integer "campaign_attributed_opportunities"
    t.json "attribution_breakdown"
    t.decimal "marketing_to_sales_conversion_rate", precision: 5, scale: 2
    t.decimal "lead_to_opportunity_conversion_rate", precision: 5, scale: 2
    t.decimal "opportunity_to_customer_conversion_rate", precision: 5, scale: 2
    t.decimal "overall_conversion_rate", precision: 5, scale: 2
    t.decimal "time_to_mql_hours", precision: 10, scale: 2
    t.decimal "time_to_sql_hours", precision: 10, scale: 2
    t.decimal "time_to_opportunity_hours", precision: 10, scale: 2
    t.decimal "time_to_close_hours", precision: 10, scale: 2
    t.json "channel_performance"
    t.json "source_performance"
    t.json "campaign_performance"
    t.json "lifecycle_stage_breakdown"
    t.json "stage_progression_metrics"
    t.json "raw_metrics"
    t.json "calculated_metrics"
    t.datetime "calculated_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["analytics_date"], name: "index_crm_analytics_on_analytics_date"
    t.index ["brand_id"], name: "index_crm_analytics_on_brand_id"
    t.index ["calculated_at"], name: "index_crm_analytics_on_calculated_at"
    t.index ["crm_integration_id", "analytics_date", "metric_type"], name: "idx_crm_analytics_unique", unique: true
    t.index ["crm_integration_id"], name: "index_crm_analytics_on_crm_integration_id"
    t.index ["metric_type"], name: "index_crm_analytics_on_metric_type"
  end

  create_table "crm_integrations", force: :cascade do |t|
    t.string "platform", limit: 50, null: false
    t.string "name", limit: 255, null: false
    t.text "description"
    t.integer "brand_id", null: false
    t.integer "user_id", null: false
    t.text "access_token_encrypted"
    t.text "refresh_token_encrypted"
    t.text "client_id_encrypted"
    t.text "client_secret_encrypted"
    t.text "additional_credentials_encrypted"
    t.datetime "token_expires_at"
    t.datetime "last_token_refresh_at"
    t.string "api_version", limit: 20
    t.string "instance_url", limit: 500
    t.string "sandbox_mode", default: "f"
    t.json "api_configuration"
    t.boolean "active", default: true
    t.string "status", limit: 50, default: "pending", null: false
    t.text "last_error_message"
    t.datetime "last_successful_sync_at"
    t.datetime "last_attempted_sync_at"
    t.integer "consecutive_error_count", default: 0
    t.datetime "rate_limit_reset_at"
    t.integer "rate_limit_remaining"
    t.integer "daily_api_calls", default: 0
    t.integer "monthly_api_calls", default: 0
    t.json "sync_configuration"
    t.json "field_mappings"
    t.datetime "last_sync_cursor"
    t.boolean "sync_leads", default: true
    t.boolean "sync_opportunities", default: true
    t.boolean "sync_contacts", default: true
    t.boolean "sync_accounts", default: true
    t.boolean "sync_campaigns", default: true
    t.integer "total_leads_synced", default: 0
    t.integer "total_opportunities_synced", default: 0
    t.integer "total_contacts_synced", default: 0
    t.bigint "total_revenue_tracked", default: 0
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["active"], name: "index_crm_integrations_on_active"
    t.index ["brand_id"], name: "index_crm_integrations_on_brand_id"
    t.index ["last_successful_sync_at"], name: "index_crm_integrations_on_last_successful_sync_at"
    t.index ["platform", "brand_id"], name: "index_crm_integrations_on_platform_and_brand_id", unique: true
    t.index ["rate_limit_reset_at"], name: "index_crm_integrations_on_rate_limit_reset_at"
    t.index ["status"], name: "index_crm_integrations_on_status"
    t.index ["user_id"], name: "index_crm_integrations_on_user_id"
  end

  create_table "crm_leads", force: :cascade do |t|
    t.integer "crm_integration_id", null: false
    t.integer "brand_id", null: false
    t.string "crm_id", limit: 255, null: false
    t.string "first_name", limit: 255
    t.string "last_name", limit: 255
    t.string "email", limit: 255
    t.string "phone", limit: 50
    t.string "company", limit: 255
    t.string "title", limit: 255
    t.string "status", limit: 100
    t.string "source", limit: 255
    t.text "description"
    t.string "lead_score", limit: 50
    t.string "lead_grade", limit: 10
    t.string "lifecycle_stage", limit: 100
    t.boolean "marketing_qualified", default: false
    t.boolean "sales_qualified", default: false
    t.datetime "mql_date"
    t.datetime "sql_date"
    t.string "original_source", limit: 255
    t.string "original_medium", limit: 255
    t.string "original_campaign", limit: 255
    t.string "first_touch_campaign_id", limit: 255
    t.string "last_touch_campaign_id", limit: 255
    t.json "utm_parameters"
    t.decimal "annual_revenue", precision: 15, scale: 2
    t.integer "number_of_employees"
    t.string "industry", limit: 255
    t.datetime "crm_created_at"
    t.datetime "crm_updated_at"
    t.datetime "last_synced_at"
    t.json "raw_data"
    t.json "custom_fields"
    t.boolean "converted", default: false
    t.datetime "converted_at"
    t.string "converted_contact_id", limit: 255
    t.string "converted_opportunity_id", limit: 255
    t.string "converted_account_id", limit: 255
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["brand_id"], name: "index_crm_leads_on_brand_id"
    t.index ["converted"], name: "index_crm_leads_on_converted"
    t.index ["crm_integration_id", "crm_id"], name: "index_crm_leads_on_crm_integration_id_and_crm_id", unique: true
    t.index ["crm_integration_id"], name: "index_crm_leads_on_crm_integration_id"
    t.index ["email"], name: "index_crm_leads_on_email"
    t.index ["last_synced_at"], name: "index_crm_leads_on_last_synced_at"
    t.index ["lifecycle_stage"], name: "index_crm_leads_on_lifecycle_stage"
    t.index ["marketing_qualified"], name: "index_crm_leads_on_marketing_qualified"
    t.index ["original_campaign"], name: "index_crm_leads_on_original_campaign"
    t.index ["sales_qualified"], name: "index_crm_leads_on_sales_qualified"
    t.index ["status"], name: "index_crm_leads_on_status"
  end

  create_table "crm_opportunities", force: :cascade do |t|
    t.integer "crm_integration_id", null: false
    t.integer "brand_id", null: false
    t.string "crm_id", limit: 255, null: false
    t.string "name", limit: 500, null: false
    t.string "account_name", limit: 255
    t.string "account_id", limit: 255
    t.string "contact_id", limit: 255
    t.string "lead_id", limit: 255
    t.text "description"
    t.decimal "amount", precision: 15, scale: 2
    t.string "currency", limit: 10, default: "USD"
    t.string "stage", limit: 100
    t.string "type", limit: 100
    t.decimal "probability", precision: 5, scale: 2
    t.date "close_date"
    t.date "expected_close_date"
    t.string "pipeline_id", limit: 255
    t.string "pipeline_name", limit: 255
    t.integer "stage_order"
    t.datetime "stage_changed_at"
    t.string "previous_stage", limit: 100
    t.integer "days_in_current_stage"
    t.integer "total_days_in_pipeline"
    t.string "lead_source", limit: 255
    t.string "original_source", limit: 255
    t.string "original_medium", limit: 255
    t.string "original_campaign", limit: 255
    t.string "first_touch_campaign_id", limit: 255
    t.string "last_touch_campaign_id", limit: 255
    t.json "utm_parameters"
    t.string "owner_id", limit: 255
    t.string "owner_name", limit: 255
    t.string "team_id", limit: 255
    t.string "team_name", limit: 255
    t.boolean "is_closed", default: false
    t.boolean "is_won", default: false
    t.datetime "closed_at"
    t.string "close_reason", limit: 255
    t.string "lost_reason", limit: 255
    t.datetime "crm_created_at"
    t.datetime "crm_updated_at"
    t.datetime "last_synced_at"
    t.json "raw_data"
    t.json "custom_fields"
    t.integer "days_to_close"
    t.decimal "conversion_rate", precision: 5, scale: 2
    t.integer "pipeline_velocity_score"
    t.decimal "deal_size_score", precision: 5, scale: 2
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["amount"], name: "index_crm_opportunities_on_amount"
    t.index ["brand_id"], name: "index_crm_opportunities_on_brand_id"
    t.index ["close_date"], name: "index_crm_opportunities_on_close_date"
    t.index ["crm_integration_id", "crm_id"], name: "index_crm_opportunities_on_crm_integration_id_and_crm_id", unique: true
    t.index ["crm_integration_id"], name: "index_crm_opportunities_on_crm_integration_id"
    t.index ["is_closed"], name: "index_crm_opportunities_on_is_closed"
    t.index ["is_won"], name: "index_crm_opportunities_on_is_won"
    t.index ["last_synced_at"], name: "index_crm_opportunities_on_last_synced_at"
    t.index ["lead_source"], name: "index_crm_opportunities_on_lead_source"
    t.index ["original_campaign"], name: "index_crm_opportunities_on_original_campaign"
    t.index ["owner_id"], name: "index_crm_opportunities_on_owner_id"
    t.index ["pipeline_id"], name: "index_crm_opportunities_on_pipeline_id"
    t.index ["stage"], name: "index_crm_opportunities_on_stage"
  end

  create_table "email_automations", force: :cascade do |t|
    t.integer "email_integration_id", null: false
    t.string "platform_automation_id", null: false
    t.string "name", null: false
    t.string "automation_type"
    t.string "status", null: false
    t.string "trigger_type"
    t.text "trigger_configuration"
    t.integer "total_subscribers", default: 0
    t.integer "active_subscribers", default: 0
    t.text "configuration"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["automation_type"], name: "index_email_automations_on_automation_type"
    t.index ["email_integration_id", "platform_automation_id"], name: "idx_email_automations_integration_platform", unique: true
    t.index ["email_integration_id"], name: "index_email_automations_on_email_integration_id"
    t.index ["status"], name: "index_email_automations_on_status"
    t.index ["trigger_type"], name: "index_email_automations_on_trigger_type"
  end

  create_table "email_campaigns", force: :cascade do |t|
    t.integer "email_integration_id", null: false
    t.string "platform_campaign_id", null: false
    t.string "name", null: false
    t.string "subject"
    t.string "status", null: false
    t.string "campaign_type"
    t.string "list_id"
    t.string "template_id"
    t.datetime "send_time"
    t.string "created_by"
    t.integer "total_recipients", default: 0
    t.text "configuration"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["campaign_type"], name: "index_email_campaigns_on_campaign_type"
    t.index ["created_at"], name: "index_email_campaigns_on_created_at"
    t.index ["email_integration_id", "platform_campaign_id"], name: "idx_email_campaigns_integration_platform", unique: true
    t.index ["email_integration_id"], name: "index_email_campaigns_on_email_integration_id"
    t.index ["send_time"], name: "index_email_campaigns_on_send_time"
    t.index ["status"], name: "index_email_campaigns_on_status"
  end

  create_table "email_integrations", force: :cascade do |t|
    t.integer "brand_id", null: false
    t.string "platform", null: false
    t.string "status", default: "pending", null: false
    t.text "access_token"
    t.text "refresh_token"
    t.datetime "expires_at"
    t.string "platform_account_id"
    t.string "account_name"
    t.text "configuration"
    t.string "api_endpoint"
    t.string "webhook_secret"
    t.datetime "last_sync_at"
    t.integer "error_count", default: 0
    t.datetime "rate_limit_reset_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["brand_id", "platform"], name: "index_email_integrations_on_brand_id_and_platform", unique: true
    t.index ["brand_id"], name: "index_email_integrations_on_brand_id"
    t.index ["expires_at"], name: "index_email_integrations_on_expires_at"
    t.index ["last_sync_at"], name: "index_email_integrations_on_last_sync_at"
    t.index ["platform"], name: "index_email_integrations_on_platform"
    t.index ["status"], name: "index_email_integrations_on_status"
  end

  create_table "email_metrics", force: :cascade do |t|
    t.integer "email_integration_id", null: false
    t.integer "email_campaign_id", null: false
    t.string "metric_type", null: false
    t.date "metric_date", null: false
    t.integer "opens", default: 0
    t.integer "clicks", default: 0
    t.integer "bounces", default: 0
    t.integer "unsubscribes", default: 0
    t.integer "complaints", default: 0
    t.integer "delivered", default: 0
    t.integer "sent", default: 0
    t.integer "unique_opens", default: 0
    t.integer "unique_clicks", default: 0
    t.decimal "open_rate", precision: 5, scale: 4, default: "0.0"
    t.decimal "click_rate", precision: 5, scale: 4, default: "0.0"
    t.decimal "bounce_rate", precision: 5, scale: 4, default: "0.0"
    t.decimal "unsubscribe_rate", precision: 5, scale: 4, default: "0.0"
    t.decimal "complaint_rate", precision: 5, scale: 4, default: "0.0"
    t.decimal "delivery_rate", precision: 5, scale: 4, default: "0.0"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["email_campaign_id", "metric_date"], name: "index_email_metrics_on_email_campaign_id_and_metric_date", unique: true
    t.index ["email_campaign_id"], name: "index_email_metrics_on_email_campaign_id"
    t.index ["email_integration_id", "metric_date"], name: "index_email_metrics_on_email_integration_id_and_metric_date"
    t.index ["email_integration_id"], name: "index_email_metrics_on_email_integration_id"
    t.index ["metric_date"], name: "index_email_metrics_on_metric_date"
    t.index ["metric_type"], name: "index_email_metrics_on_metric_type"
  end

  create_table "email_subscribers", force: :cascade do |t|
    t.integer "email_integration_id", null: false
    t.string "platform_subscriber_id", null: false
    t.string "email", null: false
    t.string "first_name"
    t.string "last_name"
    t.string "status", null: false
    t.datetime "subscribed_at"
    t.datetime "unsubscribed_at"
    t.text "tags"
    t.text "segments"
    t.text "location"
    t.string "source"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_email_subscribers_on_email"
    t.index ["email_integration_id", "platform_subscriber_id"], name: "idx_email_subscribers_integration_platform", unique: true
    t.index ["email_integration_id"], name: "index_email_subscribers_on_email_integration_id"
    t.index ["source"], name: "index_email_subscribers_on_source"
    t.index ["status"], name: "index_email_subscribers_on_status"
    t.index ["subscribed_at"], name: "index_email_subscribers_on_subscribed_at"
  end

  create_table "etl_pipeline_runs", force: :cascade do |t|
    t.string "pipeline_id", null: false
    t.string "source", null: false
    t.string "status", null: false
    t.datetime "started_at", null: false
    t.datetime "completed_at"
    t.float "duration"
    t.text "error_message"
    t.json "error_backtrace"
    t.json "metrics"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["pipeline_id"], name: "index_etl_pipeline_runs_on_pipeline_id"
    t.index ["source", "started_at"], name: "index_etl_pipeline_runs_on_source_and_started_at"
    t.index ["source", "status"], name: "index_etl_pipeline_runs_on_source_and_status"
    t.index ["source"], name: "index_etl_pipeline_runs_on_source"
    t.index ["started_at", "status"], name: "index_etl_pipeline_runs_on_started_at_and_status"
    t.index ["started_at"], name: "index_etl_pipeline_runs_on_started_at"
    t.index ["status"], name: "index_etl_pipeline_runs_on_status"
  end

  create_table "google_analytics_metrics", force: :cascade do |t|
    t.date "date", null: false
    t.integer "sessions", default: 0
    t.integer "users", default: 0
    t.integer "new_users", default: 0
    t.integer "page_views", default: 0
    t.float "bounce_rate", default: 0.0
    t.float "avg_session_duration", default: 0.0
    t.integer "goal_completions", default: 0
    t.decimal "transaction_revenue", precision: 12, scale: 2, default: "0.0"
    t.json "dimension_data"
    t.json "raw_data"
    t.string "pipeline_id", null: false
    t.datetime "processed_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["date", "sessions"], name: "index_google_analytics_metrics_on_date_and_sessions"
    t.index ["date", "transaction_revenue"], name: "index_google_analytics_metrics_on_date_and_transaction_revenue"
    t.index ["date", "users"], name: "index_google_analytics_metrics_on_date_and_users"
    t.index ["date"], name: "index_google_analytics_metrics_on_date"
    t.index ["pipeline_id"], name: "index_google_analytics_metrics_on_pipeline_id"
    t.index ["processed_at"], name: "index_google_analytics_metrics_on_processed_at"
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
    t.integer "brand_id"
    t.index ["brand_id"], name: "index_journeys_on_brand_id"
    t.index ["campaign_id", "status"], name: "index_journeys_on_campaign_id_and_status"
    t.index ["campaign_id"], name: "index_journeys_on_campaign_id"
    t.index ["campaign_type"], name: "index_journeys_on_campaign_type"
    t.index ["published_at"], name: "index_journeys_on_published_at"
    t.index ["status"], name: "index_journeys_on_status"
    t.index ["user_id", "status"], name: "index_journeys_on_user_id_and_status"
    t.index ["user_id"], name: "index_journeys_on_user_id"
  end

  create_table "messaging_frameworks", force: :cascade do |t|
    t.integer "brand_id", null: false
    t.json "key_messages", default: {}
    t.json "value_propositions", default: {}
    t.json "terminology", default: {}
    t.text "tagline"
    t.text "mission_statement"
    t.text "vision_statement"
    t.json "approved_phrases", default: []
    t.json "banned_words", default: []
    t.json "tone_attributes", default: {}
    t.boolean "active", default: true
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["brand_id", "active"], name: "index_messaging_frameworks_on_brand_id_and_active"
    t.index ["brand_id"], name: "index_messaging_frameworks_on_brand_id"
  end

  create_table "notification_queues", force: :cascade do |t|
    t.integer "alert_instance_id", null: false
    t.integer "user_id", null: false
    t.string "channel", null: false
    t.string "status", default: "pending", null: false
    t.string "priority", default: "medium", null: false
    t.string "subject", null: false
    t.text "message", null: false
    t.json "template_data"
    t.string "template_name"
    t.string "recipient_address"
    t.json "channel_config"
    t.datetime "scheduled_for", null: false
    t.datetime "sent_at"
    t.integer "retry_count", default: 0
    t.integer "max_retries", default: 3
    t.datetime "next_retry_at"
    t.json "retry_schedule"
    t.string "external_id"
    t.json "delivery_status"
    t.text "failure_reason"
    t.json "delivery_metadata"
    t.string "batch_id"
    t.boolean "can_batch", default: true
    t.integer "batch_window_minutes", default: 5
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["alert_instance_id"], name: "index_notification_queues_on_alert_instance_id"
    t.index ["batch_id"], name: "index_notification_queues_on_batch_id"
    t.index ["channel", "status"], name: "index_notification_queues_on_channel_and_status"
    t.index ["external_id"], name: "index_notification_queues_on_external_id"
    t.index ["next_retry_at", "status"], name: "index_notification_queues_on_next_retry_at_and_status"
    t.index ["priority", "scheduled_for"], name: "index_notification_queues_on_priority_and_scheduled_for"
    t.index ["status", "scheduled_for"], name: "index_notification_queues_on_status_and_scheduled_for"
    t.index ["user_id"], name: "index_notification_queues_on_user_id"
  end

  create_table "performance_alerts", force: :cascade do |t|
    t.string "name", null: false
    t.text "description"
    t.string "metric_type", null: false
    t.string "metric_source", null: false
    t.string "alert_type", null: false
    t.string "severity", default: "medium", null: false
    t.string "status", default: "active", null: false
    t.decimal "threshold_value", precision: 15, scale: 6
    t.string "threshold_operator"
    t.integer "threshold_duration_minutes", default: 5
    t.boolean "use_ml_thresholds", default: false
    t.json "ml_model_config"
    t.decimal "anomaly_sensitivity", precision: 3, scale: 2, default: "0.95"
    t.integer "baseline_period_days", default: 30
    t.json "conditions"
    t.json "filters"
    t.json "notification_channels"
    t.json "notification_settings"
    t.integer "cooldown_minutes", default: 60
    t.integer "max_alerts_per_hour", default: 5
    t.integer "user_id", null: false
    t.integer "campaign_id"
    t.integer "journey_id"
    t.json "user_roles"
    t.json "metadata"
    t.datetime "last_triggered_at"
    t.datetime "last_checked_at"
    t.integer "trigger_count", default: 0
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["campaign_id"], name: "index_performance_alerts_on_campaign_id"
    t.index ["journey_id"], name: "index_performance_alerts_on_journey_id"
    t.index ["metric_type", "metric_source"], name: "index_performance_alerts_on_metric_type_and_metric_source"
    t.index ["severity"], name: "index_performance_alerts_on_severity"
    t.index ["status", "last_checked_at"], name: "index_performance_alerts_on_status_and_last_checked_at"
    t.index ["user_id"], name: "index_performance_alerts_on_user_id"
  end

  create_table "performance_thresholds", force: :cascade do |t|
    t.string "metric_type", null: false
    t.string "metric_source", null: false
    t.string "context_filters", null: false
    t.decimal "baseline_mean", precision: 15, scale: 6
    t.decimal "baseline_std_dev", precision: 15, scale: 6
    t.decimal "upper_threshold", precision: 15, scale: 6
    t.decimal "lower_threshold", precision: 15, scale: 6
    t.decimal "anomaly_threshold", precision: 15, scale: 6
    t.integer "sample_size"
    t.decimal "confidence_level", precision: 5, scale: 4, default: "0.95"
    t.datetime "baseline_start_date"
    t.datetime "baseline_end_date"
    t.datetime "last_recalculated_at"
    t.decimal "accuracy_score", precision: 5, scale: 4
    t.decimal "precision_score", precision: 5, scale: 4
    t.decimal "recall_score", precision: 5, scale: 4
    t.decimal "f1_score", precision: 5, scale: 4
    t.integer "true_positives", default: 0
    t.integer "false_positives", default: 0
    t.integer "true_negatives", default: 0
    t.integer "false_negatives", default: 0
    t.boolean "auto_adjust", default: true
    t.integer "recalculation_frequency_hours", default: 24
    t.decimal "learning_rate", precision: 5, scale: 4, default: "0.1"
    t.json "model_parameters"
    t.integer "campaign_id"
    t.integer "journey_id"
    t.string "audience_segment"
    t.string "time_of_day_segment"
    t.string "day_of_week_segment"
    t.string "seasonality_segment"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["accuracy_score", "metric_type"], name: "index_performance_thresholds_on_accuracy_score_and_metric_type"
    t.index ["campaign_id"], name: "index_performance_thresholds_on_campaign_id"
    t.index ["context_filters"], name: "index_performance_thresholds_on_context_filters"
    t.index ["journey_id"], name: "index_performance_thresholds_on_journey_id"
    t.index ["last_recalculated_at", "auto_adjust"], name: "idx_on_last_recalculated_at_auto_adjust_7ccd367fa2"
    t.index ["metric_type", "metric_source"], name: "index_performance_thresholds_on_metric_type_and_metric_source"
    t.check_constraint "confidence_level >= 0.5 AND confidence_level <= 1.0", name: "confidence_level_range"
    t.check_constraint "learning_rate >= 0.001 AND learning_rate <= 1.0", name: "learning_rate_range"
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

  create_table "plan_comments", force: :cascade do |t|
    t.integer "campaign_plan_id", null: false
    t.integer "user_id", null: false
    t.integer "parent_comment_id"
    t.text "content"
    t.string "section"
    t.string "comment_type"
    t.string "priority"
    t.integer "line_number"
    t.boolean "resolved"
    t.datetime "resolved_at"
    t.integer "resolved_by_user_id"
    t.text "mentioned_users"
    t.text "metadata"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["campaign_plan_id"], name: "index_plan_comments_on_campaign_plan_id"
    t.index ["parent_comment_id"], name: "index_plan_comments_on_parent_comment_id"
    t.index ["resolved_by_user_id"], name: "index_plan_comments_on_resolved_by_user_id"
    t.index ["user_id"], name: "index_plan_comments_on_user_id"
  end

  create_table "plan_revisions", force: :cascade do |t|
    t.integer "campaign_plan_id", null: false
    t.integer "user_id", null: false
    t.decimal "revision_number"
    t.text "plan_data"
    t.text "change_summary"
    t.text "changes_made"
    t.text "metadata"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["campaign_plan_id"], name: "index_plan_revisions_on_campaign_plan_id"
    t.index ["user_id"], name: "index_plan_revisions_on_user_id"
  end

  create_table "plan_templates", force: :cascade do |t|
    t.string "name"
    t.integer "user_id", null: false
    t.string "industry_type"
    t.string "template_type"
    t.text "description"
    t.text "template_data"
    t.text "default_channels"
    t.text "messaging_themes"
    t.text "success_metrics_template"
    t.boolean "active"
    t.boolean "is_public"
    t.text "metadata"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_plan_templates_on_user_id"
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

  create_table "social_media_integrations", force: :cascade do |t|
    t.integer "brand_id", null: false
    t.string "platform", null: false
    t.text "access_token"
    t.text "refresh_token"
    t.datetime "expires_at"
    t.text "scope"
    t.string "platform_account_id"
    t.string "status", default: "pending", null: false
    t.datetime "last_sync_at"
    t.integer "error_count", default: 0
    t.datetime "rate_limit_reset_at"
    t.text "configuration"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["brand_id", "platform"], name: "index_social_media_integrations_on_brand_id_and_platform", unique: true
    t.index ["brand_id"], name: "index_social_media_integrations_on_brand_id"
    t.index ["platform"], name: "index_social_media_integrations_on_platform"
    t.index ["platform_account_id"], name: "index_social_media_integrations_on_platform_account_id"
    t.index ["status"], name: "index_social_media_integrations_on_status"
  end

  create_table "social_media_metrics", force: :cascade do |t|
    t.integer "social_media_integration_id", null: false
    t.string "metric_type", null: false
    t.string "platform", null: false
    t.decimal "value", precision: 15, scale: 2
    t.date "date", null: false
    t.text "raw_data"
    t.text "metadata"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["date"], name: "index_social_media_metrics_on_date"
    t.index ["metric_type"], name: "index_social_media_metrics_on_metric_type"
    t.index ["platform", "date"], name: "index_social_media_metrics_on_platform_and_date"
    t.index ["platform"], name: "index_social_media_metrics_on_platform"
    t.index ["social_media_integration_id", "metric_type", "date"], name: "index_social_media_metrics_unique", unique: true
    t.index ["social_media_integration_id"], name: "index_social_media_metrics_on_social_media_integration_id"
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

  add_foreign_key "ab_test_configurations", "ab_tests"
  add_foreign_key "ab_test_metrics", "ab_tests"
  add_foreign_key "ab_test_recommendations", "ab_tests"
  add_foreign_key "ab_test_results", "ab_tests"
  add_foreign_key "ab_test_templates", "users"
  add_foreign_key "ab_test_variants", "ab_tests"
  add_foreign_key "ab_test_variants", "journeys"
  add_foreign_key "ab_tests", "campaigns"
  add_foreign_key "ab_tests", "users"
  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "activities", "users"
  add_foreign_key "admin_audit_logs", "users"
  add_foreign_key "alert_instances", "performance_alerts"
  add_foreign_key "alert_instances", "users", column: "acknowledged_by_id"
  add_foreign_key "alert_instances", "users", column: "resolved_by_id"
  add_foreign_key "brand_analyses", "brands"
  add_foreign_key "brand_assets", "brands"
  add_foreign_key "brand_guidelines", "brands"
  add_foreign_key "brands", "users"
  add_foreign_key "campaign_intake_sessions", "campaigns"
  add_foreign_key "campaign_intake_sessions", "users"
  add_foreign_key "campaign_plans", "campaigns"
  add_foreign_key "campaign_plans", "users"
  add_foreign_key "campaigns", "personas"
  add_foreign_key "campaigns", "users"
  add_foreign_key "compliance_results", "brands"
  add_foreign_key "content_archives", "users", column: "retention_extended_by_id"
  add_foreign_key "crm_analytics", "brands"
  add_foreign_key "crm_analytics", "crm_integrations"
  add_foreign_key "crm_integrations", "brands"
  add_foreign_key "crm_integrations", "users"
  add_foreign_key "crm_leads", "brands"
  add_foreign_key "crm_leads", "crm_integrations"
  add_foreign_key "crm_opportunities", "brands"
  add_foreign_key "crm_opportunities", "crm_integrations"
  add_foreign_key "email_automations", "email_integrations"
  add_foreign_key "email_campaigns", "email_integrations"
  add_foreign_key "email_integrations", "brands"
  add_foreign_key "email_metrics", "email_campaigns"
  add_foreign_key "email_metrics", "email_integrations"
  add_foreign_key "email_subscribers", "email_integrations"
  add_foreign_key "notification_queues", "alert_instances"
  add_foreign_key "notification_queues", "users"
  add_foreign_key "performance_alerts", "campaigns"
  add_foreign_key "performance_alerts", "journeys"
  add_foreign_key "performance_alerts", "users"
  add_foreign_key "performance_thresholds", "campaigns"
  add_foreign_key "performance_thresholds", "journeys"
  add_foreign_key "social_media_integrations", "brands"
  add_foreign_key "social_media_metrics", "social_media_integrations"
end
