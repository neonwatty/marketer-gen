require "test_helper"

class ContentSecurityPolicyTest < ActionDispatch::IntegrationTest
  test "CSP header is present" do
    get root_path
    assert_response :success
    assert_not_nil response.headers["Content-Security-Policy"]
  end

  test "CSP allows necessary sources" do
    get root_path
    csp_header = response.headers["Content-Security-Policy"]
    
    # Should allow self and https for default sources
    assert_includes csp_header, "default-src 'self' https:"
    
    # Should allow unsafe-eval for importmap functionality
    assert_includes csp_header, "script-src 'self' https: 'unsafe-eval'"
    
    # Should allow unsafe-inline for Tailwind CSS
    assert_includes csp_header, "style-src 'self' https: 'unsafe-inline'"
    
    # Should allow CDN for external stylesheets
    assert_includes csp_header, "https://cdn.jsdelivr.net"
  end

  test "CSP nonce is generated for requests" do
    get root_path
    csp_header = response.headers["Content-Security-Policy"]
    
    # Should contain nonce for script-src
    assert_match /script-src[^;]*'nonce-[A-Za-z0-9+\/=]+'/, csp_header
    
    # Should contain nonce for style-src  
    assert_match /style-src[^;]*'nonce-[A-Za-z0-9+\/=]+'/, csp_header
  end

  test "journey builder page loads without CSP violations" do
    # This test assumes we have a user and can access the journey builder
    # Skip if authentication is required and we don't have a test user
    skip "Authentication required" unless defined?(create_test_user)
    
    get "/journey_templates/builder_react"
    assert_response :success
    
    # The page should load successfully with the CSP in place
    assert_select "div#react-journey-builder"
    
    # The inline script should have a nonce attribute
    assert_select "script[nonce]"
  end
end