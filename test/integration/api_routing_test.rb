# frozen_string_literal: true

require 'test_helper'

class ApiRoutingTest < ActionDispatch::IntegrationTest
  test "should route to content generation endpoints" do
    assert_routing(
      { method: 'post', path: '/api/v1/content_generation/social_media' },
      { controller: 'api/v1/content_generation', action: 'social_media' }
    )
    
    assert_routing(
      { method: 'post', path: '/api/v1/content_generation/email' },
      { controller: 'api/v1/content_generation', action: 'email' }
    )
    
    assert_routing(
      { method: 'post', path: '/api/v1/content_generation/ad_copy' },
      { controller: 'api/v1/content_generation', action: 'ad_copy' }
    )
    
    assert_routing(
      { method: 'post', path: '/api/v1/content_generation/landing_page' },
      { controller: 'api/v1/content_generation', action: 'landing_page' }
    )
    
    assert_routing(
      { method: 'post', path: '/api/v1/content_generation/campaign_plan' },
      { controller: 'api/v1/content_generation', action: 'campaign_plan' }
    )
    
    assert_routing(
      { method: 'post', path: '/api/v1/content_generation/variations' },
      { controller: 'api/v1/content_generation', action: 'variations' }
    )
    
    assert_routing(
      { method: 'post', path: '/api/v1/content_generation/optimize' },
      { controller: 'api/v1/content_generation', action: 'optimize' }
    )
    
    assert_routing(
      { method: 'post', path: '/api/v1/content_generation/brand_compliance' },
      { controller: 'api/v1/content_generation', action: 'brand_compliance' }
    )
    
    assert_routing(
      { method: 'post', path: '/api/v1/content_generation/analytics_insights' },
      { controller: 'api/v1/content_generation', action: 'analytics_insights' }
    )
    
    assert_routing(
      { method: 'get', path: '/api/v1/content_generation/health' },
      { controller: 'api/v1/content_generation', action: 'health' }
    )
  end

  test "should not route invalid paths" do
    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path('/api/v1/content_generation/invalid')
    end
  end

  test "should require correct HTTP methods" do
    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path(
        '/api/v1/content_generation/social_media', 
        method: :get
      )
    end
    
    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path(
        '/api/v1/content_generation/health', 
        method: :post
      )
    end
  end

  test "should route to correct API namespace" do
    # Ensure routes are under correct API versioning
    social_media_route = Rails.application.routes.recognize_path(
      '/api/v1/content_generation/social_media',
      method: :post
    )
    
    assert_equal 'api/v1/content_generation', social_media_route[:controller]
    assert_equal 'social_media', social_media_route[:action]
  end
end