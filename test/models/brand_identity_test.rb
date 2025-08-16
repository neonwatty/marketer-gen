require "test_helper"

class BrandIdentityTest < ActiveSupport::TestCase
  def setup
    @user = users(:one)
    @brand_identity = brand_identities(:valid_brand)
  end

  test "should be valid with valid attributes" do
    brand_identity = BrandIdentity.new(
      user: @user,
      name: "Unique Test Brand",
      description: "A test brand identity"
    )
    assert brand_identity.valid?, "Expected brand identity to be valid, but got errors: #{brand_identity.errors.full_messages}"
  end

  test "should require name" do
    brand_identity = BrandIdentity.new(user: @user)
    assert_not brand_identity.valid?
    assert_includes brand_identity.errors[:name], "can't be blank"
  end

  test "should require user" do
    brand_identity = BrandIdentity.new(name: "Test Brand")
    assert_not brand_identity.valid?
    assert_includes brand_identity.errors[:user], "must exist"
  end

  test "should have unique name per user" do
    existing = BrandIdentity.create!(user: @user, name: "Unique Brand")
    duplicate = BrandIdentity.new(user: @user, name: "Unique Brand")
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:name], "has already been taken"
  end

  test "should allow same name for different users" do
    user2 = users(:two)
    BrandIdentity.create!(user: @user, name: "Same Name")
    brand_identity = BrandIdentity.new(user: user2, name: "Same Name")
    assert brand_identity.valid?
  end

  test "should have default status of draft" do
    brand_identity = BrandIdentity.new(user: @user, name: "Test")
    assert_equal "draft", brand_identity.status
  end

  test "should validate status inclusion" do
    brand_identity = BrandIdentity.new(user: @user, name: "Test", status: "invalid")
    assert_not brand_identity.valid?
    assert_includes brand_identity.errors[:status], "is not included in the list"
  end

  test "should validate description length" do
    brand_identity = BrandIdentity.new(
      user: @user,
      name: "Test",
      description: "a" * 1001
    )
    assert_not brand_identity.valid?
    assert_includes brand_identity.errors[:description], "is too long (maximum is 1000 characters)"
  end

  test "activate! should deactivate other brand identities" do
    brand1 = BrandIdentity.create!(user: @user, name: "Brand 1", is_active: true, status: "active")
    brand2 = BrandIdentity.create!(user: @user, name: "Brand 2")
    
    brand2.activate!
    
    assert brand2.is_active?
    assert_equal "active", brand2.status
    
    brand1.reload
    assert_not brand1.is_active?
  end

  test "deactivate! should set inactive and draft status" do
    brand_identity = BrandIdentity.create!(
      user: @user,
      name: "Test",
      is_active: true,
      status: "active"
    )
    
    brand_identity.deactivate!
    
    assert_not brand_identity.is_active?
    assert_equal "draft", brand_identity.status
  end

  test "process_materials! should update status to processing" do
    brand_identity = BrandIdentity.create!(user: @user, name: "Test")
    
    # Mock the job to prevent actual job execution in tests
    BrandMaterialsProcessorJob.expects(:perform_later).with(brand_identity)
    
    brand_identity.process_materials!
    
    assert_equal "processing", brand_identity.status
  end

  test "status helper methods should work correctly" do
    brand_identity = BrandIdentity.new(status: "draft")
    assert brand_identity.draft?
    assert_not brand_identity.processing?
    assert_not brand_identity.active?
    assert_not brand_identity.archived?
  end

  test "processed_guidelines_summary should return correct data" do
    brand_identity = BrandIdentity.new(
      processed_guidelines: {
        'voice' => 'friendly',
        'tone' => 'professional',
        'files_processed' => { 'count' => 3 }
      }
    )
    
    summary = brand_identity.processed_guidelines_summary
    
    assert summary[:voice_extracted]
    assert summary[:tone_extracted]
    assert_equal 3, summary[:files_processed]
  end

  test "active scope should return only active brand identities" do
    active = BrandIdentity.create!(user: @user, name: "Active", is_active: true)
    inactive = BrandIdentity.create!(user: @user, name: "Inactive", is_active: false)
    
    assert_includes BrandIdentity.active, active
    assert_not_includes BrandIdentity.active, inactive
  end

  test "by_status scope should filter by status" do
    draft = BrandIdentity.create!(user: @user, name: "Draft", status: "draft")
    active = BrandIdentity.create!(user: @user, name: "Active", status: "active")
    
    draft_results = BrandIdentity.by_status("draft")
    assert_includes draft_results, draft
    assert_not_includes draft_results, active
  end
end
