require "test_helper"

class Api::V1::JourneysControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = create(:user)
    @persona = create(:persona, user: @user)
    @campaign = create(:campaign, user: @user, persona: @persona)
    @journey = create(:journey, user: @user, campaign: @campaign)
    sign_in_as(@user)
  end

  test "should get index" do
    get api_v1_journeys_url, as: :json
    assert_response :success
    
    response_data = JSON.parse(response.body)
    assert response_data['success']
    assert response_data['data'].is_a?(Array)
    assert response_data['meta']['pagination']
  end

  test "should get index with filters" do
    get api_v1_journeys_url, params: { status: 'draft' }, as: :json
    assert_response :success
    
    response_data = JSON.parse(response.body)
    assert response_data['success']
  end

  test "should show journey" do
    get api_v1_journey_url(@journey), as: :json
    assert_response :success
    
    response_data = JSON.parse(response.body)
    assert response_data['success']
    assert_equal @journey.id, response_data['data']['id']
    assert_equal @journey.name, response_data['data']['name']
  end

  test "should create journey" do
    journey_params = {
      journey: {
        name: "Test Journey",
        description: "Test description",
        campaign_type: "email_nurture"
      }
    }

    assert_difference('Journey.count') do
      post api_v1_journeys_url, params: journey_params, as: :json
    end

    assert_response :created
    response_data = JSON.parse(response.body)
    assert response_data['success']
    assert_equal "Test Journey", response_data['data']['name']
    assert_equal "Journey created successfully", response_data['message']
  end

  test "should update journey" do
    patch_params = {
      journey: {
        name: "Updated Journey Name",
        description: "Updated description"
      }
    }

    patch api_v1_journey_url(@journey), params: patch_params, as: :json
    assert_response :success

    response_data = JSON.parse(response.body)
    assert response_data['success']
    assert_equal "Updated Journey Name", response_data['data']['name']
    assert_equal "Journey updated successfully", response_data['message']
  end

  test "should destroy journey" do
    assert_difference('Journey.count', -1) do
      delete api_v1_journey_url(@journey), as: :json
    end

    assert_response :success
    response_data = JSON.parse(response.body)
    assert response_data['success']
    assert_equal "Journey deleted successfully", response_data['message']
  end

  test "should duplicate journey" do
    assert_difference('Journey.count') do
      post duplicate_api_v1_journey_url(@journey), as: :json
    end

    assert_response :created
    response_data = JSON.parse(response.body)
    assert response_data['success']
    assert_match(/Copy/, response_data['data']['name'])
    assert_equal "Journey duplicated successfully", response_data['message']
  end

  test "should publish journey" do
    @journey.update!(status: 'draft')
    
    post publish_api_v1_journey_url(@journey), as: :json
    assert_response :success

    response_data = JSON.parse(response.body)
    assert response_data['success']
    assert_equal 'published', response_data['data']['status']
    assert_not_nil response_data['data']['published_at']
  end

  test "should get journey analytics" do
    get analytics_api_v1_journey_url(@journey), as: :json
    assert_response :success

    response_data = JSON.parse(response.body)
    assert response_data['success']
    assert response_data['data']['summary']
    assert response_data['data']['performance_score']
  end

  test "should get execution status" do
    get execution_status_api_v1_journey_url(@journey), as: :json
    assert_response :success

    response_data = JSON.parse(response.body)
    assert response_data['success']
    assert response_data['data'].is_a?(Array)
  end

  test "should require authentication" do
    sign_out
    
    get api_v1_journeys_url, as: :json
    assert_response :unauthorized
    
    response_data = JSON.parse(response.body)
    assert_equal false, response_data['success']
    assert_equal 'Authentication required', response_data['message']
  end

  test "should not show other user's journey" do
    other_user = create(:user, email_address: "other@example.com")
    other_persona = create(:persona, user: other_user)
    other_campaign = create(:campaign, user: other_user, persona: other_persona)
    other_journey = create(:journey, user: other_user, campaign: other_campaign)

    get api_v1_journey_url(other_journey), as: :json
    assert_response :not_found
  end

  test "should handle validation errors" do
    journey_params = {
      journey: {
        name: "", # Invalid: name is required
        campaign_type: "invalid_type" # Invalid campaign type
      }
    }

    post api_v1_journeys_url, params: journey_params, as: :json
    assert_response :unprocessable_entity

    response_data = JSON.parse(response.body)
    assert_equal false, response_data['success']
    assert response_data['errors']
  end

  private

  def sign_in_as(user)
    post session_path, params: { 
      email_address: user.email_address, 
      password: "password" 
    }
  end

  def sign_out
    delete session_path
  end
end