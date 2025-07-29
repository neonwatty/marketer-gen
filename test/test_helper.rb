ENV["RAILS_ENV"] ||= "test"

# SimpleCov must be started before any application code
require 'simplecov'
SimpleCov.start 'rails' do
  add_filter '/test/'
  add_filter '/config/'
  add_filter '/vendor/'
  
  add_group 'Controllers', 'app/controllers'
  add_group 'Models', 'app/models'
  add_group 'Helpers', 'app/helpers'
  add_group 'Mailers', 'app/mailers'
  add_group 'Policies', 'app/policies'
  add_group 'Services', 'app/services'
  add_group 'Jobs', 'app/jobs'
end

require_relative "../config/environment"
require "rails/test_help"
require "mocha/minitest"
require "webmock/minitest"
require "minitest/reporters"

# Configure test environment to handle assets
WebMock.disable_net_connect!(allow_localhost: true)

# Use more verbose test reporter
Minitest::Reporters.use!(
  Minitest::Reporters::SpecReporter.new,
  ENV,
  Minitest.backtrace_filter
)

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    # Disable parallelization when running with coverage
    parallelize(workers: :number_of_processors) unless ENV['COVERAGE']

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all
    
    # Include FactoryBot methods
    include FactoryBot::Syntax::Methods

    # Add more helper methods to be used by all tests here...
    
    # Helper method for sign in path
    def sign_in_path
      new_session_path
    end
    
    # Mock LLM API responses for testing
    def mock_llm_response(response_text = "Mocked LLM response")
      stub_request(:post, /api\.openai\.com/)
        .to_return(
          status: 200,
          body: {
            choices: [
              {
                message: {
                  content: response_text
                }
              }
            ]
          }.to_json,
          headers: { 'Content-Type' => 'application/json' }
        )
    end
    
    # Helper to sign in a user for controller tests
    def sign_in_as(user, password = "password123")
      post session_path, params: { email_address: user.email_address, password: password }
    end
  end
end
