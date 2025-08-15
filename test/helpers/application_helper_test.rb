require "test_helper"

class ApplicationHelperTest < ActionView::TestCase
  test "status_badge_classes returns correct classes for active status" do
    assert_equal "bg-green-100 text-green-800", status_badge_classes("active")
  end

  test "status_badge_classes returns correct classes for draft status" do
    assert_equal "bg-gray-100 text-gray-800", status_badge_classes("draft")
  end

  test "status_badge_classes returns correct classes for paused status" do
    assert_equal "bg-yellow-100 text-yellow-800", status_badge_classes("paused")
  end

  test "status_badge_classes returns correct classes for completed status" do
    assert_equal "bg-blue-100 text-blue-800", status_badge_classes("completed")
  end

  test "status_badge_classes returns correct classes for archived status" do
    assert_equal "bg-red-100 text-red-800", status_badge_classes("archived")
  end

  test "status_badge_classes returns default classes for unknown status" do
    assert_equal "bg-gray-100 text-gray-800", status_badge_classes("unknown_status")
  end

  test "status_badge_classes returns default classes for nil status" do
    assert_equal "bg-gray-100 text-gray-800", status_badge_classes(nil)
  end

  test "status_badge_classes returns default classes for empty string" do
    assert_equal "bg-gray-100 text-gray-800", status_badge_classes("")
  end

  test "status_badge_classes handles case sensitivity" do
    assert_equal "bg-gray-100 text-gray-800", status_badge_classes("ACTIVE")
    assert_equal "bg-gray-100 text-gray-800", status_badge_classes("Active")
  end

  test "status_badge_classes works with all valid journey statuses" do
    Journey::STATUSES.each do |status|
      result = status_badge_classes(status)
      assert_match(/^bg-\w+-100 text-\w+-800$/, result)
      refute_nil result
    end
  end
end