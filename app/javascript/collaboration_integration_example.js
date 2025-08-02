// Example integration for real-time collaboration features
// This demonstrates how to use the collaboration system in your Rails views

// 1. Campaign Plan Collaboration Example
/*
In your campaign plan view, add:

<div data-controller="campaign-collaboration" 
     data-campaign-collaboration-campaign-plan-id-value="<%= @campaign_plan.id %>"
     data-campaign-collaboration-current-user-value="<%= current_user.to_json %>"
     data-campaign-collaboration-initial-version-value="<%= @campaign_plan.version %>">
  
  <!-- Presence indicator -->
  <div data-campaign-collaboration-target="presenceIndicator" class="presence-indicator">
    <span class="online-count">0 online</span>
    <div class="status-dot"></div>
  </div>
  
  <!-- Collaborators list -->
  <div data-campaign-collaboration-target="collaboratorsList" class="collaborators-list">
    <!-- Dynamic content -->
  </div>
  
  <!-- Plan fields -->
  <input type="text" 
         data-campaign-collaboration-target="planField"
         data-field="strategic_rationale"
         data-original-value="<%= @campaign_plan.strategic_rationale %>"
         class="plan-field">
  
  <!-- Comments sidebar -->
  <div data-campaign-collaboration-target="commentsSidebar" class="comments-sidebar">
    <!-- Dynamic comments -->
  </div>
  
  <!-- Version info -->
  <div data-campaign-collaboration-target="versionInfo" class="version-info">
    v<%= @campaign_plan.version %>
  </div>
</div>
*/

// 2. Content Editor Collaboration Example
/*
In your content editor view, add:

<div data-controller="content-collaboration"
     data-content-collaboration-content-id-value="<%= @content.id %>"
     data-content-collaboration-current-user-value="<%= current_user.to_json %>"
     data-content-collaboration-initial-content-value="<%= @content.current_version&.body %>"
     data-content-collaboration-initial-version-value="<%= @content.total_versions %>">
  
  <!-- Editor textarea -->
  <textarea data-content-collaboration-target="editor"
            id="content-editor"
            class="content-field"><%= @content.current_version&.body %></textarea>
  
  <!-- Collaborators list -->
  <div data-content-collaboration-target="collaboratorsList" class="collaborators-list">
    <!-- Dynamic content -->
  </div>
  
  <!-- Save status -->
  <div data-content-collaboration-target="saveStatus" class="save-status">
    All changes saved
  </div>
  
  <!-- Version info -->
  <div data-content-collaboration-target="versionInfo" class="version-info">
    v<%= @content.total_versions %>
  </div>
</div>
*/

// 3. A/B Test Monitoring Example
/*
In your A/B test monitoring view, add:

<div data-controller="ab-test-realtime"
     data-ab-test-realtime-ab-test-id-value="<%= @ab_test.id %>"
     data-ab-test-realtime-current-user-value="<%= current_user.to_json %>"
     data-ab-test-realtime-auto-refresh-interval-value="30000">
  
  <!-- Test status -->
  <div data-ab-test-realtime-target="testStatus" 
       class="test-status status-<%= @ab_test.status %>">
    <%= @ab_test.status.humanize %>
  </div>
  
  <!-- Variant cards -->
  <% @ab_test.ab_test_variants.each do |variant| %>
    <div data-ab-test-realtime-target="variantCard" 
         data-variant-id="<%= variant.id %>"
         class="variant-card <%= 'is-control' if variant.is_control %>">
      
      <h4 class="variant-name"><%= variant.name %></h4>
      
      <div class="metrics-grid">
        <div class="metric-item">
          <div class="metric-label">Visitors</div>
          <div class="metric-value" data-metric="visitors">
            <%= number_with_delimiter(variant.total_visitors) %>
          </div>
        </div>
        <div class="metric-item">
          <div class="metric-label">Conversions</div>
          <div class="metric-value" data-metric="conversions">
            <%= number_with_delimiter(variant.conversions) %>
          </div>
        </div>
        <div class="metric-item">
          <div class="metric-label">Rate</div>
          <div class="metric-value" data-metric="conversion_rate">
            <%= variant.conversion_rate.round(2) %>%
          </div>
        </div>
      </div>
      
      <!-- Chart container -->
      <div data-chart class="chart-container">
        <!-- Dynamic chart -->
      </div>
      
      <!-- Traffic allocation slider -->
      <input type="range" 
             data-ab-test-realtime-target="trafficSlider"
             data-variant-id="<%= variant.id %>"
             min="0" max="100" 
             value="<%= variant.traffic_percentage %>"
             class="traffic-slider">
    </div>
  <% end %>
  
  <!-- Control buttons -->
  <button data-ab-test-realtime-target="pauseButton" class="btn btn-warning">
    Pause Test
  </button>
  <button data-ab-test-realtime-target="stopButton" class="btn btn-danger">
    Stop Test
  </button>
  
  <!-- Monitors list -->
  <div data-ab-test-realtime-target="monitorsList" class="monitors-list">
    <!-- Dynamic monitors -->
  </div>
  
  <!-- Alerts container -->
  <div data-ab-test-realtime-target="alertsContainer" class="alerts-container">
    <!-- Dynamic alerts -->
  </div>
  
  <!-- Winner banner -->
  <div data-ab-test-realtime-target="winnerBanner" class="winner-banner">
    <!-- Dynamic winner announcement -->
  </div>
</div>
*/

// 4. CSS Classes for Styling
/*
Add this to your application.scss:

@import "collaboration";

Or include the collaboration styles directly in your layout:

<link rel="stylesheet" href="<%= asset_path('collaboration.css') %>">
*/

// 5. Rails Configuration
/*
Ensure you have ActionCable configured in config/cable.yml:

development:
  adapter: redis
  url: redis://localhost:6379/1

production:
  adapter: redis
  url: <%= ENV.fetch("REDIS_URL") { "redis://localhost:6379/1" } %>
  channel_prefix: your_app_production

And in config/routes.rb:
mount ActionCable.server => '/cable'
*/

// 6. Security Considerations
/*
Ensure your ApplicationCable::Connection properly authenticates users:

module ApplicationCable
  class Connection < ActionCable::Connection::Base
    identified_by :current_user

    def connect
      set_current_user || reject_unauthorized_connection
    end

    private
      def set_current_user
        if session = Session.find_by(id: cookies.signed[:session_id])
          self.current_user = session.user
        end
      end
  end
end
*/

// 7. Environment Variables
/*
Set these environment variables for production:

REDIS_URL=redis://your-redis-server:6379/0
ACTION_CABLE_ALLOWED_REQUEST_ORIGINS=https://your-domain.com
*/

// 8. Performance Monitoring
/*
Monitor WebSocket connections and message throughput:

// In your Rails application
Rails.application.config.action_cable.disable_request_forgery_protection = false
Rails.application.config.action_cable.allow_same_origin_as_host = true

// Add logging
Rails.application.config.action_cable.log_tags = [
  :action_cable,
  -> request { request.uuid }
]
*/

// 9. Browser Compatibility
/*
The collaboration features require:
- WebSocket support (all modern browsers)
- ES6+ features (transform with Babel if needed)
- CSS Grid (fallback to flexbox if needed)

Add polyfills if supporting older browsers:
npm install --save core-js regenerator-runtime
*/

// 10. Testing
/*
Test collaboration features with:

// RSpec for Rails channels
RSpec.describe CampaignCollaborationChannel, type: :channel do
  it "subscribes to collaboration stream" do
    campaign_plan = create(:campaign_plan)
    subscribe(campaign_plan_id: campaign_plan.id)
    expect(subscription).to be_confirmed
  end
end

// JavaScript tests with Jest
import { getCollaborationWebSocket } from '../utils/collaborationWebSocket';

describe('CollaborationWebSocket', () => {
  test('establishes connection', () => {
    const ws = getCollaborationWebSocket();
    expect(ws).toBeDefined();
  });
});
*/

export default {
  // Helper functions for manual integration
  initializeCampaignCollaboration: (campaignPlanId, currentUser) => {
    const element = document.querySelector('[data-controller="campaign-collaboration"]');
    if (element) {
      element.dataset.campaignCollaborationCampaignPlanIdValue = campaignPlanId;
      element.dataset.campaignCollaborationCurrentUserValue = JSON.stringify(currentUser);
    }
  },

  initializeContentCollaboration: (contentId, currentUser, initialContent) => {
    const element = document.querySelector('[data-controller="content-collaboration"]');
    if (element) {
      element.dataset.contentCollaborationContentIdValue = contentId;
      element.dataset.contentCollaborationCurrentUserValue = JSON.stringify(currentUser);
      element.dataset.contentCollaborationInitialContentValue = initialContent;
    }
  },

  initializeAbTestMonitoring: (abTestId, currentUser) => {
    const element = document.querySelector('[data-controller="ab-test-realtime"]');
    if (element) {
      element.dataset.abTestRealtimeAbTestIdValue = abTestId;
      element.dataset.abTestRealtimeCurrentUserValue = JSON.stringify(currentUser);
    }
  }
};