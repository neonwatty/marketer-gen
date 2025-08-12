require 'test_helper'

class ContentVersionTest < ActiveSupport::TestCase
  setup do
    @campaign = campaigns(:one) # Use existing campaign as content item
    @main_branch = ContentBranch.create_main_branch(@campaign)
  end

  test "should create content version with valid attributes" do
    version = ContentVersion.new(
      content_item: @campaign,
      content_data: { content: "Test marketing content" },
      content_type: 'marketing_content',
      commit_message: 'Initial content creation',
      branch: @main_branch
    )
    
    assert version.valid?
    assert version.save
    assert_not_nil version.version_hash
    assert_equal 1, version.version_number
  end

  test "should validate required fields" do
    version = ContentVersion.new
    
    assert_not version.valid?
    assert_includes version.errors[:content_data], "can't be blank"
    assert_includes version.errors[:commit_message], "can't be blank"
    assert_includes version.errors[:content_type], "can't be blank"
  end

  test "should generate unique version hash" do
    version1 = ContentVersion.create!(
      content_item: @campaign,
      content_data: { content: "Content 1" },
      content_type: 'marketing_content',
      commit_message: 'First version',
      branch: @main_branch
    )
    
    version2 = ContentVersion.create!(
      content_item: @campaign,
      content_data: { content: "Content 2" },
      content_type: 'marketing_content',
      commit_message: 'Second version',
      branch: @main_branch
    )
    
    assert_not_equal version1.version_hash, version2.version_hash
  end

  test "should commit version successfully" do
    version = ContentVersion.create!(
      content_item: @campaign,
      content_data: { content: "Test content" },
      content_type: 'marketing_content',
      commit_message: 'Test commit',
      branch: @main_branch
    )
    
    assert_equal 'draft', version.status
    
    version.commit!('Test commit message')
    
    assert_equal 'committed', version.status
    assert_not_nil version.committed_at
    assert_equal version, @main_branch.reload.head_version
  end

  test "should create child version with correct parent relationship" do
    parent_version = ContentVersion.create!(
      content_item: @campaign,
      content_data: { content: "Parent content" },
      content_type: 'marketing_content',
      commit_message: 'Parent commit',
      branch: @main_branch
    )
    parent_version.commit!('Parent commit')
    
    child_version = ContentVersion.create!(
      content_item: @campaign,
      content_data: { content: "Child content" },
      content_type: 'marketing_content',
      commit_message: 'Child commit',
      parent: parent_version,
      branch: @main_branch
    )
    
    assert_equal parent_version, child_version.parent
    assert_includes parent_version.children, child_version
    assert_equal 2, child_version.version_number
  end

  test "should track ancestry correctly" do
    v1 = ContentVersion.create!(
      content_item: @campaign,
      content_data: { content: "Version 1" },
      content_type: 'marketing_content',
      commit_message: 'V1',
      branch: @main_branch
    )
    
    v2 = ContentVersion.create!(
      content_item: @campaign,
      content_data: { content: "Version 2" },
      content_type: 'marketing_content',
      commit_message: 'V2',
      parent: v1,
      branch: @main_branch
    )
    
    v3 = ContentVersion.create!(
      content_item: @campaign,
      content_data: { content: "Version 3" },
      content_type: 'marketing_content',
      commit_message: 'V3',
      parent: v2,
      branch: @main_branch
    )
    
    ancestors = v3.ancestors
    assert_equal 2, ancestors.size
    assert_includes ancestors, v2
    assert_includes ancestors, v1
    
    assert v1.is_ancestor_of?(v3)
    assert_not v3.is_ancestor_of?(v1)
  end

  test "should detect content changes between versions" do
    v1 = ContentVersion.create!(
      content_item: @campaign,
      content_data: { 
        content: "Original content",
        title: "Original title"
      },
      content_type: 'marketing_content',
      commit_message: 'V1',
      branch: @main_branch
    )
    
    v2 = ContentVersion.create!(
      content_item: @campaign,
      content_data: { 
        content: "Modified content",
        title: "Original title"
      },
      content_type: 'marketing_content',
      commit_message: 'V2',
      parent: v1,
      branch: @main_branch
    )
    
    assert v2.has_changes_from?(v1)
    changed_fields = v2.content_changed_fields(v1)
    assert_includes changed_fields, 'content'
    assert_not_includes changed_fields, 'title'
  end

  test "should rollback to previous version" do
    v1 = ContentVersion.create!(
      content_item: @campaign,
      content_data: { content: "Original content" },
      content_type: 'marketing_content',
      commit_message: 'Original',
      branch: @main_branch
    )
    v1.commit!('Original')
    
    v2 = ContentVersion.create!(
      content_item: @campaign,
      content_data: { content: "Modified content" },
      content_type: 'marketing_content',
      commit_message: 'Modified',
      parent: v1,
      branch: @main_branch
    )
    v2.commit!('Modified')
    
    rollback_version = v1.rollback_to!
    
    assert_equal v1.content_data, rollback_version.content_data
    assert_includes rollback_version.commit_message, 'Rollback to version'
    assert_equal v2, rollback_version.parent
  end
end