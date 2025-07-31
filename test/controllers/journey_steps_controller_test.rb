require "test_helper"

class JourneyStepsControllerTest < ActionDispatch::IntegrationTest
  def setup
    @user = users(:one)
    @other_user = users(:two)
    @journey = journeys(:one)
    @journey.update!(user: @user)
    @journey_step = journey_steps(:one)
    @journey_step.update!(journey: @journey)
    sign_in_as(@user)
  end

  test "should get show" do
    get journey_step_url(@journey, @journey_step)
    assert_response :success
    assert_includes response.body, @journey_step.name
  end

  test "should get show as JSON" do
    get journey_step_url(@journey, @journey_step), as: :json
    assert_response :success
    
    json_response = JSON.parse(response.body)
    assert_equal @journey_step.id, json_response["id"]
    assert_equal @journey_step.name, json_response["name"]
  end

  test "should not show step from other user's journey" do
    other_journey = journeys(:two)
    other_journey.update!(user: @other_user)
    other_step = journey_steps(:two)
    other_step.update!(journey: other_journey)
    
    assert_raises(Pundit::NotAuthorizedError) do
      get journey_step_url(other_journey, other_step)
    end
  end

  test "should get new" do
    get new_journey_step_url(@journey)
    assert_response :success
  end

  test "should get new with params" do
    get new_journey_step_url(@journey), params: { 
      stage: 'awareness', 
      content_type: 'email',
      channel: 'email'
    }
    assert_response :success
  end

  test "should create journey step" do
    assert_difference("JourneyStep.count") do
      post journey_steps_url(@journey), params: { 
        journey_step: { 
          name: "New Step", 
          description: "Test description",
          stage: "awareness",
          content_type: "email",
          channel: "email",
          duration_days: 1
        } 
      }
    end

    new_step = JourneyStep.last
    assert_equal @journey, new_step.journey
    assert_redirected_to journey_step_url(@journey, new_step)
  end

  test "should create journey step as JSON" do
    assert_difference("JourneyStep.count") do
      post journey_steps_url(@journey), params: { 
        journey_step: { 
          name: "New Step", 
          description: "Test description",
          stage: "awareness"
        } 
      }, as: :json
    end

    assert_response :created
    json_response = JSON.parse(response.body)
    assert_equal "New Step", json_response["name"]
  end

  test "should not create journey step with invalid params" do
    assert_no_difference("JourneyStep.count") do
      post journey_steps_url(@journey), params: { journey_step: { name: "" } }
    end

    assert_response :unprocessable_entity
  end

  test "should not create step for other user's journey" do
    other_journey = journeys(:two)
    other_journey.update!(user: @other_user)
    
    assert_raises(Pundit::NotAuthorizedError) do
      post journey_steps_url(other_journey), params: { 
        journey_step: { name: "Hacked Step", stage: "awareness" } 
      }
    end
  end

  test "should get edit" do
    get edit_journey_step_url(@journey, @journey_step)
    assert_response :success
  end

  test "should not edit step from other user's journey" do
    other_journey = journeys(:two)
    other_journey.update!(user: @other_user)
    other_step = journey_steps(:two)
    other_step.update!(journey: other_journey)
    
    assert_raises(Pundit::NotAuthorizedError) do
      get edit_journey_step_url(other_journey, other_step)
    end
  end

  test "should update journey step" do
    patch journey_step_url(@journey, @journey_step), params: { 
      journey_step: { 
        name: "Updated Step",
        description: "Updated description"
      } 
    }
    assert_redirected_to journey_step_url(@journey, @journey_step)
    
    @journey_step.reload
    assert_equal "Updated Step", @journey_step.name
    assert_equal "Updated description", @journey_step.description
  end

  test "should update journey step as JSON" do
    patch journey_step_url(@journey, @journey_step), params: { 
      journey_step: { name: "Updated Step" } 
    }, as: :json
    assert_response :success
    
    json_response = JSON.parse(response.body)
    assert_equal "Updated Step", json_response["name"]
  end

  test "should not update journey step with invalid params" do
    patch journey_step_url(@journey, @journey_step), params: { 
      journey_step: { name: "" } 
    }
    assert_response :unprocessable_entity
  end

  test "should not update step from other user's journey" do
    other_journey = journeys(:two)
    other_journey.update!(user: @other_user)
    other_step = journey_steps(:two)
    other_step.update!(journey: other_journey)
    
    assert_raises(Pundit::NotAuthorizedError) do
      patch journey_step_url(other_journey, other_step), params: { 
        journey_step: { name: "Hacked" } 
      }
    end
  end

  test "should destroy journey step" do
    assert_difference("JourneyStep.count", -1) do
      delete journey_step_url(@journey, @journey_step)
    end

    assert_redirected_to journey_url(@journey)
  end

  test "should destroy journey step as JSON" do
    assert_difference("JourneyStep.count", -1) do
      delete journey_step_url(@journey, @journey_step), as: :json
    end

    assert_response :success
  end

  test "should not destroy step from other user's journey" do
    other_journey = journeys(:two)
    other_journey.update!(user: @other_user)
    other_step = journey_steps(:two)
    other_step.update!(journey: other_journey)
    
    assert_raises(Pundit::NotAuthorizedError) do
      delete journey_step_url(other_journey, other_step)
    end
  end

  test "should move journey step to new position" do
    # Create additional steps to test positioning
    step2 = @journey.journey_steps.create!(
      name: "Step 2", 
      stage: "consideration",
      position: 1
    )
    step3 = @journey.journey_steps.create!(
      name: "Step 3", 
      stage: "conversion",
      position: 2
    )
    
    # Move the first step to position 2
    patch move_journey_step_url(@journey, @journey_step), params: { position: 2 }
    assert_redirected_to journey_url(@journey)
    
    @journey_step.reload
    assert_equal 2, @journey_step.position
  end

  test "should move journey step as JSON" do
    step2 = @journey.journey_steps.create!(
      name: "Step 2", 
      stage: "consideration",
      position: 1
    )
    
    patch move_journey_step_url(@journey, @journey_step), params: { position: 1 }, as: :json
    assert_response :success
    
    json_response = JSON.parse(response.body)
    assert_equal 1, json_response["position"]
  end

  test "should duplicate journey step" do
    assert_difference("JourneyStep.count") do
      post duplicate_journey_step_url(@journey, @journey_step)
    end

    new_step = JourneyStep.last
    assert_equal @journey, new_step.journey
    assert_includes new_step.name, "Copy"
    assert_redirected_to journey_step_url(@journey, new_step)
  end

  test "should duplicate journey step as JSON" do
    assert_difference("JourneyStep.count") do
      post duplicate_journey_step_url(@journey, @journey_step), as: :json
    end

    assert_response :created
    json_response = JSON.parse(response.body)
    assert_includes json_response["name"], "Copy"
  end

  test "should require authentication" do
    sign_out
    
    get journey_step_url(@journey, @journey_step)
    assert_redirected_to new_session_url
  end

  test "should track activity on step actions" do
    # Test that activities are being tracked
    assert_difference("Activity.count") do
      get journey_step_url(@journey, @journey_step)
    end
    
    activity = Activity.last
    assert_equal 'viewed_journey_step', activity.action
    assert_equal @user, activity.user
  end

  test "should set position automatically on create" do
    # Create a few steps first
    @journey.journey_steps.create!(name: "Step 1", stage: "awareness", position: 0)
    @journey.journey_steps.create!(name: "Step 2", stage: "consideration", position: 1)
    
    # Create new step without specifying position
    post journey_steps_url(@journey), params: { 
      journey_step: { 
        name: "New Step", 
        stage: "conversion"
      } 
    }

    new_step = JourneyStep.last
    assert_equal 2, new_step.position # Should be automatically set to next available position
  end

  test "should validate stage is included in allowed values" do
    post journey_steps_url(@journey), params: { 
      journey_step: { 
        name: "Invalid Step", 
        stage: "invalid_stage"
      } 
    }

    assert_response :unprocessable_entity
  end

  test "should validate content_type is included in allowed values" do
    post journey_steps_url(@journey), params: { 
      journey_step: { 
        name: "Invalid Step", 
        stage: "awareness",
        content_type: "invalid_type"
      } 
    }

    assert_response :unprocessable_entity
  end

  test "should validate channel is included in allowed values" do
    post journey_steps_url(@journey), params: { 
      journey_step: { 
        name: "Invalid Step", 
        stage: "awareness",
        channel: "invalid_channel"
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