# frozen_string_literal: true

# Converts Playwright test files into Intro.js tour configurations
class PlaywrightToTourConverter
  class << self
    def convert(playwright_file_path)
      return [] unless File.exist?(playwright_file_path)

      playwright_content = File.read(playwright_file_path)
      
      # Extract steps using regex patterns
      steps = extract_steps(playwright_content)
      
      # Convert to Intro.js format
      steps.map { |step| convert_step(step) }
    end

    private

    def extract_steps(content)
      steps = []
      
      # Extract Playwright actions with regex patterns
      # Pattern: await page.click('selector')
      content.scan(/await\s+page\.click\(['"`]([^'"`]+)['"`]\)/) do |match|
        steps << {
          action: :click,
          selector: match[0],
          context: extract_surrounding_context($~, content)
        }
      end

      # Pattern: await page.fill('selector', 'value')
      content.scan(/await\s+page\.fill\(['"`]([^'"`]+)['"`],\s*['"`]([^'"`]+)['"`]\)/) do |match|
        steps << {
          action: :fill,
          selector: match[0],
          value: match[1],
          context: extract_surrounding_context($~, content)
        }
      end

      # Pattern: await page.selectOption('selector', 'value')
      content.scan(/await\s+page\.selectOption\(['"`]([^'"`]+)['"`],\s*['"`]([^'"`]+)['"`]\)/) do |match|
        steps << {
          action: :select,
          selector: match[0],
          value: match[1],
          context: extract_surrounding_context($~, content)
        }
      end

      # Pattern: await page.goto('url')
      content.scan(/await\s+page\.goto\(['"`]([^'"`]+)['"`]\)/) do |match|
        steps << {
          action: :navigate,
          url: match[0],
          context: extract_surrounding_context($~, content)
        }
      end

      steps
    end

    def extract_surrounding_context(match_data, content)
      # Extract comments and descriptive text around the match
      lines = content.lines
      match_line = content[0...match_data.begin(0)].count("\n")
      
      context_lines = []
      
      # Look for context in previous lines (comments, console.log, etc.)
      (match_line - 3).clamp(0, lines.length - 1).upto(match_line + 1) do |i|
        line = lines[i]&.strip
        next unless line
        
        if line.start_with?('//') || line.include?('console.log')
          context_lines << line.gsub(/^\/\/\s*|console\.log\(['"`]|['"`]\);?$/, '')
        end
      end
      
      context_lines.join(' ').strip
    end

    def convert_step(playwright_step)
      {
        element: convert_selector(playwright_step[:selector] || ''),
        intro: generate_educational_content(playwright_step),
        position: determine_optimal_position(playwright_step[:selector]),
        tooltipClass: 'ai-demo-tooltip'
      }.compact
    end

    def convert_selector(selector)
      # Convert Playwright selectors to standard CSS selectors for Intro.js
      return nil if selector.blank?
      
      # Handle common Playwright selector patterns
      case selector
      when /^text=/
        # Convert text= selectors to more specific targeting
        text = selector.gsub('text=', '')
        ":contains('#{text}')"
      when /^button:has-text\("([^"]+)"\)/
        # Convert button:has-text to CSS selector
        "button:contains('#{$1}')"
      when /^\[data-testid="([^"]+)"\]/
        # Keep data-testid selectors as is
        selector
      else
        # Return as-is for standard CSS selectors
        selector
      end
    end

    def generate_educational_content(step)
      case step[:action]
      when :fill
        generate_fill_content(step)
      when :click
        generate_click_content(step)
      when :select
        generate_select_content(step)
      when :navigate
        generate_navigation_content(step)
      else
        step[:context].presence || "Continue with the next step in the workflow."
      end
    end

    def generate_fill_content(step)
      field_name = extract_field_name(step[:selector])
      
      case field_name.downcase
      when /title/, /name/
        "✏️ **#{field_name.humanize}**: Enter a descriptive name here. Our AI uses this to understand the purpose and adjust content tone accordingly."
      when /audience/, /target/
        "🎯 **Target Audience**: Describe your ideal customers. AI analyzes this to personalize messaging and select optimal channels."
      when /budget/
        "💰 **Budget Information**: Our AI uses budget constraints to prioritize channels and recommend resource allocation strategies."
      when /description/, /content/
        "📝 **Description**: Provide context about your goals. This helps our AI generate more relevant and targeted content."
      else
        "✏️ Fill in this field with relevant information. The AI will use this data to optimize your campaign strategy."
      end
    end

    def generate_click_content(step)
      if step[:selector]&.include?('Generate')
        "🤖 **AI Generation**: Click to activate our advanced AI engine. It will analyze your inputs, apply brand guidelines, and create optimized content in seconds."
      elsif step[:selector]&.include?('submit') || step[:selector]&.include?('Submit')
        "✅ **Submit Form**: Save your inputs and proceed to the next step in the AI workflow."
      elsif step[:context].present?
        "🖱️ **#{step[:context]}**: #{step[:context]}"
      else
        "🖱️ Click this element to continue with the next step in the workflow."
      end
    end

    def generate_select_content(step)
      option_explanations = {
        'social_post' => 'activate AI social media optimization algorithms that consider platform-specific best practices',
        'email_campaign' => 'enable AI email personalization and subject line optimization features',
        'awareness' => 'configure AI to focus on reach, impressions, and brand recognition metrics',
        'conversion' => 'optimize AI recommendations for sales funnel efficiency and ROI',
        'engagement' => 'tune AI for interaction rates, shares, and community building'
      }
      
      explanation = option_explanations[step[:value]] || "optimize the AI's approach for your specific use case"
      
      "🎨 **Select Option**: Choose '#{step[:value]}' to #{explanation}."
    end

    def generate_navigation_content(step)
      case step[:url]
      when /campaign_plans\/new/
        "🚀 **Create Campaign**: Navigate to the campaign creation form where we'll set up the foundation for AI-powered content generation."
      when /generated_contents/
        "📄 **Content Generation**: Access the AI content creation interface where our algorithms will produce optimized marketing materials."
      else
        "🧭 **Navigation**: Move to the next section of the application to continue the workflow."
      end
    end

    def extract_field_name(selector)
      # Extract field name from various selector patterns
      case selector
      when /\[name="[^\[]*\[([^\]]+)\]"\]/
        $1
      when /\[name="([^"]+)"\]/
        $1.split('[').last.gsub(']', '')
      when /#(\w+)/
        $1
      when /\.(\w+)/
        $1
      else
        'field'
      end
    end

    def determine_optimal_position(selector)
      # Determine tooltip position based on selector type
      return 'auto' if selector.blank?
      
      case selector
      when /button/, /submit/
        'top'
      when /input/, /textarea/
        'right'
      when /select/
        'bottom'
      when /nav/, /header/
        'bottom'
      else
        'auto'
      end
    end
  end
end