require "test_helper"

class JourneysControllerTest < ActionDispatch::IntegrationTest
  def setup
    @user = users(:one)
    @other_user = users(:two)
    @journey = journeys(:awareness_journey)
    @other_journey = journeys(:conversion_journey)
  end

  # Authentication Tests
  test "should require authentication for all actions" do
    get journeys_path
    assert_redirected_to new_session_path

    get journey_path(@journey)
    assert_redirected_to new_session_path

    get new_journey_path
    assert_redirected_to new_session_path

    post journeys_path, params: { journey: { name: "Test" } }
    assert_redirected_to new_session_path

    get edit_journey_path(@journey)
    assert_redirected_to new_session_path

    patch journey_path(@journey), params: { journey: { name: "Updated" } }
    assert_redirected_to new_session_path

    delete journey_path(@journey)
    assert_redirected_to new_session_path

    patch reorder_steps_journey_path(@journey), params: { step_ids: [] }
    assert_redirected_to new_session_path
  end

  # Index Tests
  test "should get index when authenticated" do
    sign_in_as(@user)
    get journeys_path
    assert_response :success
    assert_select "h1", "Customer Journeys"
  end

  test "should only show current user journeys" do
    sign_in_as(@user)
    get journeys_path
    assert_response :success
    # Should see own journey
    assert_select "h3", @journey.name
    # Should not see other user's journey
    assert_select "h3", { count: 0, text: @other_journey.name }
  end

  test "should filter journeys by campaign type" do
    sign_in_as(@user)
    get journeys_path, params: { campaign_type: "awareness" }
    assert_response :success
    assert_includes assigns(:journeys), @journey
  end

  test "should filter journeys by template type" do
    sign_in_as(@user)
    @journey.update!(template_type: "email")
    get journeys_path, params: { template_type: "email" }
    assert_response :success
    assert_includes assigns(:journeys), @journey
  end

  test "should filter journeys by status" do
    sign_in_as(@user)
    get journeys_path, params: { status: "draft" }
    assert_response :success
    assert_includes assigns(:journeys), @journey
  end

  # Show Tests
  test "should show journey when authenticated and authorized" do
    sign_in_as(@user)
    get journey_path(@journey)
    assert_response :success
    assert_select "h1", @journey.name
  end

  test "should not show other user journey" do
    sign_in_as(@user)
    get journey_path(@other_journey)
    assert_response :not_found
  end

  test "should load ordered journey steps on show" do
    sign_in_as(@user)
    # Create a fresh journey to avoid fixture conflicts
    test_journey = @user.journeys.create!(
      name: "Test Journey",
      campaign_type: "awareness",
      status: "draft"
    )
    step1 = test_journey.journey_steps.create!(title: "Step 1", step_type: "email", sequence_order: 0)
    step2 = test_journey.journey_steps.create!(title: "Step 2", step_type: "email", sequence_order: 1)
    
    get journey_path(test_journey)
    assert_response :success
    assert_equal [step1, step2], assigns(:journey_steps)
  end

  # New Tests
  test "should get new when authenticated" do
    sign_in_as(@user)
    get new_journey_path
    assert_response :success
    assert_select "h1", "Create New Journey"
  end

  test "should preset template type from params" do
    sign_in_as(@user)
    get new_journey_path, params: { template_type: "webinar" }
    assert_response :success
    assert_equal "webinar", assigns(:journey).template_type
  end

  # Create Tests
  test "should create journey with valid params" do
    sign_in_as(@user)
    assert_difference("Journey.count") do
      post journeys_path, params: {
        journey: {
          name: "New Journey",
          description: "Test description",
          campaign_type: "awareness",
          status: "draft"
        }
      }
    end
    
    journey = Journey.last
    assert_redirected_to journey_path(journey)
    assert_equal @user, journey.user
    assert_equal "New Journey", journey.name
    assert_equal "awareness", journey.campaign_type
    assert_equal "Journey was successfully created.", flash[:notice]
  end

  test "should not create journey with invalid params" do
    sign_in_as(@user)
    assert_no_difference("Journey.count") do
      post journeys_path, params: {
        journey: {
          name: "", # Invalid: blank name
          campaign_type: "invalid_type", # Invalid campaign type
          status: "draft"
        }
      }
    end
    assert_response :unprocessable_entity
    assert_select ".text-red-800", "Please fix the following errors:"
  end

  test "should handle stages parameter on create" do
    sign_in_as(@user)
    post journeys_path, params: {
      journey: {
        name: "Test Journey",
        campaign_type: "awareness",
        status: "draft",
        stages: ["discovery", "education"]
      }
    }
    
    journey = Journey.last
    assert_equal ["discovery", "education"], journey.stages
  end

  # Edit Tests
  test "should get edit when authenticated and authorized" do
    sign_in_as(@user)
    get edit_journey_path(@journey)
    assert_response :success
    assert_select "h1", "Edit Journey"
  end

  test "should not edit other user journey" do
    sign_in_as(@user)
    get edit_journey_path(@other_journey)
    assert_response :not_found
  end

  # Update Tests
  test "should update journey with valid params" do
    sign_in_as(@user)
    patch journey_path(@journey), params: {
      journey: {
        name: "Updated Journey Name",
        description: "Updated description",
        status: "active"
      }
    }
    
    assert_redirected_to journey_path(@journey)
    @journey.reload
    assert_equal "Updated Journey Name", @journey.name
    assert_equal "Updated description", @journey.description
    assert_equal "active", @journey.status
    assert_equal "Journey was successfully updated.", flash[:notice]
  end

  test "should not update journey with invalid params" do
    sign_in_as(@user)
    patch journey_path(@journey), params: {
      journey: {
        name: "", # Invalid: blank name
        campaign_type: "invalid_type"
      }
    }
    assert_response :unprocessable_entity
    assert_select ".text-red-800", "Please fix the following errors:"
  end

  test "should not update other user journey" do
    sign_in_as(@user)
    patch journey_path(@other_journey), params: {
      journey: { name: "Hacked Name" }
    }
    assert_response :not_found
  end

  # Destroy Tests
  test "should destroy journey when authenticated and authorized" do
    sign_in_as(@user)
    assert_difference("Journey.count", -1) do
      delete journey_path(@journey)
    end
    assert_redirected_to journeys_path
    assert_equal "Journey was successfully deleted.", flash[:notice]
  end

  test "should not destroy other user journey" do
    sign_in_as(@user)
    delete journey_path(@other_journey)
    assert_response :not_found
  end

  # Reorder Steps Tests
  test "should reorder steps with valid step ids" do
    sign_in_as(@user)
    # Create a fresh journey to avoid fixture conflicts
    test_journey = @user.journeys.create!(
      name: "Test Journey",
      campaign_type: "awareness",
      status: "draft"
    )
    step1 = test_journey.journey_steps.create!(title: "Step 1", step_type: "email", sequence_order: 0)
    step2 = test_journey.journey_steps.create!(title: "Step 2", step_type: "email", sequence_order: 1)
    step3 = test_journey.journey_steps.create!(title: "Step 3", step_type: "email", sequence_order: 2)
    
    # Reorder: step3, step1, step2
    patch reorder_steps_journey_path(test_journey), params: {
      step_ids: [step3.id, step1.id, step2.id]
    }
    
    assert_response :ok
    
    # Check new order
    step1.reload
    step2.reload
    step3.reload
    
    assert_equal 1, step1.sequence_order
    assert_equal 2, step2.sequence_order
    assert_equal 0, step3.sequence_order
  end

  test "should return not found for invalid step ids" do
    sign_in_as(@user)
    patch reorder_steps_journey_path(@journey), params: {
      step_ids: [99999] # Non-existent step ID
    }
    assert_response :not_found
  end

  test "should not reorder steps of other user journey" do
    sign_in_as(@user)
    patch reorder_steps_journey_path(@other_journey), params: {
      step_ids: []
    }
    assert_response :not_found
  end

  private

  def sign_in_as(user)
    post session_path, params: { email_address: user.email_address, password: "password" }
  end
end