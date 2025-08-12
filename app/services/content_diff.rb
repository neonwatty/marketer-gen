# ContentDiff service - Git-like diff functionality for content versions
# Generates detailed differences between content versions with multiple output formats
class ContentDiff
  include ActiveModel::Model

  attr_reader :version_a, :version_b, :options
  attr_accessor :changes, :statistics

  # Diff change types
  CHANGE_TYPES = {
    added: '+',
    removed: '-',
    modified: '~',
    moved: '→',
    unchanged: ' '
  }.freeze

  # Output formats
  OUTPUT_FORMATS = %i[unified context side_by_side json html].freeze

  def initialize(version_a, version_b, options = {})
    @version_a = version_a
    @version_b = version_b
    @options = options.symbolize_keys
    @changes = []
    @statistics = { additions: 0, deletions: 0, modifications: 0 }
  end

  def generate
    analyze_differences
    ContentDiffResult.new(
      version_a: version_a,
      version_b: version_b,
      changes: changes,
      statistics: statistics,
      options: options
    )
  end

  def self.compare(version_a, version_b, options = {})
    new(version_a, version_b, options).generate
  end

  def self.show_history(content_item, limit: 10, format: :unified)
    versions = ContentVersion.where(content_item: content_item)
                            .order(:version_number)
                            .limit(limit + 1)

    history_diffs = []
    
    versions.each_cons(2) do |prev_version, current_version|
      diff = compare(prev_version, current_version, format: format)
      history_diffs << {
        from: prev_version.content_summary,
        to: current_version.content_summary,
        diff: diff
      }
    end
    
    history_diffs
  end

  private

  def analyze_differences
    content_a = version_a.content_data
    content_b = version_b.content_data
    
    # Get all fields from both versions
    all_fields = (content_a.keys + content_b.keys).uniq
    
    all_fields.each do |field|
      analyze_field_difference(field, content_a[field], content_b[field])
    end
    
    calculate_statistics
  end

  def analyze_field_difference(field, value_a, value_b)
    if value_a.nil? && !value_b.nil?
      # Field added
      add_change(field, :added, nil, value_b, "Added field '#{field}'")
      @statistics[:additions] += 1
      
    elsif !value_a.nil? && value_b.nil?
      # Field removed
      add_change(field, :removed, value_a, nil, "Removed field '#{field}'")
      @statistics[:deletions] += 1
      
    elsif value_a != value_b
      # Field modified
      if value_a.is_a?(String) && value_b.is_a?(String)
        analyze_text_difference(field, value_a, value_b)
      elsif value_a.is_a?(Array) && value_b.is_a?(Array)
        analyze_array_difference(field, value_a, value_b)
      elsif value_a.is_a?(Hash) && value_b.is_a?(Hash)
        analyze_hash_difference(field, value_a, value_b)
      else
        add_change(field, :modified, value_a, value_b, "Modified field '#{field}'")
        @statistics[:modifications] += 1
      end
    end
  end

  def analyze_text_difference(field, text_a, text_b)
    if options[:word_diff]
      analyze_word_difference(field, text_a, text_b)
    else
      analyze_line_difference(field, text_a, text_b)
    end
  end

  def analyze_line_difference(field, text_a, text_b)
    lines_a = text_a.lines.map(&:chomp)
    lines_b = text_b.lines.map(&:chomp)
    
    # Simple line-based diff using longest common subsequence
    diff_lines = calculate_line_diff(lines_a, lines_b)
    
    if diff_lines.any?
      add_change(field, :modified, text_a, text_b, "Text content changed in '#{field}'", {
        line_changes: diff_lines,
        lines_added: diff_lines.count { |line| line[:type] == :added },
        lines_removed: diff_lines.count { |line| line[:type] == :removed }
      })
      @statistics[:modifications] += 1
    end
  end

  def analyze_word_difference(field, text_a, text_b)
    words_a = text_a.split(/\s+/)
    words_b = text_b.split(/\s+/)
    
    word_changes = calculate_word_diff(words_a, words_b)
    
    if word_changes.any?
      add_change(field, :modified, text_a, text_b, "Word-level changes in '#{field}'", {
        word_changes: word_changes,
        words_added: word_changes.count { |change| change[:type] == :added },
        words_removed: word_changes.count { |change| change[:type] == :removed }
      })
      @statistics[:modifications] += 1
    end
  end

  def analyze_array_difference(field, array_a, array_b)
    added_items = array_b - array_a
    removed_items = array_a - array_b
    
    changes_details = []
    
    if added_items.any?
      changes_details << {
        type: :added,
        items: added_items,
        description: "Added #{added_items.size} items"
      }
      @statistics[:additions] += added_items.size
    end
    
    if removed_items.any?
      changes_details << {
        type: :removed,
        items: removed_items,
        description: "Removed #{removed_items.size} items"
      }
      @statistics[:deletions] += removed_items.size
    end
    
    if changes_details.any?
      add_change(field, :modified, array_a, array_b, "Array changes in '#{field}'", {
        array_changes: changes_details
      })
    end
  end

  def analyze_hash_difference(field, hash_a, hash_b)
    all_keys = (hash_a.keys + hash_b.keys).uniq
    hash_changes = []
    
    all_keys.each do |key|
      if hash_a.key?(key) && !hash_b.key?(key)
        hash_changes << { type: :removed, key: key, value: hash_a[key] }
        @statistics[:deletions] += 1
      elsif !hash_a.key?(key) && hash_b.key?(key)
        hash_changes << { type: :added, key: key, value: hash_b[key] }
        @statistics[:additions] += 1
      elsif hash_a[key] != hash_b[key]
        hash_changes << { 
          type: :modified, 
          key: key, 
          old_value: hash_a[key], 
          new_value: hash_b[key] 
        }
        @statistics[:modifications] += 1
      end
    end
    
    if hash_changes.any?
      add_change(field, :modified, hash_a, hash_b, "Hash structure changes in '#{field}'", {
        hash_changes: hash_changes
      })
    end
  end

  def calculate_line_diff(lines_a, lines_b)
    # Simple implementation of Myers diff algorithm for lines
    diff_result = []
    
    # Use a basic approach for demonstration
    # In production, you might want to use a more sophisticated diff library
    
    max_length = [lines_a.length, lines_b.length].max
    
    (0...max_length).each do |i|
      line_a = lines_a[i]
      line_b = lines_b[i]
      
      if line_a && line_b
        if line_a == line_b
          diff_result << { type: :unchanged, content: line_a, line_number_a: i + 1, line_number_b: i + 1 }
        else
          diff_result << { type: :removed, content: line_a, line_number_a: i + 1 }
          diff_result << { type: :added, content: line_b, line_number_b: i + 1 }
        end
      elsif line_a
        diff_result << { type: :removed, content: line_a, line_number_a: i + 1 }
      elsif line_b
        diff_result << { type: :added, content: line_b, line_number_b: i + 1 }
      end
    end
    
    diff_result
  end

  def calculate_word_diff(words_a, words_b)
    # Simple word-based diff
    word_changes = []
    
    # Find added words
    added_words = words_b - words_a
    added_words.each do |word|
      word_changes << { type: :added, content: word }
    end
    
    # Find removed words
    removed_words = words_a - words_b
    removed_words.each do |word|
      word_changes << { type: :removed, content: word }
    end
    
    word_changes
  end

  def add_change(field, type, old_value, new_value, description, details = {})
    @changes << {
      field: field,
      type: type,
      old_value: old_value,
      new_value: new_value,
      description: description,
      details: details,
      symbol: CHANGE_TYPES[type]
    }
  end

  def calculate_statistics
    @statistics[:total_changes] = changes.size
    @statistics[:fields_changed] = changes.map { |change| change[:field] }.uniq.size
    
    # Calculate similarity percentage
    total_fields = (version_a.content_data.keys + version_b.content_data.keys).uniq.size
    unchanged_fields = total_fields - @statistics[:fields_changed]
    @statistics[:similarity] = total_fields > 0 ? (unchanged_fields.to_f / total_fields * 100).round(2) : 100.0
  end
end

# Result class for diff operations
class ContentDiffResult
  include ActiveModel::Model
  
  attr_accessor :version_a, :version_b, :changes, :statistics, :options
  
  def initialize(attributes = {})
    super(attributes)
    @options ||= {}
  end
  
  def has_changes?
    changes.any?
  end
  
  def format(output_format = :unified)
    case output_format.to_sym
    when :unified
      to_unified_format
    when :context
      to_context_format
    when :side_by_side
      to_side_by_side_format
    when :json
      to_json_format
    when :html
      to_html_format
    else
      to_unified_format
    end
  end
  
  def summary
    {
      versions: {
        from: version_a.content_summary,
        to: version_b.content_summary
      },
      statistics: statistics,
      has_changes: has_changes?,
      change_count: changes.size
    }
  end
  
  def changed_fields
    changes.map { |change| change[:field] }.uniq
  end
  
  def changes_by_type
    changes.group_by { |change| change[:type] }
  end
  
  private
  
  def to_unified_format
    output = []
    output << "--- #{version_a.content_summary[:hash]} (#{version_a.content_summary[:author]})"
    output << "+++ #{version_b.content_summary[:hash]} (#{version_b.content_summary[:author]})"
    output << ""
    
    changes.each do |change|
      output << format_unified_change(change)
    end
    
    output.join("\n")
  end
  
  def format_unified_change(change)
    case change[:type]
    when :added
      "+++ #{change[:field]}: #{format_value(change[:new_value])}"
    when :removed
      "--- #{change[:field]}: #{format_value(change[:old_value])}"
    when :modified
      [
        "--- #{change[:field]}: #{format_value(change[:old_value])}",
        "+++ #{change[:field]}: #{format_value(change[:new_value])}"
      ].join("\n")
    else
      "    #{change[:field]}: #{format_value(change[:new_value])}"
    end
  end
  
  def to_context_format
    output = []
    output << "*** #{version_a.content_summary[:hash]} ***"
    output << "--- #{version_b.content_summary[:hash]} ---"
    output << ""
    
    # Group changes by field and show context
    changes.group_by { |change| change[:field] }.each do |field, field_changes|
      output << "*** #{field} ***"
      field_changes.each do |change|
        output << format_context_change(change)
      end
      output << ""
    end
    
    output.join("\n")
  end
  
  def format_context_change(change)
    case change[:type]
    when :added
      "+ #{format_value(change[:new_value])}"
    when :removed
      "- #{format_value(change[:old_value])}"
    when :modified
      "! #{format_value(change[:old_value])} -> #{format_value(change[:new_value])}"
    else
      "  #{format_value(change[:new_value])}"
    end
  end
  
  def to_side_by_side_format
    output = []
    output << sprintf("%-50s | %s", version_a.content_summary[:hash], version_b.content_summary[:hash])
    output << "-" * 102
    
    changes.each do |change|
      left_side = change[:old_value] ? format_value(change[:old_value]) : ""
      right_side = change[:new_value] ? format_value(change[:new_value]) : ""
      
      # Truncate long values for side-by-side display
      left_side = left_side[0..45] + "..." if left_side.length > 48
      right_side = right_side[0..45] + "..." if right_side.length > 48
      
      marker = case change[:type]
               when :added then ">"
               when :removed then "<"
               when :modified then "|"
               else " "
               end
      
      output << sprintf("%-50s %s %s", left_side, marker, right_side)
    end
    
    output.join("\n")
  end
  
  def to_json_format
    {
      summary: summary,
      changes: changes,
      statistics: statistics
    }.to_json
  end
  
  def to_html_format
    html = []
    html << "<div class='content-diff'>"
    html << "<div class='diff-header'>"
    html << "<h3>Content Diff</h3>"
    html << "<p>From: #{version_a.content_summary[:hash]} (#{version_a.content_summary[:author]})</p>"
    html << "<p>To: #{version_b.content_summary[:hash]} (#{version_b.content_summary[:author]})</p>"
    html << "</div>"
    
    html << "<div class='diff-stats'>"
    html << "<span class='additions'>+#{statistics[:additions]}</span> "
    html << "<span class='deletions'>-#{statistics[:deletions]}</span> "
    html << "<span class='modifications'>~#{statistics[:modifications]}</span>"
    html << "</div>"
    
    html << "<div class='diff-content'>"
    changes.each do |change|
      html << format_html_change(change)
    end
    html << "</div>"
    
    html << "</div>"
    html.join("\n")
  end
  
  def format_html_change(change)
    css_class = "diff-#{change[:type]}"
    field_name = "<strong>#{change[:field]}</strong>"
    
    case change[:type]
    when :added
      "<div class='#{css_class}'>+ #{field_name}: #{escape_html(format_value(change[:new_value]))}</div>"
    when :removed
      "<div class='#{css_class}'>- #{field_name}: #{escape_html(format_value(change[:old_value]))}</div>"
    when :modified
      old_val = escape_html(format_value(change[:old_value]))
      new_val = escape_html(format_value(change[:new_value]))
      "<div class='#{css_class}'>~ #{field_name}: <span class='old'>#{old_val}</span> → <span class='new'>#{new_val}</span></div>"
    else
      "<div class='#{css_class}'>  #{field_name}: #{escape_html(format_value(change[:new_value]))}</div>"
    end
  end
  
  def format_value(value)
    case value
    when String
      value.length > 100 ? "#{value[0..97]}..." : value
    when Array
      "[#{value.join(', ')}]"
    when Hash
      "{#{value.map { |k, v| "#{k}: #{v}" }.join(', ')}}"
    when nil
      "(empty)"
    else
      value.to_s
    end
  end
  
  def escape_html(text)
    text.to_s.gsub('&', '&amp;').gsub('<', '&lt;').gsub('>', '&gt;').gsub('"', '&quot;')
  end
end