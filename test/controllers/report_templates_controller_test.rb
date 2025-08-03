require "test_helper"

class ReportTemplatesControllerTest < ActionDispatch::IntegrationTest
  test "should get index" do
    get report_templates_index_url
    assert_response :success
  end

  test "should get show" do
    get report_templates_show_url
    assert_response :success
  end

  test "should get new" do
    get report_templates_new_url
    assert_response :success
  end

  test "should get create" do
    get report_templates_create_url
    assert_response :success
  end

  test "should get edit" do
    get report_templates_edit_url
    assert_response :success
  end

  test "should get update" do
    get report_templates_update_url
    assert_response :success
  end

  test "should get destroy" do
    get report_templates_destroy_url
    assert_response :success
  end

  test "should get clone" do
    get report_templates_clone_url
    assert_response :success
  end

  test "should get instantiate" do
    get report_templates_instantiate_url
    assert_response :success
  end
end
