require "test_helper"

class BrandsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(email_address: "brands_test@example.com", password: "password123")
    @brand = @user.brands.create!(name: "Test Brand")
    sign_in_as(@user)
  end

  test "should get index" do
    get brands_url
    assert_response :success
  end

  test "should get show" do
    get brand_url(@brand)
    assert_response :success
  end

  test "should get new" do
    get new_brand_url
    assert_response :success
  end

  test "should create brand" do
    assert_difference("Brand.count") do
      post brands_url, params: { brand: { name: "New Brand" } }
    end
    assert_redirected_to brand_url(Brand.last)
  end

  test "should get edit" do
    get edit_brand_url(@brand)
    assert_response :success
  end

  test "should update brand" do
    patch brand_url(@brand), params: { brand: { name: "Updated Brand" } }
    assert_redirected_to brand_url(@brand)
  end

  test "should destroy brand" do
    assert_difference("Brand.count", -1) do
      delete brand_url(@brand)
    end
    assert_redirected_to brands_url
  end
end
