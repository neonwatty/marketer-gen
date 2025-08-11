require "test_helper"

class AiResponseCacheTest < ActiveSupport::TestCase
  class TestService < AiServiceBase
    include AiResponseCache

    def initialize(attributes = {})
      super(attributes.merge(
        provider_name: "test_provider",
        model_name: "test_model",
        cache_enabled: true,
        cache_ttl_seconds: 3600
      ))
    end
  end

  setup do
    @service = TestService.new
    Rails.cache.clear
  end

  test "caches and retrieves responses correctly" do
    prompt = "Generate a marketing plan"
    response = "Here is a comprehensive marketing plan..."
    
    # Should return nil for cache miss
    cached = @service.get_cached_response(prompt)
    assert_nil cached

    # Cache the response
    cached_response = @service.cache_response(prompt, response)
    assert_equal response, cached_response

    # Should now return cached response
    cached = @service.get_cached_response(prompt)
    assert cached[:cached]
    assert_equal response, cached[:response]
    assert cached[:cached_at]
    assert cached[:tokens_saved]
  end

  test "generates consistent cache keys for same prompt" do
    prompt = "Test prompt"
    options = { temperature: 0.5, max_tokens: 1000 }

    key1 = @service.send(:generate_cache_key, prompt, options)
    key2 = @service.send(:generate_cache_key, prompt, options)

    assert_equal key1, key2
  end

  test "generates different cache keys for different prompts" do
    prompt1 = "Test prompt 1"
    prompt2 = "Test prompt 2"
    options = { temperature: 0.5 }

    key1 = @service.send(:generate_cache_key, prompt1, options)
    key2 = @service.send(:generate_cache_key, prompt2, options)

    assert_not_equal key1, key2
  end

  test "generates different cache keys for different options" do
    prompt = "Test prompt"
    options1 = { temperature: 0.5 }
    options2 = { temperature: 0.7 }

    key1 = @service.send(:generate_cache_key, prompt, options1)
    key2 = @service.send(:generate_cache_key, prompt, options2)

    assert_not_equal key1, key2
  end

  test "cache statistics track hits and misses" do
    prompt = "Test prompt"
    response = "Test response"

    # Initial stats
    initial_stats = @service.cache_statistics
    assert initial_stats[:enabled]
    assert_equal 0, initial_stats[:hits]
    assert_equal 0, initial_stats[:misses]

    # Cache miss should increment misses
    @service.get_cached_response(prompt)
    stats_after_miss = @service.cache_statistics
    assert_equal 1, stats_after_miss[:misses]
    assert_equal 0, stats_after_miss[:hits]

    # Cache the response
    @service.cache_response(prompt, response)

    # Cache hit should increment hits
    @service.get_cached_response(prompt)
    stats_after_hit = @service.cache_statistics
    assert_equal 1, stats_after_hit[:misses]
    assert_equal 1, stats_after_hit[:hits]
    assert_equal 50.0, stats_after_hit[:hit_rate]
  end

  test "caching can be disabled" do
    service = TestService.new
    service.cache_enabled = false
    prompt = "Test prompt"
    response = "Test response"

    # Should not cache when disabled
    cached_response = service.cache_response(prompt, response)
    assert_equal response, cached_response

    # Should not return cached response
    cached = service.get_cached_response(prompt)
    assert_nil cached

    # Statistics should show disabled
    stats = service.cache_statistics
    assert_not stats[:enabled]
  end

  test "cache TTL is respected" do
    short_ttl_service = TestService.new
    short_ttl_service.cache_ttl_seconds = 1
    prompt = "Test prompt"
    response = "Test response"

    # Cache with short TTL
    short_ttl_service.cache_response(prompt, response, cache_ttl: 1)

    # Should be cached immediately
    cached = short_ttl_service.get_cached_response(prompt)
    assert cached[:cached]

    # Wait for TTL to expire
    sleep(2)

    # Should not be cached after expiry
    cached = short_ttl_service.get_cached_response(prompt)
    assert_nil cached
  end

  test "cache invalidation works" do
    prompt = "Test prompt"
    response = "Test response"

    # Cache a response
    @service.cache_response(prompt, response)

    # Verify it's cached
    cached = @service.get_cached_response(prompt)
    assert cached[:cached]

    # Invalidate cache
    @service.invalidate_cache

    # Should no longer be cached
    cached = @service.get_cached_response(prompt)
    assert_nil cached
  end

  test "cache statistics can be reset" do
    prompt = "Test prompt"
    response = "Test response"

    # Generate some cache activity
    @service.get_cached_response(prompt) # miss
    @service.cache_response(prompt, response) # store
    @service.get_cached_response(prompt) # hit

    # Verify stats exist
    stats = @service.cache_statistics
    assert stats[:hits] > 0
    assert stats[:misses] > 0

    # Reset statistics
    @service.reset_cache_statistics

    # Stats should be reset
    reset_stats = @service.cache_statistics
    assert_equal 0, reset_stats[:hits]
    assert_equal 0, reset_stats[:misses]
    assert_equal 0, reset_stats[:stores]
  end

  test "estimate token count provides reasonable estimates" do
    short_text = "Hello"
    long_text = "This is a much longer piece of text that should have more tokens"

    short_count = @service.send(:estimate_token_count, short_text)
    long_count = @service.send(:estimate_token_count, long_text)

    assert short_count > 0
    assert long_count > short_count
  end

  teardown do
    Rails.cache.clear
  end
end