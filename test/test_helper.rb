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
    
    # Ensure proper test isolation
    parallelize_setup do |worker|
      # Each worker gets its own database
      ActiveRecord::Base.connection.reconnect!
    end
    
    # Clean up after each test
    teardown do
      # Clear any cached current attributes
      Current.reset if defined?(Current)
    end
    
    # Include FactoryBot methods
    include FactoryBot::Syntax::Methods
    
    # Include ActionMailer test helpers
    include ActionMailer::TestHelper
    
    # Include ActiveJob test helpers for job assertions
    include ActiveJob::TestHelper

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

    # Helper method to mock LLM service responses for campaign planning
    def mock_campaign_planning_llm_response
      response_data = {
        "strategic_rationale" => { "rationale" => "Comprehensive campaign strategy" },
        "target_audience" => { "primary" => "Tech professionals" },
        "success_metrics" => { "leads" => 100, "conversions" => 10 },
        "timeline" => { "duration_weeks" => 8 },
        "channels" => ["email", "social", "content"]
      }
      
      LlmService.any_instance.stubs(:analyze).returns(response_data.to_json)
      stub_request(:post, /api\.openai\.com/)
        .to_return(
          status: 200,
          body: {
            choices: [
              {
                message: {
                  content: response_data.to_json
                }
              }
            ]
          }.to_json,
          headers: { 'Content-Type' => 'application/json' }
        )
    end

    # Helper method to mock creative approach responses
    def mock_creative_approach_llm_response
      response_data = {
        "main_theme" => "Innovation meets excellence",
        "creative_direction" => "Professional, modern approach",
        "emotional_appeal" => "Confidence and empowerment",
        "narrative_structure" => "Challenge to solution to success",
        "key_visuals" => ["Professional team collaboration", "Data visualization"],
        "content_pillars" => ["Industry expertise", "Customer success"]
      }
      
      LlmService.any_instance.stubs(:analyze).returns(response_data.to_json)
      stub_request(:post, /api\.openai\.com/)
        .to_return(
          status: 200,
          body: {
            choices: [
              {
                message: {
                  content: response_data.to_json
                }
              }
            ]
          }.to_json,
          headers: { 'Content-Type' => 'application/json' }
        )
    end
    
    # Helper to sign in a user (alias for controller tests)
    def sign_in(user, password = "password")
      sign_in_as(user, password)
    end
    
    # Helper to sign in a user for both controller and integration tests
    def sign_in_as(user, password = "password")
      if self.class < ActionDispatch::IntegrationTest
        # Integration test - use the proper login flow by posting to sessions
        post session_path, params: { 
          email_address: user.email_address, 
          password: password 
        }
        # Follow any redirect to complete the login flow
        follow_redirect! if response.redirect?
      else
        # Controller test - set cookies and session directly
        session = user.sessions.create!(
          user_agent: 'Test User Agent',
          ip_address: '127.0.0.1',
          expires_at: 24.hours.from_now,
          last_active_at: Time.current
        )
        
        # Set the signed cookie using ActionDispatch cookie jar
        if defined?(cookies) && cookies.respond_to?(:signed)
          cookies.signed[:session_id] = {
            value: session.id,
            httponly: true,
            same_site: :lax,
            secure: false, # Not secure in test environment
            expires: 24.hours.from_now
          }
        end
        
        # Set Current.session for immediate use in the current thread
        Current.session = session
        
        # Return the session for any additional test setup
        session
      end
    end
  end
end

# Simple VCR stub for tests that expect it
module VCR
  def self.use_cassette(name, &block)
    # Simply execute the block without recording
    yield if block_given?
  end
end

# A/B Testing service class aliases for backward compatibility
# Create global aliases for namespaced services to make tests work
AbTestVariantGenerator = AbTesting::AbTestVariantGenerator
MessagingVariantEngine = AbTesting::MessagingVariantEngine
VisualVariantEngine = AbTesting::VisualVariantEngine
AbTestVariantManager = AbTesting::AbTestVariantManager
AbTestTrafficSplitter = AbTesting::AbTestTrafficSplitter
AdaptiveTrafficAllocator = AbTesting::AdaptiveTrafficAllocator
ConstrainedTrafficAllocator = AbTesting::ConstrainedTrafficAllocator
RealTimeAbTestMetrics = AbTesting::RealTimeAbTestMetrics
AbTestStatisticalAnalyzer = AbTesting::AbTestStatisticalAnalyzer
BayesianAbTestAnalyzer = AbTesting::BayesianAbTestAnalyzer
AbTestConfidenceCalculator = AbTesting::AbTestConfidenceCalculator
AbTestEarlyStopping = AbTesting::AbTestEarlyStopping
AbTestWinnerDeclarator = AbTesting::AbTestWinnerDeclarator
AbTestAIRecommender = AbTesting::AbTestAiRecommender
AbTestPatternRecognizer = AbTesting::AbTestPatternRecognizer
AbTestOptimizationAI = AbTesting::AbTestOptimizationAi
AbTestOutcomePredictor = AbTesting::AbTestOutcomePredictor
