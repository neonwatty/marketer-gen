# Example usage of the enhanced Brand Compliance Validation Service

module Branding
  class ComplianceUsageExample
    def self.demonstrate
      # 1. Basic compliance check
      brand = Brand.first
      content = "Check out our amazing new product! It's the best solution for your needs."
      
      service = ComplianceServiceV2.new(brand, content, "marketing_copy")
      results = service.check_compliance
      
      puts "=== Basic Compliance Check ==="
      puts "Compliant: #{results[:compliant]}"
      puts "Score: #{results[:score]}"
      puts "Summary: #{results[:summary]}"
      puts "Violations: #{results[:violations].count}"
      puts "Suggestions: #{results[:suggestions].count}"
      puts
      
      # 2. Check specific aspects
      puts "=== Specific Aspect Validation ==="
      aspect_results = service.check_specific_aspects([:tone, :readability])
      aspect_results.each do |aspect, result|
        puts "#{aspect}: #{result[:violations].count} violations"
      end
      puts
      
      # 3. Auto-fix violations
      puts "=== Auto-Fix Violations ==="
      fix_results = service.validate_and_fix
      if fix_results[:fixes_applied]
        puts "Original compliant: #{fix_results[:original_results][:compliant]}"
        puts "Fixes applied: #{fix_results[:fixes_applied].count}"
        puts "Final compliant: #{fix_results[:final_results][:compliant]}"
        puts "Fixed content preview: #{fix_results[:fixed_content][0..100]}..."
      end
      puts
      
      # 4. Visual content compliance
      puts "=== Visual Content Compliance ==="
      visual_data = {
        colors: {
          primary: ["#1E40AF", "#3B82F6"],
          secondary: ["#10B981", "#34D399"]
        },
        typography: {
          fonts: ["Inter", "Roboto"],
          legibility_score: 0.85
        },
        logo: {
          size: 150,
          placement: "top-left",
          clear_space_ratio: 0.6
        },
        quality: {
          resolution: 72,
          file_size: 250_000,
          dimensions: { width: 1200, height: 600 }
        }
      }
      
      visual_service = ComplianceServiceV2.new(
        brand, 
        "Visual content description", 
        "image",
        { visual_data: visual_data }
      )
      visual_results = visual_service.check_compliance
      puts "Visual compliance score: #{visual_results[:score]}"
      puts
      
      # 5. Async processing for large content
      puts "=== Async Processing ==="
      large_content = "Large content " * 1000 # Simulating large content
      
      job = BrandComplianceJob.perform_later(
        brand.id,
        large_content,
        "article",
        {
          user_id: brand.user_id,
          broadcast_events: true,
          store_results: true
        }
      )
      puts "Job queued with ID: #{job.job_id}"
      puts
      
      # 6. Using the API endpoint
      puts "=== API Usage Example ==="
      puts <<~CURL
        # Check compliance via API
        curl -X POST http://localhost:3000/api/v1/brands/#{brand.id}/compliance/check \\
          -H "Content-Type: application/json" \\
          -H "Authorization: Bearer YOUR_TOKEN" \\
          -d '{
            "content": "Your content here",
            "content_type": "social_media",
            "compliance_level": "strict",
            "channel": "twitter",
            "audience": "b2b_professionals"
          }'
        
        # Validate specific aspect
        curl -X POST http://localhost:3000/api/v1/brands/#{brand.id}/compliance/validate_aspect \\
          -H "Content-Type: application/json" \\
          -H "Authorization: Bearer YOUR_TOKEN" \\
          -d '{
            "aspect": "tone",
            "content": "Your content here"
          }'
        
        # Preview fix for violation
        curl -X POST http://localhost:3000/api/v1/brands/#{brand.id}/compliance/preview_fix \\
          -H "Content-Type: application/json" \\
          -H "Authorization: Bearer YOUR_TOKEN" \\
          -d '{
            "violation": {
              "id": "tone_1",
              "type": "tone_mismatch",
              "severity": "medium",
              "details": {
                "expected": "professional",
                "detected": "casual"
              }
            },
            "content": "Your content here"
          }'
      CURL
      
      # 7. Real-time updates via ActionCable
      puts "\n=== ActionCable Subscription Example ==="
      puts <<~JS
        // JavaScript client code
        const cable = ActionCable.createConsumer('ws://localhost:3000/cable');
        
        const complianceChannel = cable.subscriptions.create(
          {
            channel: 'BrandComplianceChannel',
            brand_id: #{brand.id},
            session_id: 'unique-session-id'
          },
          {
            connected() {
              console.log('Connected to compliance channel');
              
              // Request compliance check
              this.perform('check_compliance', {
                content: 'Content to check',
                content_type: 'email',
                async: true
              });
            },
            
            received(data) {
              switch(data.event) {
                case 'validation_started':
                  console.log('Validation started:', data);
                  break;
                case 'violation_detected':
                  console.log('Violation found:', data.violation);
                  break;
                case 'validation_complete':
                  console.log('Validation complete:', data);
                  break;
              }
            }
          }
        );
      JS
      
      # 8. Caching and performance
      puts "\n=== Cache Management ==="
      cache_stats = Branding::Compliance::CacheService.cache_statistics(brand.id)
      puts "Cache statistics: #{cache_stats}"
      
      # Warm cache for better performance
      Branding::Compliance::CacheWarmerJob.perform_later(brand.id)
      puts "Cache warming job queued"
      
      # 9. Compliance history and analytics
      puts "\n=== Compliance Analytics ==="
      recent_results = brand.compliance_results.recent.limit(10)
      puts "Recent checks: #{recent_results.count}"
      puts "Average score: #{brand.compliance_results.average_score}"
      puts "Compliance rate: #{brand.compliance_results.compliance_rate}%"
      puts "Common violations: #{brand.compliance_results.common_violations(3)}"
      
    rescue => e
      puts "Error: #{e.message}"
      puts e.backtrace.first(5)
    end
    
    # Advanced configuration example
    def self.configure_compliance_service
      # Configure global settings
      Branding::ComplianceServiceV2.configure do |config|
        config.cache_store = Rails.cache
        config.broadcast_violations = true
        config.async_processing = true
        config.max_processing_time = 60.seconds
      end
    end
      
  end

  # Custom validator example
  class CustomIndustryValidator < Branding::Compliance::BaseValidator
    def validate
      # Custom industry-specific validation logic
      if brand.industry == "healthcare" && content.match?(/medical claim/i)
        add_violation(
          type: "unverified_medical_claim",
          severity: "high",
          message: "Medical claims must be verified and include disclaimers"
        )
      end
      
      { violations: @violations, suggestions: @suggestions }
    end
  end
end

# To run the demonstration:
# rails runner "Branding::ComplianceUsageExample.demonstrate"