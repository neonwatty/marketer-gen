require "test_helper"

class AbTestComprehensiveTest < ActiveSupport::TestCase
  setup do
    @user = create(:user)
    @persona = create(:persona, user: @user)
    @campaign = create(:campaign, user: @user, persona: @persona)
    @journey = create(:journey, user: @user, campaign: @campaign)
  end

  test "should create valid AB test" do
    ab_test = create(:ab_test, campaign: @campaign, user: @user)
    assert ab_test.valid?
    assert_equal @campaign, ab_test.campaign
    assert_equal @user, ab_test.user
  end

  test "should require required fields" do
    ab_test = AbTest.new
    assert_not ab_test.valid?

    required_fields = [ :name, :campaign, :user ]
    required_fields.each do |field|
      assert_includes ab_test.errors[field], "must exist" if field != :name
      assert_includes ab_test.errors[field], "can't be blank" if field == :name
    end
  end

  test "should validate status values" do
    ab_test = build(:ab_test, campaign: @campaign, user: @user)

    valid_statuses = %w[draft running paused completed cancelled]
    valid_statuses.each do |status|
      ab_test.status = status
      assert ab_test.valid?, "#{status} should be a valid status"
    end

    ab_test.status = "invalid_status"
    assert_not ab_test.valid?
  end

  test "should validate confidence level range" do
    ab_test = build(:ab_test, campaign: @campaign, user: @user)

    ab_test.confidence_level = 50.0
    assert_not ab_test.valid?

    ab_test.confidence_level = 99.9
    assert_not ab_test.valid?

    ab_test.confidence_level = 95.0
    assert ab_test.valid?
  end

  test "should have proper associations" do
    ab_test = create(:ab_test, campaign: @campaign, user: @user)

    # Test can create variants
    variant1 = create(:ab_test_variant, :control, ab_test: ab_test, journey: @journey)
    variant2 = create(:ab_test_variant, :variation, ab_test: ab_test, journey: @journey)

    assert_equal 2, ab_test.ab_test_variants.count
    assert_includes ab_test.ab_test_variants, variant1
    assert_includes ab_test.ab_test_variants, variant2
  end

  test "should calculate statistical significance" do
    ab_test = create(:ab_test, campaign: @campaign, user: @user)
    control = create(:ab_test_variant, :control, ab_test: ab_test, journey: @journey,
                     total_visitors: 1000, conversions: 100)
    variant = create(:ab_test_variant, :variation, ab_test: ab_test, journey: @journey,
                     total_visitors: 1000, conversions: 120)

    significance = ab_test.calculate_statistical_significance
    assert significance.is_a?(Hash)
    assert significance.key?(:p_value)
    assert significance.key?(:is_significant)
    assert significance.key?(:confidence_interval)
  end

  test "should determine winner when test completes" do
    ab_test = create(:ab_test, campaign: @campaign, user: @user, status: "running")
    control = create(:ab_test_variant, :control, ab_test: ab_test, journey: @journey,
                     total_visitors: 1000, conversions: 100, conversion_rate: 10.0)
    variant = create(:ab_test_variant, :variation, ab_test: ab_test, journey: @journey,
                     total_visitors: 1000, conversions: 150, conversion_rate: 15.0)

    ab_test.complete_test!

    assert_equal "completed", ab_test.status
    # Winner should be the variant with higher conversion rate
    assert_equal variant.id, ab_test.winner_variant_id
  end

  test "should validate traffic allocation" do
    ab_test = create(:ab_test, campaign: @campaign, user: @user)

    # Create variants that exceed 100% traffic allocation
    create(:ab_test_variant, ab_test: ab_test, journey: @journey, traffic_percentage: 60.0)
    create(:ab_test_variant, ab_test: ab_test, journey: @journey, traffic_percentage: 50.0)

    assert_not ab_test.valid_traffic_allocation?

    # Fix traffic allocation
    ab_test.ab_test_variants.last.update!(traffic_percentage: 40.0)
    assert ab_test.valid_traffic_allocation?
  end

  test "should generate performance report" do
    ab_test = create(:ab_test, campaign: @campaign, user: @user)
    control = create(:ab_test_variant, :control, ab_test: ab_test, journey: @journey,
                     total_visitors: 1000, conversions: 100)
    variant = create(:ab_test_variant, :variation, ab_test: ab_test, journey: @journey,
                     total_visitors: 1000, conversions: 120)

    report = ab_test.performance_report

    assert report.is_a?(Hash)
    assert report.key?(:test_summary)
    assert report.key?(:variants)
    assert report.key?(:statistical_analysis)
    assert report.key?(:recommendations)

    assert_equal 2, report[:variants].length
  end

  test "AB test variant should validate control variant uniqueness" do
    ab_test = create(:ab_test, campaign: @campaign, user: @user)

    # First control variant should be fine
    control1 = create(:ab_test_variant, :control, ab_test: ab_test, journey: @journey)
    assert control1.valid?

    # Second control variant should fail validation
    control2 = build(:ab_test_variant, :control, ab_test: ab_test, journey: @journey, name: "Control 2")
    assert_not control2.valid?
    assert_includes control2.errors[:is_control], "Only one control variant allowed per test"
  end

  test "AB test variant should calculate conversion rate" do
    variant = create(:ab_test_variant,
                     ab_test: create(:ab_test, campaign: @campaign, user: @user),
                     journey: @journey,
                     total_visitors: 1000,
                     conversions: 150)

    assert_equal 15.0, variant.conversion_rate

    # Test zero visitors case
    variant.total_visitors = 0
    assert_equal 0.0, variant.conversion_rate
  end

  test "AB test variant should validate traffic percentage range" do
    variant = build(:ab_test_variant,
                    ab_test: create(:ab_test, campaign: @campaign, user: @user),
                    journey: @journey)

    variant.traffic_percentage = -1
    assert_not variant.valid?

    variant.traffic_percentage = 101
    assert_not variant.valid?

    variant.traffic_percentage = 50.0
    assert variant.valid?
  end

  test "should calculate lift between variants" do
    ab_test = create(:ab_test, campaign: @campaign, user: @user)
    control = create(:ab_test_variant, :control, ab_test: ab_test, journey: @journey,
                     total_visitors: 1000, conversions: 100, conversion_rate: 10.0)
    variant = create(:ab_test_variant, :variation, ab_test: ab_test, journey: @journey,
                     total_visitors: 1000, conversions: 150, conversion_rate: 15.0)

    lift = variant.calculate_lift(control)
    assert_equal 50.0, lift # (15 - 10) / 10 * 100 = 50%
  end

  test "should track visitor assignment" do
    ab_test = create(:ab_test, campaign: @campaign, user: @user)
    control = create(:ab_test_variant, :control, ab_test: ab_test, journey: @journey, traffic_percentage: 50.0)
    variant = create(:ab_test_variant, :variation, ab_test: ab_test, journey: @journey, traffic_percentage: 50.0)

    # Simulate visitor assignment
    visitor_id = "user_123"
    assigned_variant = ab_test.assign_visitor(visitor_id)

    assert_includes [ control, variant ], assigned_variant

    # Same visitor should get same variant
    second_assignment = ab_test.assign_visitor(visitor_id)
    assert_equal assigned_variant, second_assignment
  end

  test "should validate minimum sample size requirements" do
    ab_test = create(:ab_test, campaign: @campaign, user: @user, minimum_sample_size: 1000)

    control = create(:ab_test_variant, :control, ab_test: ab_test, journey: @journey, total_visitors: 500)
    variant = create(:ab_test_variant, :variation, ab_test: ab_test, journey: @journey, total_visitors: 500)

    assert_not ab_test.meets_minimum_sample_size?

    control.update!(total_visitors: 1000)
    variant.update!(total_visitors: 1000)

    assert ab_test.meets_minimum_sample_size?
  end

  test "should generate test insights" do
    ab_test = create(:ab_test, campaign: @campaign, user: @user)
    control = create(:ab_test_variant, :control, ab_test: ab_test, journey: @journey,
                     total_visitors: 1000, conversions: 100)
    variant = create(:ab_test_variant, :variation, ab_test: ab_test, journey: @journey,
                     total_visitors: 1000, conversions: 120)

    insights = ab_test.generate_insights

    assert insights.is_a?(Hash)
    assert insights.key?(:performance_summary)
    assert insights.key?(:statistical_summary)
    assert insights.key?(:recommendations)
    assert insights.key?(:next_steps)
  end
end
