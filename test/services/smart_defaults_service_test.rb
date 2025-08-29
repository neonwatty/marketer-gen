require "test_helper"

class SmartDefaultsServiceTest < ActiveSupport::TestCase
  def setup
    @user = users(:one)
    @service = SmartDefaultsService.new(@user)
  end

  test "provides campaign plan defaults" do
    defaults = @service.campaign_plan_defaults
    
    assert_not_nil defaults
    assert_includes defaults.keys, :suggested_names
    assert_includes defaults.keys, :suggested_descriptions
    assert_includes defaults.keys, :suggested_campaign_types
    assert_includes defaults.keys, :suggested_objectives
    assert_includes defaults.keys, :suggested_target_audiences
    assert_includes defaults.keys, :suggested_budgets
    assert_includes defaults.keys, :suggested_timelines
    assert_includes defaults.keys, :prefilled_brand_context
  end

  test "provides journey defaults" do
    defaults = @service.journey_defaults
    
    assert_not_nil defaults
    assert_includes defaults.keys, :suggested_names
    assert_includes defaults.keys, :suggested_target_audiences
    assert_includes defaults.keys, :suggested_steps
  end

  test "calculates user onboarding progress for new user" do
    # Test with a new user who hasn't completed any steps
    new_user = User.new(email_address: "new@test.com", password: "password")
    new_user.save!
    service = SmartDefaultsService.new(new_user)
    
    progress = service.user_onboarding_progress
    
    assert_not_nil progress
    assert_includes progress.keys, :completed_steps
    assert_includes progress.keys, :next_suggested_action
    assert_includes progress.keys, :completion_percentage
    assert_includes progress.keys, :missing_essentials
    
    # New user should have 0% completion
    assert_equal 0, progress[:completion_percentage]
    assert_equal :complete_profile, progress[:next_suggested_action]
    assert_empty progress[:completed_steps]
    assert progress[:missing_essentials].length > 0
  end

  test "calculates completion percentage correctly" do
    # Test profile completion
    @user.update!(company: "Test Company")
    progress = @service.user_onboarding_progress
    
    # Should have at least profile_setup completed
    assert_includes progress[:completed_steps], :profile_setup
    assert progress[:completion_percentage] > 0
    assert progress[:completion_percentage] <= 100
  end

  test "determines next action based on completion state" do
    # Test progression of next actions
    progress = @service.user_onboarding_progress
    
    # Should start with profile completion
    unless @user.company.present? && @user.role.present?
      assert_equal :complete_profile, progress[:next_suggested_action]
    end
  end

  test "identifies missing essentials correctly" do
    # Test with incomplete profile
    @user.update!(company: nil)
    progress = @service.user_onboarding_progress
    
    missing = progress[:missing_essentials]
    assert missing.any? { |item| item[:step] == :profile }
    
    # Complete profile and check again
    @user.update!(company: "Test Company")
    progress = @service.user_onboarding_progress
    
    missing = progress[:missing_essentials]
    assert missing.none? { |item| item[:step] == :profile }
  end

  test "provides personalized campaign name suggestions" do
    @user.update!(company: "Test Corp")
    suggestions = @service.send(:generate_campaign_name_suggestions)
    
    assert suggestions.is_a?(Array)
    assert suggestions.length <= 5
    assert suggestions.any? { |name| name.include?("Test Corp") }
  end

  test "prioritizes campaign types based on user history" do
    # Create some campaign plans for the user
    @user.campaign_plans.create!(
      name: "Test Campaign 1", 
      campaign_type: "lead_generation",
      objective: "lead_generation",
      target_audience: "Test audience"
    )
    @user.campaign_plans.create!(
      name: "Test Campaign 2", 
      campaign_type: "lead_generation",
      objective: "lead_generation", 
      target_audience: "Test audience"
    )
    
    prioritized_types = @service.send(:prioritized_campaign_types)
    
    assert prioritized_types.is_a?(Array)
    assert_equal "lead_generation", prioritized_types.first
  end

  private

  def assert_includes_all(collection, items)
    items.each { |item| assert_includes collection, item }
  end
end