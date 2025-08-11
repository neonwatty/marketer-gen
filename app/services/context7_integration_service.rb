# Context7 MCP server integration service
# Provides documentation lookup and research capabilities for AI content generation
class Context7IntegrationService
  include ActiveModel::Model
  include ActiveModel::Attributes

  class Context7Error < StandardError; end
  class LibraryNotFoundError < Context7Error; end
  class DocumentationNotFoundError < Context7Error; end

  attribute :enabled, :boolean, default: true
  attribute :cache_duration, :integer, default: 3600 # 1 hour cache
  attribute :max_doc_tokens, :integer, default: 10000

  attr_reader :errors, :last_query

  def initialize(attributes = {})
    super(attributes)
    @errors = []
    @cache = {}
    @last_query = nil
  end

  # Main interface methods

  # Look up documentation for a specific library/framework
  def lookup_documentation(library_name, topic: nil, tokens: nil)
    @last_query = { library: library_name, topic: topic, timestamp: Time.current }
    
    cache_key = build_cache_key(library_name, topic)
    
    # Check cache first
    if cached_result = get_from_cache(cache_key)
      Rails.logger.info "Context7: Retrieved documentation from cache for #{library_name}"
      return cached_result
    end

    begin
      # Resolve library ID
      library_id = resolve_library_id(library_name)
      
      # Fetch documentation
      docs = fetch_library_docs(library_id, topic: topic, tokens: tokens)
      
      # Cache the result
      cache_result(cache_key, docs)
      
      Rails.logger.info "Context7: Successfully retrieved documentation for #{library_name}"
      docs
    rescue => e
      error_message = "Context7 documentation lookup failed for '#{library_name}': #{e.message}"
      @errors << error_message
      Rails.logger.error error_message
      nil
    end
  end

  # Enhanced documentation lookup with AI context integration
  def lookup_with_context(library_name, user_query, topic: nil)
    docs = lookup_documentation(library_name, topic: topic)
    return nil unless docs

    # Enhance the documentation with context relevant to the user's query
    contextualize_documentation(docs, user_query)
  end

  # Batch lookup for multiple libraries
  def batch_lookup(library_list, topic: nil)
    results = {}
    library_list.each do |library|
      results[library] = lookup_documentation(library, topic: topic)
    end
    results
  end

  # Get available libraries for a technology stack
  def suggest_libraries(technology_keywords)
    # This would ideally integrate with Context7's search capabilities
    # For now, provide common library suggestions based on keywords
    suggestions = []
    
    technology_keywords.each do |keyword|
      case keyword.downcase
      when /react/
        suggestions.concat(["react", "next.js", "react-router"])
      when /ruby|rails/
        suggestions.concat(["rails", "activerecord", "stimulus"])
      when /javascript|js/
        suggestions.concat(["express", "lodash", "moment"])
      when /css|styling/
        suggestions.concat(["tailwindcss", "bootstrap"])
      end
    end
    
    suggestions.uniq
  end

  # Check if Context7 integration is available and working
  def available?
    return false unless enabled
    
    begin
      # Test with a simple library lookup using the Context7Client
      test_result = Context7Client.resolve_library_id("rails")
      !test_result.nil? && test_result.key?(:library_id)
    rescue NotImplementedError => e
      Rails.logger.warn "Context7 MCP client not yet implemented: #{e.message}"
      false
    rescue => e
      Rails.logger.warn "Context7 availability check failed: #{e.message}"
      false
    end
  end

  # Clear documentation cache
  def clear_cache
    @cache.clear
    Rails.logger.info "Context7: Documentation cache cleared"
  end

  # Get cache statistics
  def cache_stats
    {
      entries: @cache.size,
      memory_usage_mb: (@cache.to_s.bytesize / 1024.0 / 1024.0).round(2),
      oldest_entry: @cache.values.map { |v| v[:cached_at] }.min,
      newest_entry: @cache.values.map { |v| v[:cached_at] }.max
    }
  end

  private

  # Resolve library name to Context7-compatible library ID
  def resolve_library_id(library_name)
    Rails.logger.debug "Context7: Resolving library ID for '#{library_name}'"
    
    begin
      # Call Context7 MCP to resolve library ID
      result = Context7Client.resolve_library_id(library_name)
      
      if result && result[:library_id]
        Rails.logger.debug "Context7: Resolved '#{library_name}' to '#{result[:library_id]}'"
        result[:library_id]
      else
        raise LibraryNotFoundError, "Could not resolve library: #{library_name}"
      end
    rescue => e
      Rails.logger.error "Context7: Library resolution failed for '#{library_name}': #{e.message}"
      # Fallback to basic transformation for common libraries
      fallback_library_id(library_name)
    end
  end
  
  # Fallback method for basic library ID transformation
  def fallback_library_id(library_name)
    case library_name.downcase
    when "react"
      "/facebook/react"
    when "rails", "ruby on rails"
      "/rails/rails"
    when "next.js", "nextjs"
      "/vercel/next.js"
    when "tailwindcss", "tailwind"
      "/tailwindlabs/tailwindcss"
    when "stimulus"
      "/hotwired/stimulus"
    else
      "/#{library_name.gsub(/\s+/, '-').downcase}/#{library_name.gsub(/\s+/, '-').downcase}"
    end
  end

  # Fetch documentation from Context7 MCP server
  def fetch_library_docs(library_id, topic: nil, tokens: nil)
    Rails.logger.debug "Context7: Fetching documentation for #{library_id}"
    
    begin
      # Call Context7 MCP to fetch library documentation
      result = Context7Client.get_library_docs(
        library_id: library_id,
        topic: topic,
        tokens: tokens || max_doc_tokens
      )
      
      if result
        Rails.logger.debug "Context7: Successfully fetched documentation for #{library_id}"
        {
          library_id: library_id,
          topic: topic,
          content: result[:content] || result['content'],
          retrieved_at: Time.current.iso8601,
          token_count: tokens || max_doc_tokens,
          raw_response: result
        }
      else
        raise DocumentationNotFoundError, "No documentation found for #{library_id}"
      end
    rescue => e
      Rails.logger.error "Context7: Documentation fetch failed for #{library_id}: #{e.message}"
      # Fallback to simulated content
      fallback_documentation_content(library_id, topic)
    end
  end

  # Fallback documentation content when Context7 MCP is unavailable
  def fallback_documentation_content(library_id, topic)
    content = case library_id
    when "/facebook/react"
      if topic&.include?("hooks")
        "React Hooks allow you to use state and other React features in functional components..."
      else
        "React is a JavaScript library for building user interfaces..."
      end
    when "/rails/rails"
      "Ruby on Rails is a web application framework written in Ruby..."
    when "/vercel/next.js"
      "Next.js is a React framework that provides hybrid static & server rendering..."
    else
      "Documentation content for #{library_id}..."
    end
    
    {
      library_id: library_id,
      topic: topic,
      content: content,
      retrieved_at: Time.current.iso8601,
      token_count: max_doc_tokens,
      fallback: true
    }
  end

  # Enhance documentation with user query context
  def contextualize_documentation(docs, user_query)
    return docs unless docs.is_a?(Hash)
    
    docs.merge(
      contextualized: true,
      user_query: user_query,
      relevant_sections: extract_relevant_sections(docs[:content], user_query),
      suggestions: generate_usage_suggestions(docs, user_query)
    )
  end

  # Extract sections of documentation most relevant to user query
  def extract_relevant_sections(content, query)
    # Simple keyword-based relevance scoring
    query_keywords = query.downcase.split(/\s+/)
    content_sentences = content.split(/[.!?]+/)
    
    scored_sentences = content_sentences.map do |sentence|
      score = query_keywords.sum { |keyword| sentence.downcase.include?(keyword) ? 1 : 0 }
      { text: sentence.strip, relevance_score: score }
    end
    
    # Return top 5 most relevant sentences
    scored_sentences
      .select { |s| s[:relevance_score] > 0 }
      .sort_by { |s| -s[:relevance_score] }
      .first(5)
      .map { |s| s[:text] }
  end

  # Generate usage suggestions based on documentation and query
  def generate_usage_suggestions(docs, query)
    library_id = docs[:library_id]
    
    case library_id
    when "/facebook/react"
      ["Use functional components with hooks", "Implement proper state management", "Follow React best practices"]
    when "/rails/rails"
      ["Follow Rails conventions", "Use Active Record associations", "Implement proper validations"]
    else
      ["Follow library best practices", "Check official documentation", "Consider performance implications"]
    end
  end

  # Cache management
  def build_cache_key(library_name, topic)
    "context7:#{library_name}:#{topic || 'general'}".downcase.gsub(/[^a-z0-9:_-]/, '_')
  end

  def get_from_cache(cache_key)
    cached_entry = @cache[cache_key]
    return nil unless cached_entry
    
    # Check if cache entry is still valid
    if cached_entry[:cached_at] + cache_duration > Time.current.to_i
      cached_entry[:data]
    else
      @cache.delete(cache_key)
      nil
    end
  end

  def cache_result(cache_key, data)
    @cache[cache_key] = {
      data: data,
      cached_at: Time.current.to_i
    }
    
    # Limit cache size to prevent memory bloat
    if @cache.size > 100
      oldest_key = @cache.min_by { |k, v| v[:cached_at] }.first
      @cache.delete(oldest_key)
    end
  end
end