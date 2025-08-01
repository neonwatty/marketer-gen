require "test_helper"

class BrandsControllerTest < ActionController::TestCase
  setup do
    @user = User.create!(email_address: "brands_test@example.com", password: "password123")
    @brand = @user.brands.create!(name: "Test Brand")
    sign_in_as(@user, "password123")
  end

  test "should get index" do
    get :index
    assert_response :success
  end

  test "should get show" do
    get :show, params: { id: @brand }
    assert_response :success
  end

  test "should get new" do
    get :new
    assert_response :success
  end

  test "should create brand" do
    assert_difference("Brand.count") do
      post :create, params: { brand: { name: "New Brand" } }
    end
    assert_redirected_to brand_url(Brand.last)
  end

  test "should get edit" do
    get :edit, params: { id: @brand }
    assert_response :success
  end

  test "should update brand" do
    patch :update, params: { id: @brand, brand: { name: "Updated Brand" } }
    assert_redirected_to brand_url(@brand)
  end

  test "should destroy brand" do
    assert_difference("Brand.count", -1) do
      delete :destroy, params: { id: @brand }
    end
    assert_redirected_to brands_url
  end
end
