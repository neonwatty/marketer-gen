FactoryBot.define do
  factory :content_repository do
    association :user
    
    title { "Test Content Repository" }
    body { "Repository for test content items" }
    content_type { 0 }  # email_template
    format { 0 }        # text format
    storage_path { "/test/content" }
    file_hash { "test_hash_#{SecureRandom.hex(8)}" }
    status { 0 }        # draft
  end

  factory :content_version do
    association :content_repository
    association :user
    
    version_number { "1.0" }
    change_summary { "Initial version of content" }
    content_data do
      {
        "title" => "Test Content Title",
        "body" => "Test content body with detailed information",
        "metadata" => {
          "word_count" => 500,
          "last_edited" => Time.current,
          "editor" => "test_user"
        }
      }
    end
    file_size { 1024 }
    checksum { "sha256_#{SecureRandom.hex(32)}" }
  end

  factory :content_revision do
    association :content_repository
    association :user
    
    revision_type { "minor" }
    changes_description { "Minor updates and improvements" }
    previous_content do
      {
        "backup_data" => "Previous version content",
        "timestamp" => 1.hour.ago
      }
    end
  end

  factory :content_tag do
    association :content_repository
    association :user
    
    tag_name { "test_tag" }
    tag_type { "category" }
    tag_weight { 5 }
  end

  factory :content_approval do
    association :content_repository
    association :user
    
    approval_status { "pending" }
    approval_type { "content_review" }
    comments { "Content requires review for approval" }
    approval_criteria do
      {
        "brand_compliance" => true,
        "content_quality" => true,
        "technical_accuracy" => true,
        "legal_compliance" => true
      }
    end
  end

  factory :content_workflow do
    association :content_repository
    association :user
    
    workflow_type { "approval" }
    workflow_steps do
      [
        { "step" => "initial_review", "assignee" => "reviewer_1", "status" => "pending" },
        { "step" => "content_check", "assignee" => "editor_1", "status" => "waiting" },
        { "step" => "brand_compliance", "assignee" => "brand_manager", "status" => "waiting" },
        { "step" => "final_approval", "assignee" => "director", "status" => "waiting" }
      ]
    end
    current_step { 0 }
    deadline { 3.days.from_now }
  end

  factory :content_category do
    association :user
    
    name { "Test Category" }
    description { "Category for test content" }
    category_type { "content_type" }
    parent_category_id { nil }
    metadata { { "level" => 1 } }
  end

  factory :content_permission do
    association :content_repository
    association :user
    
    permission_type { "read" }
    access_level { "user" }
    granted_by_user_id { user.id }
    expires_at { 1.year.from_now }
    metadata { { "granted_for" => "testing" } }
  end

  factory :content_archive do
    association :content_repository
    association :user
    
    archive_reason { "automated_cleanup" }
    archive_type { "soft_delete" }
    archived_data do
      {
        "original_name" => "Test Content",
        "original_description" => "Test content description",
        "archive_timestamp" => Time.current,
        "retention_period" => "2 years"
      }
    end
    retention_until { 2.years.from_now }
  end
end