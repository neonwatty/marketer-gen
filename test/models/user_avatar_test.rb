require "test_helper"

class UserAvatarTest < ActiveSupport::TestCase
  def setup
    @user = users(:one)
  end

  test "should accept valid image formats" do
    valid_formats = %w[image/jpeg image/png image/gif image/webp]
    
    valid_formats.each do |format|
      # Create a minimal file blob for testing
      blob = ActiveStorage::Blob.create_and_upload!(
        io: StringIO.new("fake image data"),
        filename: "test.#{format.split('/').last}",
        content_type: format
      )
      
      @user.avatar.attach(blob)
      assert @user.valid?, "Should accept #{format}"
      @user.avatar.purge
    end
  end

  test "should reject invalid image formats" do
    invalid_blob = ActiveStorage::Blob.create_and_upload!(
      io: StringIO.new("fake data"),
      filename: "test.txt",
      content_type: "text/plain"
    )
    
    @user.avatar.attach(invalid_blob)
    assert_not @user.valid?
    assert_includes @user.errors[:avatar], "must be a JPEG, PNG, GIF, or WebP image"
  end

  test "should reject oversized images" do
    # Create a blob that's larger than 5MB
    large_blob = ActiveStorage::Blob.create_and_upload!(
      io: StringIO.new("x" * 6.megabytes),
      filename: "large.jpg",
      content_type: "image/jpeg"
    )
    
    @user.avatar.attach(large_blob)
    assert_not @user.valid?
    assert_includes @user.errors[:avatar], "must be less than 5MB"
  end
end