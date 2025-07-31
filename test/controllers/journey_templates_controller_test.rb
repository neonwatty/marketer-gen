require "test_helper"

class JourneyTemplatesControllerTest < ActionDispatch::IntegrationTest
  def setup
    @user = users(:one)
    @other_user = users(:two)
    @template = journey_templates(:one)
    @template.update!(is_active: true)
    sign_in_as(@user)
  end

  test "should get index" do
    get journey_templates_url
    assert_response :success
    assert_includes response.body, @template.name
  end

  test "should filter templates by category" do
    @template.update!(category: 'b2b')
    other_template = journey_templates(:two)
    other_template.update!(category: 'b2c', is_active: true)
    
    get journey_templates_url, params: { category: 'b2b' }
    assert_response :success
    assert_includes response.body, @template.name
    assert_not_includes response.body, other_template.name
  end

  test "should filter templates by campaign_type" do
    @template.update!(campaign_type: 'product_launch')
    other_template = journey_templates(:two)
    other_template.update!(campaign_type: 'brand_awareness', is_active: true)
    
    get journey_templates_url, params: { campaign_type: 'product_launch' }
    assert_response :success
    assert_includes response.body, @template.name
    assert_not_includes response.body, other_template.name
  end

  test "should search templates by name" do
    @template.update!(name: 'Unique Template Name')
    other_template = journey_templates(:two)
    other_template.update!(name: 'Different Name', is_active: true)
    
    get journey_templates_url, params: { search: 'Unique' }
    assert_response :success
    assert_includes response.body, @template.name
    assert_not_includes response.body, other_template.name
  end

  test "should sort templates by popularity" do
    @template.update!(usage_count: 10)
    other_template = journey_templates(:two)
    other_template.update!(usage_count: 5, is_active: true)
    
    get journey_templates_url, params: { sort: 'popular' }
    assert_response :success
    # Should display templates in order of usage_count
  end

  test "should only show active templates to regular users" do
    inactive_template = journey_templates(:two)
    inactive_template.update!(is_active: false)
    
    get journey_templates_url
    assert_response :success
    assert_includes response.body, @template.name
    assert_not_includes response.body, inactive_template.name
  end

  test "should get show" do
    get journey_template_url(@template)
    assert_response :success
    assert_includes response.body, @template.name
  end

  test "should show template preview data" do
    @template.update!(
      template_data: {
        'steps' => [
          { 'name' => 'Test Step', 'stage' => 'awareness' }
        ]
      }
    )
    
    get journey_template_url(@template)
    assert_response :success
    assert_includes response.body, 'Test Step'
  end

  test "should not show inactive template to regular users" do
    @template.update!(is_active: false)
    
    assert_raises(Pundit::NotAuthorizedError) do
      get journey_template_url(@template)
    end
  end

  test "should get new" do
    get new_journey_template_url
    assert_response :success
  end

  test "should create template" do
    assert_difference("JourneyTemplate.count") do
      post journey_templates_url, params: { 
        journey_template: { 
          name: "New Template", 
          description: "Test description",
          category: "b2b",
          campaign_type: "product_launch",
          difficulty_level: "beginner",
          estimated_duration_days: 30,
          version: 1.0
        } 
      }
    end

    assert_redirected_to journey_template_url(JourneyTemplate.last)
  end

  test "should create template as JSON" do
    assert_difference("JourneyTemplate.count") do
      post journey_templates_url, params: { 
        journey_template: { 
          name: "New Template", 
          description: "Test description",
          category: "b2b",
          version: 1.0
        } 
      }, as: :json
    end

    assert_response :created
  end

  test "should not create template with invalid params" do
    assert_no_difference("JourneyTemplate.count") do
      post journey_templates_url, params: { journey_template: { name: "" } }
    end

    assert_response :unprocessable_entity
  end

  test "should get edit" do
    get edit_journey_template_url(@template)
    assert_response :success
  end

  test "should update template" do
    patch journey_template_url(@template), params: { 
      journey_template: { 
        name: "Updated Template",
        description: "Updated description"
      } 
    }
    assert_redirected_to journey_template_url(@template)
    
    @template.reload
    assert_equal "Updated Template", @template.name
    assert_equal "Updated description", @template.description
  end

  test "should update template as JSON" do
    patch journey_template_url(@template), params: { 
      journey_template: { name: "Updated Template" } 
    }, as: :json
    assert_response :success
  end

  test "should not update template with invalid params" do
    patch journey_template_url(@template), params: { 
      journey_template: { name: "" } 
    }
    assert_response :unprocessable_entity
  end

  test "should deactivate template on destroy" do
    assert_no_difference("JourneyTemplate.count") do
      delete journey_template_url(@template)
    end
    
    @template.reload
    assert_not @template.is_active?
    assert_redirected_to journey_templates_url
  end

  test "should clone template" do
    assert_difference("JourneyTemplate.count") do
      post clone_journey_template_url(@template)
    end

    new_template = JourneyTemplate.last
    assert_includes new_template.name, "Copy"
    assert_equal 0, new_template.usage_count
    assert new_template.is_active?
    assert_redirected_to edit_journey_template_url(new_template)
  end

  test "should use template to create journey" do
    assert_difference("Journey.count") do
      post use_template_journey_template_url(@template), params: {
        name: "New Journey from Template",
        description: "Test journey",
        target_audience: "Test audience"
      }
    end

    new_journey = Journey.last
    assert_equal @user, new_journey.user
    assert_equal "New Journey from Template", new_journey.name
    assert_equal @template.campaign_type, new_journey.campaign_type
    assert_redirected_to journey_url(new_journey)
    
    # Template usage count should increment
    @template.reload
    assert_equal 1, @template.usage_count
  end

  test "should get builder" do
    get builder_journey_template_url(@template)
    assert_response :success
  end

  test "should get builder_react" do
    get builder_react_journey_template_url(@template)
    assert_response :success
  end

  test "should handle builder with new template" do
    get builder_journey_template_url('new')
    assert_response :success
  end

  test "should require authentication" do
    sign_out
    
    get journey_templates_url
    assert_redirected_to new_session_url
  end

  test "should track activity on template actions" do
    # Test that activities are being tracked
    assert_difference("Activity.count") do
      get journey_templates_url
    end
    
    activity = Activity.last
    assert_equal 'viewed_journey_templates', activity.action
    assert_equal @user, activity.user
  end

  test "should validate category is included in allowed values" do
    post journey_templates_url, params: { 
      journey_template: { 
        name: "Invalid Template", 
        category: "invalid_category",
        version: 1.0
      } 
    }

    assert_response :unprocessable_entity
  end

  test "should validate campaign_type is included in allowed values" do
    post journey_templates_url, params: { 
      journey_template: { 
        name: "Invalid Template", 
        category: "b2b",
        campaign_type: "invalid_type",
        version: 1.0
      } 
    }

    assert_response :unprocessable_entity
  end

  test "should validate difficulty_level is included in allowed values" do
    post journey_templates_url, params: { 
      journey_template: { 
        name: "Invalid Template", 
        category: "b2b",
        difficulty_level: "invalid_level",
        version: 1.0
      } 
    }

    assert_response :unprocessable_entity
  end

  test "should validate estimated_duration_days is positive" do
    post journey_templates_url, params: { 
      journey_template: { 
        name: "Invalid Template", 
        category: "b2b",
        estimated_duration_days: -5,
        version: 1.0
      } 
    }

    assert_response :unprocessable_entity
  end

  test "should validate version is present and positive" do
    post journey_templates_url, params: { 
      journey_template: { 
        name: "Invalid Template", 
        category: "b2b"
        # Missing version
      } 
    }

    assert_response :unprocessable_entity
  end

  private

  def sign_in_as(user)
    post session_url, params: { email_address: user.email_address, password: "password" }
  end

  def sign_out
    delete session_url
  end
end