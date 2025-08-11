# Intelligent caching for AI service responses
# Provides prompt-based caching with configurable invalidation strategies
module AiResponseCache
  extend ActiveSupport::Concern

  included do
    # Caching configuration
    attribute :cache_enabled, :boolean, default: true
    attribute :cache_ttl_seconds, :integer, default: 3600 # 1 hour default
    attribute :cache_key_prefix, :string
    attribute :cache_similar_prompts, :boolean, default: false
    attribute :cache_similarity_threshold, :float, default: 0.85
  end

  # Attempt to get cached response for a prompt
  def get_cached_response(prompt, options = {})
    return nil unless cache_enabled
    
    cache_key = generate_cache_key(prompt, options)
    cached_data = Rails.cache.read(cache_key)
    
    if cached_data
      Rails.logger.info "AI cache hit for #{provider_name}: #{cache_key}"
      
      # Update cache metadata
      update_cache_metadata(cache_key, :hit)
      
      # Return cached response with metadata
      {
        response: cached_data[:response],
        cached: true,
        cache_key: cache_key,
        cached_at: cached_data[:cached_at],
        tokens_saved: cached_data[:estimated_tokens] || 0
      }
    else
      Rails.logger.debug "AI cache miss for #{provider_name}: #{cache_key}"
      update_cache_metadata(cache_key, :miss)
      nil
    end
  end

  # Cache a response with metadata
  def cache_response(prompt, response, options = {})
    return response unless cache_enabled
    
    cache_key = generate_cache_key(prompt, options)
    estimated_tokens = options[:estimated_tokens] || estimate_token_count(response.to_s)
    
    cache_data = {
      response: response,
      cached_at: Time.current,
      prompt_hash: generate_prompt_hash(prompt, options),
      estimated_tokens: estimated_tokens,
      provider: provider_name,
      model: attributes['model_name'],
      cache_version: 1
    }
    
    # Store with configurable TTL
    ttl = options[:cache_ttl] || cache_ttl_seconds
    Rails.cache.write(cache_key, cache_data, expires_in: ttl.seconds)
    
    Rails.logger.info "AI response cached for #{provider_name}: #{cache_key} (#{estimated_tokens} tokens, TTL: #{ttl}s)"
    
    # Update cache metadata
    update_cache_metadata(cache_key, :stored, estimated_tokens)
    
    response
  end

  # Find similar cached responses if enabled
  def find_similar_cached_response(prompt, options = {})
    return nil unless cache_enabled && cache_similar_prompts
    
    prompt_hash = generate_prompt_hash(prompt, options)
    
    # This is a simplified implementation - in production you'd want a more sophisticated
    # similarity search using embeddings or fuzzy matching
    search_pattern = cache_key_pattern(prompt_hash[0..8]) # Use first 8 chars as prefix
    
    Rails.cache.redis&.keys(search_pattern)&.each do |key|
      cached_data = Rails.cache.read(key)
      next unless cached_data
      
      similarity = calculate_prompt_similarity(prompt_hash, cached_data[:prompt_hash])
      
      if similarity >= cache_similarity_threshold
        Rails.logger.info "AI cache similar hit (#{similarity.round(2)}): #{key}"
        
        return {
          response: cached_data[:response],
          cached: true,
          cache_key: key,
          cached_at: cached_data[:cached_at],
          similarity: similarity,
          tokens_saved: cached_data[:estimated_tokens] || 0
        }
      end
    end
    
    nil
  rescue => e
    Rails.logger.warn "Error finding similar cached responses: #{e.message}"
    nil
  end

  # Invalidate cache entries matching pattern
  def invalidate_cache(pattern = nil)
    return unless cache_enabled
    
    pattern ||= "#{cache_key_prefix}:*"
    
    count = 0
    if Rails.cache.respond_to?(:delete_matched)
      # Use Rails cache delete_matched if available
      count = Rails.cache.delete_matched(pattern)
    else
      # Fallback for cache stores that don't support pattern deletion
      Rails.logger.warn "Cache invalidation by pattern not supported for #{Rails.cache.class}"
    end
    
    Rails.logger.info "Invalidated #{count} cache entries for pattern: #{pattern}"
    count
  end

  # Get cache statistics
  def cache_statistics
    return { enabled: false } unless cache_enabled
    
    metadata_key = "#{cache_key_prefix}:metadata"
    metadata = Rails.cache.read(metadata_key) || {
      hits: 0,
      misses: 0,
      stores: 0,
      tokens_saved: 0,
      last_reset: Time.current
    }
    
    {
      enabled: true,
      hits: metadata[:hits],
      misses: metadata[:misses],
      stores: metadata[:stores],
      hit_rate: calculate_hit_rate(metadata[:hits], metadata[:misses]),
      tokens_saved: metadata[:tokens_saved],
      last_reset: metadata[:last_reset]
    }
  end

  # Reset cache statistics
  def reset_cache_statistics
    return unless cache_enabled
    
    metadata_key = "#{cache_key_prefix}:metadata"
    Rails.cache.write(metadata_key, {
      hits: 0,
      misses: 0,
      stores: 0,
      tokens_saved: 0,
      last_reset: Time.current
    }, expires_in: 30.days)
  end

  private

  def generate_cache_key(prompt, options = {})
    # Create a deterministic cache key based on prompt and relevant options
    prompt_hash = generate_prompt_hash(prompt, options)
    model_context = "#{provider_name}:#{attributes['model_name']}"
    
    "#{cache_key_prefix}:#{model_context}:#{prompt_hash}"
  end

  def generate_prompt_hash(prompt, options = {})
    # Include relevant options that would affect the response
    cache_relevant_options = options.slice(
      :temperature, :max_tokens, :top_p, :top_k, :presence_penalty, 
      :frequency_penalty, :stop_sequences, :system_prompt
    )
    
    content_to_hash = {
      prompt: sanitize_prompt(prompt),
      options: cache_relevant_options,
      model: attributes['model_name']
    }
    
    Digest::SHA256.hexdigest(content_to_hash.to_json)
  end

  def cache_key_pattern(prefix)
    "#{cache_key_prefix}:*:#{prefix}*"
  end

  def calculate_prompt_similarity(hash1, hash2)
    # Simple similarity based on common prefix length
    # In production, you'd want more sophisticated similarity measures
    return 1.0 if hash1 == hash2
    
    common_length = 0
    [hash1.length, hash2.length].min.times do |i|
      break if hash1[i] != hash2[i]
      common_length += 1
    end
    
    common_length.to_f / [hash1.length, hash2.length].max
  end

  def update_cache_metadata(cache_key, operation, tokens = 0)
    metadata_key = "#{cache_key_prefix}:metadata"
    
    metadata = Rails.cache.read(metadata_key) || {
      hits: 0,
      misses: 0,
      stores: 0,
      tokens_saved: 0,
      last_reset: Time.current
    }
    
    case operation
    when :hit
      metadata[:hits] += 1
      metadata[:tokens_saved] += tokens if tokens > 0
    when :miss
      metadata[:misses] += 1
    when :stored
      metadata[:stores] += 1
    end
    
    Rails.cache.write(metadata_key, metadata, expires_in: 30.days)
  end

  def calculate_hit_rate(hits, misses)
    total = hits + misses
    return 0.0 if total == 0
    (hits.to_f / total * 100).round(2)
  end

  def cache_key_prefix
    @cache_key_prefix ||= attributes['cache_key_prefix'] || "ai_cache:#{provider_name}"
  end
end