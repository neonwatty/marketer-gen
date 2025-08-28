# frozen_string_literal: true

require 'test_helper'

class GeneratedContentsControllerTest < ActionController::TestCase
  def setup
    @user = users(:marketer_user)
    @other_user = users(:team_member_user)
    @admin_user = users(:admin_user) if User.exists?(role: 'admin')
    @campaign_plan = campaign_plans(:completed_plan)
    @other_campaign = campaign_plans(:other_user_plan)
    
    # Create test content
    @generated_content = GeneratedContent.create!(
      campaign_plan: @campaign_plan,
      content_type: 'email',
      format_variant: 'standard',
      title: 'Test Email Content',
      body_content: 'This is a comprehensive test email content that meets all validation requirements for testing our generated content controller functionality.',
      status: 'draft',
      version_number: 1,
      created_by: @user
    )
    
    # Mock authorization for all tests
    GeneratedContentPolicy.any_instance.stubs(:index?).returns(true)
    GeneratedContentPolicy.any_instance.stubs(:show?).returns(true)
    GeneratedContentPolicy.any_instance.stubs(:create?).returns(true)
    GeneratedContentPolicy.any_instance.stubs(:new?).returns(true)
    GeneratedContentPolicy.any_instance.stubs(:edit?).returns(true)
    GeneratedContentPolicy.any_instance.stubs(:update?).returns(true)
    GeneratedContentPolicy.any_instance.stubs(:destroy?).returns(true)
    GeneratedContentPolicy.any_instance.stubs(:generate?).returns(true)
    GeneratedContentPolicy.any_instance.stubs(:regenerate?).returns(true)
    GeneratedContentPolicy.any_instance.stubs(:approve?).returns(true)
    GeneratedContentPolicy.any_instance.stubs(:publish?).returns(true)
    GeneratedContentPolicy.any_instance.stubs(:archive?).returns(true)
    
    # Mock policy scope
    GeneratedContentPolicy::Scope.any_instance.stubs(:resolve).returns(GeneratedContent.all)
    
    # Mock CampaignPlan policy
    CampaignPlanPolicy.any_instance.stubs(:show?).returns(true)
  end

  def login_as(user)
    session = Session.create!(user: user, user_agent: 'Test', ip_address: '127.0.0.1')
    cookies.signed[:session_id] = session.id
    session
  end

  # Basic tests
  test "should require authentication for index" do
    get :index
    assert_redirected_to new_session_path
  end

  test "should get index for campaign when authenticated" do
    login_as(@user)
    get :index, params: { campaign_plan_id: @campaign_plan.id }
    assert_response :success
  end

  test "should show generated content when authenticated and authorized" do
    login_as(@user)
    get :show, params: { id: @generated_content.id }
    assert_response :success
    assert_equal @generated_content, assigns(:generated_content)
  end

  test "should get new when authenticated and authorized" do
    login_as(@user)
    get :new, params: { campaign_plan_id: @campaign_plan.id }
    assert_response :success
    assert assigns(:generated_content)
  end

  test "should create generated content when authenticated" do
    session = login_as(@user)
    Current.session = session
    
    assert_difference('GeneratedContent.count') do
      post :create, params: {
        campaign_plan_id: @campaign_plan.id,
        generated_content: {
          title: 'New Test Content',
          body_content: 'This is a comprehensive new test content with sufficient length to meet all validation requirements for the standard format. This content should be at least 100 characters long to pass the validation rules.',
          content_type: 'blog_article',
          format_variant: 'standard'
        }
      }
    end
    
    assert_response :redirect
    assert_equal @user, assigns(:generated_content).created_by
  end

  test "should get edit when authenticated and authorized" do
    login_as(@user)
    get :edit, params: { id: @generated_content.id }
    assert_response :success
    assert_equal @generated_content, assigns(:generated_content)
  end

  test "should update generated content when authenticated" do
    session = login_as(@user)
    Current.session = session
    
    # Make a small change to avoid triggering version creation (only change title)
    patch :update, params: {
      id: @generated_content.id,
      generated_content: {
        title: 'Updated Title'
        # Don't change body_content to avoid triggering version creation
      }
    }
    
    assert_response :redirect
    @generated_content.reload
    assert_equal 'Updated Title', @generated_content.title
  end

  test "should destroy generated content when authenticated" do
    login_as(@user)
    
    delete :destroy, params: { id: @generated_content.id }
    
    assert_response :redirect
    @generated_content.reload
    assert @generated_content.deleted?
  end

  test "should handle content not found gracefully" do
    login_as(@user)
    
    get :show, params: { id: 99999 }
    assert_response :redirect
  end

  test "should return JSON response for index" do
    login_as(@user)
    get :index, params: { campaign_plan_id: @campaign_plan.id }, format: :json
    assert_response :success
    json_response = JSON.parse(response.body)
    assert json_response['contents'].is_a?(Array)
  end

  test "should return JSON response for show" do
    login_as(@user)
    get :show, params: { id: @generated_content.id }, format: :json
    assert_response :success
    json_response = JSON.parse(response.body)
    assert_equal @generated_content.id, json_response['id']
  end

  test "should search content" do
    login_as(@user)
    
    get :search, params: { q: 'test' }
    
    assert_response :success
    assert assigns(:generated_contents)
  end

  test "should return empty results for blank search" do
    login_as(@user)
    
    get :search, params: { q: '' }
    
    assert_response :success
    assert_equal 0, assigns(:generated_contents).count
  end

  # Test parameter sanitization
  test "should sanitize content params" do
    login_as(@user)
    
    post :create, params: {
      campaign_plan_id: @campaign_plan.id,
      generated_content: {
        title: 'Test',
        body_content: 'This is comprehensive test content with proper length for validation requirements and parameter sanitization testing. This content is made longer to meet the minimum character requirements for the standard format variant validation.',
        content_type: 'email',
        format_variant: 'standard',
        malicious_param: 'should be filtered'
      }
    }
    
    # Should create content without malicious params
    assert_response :redirect
    content = assigns(:generated_content)
    assert_equal 'Test', content.title
  end

  # Test filters
  test "should apply content type filter" do
    login_as(@user)
    
    get :index, params: { 
      campaign_plan_id: @campaign_plan.id,
      content_type: 'email'
    }
    
    assert_response :success
    # All returned content should be email type
    assigns(:generated_contents).each do |content|
      assert_equal 'email', content.content_type
    end
  end

  test "should apply status filter" do
    login_as(@user)
    
    get :index, params: { 
      campaign_plan_id: @campaign_plan.id,
      status: 'draft'
    }
    
    assert_response :success
    # All returned content should be draft status
    assigns(:generated_contents).each do |content|
      assert_equal 'draft', content.status
    end
  end
end