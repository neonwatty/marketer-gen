require "test_helper"

class JourneysMultiManagementTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:admin_user)
    sign_in_as @user
    
    @journey1 = journeys(:admin_email_journey)
    @journey2 = journeys(:admin_social_journey)
    
    # Create some journey steps for testing analytics
    @journey1.journey_steps.create!(
      title: "Welcome Email",
      step_type: "email",
      channel: "email",
      sequence_order: 0,
      status: "completed"
    )
    @journey1.journey_steps.create!(
      title: "Follow-up Email",
      step_type: "email", 
      channel: "email",
      sequence_order: 1,
      status: "active"
    )
    
    @journey2.journey_steps.create!(
      title: "Social Post",
      step_type: "social_post",
      channel: "social_media",
      sequence_order: 0,
      status: "draft"
    )
  end

  test "should display analytics dashboard on journey index" do
    get journeys_url
    assert_response :success
    
    # Check for analytics cards in the dashboard section
    assert_select ".grid .bg-white .rounded-lg", minimum: 4
    assert_select "p", text: /Total Journeys/
    assert_select "p", text: /Active/
    assert_select "p", text: /Completed/
    assert_select "p", text: /Avg. Completion/
  end

  test "should search journeys by name and description" do
    # Test search by name
    get journeys_url, params: { search: "email" }
    assert_response :success
    assert_select ".grid .rounded-lg .font-semibold", text: @journey1.name
    
    # Test search by description  
    get journeys_url, params: { search: @journey1.description }
    assert_response :success
    assert_select ".grid .rounded-lg .font-semibold", text: @journey1.name
  end

  test "should duplicate journey successfully" do
    assert_difference('Journey.count', 1) do
      post duplicate_journey_url(@journey1)
    end
    
    follow_redirect!
    assert_response :success
    assert_match(/Journey duplicated successfully/, flash[:notice])
    
    # Check that the duplicated journey has correct attributes
    duplicated_journey = Journey.last
    assert_equal "#{@journey1.name} (Copy)", duplicated_journey.name
    assert_equal 'draft', duplicated_journey.status
    assert_equal @user, duplicated_journey.user
    assert_equal @journey1.campaign_type, duplicated_journey.campaign_type
  end

  test "should duplicate journey steps when duplicating journey" do
    initial_steps_count = @journey1.journey_steps.count
    
    post duplicate_journey_url(@journey1)
    
    duplicated_journey = Journey.last
    assert_equal initial_steps_count, duplicated_journey.journey_steps.count
    
    # Verify steps are duplicated with draft status
    duplicated_journey.journey_steps.each do |step|
      assert_equal 'draft', step.status
    end
  end

  test "should archive journey when conditions are met" do
    # Set journey to completed status (archivable)
    @journey1.update!(status: 'completed')
    
    patch archive_journey_url(@journey1)
    assert_redirected_to journeys_url
    assert_match(/Journey archived successfully/, flash[:notice])
    
    @journey1.reload
    assert_equal 'archived', @journey1.status
  end

  test "should not archive journey when conditions are not met" do
    # Set journey to active status (not archivable)
    @journey1.update!(status: 'active')
    
    patch archive_journey_url(@journey1)
    assert_redirected_to @journey1
    assert_match(/Journey cannot be archived/, flash[:alert])
    
    @journey1.reload
    assert_not_equal 'archived', @journey1.status
  end

  test "should show journey comparison page with valid journey ids" do
    get compare_journeys_url, params: { journey_ids: [@journey1.id, @journey2.id] }
    assert_response :success
    
    assert_select "h1", text: "Journey Comparison"
    assert_select "table tbody tr", count: 2
    assert_select "td", text: @journey1.name
    assert_select "td", text: @journey2.name
  end

  test "should redirect when no journeys selected for comparison" do
    get compare_journeys_url, params: { journey_ids: [] }
    assert_redirected_to journeys_url
    assert_match(/Please select journeys to compare/, flash[:alert])
  end

  test "should redirect when only one journey selected for comparison" do
    get compare_journeys_url, params: { journey_ids: [@journey1.id] }
    assert_redirected_to journeys_url
    assert_match(/Please select at least 2 journeys/, flash[:alert])
  end

  test "should redirect when too many journeys selected for comparison" do
    # Create additional journeys to exceed the limit
    journey3 = @user.journeys.create!(name: "Journey 3", campaign_type: "awareness")
    journey4 = @user.journeys.create!(name: "Journey 4", campaign_type: "awareness") 
    journey5 = @user.journeys.create!(name: "Journey 5", campaign_type: "awareness")
    
    get compare_journeys_url, params: { 
      journey_ids: [@journey1.id, @journey2.id, journey3.id, journey4.id, journey5.id] 
    }
    assert_redirected_to journeys_url
    assert_match(/Please select no more than 4 journeys/, flash[:alert])
  end

  test "journey analytics methods should return correct values" do
    # Test completion_rate method
    expected_completion_rate = (1.0 / 2 * 100).round(1) # 1 completed out of 2 steps
    assert_equal expected_completion_rate, @journey1.completion_rate
    
    # Test can_be_duplicated method
    assert @journey1.can_be_duplicated?
    
    # Test can_be_archived method - draft status should be archivable
    @journey1.update!(status: 'draft')
    assert @journey1.can_be_archived?
    
    # Active status should not be archivable
    @journey1.update!(status: 'active')
    assert_not @journey1.can_be_archived?
    
    # Test analytics_summary method
    analytics = @journey1.analytics_summary
    assert_includes analytics.keys, :total_steps
    assert_includes analytics.keys, :completion_rate
    assert_includes analytics.keys, :last_activity
    assert_includes analytics.keys, :duration
    assert_equal 2, analytics[:total_steps]
  end

  test "comparison should include correct analytics data" do
    get compare_journeys_url, params: { journey_ids: [@journey1.id, @journey2.id] }
    assert_response :success
    
    # Check that completion rates are displayed correctly
    assert_select "td", text: "50.0%" # @journey1 completion rate
    assert_select "td", text: "0.0%" # @journey2 completion rate (no completed steps)
  end

end