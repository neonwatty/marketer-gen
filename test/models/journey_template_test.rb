require "test_helper"

class JourneyTemplateTest < ActiveSupport::TestCase
  def setup
    @template = journey_templates(:awareness_template)
    @user = users(:one)
  end

  test "should validate presence of name" do
    template = JourneyTemplate.new
    template.valid?
    assert_includes template.errors[:name], "can't be blank"
  end

  test "should validate uniqueness of name" do
    existing_template = @template
    new_template = JourneyTemplate.new(
      name: existing_template.name,
      campaign_type: "conversion",
      template_data: "{}"
    )
    new_template.valid?
    assert_includes new_template.errors[:name], "has already been taken"
  end

  test "should validate presence of campaign_type" do
    template = JourneyTemplate.new
    template.valid?
    assert_includes template.errors[:campaign_type], "can't be blank"
  end

  test "should validate campaign_type inclusion" do
    template = JourneyTemplate.new(campaign_type: "invalid_type")
    template.valid?
    assert_includes template.errors[:campaign_type], "is not included in the list"
  end

  test "should validate presence of template_data" do
    template = JourneyTemplate.new
    template.valid?
    assert_includes template.errors[:template_data], "can't be blank"
  end

  test "should find default template for campaign type" do
    default_template = JourneyTemplate.default_for_campaign_type("awareness")
    assert_equal @template, default_template
  end

  test "should serialize template_data as JSON" do
    data = { "stages" => ["stage1", "stage2"], "steps" => [] }
    @template.update!(template_data: data)
    @template.reload
    assert_equal data, @template.template_data
  end

  test "should prevent multiple default templates per campaign type" do
    new_template = JourneyTemplate.new(
      name: "Another Awareness Template",
      campaign_type: "awareness",
      template_data: "{}",
      is_default: true
    )
    new_template.valid?
    assert_includes new_template.errors[:is_default], "can only have one default template per campaign type"
  end

  test "should create journey for user" do
    journey_attributes = {
      name: "My Custom Journey",
      description: "A custom journey description"
    }
    
    journey = @template.create_journey_for_user(@user, journey_attributes)
    
    assert journey.persisted?
    assert_equal "My Custom Journey", journey.name
    assert_equal "A custom journey description", journey.description
    assert_equal @template.campaign_type, journey.campaign_type
    assert_equal @user, journey.user
  end

  test "should scope by campaign type" do
    awareness_templates = JourneyTemplate.for_campaign_type("awareness")
    assert_includes awareness_templates, @template
  end

  test "should scope default templates" do
    default_templates = JourneyTemplate.default_templates
    assert_includes default_templates, @template
  end
end
