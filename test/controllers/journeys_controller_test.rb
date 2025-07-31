require "test_helper"

class JourneysControllerTest < ActionDispatch::IntegrationTest
  def setup
    @user = users(:one)
    @other_user = users(:two)
    @journey = journeys(:one)
    @journey.update!(user: @user)
    sign_in_as(@user)
    
    @campaign = campaigns(:one)
    @campaign.update!(user: @user)
  end

  test "should get index" do
    get journeys_url
    assert_response :success
    assert_includes response.body, @journey.name
  end

  test "should get index as JSON" do
    get journeys_url, as: :json
    assert_response :success
    
    json_response = JSON.parse(response.body)
    assert json_response["journeys"].is_a?(Array)
    assert json_response["pagination"].present?
  end

  test "should filter journeys by status" do
    @journey.update!(status: 'published')
    draft_journey = journeys(:two)
    draft_journey.update!(user: @user, status: 'draft')
    
    get journeys_url, params: { status: 'published' }
    assert_response :success
    assert_includes response.body, @journey.name
    assert_not_includes response.body, draft_journey.name
  end

  test "should filter journeys by campaign_type" do
    @journey.update!(campaign_type: 'product_launch')
    other_journey = journeys(:two)
    other_journey.update!(user: @user, campaign_type: 'brand_awareness')
    
    get journeys_url, params: { campaign_type: 'product_launch' }
    assert_response :success
    assert_includes response.body, @journey.name
    assert_not_includes response.body, other_journey.name
  end

  test "should search journeys by name" do
    @journey.update!(name: 'Unique Journey Name')
    other_journey = journeys(:two)
    other_journey.update!(user: @user, name: 'Different Name')
    
    get journeys_url, params: { search: 'Unique' }
    assert_response :success
    assert_includes response.body, @journey.name
    assert_not_includes response.body, other_journey.name
  end

  test "should only show user's own journeys" do
    other_journey = journeys(:two)
    other_journey.update!(user: @other_user)
    
    get journeys_url
    assert_response :success
    assert_includes response.body, @journey.name
    assert_not_includes response.body, other_journey.name
  end

  test "should get show" do
    get journey_url(@journey)
    assert_response :success
    assert_includes response.body, @journey.name
  end

  test "should get show as JSON" do
    get journey_url(@journey), as: :json
    assert_response :success
    
    json_response = JSON.parse(response.body)
    assert_equal @journey.id, json_response["id"]
    assert_equal @journey.name, json_response["name"]
  end

  test "should not show other user's journey" do
    other_journey = journeys(:two)
    other_journey.update!(user: @other_user)
    
    assert_raises(Pundit::NotAuthorizedError) do
      get journey_url(other_journey)
    end
  end

  test "should get new" do
    get new_journey_url
    assert_response :success
  end

  test "should get new with template" do
    template = journey_templates(:one)
    get new_journey_url, params: { template_id: template.id }
    assert_response :success
    assert_includes response.body, template.name
  end

  test "should create journey" do
    assert_difference("Journey.count") do
      post journeys_url, params: { 
        journey: { 
          name: "New Journey", 
          description: "Test description",
          campaign_type: "product_launch",
          target_audience: "Test audience",
          goals: ["Test goal"]
        } 
      }
    end

    assert_redirected_to journey_url(Journey.last)
    assert_equal @user, Journey.last.user
  end

  test "should create journey as JSON" do
    assert_difference("Journey.count") do
      post journeys_url, params: { 
        journey: { 
          name: "New Journey", 
          description: "Test description",
          campaign_type: "product_launch"
        } 
      }, as: :json
    end

    assert_response :created
    json_response = JSON.parse(response.body)
    assert_equal "New Journey", json_response["name"]
  end

  test "should not create journey with invalid params" do
    assert_no_difference("Journey.count") do
      post journeys_url, params: { journey: { name: "" } }
    end

    assert_response :unprocessable_entity
  end

  test "should get edit" do
    get edit_journey_url(@journey)
    assert_response :success
  end

  test "should not edit other user's journey" do
    other_journey = journeys(:two)
    other_journey.update!(user: @other_user)
    
    assert_raises(Pundit::NotAuthorizedError) do
      get edit_journey_url(other_journey)
    end
  end

  test "should update journey" do
    patch journey_url(@journey), params: { 
      journey: { 
        name: "Updated Journey",
        description: "Updated description"
      } 
    }
    assert_redirected_to journey_url(@journey)
    
    @journey.reload
    assert_equal "Updated Journey", @journey.name
    assert_equal "Updated description", @journey.description
  end

  test "should update journey as JSON" do
    patch journey_url(@journey), params: { 
      journey: { name: "Updated Journey" } 
    }, as: :json
    assert_response :success
    
    json_response = JSON.parse(response.body)
    assert_equal "Updated Journey", json_response["name"]
  end

  test "should not update journey with invalid params" do
    patch journey_url(@journey), params: { journey: { name: "" } }
    assert_response :unprocessable_entity
  end

  test "should not update other user's journey" do
    other_journey = journeys(:two)
    other_journey.update!(user: @other_user)
    
    assert_raises(Pundit::NotAuthorizedError) do
      patch journey_url(other_journey), params: { journey: { name: "Hacked" } }
    end
  end

  test "should destroy journey" do
    assert_difference("Journey.count", -1) do
      delete journey_url(@journey)
    end

    assert_redirected_to journeys_url
  end

  test "should destroy journey as JSON" do
    assert_difference("Journey.count", -1) do
      delete journey_url(@journey), as: :json
    end

    assert_response :success
  end

  test "should not destroy other user's journey" do
    other_journey = journeys(:two)
    other_journey.update!(user: @other_user)
    
    assert_raises(Pundit::NotAuthorizedError) do
      delete journey_url(other_journey)
    end
  end

  test "should duplicate journey" do
    assert_difference("Journey.count") do
      post duplicate_journey_url(@journey)
    end

    new_journey = Journey.last
    assert_equal @user, new_journey.user
    assert_includes new_journey.name, "Copy"
    assert_redirected_to journey_url(new_journey)
  end

  test "should duplicate journey as JSON" do
    assert_difference("Journey.count") do
      post duplicate_journey_url(@journey), as: :json
    end

    assert_response :created
    json_response = JSON.parse(response.body)
    assert_includes json_response["name"], "Copy"
  end

  test "should publish journey" do
    @journey.update!(status: 'draft')
    
    post publish_journey_url(@journey)
    assert_redirected_to journey_url(@journey)
    
    @journey.reload
    assert_equal 'published', @journey.status
    assert @journey.published_at.present?
  end

  test "should publish journey as JSON" do
    @journey.update!(status: 'draft')
    
    post publish_journey_url(@journey), as: :json
    assert_response :success
    
    json_response = JSON.parse(response.body)
    assert_equal 'published', json_response["status"]
  end

  test "should archive journey" do
    @journey.update!(status: 'published')
    
    post archive_journey_url(@journey)
    assert_redirected_to journey_url(@journey)
    
    @journey.reload
    assert_equal 'archived', @journey.status
    assert @journey.archived_at.present?
  end

  test "should archive journey as JSON" do
    @journey.update!(status: 'published')
    
    post archive_journey_url(@journey), as: :json
    assert_response :success
    
    json_response = JSON.parse(response.body)
    assert_equal 'archived', json_response["status"]
  end

  test "should require authentication" do
    sign_out
    
    get journeys_url
    assert_redirected_to new_session_url
  end

  test "should track activity on journey actions" do
    # Test that activities are being tracked
    assert_difference("Activity.count") do
      get journeys_url
    end
    
    activity = Activity.last
    assert_equal 'viewed_journeys_list', activity.action
    assert_equal @user, activity.user
  end

  private

  def sign_in_as(user)
    post session_url, params: { email_address: user.email_address, password: "password" }
  end

  def sign_out
    delete session_url
  end
end