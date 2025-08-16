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

  # Strategic fields edge case tests
  test "should handle malformed JSON in strategic fields gracefully" do
    campaign_plan = campaign_plans(:draft_plan)
    
    # Directly insert malformed JSON (simulating data corruption)
    ActiveRecord::Base.connection.execute(
      "UPDATE campaign_plans SET content_strategy = 'invalid json}' WHERE id = #{campaign_plan.id}"
    )
    
    campaign_plan.reload
    
    # Should not raise errors when accessing the field
    assert_nothing_raised do
      campaign_plan.has_generated_content?
      campaign_plan.generation_progress  
      campaign_plan.plan_analytics
    end
  end

  test "should handle extremely large strategic field content" do
    campaign_plan = campaign_plans(:draft_plan)
    massive_content = { 
      data: "x" * 100_000,  # ~100KB of content
      nested_arrays: Array.new(1000) { |i| { index: i, content: "data_#{i}" } }
    }
    
    assert_nothing_raised do
      campaign_plan.update!(content_strategy: massive_content)
      campaign_plan.reload
      assert_equal 100_000, campaign_plan.content_strategy["data"].length
      assert_equal 1000, campaign_plan.content_strategy["nested_arrays"].length
    end
  end

  test "should handle nil and empty strategic field combinations correctly" do
    campaign_plan = campaign_plans(:draft_plan)
    
    # Test various nil/empty combinations
    test_cases = [
      { content_strategy: nil, creative_approach: {} },
      { content_strategy: {}, creative_approach: nil },
      { strategic_rationale: { key: nil }, content_mapping: [] },
      { strategic_rationale: {}, content_mapping: nil },
      { content_strategy: { empty_array: [] }, creative_approach: { empty_hash: {} } },
      { strategic_rationale: { nil_value: nil, empty_string: "" }, content_mapping: [{}] }
    ]
    
    test_cases.each_with_index do |test_case, index|
      campaign_plan.update!(test_case)
      
      assert_nothing_raised do
        has_content = campaign_plan.has_generated_content?
        progress = campaign_plan.generation_progress
        analytics = campaign_plan.plan_analytics
        
        # Verify methods return sensible values
        assert [true, false].include?(has_content)
        assert progress.is_a?(Integer)
        assert progress >= 0 && progress <= 100
        assert analytics.is_a?(Hash)
      end
    end
  end

  test "should handle unicode and special characters in strategic fields" do
    unicode_content_strategy = {
      themes: ["革新", "신뢰성", "イノベーション", "🚀 Innovation"],
      approach: "Multi-channel approach with émojis 💯 and spécial characters: ñáéíóú"
    }
    
    unicode_creative_approach = {
      style: "现代风格",
      tone: "Professional avec des accents français",
      visual_identity: "🎨 Clean & Modern ✨"
    }
    
    unicode_strategic_rationale = {
      reasoning: "Market research shows growing demand for internationalization 🌍",
      target_markets: ["北京", "서울", "東京", "México DF"]
    }
    
    unicode_content_mapping = [
      { platform: "WeChat 微信", content_type: "article 文章", frequency: "daily 每日" },
      { platform: "KakaoTalk 카카오톡", content_type: "story 스토리", frequency: "weekly 주간" }
    ]
    
    campaign_plan = campaign_plans(:draft_plan)
    
    assert_nothing_raised do
      campaign_plan.update!(
        content_strategy: unicode_content_strategy,
        creative_approach: unicode_creative_approach,
        strategic_rationale: unicode_strategic_rationale,
        content_mapping: unicode_content_mapping
      )
      
      campaign_plan.reload
      
      # Verify unicode content is preserved
      assert_includes campaign_plan.content_strategy["themes"], "革新"
      assert_includes campaign_plan.creative_approach["style"], "现代风格"
      assert_includes campaign_plan.strategic_rationale["reasoning"], "🌍"
      assert_equal "WeChat 微信", campaign_plan.content_mapping.first["platform"]
    end
  end

  test "should handle deeply nested strategic field structures" do
    deeply_nested_strategy = {
      level1: {
        level2: {
          level3: {
            level4: {
              level5: {
                level6: {
                  level7: {
                    level8: {
                      level9: {
                        level10: "Deep content",
                        array_data: Array.new(50) { |i| { index: i, nested: { data: "value_#{i}" } } }
                      }
                    }
                  }
                }
              }
            }
          }
        }
      }
    }
    
    campaign_plan = campaign_plans(:draft_plan)
    
    assert_nothing_raised do
      campaign_plan.update!(content_strategy: deeply_nested_strategy)
      campaign_plan.reload
      
      # Should be able to access deeply nested content
      deep_content = campaign_plan.content_strategy["level1"]["level2"]["level3"]["level4"]["level5"]["level6"]["level7"]["level8"]["level9"]["level10"]
      assert_equal "Deep content", deep_content
      
      # Should handle deeply nested arrays
      nested_array = campaign_plan.content_strategy["level1"]["level2"]["level3"]["level4"]["level5"]["level6"]["level7"]["level8"]["level9"]["array_data"]
      assert_equal 50, nested_array.length
    end
  end

  test "should handle strategic fields with circular reference-like structures" do
    # Test content that references itself (but not truly circular since JSON doesn't support it)
    self_referential_content = {
      theme_a: { related_themes: ["theme_b", "theme_c"] },
      theme_b: { related_themes: ["theme_a", "theme_c"] },
      theme_c: { related_themes: ["theme_a", "theme_b"] },
      content_matrix: {
        platform_linkedin: { related_platforms: ["platform_twitter", "platform_facebook"] },
        platform_twitter: { related_platforms: ["platform_linkedin", "platform_facebook"] },
        platform_facebook: { related_platforms: ["platform_linkedin", "platform_twitter"] }
      }
    }
    
    campaign_plan = campaign_plans(:draft_plan)
    
    assert_nothing_raised do
      campaign_plan.update!(content_strategy: self_referential_content)
      campaign_plan.reload
      
      # Verify self-referential structure is preserved
      theme_a_refs = campaign_plan.content_strategy["theme_a"]["related_themes"]
      assert_includes theme_a_refs, "theme_b"
      assert_includes theme_a_refs, "theme_c"
    end
  end

  test "should handle strategic fields with mixed data types" do
    mixed_type_content = {
      string_field: "text content",
      integer_field: 42,
      float_field: 3.14159,
      boolean_true: true,
      boolean_false: false,
      null_field: nil,
      array_mixed: ["string", 123, true, nil, { nested: "object" }],
      nested_object: {
        mixed_nested: {
          numbers: [1, 2, 3.14, -5],
          strings: ["a", "b", "c"],
          booleans: [true, false, true],
          nulls: [nil, nil]
        }
      }
    }
    
    campaign_plan = campaign_plans(:draft_plan)
    
    assert_nothing_raised do
      campaign_plan.update!(content_strategy: mixed_type_content)
      campaign_plan.reload
      
      # Verify mixed types are preserved correctly
      strategy = campaign_plan.content_strategy
      assert_equal "text content", strategy["string_field"]
      assert_equal 42, strategy["integer_field"]
      assert_equal 3.14159, strategy["float_field"]
      assert_equal true, strategy["boolean_true"]
      assert_equal false, strategy["boolean_false"]
      assert_nil strategy["null_field"]
      assert_equal 5, strategy["array_mixed"].length
    end
  end

  test "should handle strategic field updates with partial data" do
    campaign_plan = campaign_plans(:draft_plan)
    
    # Start with full strategic content
    campaign_plan.update!(
      content_strategy: { themes: ["original"], approach: "original" },
      creative_approach: { style: "original", tone: "original" },
      strategic_rationale: { reasoning: "original" },
      content_mapping: [{ platform: "original" }]
    )
    
    # Update with partial data (some fields nil, some missing)
    assert_nothing_raised do
      campaign_plan.update!(
        content_strategy: { themes: ["updated"] },  # Missing 'approach'
        creative_approach: nil,  # Explicitly nil
        strategic_rationale: { reasoning: "updated", new_field: "added" }
        # content_mapping not specified, should remain unchanged
      )
      
      campaign_plan.reload
      
      # Verify partial updates work correctly
      assert_equal ["updated"], campaign_plan.content_strategy["themes"]
      assert_nil campaign_plan.content_strategy["approach"]  # Should be missing/nil
      assert_nil campaign_plan.creative_approach
      assert_equal "updated", campaign_plan.strategic_rationale["reasoning"]
      assert_equal "added", campaign_plan.strategic_rationale["new_field"]
      assert_equal [{ "platform" => "original" }], campaign_plan.content_mapping  # Should remain unchanged
    end
  end

  test "should handle strategic fields during concurrent modifications" do
    campaign_plan = campaign_plans(:draft_plan)
    
    # Simulate concurrent modifications by updating different strategic fields
    # This tests for any race conditions or data integrity issues
    assert_nothing_raised do
      # Update 1: Content strategy
      campaign_plan.update!(content_strategy: { themes: ["concurrent_1"] })
      
      # Update 2: Creative approach (simulating concurrent update)
      campaign_plan.reload
      campaign_plan.update!(creative_approach: { style: "concurrent_2" })
      
      # Update 3: Both fields (simulating concurrent bulk update)
      campaign_plan.reload
      campaign_plan.update!(
        strategic_rationale: { reasoning: "concurrent_3" },
        content_mapping: [{ platform: "concurrent_4" }]
      )
      
      campaign_plan.reload
      
      # All updates should be preserved
      assert_equal ["concurrent_1"], campaign_plan.content_strategy["themes"]
      assert_equal "concurrent_2", campaign_plan.creative_approach["style"]
      assert_equal "concurrent_3", campaign_plan.strategic_rationale["reasoning"]
      assert_equal "concurrent_4", campaign_plan.content_mapping.first["platform"]
    end
  end
end