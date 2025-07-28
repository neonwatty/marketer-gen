require "test_helper"

class BrandTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
    @brand = brands(:one)
  end

  test "should be valid with valid attributes" do
    brand = Brand.new(
      name: "Test Brand",
      description: "A test brand",
      user: @user,
      industry: "Technology"
    )
    assert brand.valid?
  end

  test "should require name" do
    brand = Brand.new(user: @user)
    assert_not brand.valid?
    assert_includes brand.errors[:name], "can't be blank"
  end

  test "should require unique name per user" do
    existing_brand = Brand.create!(
      name: "Unique Brand",
      user: @user
    )
    
    duplicate_brand = Brand.new(
      name: "Unique Brand",
      user: @user
    )
    
    assert_not duplicate_brand.valid?
    assert_includes duplicate_brand.errors[:name], "has already been taken"
  end

  test "should allow same name for different users" do
    user2 = users(:two)
    
    Brand.create!(name: "Same Name", user: @user)
    brand2 = Brand.new(name: "Same Name", user: user2)
    
    assert brand2.valid?
  end

  test "should create default messaging framework after creation" do
    brand = Brand.create!(name: "Test Brand", user: @user)
    assert_not_nil brand.messaging_framework
  end

  test "should return latest analysis" do
    analysis1 = brand_analyses(:one)
    analysis2 = @brand.brand_analyses.create!(
      analysis_status: "completed",
      analyzed_at: 1.day.from_now
    )
    
    assert_equal analysis2, @brand.latest_analysis
  end

  test "should check if has complete brand assets" do
    # Start with no processed assets (clear any from fixtures)
    @brand.brand_assets.destroy_all
    assert_not @brand.has_complete_brand_assets?
    
    # Create a brand asset without file attachment first
    brand_asset = @brand.brand_assets.build(
      asset_type: "document",
      processing_status: "completed",
      original_filename: "test.pdf",
      content_type: "application/pdf"
    )
    # Attach file using Active Storage
    brand_asset.file.attach(
      io: File.open(Rails.root.join("test", "fixtures", "files", "test.pdf")),  
      filename: "test.pdf",
      content_type: "application/pdf"
    )
    brand_asset.save!
    
    assert @brand.has_complete_brand_assets?
  end

  test "should return guidelines by category" do
    # Clear existing guidelines to avoid fixture interference
    @brand.brand_guidelines.destroy_all
    
    guideline1 = @brand.brand_guidelines.create!(
      rule_type: "do",
      rule_content: "Use clear language",
      category: "voice",
      priority: 8
    )
    
    guideline2 = @brand.brand_guidelines.create!(
      rule_type: "dont",
      rule_content: "Avoid jargon",
      category: "voice",
      priority: 9
    )
    
    voice_guidelines = @brand.guidelines_by_category("voice")
    assert_includes voice_guidelines, guideline1
    assert_includes voice_guidelines, guideline2
    # Check that higher priority comes first (priority 9 > priority 8)
    assert_equal guideline2.rule_content, voice_guidelines.first.rule_content
  end

  test "should return brand voice attributes from latest analysis" do
    analysis = brand_analyses(:one)
    analysis.update!(
      voice_attributes: {
        "tone" => { "primary" => "friendly" },
        "formality" => { "level" => "casual" }
      }
    )
    
    voice_attrs = @brand.brand_voice_attributes
    assert_equal "friendly", voice_attrs.dig("tone", "primary")
    assert_equal "casual", voice_attrs.dig("formality", "level")
  end
end
