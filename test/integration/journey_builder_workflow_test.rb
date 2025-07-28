require "test_helper"

class JourneyBuilderWorkflowTest < ActionDispatch::IntegrationTest
  setup do
    @user = create(:user)
    @persona = create(:persona, user: @user)
    @campaign = create(:campaign, user: @user, persona: @persona)
    
    # Mock LLM API responses
    mock_llm_response(
      JSON.generate({
        suggestions: [
          {
            name: "Welcome Email",
            description: "Send a personalized welcome email to new subscribers",
            stage: "awareness",
            content_type: "email",
            channel: "email",
            confidence_score: 0.9
          },
          {
            name: "Educational Content",
            description: "Share valuable educational content about the product",
            stage: "consideration",
            content_type: "email",
            channel: "email",
            confidence_score: 0.8
          }
        ]
      })
    )
    
    sign_in_as(@user)
  end

  test "complete journey creation workflow" do
    # Step 1: Create a new journey
    post api_v1_journeys_path, 
      params: { 
        journey: {
          name: "Customer Onboarding Journey",
          description: "A comprehensive onboarding journey for new customers",
          campaign_type: "customer_retention"
        }
      }, 
      as: :json

    assert_response :created
    response_data = JSON.parse(response.body)
    journey_id = response_data['data']['id']
    
    # Step 2: Add journey steps
    post api_v1_journey_journey_steps_path(journey_id),
      params: {
        journey_step: {
          name: "Welcome Email",
          description: "Send welcome email to new users",
          stage: "awareness",
          content_type: "email",
          channel: "email",
          position: 1
        }
      },
      as: :json
    
    assert_response :created
    step_data = JSON.parse(response.body)
    step_id = step_data['data']['id']
    
    # Step 3: Get AI suggestions for next steps
    get suggestions_api_v1_journey_path(journey_id),
      params: { stage: "consideration" },
      as: :json
    
    assert_response :success
    suggestions_data = JSON.parse(response.body)
    assert suggestions_data['data'].is_a?(Array)
    assert suggestions_data['data'].length > 0
    
    # Step 4: Add a suggested step
    suggested_step = suggestions_data['data'].first
    post api_v1_journey_journey_steps_path(journey_id),
      params: {
        journey_step: {
          name: suggested_step['name'],
          description: suggested_step['description'],
          stage: suggested_step['stage'],
          content_type: suggested_step['content_type'],
          channel: suggested_step['channel'],
          position: 2
        }
      },
      as: :json
    
    assert_response :created
    
    # Step 5: Publish the journey
    post publish_api_v1_journey_path(journey_id), as: :json
    assert_response :success
    
    published_data = JSON.parse(response.body)
    assert_equal 'published', published_data['data']['status']
    assert_not_nil published_data['data']['published_at']
    
    # Step 6: Execute the journey (simulation)
    post execute_api_v1_journey_path(journey_id),
      params: { 
        execution: {
          execution_type: "test",
          target_audience_size: 100
        }
      },
      as: :json
    
    assert_response :success
    execution_data = JSON.parse(response.body)
    assert execution_data['data']['execution_id']
    
    # Step 7: Check journey analytics
    get analytics_api_v1_journey_path(journey_id), as: :json
    assert_response :success
    
    analytics_data = JSON.parse(response.body)
    assert analytics_data['data']['summary']
    assert analytics_data['data']['performance_score'].is_a?(Numeric)
  end

  test "journey template creation and usage workflow" do
    # Step 1: Create a journey template
    post api_v1_journey_templates_path,
      params: {
        journey_template: {
          name: "Email Nurture Template",
          description: "A template for email nurturing campaigns",
          category: "nurture",
          template_data: {
            steps: [
              {
                name: "Welcome Email",
                stage: "awareness",
                content_type: "email",
                channel: "email"
              },
              {
                name: "Educational Content",
                stage: "consideration", 
                content_type: "email",
                channel: "email"
              }
            ]
          }
        }
      },
      as: :json
    
    assert_response :created
    template_data = JSON.parse(response.body)
    template_id = template_data['data']['id']
    
    # Step 2: Create journey from template
    post create_from_template_api_v1_journey_templates_path(template_id),
      params: {
        journey: {
          name: "Q1 Email Campaign"
        }
      },
      as: :json
    
    assert_response :created
    journey_data = JSON.parse(response.body)
    
    # Verify journey was created with template steps
    get api_v1_journey_path(journey_data['data']['id']), as: :json
    assert_response :success
    
    journey_details = JSON.parse(response.body)
    assert_equal 2, journey_details['data']['steps'].length
    assert_equal "Welcome Email", journey_details['data']['steps'].first['name']
  end

  test "A/B testing workflow" do
    # Step 1: Create base journey
    journey = create(:journey, user: @user, campaign: @campaign)
    
    # Step 2: Create A/B test
    post api_v1_journey_ab_tests_path(journey.id),
      params: {
        ab_test: {
          name: "Subject Line Test",
          description: "Testing different subject lines for welcome email",
          hypothesis: "Personalized subject lines will increase open rates",
          test_type: "conversion",
          confidence_level: 95.0
        }
      },
      as: :json
    
    assert_response :created
    ab_test_data = JSON.parse(response.body)
    ab_test_id = ab_test_data['data']['id']
    
    # Step 3: Create variants
    post api_v1_ab_test_ab_test_variants_path(ab_test_id),
      params: {
        ab_test_variant: {
          name: "Control",
          is_control: true,
          traffic_percentage: 50.0,
          configuration: {
            subject_line: "Welcome to our service"
          }
        }
      },
      as: :json
    
    assert_response :created
    
    post api_v1_ab_test_ab_test_variants_path(ab_test_id),
      params: {
        ab_test_variant: {
          name: "Personalized",
          is_control: false,
          traffic_percentage: 50.0,
          configuration: {
            subject_line: "{{first_name}}, welcome to our service!"
          }
        }
      },
      as: :json
    
    assert_response :created
    
    # Step 4: Start A/B test
    post start_api_v1_ab_test_path(ab_test_id), as: :json
    assert_response :success
    
    test_status_data = JSON.parse(response.body)
    assert_equal 'running', test_status_data['data']['status']
    
    # Step 5: Check A/B test results
    get results_api_v1_ab_test_path(ab_test_id), as: :json
    assert_response :success
    
    results_data = JSON.parse(response.body)
    assert results_data['data']['variants'].is_a?(Array)
    assert_equal 2, results_data['data']['variants'].length
  end

  test "analytics and reporting workflow" do
    # Create journey with some execution data
    journey = create(:journey, user: @user, campaign: @campaign)
    
    # Create analytics data
    create(:journey_analytics,
      journey: journey,
      campaign: @campaign,
      user: @user,
      total_executions: 1000,
      completed_executions: 750,
      abandoned_executions: 100,
      conversion_rate: 75.0,
      engagement_score: 85.0
    )
    
    # Test analytics dashboard
    get analytics_api_v1_journey_path(journey.id), as: :json
    assert_response :success
    
    analytics_data = JSON.parse(response.body)
    assert analytics_data['data']['summary']
    assert_equal 1000, analytics_data['data']['summary']['total_executions']
    assert_equal 750, analytics_data['data']['summary']['completed_executions']
    
    # Test funnel analysis
    get funnel_api_v1_journey_path(journey.id), as: :json
    assert_response :success
    
    funnel_data = JSON.parse(response.body)
    assert funnel_data['data']['funnel_steps'].is_a?(Array)
    
    # Test comparison with other journeys
    other_journey = create(:journey, user: @user, campaign: @campaign, name: "Comparison Journey")
    
    get compare_api_v1_journey_path(journey.id),
      params: { compare_with: other_journey.id },
      as: :json
    
    assert_response :success
    comparison_data = JSON.parse(response.body)
    assert comparison_data['data']['comparison']
  end

  test "error handling and validation workflow" do
    # Test creating journey with invalid data
    post api_v1_journeys_path,
      params: {
        journey: {
          name: "", # Invalid: empty name
          campaign_type: "invalid_type" # Invalid: not in allowed types
        }
      },
      as: :json
    
    assert_response :unprocessable_entity
    error_data = JSON.parse(response.body)
    assert_equal false, error_data['success']
    assert error_data['errors']
    
    # Test accessing non-existent journey
    get api_v1_journey_path(99999), as: :json
    assert_response :not_found
    
    # Test unauthorized access
    sign_out
    get api_v1_journeys_path, as: :json
    assert_response :unauthorized
  end

  private

  def sign_in_as(user)
    post new_session_path, params: { 
      email_address: user.email_address, 
      password: "password123" 
    }
  end

  def sign_out
    delete session_path if session_path.present?
  rescue
    # Handle case where no session exists
  end
end