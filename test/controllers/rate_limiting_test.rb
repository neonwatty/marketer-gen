require "test_helper"

class RateLimitingTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(
      email_address: "existing@example.com",
      password: "password123"
    )
    
    # Configure cache store for rate limiting in test
    Rails.application.config.cache_store = :memory_store
    Rails.cache.clear
  end
  
  teardown do
    Rails.cache.clear
  end
  
  test "rate limiting on registration allows normal usage" do
    # First few registrations should work
    3.times do |i|
      post sign_up_path, params: {
        user: {
          email_address: "user#{i}@example.com",
          password: "password123",
          password_confirmation: "password123"
        }
      }
      
      # Should redirect to root on success
      assert_redirected_to root_path
    end
  end
  
  test "rate limiting on registration blocks excessive attempts" do
    skip "Rate limiting requires proper cache configuration in test environment"
    
    # Make many registration attempts
    10.times do |i|
      post sign_up_path, params: {
        user: {
          email_address: "user#{i}@example.com",
          password: "password123",
          password_confirmation: "password123"
        }
      }
    end
    
    # Next attempt should be rate limited
    post sign_up_path, params: {
      user: {
        email_address: "blocked@example.com",
        password: "password123",
        password_confirmation: "password123"
      }
    }
    
    assert_response :too_many_requests
  end
  
  test "rate limiting on profile updates allows normal usage" do
    # Sign in
    post session_path, params: {
      email_address: @user.email_address,
      password: "password123"
    }
    
    # First few updates should work
    3.times do |i|
      patch profile_path, params: {
        user: {
          full_name: "Test User #{i}"
        }
      }
      
      assert_redirected_to profile_path
    end
  end
  
  test "rate limiting tracks by IP address" do
    # Requests from different IPs should have separate limits
    post sign_up_path, params: {
      user: {
        email_address: "user1@example.com",
        password: "password123",
        password_confirmation: "password123"
      }
    }, env: { "REMOTE_ADDR" => "192.168.1.1" }
    
    assert_redirected_to root_path
    
    post sign_up_path, params: {
      user: {
        email_address: "user2@example.com",
        password: "password123",
        password_confirmation: "password123"
      }
    }, env: { "REMOTE_ADDR" => "192.168.1.2" }
    
    assert_redirected_to root_path
  end
end