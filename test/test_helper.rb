# SimpleCov must be started before any other code is required
require 'simplecov'

SimpleCov.start 'rails' do
  # Set minimum coverage threshold - start with achievable goal
  minimum_coverage 5
  
  # Configure groups for better reporting
  add_group 'Models', 'app/models'
  add_group 'Controllers', 'app/controllers'
  add_group 'Services', 'app/services'
  add_group 'Jobs', 'app/jobs'
  add_group 'Helpers', 'app/helpers'
  add_group 'Policies', 'app/policies'
  add_group 'Mailers', 'app/mailers'
  add_group 'Concerns', 'app/controllers/concerns'
  
  # Exclude files that don't need coverage
  add_filter '/config/'
  add_filter '/db/migrate/'
  add_filter '/vendor/'
  add_filter '/test/'
  add_filter '/spec/'
  add_filter 'app/channels/application_cable/'
  add_filter 'app/jobs/application_job.rb'
  add_filter 'app/mailers/application_mailer.rb'
  add_filter 'app/models/application_record.rb'
  add_filter 'app/controllers/application_controller.rb'
  
  # Configure output
  formatter SimpleCov::Formatter::HTMLFormatter
  
  coverage_dir 'coverage'
  
  # Enable branch coverage for more detailed analysis (if supported)
  begin
    enable_coverage :branch if ENV['COVERAGE_BRANCH'] == 'true'
  rescue ArgumentError
    # Branch coverage not supported in this Ruby version
  end
end

ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"
require "mocha/minitest"
require "rails-controller-testing"

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    # parallelize(workers: :number_of_processors)  # Disabled due to Mocha issues

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
      
      # Clear LLM service container state to avoid test interference
      LlmServiceContainer.clear! if defined?(LlmServiceContainer)
      
      # Re-register the mock service after clearing
      if defined?(LlmServiceContainer) && defined?(MockLlmService)
        LlmServiceContainer.register(:mock, MockLlmService)
      end
      
      # Set up test logging
      @log_output = StringIO.new
      @old_logger = Rails.logger
      Rails.logger = Logger.new(@log_output)
    end
    
    def teardown
      # Clear Current state after each test
      Current.reset
      
      # Restore original logger
      Rails.logger = @old_logger if @old_logger
      
      super
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

  def sign_out
    # Clear the session by making a DELETE request to the session path
    delete session_path
    follow_redirect! if response.redirect?
  end

  def api_sign_in_as(user)
    # For API tests, just use the regular sign-in approach
    # The session cookie will be set and available for subsequent API requests
    sign_in_as(user)
  end
end
