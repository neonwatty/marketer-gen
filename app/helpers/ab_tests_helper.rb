module AbTestsHelper
  # Status badge classes for different test statuses
  STATUS_CLASSES = {
    'draft' => 'bg-gray-100 text-gray-800',
    'running' => 'bg-green-100 text-green-800',
    'paused' => 'bg-yellow-100 text-yellow-800',
    'completed' => 'bg-blue-100 text-blue-800',
    'cancelled' => 'bg-red-100 text-red-800'
  }.freeze

  # Status icons for different test statuses
  STATUS_ICONS = {
    'draft' => 'M15.232 5.232l3.536 3.536m-2.036-5.036a2.5 2.5 0 113.536 3.536L6.5 21.036H3v-3.572L16.732 3.732z',
    'running' => 'M13 10V3L4 14h7v7l9-11h-7z',
    'paused' => 'M10 9v6m4-6v6m7-3a9 9 0 11-18 0 9 9 0 0118 0z',
    'completed' => 'M9 12l2 2 4-4M7.835 4.697a3.42 3.42 0 001.946-.806 3.42 3.42 0 014.438 0 3.42 3.42 0 001.946.806 3.42 3.42 0 013.138 3.138 3.42 3.42 0 00.806 1.946 3.42 3.42 0 010 4.438 3.42 3.42 0 00-.806 1.946 3.42 3.42 0 01-3.138 3.138 3.42 3.42 0 00-1.946.806 3.42 3.42 0 01-4.438 0 3.42 3.42 0 00-1.946-.806 3.42 3.42 0 01-3.138-3.138 3.42 3.42 0 00-.806-1.946 3.42 3.42 0 010-4.438 3.42 3.42 0 00.806-1.946 3.42 3.42 0 013.138-3.138z',
    'cancelled' => 'M6 18L18 6M6 6l12 12'
  }.freeze

  # Render status badge for A/B test
  def ab_test_status_badge(test)
    status = test.status
    classes = "inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium #{STATUS_CLASSES[status]}"
    
    content_tag :span, class: classes do
      concat content_tag(:svg, class: "-ml-0.5 mr-1.5 h-2 w-2 text-current", fill: "currentColor", viewBox: "0 0 8 8") do
        content_tag :circle, '', cx: "4", cy: "4", r: "3"
      end
      concat status.humanize
    end
  end

  # Render variant type badge
  def variant_type_badge(variant)
    if variant.is_control?
      content_tag :span, class: "inline-flex items-center px-2 py-1 rounded text-xs font-medium bg-blue-100 text-blue-800" do
        concat content_tag(:svg, class: "w-3 h-3 mr-1", fill: "none", stroke: "currentColor", viewBox: "0 0 24 24") do
          content_tag :path, '', "stroke-linecap": "round", "stroke-linejoin": "round", "stroke-width": "2", d: "M9 12l2 2 4-4m6-2a9 9 0 11-18 0 9 9 0 0118 0z"
        end
        concat "Control"
      end
    else
      content_tag :span, class: "inline-flex items-center px-2 py-1 rounded text-xs font-medium bg-purple-100 text-purple-800" do
        concat content_tag(:svg, class: "w-3 h-3 mr-1", fill: "none", stroke: "currentColor", viewBox: "0 0 24 24") do
          content_tag :path, '', "stroke-linecap": "round", "stroke-linejoin": "round", "stroke-width": "2", d: "M13 10V3L4 14h7v7l9-11h-7z"
        end
        concat "Treatment"
      end
    end
  end

  # Render winner badge
  def winner_badge(test)
    return unless test.winner_declared?
    
    content_tag :span, class: "inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-amber-100 text-amber-800" do
      concat content_tag(:svg, class: "-ml-0.5 mr-1.5 h-2 w-2 text-amber-400", fill: "currentColor", viewBox: "0 0 8 8") do
        content_tag :circle, '', cx: "4", cy: "4", r: "3"
      end
      concat "Winner: #{test.winner_variant.name}"
    end
  end

  # Render statistical significance indicator
  def significance_indicator(test)
    if test.statistical_significance_reached?
      content_tag :div, class: "flex items-center p-3 rounded-lg bg-green-50 border border-green-200" do
        concat content_tag(:svg, class: "w-5 h-5 text-green-500 mr-2", fill: "none", stroke: "currentColor", viewBox: "0 0 24 24") do
          content_tag :path, '', "stroke-linecap": "round", "stroke-linejoin": "round", "stroke-width": "2", d: "M9 12l2 2 4-4m6-2a9 9 0 11-18 0 9 9 0 0118 0z"
        end
        concat content_tag(:span, "Statistical significance reached", class: "text-sm font-medium text-green-800")
      end
    else
      content_tag :div, class: "flex items-center p-3 rounded-lg bg-yellow-50 border border-yellow-200" do
        concat content_tag(:svg, class: "w-5 h-5 text-yellow-500 mr-2", fill: "none", stroke: "currentColor", viewBox: "0 0 24 24") do
          content_tag :path, '', "stroke-linecap": "round", "stroke-linejoin": "round", "stroke-width": "2", d: "M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-2.5L13.732 4c-.77-.833-1.864-.833-2.464 0L5.232 16.5c-.77.833.192 2.5 1.732 2.5z"
        end
        concat content_tag(:span, "More data needed for statistical significance", class: "text-sm font-medium text-yellow-800")
      end
    end
  end

  # Format lift percentage with color coding
  def format_lift(lift)
    color_class = if lift > 0
                   'text-green-600'
                 elsif lift < 0
                   'text-red-600'
                 else
                   'text-gray-900'
                 end
    
    content_tag :span, class: "font-medium #{color_class}" do
      "#{lift > 0 ? '+' : ''}#{number_to_percentage(lift, precision: 1)}"
    end
  end

  # Render progress bar for test duration
  def test_progress_bar(test)
    return unless test.running? || test.paused?
    
    percentage = test.progress_percentage
    color_class = case test.status
                  when 'running'
                    'bg-blue-600'
                  when 'paused'
                    'bg-yellow-600'
                  else
                    'bg-gray-600'
                  end
    
    content_tag :div, class: "w-full" do
      concat content_tag(:div, class: "flex justify-between text-sm text-gray-600 mb-2") do
        concat content_tag(:span, "Progress")
        concat content_tag(:span, "#{percentage}% complete")
      end
      concat content_tag(:div, class: "w-full bg-gray-200 rounded-full h-2") do
        content_tag :div, '', class: "#{color_class} h-2 rounded-full transition-all duration-300", style: "width: #{percentage}%"
      end
    end
  end

  # Render metric card
  def metric_card(title, value, subtitle: nil, color: 'blue')
    color_classes = {
      'blue' => 'bg-blue-50',
      'green' => 'bg-green-50',
      'yellow' => 'bg-yellow-50',
      'red' => 'bg-red-50',
      'purple' => 'bg-purple-50',
      'gray' => 'bg-gray-50'
    }
    
    content_tag :div, class: "text-center p-3 #{color_classes[color]} rounded-lg" do
      concat content_tag(:div, title, class: "text-sm font-medium text-gray-500")
      concat content_tag(:div, value, class: "text-lg font-bold text-gray-900")
      if subtitle
        concat content_tag(:div, subtitle, class: "text-xs text-gray-500 mt-1")
      end
    end
  end

  # Render confidence interval display
  def confidence_interval_display(variant)
    interval = variant.confidence_interval_range
    return '--' if interval.all?(&:zero?)
    
    "#{interval.first}% - #{interval.last}%"
  end

  # Check if test can be edited
  def test_editable?(test)
    test.draft? || test.paused?
  end

  # Check if variants can be modified
  def variants_editable?(test)
    test.draft?
  end

  # Render test type icon
  def test_type_icon(test_type)
    icons = {
      'conversion' => 'M9 19v-6a2 2 0 00-2-2H5a2 2 0 00-2 2v6a2 2 0 002 2h2a2 2 0 002-2zm0 0V9a2 2 0 012-2h2a2 2 0 012 2v10m-6 0a2 2 0 002 2h2a2 2 0 002-2m0 0V5a2 2 0 012-2h2a2 2 0 012 2v14a2 2 0 01-2 2h-2a2 2 0 01-2-2z',
      'engagement' => 'M4.318 6.318a4.5 4.5 0 000 6.364L12 20.364l7.682-7.682a4.5 4.5 0 00-6.364-6.364L12 7.636l-1.318-1.318a4.5 4.5 0 00-6.364 0z',
      'click_through' => 'M15 15l-2 5L9 9l11 4-5 2zm0 0l5 5M7.188 2.239l.777 2.897M5.136 7.965l-2.898-.777M13.95 4.05l-2.122 2.122m-5.657 5.656l-2.12 2.122',
      'retention' => 'M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15'
    }
    
    icon_path = icons[test_type] || icons['conversion']
    
    content_tag :svg, class: "w-4 h-4", fill: "none", stroke: "currentColor", viewBox: "0 0 24 24", "aria-hidden": "true" do
      content_tag :path, '', "stroke-linecap": "round", "stroke-linejoin": "round", "stroke-width": "2", d: icon_path
    end
  end

  # Render recommendation priority badge
  def recommendation_priority_badge(priority)
    case priority
    when 'high'
      content_tag :span, 'High Priority', class: "inline-flex items-center px-2 py-1 rounded text-xs font-medium bg-red-100 text-red-800"
    when 'medium'
      content_tag :span, 'Medium Priority', class: "inline-flex items-center px-2 py-1 rounded text-xs font-medium bg-yellow-100 text-yellow-800"
    when 'low'
      content_tag :span, 'Low Priority', class: "inline-flex items-center px-2 py-1 rounded text-xs font-medium bg-green-100 text-green-800"
    else
      content_tag :span, 'Normal', class: "inline-flex items-center px-2 py-1 rounded text-xs font-medium bg-gray-100 text-gray-800"
    end
  end

  # Format duration in human readable format
  def format_test_duration(test)
    return 'Not started' unless test.start_date
    
    if test.end_date
      duration = test.end_date - test.start_date
      days = (duration / 1.day).round
      
      if days == 1
        '1 day'
      elsif days < 7
        "#{days} days"
      elsif days < 30
        weeks = (days / 7).round
        "#{weeks} #{'week'.pluralize(weeks)}"
      else
        months = (days / 30).round
        "#{months} #{'month'.pluralize(months)}"
      end
    else
      if test.running?
        elapsed = Time.current - test.start_date
        days = (elapsed / 1.day).round
        "#{days} #{'day'.pluralize(days)} (ongoing)"
      else
        'Duration not set'
      end
    end
  end
end