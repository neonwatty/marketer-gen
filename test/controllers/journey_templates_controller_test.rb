require "test_helper"

class JourneyTemplatesControllerTest < ActionDispatch::IntegrationTest
  test "should get index" do
    get journey_templates_index_url
    assert_response :success
  end

  test "should get show" do
    get journey_templates_show_url
    assert_response :success
  end

  test "should get new" do
    get journey_templates_new_url
    assert_response :success
  end

  test "should get create" do
    get journey_templates_create_url
    assert_response :success
  end

  test "should get edit" do
    get journey_templates_edit_url
    assert_response :success
  end

  test "should get update" do
    get journey_templates_update_url
    assert_response :success
  end

  test "should get destroy" do
    get journey_templates_destroy_url
    assert_response :success
  end
end
