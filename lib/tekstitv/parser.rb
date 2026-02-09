# frozen_string_literal: true

require 'json'
require 'cgi'

module TekstiTV
  # Parses the YLE teletext JSON into printable text lines.
  module Parser
    def self.parse_content(body)
      data = JSON.parse(body)
      page = data.dig('teletext', 'page') || {}
      subpages = page['subpage']

      if subpages.is_a?(Array) && !subpages.empty?
        content = subpages.first['content']
        return normalize_content(content)
      end

      content = page['content']
      normalize_content(content)
    rescue JSON::ParserError
      'Error: Invalid JSON response'
    end

    def self.normalize_content(content)
      return 'No content available.' if content.nil?

      return content.join("\n") if content.is_a?(Array) && content.all? { |c| c.is_a?(String) }

      if content.is_a?(Array)
        entry = content.find { |c| c.is_a?(Hash) && c['line'] } ||
                content.find { |c| c.is_a?(Hash) && c['type'] == 'text' } ||
                content.find { |c| c.is_a?(Hash) }
        return extract_lines(entry) if entry.is_a?(Hash)
        return content.map(&:to_s).join("\n")
      end

      return extract_lines(content) if content.is_a?(Hash)

      content.to_s
    end

    def self.extract_lines(entry)
      lines = entry['line']
      return entry.to_s if lines.nil?

      return lines.join("\n") if lines.is_a?(Array) && lines.all? { |l| l.is_a?(String) }

      if lines.is_a?(Array)
        indexed = lines.map.with_index do |line, idx|
          num = line.is_a?(Hash) ? line['number'].to_i : 0
          text = extract_line_text(line)
          num = idx + 1 if num <= 0
          [num, text]
        end

        max = indexed.map(&:first).max || 0
        output = Array.new(max, '')
        indexed.each do |num, text|
          next if num <= 0
          output[num - 1] = text
        end
        return output.join("\n")
      end

      entry.to_s
    end

    def self.extract_line_text(line)
      return html_to_text(line) unless line.is_a?(Hash)

      raw = line['text'] || line['Text'] || line['value'] || line['line'] || line['content'] || ''
      html_to_text(raw.to_s)
    end

    def self.html_to_text(text)
      unescaped = CGI.unescapeHTML(text.to_s)
      unescaped.gsub(/<[^>]+>/, '').gsub(/\u00A0/, ' ')
    end
  end
end
