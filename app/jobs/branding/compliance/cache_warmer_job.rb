module Branding
  module Compliance
    class CacheWarmerJob < ApplicationJob
      queue_as :low

      def perform(brand_id)
        brand = Brand.find(brand_id)
        CacheService.preload_brand_cache(brand)
      end
    end
  end
end