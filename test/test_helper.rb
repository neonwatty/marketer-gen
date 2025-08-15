ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

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
    # Create a session for the user
    user_session = user.sessions.create!(
      user_agent: 'test',
      ip_address: '127.0.0.1'
    )
    
    # Use simple POST to authenticate and let Rails handle the session
    post session_path, params: { email_address: user.email_address, password: "password" }
    follow_redirect! if response.redirect?
  end
end
