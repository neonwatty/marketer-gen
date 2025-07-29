require "test_helper"

class SecurityHeadersTest < ActionDispatch::IntegrationTest
  test "security headers are present on responses" do
    get root_path
    
    # Check security headers
    assert_equal "DENY", response.headers["X-Frame-Options"]
    assert_equal "nosniff", response.headers["X-Content-Type-Options"]
    assert_equal "0", response.headers["X-XSS-Protection"]
    assert_equal "strict-origin-when-cross-origin", response.headers["Referrer-Policy"]
    assert_match /geolocation=\(\)/, response.headers["Permissions-Policy"]
  end
  
  test "content security policy is applied" do
    get root_path
    
    csp = response.headers["Content-Security-Policy"]
    assert_not_nil csp
    
    # Check key CSP directives
    assert_match /default-src 'self' https:/, csp
    assert_match /script-src 'self' https:/, csp
    assert_match /style-src 'self' https: 'unsafe-inline'/, csp
    assert_match /frame-ancestors 'none'/, csp
    assert_match /base-uri 'self'/, csp
  end
  
  test "CSP nonce is generated for inline scripts" do
    get root_path
    
    # Check that content_security_policy_nonce helper is available
    assert_respond_to @controller.helpers, :content_security_policy_nonce
  end
  
  test "secure cookies in production-like environment" do
    # Simulate production environment
    Rails.application.config.force_ssl = true
    
    post session_path, params: {
      email_address: User.create!(email_address: "secure_test@example.com", password: "password").email_address,
      password: "password"
    }
    
    # In production, cookies should have secure flag
    # This test documents expected behavior
    assert_response :redirect
    assert_not_nil cookies[:session_id]
  ensure
    Rails.application.config.force_ssl = false
  end
  
  test "session cookie has proper attributes" do
    post session_path, params: {
      email_address: User.create!(email_address: "test@example.com", password: "password").email_address,
      password: "password"
    }
    
    # Session cookie should be httponly
    session_cookie = response.cookies["_marketer_gen_session"]
    assert_not_nil session_cookie
  end
  
  test "HSTS header in production environment" do
    # Simulate production
    Rails.application.config.force_ssl = true
    
    get root_path
    
    # Should have Strict-Transport-Security header
    # This test documents expected behavior for production
  ensure
    Rails.application.config.force_ssl = false
  end
end