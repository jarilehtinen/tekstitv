# frozen_string_literal: true

require_relative 'env'
require_relative 'client'
require_relative 'ui'

module TekstiTV
  # App lifecycle and navigation loop.
  class App
    def run
      Env.load!
      Env.ensure_credentials!

      current_page = '100'
      history = []
      text_cache = {}
      appendix_lines = load_appendix(text_cache)
      ui = UI.new
      ui.start

      begin
        loop do
          appendix_lines ||= load_appendix(text_cache)
          content = Client.fetch_page(current_page, cache: text_cache, allow_api: false)

          ui.render(page: current_page, content: content, appendix_lines: appendix_lines)

          action = ui.prompt_page(page: current_page)
          break if action.nil?

        if action == :back
          prev = history.pop
          current_page = prev if prev
          next
        end

        if action == :refresh
          ui.show_loading(page: current_page)
          Client.refresh_page(current_page, cache: text_cache)
          next
        end

        if action == :prev || action == :next
          history << current_page
          new_page = current_page.to_i
          new_page += (action == :next ? 1 : -1)
          new_page = 100 if new_page < 100
          new_page = 999 if new_page > 999
          ui.show_loading(page: format('%03d', new_page))
          current_page = advance_to_data(format('%03d', new_page), text_cache)
          next
        end

        if action.match?(/^\d{3}$/)
          history << current_page
          ui.show_loading(page: action)
          current_page = advance_to_data(action, text_cache, force_refresh_first: true)
        end
        end
      ensure
        ui.shutdown
      end
    end

    private

    def load_appendix(cache)
      content = Client.fetch_page('100', cache: cache, allow_api: false)
      return nil if content.nil?

      lines = content.to_s.split("\n")
      idx = lines.index { |line| line.match?(/\b101\b/) }
      return nil unless idx

      appendix = lines[idx..].map(&:rstrip)
      appendix.pop while appendix.last&.strip&.empty?

      items = appendix.flat_map do |line|
        leading = line.scan(/(?:^|\s)(\d{3})\s+([^0-9]+?)(?=(\s\d{3}\s)|$)/)
        trailing = line.scan(/([^0-9]{3,}?)\s+(\d{3})(?:-\d{3})?$/).map { |title, num| [num, title, nil, :special] }
        leading + trailing
      end
      return nil if items.empty?

      items.map do |num, title, _, kind|
        { number: num, title: title.strip, kind: kind }
      end
    end

    # Fetches starting at page_number and skips forward until content exists.
    def advance_to_data(page_number, cache, force_refresh_first: false)
      page = page_number
      attempts = 0

      while attempts < 900
        content = if force_refresh_first && attempts.zero?
                    Client.refresh_page(page, cache: cache)
                  else
                    Client.fetch_page(page, cache: cache, allow_api: true)
                  end
        return page unless content_empty?(content)

        next_page = page.to_i + 1
        return page if next_page > 999

        page = format('%03d', next_page)
        attempts += 1
      end

      page_number
    end

    # Treat empty/placeholder content as missing data.
    def content_empty?(content)
      return true if content.nil?

      text = content.to_s
      return true if text.start_with?('HTTP ')
      return true if text.start_with?('Error:')
      text = text.gsub(/\s+/, '')
      return true if text.empty?

      # Consider pages with no letters as empty to skip placeholder pages.
      return true unless content.to_s.match?(/[A-Za-zÅÄÖåäö]/)

      text = content.to_s.strip
      return true if text.empty?
      return true if text == 'No content available.'

      false
    end
  end

  def self.run
    App.new.run
  end
end
