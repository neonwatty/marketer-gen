ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"
require "mocha/minitest"

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # Add more helper methods to be used by all tests here...
    
    def setup
      super
      # Clear Current state before each test
      Current.reset
      
      # Clear all cached rate limiting and security monitoring data
      Rails.cache.clear
      
      # Clean up sessions to avoid test interference
      # Session.destroy_all  # Commented out to allow API tests to work
      
      # Set up test logging
      @log_output = StringIO.new
      @old_logger = Rails.logger
      Rails.logger = Logger.new(@log_output)
    end
    
    def teardown
      super
      # Clear Current state after each test
      Current.reset
      
      # Restore original logger
      Rails.logger = @old_logger if @old_logger
    end
    
    def sign_in_as(user)
      # Create a session for the user
      user_session = user.sessions.create!(
        user_agent: 'test',
        ip_address: '127.0.0.1'
      )
      
      # Set in Current for the duration of this test
      Current.session = user_session
    end
    
    def logs_containing(text)
      # Helper to find log entries containing specific text
      @log_output&.string&.lines&.select { |line| line.include?(text) } || []
    end
  end
end

class ActionDispatch::IntegrationTest
  def sign_in_as(user)
    # Perform authentication via standard login flow
    post session_path, params: { 
      email_address: user.email_address, 
      password: "password" 
    }
    
    # The response should be a redirect on successful authentication
    # This ensures the session cookie is set properly
    follow_redirect! if response.redirect?
  end

  def api_sign_in_as(user)
    # For API tests, just use the regular sign-in approach
    # The session cookie will be set and available for subsequent API requests
    sign_in_as(user)
  end
end
