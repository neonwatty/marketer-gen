require 'test_helper'

class RailsAdminBasicTest < ActionDispatch::IntegrationTest
  fixtures :users

  def setup
    @admin_user = users(:admin_user)
    @regular_user = users(:marketer_user)
  end

  test "admin user can access rails admin dashboard" do
    sign_in_as(@admin_user)
    get rails_admin_path
    assert_response :success
  end

  test "non-admin user cannot access rails admin" do
    sign_in_as(@regular_user)
    get rails_admin_path
    assert_redirected_to '/'
  end

  test "unauthenticated user redirected to login" do
    get rails_admin_path
    assert_redirected_to '/sessions/new'
  end

end