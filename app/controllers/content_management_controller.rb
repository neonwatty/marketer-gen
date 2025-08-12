class ContentManagementController < ApplicationController
  before_action :set_content_request, only: [:show, :edit, :update]

  def index
    @content_requests = ContentRequest.includes(:content_response).order(created_at: :desc)
    @channels = %w[social_media email ads landing_page general]
  end

  def show
    @content_response = @content_request.content_response
    @available_channels = %w[social_media email ads landing_page general]
  end

  def new
    @content_request = ContentRequest.new
    @channels = %w[social_media email ads landing_page general]
    @available_templates = PromptTemplate.active.pluck(:prompt_type, :name)
  end

  def create
    @content_request = ContentRequest.new(content_request_params)
    
    if @content_request.save
      # Generate initial content if requested
      if params[:generate_content].present?
        generate_content_for_request(@content_request)
      end
      
      redirect_to content_management_path(@content_request), 
                  notice: 'Content request created successfully.'
    else
      @channels = %w[social_media email ads landing_page general]
      @available_templates = PromptTemplate.active.pluck(:prompt_type, :name)
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @channels = %w[social_media email ads landing_page general]
    @content_response = @content_request.content_response || build_empty_response
  end

  def update
    if @content_request.update(content_request_params)
      
      # Update or create content response
      if content_response_params.present?
        if @content_request.content_response
          @content_request.content_response.update(content_response_params)
        else
          @content_request.create_content_response(content_response_params)
        end
      end

      # Regenerate content if requested
      if params[:regenerate_content].present?
        generate_content_for_request(@content_request)
      end
      
      redirect_to content_management_path(@content_request), 
                  notice: 'Content updated successfully.'
    else
      @channels = %w[social_media email ads landing_page general]
      @content_response = @content_request.content_response || build_empty_response
      render :edit, status: :unprocessable_entity
    end
  end

  def preview
    content = params[:content] || ''
    channel = params[:channel] || 'general'
    
    render json: {
      success: true,
      preview_html: generate_preview_html(content, channel),
      channel: channel
    }
  end

  def export
    @content_request = ContentRequest.find(params[:id])
    format = params[:format] || 'html'
    
    case format
    when 'html'
      send_data @content_request.content_response&.generated_content || '',
                filename: "content_#{@content_request.id}.html",
                type: 'text/html'
    when 'json'
      content_data = {
        request: @content_request.as_json,
        response: @content_request.content_response&.as_json,
        exported_at: Time.current.iso8601
      }
      send_data content_data.to_json,
                filename: "content_#{@content_request.id}.json",
                type: 'application/json'
    when 'markdown'
      markdown_content = html_to_markdown(@content_request.content_response&.generated_content || '')
      send_data markdown_content,
                filename: "content_#{@content_request.id}.md",
                type: 'text/markdown'
    else
      redirect_to content_management_path(@content_request), 
                  alert: 'Invalid export format'
    end
  end

  private

  def set_content_request
    @content_request = ContentRequest.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    redirect_to content_management_index_path, alert: 'Content request not found'
  end

  def content_request_params
    params.require(:content_request).permit(
      :content_type, :platform, :brand_context, :campaign_name,
      :campaign_goal, :target_audience, :tone, :content_length,
      :required_elements, :restrictions, :additional_context,
      :request_metadata
    )
  end

  def content_response_params
    return {} unless params[:content_response].present?
    
    params.require(:content_response).permit(
      :generated_content, :response_metadata, :generation_status
    )
  end

  def build_empty_response
    @content_request.build_content_response(
      generated_content: '<p>Enter your content here...</p>',
      generation_status: 'draft'
    )
  end

  def generate_content_for_request(content_request)
    # Use the existing API generation logic
    begin
      # Determine the appropriate template type based on content type
      template_type = map_content_type_to_template(content_request.content_type)
      template = PromptTemplate.active.where(prompt_type: template_type).first
      
      unless template
        flash[:alert] = "No template found for content type: #{content_request.content_type}"
        return
      end

      # Extract variables from the content request
      variables = extract_variables_from_request(content_request)
      
      # Get AI service
      ai_service = AiService.new(
        provider: 'anthropic',
        model: 'claude-3-5-sonnet-20241022',
        enable_context7: true,
        enable_caching: true
      )
      
      # Generate content
      rendered_prompt = template.render_prompt(variables)
      response = ai_service.generate_content(
        rendered_prompt[:user_prompt],
        system_message: rendered_prompt[:system_prompt],
        temperature: rendered_prompt[:temperature],
        max_tokens: rendered_prompt[:max_tokens]
      )
      
      # Parse and store response
      generated_content = parse_ai_response(response)
      
      if content_request.content_response
        content_request.content_response.update(
          generated_content: generated_content,
          generation_status: 'completed',
          response_metadata: {
            template_used: template.name,
            model_used: 'claude-3-5-sonnet-20241022',
            generated_at: Time.current.iso8601
          }
        )
      else
        content_request.create_content_response(
          generated_content: generated_content,
          generation_status: 'completed',
          response_metadata: {
            template_used: template.name,
            model_used: 'claude-3-5-sonnet-20241022',
            generated_at: Time.current.iso8601
          }
        )
      end
      
      flash[:notice] = 'Content generated successfully!'
      
    rescue => e
      Rails.logger.error "Content generation failed: #{e.message}"
      flash[:alert] = "Content generation failed: #{e.message}"
    end
  end

  def map_content_type_to_template(content_type)
    mapping = {
      'social_media' => 'social_media',
      'email' => 'email_marketing',
      'ads' => 'ad_copy',
      'landing_page' => 'landing_page',
      'general' => 'social_media' # fallback
    }
    mapping[content_type] || 'social_media'
  end

  def extract_variables_from_request(content_request)
    {
      'content_type' => content_request.content_type,
      'platform' => content_request.platform || 'general',
      'brand_context' => content_request.brand_context || '',
      'campaign_name' => content_request.campaign_name || '',
      'campaign_goal' => content_request.campaign_goal || 'engagement',
      'target_audience' => content_request.target_audience || '',
      'tone' => content_request.tone || 'professional',
      'content_length' => content_request.content_length || 'medium',
      'required_elements' => content_request.required_elements || '',
      'restrictions' => content_request.restrictions || '',
      'additional_context' => content_request.additional_context || ''
    }
  end

  def parse_ai_response(response)
    if response.is_a?(Hash) && response["content"]
      content_blocks = response["content"] || []
      content_blocks.map { |block| block["text"] }.compact.join("\n")
    else
      response.to_s
    end
  end

  def generate_preview_html(content, channel)
    # This mirrors the JavaScript preview generation
    channel_configs = {
      'social_media' => {
        title: 'Social Media Preview',
        container_class: 'bg-white border rounded-lg p-4 max-w-md mx-auto shadow-sm',
        content_class: 'text-gray-800 text-sm leading-relaxed',
        header: '<div class="flex items-center mb-3"><div class="w-10 h-10 bg-blue-500 rounded-full flex items-center justify-center text-white font-bold text-sm">B</div><div class="ml-3"><div class="font-semibold text-sm text-gray-900">Brand Account</div><div class="text-xs text-gray-500">Just now</div></div></div>',
        footer: '<div class="flex items-center justify-between mt-3 pt-2 border-t border-gray-100"><div class="flex space-x-4 text-gray-500"><button class="flex items-center space-x-1 text-xs hover:text-blue-600"><span>👍</span><span>Like</span></button><button class="flex items-center space-x-1 text-xs hover:text-blue-600"><span>💬</span><span>Comment</span></button><button class="flex items-center space-x-1 text-xs hover:text-blue-600"><span>↗️</span><span>Share</span></button></div></div>'
      },
      'email' => {
        title: 'Email Preview',
        container_class: 'bg-white border rounded-lg max-w-2xl mx-auto shadow-sm',
        content_class: 'text-gray-800 text-sm leading-relaxed px-6 py-4',
        header: "<div class=\"border-b border-gray-200 px-6 py-3\"><div class=\"flex items-center justify-between\"><div><div class=\"font-semibold text-sm text-gray-900\">Campaign Email</div><div class=\"text-xs text-gray-500\">from: your-company@example.com</div></div><div class=\"text-xs text-gray-500\">#{Date.current.strftime('%m/%d/%Y')}</div></div></div>",
        footer: '<div class="border-t border-gray-200 px-6 py-3 bg-gray-50 text-xs text-gray-500"><div class="text-center"><p>This email was sent to subscriber@example.com</p><p class="mt-1"><a href="#" class="text-blue-600 hover:underline">Unsubscribe</a> | <a href="#" class="text-blue-600 hover:underline">View in browser</a></p></div></div>'
      },
      'ads' => {
        title: 'Ad Preview',
        container_class: 'bg-white border rounded-lg p-4 max-w-md mx-auto shadow-sm',
        content_class: 'text-gray-800 text-sm leading-relaxed',
        header: '<div class="flex items-center justify-between mb-2"><div class="flex items-center"><div class="w-8 h-8 bg-green-500 rounded-full flex items-center justify-center text-white font-bold text-xs">AD</div><div class="ml-2"><div class="font-semibold text-xs text-gray-900">Sponsored</div></div></div><div class="text-xs text-gray-500">•••</div></div>',
        footer: '<div class="mt-3"><button class="w-full bg-blue-600 text-white text-sm font-medium py-2 px-4 rounded hover:bg-blue-700 transition-colors">Learn More</button></div>'
      },
      'general' => {
        title: 'Content Preview',
        container_class: 'bg-white border rounded-lg p-6 max-w-2xl mx-auto shadow-sm',
        content_class: 'prose prose-sm max-w-none',
        header: '',
        footer: ''
      }
    }

    config = channel_configs[channel] || channel_configs['general']

    <<-HTML
      <div class="mb-2">
        <h3 class="text-lg font-semibold text-gray-900">#{config[:title]}</h3>
      </div>
      <div class="#{config[:container_class]}">
        #{config[:header]}
        <div class="#{config[:content_class]}">
          #{content}
        </div>
        #{config[:footer]}
      </div>
    HTML
  end

  def html_to_markdown(html)
    # Basic HTML to Markdown conversion
    html.gsub(/<h1>(.*?)<\/h1>/mi, "# \\1\n\n")
        .gsub(/<h2>(.*?)<\/h2>/mi, "## \\1\n\n")
        .gsub(/<h3>(.*?)<\/h3>/mi, "### \\1\n\n")
        .gsub(/<p>(.*?)<\/p>/mi, "\\1\n\n")
        .gsub(/<strong>(.*?)<\/strong>/mi, "**\\1**")
        .gsub(/<em>(.*?)<\/em>/mi, "*\\1*")
        .gsub(/<code>(.*?)<\/code>/mi, "`\\1`")
        .gsub(/<blockquote>(.*?)<\/blockquote>/mi, "> \\1\n\n")
        .gsub(/<ul><li>(.*?)<\/li><\/ul>/mi, "- \\1\n")
        .gsub(/<li>(.*?)<\/li>/mi, "- \\1\n")
        .gsub(/<br\s*\/?>/mi, "\n")
        .strip
  end
end