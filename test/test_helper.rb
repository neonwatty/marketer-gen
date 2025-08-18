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
    
    # Helper method to create valid test content that meets validation requirements
    def create_valid_test_content(options = {})
      defaults = {
        content_type: "blog_article",
        format_variant: "standard",
        status: "draft",
        version_number: 1,
        title: "Test Content #{SecureRandom.hex(4)}"
      }
      
      attributes = defaults.merge(options)
      
      # Generate appropriate body content based on format variant
      attributes[:body_content] ||= generate_body_content_for_format(attributes[:format_variant])
      
      GeneratedContent.create!(attributes)
    end
    
    private
    
    def generate_body_content_for_format(format_variant)
      case format_variant
      when 'short', 'brief'
        "This is a short test content for #{format_variant} format testing."
      when 'summary'
        "This is a summary test content for testing purposes. It contains enough characters to meet the validation requirements for summary format content."
      when 'medium', 'standard'
        "This is a comprehensive test content for #{format_variant} format testing. It contains enough characters to meet the standard format requirements and provides a good foundation for testing various features of the content management system. This ensures all validation requirements are properly met."
      when 'long'
        content = "This is a long test content for testing purposes. " * 10
        content += "It contains substantial text to meet the validation requirements for long format content. "
        content += "This ensures that all tests can run properly without validation errors. " * 3
        content
      when 'extended', 'comprehensive'
        content = "This is an extended comprehensive test content for testing purposes. " * 15
        content += "It contains substantial text to meet the validation requirements for extended format content. " * 5
        content += "This ensures that all tests can run properly without validation errors and provides adequate content for comprehensive testing scenarios. " * 3
        content
      when 'detailed'
        content = "This is detailed test content for testing purposes. " * 8
        content += "It contains enough text to meet the validation requirements for detailed format content. " * 4
        content
      else
        "This is test content for #{format_variant} format testing. It contains enough characters to meet the standard validation requirements and provides a foundation for testing various features."
      end
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
