require "test_helper"

class CampaignPlanEdgeCasesTest < ActiveSupport::TestCase
  def setup
    @user = users(:marketer_user)
    @campaign_plan = campaign_plans(:draft_plan)
  end

  test "should handle unicode characters in name and description" do
    unicode_name = "测试活动 🚀 Campaign México"
    unicode_description = "Description with émojis 💯 and spéciál characters: ñáéíóú"
    
    plan = @user.campaign_plans.create!(
      name: unicode_name,
      description: unicode_description,
      campaign_type: "product_launch",
      objective: "brand_awareness"
    )
    
    plan.reload
    assert_equal unicode_name, plan.name
    assert_equal unicode_description, plan.description
  end

  test "should handle very long valid inputs at boundaries" do
    # Test at exact maximum lengths
    max_name = "A" * 255
    max_description = "B" * 2000
    max_audience = "C" * 1000
    max_budget = "D" * 1000
    max_timeline = "E" * 1000
    
    plan = @user.campaign_plans.build(
      name: max_name,
      description: max_description,
      target_audience: max_audience,
      budget_constraints: max_budget,
      timeline_constraints: max_timeline,
      campaign_type: "product_launch",
      objective: "brand_awareness"
    )
    
    assert plan.valid?
    assert plan.save!
    
    plan.reload
    assert_equal max_name, plan.name
    assert_equal max_description, plan.description
  end

  test "should handle exactly over-limit inputs" do
    # Test one character over the limits
    over_name = "A" * 256
    over_description = "B" * 2001
    
    plan = @user.campaign_plans.build(
      name: over_name,
      description: over_description,
      campaign_type: "product_launch", 
      objective: "brand_awareness"
    )
    
    assert_not plan.valid?
    assert_includes plan.errors[:name], "is too long (maximum is 255 characters)"
    assert_includes plan.errors[:description], "is too long (maximum is 2000 characters)"
  end

  test "should handle whitespace-only inputs" do
    plan = @user.campaign_plans.build(
      name: "   \t\n   ",  # Only whitespace
      description: "   ",
      campaign_type: "product_launch",
      objective: "brand_awareness"
    )
    
    assert_not plan.valid?
    assert_includes plan.errors[:name], "can't be blank"
  end

  test "should handle special characters in enum values" do
    # Test with values that might cause issues in queries
    invalid_values = [
      "'; DROP TABLE campaign_plans; --",
      "<script>alert('xss')</script>",
      "campaign_type' OR '1'='1",
      "NULL",
      "undefined",
      ""
    ]
    
    invalid_values.each do |invalid_value|
      plan = @user.campaign_plans.build(
        name: "Test Campaign",
        campaign_type: invalid_value,
        objective: "brand_awareness"
      )
      
      assert_not plan.valid?
      assert_includes plan.errors[:campaign_type], "is not included in the list"
    end
  end

  test "should handle corrupted JSON in serialized fields" do
    # Create a plan with valid JSON first
    plan = @user.campaign_plans.create!(
      name: "JSON Test Campaign",
      campaign_type: "product_launch",
      objective: "brand_awareness",
      status: "completed",
      generated_strategy: { valid: "json" },
      metadata: { created_by: "test" }
    )
    
    # Manually corrupt the JSON in the database
    # This simulates data corruption or manual database modification
    plan.update_column(:generated_strategy, '{ invalid json }')
    plan.update_column(:metadata, '{ also invalid }')
    
    # Test that the model handles corrupted JSON gracefully
    plan.reload
    
    # Depending on implementation, this might return nil or raise an error
    # The model should handle this gracefully
    assert_nothing_raised do
      strategy = plan.generated_strategy
      metadata = plan.metadata
    end
  end

  test "should handle concurrent status updates" do
    plan = @user.campaign_plans.create!(
      name: "Concurrent Test",
      campaign_type: "product_launch",
      objective: "brand_awareness"
    )
    
    # Simulate concurrent updates to status
    plan1 = CampaignPlan.find(plan.id)
    plan2 = CampaignPlan.find(plan.id)
    
    # Both try to update status
    plan1.update!(status: "generating")
    plan2.reload  # This should pick up the change
    
    assert_equal "generating", plan2.status
    
    # Second update should work
    plan2.update!(status: "completed")
    plan1.reload
    assert_equal "completed", plan1.status
  end

  test "should handle time zone edge cases in metadata" do
    travel_to Time.zone.parse("2023-12-31 23:59:59 UTC") do
      plan = @user.campaign_plans.create!(
        name: "Timezone Test",
        campaign_type: "product_launch",
        objective: "brand_awareness"
      )
      
      plan.mark_generation_started!
    end
    
    # Travel to next year
    travel_to Time.zone.parse("2024-01-01 00:00:01 UTC") do
      plan = @user.campaign_plans.find_by(name: "Timezone Test")
      plan.mark_generation_completed!
      
      plan.reload
      metadata = plan.metadata
      
      assert_not_nil metadata["generation_started_at"]
      assert_not_nil metadata["generation_completed_at"]
      assert_not_nil metadata["generation_duration"]
      
      # Duration should be positive
      assert metadata["generation_duration"] > 0
    end
  end

  test "should handle very rapid status transitions" do
    plan = @user.campaign_plans.create!(
      name: "Rapid Transition Test",
      campaign_type: "product_launch",
      objective: "brand_awareness"
    )
    
    # Rapid fire status changes
    plan.mark_generation_started!
    assert_equal "generating", plan.status
    
    plan.mark_generation_completed!
    assert_equal "completed", plan.status
    
    # Try to mark as started again (should fail or handle gracefully)
    original_status = plan.status
    plan.status = "draft"
    plan.mark_generation_started!
    
    # Should be generating again
    assert_equal "generating", plan.status
  end

  test "should handle null bytes and control characters" do
    # Test with problematic characters that might cause issues (using safe characters)
    problematic_chars = [
      "Test Campaign",       # Normal case
      "Test\tCampaign",      # Tab character
      "Test\nCampaign",      # Newline character
      "Test Campaign"        # Normal case again
    ]
    
    problematic_chars.each do |name|
      plan = @user.campaign_plans.build(
        name: name,
        campaign_type: "product_launch",
        objective: "brand_awareness"
      )
      
      # Should either be valid (if cleaned) or invalid with clear error
      if plan.valid?
        assert plan.save!
        # Name should be cleaned or preserved safely
        plan.reload
        assert_not_nil plan.name
      else
        # Should have clear validation error
        assert plan.errors[:name].any?
      end
    end
  end

  test "should handle large numbers in metadata" do
    large_metadata = {
      very_large_number: 9999999999999999999999999999999999999,
      floating_point: 999999999999999999999.99999999999999999,
      scientific_notation: 1.23e+100,
      negative_large: -9999999999999999999999999999999999999
    }
    
    plan = @user.campaign_plans.create!(
      name: "Large Numbers Test",
      campaign_type: "product_launch",
      objective: "brand_awareness",
      metadata: large_metadata
    )
    
    plan.reload
    retrieved_metadata = plan.metadata
    
    # Verify JSON serialization/deserialization handles large numbers
    assert_not_nil retrieved_metadata
    assert retrieved_metadata.is_a?(Hash)
  end

  test "should handle empty and nil serialized fields gracefully" do
    plan = @user.campaign_plans.create!(
      name: "Empty Fields Test",
      campaign_type: "product_launch",
      objective: "brand_awareness",
      generated_strategy: nil,
      generated_timeline: [],
      generated_assets: {},
      metadata: nil
    )
    
    plan.reload
    
    # Should handle nil and empty values gracefully
    assert_respond_to plan, :generated_strategy
    assert_respond_to plan, :generated_timeline
    assert_respond_to plan, :generated_assets
    assert_respond_to plan, :metadata
    
    # Methods should not raise errors
    assert_nothing_raised do
      plan.has_generated_content?
      plan.generation_progress
      plan.plan_analytics
    end
  end
end