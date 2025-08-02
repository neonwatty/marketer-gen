require "test_helper"

class AbTestTest < ActiveSupport::TestCase
  def setup
    @user = users(:admin)
    @persona = Persona.create!(
      user: @user,
      name: "Test Persona",
      description: "Test persona description"
    )
    @campaign = Campaign.create!(
      user: @user,
      persona: @persona,
      name: "Test Campaign",
      description: "Test campaign description"
    )
    @control_journey = Journey.create!(
      user: @user,
      campaign: @campaign,
      name: "Control Journey",
      description: "Control journey description"
    )
    @treatment_journey = Journey.create!(
      user: @user,
      campaign: @campaign,
      name: "Treatment Journey",
      description: "Treatment journey description"
    )
    @ab_test = AbTest.new(
      campaign: @campaign,
      user: @user,
      name: "Homepage CTA Test",
      description: "Testing different call-to-action buttons",
      hypothesis: "Green CTA button will increase conversions by 20%",
      test_type: "conversion"
    )
  end

  test "should be valid with all required attributes" do
    assert @ab_test.valid?
  end

  test "should require name" do
    @ab_test.name = nil
    assert_not @ab_test.valid?
    assert_includes @ab_test.errors[:name], "can't be blank"
  end

  test "should require campaign" do
    @ab_test.campaign = nil
    assert_not @ab_test.valid?
    assert_includes @ab_test.errors[:campaign], "must exist"
  end

  test "should require user" do
    @ab_test.user = nil
    assert_not @ab_test.valid?
    assert_includes @ab_test.errors[:user], "must exist"
  end

  test "should enforce uniqueness of name per campaign" do
    @ab_test.save!

    duplicate_test = AbTest.new(
      campaign: @campaign,
      user: @user,
      name: "Homepage CTA Test",
      description: "Another test with same name"
    )

    assert_not duplicate_test.valid?
    assert_includes duplicate_test.errors[:name], "has already been taken"
  end

  test "should have default values" do
    test = AbTest.new
    assert_equal "draft", test.status
    assert_equal "conversion", test.test_type
    assert_equal 95.0, test.confidence_level
    assert_equal 5.0, test.significance_threshold
  end

  test "should validate status inclusion" do
    @ab_test.status = "invalid_status"
    assert_not @ab_test.valid?
    assert_includes @ab_test.errors[:status], "is not included in the list"
  end

  test "should validate test_type inclusion" do
    @ab_test.test_type = "invalid_type"
    assert_not @ab_test.valid?
    assert_includes @ab_test.errors[:test_type], "is not included in the list"
  end

  test "should validate confidence_level range" do
    @ab_test.confidence_level = 45.0
    assert_not @ab_test.valid?
    assert_includes @ab_test.errors[:confidence_level], "must be greater than 50"

    @ab_test.confidence_level = 100.0
    assert_not @ab_test.valid?
    assert_includes @ab_test.errors[:confidence_level], "must be less than or equal to 99.9"

    @ab_test.confidence_level = 95.0
    assert @ab_test.valid?
  end

  test "should validate significance_threshold range" do
    @ab_test.significance_threshold = 0.0
    assert_not @ab_test.valid?
    assert_includes @ab_test.errors[:significance_threshold], "must be greater than 0"

    @ab_test.significance_threshold = 25.0
    assert_not @ab_test.valid?
    assert_includes @ab_test.errors[:significance_threshold], "must be less than or equal to 20"

    @ab_test.significance_threshold = 5.0
    assert @ab_test.valid?
  end

  test "should validate end_date_after_start_date" do
    @ab_test.start_date = Time.current
    @ab_test.end_date = 1.day.ago

    assert_not @ab_test.valid?
    assert_includes @ab_test.errors[:end_date], "must be after start date"
  end

  test "start! should change status and set start_date" do
    @ab_test.save!
    setup_variants

    travel_to Time.zone.local(2025, 1, 1, 12, 0, 0) do
      result = @ab_test.start!

      assert result
      assert_equal "running", @ab_test.status
      assert_equal Time.current, @ab_test.start_date
    end
  end

  test "start! should fail if test cannot start" do
    @ab_test.save!
    # Don't setup variants - test should fail

    result = @ab_test.start!
    assert_not result
    assert_equal "draft", @ab_test.status
  end

  test "pause! should change status to paused" do
    @ab_test.save!
    setup_variants
    @ab_test.start!
    @ab_test.pause!

    assert_equal "paused", @ab_test.status
  end

  test "resume! should change status back to running" do
    @ab_test.save!
    setup_variants
    @ab_test.start!
    @ab_test.pause!

    result = @ab_test.resume!
    assert result
    assert_equal "running", @ab_test.status
  end

  test "complete! should determine winner and set completed status" do
    @ab_test.save!
    setup_variants_with_data

    travel_to Time.zone.local(2025, 1, 1, 12, 0, 0) do
      @ab_test.start!
    end

    travel_to Time.zone.local(2025, 2, 1, 12, 0, 0) do
      @ab_test.complete!

      assert_equal "completed", @ab_test.status
      assert_equal Time.current, @ab_test.end_date
    end
  end

  test "cancel! should set status to cancelled and end_date" do
    @ab_test.save!
    setup_variants

    travel_to Time.zone.local(2025, 1, 1, 12, 0, 0) do
      @ab_test.start!
    end

    travel_to Time.zone.local(2025, 2, 1, 12, 0, 0) do
      @ab_test.cancel!

      assert_equal "cancelled", @ab_test.status
      assert_equal Time.current, @ab_test.end_date
    end
  end

  test "can_start? should return true when conditions are met" do
    @ab_test.save!
    setup_variants

    assert @ab_test.can_start?
  end

  test "can_start? should return false without enough variants" do
    @ab_test.save!
    # Only create one variant
    @ab_test.ab_test_variants.create!(
      journey: @control_journey,
      name: "Control",
      is_control: true,
      traffic_percentage: 100.0
    )

    assert_not @ab_test.can_start?
  end

  test "duration_days should calculate correctly" do
    @ab_test.save!
    start_time = Time.zone.local(2025, 1, 1, 12, 0, 0)
    end_time = Time.zone.local(2025, 1, 15, 12, 0, 0)

    @ab_test.update!(start_date: start_time, end_date: end_time)

    assert_equal 14.0, @ab_test.duration_days
  end

  test "progress_percentage should calculate correctly" do
    @ab_test.save!

    travel_to Time.zone.local(2025, 1, 15, 12, 0, 0) do
      start_time = 10.days.ago  # 2025-01-05
      end_time = 10.days.from_now  # 2025-01-25

      @ab_test.update!(start_date: start_time, end_date: end_time)

      # We're at 2025-01-15, which is 10 days after start (2025-01-05)
      # Total duration is 20 days, so progress should be 10/20 = 50%
      assert_equal 50, @ab_test.progress_percentage
    end
  end

  test "results_summary should provide comprehensive results" do
    @ab_test.save!
    setup_variants_with_data

    summary = @ab_test.results_summary

    assert_equal @ab_test.name, summary[:test_name]
    assert_equal @ab_test.status, summary[:status]
    assert_includes summary, :control_performance
    assert_includes summary, :treatment_performances
    assert_includes summary, :total_visitors
  end

  test "variant_comparison should compare variants against control" do
    @ab_test.save!
    setup_variants_with_data

    comparison = @ab_test.variant_comparison

    assert comparison.is_a?(Array)
    assert comparison.first.is_a?(Hash)
    assert_includes comparison.first, :variant_name
    assert_includes comparison.first, :control_conversion_rate
    assert_includes comparison.first, :treatment_conversion_rate
    assert_includes comparison.first, :lift_percentage
  end

  test "create_basic_ab_test should create test with variants" do
    test = AbTest.create_basic_ab_test(
      @campaign,
      "Basic Test",
      @control_journey,
      @treatment_journey
    )

    assert test.persisted?
    assert_equal 2, test.ab_test_variants.count

    control = test.ab_test_variants.find_by(is_control: true)
    treatment = test.ab_test_variants.find_by(is_control: false)

    assert control.present?
    assert treatment.present?
    assert_equal @control_journey, control.journey
    assert_equal @treatment_journey, treatment.journey
    assert_equal 50.0, control.traffic_percentage
    assert_equal 50.0, treatment.traffic_percentage
  end

  test "scopes should work correctly" do
    @ab_test.save!

    # Test recent scope
    assert_includes AbTest.recent, @ab_test

    # Test by_type scope
    assert_includes AbTest.by_type("conversion"), @ab_test
    assert_not_includes AbTest.by_type("engagement"), @ab_test

    setup_variants
    @ab_test.start!

    # Test running scope
    assert_includes AbTest.running, @ab_test
    assert_includes AbTest.active, @ab_test

    @ab_test.complete!

    # Test completed scope
    assert_includes AbTest.completed, @ab_test
    assert_not_includes AbTest.active, @ab_test
  end

  test "statistical_significance_reached? should work correctly" do
    @ab_test.save!
    setup_variants_with_significant_data
    @ab_test.start!

    # This is a simplified test - in practice would need more sophisticated calculation
    significance = @ab_test.statistical_significance_reached?
    assert significance.is_a?(TrueClass) || significance.is_a?(FalseClass)
  end

  test "winner_declared? should return true when winner is set" do
    @ab_test.save!
    setup_variants

    assert_not @ab_test.winner_declared?

    @ab_test.update!(winner_variant: @ab_test.ab_test_variants.first)
    assert @ab_test.winner_declared?
  end

  test "recommend_action should provide actionable recommendations" do
    @ab_test.save!
    setup_variants_with_data
    @ab_test.start!

    recommendation = @ab_test.recommend_action
    assert recommendation.is_a?(String)
    assert recommendation.length > 0
  end

  private

  def setup_variants
    @ab_test.ab_test_variants.create!(
      journey: @control_journey,
      name: "Control",
      is_control: true,
      traffic_percentage: 50.0
    )

    @ab_test.ab_test_variants.create!(
      journey: @treatment_journey,
      name: "Treatment",
      is_control: false,
      traffic_percentage: 50.0
    )
  end

  def setup_variants_with_data
    control = @ab_test.ab_test_variants.create!(
      journey: @control_journey,
      name: "Control",
      is_control: true,
      traffic_percentage: 50.0,
      total_visitors: 1000,
      conversions: 50
    )

    treatment = @ab_test.ab_test_variants.create!(
      journey: @treatment_journey,
      name: "Treatment",
      is_control: false,
      traffic_percentage: 50.0,
      total_visitors: 1000,
      conversions: 60
    )

    # Trigger conversion rate calculation
    control.save!
    treatment.save!
  end

  def setup_variants_with_significant_data
    control = @ab_test.ab_test_variants.create!(
      journey: @control_journey,
      name: "Control",
      is_control: true,
      traffic_percentage: 50.0,
      total_visitors: 5000,
      conversions: 250
    )

    treatment = @ab_test.ab_test_variants.create!(
      journey: @treatment_journey,
      name: "Treatment",
      is_control: false,
      traffic_percentage: 50.0,
      total_visitors: 5000,
      conversions: 350
    )

    # Trigger conversion rate calculation
    control.save!
    treatment.save!
  end
end
