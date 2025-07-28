require "test_helper"

class BrandAssetsControllerTest < ActionDispatch::IntegrationTest
  test "basic routes work" do
    # Just test that our controller methods exist
    # Full integration tests would require proper authentication setup
    
    # Test that the controller has the expected methods
    controller = BrandAssetsController.new
    
    assert_respond_to controller, :index
    assert_respond_to controller, :show
    assert_respond_to controller, :new
    assert_respond_to controller, :create
    assert_respond_to controller, :edit
    assert_respond_to controller, :update
    assert_respond_to controller, :destroy
    assert_respond_to controller, :status
    assert_respond_to controller, :batch_status
  end

  test "brand asset model methods work" do
    brand_asset = brand_assets(:one)
    
    # Test our new methods
    assert_respond_to brand_asset, :content_type
    assert_respond_to brand_asset, :file_size_mb
    assert_respond_to brand_asset, :image?
    assert_respond_to brand_asset, :video?
    assert_respond_to brand_asset, :document?
  end
end
