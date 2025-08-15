require 'test_helper'

class RailsAdminTest < ActionDispatch::IntegrationTest
  def setup
    @admin_user = users(:admin_user) || create_admin_user
    @regular_user = users(:marketer_user) || create_regular_user
  end

  test "admin user can access rails admin dashboard" do
    sign_in_as(@admin_user)
    get rails_admin_path
    assert_response :success
    assert_select 'h1', text: /Site Administration|Dashboard/
  end

  test "non-admin user cannot access rails admin" do
    sign_in_as(@regular_user)
    get rails_admin_path
    assert_redirected_to '/'
    follow_redirect!
    assert_match /not authorized/, flash[:alert]
  end

  test "unauthenticated user redirected to login" do
    get rails_admin_path
    assert_redirected_to '/sessions/new'
  end

  test "admin can view user list" do
    sign_in_as(@admin_user)
    get rails_admin.index_path(model_name: 'user')
    assert_response :success
    assert_select 'tbody tr', minimum: 1
  end

  test "admin can view user details" do
    sign_in_as(@admin_user)
    get rails_admin.show_path(model_name: 'user', id: @regular_user.id)
    assert_response :success
    assert response.body.include?(@regular_user.email_address)
  end

  test "admin can edit user role" do
    sign_in_as(@admin_user)
    get rails_admin.edit_path(model_name: 'user', id: @regular_user.id)
    assert_response :success
    assert_select 'select[name*="role"]'
    
    put rails_admin.edit_path(model_name: 'user', id: @regular_user.id), params: {
      user: { role: 'team_member' }
    }
    
    @regular_user.reload
    assert_equal 'team_member', @regular_user.role
  end

  test "admin can view sessions" do
    # Create a session for the regular user
    session = @regular_user.sessions.create!(
      user_agent: 'Test Browser',
      ip_address: '127.0.0.1'
    )

    sign_in_as(@admin_user)
    get rails_admin.index_path(model_name: 'session')
    assert_response :success
    assert_select 'tbody tr', minimum: 1
  end

  test "admin cannot create sessions through admin interface" do
    sign_in_as(@admin_user)
    get rails_admin.new_path(model_name: 'session')
    assert_response :forbidden
  end

  test "admin cannot edit sessions" do
    session = @regular_user.sessions.create!(
      user_agent: 'Test Browser',
      ip_address: '127.0.0.1'
    )

    sign_in_as(@admin_user)
    get rails_admin.edit_path(model_name: 'session', id: session.id)
    assert_response :forbidden
  end

  private

  def create_admin_user
    User.create!(
      email_address: 'admin@test.com',
      password: 'password123',
      role: 'admin'
    )
  end

  def create_regular_user  
    User.create!(
      email_address: 'user@test.com',
      password: 'password123',
      role: 'marketer'
    )
  end
end