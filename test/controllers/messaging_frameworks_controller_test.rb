require "test_helper"

class MessagingFrameworksControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @brand = brands(:one)
    @messaging_framework = messaging_frameworks(:one)
    sign_in @user
  end

  test "should show messaging framework" do
    get brand_messaging_framework_url(@brand)
    assert_response :success
  end

  test "should get edit" do
    get edit_brand_messaging_framework_url(@brand)
    assert_response :success
  end

  test "should update messaging framework" do
    patch brand_messaging_framework_url(@brand), params: {
      messaging_framework: {
        tagline: "Updated tagline",
        mission_statement: "Updated mission",
        vision_statement: "Updated vision",
        active: true
      }
    }
    assert_redirected_to brand_messaging_framework_url(@brand)
  end

  test "should add key message via ajax" do
    post add_key_message_brand_messaging_framework_url(@brand), 
         params: { category: "test", message: "Test message" },
         headers: { 'Content-Type': 'application/json' },
         as: :json
    
    assert_response :success
    json_response = JSON.parse(response.body)
    assert json_response["success"]
  end

  test "should add value proposition via ajax" do
    post add_value_proposition_brand_messaging_framework_url(@brand),
         params: { proposition_type: "primary", proposition: "Test proposition" },
         headers: { 'Content-Type': 'application/json' },
         as: :json
    
    assert_response :success
    json_response = JSON.parse(response.body)
    assert json_response["success"]
  end

  test "should validate content" do
    post validate_content_brand_messaging_framework_url(@brand),
         params: { content: "Test content with some words" },
         headers: { 'Content-Type': 'application/json' },
         as: :json
    
    assert_response :success
    json_response = JSON.parse(response.body)
    assert_includes json_response.keys, "banned_words"
    assert_includes json_response.keys, "contains_banned"
  end

  test "should get ai suggestions" do
    post ai_suggestions_brand_messaging_framework_url(@brand),
         params: { content_type: "tagline", current_content: "Current tagline" },
         headers: { 'Content-Type': 'application/json' },
         as: :json
    
    assert_response :success
    json_response = JSON.parse(response.body)
    assert_includes json_response.keys, "suggestions"
    assert json_response["suggestions"].is_a?(Array)
  end

  test "should export framework as json" do
    get export_brand_messaging_framework_url(@brand, format: :json)
    assert_response :success
    assert_equal 'application/json', response.content_type
  end

  test "should import framework" do
    file_content = {
      tagline: "Imported tagline",
      key_messages: { "category1" => ["message1", "message2"] },
      value_propositions: { "primary" => ["prop1"] }
    }.to_json

    file = fixture_file_upload(StringIO.new(file_content), 'application/json')
    
    post import_brand_messaging_framework_url(@brand),
         params: { file: file }
    
    assert_response :success
  end

  private

  def fixture_file_upload(io, content_type)
    uploaded_file = ActionDispatch::Http::UploadedFile.new(
      tempfile: io,
      filename: 'test.json',
      type: content_type
    )
    uploaded_file
  end
end
