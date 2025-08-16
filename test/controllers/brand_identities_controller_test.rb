require "test_helper"

class BrandIdentitiesControllerTest < ActionDispatch::IntegrationTest
  def setup
    @user = users(:one)
    @brand_identity = brand_identities(:valid_brand)
    sign_in_as(@user)
  end

  test "should get index" do
    get brand_identities_url
    assert_response :success
    assert_includes response.body, "Brand Identities"
  end

  test "should get show" do
    get brand_identity_url(@brand_identity)
    assert_response :success
    assert_includes response.body, @brand_identity.name
  end

  test "should get new" do
    get new_brand_identity_url
    assert_response :success
    assert_includes response.body, "Create New Brand Identity"
  end

  test "should create brand identity" do
    assert_difference('BrandIdentity.count', 1) do
      post brand_identities_url, params: { 
        brand_identity: { 
          name: "New Brand Identity",
          description: "A new brand for testing",
          brand_voice: "Professional",
          tone_guidelines: "Friendly"
        } 
      }
    end
    
    assert_redirected_to brand_identity_url(BrandIdentity.last)
    assert_equal "Brand identity created successfully.", flash[:notice]
  end

  test "should not create brand identity with invalid params" do
    assert_no_difference('BrandIdentity.count') do
      post brand_identities_url, params: { 
        brand_identity: { 
          name: "", # Missing required name
          description: "A new brand for testing"
        } 
      }
    end
    
    assert_response :unprocessable_entity
  end

  test "should get edit" do
    get edit_brand_identity_url(@brand_identity)
    assert_response :success
    assert_includes response.body, "Edit Brand Identity"
  end

  test "should update brand identity" do
    patch brand_identity_url(@brand_identity), params: { 
      brand_identity: { 
        name: "Updated Brand Name",
        description: "Updated description"
      } 
    }
    
    assert_redirected_to brand_identity_url(@brand_identity)
    assert_equal "Brand identity updated successfully.", flash[:notice]
    
    @brand_identity.reload
    assert_equal "Updated Brand Name", @brand_identity.name
  end

  test "should not update brand identity with invalid params" do
    original_name = @brand_identity.name
    
    patch brand_identity_url(@brand_identity), params: { 
      brand_identity: { 
        name: "" # Invalid - name can't be blank
      } 
    }
    
    assert_response :unprocessable_entity
    
    @brand_identity.reload
    assert_equal original_name, @brand_identity.name
  end

  test "should destroy brand identity" do
    assert_difference('BrandIdentity.count', -1) do
      delete brand_identity_url(@brand_identity)
    end
    
    assert_redirected_to brand_identities_url
    assert_equal "Brand identity deleted successfully.", flash[:notice]
  end

  test "should activate brand identity" do
    # Ensure the brand identity starts as not active
    @brand_identity.update!(is_active: false, status: "draft")
    
    patch activate_brand_identity_url(@brand_identity)
    
    assert_redirected_to brand_identity_url(@brand_identity)
    @brand_identity.reload
    assert @brand_identity.is_active?
    assert_equal "active", @brand_identity.status
  end

  test "should deactivate brand identity" do
    @brand_identity.update!(is_active: true, status: "active")
    
    patch deactivate_brand_identity_url(@brand_identity)
    
    assert_redirected_to brand_identity_url(@brand_identity)
    assert_equal "Brand identity deactivated successfully.", flash[:notice]
    
    @brand_identity.reload
    assert_not @brand_identity.is_active?
    assert_equal "draft", @brand_identity.status
  end

  test "should process materials" do
    # Mock the job to prevent actual job execution
    BrandMaterialsProcessorJob.expects(:perform_later).with(@brand_identity)
    
    post process_materials_brand_identity_url(@brand_identity)
    
    assert_redirected_to brand_identity_url(@brand_identity)
    assert_equal "Brand materials processing started. This may take a few minutes.", flash[:notice]
    
    @brand_identity.reload
    assert_equal "processing", @brand_identity.status
  end

  test "should require authentication" do
    # Sign out the user
    delete session_url
    
    get brand_identities_url
    assert_redirected_to new_session_url
  end

  test "should only show user's own brand identities" do
    other_user = users(:two)
    other_brand = brand_identities(:other_user_brand)
    
    get brand_identities_url
    assert_response :success
    
    # Should include user's brand identity
    assert_includes response.body, @brand_identity.name
    
    # Should not include other user's brand identity
    assert_not_includes response.body, other_brand.name
  end

  test "should not allow access to other user's brand identity" do
    other_brand = brand_identities(:other_user_brand)
    
    get brand_identity_url(other_brand)
    
    # Should redirect to root path due to authorization failure
    assert_redirected_to root_path
    assert_equal "You are not authorized to perform this action.", flash[:alert]
  end
end
