# Service for link shortening, UTM parameter management, and link tracking
# Handles URL processing, campaign tracking, and analytics integration
class LinkManagementService
  include ActiveModel::Model
  include ActiveModel::Attributes

  # UTM parameter templates for different campaign types
  UTM_TEMPLATES = {
    social_media: {
      utm_source: '%{platform}',
      utm_medium: 'social',
      utm_campaign: '%{campaign_name}',
      utm_content: '%{content_type}_%{variant_id}',
      utm_term: '%{target_keywords}'
    },
    email: {
      utm_source: 'email',
      utm_medium: 'email',
      utm_campaign: '%{campaign_name}',
      utm_content: '%{email_type}_%{segment}',
      utm_term: '%{subject_line_variant}'
    },
    ads: {
      utm_source: '%{platform}',
      utm_medium: 'cpc',
      utm_campaign: '%{campaign_name}',
      utm_content: '%{ad_group}_%{ad_variant}',
      utm_term: '%{keyword}'
    },
    display: {
      utm_source: '%{network}',
      utm_medium: 'display',
      utm_campaign: '%{campaign_name}',
      utm_content: '%{placement}_%{creative}',
      utm_term: '%{audience_segment}'
    },
    affiliate: {
      utm_source: '%{affiliate_partner}',
      utm_medium: 'affiliate',
      utm_campaign: '%{campaign_name}',
      utm_content: '%{promotion_type}',
      utm_term: '%{commission_tier}'
    },
    referral: {
      utm_source: '%{referrer_source}',
      utm_medium: 'referral',
      utm_campaign: '%{campaign_name}',
      utm_content: '%{referral_type}',
      utm_term: '%{incentive_type}'
    }
  }.freeze

  # Link shortening service configurations
  SHORTENING_SERVICES = {
    bitly: {
      api_endpoint: 'https://api-ssl.bitly.com/v4/shorten',
      requires_auth: true,
      custom_domains: true,
      analytics: true
    },
    tinyurl: {
      api_endpoint: 'https://tinyurl.com/api-create.php',
      requires_auth: false,
      custom_domains: false,
      analytics: false
    },
    rebrandly: {
      api_endpoint: 'https://api.rebrandly.com/v1/links',
      requires_auth: true,
      custom_domains: true,
      analytics: true,
      branded_domains: true
    },
    custom: {
      api_endpoint: nil,
      requires_auth: true,
      custom_domains: true,
      analytics: true
    }
  }.freeze

  attr_accessor :campaign_context, :shortening_service, :analytics_enabled

  def initialize(campaign_context: {}, shortening_service: :bitly, analytics_enabled: true)
    @campaign_context = campaign_context || {}
    @shortening_service = shortening_service.to_sym
    @analytics_enabled = analytics_enabled
    validate_configuration!
  end

  # Main method to process all links in content
  def process_content_links(content, options = {})
    processed_content = content.dup
    processed_links = []
    
    # Find all links in content
    links = extract_links(content)
    
    links.each do |original_link|
      processed_link_data = process_single_link(original_link, options)
      processed_content.gsub!(original_link, processed_link_data[:final_url])
      processed_links << processed_link_data
    end

    {
      content: processed_content,
      processed_links: processed_links,
      link_count: processed_links.length,
      total_utm_parameters: processed_links.sum { |link| link[:utm_parameters]&.length || 0 }
    }
  end

  # Process a single link with UTM parameters and shortening
  def process_single_link(url, options = {})
    link_data = {
      original_url: url,
      utm_parameters: {},
      shortened_url: nil,
      final_url: url,
      processing_steps: [],
      analytics_enabled: analytics_enabled
    }

    begin
      # Step 1: Add UTM parameters
      if options[:add_utm] != false
        utm_url = add_utm_parameters(url, options[:utm_context] || {})
        link_data[:utm_parameters] = extract_utm_parameters(utm_url)
        link_data[:final_url] = utm_url
        link_data[:processing_steps] << 'utm_added'
      end

      # Step 2: Shorten link if requested or required by platform
      if should_shorten_link?(options)
        shortened_result = shorten_link(link_data[:final_url], options[:shortening_options] || {})
        if shortened_result[:success]
          link_data[:shortened_url] = shortened_result[:shortened_url]
          link_data[:final_url] = shortened_result[:shortened_url]
          link_data[:shortening_service] = shortening_service
          link_data[:processing_steps] << 'shortened'
          link_data.merge!(shortened_result.except(:success, :shortened_url))
        else
          link_data[:shortening_error] = shortened_result[:error]
        end
      end

      # Step 3: Add click tracking if enabled
      if analytics_enabled && options[:add_tracking] != false
        tracked_url = add_click_tracking(link_data[:final_url], options[:tracking_context] || {})
        link_data[:final_url] = tracked_url
        link_data[:processing_steps] << 'tracking_added'
      end

      link_data[:success] = true

    rescue => e
      link_data[:success] = false
      link_data[:error] = e.message
      link_data[:final_url] = url # Fall back to original URL
    end

    link_data
  end

  # Add UTM parameters to a URL
  def add_utm_parameters(url, context = {})
    return url if url.blank?

    begin
      uri = URI.parse(url)
      existing_params = URI.decode_www_form(uri.query || '')
      
      # Determine UTM template based on context
      template_type = determine_utm_template(context)
      utm_template = UTM_TEMPLATES[template_type] || UTM_TEMPLATES[:social_media]
      
      # Build UTM parameters
      utm_params = build_utm_parameters(utm_template, context)
      
      # Merge with existing parameters (UTM parameters take precedence)
      all_params = merge_url_parameters(existing_params, utm_params)
      
      # Rebuild URL with parameters
      uri.query = URI.encode_www_form(all_params)
      uri.to_s

    rescue URI::InvalidURIError => e
      Rails.logger.warn "Invalid URL for UTM processing: #{url} - #{e.message}"
      url # Return original URL if parsing fails
    end
  end

  # Shorten a URL using configured service
  def shorten_link(url, options = {})
    return { success: false, error: "URL is blank" } if url.blank?

    case shortening_service
    when :bitly
      shorten_with_bitly(url, options)
    when :tinyurl
      shorten_with_tinyurl(url, options)
    when :rebrandly
      shorten_with_rebrandly(url, options)
    when :custom
      shorten_with_custom_service(url, options)
    else
      { success: false, error: "Unsupported shortening service: #{shortening_service}" }
    end
  end

  # Bulk process multiple URLs
  def bulk_process_links(urls, options = {})
    results = []
    
    urls.each do |url|
      result = process_single_link(url, options)
      results << result
    end

    {
      processed_links: results,
      success_count: results.count { |r| r[:success] },
      error_count: results.count { |r| !r[:success] },
      total_count: results.length
    }
  end

  # Generate campaign tracking report
  def generate_tracking_report(campaign_id, date_range = nil)
    # This would integrate with analytics services to provide click tracking data
    # For now, return a mock structure
    {
      campaign_id: campaign_id,
      date_range: date_range || (30.days.ago..Time.current),
      total_clicks: 0,
      unique_clicks: 0,
      click_through_rate: 0.0,
      top_performing_links: [],
      platform_breakdown: {},
      geographic_data: {},
      device_breakdown: {},
      referrer_data: {}
    }
  end

  # Validate and clean URLs
  def validate_url(url)
    return { valid: false, error: "URL is blank" } if url.blank?

    begin
      uri = URI.parse(url)
      
      # Check for valid scheme
      unless %w[http https].include?(uri.scheme&.downcase)
        return { valid: false, error: "Invalid URL scheme. Must be http or https" }
      end

      # Check for valid host
      if uri.host.blank?
        return { valid: false, error: "URL must have a valid domain" }
      end

      # Check for suspicious patterns
      if suspicious_url?(url)
        return { valid: false, error: "URL appears to contain suspicious content" }
      end

      { valid: true, cleaned_url: uri.to_s }

    rescue URI::InvalidURIError => e
      { valid: false, error: "Invalid URL format: #{e.message}" }
    end
  end

  private

  def validate_configuration!
    unless SHORTENING_SERVICES.key?(shortening_service)
      raise ArgumentError, "Invalid shortening service: #{shortening_service}"
    end
  end

  # Extract all URLs from content
  def extract_links(content)
    # Pattern to match HTTP/HTTPS URLs
    url_pattern = /https?:\/\/[^\s<>"'\[\]]+/i
    content.scan(url_pattern).uniq
  end

  # Determine appropriate UTM template based on context
  def determine_utm_template(context)
    return context[:utm_template].to_sym if context[:utm_template]
    
    platform = context[:platform]&.to_s&.downcase
    content_type = context[:content_type]&.to_s&.downcase
    
    # Platform-based detection
    case platform
    when 'email', 'newsletter', 'mailchimp', 'sendgrid'
      :email
    when 'google_ads', 'facebook_ads', 'linkedin_ads', 'twitter_ads'
      :ads
    when 'google_display', 'programmatic', 'display_network'
      :display
    when /affiliate|partner/
      :affiliate
    when /referral|refer/
      :referral
    else
      # Content type based detection
      case content_type
      when /email/
        :email
      when /ad|advertisement/
        :ads
      when /social|post|tweet|status/
        :social_media
      else
        :social_media # Default
      end
    end
  end

  # Build UTM parameters from template
  def build_utm_parameters(template, context)
    merged_context = campaign_context.merge(context)
    
    utm_params = []
    template.each do |param, template_value|
      begin
        value = template_value % merged_context.symbolize_keys
        utm_params << [param.to_s, value] unless value.blank?
      rescue KeyError => e
        # Log missing context but continue processing
        Rails.logger.debug "Missing UTM context for #{param}: #{e.message}"
      end
    end
    
    utm_params
  end

  # Merge URL parameters, giving precedence to UTM parameters
  def merge_url_parameters(existing_params, utm_params)
    # Convert existing params to hash for easier manipulation
    existing_hash = existing_params.to_h
    utm_hash = utm_params.to_h
    
    # UTM parameters override existing ones
    merged_hash = existing_hash.merge(utm_hash)
    
    # Convert back to array format for URI encoding
    merged_hash.to_a
  end

  # Extract UTM parameters from URL
  def extract_utm_parameters(url)
    begin
      uri = URI.parse(url)
      params = URI.decode_www_form(uri.query || '')
      utm_params = params.select { |key, _| key.start_with?('utm_') }
      utm_params.to_h
    rescue URI::InvalidURIError
      {}
    end
  end

  # Check if link should be shortened
  def should_shorten_link?(options)
    return true if options[:force_shorten]
    return true if options[:platform_requires_shortening]
    return true if campaign_context[:auto_shorten_links]
    false
  end

  # Link shortening implementations
  def shorten_with_bitly(url, options)
    # Mock implementation - would integrate with Bitly API
    {
      success: true,
      shortened_url: "https://bit.ly/#{generate_short_code}",
      service: :bitly,
      analytics_url: "https://bitly.com/analytics",
      custom_domain: options[:custom_domain]
    }
  end

  def shorten_with_tinyurl(url, options)
    # Mock implementation - would integrate with TinyURL API
    {
      success: true,
      shortened_url: "https://tinyurl.com/#{generate_short_code}",
      service: :tinyurl
    }
  end

  def shorten_with_rebrandly(url, options)
    # Mock implementation - would integrate with Rebrandly API
    {
      success: true,
      shortened_url: "https://#{options[:custom_domain] || 'rebrand.ly'}/#{generate_short_code}",
      service: :rebrandly,
      branded_domain: options[:custom_domain],
      analytics_enabled: true
    }
  end

  def shorten_with_custom_service(url, options)
    # Custom implementation for internal link shortening
    custom_domain = options[:custom_domain] || campaign_context[:custom_domain] || 'short.ly'
    {
      success: true,
      shortened_url: "https://#{custom_domain}/#{generate_short_code}",
      service: :custom,
      analytics_enabled: analytics_enabled
    }
  end

  # Generate a unique short code
  def generate_short_code(length = 7)
    chars = ('a'..'z').to_a + ('A'..'Z').to_a + ('0'..'9').to_a
    Array.new(length) { chars.sample }.join
  end

  # Add click tracking parameters
  def add_click_tracking(url, tracking_context)
    return url unless analytics_enabled

    begin
      uri = URI.parse(url)
      existing_params = URI.decode_www_form(uri.query || '')
      
      # Add tracking parameters
      tracking_params = [
        ['click_id', generate_click_id],
        ['source_content', tracking_context[:content_id]],
        ['user_segment', tracking_context[:user_segment]]
      ].reject { |_, value| value.blank? }
      
      all_params = existing_params + tracking_params
      uri.query = URI.encode_www_form(all_params)
      uri.to_s
      
    rescue URI::InvalidURIError
      url # Return original URL if parsing fails
    end
  end

  # Generate unique click tracking ID
  def generate_click_id
    "click_#{Time.current.to_i}_#{SecureRandom.hex(8)}"
  end

  # Check for suspicious URL patterns
  def suspicious_url?(url)
    suspicious_patterns = [
      /bit\.ly\/[0-9]+/, # Suspicious bit.ly patterns
      /tinyurl\.com\/[0-9]+/, # Suspicious TinyURL patterns
      /[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}/, # Raw IP addresses
      /localhost|127\.0\.0\.1/, # Local addresses
      /\.onion/, # Tor hidden services
      /phishing|malware|virus/i, # Common malicious terms
    ]
    
    suspicious_patterns.any? { |pattern| url.match?(pattern) }
  end
end