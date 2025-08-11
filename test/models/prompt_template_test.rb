require "test_helper"

class PromptTemplateTest < ActiveSupport::TestCase
  # Basic Model Tests
  test "should be valid with valid attributes" do
    template = PromptTemplate.new(
      name: "Test Template",
      prompt_type: "social_media",
      system_prompt: "You are a test assistant.",
      user_prompt: "Generate content about {{topic}}.",
      variables: [{"name" => "topic", "type" => "string", "required" => true}],
      default_values: {},
      temperature: 0.7,
      max_tokens: 1000
    )
    assert template.valid?
  end

  test "should require name" do
    template = prompt_templates(:social_media_template)
    template.name = nil
    assert_not template.valid?
    assert_includes template.errors[:name], "can't be blank"
  end

  test "should require prompt_type" do
    template = prompt_templates(:social_media_template)
    template.prompt_type = nil
    assert_not template.valid?
    assert_includes template.errors[:prompt_type], "can't be blank"
  end

  test "should require system_prompt" do
    template = prompt_templates(:social_media_template)
    template.system_prompt = nil
    assert_not template.valid?
    assert_includes template.errors[:system_prompt], "can't be blank"
  end

  test "should require user_prompt" do
    template = prompt_templates(:social_media_template)
    template.user_prompt = nil
    assert_not template.valid?
    assert_includes template.errors[:user_prompt], "can't be blank"
  end

  test "should validate name length" do
    template = prompt_templates(:social_media_template)
    template.name = "a"
    assert_not template.valid?
    assert_includes template.errors[:name], "is too short (minimum is 2 characters)"

    template.name = "a" * 201
    assert_not template.valid?
    assert_includes template.errors[:name], "is too long (maximum is 200 characters)"
  end

  test "should validate temperature range" do
    template = prompt_templates(:social_media_template)
    
    template.temperature = -0.1
    assert_not template.valid?
    assert_includes template.errors[:temperature], "must be greater than or equal to 0"

    template.temperature = 2.1
    assert_not template.valid?
    assert_includes template.errors[:temperature], "must be less than or equal to 2"

    template.temperature = 1.0
    assert template.valid?
  end

  test "should validate max_tokens is positive" do
    template = prompt_templates(:social_media_template)
    template.max_tokens = 0
    assert_not template.valid?
    assert_includes template.errors[:max_tokens], "must be greater than 0"
  end

  test "should validate variables structure" do
    template = prompt_templates(:social_media_template)
    
    # Invalid: not an array
    template.variables = {"invalid" => "structure"}
    assert_not template.valid?
    assert_includes template.errors[:variables], "must be an array"

    # Invalid: variable without name
    template.variables = [{"type" => "string"}]
    assert_not template.valid?
    assert_includes template.errors[:variables], "Variable at position 0 must have a name"

    # Valid: proper structure
    template.variables = [{"name" => "test", "type" => "string"}]
    assert template.valid?
  end

  test "should validate default_values structure" do
    template = prompt_templates(:social_media_template)
    
    template.default_values = "not a hash"
    assert_not template.valid?
    assert_includes template.errors[:default_values], "must be a hash"

    template.default_values = {"valid" => "hash"}
    assert template.valid?
  end

  # Scope Tests
  test "active scope should return only active templates" do
    active_templates = PromptTemplate.active
    assert_includes active_templates, prompt_templates(:social_media_template)
    assert_not_includes active_templates, prompt_templates(:inactive_template)
  end

  test "by_type scope should filter by prompt_type" do
    social_templates = PromptTemplate.by_type("social_media")
    assert_includes social_templates, prompt_templates(:social_media_template)
    assert_not_includes social_templates, prompt_templates(:email_template)
  end

  test "by_category scope should filter by category" do
    content_templates = PromptTemplate.by_category("content")
    assert_includes content_templates, prompt_templates(:social_media_template)
    assert_not_includes content_templates, prompt_templates(:email_template)
  end

  test "popular scope should order by usage_count desc" do
    popular_templates = PromptTemplate.popular.limit(2)
    # email_template has usage_count: 12, social_media_template has usage_count: 5
    assert_equal prompt_templates(:email_template), popular_templates.first
  end

  test "root_templates scope should return templates without parent" do
    root_templates = PromptTemplate.root_templates
    assert_includes root_templates, prompt_templates(:social_media_template)
    assert_not_includes root_templates, prompt_templates(:child_template)
  end

  # Variable Management Tests
  test "should extract variable names from variables array" do
    template = prompt_templates(:social_media_template)
    expected_names = ["content_type", "platform", "brand_context", "campaign_name", "campaign_goal"]
    assert_equal expected_names, template.variable_names
  end

  test "should identify required variables" do
    template = prompt_templates(:social_media_template)
    required = template.required_variables
    assert_includes required, "platform"
    assert_includes required, "brand_context"
    assert_not_includes required, "content_type"
  end

  test "should identify optional variables" do
    template = prompt_templates(:social_media_template)
    optional = template.optional_variables
    assert_includes optional, "content_type"
    assert_not_includes optional, "platform"
  end

  test "should add new variable" do
    template = prompt_templates(:social_media_template)
    initial_count = template.variable_names.count
    
    template.add_variable("new_var", type: "string", description: "Test variable", required: true)
    template.reload
    
    assert_equal initial_count + 1, template.variable_names.count
    assert_includes template.variable_names, "new_var"
    
    var_info = template.variable_info.find { |v| v["name"] == "new_var" }
    assert_equal "string", var_info["type"]
    assert_equal "Test variable", var_info["description"]
    assert_equal true, var_info["required"]
  end

  test "should remove variable" do
    template = prompt_templates(:social_media_template)
    initial_count = template.variable_names.count
    
    # First remove the variable reference from the prompt so it doesn't get auto-added back
    template.update!(
      user_prompt: template.user_prompt.gsub(/\{\{content_type\}\}/, "social media post")
    )
    
    template.remove_variable("content_type")
    template.reload
    
    assert_equal initial_count - 1, template.variable_names.count
    assert_not_includes template.variable_names, "content_type"
  end

  test "should set default value for variable" do
    template = prompt_templates(:social_media_template)
    
    template.set_default_value("platform", "Instagram")
    template.reload
    
    assert_equal "Instagram", template.default_values["platform"]
  end

  test "should validate variable values" do
    template = prompt_templates(:social_media_template)
    
    # Missing required variables
    errors = template.validate_variable_values({})
    assert_includes errors, "Required variable 'platform' is missing"
    assert_includes errors, "Required variable 'brand_context' is missing"
    
    # Valid variables
    errors = template.validate_variable_values({
      "platform" => "Instagram",
      "brand_context" => "Fashion brand"
    })
    assert_empty errors
  end

  # Template Rendering Tests
  test "should render prompt with variables" do
    template = prompt_templates(:social_media_template)
    variables = {
      "content_type" => "Instagram post",
      "platform" => "Instagram",
      "brand_context" => "Sustainable fashion brand",
      "campaign_name" => "Summer Sale",
      "campaign_goal" => "Drive sales"
    }
    
    rendered = template.render_prompt(variables)
    
    assert_includes rendered[:user_prompt], "Instagram post"
    assert_includes rendered[:user_prompt], "Instagram"
    assert_includes rendered[:user_prompt], "Sustainable fashion brand"
    assert_includes rendered[:user_prompt], "Summer Sale"
    assert_includes rendered[:user_prompt], "Drive sales"
    
    assert_equal template.temperature, rendered[:temperature]
    assert_equal template.max_tokens, rendered[:max_tokens]
  end

  test "should render with default values when variables missing" do
    template = prompt_templates(:social_media_template)
    variables = {
      "platform" => "Instagram",
      "brand_context" => "Fashion brand"
    }
    
    rendered = template.render_prompt(variables)
    
    # Should use default values from template
    assert_includes rendered[:user_prompt], "social media post"  # default content_type
    assert_includes rendered[:user_prompt], "engagement"         # default campaign_goal
  end

  test "should render system and user prompts separately" do
    template = prompt_templates(:social_media_template)
    variables = {"platform" => "Instagram", "brand_context" => "Fashion brand"}
    
    system = template.render_system_prompt(variables)
    user = template.render_user_prompt(variables)
    
    assert_equal template.system_prompt, system
    assert_includes user, "Instagram"
    assert_includes user, "Fashion brand"
  end

  test "should generate preview" do
    template = prompt_templates(:social_media_template)
    variables = {"platform" => "Instagram", "brand_context" => "Fashion brand"}
    
    preview = template.preview(variables)
    
    assert_equal template.name, preview[:name]
    assert_equal template.prompt_type, preview[:type]
    assert preview[:rendered].is_a?(Hash)
    assert preview[:variables].is_a?(Array)
  end

  # Template Management Tests
  test "should duplicate template" do
    original = prompt_templates(:social_media_template)
    duplicate = original.duplicate("Duplicated Template")
    
    assert_not_equal original.id, duplicate.id
    assert_equal "Duplicated Template", duplicate.name
    assert_equal original.prompt_type, duplicate.prompt_type
    assert_equal original.system_prompt, duplicate.system_prompt
    assert_equal original.user_prompt, duplicate.user_prompt
    assert_equal false, duplicate.is_active  # Duplicates start as inactive
    assert_equal 1, duplicate.version      # Duplicates start at version 1
  end

  test "should create new version" do
    original = prompt_templates(:social_media_template)
    new_version = original.create_version(system_prompt: "Updated system prompt")
    
    assert_not_equal original.id, new_version.id
    assert_equal original.name, new_version.name
    assert_equal "Updated system prompt", new_version.system_prompt
    assert_equal original.version + 1, new_version.version
    assert_equal false, new_version.is_active  # New versions start as inactive
  end

  test "should create variant for A/B testing" do
    original = prompt_templates(:social_media_template)
    variant = original.create_variant("Casual", temperature: 0.9)
    
    assert_not_equal original.id, variant.id
    assert_includes variant.name, "Casual"
    assert_equal 0.9, variant.temperature
    assert_equal original.id, variant.metadata["variant_of"]
    assert_equal "Casual", variant.metadata["variant_name"]
    assert_equal true, variant.metadata["created_for_testing"]
  end

  test "should find variants" do
    original = prompt_templates(:social_media_template)
    variant = prompt_templates(:variant_template)
    
    # Update the variant's metadata to point to the correct template ID
    variant.update!(metadata: variant.metadata.merge("variant_of" => original.id))
    
    variants = original.variants
    variant_names = variants.map(&:name)
    assert_includes variant_names, "Social Media Test Template - Variant"
  end

  test "should find original template from variant" do
    original_template = prompt_templates(:social_media_template)
    variant = prompt_templates(:variant_template)
    
    # Update the variant's metadata to point to the correct template ID
    variant.update!(metadata: variant.metadata.merge("variant_of" => original_template.id))
    
    original = variant.original_template
    assert_equal original_template, original
  end

  # Usage and Analytics Tests
  test "should increment usage count" do
    template = prompt_templates(:social_media_template)
    initial_count = template.usage_count
    
    template.increment_usage!
    
    assert_equal initial_count + 1, template.reload.usage_count
  end

  test "should provide usage analytics" do
    template = prompt_templates(:social_media_template)
    analytics = template.usage_analytics
    
    assert analytics.key?(:usage_count)
    assert analytics.key?(:created_at)
    assert analytics.key?(:variants)
    assert analytics.key?(:child_templates_count)
  end

  # Search and Discovery Tests
  test "should search by name" do
    results = PromptTemplate.search("Social Media")
    assert_includes results, prompt_templates(:social_media_template)
    assert_not_includes results, prompt_templates(:email_template)
  end

  test "should search by description" do
    results = PromptTemplate.search("email marketing")
    assert_includes results, prompt_templates(:email_template)
    assert_not_includes results, prompt_templates(:social_media_template)
  end

  test "should search case insensitively" do
    results = PromptTemplate.search("SOCIAL MEDIA")
    assert_includes results, prompt_templates(:social_media_template)
  end

  test "should return empty results for blank search" do
    results = PromptTemplate.search("")
    assert_empty results
  end

  test "should filter by tag" do
    results = PromptTemplate.by_tag("social")
    assert_includes results, prompt_templates(:social_media_template)
    assert_not_includes results, prompt_templates(:email_template)
  end

  # Tag Management Tests
  test "should manage tag list" do
    template = prompt_templates(:social_media_template)
    
    expected_tags = ["social", "content", "engagement"]
    assert_equal expected_tags, template.tag_list
    
    template.tag_list = ["new", "tags"]
    assert_equal "new, tags", template.tags
    
    template.tag_list = "single tag"
    assert_equal "single tag", template.tags
  end

  # Relationship Tests
  test "should belong to parent template" do
    child = prompt_templates(:child_template)
    parent = prompt_templates(:parent_template)
    
    assert_equal parent, child.parent_template
  end

  test "should have many child templates" do
    parent = prompt_templates(:parent_template)
    children = parent.child_templates
    
    assert_includes children, prompt_templates(:child_template)
  end

  test "should prevent circular dependencies" do
    parent = prompt_templates(:parent_template)
    child = prompt_templates(:child_template)
    
    # Try to make parent a child of child (circular)
    parent.parent_template = child
    assert_not parent.valid?
    assert_includes parent.errors[:parent_template], "creates a circular dependency"
  end

  test "should increment parent usage when child is created" do
    parent = prompt_templates(:parent_template)
    initial_usage = parent.usage_count
    
    child = PromptTemplate.create!(
      name: "New Child",
      prompt_type: "social_media",
      system_prompt: "Test",
      user_prompt: "Test {{topic}}",
      variables: [{"name" => "topic", "type" => "string"}],
      parent_template: parent
    )
    
    assert_equal initial_usage + 1, parent.reload.usage_count
  end

  # Variable Extraction Tests
  test "should extract variables from prompts automatically" do
    template = PromptTemplate.new(
      name: "Test Auto Extract",
      prompt_type: "content_generation",
      system_prompt: "Test system with {{system_var}}",
      user_prompt: "Test user with {{user_var}} and {another_var}",
      variables: []
    )
    
    template.save!
    
    variable_names = template.variable_names
    assert_includes variable_names, "system_var"
    assert_includes variable_names, "user_var"
    assert_includes variable_names, "another_var"
  end

  # Model Preferences Tests
  test "should handle model preferences JSON" do
    template = prompt_templates(:social_media_template)
    
    # Initially empty
    assert_equal({}, template.parsed_model_preferences)
    
    # Set preferences
    template.set_model_preference("provider", "anthropic")
    template.set_model_preference("model", "claude-3-5-sonnet")
    template.reload
    
    prefs = template.parsed_model_preferences
    assert_equal "anthropic", prefs["provider"]
    assert_equal "claude-3-5-sonnet", prefs["model"]
  end

  test "should validate model preferences JSON" do
    template = prompt_templates(:social_media_template)
    template.model_preferences = "invalid json"
    
    assert_not template.valid?
    assert_includes template.errors[:model_preferences], "must be valid JSON"
  end
end