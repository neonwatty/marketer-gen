module Branding
  module Compliance
    module CacheInvalidation
      extend ActiveSupport::Concern

      included do
        after_commit :invalidate_compliance_cache, on: [:create, :update, :destroy]
      end

      private

      def invalidate_compliance_cache
        # Skip cache invalidation in test environment to avoid job issues
        return if Rails.env.test?
        
        brand_id = case self
                   when Brand then id
                   when BrandGuideline, BrandAnalysis then brand_id
                   else return
                   end

        # Use the CacheService to invalidate rules
        Branding::Compliance::CacheService.invalidate_rules(brand_id)
        
        # Queue cache warming to rebuild cache
        Branding::Compliance::CacheWarmerJob.perform_later(brand_id)
      end
    end
  end
end