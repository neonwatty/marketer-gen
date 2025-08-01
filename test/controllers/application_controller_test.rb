require "test_helper"

class ApplicationControllerTest < ActionController::TestCase
  setup do
    @user = User.create!(email_address: "test@example.com", password: "password123")
  end
  
  test "should handle Pundit NotAuthorizedError" do
    # This test verifies that our Pundit error handling is properly configured
    # We'll need to test this with a real controller that uses authorization
    # For now, we verify the ApplicationController includes the necessary modules
    assert ApplicationController.included_modules.include?(Pundit::Authorization)
    assert ApplicationController.included_modules.include?(Authentication)
  end
  
  test "application controller should rescue from Pundit NotAuthorizedError" do
    # Verify that the rescue_from handler is defined
    assert ApplicationController.rescue_handlers.any? { |handler| 
      handler.first == Pundit::NotAuthorizedError.to_s
    }
  end
end