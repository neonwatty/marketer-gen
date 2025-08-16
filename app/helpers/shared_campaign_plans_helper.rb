module SharedCampaignPlansHelper
  def render_json_content(json_data)
    return content_tag(:p, "No content available", class: "text-gray-500 italic") if json_data.blank?
    
    parsed_data = case json_data
                  when Hash
                    json_data
                  when String
                    JSON.parse(json_data)
                  else
                    json_data
                  end
    
    render_data_structure(parsed_data)
  rescue JSON::ParserError
    content_tag(:p, "Content format error", class: "text-red-500 italic")
  end

  private

  def render_data_structure(data, level = 0)
    case data
    when Hash
      content = data.map do |key, value|
        content_tag(:div, class: "mb-3") do
          content_tag("h#{[6, 3 + level].min}".to_sym, key.to_s.humanize, class: "font-semibold text-gray-900 mb-1") +
          content_tag(:div, render_data_structure(value, level + 1), class: "ml-4")
        end
      end.join.html_safe
      content_tag(:div, content, class: level == 0 ? "space-y-4" : "")
    when Array
      content = data.map.with_index do |item, index|
        content_tag(:div, class: "mb-2") do
          content_tag(:span, "#{index + 1}. ", class: "font-medium text-gray-700") +
          render_data_structure(item, level + 1)
        end
      end.join.html_safe
      content_tag(:div, content, class: "space-y-2")
    else
      simple_format(data.to_s, class: "text-gray-700")
    end
  end
end
