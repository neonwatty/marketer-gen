require 'test_helper'

class SuggestionFeedbackTest < ActiveSupport::TestCase
  def setup
    @user = User.create!(
      email_address: 'test@example.com',
      password_digest: BCrypt::Password.create('password')
    )
    @journey = Journey.create!(
      name: 'Test Journey',
      user: @user,
      status: 'draft'
    )
    @journey_step = JourneyStep.create!(
      journey: @journey,
      name: 'Test Step',
      stage: 'awareness',
      position: 1
    )
    @feedback = SuggestionFeedback.new(
      journey: @journey,
      journey_step: @journey_step,
      user: @user,
      feedback_type: 'suggestion_quality',
      rating: 4,
      selected: true
    )
  end

  test "should be valid with valid attributes" do
    assert @feedback.valid?
  end

  test "should require journey" do
    @feedback.journey = nil
    assert_not @feedback.valid?
    assert_includes @feedback.errors[:journey], "must exist"
  end

  test "should require journey_step" do
    @feedback.journey_step = nil
    assert_not @feedback.valid?
    assert_includes @feedback.errors[:journey_step], "must exist"
  end

  test "should require user" do
    @feedback.user = nil
    assert_not @feedback.valid?
    assert_includes @feedback.errors[:user], "must exist"
  end

  test "should require feedback_type" do
    @feedback.feedback_type = nil
    assert_not @feedback.valid?
    assert_includes @feedback.errors[:feedback_type], "can't be blank"
  end

  test "should validate feedback_type inclusion" do
    @feedback.feedback_type = 'invalid_type'
    assert_not @feedback.valid?
    assert_includes @feedback.errors[:feedback_type], "is not included in the list"
  end

  test "should validate rating range" do
    @feedback.rating = 0
    assert_not @feedback.valid?
    
    @feedback.rating = 6
    assert_not @feedback.valid?
    
    @feedback.rating = 3
    assert @feedback.valid?
  end

  test "should allow nil rating" do
    @feedback.rating = nil
    assert @feedback.valid?
  end

  test "should validate selected boolean" do
    @feedback.selected = nil
    assert_not @feedback.valid?
    
    @feedback.selected = true
    assert @feedback.valid?
    
    @feedback.selected = false
    assert @feedback.valid?
  end

  test "should have default values" do
    feedback = SuggestionFeedback.new(
      journey: @journey,
      journey_step: @journey_step,
      user: @user,
      feedback_type: 'suggestion_quality'
    )
    
    assert_equal false, feedback.selected
    assert_equal({}, feedback.metadata)
  end

  test "positive? should return true for ratings >= 4" do
    @feedback.rating = 4
    assert @feedback.positive?
    
    @feedback.rating = 5
    assert @feedback.positive?
    
    @feedback.rating = 3
    assert_not @feedback.positive?
  end

  test "negative? should return true for ratings <= 2" do
    @feedback.rating = 1
    assert @feedback.negative?
    
    @feedback.rating = 2
    assert @feedback.negative?
    
    @feedback.rating = 3
    assert_not @feedback.negative?
  end

  test "neutral? should return true for rating = 3" do
    @feedback.rating = 3
    assert @feedback.neutral?
    
    @feedback.rating = 4
    assert_not @feedback.neutral?
  end

  test "should access suggested_step_data from metadata" do
    step_data = { 'name' => 'Test Suggestion', 'stage' => 'awareness' }
    @feedback.metadata = { 'suggested_step_data' => step_data }
    
    assert_equal step_data, @feedback.suggested_step_data
  end

  test "should access ai_provider from metadata" do
    @feedback.metadata = { 'provider' => 'openai' }
    assert_equal 'openai', @feedback.ai_provider
  end

  test "should scope positive feedback" do
    SuggestionFeedback.create!(
      journey: @journey,
      journey_step: @journey_step,
      user: @user,
      feedback_type: 'suggestion_quality',
      rating: 5,
      selected: false
    )
    
    SuggestionFeedback.create!(
      journey: @journey,
      journey_step: @journey_step,
      user: @user,
      feedback_type: 'suggestion_quality',
      rating: 2,
      selected: false
    )
    
    positive_feedback = SuggestionFeedback.positive
    assert_equal 1, positive_feedback.count
    assert positive_feedback.first.rating >= 4
  end

  test "should scope negative feedback" do
    SuggestionFeedback.create!(
      journey: @journey,
      journey_step: @journey_step,
      user: @user,
      feedback_type: 'suggestion_quality',
      rating: 1,
      selected: false
    )
    
    SuggestionFeedback.create!(
      journey: @journey,
      journey_step: @journey_step,
      user: @user,
      feedback_type: 'suggestion_quality',
      rating: 4,
      selected: false
    )
    
    negative_feedback = SuggestionFeedback.negative
    assert_equal 1, negative_feedback.count
    assert negative_feedback.first.rating <= 2
  end

  test "should scope selected feedback" do
    @feedback.save!
    
    SuggestionFeedback.create!(
      journey: @journey,
      journey_step: @journey_step,
      user: @user,
      feedback_type: 'suggestion_quality',
      rating: 3,
      selected: false
    )
    
    selected_feedback = SuggestionFeedback.selected
    assert_equal 1, selected_feedback.count
    assert selected_feedback.first.selected?
  end

  test "should scope by feedback type" do
    @feedback.save!
    
    SuggestionFeedback.create!(
      journey: @journey,
      journey_step: @journey_step,
      user: @user,
      feedback_type: 'relevance',
      rating: 3,
      selected: false
    )
    
    quality_feedback = SuggestionFeedback.by_feedback_type('suggestion_quality')
    assert_equal 1, quality_feedback.count
    assert_equal 'suggestion_quality', quality_feedback.first.feedback_type
  end

  test "should scope recent feedback" do
    @feedback.created_at = 10.days.ago
    @feedback.save!
    
    recent_feedback = SuggestionFeedback.create!(
      journey: @journey,
      journey_step: @journey_step,
      user: @user,
      feedback_type: 'suggestion_quality',
      rating: 3,
      selected: false
    )
    
    recent = SuggestionFeedback.recent
    assert_includes recent, recent_feedback
    assert_not_includes recent, @feedback
  end

  test "should calculate average rating by type" do
    @feedback.save!
    
    SuggestionFeedback.create!(
      journey: @journey,
      journey_step: @journey_step,
      user: @user,
      feedback_type: 'suggestion_quality',
      rating: 2,
      selected: false
    )
    
    SuggestionFeedback.create!(
      journey: @journey,
      journey_step: @journey_step,
      user: @user,
      feedback_type: 'relevance',
      rating: 5,
      selected: false
    )
    
    averages = SuggestionFeedback.average_rating_by_type
    assert_equal 3.0, averages['suggestion_quality'] # (4 + 2) / 2
    assert_equal 5.0, averages['relevance']
  end

  test "should calculate selection rate by content type" do
    @journey_step.update!(content_type: 'email')
    @feedback.save!
    
    # Create another step with different content type
    blog_step = JourneyStep.create!(
      journey: @journey,
      name: 'Blog Step',
      stage: 'awareness',
      position: 2,
      content_type: 'blog_post'
    )
    
    SuggestionFeedback.create!(
      journey: @journey,
      journey_step: blog_step,
      user: @user,
      feedback_type: 'suggestion_quality',
      rating: 3,
      selected: false
    )
    
    rates = SuggestionFeedback.selection_rate_by_content_type
    
    # Should have data for both content types
    assert rates.any? { |key, _| key[:content_type] == 'email' && key[:selected] == true }
    assert rates.any? { |key, _| key[:content_type] == 'blog_post' && key[:selected] == false }
  end

  test "should require rating for certain feedback types" do
    feedback = SuggestionFeedback.new(
      journey: @journey,
      journey_step: @journey_step,
      user: @user,
      feedback_type: 'suggestion_quality',
      rating: nil
    )
    
    assert_not feedback.valid?
    assert_includes feedback.errors[:rating], "is required for suggestion_quality"
  end

  test "should associate with journey through journey_step" do
    @feedback.save!
    
    assert_equal @journey, @feedback.journey
    assert_equal @journey_step, @feedback.journey_step
    assert_includes @journey.suggestion_feedbacks, @feedback
  end
end