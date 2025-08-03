require "test_helper"

class CustomReportsControllerTest < ActionDispatch::IntegrationTest
  test "should get index" do
    get custom_reports_index_url
    assert_response :success
  end

  test "should get show" do
    get custom_reports_show_url
    assert_response :success
  end

  test "should get new" do
    get custom_reports_new_url
    assert_response :success
  end

  test "should get create" do
    get custom_reports_create_url
    assert_response :success
  end

  test "should get edit" do
    get custom_reports_edit_url
    assert_response :success
  end

  test "should get update" do
    get custom_reports_update_url
    assert_response :success
  end

  test "should get destroy" do
    get custom_reports_destroy_url
    assert_response :success
  end

  test "should get builder" do
    get custom_reports_builder_url
    assert_response :success
  end

  test "should get preview" do
    get custom_reports_preview_url
    assert_response :success
  end

  test "should get export" do
    get custom_reports_export_url
    assert_response :success
  end

  test "should get schedule" do
    get custom_reports_schedule_url
    assert_response :success
  end
end
