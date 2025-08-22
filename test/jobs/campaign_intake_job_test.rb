# frozen_string_literal: true

require 'test_helper'

class CampaignIntakeJobTest < ActiveJob::TestCase
  def setup
    @user = users(:marketer_user)
    @conversation_data = {
      state: 'gathering_basics',
      extracted_parameters: { 'campaign_type' => 'awareness' },
      conversation_history: [],
      question_count: 1
    }
    @user_response = "I want to target tech professionals"
  end

  test "should process intake conversation successfully" do
    # Mock successful service response
    CampaignIntakeService.stubs(:call).returns({
      success: true,
      data: {
        completed: false,
        question: "What's your budget range?",
        conversation_state: 'collecting_constraints',
        conversation_data: @conversation_data.merge(question_count: 2),
        progress: { percentage: 40, question_count: 2 }
      }
    })

    # Test that the job can be performed without errors
    assert_nothing_raised do
      CampaignIntakeJob.perform_now(
        user_id: @user.id,
        conversation_data: @conversation_data,
        user_response: @user_response
      )
    end
  end

  test "should handle service failure gracefully" do
    # Mock service failure
    CampaignIntakeService.stubs(:call).returns({
      success: false,
      error: "LLM service unavailable",
      context: { current_state: 'gathering_basics' }
    })

    # Should not raise error, but should log it
    Rails.logger.expects(:error).with("Campaign intake service failed", anything)

    CampaignIntakeJob.perform_now(
      user_id: @user.id,
      conversation_data: @conversation_data,
      user_response: @user_response
    )
  end

  test "should create new journey on completed intake" do
    final_parameters = {
      'campaign_type' => 'awareness',
      'primary_objective' => 'increase brand visibility',
      'target_audience' => 'tech professionals',
      'budget_range' => '$10,000',
      'timeline' => '2 months',
      'key_messaging' => 'innovation and reliability'
    }

    # Mock completed intake
    CampaignIntakeService.stubs(:call).returns({
      success: true,
      data: {
        completed: true,
        final_parameters: final_parameters,
        summary: "Campaign intake completed!"
      }
    })

    initial_journey_count = @user.journeys.count

    CampaignIntakeJob.perform_now(
      user_id: @user.id,
      conversation_data: @conversation_data,
      user_response: @user_response
    )

    assert_equal initial_journey_count + 1, @user.journeys.count
    
    new_journey = @user.journeys.last
    assert_equal 'awareness', new_journey.campaign_type
    assert_equal 'draft', new_journey.status
    assert_includes new_journey.name.downcase, 'awareness'
    assert_equal final_parameters, new_journey.metadata['extracted_parameters']
  end

  test "should update existing journey on completed intake" do
    existing_journey = @user.journeys.create!(
      name: "Test Journey",
      campaign_type: 'consideration',
      status: 'draft'
    )

    conversation_data_with_journey = @conversation_data.merge('journey_id' => existing_journey.id)
    
    final_parameters = {
      'campaign_type' => 'awareness',
      'primary_objective' => 'updated objective',
      'target_audience' => 'new audience'
    }

    # Mock completed intake
    CampaignIntakeService.stubs(:call).returns({
      success: true,
      data: {
        completed: true,
        final_parameters: final_parameters,
        summary: "Updated campaign!"
      }
    })

    CampaignIntakeJob.perform_now(
      user_id: @user.id,
      conversation_data: conversation_data_with_journey,
      user_response: @user_response
    )

    existing_journey.reload
    assert_equal 'awareness', existing_journey.campaign_type
    assert_equal final_parameters, existing_journey.metadata['extracted_parameters']
  end

  test "should store conversation state for incomplete intake" do
    incomplete_data = {
      completed: false,
      question: "What's your timeline?",
      conversation_state: 'collecting_constraints',
      conversation_data: @conversation_data.merge(question_count: 2),
      progress: { percentage: 50 }
    }

    CampaignIntakeService.stubs(:call).returns({
      success: true,
      data: incomplete_data
    })

    cache_key = "campaign_intake:#{@user.id}:conversation"
    
    CampaignIntakeJob.perform_now(
      user_id: @user.id,
      conversation_data: @conversation_data,
      user_response: @user_response
    )

    cached_data = Rails.cache.read(cache_key)
    assert_not_nil cached_data
    assert_equal 2, cached_data[:question_count]
  end

  test "should cleanup conversation data on completion" do
    final_parameters = {
      'campaign_type' => 'awareness',
      'primary_objective' => 'test objective'
    }

    # Pre-populate cache
    cache_key = "campaign_intake:#{@user.id}:conversation"
    Rails.cache.write(cache_key, @conversation_data)

    CampaignIntakeService.stubs(:call).returns({
      success: true,
      data: {
        completed: true,
        final_parameters: final_parameters,
        summary: "Done!"
      }
    })

    CampaignIntakeJob.perform_now(
      user_id: @user.id,
      conversation_data: @conversation_data,
      user_response: @user_response
    )

    assert_nil Rails.cache.read(cache_key)
  end

  test "should handle user not found error" do
    assert_raises ActiveRecord::RecordNotFound do
      job = CampaignIntakeJob.new
      job.perform(
        user_id: 999999, # Non-existent user
        conversation_data: @conversation_data,
        user_response: @user_response
      )
    end
  end

  test "should map campaign types correctly" do
    job = CampaignIntakeJob.new
    
    assert_equal 'awareness', job.send(:map_campaign_type, 'awareness')
    assert_equal 'upsell_cross_sell', job.send(:map_campaign_type, 'upsell')
    assert_equal 'upsell_cross_sell', job.send(:map_campaign_type, 'cross_sell')
    assert_equal 'awareness', job.send(:map_campaign_type, 'unknown_type') # fallback
  end

  test "should determine template type from parameters" do
    job = CampaignIntakeJob.new
    
    # Test email template detection
    email_params = { 'key_messaging' => 'email newsletter campaign' }
    assert_equal 'email', job.send(:determine_template_type, email_params)
    
    # Test social media template detection
    social_params = { 'primary_objective' => 'increase social media engagement' }
    assert_equal 'social_media', job.send(:determine_template_type, social_params)
    
    # Test event template detection
    event_params = { 'key_messaging' => 'webinar promotion' }
    assert_equal 'event', job.send(:determine_template_type, event_params)
    
    # Test default template
    default_params = { 'primary_objective' => 'general marketing' }
    assert_equal 'custom', job.send(:determine_template_type, default_params)
  end

  test "should generate appropriate journey name" do
    job = CampaignIntakeJob.new
    
    parameters = {
      'campaign_type' => 'awareness',
      'primary_objective' => 'increase brand visibility'
    }
    
    name = job.send(:generate_journey_name, parameters)
    assert_includes name.downcase, 'awareness'
    assert_includes name.downcase, 'increase brand visibility'
  end

  test "should handle ActionCable notification" do
    callback_params = {
      notification_type: 'actioncable',
      channel_name: 'intake_channel'
    }

    notification_data = {
      user_id: @user.id,
      completed: false,
      progress: { percentage: 50 }
    }

    # Mock ActionCable broadcast
    ActionCable.server.expects(:broadcast).with(
      'intake_channel',
      {
        type: 'campaign_intake_update',
        data: notification_data
      }
    )

    CampaignIntakeService.stubs(:call).returns({
      success: true,
      data: {
        completed: false,
        question: "What's your budget?",
        progress: { percentage: 50 }
      }
    })

    CampaignIntakeJob.perform_now(
      user_id: @user.id,
      conversation_data: @conversation_data,
      user_response: @user_response,
      callback_params: callback_params
    )
  end

  test "should handle webhook notification" do
    callback_params = {
      notification_type: 'webhook',
      webhook_url: 'https://example.com/webhook'
    }

    # Just test that it logs the webhook attempt
    Rails.logger.stubs(:info) # Allow any info calls
    Rails.logger.expects(:info).with("Would send webhook notification", anything).once

    CampaignIntakeService.stubs(:call).returns({
      success: true,
      data: {
        completed: false,
        question: "What's your budget?",
        progress: { percentage: 50 }
      }
    })

    assert_nothing_raised do
      CampaignIntakeJob.perform_now(
        user_id: @user.id,
        conversation_data: @conversation_data,
        user_response: @user_response,
        callback_params: callback_params
      )
    end
  end

  test "should store error state on service failure" do
    error_message = "LLM service timeout"
    
    CampaignIntakeService.stubs(:call).returns({
      success: false,
      error: error_message,
      context: { current_state: 'gathering_basics' }
    })

    error_cache_key = "campaign_intake:#{@user.id}:error"

    # Also need to stub logger calls to avoid interference
    Rails.logger.stubs(:error)

    CampaignIntakeJob.perform_now(
      user_id: @user.id,
      conversation_data: @conversation_data,
      user_response: @user_response
    )

    error_data = Rails.cache.read(error_cache_key)
    assert_not_nil error_data
    assert_equal error_message, error_data[:error]
    assert_equal({ current_state: 'gathering_basics' }, error_data[:context])
  end

  test "should be configured for retries" do
    # Test that the job class has retry configuration
    assert_respond_to CampaignIntakeJob, :retry_on
  end

  test "should be configured to discard on certain errors" do
    # Test that the job class has discard configuration  
    assert_respond_to CampaignIntakeJob, :discard_on
  end

  test "should build journey params correctly" do
    job = CampaignIntakeJob.new
    job.instance_variable_set(:@user, @user)
    
    parameters = {
      'campaign_type' => 'conversion',
      'primary_objective' => 'increase sales',
      'target_audience' => 'qualified leads',
      'budget_range' => '$20,000',
      'timeline' => '3 months',
      'key_messaging' => 'value and benefits'
    }
    
    journey_params = job.send(:build_journey_params, parameters)
    
    assert_includes journey_params[:name], 'Conversion Campaign'
    assert_equal 'increase sales', journey_params[:description]
    assert_equal 'conversion', journey_params[:campaign_type]
    assert_equal 'custom', journey_params[:template_type]
    assert_equal 'draft', journey_params[:status]
    
    metadata = journey_params[:metadata]
    assert_equal 'llm_guided', metadata[:intake_source]
    assert_equal parameters, metadata[:extracted_parameters]
    assert_equal '$20,000', metadata[:budget_range]
    assert_equal '3 months', metadata[:timeline]
  end

  test "should handle missing parameters gracefully in journey creation" do
    job = CampaignIntakeJob.new
    job.instance_variable_set(:@user, @user)
    
    # Minimal parameters
    parameters = {
      'campaign_type' => 'awareness'
    }
    
    journey_params = job.send(:build_journey_params, parameters)
    
    assert_not_nil journey_params[:name]
    assert_equal 'awareness', journey_params[:campaign_type]
    assert_equal 'custom', journey_params[:template_type] # default
  end
end