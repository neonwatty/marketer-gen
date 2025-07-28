class MessagingFrameworksController < ApplicationController
  before_action :set_brand
  before_action :set_messaging_framework

  def show
    respond_to do |format|
      format.html
      format.json { render json: framework_json }
    end
  end

  def edit
  end

  def update
    respond_to do |format|
      if @messaging_framework.update(messaging_framework_params)
        format.html { redirect_to brand_messaging_framework_path(@brand), notice: 'Messaging framework was successfully updated.' }
        format.json { render json: { success: true, messaging_framework: framework_json } }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: { success: false, errors: @messaging_framework.errors.full_messages }, status: :unprocessable_entity }
      end
    end
  end

  # AJAX Actions for specific updates
  def update_key_messages
    if @messaging_framework.update(key_messages: params[:key_messages])
      render json: { success: true, key_messages: @messaging_framework.key_messages }
    else
      render json: { success: false, errors: @messaging_framework.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def update_value_propositions
    if @messaging_framework.update(value_propositions: params[:value_propositions])
      render json: { success: true, value_propositions: @messaging_framework.value_propositions }
    else
      render json: { success: false, errors: @messaging_framework.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def update_terminology
    if @messaging_framework.update(terminology: params[:terminology])
      render json: { success: true, terminology: @messaging_framework.terminology }
    else
      render json: { success: false, errors: @messaging_framework.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def update_approved_phrases
    if @messaging_framework.update(approved_phrases: params[:approved_phrases])
      render json: { success: true, approved_phrases: @messaging_framework.approved_phrases }
    else
      render json: { success: false, errors: @messaging_framework.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def update_banned_words
    if @messaging_framework.update(banned_words: params[:banned_words])
      render json: { success: true, banned_words: @messaging_framework.banned_words }
    else
      render json: { success: false, errors: @messaging_framework.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def update_tone_attributes
    if @messaging_framework.update(tone_attributes: params[:tone_attributes])
      render json: { success: true, tone_attributes: @messaging_framework.tone_attributes }
    else
      render json: { success: false, errors: @messaging_framework.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def validate_content
    content = params[:content]
    validation_results = {
      banned_words: @messaging_framework.get_banned_words_in_text(content),
      contains_banned: @messaging_framework.contains_banned_words?(content),
      tone_match: analyze_tone_match(content),
      approved_phrases_used: find_approved_phrases_in_text(content)
    }
    render json: validation_results
  end

  def export
    respond_to do |format|
      format.json { render json: @messaging_framework.to_json }
      format.csv { send_data generate_csv, filename: "messaging-framework-#{@brand.name.parameterize}-#{Date.today}.csv" }
    end
  end

  def import
    if params[:file].present?
      result = import_framework_data(params[:file])
      if result[:success]
        render json: { success: true, message: 'Framework imported successfully' }
      else
        render json: { success: false, errors: result[:errors] }, status: :unprocessable_entity
      end
    else
      render json: { success: false, errors: ['No file uploaded'] }, status: :unprocessable_entity
    end
  end

  def ai_suggestions
    content_type = params[:content_type]
    current_content = params[:current_content]
    
    suggestions = generate_ai_suggestions(content_type, current_content)
    render json: { suggestions: suggestions }
  end

  def reorder_key_messages
    category = params[:category]
    ordered_ids = params[:ordered_ids]
    
    if @messaging_framework.key_messages[category]
      reordered_messages = ordered_ids.map do |id|
        @messaging_framework.key_messages[category][id.to_i]
      end.compact
      
      @messaging_framework.key_messages[category] = reordered_messages
      
      if @messaging_framework.save
        render json: { success: true, key_messages: @messaging_framework.key_messages }
      else
        render json: { success: false, errors: @messaging_framework.errors.full_messages }, status: :unprocessable_entity
      end
    else
      render json: { success: false, errors: ['Category not found'] }, status: :not_found
    end
  end

  def reorder_value_propositions
    proposition_type = params[:proposition_type]
    ordered_ids = params[:ordered_ids]
    
    if @messaging_framework.value_propositions[proposition_type]
      reordered_props = ordered_ids.map do |id|
        @messaging_framework.value_propositions[proposition_type][id.to_i]
      end.compact
      
      @messaging_framework.value_propositions[proposition_type] = reordered_props
      
      if @messaging_framework.save
        render json: { success: true, value_propositions: @messaging_framework.value_propositions }
      else
        render json: { success: false, errors: @messaging_framework.errors.full_messages }, status: :unprocessable_entity
      end
    else
      render json: { success: false, errors: ['Proposition type not found'] }, status: :not_found
    end
  end

  def add_key_message
    category = params[:category]
    message = params[:message]
    
    @messaging_framework.key_messages ||= {}
    @messaging_framework.key_messages[category] ||= []
    @messaging_framework.key_messages[category] << message
    
    if @messaging_framework.save
      render json: { success: true, key_messages: @messaging_framework.key_messages }
    else
      render json: { success: false, errors: @messaging_framework.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def remove_key_message
    category = params[:category]
    index = params[:index].to_i
    
    if @messaging_framework.key_messages[category]
      @messaging_framework.key_messages[category].delete_at(index)
      
      if @messaging_framework.save
        render json: { success: true, key_messages: @messaging_framework.key_messages }
      else
        render json: { success: false, errors: @messaging_framework.errors.full_messages }, status: :unprocessable_entity
      end
    else
      render json: { success: false, errors: ['Category not found'] }, status: :not_found
    end
  end

  def add_value_proposition
    proposition_type = params[:proposition_type]
    proposition = params[:proposition]
    
    @messaging_framework.value_propositions ||= {}
    @messaging_framework.value_propositions[proposition_type] ||= []
    @messaging_framework.value_propositions[proposition_type] << proposition
    
    if @messaging_framework.save
      render json: { success: true, value_propositions: @messaging_framework.value_propositions }
    else
      render json: { success: false, errors: @messaging_framework.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def remove_value_proposition
    proposition_type = params[:proposition_type]
    index = params[:index].to_i
    
    if @messaging_framework.value_propositions[proposition_type]
      @messaging_framework.value_propositions[proposition_type].delete_at(index)
      
      if @messaging_framework.save
        render json: { success: true, value_propositions: @messaging_framework.value_propositions }
      else
        render json: { success: false, errors: @messaging_framework.errors.full_messages }, status: :unprocessable_entity
      end
    else
      render json: { success: false, errors: ['Proposition type not found'] }, status: :not_found
    end
  end

  def search_approved_phrases
    query = params[:query].to_s.downcase
    phrases = @messaging_framework.approved_phrases || []
    
    filtered_phrases = if query.present?
      phrases.select { |phrase| phrase.downcase.include?(query) }
    else
      phrases
    end
    
    render json: { phrases: filtered_phrases }
  end

  private

  def set_brand
    @brand = current_user.brands.find(params[:brand_id])
  end

  def set_messaging_framework
    @messaging_framework = @brand.messaging_framework || @brand.create_messaging_framework!
  end

  def messaging_framework_params
    params.require(:messaging_framework).permit(
      :tagline,
      :mission_statement,
      :vision_statement,
      :active,
      key_messages: {},
      value_propositions: {},
      terminology: {},
      approved_phrases: [],
      banned_words: [],
      tone_attributes: {}
    )
  end

  def framework_json
    {
      id: @messaging_framework.id,
      tagline: @messaging_framework.tagline,
      mission_statement: @messaging_framework.mission_statement,
      vision_statement: @messaging_framework.vision_statement,
      key_messages: @messaging_framework.key_messages || {},
      value_propositions: @messaging_framework.value_propositions || {},
      terminology: @messaging_framework.terminology || {},
      approved_phrases: @messaging_framework.approved_phrases || [],
      banned_words: @messaging_framework.banned_words || [],
      tone_attributes: @messaging_framework.tone_attributes || {},
      active: @messaging_framework.active
    }
  end

  def analyze_tone_match(content)
    # Simple tone analysis - in production, this would use NLP
    tone = @messaging_framework.tone_attributes || {}
    
    {
      formality: tone['formality'] || 'neutral',
      matches_tone: true, # Simplified for now
      suggestions: []
    }
  end

  def find_approved_phrases_in_text(content)
    return [] unless @messaging_framework.approved_phrases.present?
    
    @messaging_framework.approved_phrases.select do |phrase|
      content.downcase.include?(phrase.downcase)
    end
  end

  def generate_csv
    require 'csv'
    
    CSV.generate(headers: true) do |csv|
      csv << ['Section', 'Key', 'Value']
      
      # Export key messages
      (@messaging_framework.key_messages || {}).each do |category, messages|
        messages.each { |msg| csv << ['Key Messages', category, msg] }
      end
      
      # Export value propositions
      (@messaging_framework.value_propositions || {}).each do |type, props|
        props.each { |prop| csv << ['Value Propositions', type, prop] }
      end
      
      # Export terminology
      (@messaging_framework.terminology || {}).each do |term, definition|
        csv << ['Terminology', term, definition]
      end
      
      # Export approved phrases
      (@messaging_framework.approved_phrases || []).each do |phrase|
        csv << ['Approved Phrases', '', phrase]
      end
      
      # Export banned words
      (@messaging_framework.banned_words || []).each do |word|
        csv << ['Banned Words', '', word]
      end
      
      # Export tone attributes
      (@messaging_framework.tone_attributes || {}).each do |attr, value|
        csv << ['Tone Attributes', attr, value]
      end
    end
  end

  def import_framework_data(file)
    # Handle JSON import
    if file.content_type == 'application/json'
      begin
        data = JSON.parse(file.read)
        @messaging_framework.update!(data.slice(*%w[key_messages value_propositions terminology approved_phrases banned_words tone_attributes tagline mission_statement vision_statement]))
        { success: true }
      rescue => e
        { success: false, errors: [e.message] }
      end
    else
      { success: false, errors: ['Unsupported file type. Please upload a JSON file.'] }
    end
  end

  def generate_ai_suggestions(content_type, current_content)
    # In production, this would call your AI service
    # For now, return sample suggestions
    case content_type
    when 'key_messages'
      [
        "Focus on customer benefits rather than features",
        "Include emotional appeal alongside rational arguments",
        "Ensure consistency with brand voice"
      ]
    when 'value_propositions'
      [
        "Lead with the primary benefit",
        "Quantify value where possible",
        "Differentiate from competitors"
      ]
    when 'tagline'
      [
        "Keep it under 7 words for memorability",
        "Include a unique brand element",
        "Make it actionable or aspirational"
      ]
    else
      ["No suggestions available for this content type"]
    end
  end
end
