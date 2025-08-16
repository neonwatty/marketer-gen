require "test_helper"

class CampaignPlansRoutingTest < ActionDispatch::IntegrationTest
  test "should route to campaign plans index" do
    assert_routing "/campaign_plans", 
      controller: "campaign_plans", action: "index"
  end

  test "should route to campaign plans show" do
    assert_routing "/campaign_plans/1", 
      controller: "campaign_plans", action: "show", id: "1"
  end

  test "should route to campaign plans new" do
    assert_routing "/campaign_plans/new", 
      controller: "campaign_plans", action: "new"
  end

  test "should route to campaign plans create" do
    assert_routing({ path: "/campaign_plans", method: :post },
      controller: "campaign_plans", action: "create")
  end

  test "should route to campaign plans edit" do
    assert_routing "/campaign_plans/1/edit", 
      controller: "campaign_plans", action: "edit", id: "1"
  end

  test "should route to campaign plans update" do
    assert_routing({ path: "/campaign_plans/1", method: :patch },
      controller: "campaign_plans", action: "update", id: "1")
  end

  test "should route to campaign plans destroy" do
    assert_routing({ path: "/campaign_plans/1", method: :delete },
      controller: "campaign_plans", action: "destroy", id: "1")
  end

  test "should route to campaign plans generate" do
    assert_routing({ path: "/campaign_plans/1/generate", method: :post },
      controller: "campaign_plans", action: "generate", id: "1")
  end

  test "should route to campaign plans regenerate" do
    assert_routing({ path: "/campaign_plans/1/regenerate", method: :post },
      controller: "campaign_plans", action: "regenerate", id: "1")
  end

  test "should route to campaign plans archive" do
    assert_routing({ path: "/campaign_plans/1/archive", method: :patch },
      controller: "campaign_plans", action: "archive", id: "1")
  end

  test "should generate correct paths" do
    assert_equal "/campaign_plans", campaign_plans_path
    assert_equal "/campaign_plans/1", campaign_plan_path(1)
    assert_equal "/campaign_plans/new", new_campaign_plan_path
    assert_equal "/campaign_plans/1/edit", edit_campaign_plan_path(1)
    assert_equal "/campaign_plans/1/generate", generate_campaign_plan_path(1)
    assert_equal "/campaign_plans/1/regenerate", regenerate_campaign_plan_path(1)
    assert_equal "/campaign_plans/1/archive", archive_campaign_plan_path(1)
  end

  test "should recognize routes with parameters" do
    # Test with query parameters
    get "/campaign_plans?campaign_type=product_launch&status=draft"
    assert_equal "campaign_plans", @controller.controller_name
    assert_equal "index", @controller.action_name
    assert_equal "product_launch", @request.params[:campaign_type]
    assert_equal "draft", @request.params[:status]
  end

  test "should not route to invalid actions" do
    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path("/campaign_plans/1/invalid_action", method: :post)
    end
  end

  test "should handle nested resource constraints" do
    # Verify the routes are properly configured for member actions
    assert_routing({ path: "/campaign_plans/123/generate", method: :post },
      controller: "campaign_plans", action: "generate", id: "123")
    
    # Non-numeric IDs should still route (will be handled by controller)
    assert_routing({ path: "/campaign_plans/abc/generate", method: :post },
      controller: "campaign_plans", action: "generate", id: "abc")
    
    # Add some assertion to prevent warning
    assert true
  end

  test "should integrate with existing route structure" do
    # Verify campaign plans routes don't conflict with existing routes
    assert_routing "/", controller: "home", action: "index"
    assert_routing "/journeys", controller: "journeys", action: "index"
    assert_routing "/brand_identities", controller: "brand_identities", action: "index"
  end

  test "should support all HTTP methods correctly" do
    methods_and_actions = {
      get: %w[index show new edit],
      post: %w[create generate regenerate],
      patch: %w[update archive],
      delete: %w[destroy]
    }

    methods_and_actions.each do |method, actions|
      actions.each do |action|
        case action
        when "index", "new"
          path = action == "index" ? "/campaign_plans" : "/campaign_plans/#{action}"
          assert_routing({ path: path, method: method },
            controller: "campaign_plans", action: action)
        when "create"
          assert_routing({ path: "/campaign_plans", method: method },
            controller: "campaign_plans", action: action)
        else
          path = case action
                 when "show"
                   "/campaign_plans/1"
                 when "edit"
                   "/campaign_plans/1/edit"
                 when "update", "destroy"
                   "/campaign_plans/1"
                 else
                   "/campaign_plans/1/#{action}"
                 end
          
          expected = { controller: "campaign_plans", action: action, id: "1" }
          expected.delete(:id) if %w[create].include?(action)
          
          assert_routing({ path: path, method: method }, expected)
        end
      end
    end
  end
end