require "test_helper"

class ContentAbTestTest < ActiveSupport::TestCase
  fixtures :users, :campaign_plans, :generated_contents

  def setup
    @user = users(:marketer_user)
    @campaign_plan = campaign_plans(:draft_plan)
    
    # Create control content that belongs to the same campaign
    @control_content = GeneratedContent.create!(
      title: 'Control Email',
      body_content: 'This is the control email content with sufficient length to pass all validation requirements. It contains enough text to meet the minimum character count requirement for standard format variant which requires at least one hundred characters in total length.',
      content_type: 'email',
      format_variant: 'standard',
      status: 'draft',
      campaign_plan: @campaign_plan,
      created_by: @user
    )
    
    # Create variant content that belongs to the same campaign
    @variant_content = GeneratedContent.create!(
      title: 'Variant Email',
      body_content: 'This is the variant email content with sufficient length to pass all validation requirements. It contains enough text to meet the minimum character count requirement for standard format variant which requires at least one hundred characters in total length.',
      content_type: 'email',
      format_variant: 'standard',
      status: 'draft',
      campaign_plan: @campaign_plan,
      created_by: @user
    )
    
    @ab_test = ContentAbTest.new(
      test_name: 'Email Subject Line Test',
      status: 'draft',
      primary_goal: 'click_rate',
      confidence_level: '95',
      traffic_allocation: 100,
      minimum_sample_size: 100,
      test_duration_days: 14,
      description: 'Testing different email subject lines',
      campaign_plan: @campaign_plan,
      created_by: @user,
      control_content: @control_content
    )
  end

  # Basic validation tests
  test "should be valid with valid attributes" do
    assert @ab_test.valid?, "A/B test should be valid: #{@ab_test.errors.full_messages}"
  end

  test "should require test_name" do
    @ab_test.test_name = nil
    assert_not @ab_test.valid?
    assert_includes @ab_test.errors[:test_name], "can't be blank"
  end

  test "should require status" do
    @ab_test.status = nil
    assert_not @ab_test.valid?
    assert_includes @ab_test.errors[:status], "can't be blank"
  end

  test "should require primary_goal" do
    @ab_test.primary_goal = nil
    assert_not @ab_test.valid?
    assert_includes @ab_test.errors[:primary_goal], "can't be blank"
  end

  test "should validate status inclusion" do
    @ab_test.status = 'invalid_status'
    assert_not @ab_test.valid?
    assert_includes @ab_test.errors[:status], "is not included in the list"
  end

  test "should validate primary_goal inclusion" do
    @ab_test.primary_goal = 'invalid_goal'
    assert_not @ab_test.valid?
    assert_includes @ab_test.errors[:primary_goal], "is not included in the list"
  end

  test "should validate confidence_level inclusion" do
    @ab_test.confidence_level = '85'
    assert_not @ab_test.valid?
    assert_includes @ab_test.errors[:confidence_level], "is not included in the list"
  end

  test "should validate traffic_allocation range" do
    @ab_test.traffic_allocation = 150
    assert_not @ab_test.valid?
    assert_includes @ab_test.errors[:traffic_allocation], "must be less than or equal to 100"
    
    @ab_test.traffic_allocation = -10
    assert_not @ab_test.valid?
    assert_includes @ab_test.errors[:traffic_allocation], "must be greater than 0"
  end

  test "should validate minimum_sample_size" do
    @ab_test.minimum_sample_size = 0
    assert_not @ab_test.valid?
    assert_includes @ab_test.errors[:minimum_sample_size], "must be greater than 0"
  end

  test "should validate test_duration_days" do
    @ab_test.test_duration_days = 0
    assert_not @ab_test.valid?
    assert_includes @ab_test.errors[:test_duration_days], "must be greater than 0"
    
    @ab_test.test_duration_days = 400
    assert_not @ab_test.valid?
    assert_includes @ab_test.errors[:test_duration_days], "cannot exceed 365 days"
  end

  test "should validate control_content belongs to same campaign" do
    other_campaign = campaign_plans(:completed_plan)
    other_content = GeneratedContent.create!(
      title: 'Other Content',
      body_content: 'Content for different campaign with enough characters to pass validation requirements. This needs to be at least one hundred characters long for the standard format variant validation to pass successfully.',
      content_type: 'email',
      format_variant: 'standard',
      status: 'draft',
      campaign_plan: other_campaign,
      created_by: @user
    )
    
    @ab_test.control_content = other_content
    assert_not @ab_test.valid?
    assert_includes @ab_test.errors[:control_content], "must belong to the same campaign"
  end

  test "should set default metadata on create" do
    @ab_test.save!
    assert_not_nil @ab_test.metadata
    assert_equal 'manual', @ab_test.metadata['creation_method']
    assert_equal true, @ab_test.metadata['auto_stop_enabled']
  end

  test "should calculate end_date from start_date and duration" do
    start_date = Time.current
    @ab_test.start_date = start_date
    @ab_test.save!
    
    expected_end_date = start_date + 14.days
    assert_equal expected_end_date.to_date, @ab_test.end_date.to_date
  end

  # Association tests
  test "should belong to campaign_plan" do
    assert_respond_to @ab_test, :campaign_plan
    assert_equal @campaign_plan, @ab_test.campaign_plan
  end

  test "should belong to created_by user" do
    assert_respond_to @ab_test, :created_by
    assert_equal @user, @ab_test.created_by
  end

  test "should belong to control_content" do
    assert_respond_to @ab_test, :control_content
    assert_equal @control_content, @ab_test.control_content
  end

  test "should have many content_ab_test_variants" do
    assert_respond_to @ab_test, :content_ab_test_variants
  end

  test "should have many content_ab_test_results" do
    assert_respond_to @ab_test, :content_ab_test_results
  end

  # Status method tests
  test "should have status check methods" do
    @ab_test.status = 'draft'
    assert @ab_test.draft?
    assert_not @ab_test.active?
    
    @ab_test.status = 'active'
    assert @ab_test.active?
    assert_not @ab_test.draft?
    
    @ab_test.status = 'completed'
    assert @ab_test.completed?
    assert_not @ab_test.active?
  end

  test "should determine if test is running" do
    @ab_test.save! # Save first to make it persisted
    @ab_test.update!(status: 'active', start_date: 1.day.ago, end_date: 1.day.from_now)
    
    assert @ab_test.running?
    assert_not @ab_test.scheduled?
    assert_not @ab_test.expired?
  end

  test "should determine if test is scheduled" do
    @ab_test.status = 'active'
    @ab_test.start_date = 1.day.from_now
    @ab_test.end_date = 2.days.from_now
    @ab_test.save!
    
    assert @ab_test.scheduled?
    assert_not @ab_test.running?
  end

  test "should determine if test is expired" do
    @ab_test.save! # Save first to make it persisted
    @ab_test.update!(status: 'active', start_date: 3.days.ago, end_date: 1.day.ago)
    
    assert @ab_test.expired?
    assert_not @ab_test.running?
  end

  # Variant management tests
  test "should add variant successfully" do
    @ab_test.save!
    
    variant = @ab_test.add_variant!(@variant_content, variant_name: 'Variant A', traffic_split: 50)
    
    assert variant.persisted?
    assert_equal 'Variant A', variant.variant_name
    assert_equal 50, variant.traffic_split
    assert_equal @variant_content, variant.generated_content
  end

  test "should not add variant to active test" do
    @ab_test.status = 'active'
    @ab_test.save!
    
    assert_raises(RuntimeError) do
      @ab_test.add_variant!(@variant_content)
    end
  end

  test "should remove variant successfully" do
    @ab_test.save!
    variant = @ab_test.add_variant!(@variant_content, variant_name: 'Variant A', traffic_split: 50)
    
    assert_difference '@ab_test.content_ab_test_variants.count', -1 do
      @ab_test.remove_variant!(variant)
    end
  end

  # Test lifecycle tests
  test "should start test successfully" do
    @ab_test.save!
    @ab_test.add_variant!(@variant_content, variant_name: 'Variant A', traffic_split: 50)
    @ab_test.start_date = Time.current
    
    assert @ab_test.can_start?
    assert @ab_test.start_test!
    assert @ab_test.active?
    assert_not_nil @ab_test.metadata['started_at']
  end

  test "should not start test without variants" do
    @ab_test.save!
    @ab_test.start_date = Time.current
    
    assert_not @ab_test.can_start?
  end

  test "should pause active test" do
    @ab_test.status = 'active'
    @ab_test.save!
    
    assert @ab_test.pause_test!
    assert @ab_test.paused?
    assert_not_nil @ab_test.metadata['paused_at']
  end

  test "should resume paused test" do
    @ab_test.status = 'paused'
    @ab_test.save!
    
    assert @ab_test.resume_test!
    assert @ab_test.active?
    assert_not_nil @ab_test.metadata['resumed_at']
  end

  test "should stop active test" do
    @ab_test.status = 'active'
    @ab_test.save!
    
    assert @ab_test.stop_test!('Manual stop for analysis')
    assert @ab_test.stopped?
    assert_not_nil @ab_test.end_date
    assert_equal 'Manual stop for analysis', @ab_test.metadata['stop_reason']
  end

  test "should complete test when conditions are met" do
    @ab_test.save! # Save first to make it persisted
    @ab_test.update!(status: 'active', start_date: 15.days.ago, minimum_sample_size: 10) # Low for testing
    
    # Mock minimum sample size reached
    @ab_test.stubs(:minimum_sample_size_reached?).returns(true)
    @ab_test.stubs(:test_duration_reached?).returns(true)
    
    assert @ab_test.can_complete?
    assert @ab_test.complete_test!
    assert @ab_test.completed?
  end

  # Results and analysis tests
  test "should check if minimum sample size is reached" do
    @ab_test.minimum_sample_size = 100
    @ab_test.save!
    
    # Mock results
    @ab_test.stubs(:content_ab_test_results).returns(
      mock('results', sum: 150)
    )
    
    assert @ab_test.minimum_sample_size_reached?
  end

  test "should check if test duration is reached" do
    @ab_test.save! # Save first to make it persisted
    @ab_test.update!(start_date: 15.days.ago, test_duration_days: 14)
    
    assert @ab_test.test_duration_reached?
    
    @ab_test.update!(start_date: 5.days.ago)
    assert_not @ab_test.test_duration_reached?
  end

  test "should provide test summary" do
    @ab_test.save!
    summary = @ab_test.test_summary
    
    assert_includes summary.keys, :test_name
    assert_includes summary.keys, :status
    assert_includes summary.keys, :primary_goal
    assert_includes summary.keys, :campaign_name
    assert_equal @ab_test.test_name, summary[:test_name]
    assert_equal @campaign_plan.name, summary[:campaign_name]
  end

  # Scope tests
  test "should scope by status" do
    @ab_test.save!
    draft_test = ContentAbTest.create!(
      test_name: 'Draft Test',
      status: 'draft',
      primary_goal: 'click_rate',
      confidence_level: '95',
      traffic_allocation: 50,
      minimum_sample_size: 50,
      test_duration_days: 7,
      campaign_plan: @campaign_plan,
      created_by: @user,
      control_content: @control_content
    )
    
    active_test = ContentAbTest.create!(
      test_name: 'Active Test',
      status: 'active',
      primary_goal: 'conversion_rate',
      confidence_level: '99',
      traffic_allocation: 75,
      minimum_sample_size: 200,
      test_duration_days: 21,
      campaign_plan: @campaign_plan,
      created_by: @user,
      control_content: @control_content
    )
    
    assert_includes ContentAbTest.draft, draft_test
    assert_includes ContentAbTest.draft, @ab_test
    assert_not_includes ContentAbTest.draft, active_test
    
    assert_includes ContentAbTest.active, active_test
    assert_not_includes ContentAbTest.active, draft_test
  end

  test "should scope by campaign" do
    @ab_test.save!
    other_campaign = campaign_plans(:completed_plan)
    other_content = GeneratedContent.create!(
      title: 'Other Content',
      body_content: 'Content for different campaign with sufficient characters for validation. This needs to be at least one hundred characters long to pass the standard format variant validation requirements.',
      content_type: 'email',
      format_variant: 'standard',
      status: 'draft',
      campaign_plan: other_campaign,
      created_by: @user
    )
    
    other_test = ContentAbTest.create!(
      test_name: 'Other Campaign Test',
      status: 'draft',
      primary_goal: 'click_rate',
      confidence_level: '95',
      traffic_allocation: 100,
      minimum_sample_size: 100,
      test_duration_days: 14,
      campaign_plan: other_campaign,
      created_by: @user,
      control_content: other_content
    )
    
    campaign_tests = ContentAbTest.by_campaign(@campaign_plan.id)
    assert_includes campaign_tests, @ab_test
    assert_not_includes campaign_tests, other_test
  end

  test "should scope by primary goal" do
    @ab_test.save!
    conversion_test = ContentAbTest.create!(
      test_name: 'Conversion Test',
      status: 'draft',
      primary_goal: 'conversion_rate',
      confidence_level: '95',
      traffic_allocation: 100,
      minimum_sample_size: 100,
      test_duration_days: 14,
      campaign_plan: @campaign_plan,
      created_by: @user,
      control_content: @control_content
    )
    
    click_tests = ContentAbTest.by_goal('click_rate')
    conversion_tests = ContentAbTest.by_goal('conversion_rate')
    
    assert_includes click_tests, @ab_test
    assert_not_includes click_tests, conversion_test
    assert_includes conversion_tests, conversion_test
    assert_not_includes conversion_tests, @ab_test
  end

  # Search tests
  test "should search tests by name and description" do
    @ab_test.description = 'Testing email subject lines for better engagement'
    @ab_test.save!
    
    other_test = ContentAbTest.create!(
      test_name: 'Social Media Test',
      description: 'Testing social media post variations',
      status: 'draft',
      primary_goal: 'engagement_rate',
      confidence_level: '95',
      traffic_allocation: 100,
      minimum_sample_size: 100,
      test_duration_days: 14,
      campaign_plan: @campaign_plan,
      created_by: @user,
      control_content: @control_content
    )
    
    email_results = ContentAbTest.search_tests('email')
    social_results = ContentAbTest.search_tests('social')
    
    assert_includes email_results, @ab_test
    assert_not_includes email_results, other_test
    assert_includes social_results, other_test
    assert_not_includes social_results, @ab_test
  end

  # Analytics tests
  test "should provide analytics summary" do
    @ab_test.save!
    ContentAbTest.create!(
      test_name: 'Another Test',
      status: 'active',
      primary_goal: 'conversion_rate',
      confidence_level: '99',
      traffic_allocation: 100,
      minimum_sample_size: 200,
      test_duration_days: 21,
      campaign_plan: @campaign_plan,
      created_by: @user,
      control_content: @control_content
    )
    
    summary = ContentAbTest.analytics_summary
    
    assert summary.key?(:total_tests)
    assert summary.key?(:by_status)
    assert summary.key?(:by_goal)
    assert summary.key?(:active_tests)
    assert summary.key?(:completed_tests)
    
    assert_equal 2, summary[:total_tests]
    assert_equal 1, summary[:by_status]['draft']
    assert_equal 1, summary[:by_status]['active']
  end

  # Custom validation tests
  test "should not allow start_date in past for new test" do
    @ab_test.start_date = 1.day.ago
    assert_not @ab_test.valid?
    assert_includes @ab_test.errors[:start_date], "cannot be in the past"
  end

  test "should validate end_date after start_date" do
    @ab_test.start_date = Time.current
    @ab_test.end_date = 1.day.ago
    
    assert_not @ab_test.valid?
    assert_includes @ab_test.errors[:end_date], "must be after start date"
  end

  test "should handle missing associations gracefully" do
    ab_test = ContentAbTest.new(
      test_name: 'Test without associations',
      status: 'draft',
      primary_goal: 'click_rate',
      confidence_level: '95',
      traffic_allocation: 100,
      minimum_sample_size: 100,
      test_duration_days: 14
    )
    
    assert_not ab_test.valid?
    assert_includes ab_test.errors[:campaign_plan], "must exist"
    assert_includes ab_test.errors[:created_by], "must exist"
    assert_includes ab_test.errors[:control_content], "must exist"
  end
end