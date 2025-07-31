require "test_helper"

class ErrorsControllerTest < ActionDispatch::IntegrationTest
  test "should render 404 error page" do
    get "/404"
    assert_response :not_found
    assert_select "h1", text: "Page not found"
    assert_select "a[href='#{root_path}']", text: "Go Home"
  end
  
  test "should render 422 error page" do
    get "/422"
    assert_response :unprocessable_entity
    assert_select "h1", text: "Request Error"
    assert_select "button", text: "Try Again"
  end
  
  test "should render 500 error page" do
    get "/500"
    assert_response :internal_server_error
    assert_select "h1", text: "Server Error"
    assert_select "button", text: "Refresh Page"
  end
  
  test "should handle non-existent routes with 404" do
    assert_raises(ActionController::RoutingError) do
      get "/non-existent-route"
    end
  end
  
  test "404 page should include search functionality" do
    get "/404"
    assert_response :not_found
    assert_select "input[placeholder*='Search']"
    assert_select "script", text: /performSearch/
  end
  
  test "500 page should include auto-retry functionality" do
    get "/500"
    assert_response :internal_server_error
    assert_select "script", text: /Auto-retry/
    assert_select "#auto-retry-section"
  end
  
  test "error pages should be mobile friendly" do
    get "/404"
    assert_response :not_found
    assert_select "meta[name='viewport'][content*='width=device-width']"
    assert_select ".sm\\:flex" # Responsive classes
  end
  
  test "error pages should include helpful navigation" do
    get "/404"
    assert_response :not_found
    assert_select "a[href='#{root_path}']"
    assert_select "button[onclick*='history.back']"
  end
  
  test "422 page should include troubleshooting steps" do
    get "/422"
    assert_response :unprocessable_entity
    assert_select "h3", text: "Common causes and solutions:"
    assert_select "h4", text: "Missing required fields"
    assert_select "h4", text: "Invalid data format"
  end
  
  test "500 page should show what we're doing about it" do
    get "/500"
    assert_response :internal_server_error
    assert_select "h3", text: "What we're doing about it:"
    assert_select ".text-green-500" # Success icons
  end
  
  test "all error pages should have contact support links" do
    [404, 422, 500].each do |code|
      get "/#{code}"
      assert_response code
      assert_select "a[href*='mailto:support@marketergen.com']", text: /Contact Support/
    end
  end
  
  test "error pages should not expose sensitive information" do
    get "/500"
    assert_response :internal_server_error
    
    # Should not contain stack traces, file paths, or other sensitive data
    response_body = response.body.downcase
    assert_not response_body.include?("backtrace")
    assert_not response_body.include?("/users/")
    assert_not response_body.include?("database")
    assert_not response_body.include?("password")
  end
end