require "test_helper"

class Api::V1::AnalyticsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @journey = journeys(:one)
    @journey.update!(user: @user)
    sign_in_as(@user)
  end

  test "should get analytics overview" do
    get overview_api_v1_analytics_index_url, as: :json
    assert_response :success
    
    response_data = JSON.parse(response.body)
    assert response_data['success']
    assert response_data['data']['summary']
    assert response_data['data']['journeys']
    assert response_data['data']['campaigns']
    assert response_data['data']['performance']
  end

  test "should get analytics overview with custom days" do
    get overview_api_v1_analytics_index_url, params: { days: 30 }, as: :json
    assert_response :success
    
    response_data = JSON.parse(response.body)
    assert response_data['success']
    assert_equal 30, response_data['data']['summary']['period_days']
  end

  test "should get journey analytics" do
    get journey_analytics_api_v1_analytics_index_url(@journey.id), as: :json
    assert_response :success
    
    response_data = JSON.parse(response.body)
    assert response_data['success']
    assert response_data['data']['summary']
    assert response_data['data']['performance_score']
    assert response_data['data']['step_analytics']
  end

  test "should get funnel analytics" do
    get funnel_analytics_api_v1_analytics_index_url(@journey.id), as: :json
    assert_response :success
    
    response_data = JSON.parse(response.body)
    assert response_data['success']
    assert response_data['data']['overview']
    assert response_data['data']['steps']
    assert response_data['data']['drop_off_analysis']
  end

  test "should get trends" do
    get trends_api_v1_analytics_index_url, params: { metric: 'conversion_rate' }, as: :json
    assert_response :success
    
    response_data = JSON.parse(response.body)
    assert response_data['success']
    assert_equal 'conversion_rate', response_data['data']['metric']
    assert response_data['data']['data_points'].is_a?(Array)
  end

  test "should get real time analytics" do
    get real_time_api_v1_analytics_index_url, as: :json
    assert_response :success
    
    response_data = JSON.parse(response.body)
    assert response_data['success']
    assert response_data['data']['active_journeys']
    assert response_data['data']['recent_executions']
    assert response_data['data']['system_health']
  end

  test "should create custom report" do
    report_params = {
      name: "Custom Test Report",
      description: "Test report",
      date_range_days: 30,
      metrics: ["conversion_rate", "engagement_score"],
      filters: { status: "published" }
    }

    post custom_report_api_v1_analytics_index_url, params: report_params, as: :json
    assert_response :success
    
    response_data = JSON.parse(response.body)
    assert response_data['success']
    assert_equal "Custom Test Report", response_data['data']['report_name']
  end

  test "should handle invalid metric for trends" do
    get trends_api_v1_analytics_index_url, params: { metric: 'invalid_metric' }, as: :json
    assert_response :unprocessable_entity
    
    response_data = JSON.parse(response.body)
    assert_equal false, response_data['success']
    assert_match(/Invalid metric/, response_data['message'])
  end

  test "should require authentication" do
    sign_out
    
    get overview_api_v1_analytics_index_url, as: :json
    assert_response :unauthorized
  end

  test "should not access other user's journey analytics" do
    other_user = users(:two)
    other_journey = journeys(:two)
    other_journey.update!(user: other_user)

    get journey_analytics_api_v1_analytics_index_url(other_journey.id), as: :json
    assert_response :not_found
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