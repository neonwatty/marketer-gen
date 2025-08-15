require "test_helper"

class JourneyRoutingTest < ActionDispatch::IntegrationTest
  def setup
    @user = users(:one)
    @journey = journeys(:awareness_journey)
    @journey_step = journey_steps(:awareness_step_one)
  end

  test "journeys routes" do
    # Index
    assert_routing({ method: :get, path: "/journeys" }, 
                   { controller: "journeys", action: "index" })

    # Show
    assert_routing({ method: :get, path: "/journeys/1" }, 
                   { controller: "journeys", action: "show", id: "1" })

    # New
    assert_routing({ method: :get, path: "/journeys/new" }, 
                   { controller: "journeys", action: "new" })

    # Create
    assert_routing({ method: :post, path: "/journeys" }, 
                   { controller: "journeys", action: "create" })

    # Edit
    assert_routing({ method: :get, path: "/journeys/1/edit" }, 
                   { controller: "journeys", action: "edit", id: "1" })

    # Update
    assert_routing({ method: :patch, path: "/journeys/1" }, 
                   { controller: "journeys", action: "update", id: "1" })

    # Destroy
    assert_routing({ method: :delete, path: "/journeys/1" }, 
                   { controller: "journeys", action: "destroy", id: "1" })

    # Custom member route - reorder_steps
    assert_routing({ method: :patch, path: "/journeys/1/reorder_steps" }, 
                   { controller: "journeys", action: "reorder_steps", id: "1" })
  end

  test "nested journey_steps routes" do
    # New
    assert_routing({ method: :get, path: "/journeys/1/journey_steps/new" }, 
                   { controller: "journey_steps", action: "new", journey_id: "1" })

    # Create
    assert_routing({ method: :post, path: "/journeys/1/journey_steps" }, 
                   { controller: "journey_steps", action: "create", journey_id: "1" })

    # Edit
    assert_routing({ method: :get, path: "/journeys/1/journey_steps/2/edit" }, 
                   { controller: "journey_steps", action: "edit", journey_id: "1", id: "2" })

    # Update
    assert_routing({ method: :patch, path: "/journeys/1/journey_steps/2" }, 
                   { controller: "journey_steps", action: "update", journey_id: "1", id: "2" })

    # Destroy
    assert_routing({ method: :delete, path: "/journeys/1/journey_steps/2" }, 
                   { controller: "journey_steps", action: "destroy", journey_id: "1", id: "2" })
  end

  test "journey_steps routes exclude show action" do
    # Show should not be routed (excluded in routes.rb)
    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path("/journeys/1/journey_steps/2", method: :get)
    end
  end

  test "route helpers work correctly" do
    # Journey route helpers
    assert_equal "/journeys", journeys_path
    assert_equal "/journeys/#{@journey.id}", journey_path(@journey)
    assert_equal "/journeys/new", new_journey_path
    assert_equal "/journeys/#{@journey.id}/edit", edit_journey_path(@journey)
    assert_equal "/journeys/#{@journey.id}/reorder_steps", reorder_steps_journey_path(@journey)

    # Nested journey step route helpers
    assert_equal "/journeys/#{@journey.id}/journey_steps/new", 
                 new_journey_journey_step_path(@journey)
    assert_equal "/journeys/#{@journey.id}/journey_steps", 
                 journey_journey_steps_path(@journey)
    assert_equal "/journeys/#{@journey.id}/journey_steps/#{@journey_step.id}/edit", 
                 edit_journey_journey_step_path(@journey, @journey_step)
    assert_equal "/journeys/#{@journey.id}/journey_steps/#{@journey_step.id}", 
                 journey_journey_step_path(@journey, @journey_step)
  end

  test "route constraints and requirements" do
    # Test that routes exist and are routable
    assert_routing({ method: :get, path: "/journeys/123" }, 
                   { controller: "journeys", action: "show", id: "123" })
    
    assert_routing({ method: :get, path: "/journeys/123/journey_steps/456/edit" }, 
                   { controller: "journey_steps", action: "edit", journey_id: "123", id: "456" })
  end

  test "route generation with parameters" do
    # Test query parameters are preserved
    path_with_params = journeys_path(campaign_type: "awareness", status: "active")
    assert_equal "/journeys?campaign_type=awareness&status=active", path_with_params

    # Test template type parameter for new journey
    path_with_template = new_journey_path(template_type: "webinar")
    assert_equal "/journeys/new?template_type=webinar", path_with_template
  end
end