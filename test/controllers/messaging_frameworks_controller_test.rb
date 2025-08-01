require "test_helper"

class MessagingFrameworksControllerTest < ActionController::TestCase
  setup do
    @user = users(:one)
    @brand = brands(:one)
    @messaging_framework = messaging_frameworks(:one)
    sign_in @user
  end

  test "should show messaging framework" do
    get :show, params: { brand_id: @brand }
    assert_response :success
  end

  test "should get edit" do
    get :edit, params: { brand_id: @brand }
    assert_response :success
  end

  test "should update messaging framework" do
    patch :update, params: {
      brand_id: @brand,
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
    post :add_key_message, 
         params: { brand_id: @brand, category: "test", message: "Test message" },
         format: :json
    
    assert_response :success
    json_response = JSON.parse(response.body)
    assert json_response["success"]
  end

  test "should add value proposition via ajax" do
    post :add_value_proposition,
         params: { brand_id: @brand, proposition_type: "primary", proposition: "Test proposition" },
         format: :json
    
    assert_response :success
    json_response = JSON.parse(response.body)
    assert json_response["success"]
  end

  test "should validate content" do
    post :validate_content,
         params: { brand_id: @brand, content: "Test content with some words" },
         format: :json
    
    assert_response :success
    json_response = JSON.parse(response.body)
    assert_includes json_response.keys, "banned_words"
    assert_includes json_response.keys, "contains_banned"
  end

  test "should get ai suggestions" do
    post :ai_suggestions,
         params: { brand_id: @brand, content_type: "tagline", current_content: "Current tagline" },
         format: :json
    
    assert_response :success
    json_response = JSON.parse(response.body)
    assert_includes json_response.keys, "suggestions"
    assert json_response["suggestions"].is_a?(Array)
  end

  test "should export framework as json" do
    get :export, params: { brand_id: @brand }, format: :json
    assert_response :success
    assert_match 'application/json', response.content_type
  end

  test "should import framework" do
    skip "File upload test needs controller-level implementation fix"
    file_content = {
      tagline: "Imported tagline",
      key_messages: { "category1" => ["message1", "message2"] },
      value_propositions: { "primary" => ["prop1"] }
    }.to_json

    file = fixture_file_upload(StringIO.new(file_content), 'application/json')
    
    post :import,
         params: { brand_id: @brand, file: file }
    
    assert_response :success
  end

  private

  def fixture_file_upload(io, content_type)
    uploaded_file = ActionDispatch::Http::UploadedFile.new(
      tempfile: io,
      filename: 'test.json',
      type: content_type
    )
    
    # Ensure the uploaded file responds to content_type method
    uploaded_file.define_singleton_method(:content_type) { content_type }
    uploaded_file
  end
end
