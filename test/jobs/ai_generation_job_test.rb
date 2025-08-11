require "test_helper"

class AIGenerationJobTest < ActiveJob::TestCase
  include ActiveJob::TestHelper

  def setup
    @campaign = campaigns(:one)
    @generation_request = AIGenerationRequest.create!(
      campaign: @campaign,
      content_type: 'social_media_post',
      prompt_data: { 
        topic: 'summer sale',
        tone: 'exciting',
        target_audience: 'young adults'
      },
      status: 'pending'
    )
  end

  # Basic job functionality tests
  test "should enqueue job successfully" do
    assert_enqueued_with(job: AIGenerationJob, args: [@generation_request.id, 'social_media_post', @generation_request.prompt_data]) do
      AIGenerationJob.perform_later(@generation_request.id, 'social_media_post', @generation_request.prompt_data)
    end
  end

  test "should be queued in ai_generation queue" do
    job = AIGenerationJob.new(@generation_request.id, 'social_media_post', @generation_request.prompt_data)
    assert_equal 'ai_generation', job.queue_name
  end

  # Job execution tests
  test "should update job status during execution" do
    # Mock AIService to return successful response
    mock_ai_service = Minitest::Mock.new
    mock_ai_service.expect :generate_content, {
      content: 'Generated social media content',
      metadata: { tokens_used: 50 }
    }, ['social_media_post', @generation_request.prompt_data]

    # Mock AI service instantiation
    AIService.stub :new, mock_ai_service do
      perform_enqueued_jobs do
        AIGenerationJob.perform_later(@generation_request.id, 'social_media_post', @generation_request.prompt_data)
      end
    end

    # Verify job status was created and updated
    job_status = @generation_request.ai_job_statuses.last
    assert job_status
    assert_equal 'completed', job_status.status
    assert job_status.progress_data['started_at']
    assert job_status.progress_data['completed_at']

    mock_ai_service.verify
  end

  test "should update generation request status on completion" do
    # Mock successful AI generation
    mock_ai_service = Minitest::Mock.new
    mock_ai_service.expect :generate_content, {
      content: 'Great summer sale content! #SummerSale #Deals',
      metadata: { tokens_used: 25, quality_score: 85 }
    }, ['social_media_post', @generation_request.prompt_data]

    AIService.stub :new, mock_ai_service do
      perform_enqueued_jobs do
        AIGenerationJob.perform_later(@generation_request.id, 'social_media_post', @generation_request.prompt_data)
      end
    end

    @generation_request.reload
    assert_equal 'completed', @generation_request.status
    assert @generation_request.generated_content
    assert @generation_request.metadata
    assert @generation_request.completed_at

    mock_ai_service.verify
  end

  # Full pipeline integration tests
  test "should run complete parsing and validation pipeline" do
    # Mock AI service to return structured response
    mock_ai_response = {
      content: [
        { type: 'text', text: 'Check out our amazing summer sale! Save up to 50% on all items. #SummerSale #Deals' }
      ],
      usage: { input_tokens: 20, output_tokens: 15 },
      model: 'claude-3-sonnet'
    }

    mock_ai_service = Minitest::Mock.new
    mock_ai_service.expect :generate_content, mock_ai_response, ['social_media_post', @generation_request.prompt_data]

    # Mock provider determination
    mock_provider = Minitest::Mock.new
    mock_provider.expect :provider_name, 'anthropic'
    mock_ai_service.expect :ai_provider, mock_provider

    AIService.stub :new, mock_ai_service do
      perform_enqueued_jobs do
        AIGenerationJob.perform_later(@generation_request.id, 'social_media_post', @generation_request.prompt_data)
      end
    end

    @generation_request.reload

    # Verify the full pipeline was executed
    assert_equal 'completed', @generation_request.status
    assert @generation_request.metadata['parsing']
    assert @generation_request.metadata['validation']
    assert @generation_request.metadata['moderation']
    assert @generation_request.metadata['transformation']

    # Verify content was properly transformed
    transformed_content = @generation_request.generated_content
    assert transformed_content.is_a?(Hash)

    mock_ai_service.verify
    mock_provider.verify
  end

  test "should flag content for review when moderation issues detected" do
    # Mock AI service to return content that will trigger moderation
    mock_ai_response = {
      content: 'This damn product is amazing! Contact me at john@example.com for deals. BUY NOW!!!',
      metadata: { tokens_used: 20 }
    }

    mock_ai_service = Minitest::Mock.new
    mock_ai_service.expect :generate_content, mock_ai_response, ['social_media_post', @generation_request.prompt_data]

    # Mock provider
    mock_provider = Minitest::Mock.new
    mock_provider.expect :provider_name, 'anthropic'
    mock_ai_service.expect :ai_provider, mock_provider

    AIService.stub :new, mock_ai_service do
      perform_enqueued_jobs do
        AIGenerationJob.perform_later(@generation_request.id, 'social_media_post', @generation_request.prompt_data)
      end
    end

    @generation_request.reload

    # Should be marked for review due to profanity and personal info
    assert_equal 'review', @generation_request.status
    
    # Should have moderation results
    assert @generation_request.metadata['moderation']
    assert @generation_request.metadata['moderation']['flagged']

    mock_ai_service.verify
    mock_provider.verify
  end

  test "should block content when severe moderation violations detected" do
    # Mock AI service to return content that should be blocked
    severely_problematic_content = "This shit product will hack your password and steal credit card 1234-5678-9012-3456"

    mock_ai_service = Minitest::Mock.new
    mock_ai_service.expect :generate_content, {
      content: severely_problematic_content,
      metadata: { tokens_used: 30 }
    }, ['social_media_post', @generation_request.prompt_data]

    # Mock provider
    mock_provider = Minitest::Mock.new
    mock_provider.expect :provider_name, 'openai'
    mock_ai_service.expect :ai_provider, mock_provider

    AIService.stub :new, mock_ai_service do
      perform_enqueued_jobs do
        AIGenerationJob.perform_later(@generation_request.id, 'social_media_post', @generation_request.prompt_data)
      end
    end

    @generation_request.reload

    # Job should be discarded due to content blocking
    assert_equal 'failed', @generation_request.status
    
    # Should have error information
    job_status = @generation_request.ai_job_statuses.last
    assert job_status
    assert_equal 'failed', job_status.status

    mock_ai_service.verify
    mock_provider.verify
  end

  test "should reject content with failed validation" do
    # Mock AI service to return very poor quality content
    poor_quality_content = "bad [TODO] fix this"

    mock_ai_service = Minitest::Mock.new
    mock_ai_service.expect :generate_content, {
      content: poor_quality_content,
      metadata: { tokens_used: 10 }
    }, ['social_media_post', @generation_request.prompt_data]

    # Mock provider
    mock_provider = Minitest::Mock.new
    mock_provider.expect :provider_name, 'openai'
    mock_ai_service.expect :ai_provider, mock_provider

    AIService.stub :new, mock_ai_service do
      perform_enqueued_jobs do
        AIGenerationJob.perform_later(@generation_request.id, 'social_media_post', @generation_request.prompt_data)
      end
    end

    @generation_request.reload

    # Should fail due to validation
    assert_equal 'failed', @generation_request.status

    mock_ai_service.verify
    mock_provider.verify
  end

  # Different content type tests
  test "should handle email content type transformation" do
    email_request = AIGenerationRequest.create!(
      campaign: @campaign,
      content_type: 'email_content',
      prompt_data: {
        subject: 'Newsletter signup',
        tone: 'professional'
      },
      status: 'pending'
    )

    mock_ai_response = {
      content: "Subject: Welcome to Our Newsletter\n\nDear Customer,\n\nThank you for subscribing!",
      metadata: { tokens_used: 25 }
    }

    mock_ai_service = Minitest::Mock.new
    mock_ai_service.expect :generate_content, mock_ai_response, ['email_content', email_request.prompt_data]

    # Mock provider
    mock_provider = Minitest::Mock.new
    mock_provider.expect :provider_name, 'anthropic'
    mock_ai_service.expect :ai_provider, mock_provider

    AIService.stub :new, mock_ai_service do
      perform_enqueued_jobs do
        AIGenerationJob.perform_later(email_request.id, 'email_content', email_request.prompt_data)
      end
    end

    email_request.reload

    assert_equal 'completed', email_request.status
    
    # Verify email-specific transformation was applied
    transformed_content = email_request.generated_content
    assert transformed_content.is_a?(Hash)

    mock_ai_service.verify
    mock_provider.verify
  end

  test "should handle campaign strategy content type" do
    strategy_request = AIGenerationRequest.create!(
      campaign: @campaign,
      content_type: 'campaign_strategy',
      prompt_data: {
        objective: 'Increase brand awareness',
        budget: 10000
      },
      status: 'pending'
    )

    mock_ai_response = {
      content: "Objective: Increase brand awareness\nTarget Audience: Young professionals\nBudget: $10,000",
      metadata: { tokens_used: 40 }
    }

    mock_ai_service = Minitest::Mock.new
    mock_ai_service.expect :generate_content, mock_ai_response, ['campaign_strategy', strategy_request.prompt_data]

    # Mock provider
    mock_provider = Minitest::Mock.new
    mock_provider.expect :provider_name, 'anthropic'
    mock_ai_service.expect :ai_provider, mock_provider

    AIService.stub :new, mock_ai_service do
      perform_enqueued_jobs do
        AIGenerationJob.perform_later(strategy_request.id, 'campaign_strategy', strategy_request.prompt_data)
      end
    end

    strategy_request.reload

    assert_equal 'completed', strategy_request.status
    
    # Should be transformed as campaign_plan
    transformed_content = strategy_request.generated_content
    assert transformed_content.is_a?(Hash)

    mock_ai_service.verify
    mock_provider.verify
  end

  # Brand guidelines integration tests
  test "should extract and apply brand guidelines from campaign" do
    # Set up brand identity for the campaign
    brand_identity = BrandIdentity.create!(
      name: 'Acme Corp',
      voice_tone: 'professional',
      core_values: 'innovation, quality, customer focus',
      target_audience: 'business professionals'
    )
    @campaign.update!(brand_identity: brand_identity)

    mock_ai_response = {
      content: 'Our company provides excellent solutions with innovation and quality focus.',
      metadata: { tokens_used: 20 }
    }

    mock_ai_service = Minitest::Mock.new
    mock_ai_service.expect :generate_content, mock_ai_response, ['social_media_post', @generation_request.prompt_data]

    # Mock provider
    mock_provider = Minitest::Mock.new
    mock_provider.expect :provider_name, 'anthropic'
    mock_ai_service.expect :ai_provider, mock_provider

    AIService.stub :new, mock_ai_service do
      perform_enqueued_jobs do
        AIGenerationJob.perform_later(@generation_request.id, 'social_media_post', @generation_request.prompt_data)
      end
    end

    @generation_request.reload

    # Verify brand guidelines were applied during validation
    validation_results = @generation_request.metadata['validation']
    brand_compliance = validation_results['validation_results'].find { |r| r['type'] == 'brand_compliance' }
    
    # Brand compliance validation should have been run
    assert brand_compliance if validation_results['validation_results'].any? { |r| r['type'] == 'brand_compliance' }

    mock_ai_service.verify
    mock_provider.verify
  end

  # Webhook notification tests
  test "should send webhook notification on completion when webhook_url provided" do
    @generation_request.update!(webhook_url: 'https://example.com/webhook')

    mock_ai_response = {
      content: 'Generated content for webhook test',
      metadata: { tokens_used: 15 }
    }

    mock_ai_service = Minitest::Mock.new
    mock_ai_service.expect :generate_content, mock_ai_response, ['social_media_post', @generation_request.prompt_data]

    # Mock provider
    mock_provider = Minitest::Mock.new
    mock_provider.expect :provider_name, 'anthropic'
    mock_ai_service.expect :ai_provider, mock_provider

    # Verify webhook job is enqueued
    assert_enqueued_with(job: WebhookNotificationJob) do
      AIService.stub :new, mock_ai_service do
        perform_enqueued_jobs only: AIGenerationJob do
          AIGenerationJob.perform_later(@generation_request.id, 'social_media_post', @generation_request.prompt_data)
        end
      end
    end

    mock_ai_service.verify
    mock_provider.verify
  end

  test "should not send webhook when no webhook_url provided" do
    # No webhook_url set on generation_request

    mock_ai_response = {
      content: 'Generated content without webhook',
      metadata: { tokens_used: 15 }
    }

    mock_ai_service = Minitest::Mock.new
    mock_ai_service.expect :generate_content, mock_ai_response, ['social_media_post', @generation_request.prompt_data]

    # Mock provider
    mock_provider = Minitest::Mock.new
    mock_provider.expect :provider_name, 'anthropic'
    mock_ai_service.expect :ai_provider, mock_provider

    # Verify no webhook job is enqueued
    assert_no_enqueued_jobs only: WebhookNotificationJob do
      AIService.stub :new, mock_ai_service do
        perform_enqueued_jobs only: AIGenerationJob do
          AIGenerationJob.perform_later(@generation_request.id, 'social_media_post', @generation_request.prompt_data)
        end
      end
    end

    mock_ai_service.verify
    mock_provider.verify
  end

  # Error handling tests
  test "should handle AI service errors gracefully" do
    mock_ai_service = Minitest::Mock.new
    mock_ai_service.expect :generate_content, -> { raise StandardError.new('AI service error') }, ['social_media_post', @generation_request.prompt_data]

    AIService.stub :new, mock_ai_service do
      perform_enqueued_jobs do
        assert_raises StandardError do
          AIGenerationJob.perform_later(@generation_request.id, 'social_media_post', @generation_request.prompt_data)
        end
      end
    end

    @generation_request.reload
    assert_equal 'failed', @generation_request.status

    # Should have job status with error
    job_status = @generation_request.ai_job_statuses.last
    assert job_status
    assert_equal 'failed', job_status.status
    assert job_status.progress_data['error_message']

    mock_ai_service.verify
  end

  test "should handle missing generation request" do
    non_existent_id = 99999

    assert_raises ActiveRecord::RecordNotFound do
      perform_enqueued_jobs do
        AIGenerationJob.perform_later(non_existent_id, 'social_media_post', {})
      end
    end
  end

  test "should retry on transient errors" do
    call_count = 0
    mock_ai_service = Minitest::Mock.new
    
    # First call fails with timeout, second succeeds
    mock_ai_service.expect :generate_content, -> { 
      call_count += 1
      if call_count == 1
        raise Net::TimeoutError.new('Request timeout')
      else
        { content: 'Success after retry', metadata: { tokens_used: 20 } }
      end
    }, ['social_media_post', @generation_request.prompt_data]

    # Need to handle the second call for provider mock
    mock_provider = Minitest::Mock.new
    mock_provider.expect :provider_name, 'anthropic'
    mock_ai_service.expect :ai_provider, mock_provider

    AIService.stub :new, mock_ai_service do
      perform_enqueued_jobs do
        AIGenerationJob.perform_later(@generation_request.id, 'social_media_post', @generation_request.prompt_data)
      end
    end

    @generation_request.reload
    assert_equal 'completed', @generation_request.status
    assert_equal 'Success after retry', @generation_request.generated_content[:content]

    mock_ai_service.verify
    mock_provider.verify
  end

  test "should discard job on content blocked error" do
    mock_ai_service = Minitest::Mock.new
    mock_ai_service.expect :generate_content, {
      content: 'Content that will be blocked by moderation',
      metadata: { tokens_used: 20 }
    }, ['social_media_post', @generation_request.prompt_data]

    # Mock provider
    mock_provider = Minitest::Mock.new
    mock_provider.expect :provider_name, 'anthropic'
    mock_ai_service.expect :ai_provider, mock_provider

    # Mock moderation to return blocked status
    mock_moderator = Minitest::Mock.new
    mock_moderator.expect :moderate, {
      blocked: true,
      overall_action: 'block',
      flagged: false,
      moderation_results: []
    }, [String]

    AiContentModerator.stub :new, mock_moderator do
      AIService.stub :new, mock_ai_service do
        perform_enqueued_jobs do
          AIGenerationJob.perform_later(@generation_request.id, 'social_media_post', @generation_request.prompt_data)
        end
      end
    end

    @generation_request.reload
    assert_equal 'failed', @generation_request.status

    # Job should be marked as discarded due to ContentBlockedError
    job_status = @generation_request.ai_job_statuses.last
    assert job_status
    assert_equal 'failed', job_status.status

    mock_ai_service.verify
    mock_provider.verify
    mock_moderator.verify
  end

  # Metadata and logging tests
  test "should log comprehensive job execution information" do
    mock_ai_response = {
      content: 'Test content for logging verification',
      metadata: { tokens_used: 30, model: 'test-model' }
    }

    mock_ai_service = Minitest::Mock.new
    mock_ai_service.expect :generate_content, mock_ai_response, ['social_media_post', @generation_request.prompt_data]

    # Mock provider
    mock_provider = Minitest::Mock.new
    mock_provider.expect :provider_name, 'test_provider'
    mock_ai_service.expect :ai_provider, mock_provider

    AIService.stub :new, mock_ai_service do
      perform_enqueued_jobs do
        AIGenerationJob.perform_later(@generation_request.id, 'social_media_post', @generation_request.prompt_data)
      end
    end

    @generation_request.reload
    job_status = @generation_request.ai_job_statuses.last

    # Verify comprehensive logging data
    assert job_status.progress_data['started_at']
    assert job_status.progress_data['completed_at']
    assert job_status.progress_data['quality_score']
    assert job_status.progress_data['moderation_status']
    assert job_status.progress_data['tokens_used']
    assert job_status.progress_data['content_length']

    mock_ai_service.verify
    mock_provider.verify
  end

  private

  def mock_successful_ai_response(content_type = 'social_media_post')
    case content_type
    when 'social_media_post'
      'Exciting summer sale! Save up to 50% on all items! #SummerSale #Deals'
    when 'email_content'
      "Subject: Summer Sale Alert\n\nDear Customer,\n\nDon't miss our amazing summer sale!"
    when 'campaign_strategy'
      "Objective: Increase sales\nTarget Audience: Young adults\nBudget: $10,000"
    else
      'Generated content for testing purposes'
    end
  end

  def create_mock_ai_service(response_content, tokens_used = 25)
    mock_service = Minitest::Mock.new
    mock_service.expect :generate_content, {
      content: response_content,
      metadata: { tokens_used: tokens_used }
    }
    
    mock_provider = Minitest::Mock.new
    mock_provider.expect :provider_name, 'test_provider'
    mock_service.expect :ai_provider, mock_provider
    
    [mock_service, mock_provider]
  end
end