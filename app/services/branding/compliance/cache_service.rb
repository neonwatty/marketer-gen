module Branding
  module Compliance
    class CacheService
      DEFAULT_EXPIRATION = 1.hour
      RULE_EXPIRATION = 6.hours
      RESULT_EXPIRATION = 30.minutes
      
      class << self
        def cache_store
          Rails.cache
        end

        # Rule caching methods
        def cache_rules(brand_id, rules, category = nil)
          key = rule_cache_key(brand_id, category)
          cache_store.write(key, rules, expires_in: RULE_EXPIRATION)
        end

        def get_cached_rules(brand_id, category = nil)
          key = rule_cache_key(brand_id, category)
          cache_store.read(key)
        end

        def invalidate_rules(brand_id)
          pattern = rule_cache_pattern(brand_id)
          delete_matching(pattern)
        end

        # Result caching methods
        def cache_validation_result(brand_id, content_hash, validator_type, result)
          key = result_cache_key(brand_id, content_hash, validator_type)
          cache_store.write(key, result, expires_in: RESULT_EXPIRATION)
        end

        def get_cached_validation_result(brand_id, content_hash, validator_type)
          key = result_cache_key(brand_id, content_hash, validator_type)
          cache_store.read(key)
        end

        # Analysis caching methods
        def cache_analysis(brand_id, content_hash, analysis_type, data)
          key = analysis_cache_key(brand_id, content_hash, analysis_type)
          expiration = analysis_expiration(analysis_type)
          cache_store.write(key, data, expires_in: expiration)
        end

        def get_cached_analysis(brand_id, content_hash, analysis_type)
          key = analysis_cache_key(brand_id, content_hash, analysis_type)
          cache_store.read(key)
        end

        # Suggestion caching methods
        def cache_suggestions(brand_id, violation_hash, suggestions)
          key = suggestion_cache_key(brand_id, violation_hash)
          cache_store.write(key, suggestions, expires_in: DEFAULT_EXPIRATION)
        end

        def get_cached_suggestions(brand_id, violation_hash)
          key = suggestion_cache_key(brand_id, violation_hash)
          cache_store.read(key)
        end

        # Batch operations
        def preload_brand_cache(brand)
          # Preload frequently accessed data
          preload_rules(brand)
          preload_guidelines(brand)
          preload_analysis_data(brand)
        end

        def clear_brand_cache(brand_id)
          patterns = [
            rule_cache_pattern(brand_id),
            result_cache_pattern(brand_id),
            analysis_cache_pattern(brand_id),
            suggestion_cache_pattern(brand_id)
          ]
          
          patterns.each { |pattern| delete_matching(pattern) }
        end

        # Statistics and monitoring
        def cache_statistics(brand_id)
          {
            rules_cached: count_matching(rule_cache_pattern(brand_id)),
            results_cached: count_matching(result_cache_pattern(brand_id)),
            analyses_cached: count_matching(analysis_cache_pattern(brand_id)),
            suggestions_cached: count_matching(suggestion_cache_pattern(brand_id)),
            total_size: estimate_cache_size(brand_id)
          }
        end

        private

        def rule_cache_key(brand_id, category = nil)
          parts = ["compliance", "rules", brand_id]
          parts << category if category
          parts.join(":")
        end

        def rule_cache_pattern(brand_id)
          "compliance:rules:#{brand_id}:*"
        end

        def result_cache_key(brand_id, content_hash, validator_type)
          ["compliance", "result", brand_id, content_hash, validator_type].join(":")
        end

        def result_cache_pattern(brand_id)
          "compliance:result:#{brand_id}:*"
        end

        def analysis_cache_key(brand_id, content_hash, analysis_type)
          ["compliance", "analysis", brand_id, content_hash, analysis_type].join(":")
        end

        def analysis_cache_pattern(brand_id)
          "compliance:analysis:#{brand_id}:*"
        end

        def suggestion_cache_key(brand_id, violation_hash)
          ["compliance", "suggestions", brand_id, violation_hash].join(":")
        end

        def suggestion_cache_pattern(brand_id)
          "compliance:suggestions:#{brand_id}:*"
        end

        def analysis_expiration(analysis_type)
          case analysis_type.to_s
          when "tone", "sentiment"
            2.hours # These change less frequently
          when "readability", "keyword_density"
            1.hour
          else
            DEFAULT_EXPIRATION
          end
        end

        def delete_matching(pattern)
          if cache_store.respond_to?(:delete_matched)
            cache_store.delete_matched(pattern)
          else
            # Fallback for cache stores that don't support pattern deletion
            Rails.logger.warn "Cache store doesn't support delete_matched"
          end
        end

        def count_matching(pattern)
          if cache_store.respond_to?(:keys)
            cache_store.keys(pattern).count
          else
            0
          end
        end

        def estimate_cache_size(brand_id)
          # This is an estimate - actual implementation depends on cache store
          patterns = [
            rule_cache_pattern(brand_id),
            result_cache_pattern(brand_id),
            analysis_cache_pattern(brand_id),
            suggestion_cache_pattern(brand_id)
          ]
          
          total_keys = patterns.sum { |pattern| count_matching(pattern) }
          # Estimate 1KB average per cached item
          "~#{total_keys}KB"
        end

        def preload_rules(brand)
          # Load and cache all active rules
          rule_engine = RuleEngine.new(brand)
          categories = %w[content style visual messaging legal]
          
          categories.each do |category|
            rules = rule_engine.get_rules_for_category(category)
            cache_rules(brand.id, rules, category) if rules.any?
          end
        end

        def preload_guidelines(brand)
          # Cache frequently accessed guidelines
          guidelines_by_category = brand.brand_guidelines.active.group_by(&:category)
          
          guidelines_by_category.each do |category, guidelines|
            key = ["compliance", "guidelines", brand.id, category].join(":")
            cache_store.write(key, guidelines.map(&:attributes), expires_in: RULE_EXPIRATION)
          end
        end

        def preload_analysis_data(brand)
          # Cache brand analysis data
          if latest_analysis = brand.latest_analysis
            key = ["compliance", "brand_analysis", brand.id].join(":")
            cache_store.write(key, {
              voice_attributes: latest_analysis.voice_attributes,
              sentiment_profile: latest_analysis.sentiment_profile,
              keywords: latest_analysis.keywords,
              emotional_targets: latest_analysis.emotional_targets
            }, expires_in: 6.hours)
          end
        end
      end

      # Instance methods for request-scoped caching
      def initialize
        @request_cache = {}
      end

      def fetch(key, &block)
        @request_cache[key] ||= block.call
      end

      def clear
        @request_cache.clear
      end
    end

    # Cache warming job
    class CacheWarmerJob < ApplicationJob
      queue_as :low

      def perform(brand_id)
        brand = Brand.find(brand_id)
        CacheService.preload_brand_cache(brand)
      end
    end

    # Cache invalidation concern
    module CacheInvalidation
      extend ActiveSupport::Concern

      included do
        after_commit :invalidate_compliance_cache, on: [:create, :update, :destroy]
      end

      private

      def invalidate_compliance_cache
        brand_id = case self
                   when Brand then id
                   when BrandGuideline, BrandAnalysis then brand_id
                   else return
                   end

        CacheService.invalidate_rules(brand_id)
        
        # Queue cache warming to rebuild cache
        CacheWarmerJob.perform_later(brand_id)
      end
    end
  end
end