# frozen_string_literal: true

require 'curses'

module TekstiTV
  # Curses-based UI with borders, title, and centered content block.
  class UI
    def start
      ENV['ESCDELAY'] = '25'
      print "\e[?1049h"

      Curses.init_screen
      Curses.curs_set(0)
      Curses.start_color
      Curses.use_default_colors
      Curses.init_pair(1, Curses::COLOR_WHITE, Curses::COLOR_BLACK)
      Curses.init_pair(2, Curses::COLOR_BLACK, Curses::COLOR_WHITE)
      Curses.init_pair(3, Curses::COLOR_CYAN, Curses::COLOR_BLACK)
      Curses.init_pair(4, Curses::COLOR_YELLOW, Curses::COLOR_BLACK)

      Curses.stdscr.keypad(true)
      Curses.noecho
    end

    def shutdown
      Curses.close_screen
      print "\e[?1049l"
    rescue StandardError
      print "\e[?1049l"
    end

    def render(page:, content:, appendix_lines:)
      Curses.clear

      box_height = [Curses.lines - 2, 3].max
      box_width = [Curses.cols, 10].max
      draw_box(box_height, box_width, 0, 0)
      draw_title("TEKSTI-TV  Sivu #{page}", box_width)

      inner_width = box_width - 2
      inner_height = box_height - 1

      content_width = [(inner_width * 0.7).floor, 40].max
      main_text = strip_appendix_from_text(content.to_s, appendix_lines, page)
      main_text = inject_current_page_number(main_text, page)
      lines = prepare_lines(main_text, content_width)

      appendix_height = 0
      has_special_appendix_items = false
      if appendix_lines && !appendix_lines.empty?
        normal_items, special_items = split_appendix_items(appendix_lines)
        has_special_appendix_items = special_items.any?
        rows_needed = appendix_rows_needed(
          normal_items: normal_items,
          special_items: special_items,
          inner_width: inner_width
        )
        max_height = [inner_height - 2, 3].max
        appendix_height = [rows_needed, max_height].min
      end
      gap = if appendix_height.positive?
              has_special_appendix_items ? 1 : 2
            else
              0
            end
      bottom_padding = appendix_height.positive? ? 1 : 0
      content_height = [inner_height - appendix_height - gap - bottom_padding, 1].max

      render_block(
        lines,
        inner_width: inner_width,
        inner_height: content_height,
        content_width: content_width,
        offset_y: 1,
        offset_x: 1,
        preserve_indent: false
      )

      if appendix_height.positive?
        render_appendix(
          appendix_lines,
          inner_width: inner_width,
          height: appendix_height,
          offset_y: 1 + content_height + gap,
          offset_x: 1
        )
      end

      Curses.refresh
    end

    def prompt_page(page:)
      Curses.setpos(Curses.lines - 1, 0)
      Curses.clrtoeol
      Curses.attron(Curses.color_pair(3)) { Curses.addstr("Sivu #{page} > ") }
      Curses.refresh

      input = String.new
      Curses.curs_set(1)
      Curses.noecho

      loop do
        ch = Curses.getch
        next if ch.nil?

        if ch.is_a?(Integer)
          return :back if ch == 27
          if ch == 10 || ch == 13
            break
          elsif ch == 127 || ch == 8
            input = input[0..-2]
          elsif ch == Curses::Key::LEFT
            return :prev
          elsif ch == Curses::Key::RIGHT
            return :next
          elsif ch == 114 || ch == 82
            return :refresh
          elsif ch == 104 || ch == 72
            return '100'
          elsif ch >= 48 && ch <= 57
            input << ch.chr if input.length < 3
          end
        else
          return :back if ch == "\e"
          if ch == "\n" || ch == "\r"
            break
          elsif ch.downcase == 'a'
            return :prev
          elsif ch.downcase == 'd'
            return :next
          elsif ch.downcase == 'r'
            return :refresh
          elsif ch.downcase == 'h'
            return '100'
          elsif ch == "\b"
            input = input[0..-2]
          elsif ch =~ /\d/
            input << ch if input.length < 3
          elsif ch.downcase == 'q'
            return nil
          end
        end

        Curses.setpos(Curses.lines - 1, 0)
        Curses.clrtoeol
        Curses.attron(Curses.color_pair(3)) { Curses.addstr("Sivu #{page} > #{input}") }
        Curses.refresh
      end

      input = input.strip
      return nil if input.downcase == 'q'

      if input.match?(/^\d{3}$/)
        input
      else
        page
      end
    rescue Interrupt
      nil
    ensure
      Curses.curs_set(0)
    end

    def show_loading(page:)
      Curses.setpos(Curses.lines - 1, 0)
      Curses.clrtoeol
      Curses.attron(Curses.color_pair(3)) { Curses.addstr("Sivu #{page} > (ladataan...)") }
      Curses.refresh
    end

    def draw_box(h, w, y, x)
      Curses.attron(Curses.color_pair(1)) do
        Curses.setpos(y, x)
        Curses.addstr('┌')
        Curses.setpos(y, x + w - 1)
        Curses.addstr('┐')
        Curses.setpos(y + h, x)
        Curses.addstr('└')
        Curses.setpos(y + h, x + w - 1)
        Curses.addstr('┘')

        Curses.setpos(y, x + 1)
        Curses.addstr('─' * (w - 2))
        Curses.setpos(y + h, x + 1)
        Curses.addstr('─' * (w - 2))

        (y + 1..(y + h - 1)).each do |this_y|
          Curses.setpos(this_y, x)
          Curses.addstr('│')
          Curses.setpos(this_y, x + w - 1)
          Curses.addstr('│')
        end
      end
    end

    def draw_title(text, width)
      title = " #{text} "
      x = [0, (width / 2) - (title.length / 2)].max
      Curses.setpos(0, x)
      Curses.attron(Curses.color_pair(2)) { Curses.addstr(title) }
    end

    def draw_colored_line(y, x, text)
      Curses.setpos(y, x)

      idx = 0
      while idx < text.length
        match = /(\b\d{1,2}\.\d{2}\b|\b\d{3}\b)/.match(text, idx)
        if match.nil?
          Curses.attron(Curses.color_pair(1)) { Curses.addstr(text[idx..]) }
          break
        end

        if match.begin(0) > idx
          Curses.attron(Curses.color_pair(1)) { Curses.addstr(text[idx...match.begin(0)]) }
        end

        token = match[0]
        if token.include?('.')
          Curses.attron(Curses.color_pair(4)) { Curses.addstr(token) }
        else
          if token.to_i >= 100
            Curses.attron(Curses.color_pair(3)) { Curses.addstr(token) }
          else
            Curses.attron(Curses.color_pair(1)) { Curses.addstr(token) }
          end
        end

        idx = match.end(0)
      end
    end

    def render_block(lines, inner_width:, inner_height:, content_width:, offset_y:, offset_x:, preserve_indent:)
      lines = lines.first(inner_height)
      lines.fill('', lines.length...inner_height)

      # Trim empty rows for vertical centering.
      trimmed = lines.map { |l| l.to_s.rstrip }
      trimmed.shift while trimmed.first&.empty?
      trimmed.pop while trimmed.last&.empty?
      trimmed = [''] if trimmed.empty?

      aligned = if preserve_indent
                  trimmed.map { |l| l.to_s[0, content_width] }
                else
                  trimmed.map { |l| l.lstrip[0, content_width] }
                end
      block_width = [aligned.map(&:length).max || 0, content_width].min
      block_height = aligned.length
      left_pad = [(inner_width - block_width) / 2, 0].max
      top_pad = [(inner_height - block_height) / 2, 0].max

      start_y = offset_y
      start_x = offset_x
      inner_height.times do |row|
        Curses.setpos(start_y + row, 1)
        Curses.attron(Curses.color_pair(1)) { Curses.addstr(' ' * inner_width) }
      end

      heading_indices = []
      unless preserve_indent
        heading_indices = aligned.each_index.select { |i| heading_line?(aligned[i]) }.first(2)
      end

      if heading_indices.empty?
        teksti_idx = aligned.index { |line| line.to_s.strip.casecmp('teksti-tv').zero? }
        heading_indices = [teksti_idx].compact if teksti_idx
      end

      aligned.each_with_index do |line, idx|
        y = start_y + top_pad + idx
        next if y >= start_y + inner_height

        text = line.to_s[0, inner_width - left_pad]
        if heading_indices[0] == idx
          draw_heading_line(y, start_x + left_pad, text.lstrip, 4)
        elsif heading_indices[1] == idx
          draw_heading_line(y, start_x + left_pad, text.lstrip, 1, bold: true)
        else
          draw_colored_line(y, start_x + left_pad, preserve_indent ? text : text.lstrip)
        end
      end
    end

    def render_appendix(items, inner_width:, height:, offset_y:, offset_x:)
      return if items.nil? || items.empty?

      usable_width = [inner_width - 2, 40].max
      usable_width = [usable_width, inner_width].min

      normal_items, special_items = split_appendix_items(items)

      cols = 3
      cols = [cols, normal_items.length].min
      cols = 1 if cols <= 0
      col_width = usable_width / cols
      rows = normal_items.empty? ? 0 : (normal_items.length.to_f / cols).ceil
      rows = [rows, height].min

      start_y = offset_y
      start_x = offset_x + 2
      height.times do |row|
        Curses.setpos(start_y + row, 1)
        Curses.attron(Curses.color_pair(1)) { Curses.addstr(' ' * inner_width) }
      end

      normal_items.first(rows * cols).each_with_index do |item, idx|
        r = idx / cols
        c = idx % cols
        y = start_y + r
        x = start_x + (c * col_width)
        next if y >= start_y + height

        label = "#{item[:number]} #{item[:title]}"
        label = label[0, col_width - 1]
        draw_colored_line(y, x, label)
      end

      special_start = start_y + rows
      if special_items.any?
        special_labels = special_items.map { |item| "#{item[:number]} #{item[:title]}" }
        if special_start < start_y + height
          positions = special_column_positions(labels: special_labels, start_x: start_x, col_width: col_width, gap: 0, max_width: usable_width)
          if positions
            positions.each do |pos|
              draw_colored_line(special_start, pos[:x], pos[:label])
            end
          else
            special_items.each_with_index do |item, idx|
              y = special_start + idx
              break if y >= start_y + height

              label = "#{item[:number]} #{item[:title]}"
              draw_colored_line(y, start_x, label)
            end
          end
        end
      end
    end

    def split_appendix_items(items)
      normal = []
      special = []

      items.each do |item|
        if item[:kind] == :special
          special << item
        else
          normal << item
        end
      end

      [normal, special]
    end

    def appendix_rows_needed(normal_items:, special_items:, inner_width:)
      usable_width = [inner_width - 2, 40].max
      usable_width = [usable_width, inner_width].min

      cols = [3, normal_items.length].min
      cols = 1 if cols <= 0

      normal_rows = normal_items.empty? ? 0 : (normal_items.length.to_f / cols).ceil
      return normal_rows if special_items.empty?

      col_width = usable_width / cols
      labels = special_items.map { |item| "#{item[:number]} #{item[:title]}" }
      fits_single_special_row = special_column_positions(
        labels: labels,
        start_x: 0,
        col_width: col_width,
        gap: 0,
        max_width: usable_width
      )

      normal_rows + (fits_single_special_row ? 1 : special_items.length)
    end

    def heading_line?(line)
      text = line.to_s.strip
      return false if text.empty?
      return false if text =~ /^\d{3}\b/
      return false if text.end_with?('.')

      true
    end

    def draw_heading_line(y, x, text, color_pair, bold: false)
      Curses.setpos(y, x)
      attrs = Curses.color_pair(color_pair)
      attrs |= Curses::A_BOLD if bold
      Curses.attron(attrs) { Curses.addstr(text) }
    end

    def special_column_positions(labels:, start_x:, col_width:, gap:, max_width:)
      return nil if labels.empty?

      positions = []
      labels.each_with_index do |label, idx|
        return nil if label.length > col_width

        x = start_x + (idx * (col_width + gap))
        return nil if (x - start_x) + label.length > max_width

        positions << { x: x, label: label }
      end

      positions
    end

    def strip_appendix_from_text(text, appendix_lines, page)
      return text if appendix_lines.nil? || appendix_lines.empty?
      return text unless page == '100'

      lines = text.split("\n")
      marker = appendix_lines.first[:number].to_s
      idx = lines.index { |line| line.to_s.include?(marker) }
      return text unless idx

      lines[0...idx].join("\n")
    end

    def inject_current_page_number(text, page)
      return text unless page.match?(/^\d{3}$/)

      lines = text.split("\n")
      return text if lines.any? { |line| line.to_s.strip.start_with?(page) }

      idx = lines.index { |line| line =~ /^\s+[A-ZÅÄÖ].*\b\d{3}\b/ }
      return text unless idx

      lines[idx] = lines[idx].sub(/^\s+/, "#{page} ")
      lines.join("\n")
    end

    def wrap_lines(text, width)
      return [''] if text.to_s.empty?

      lines = []
      text.to_s.split("\n").each do |raw|
        line = raw.dup
        while line.length > width
          slice = line.slice(0, width)
          break_at = slice.rindex(/\s/)
          if break_at && break_at > 0
            lines << slice[0...break_at]
            line = line[break_at..].lstrip
          else
            lines << line.slice!(0, width)
          end
        end
        lines << line unless line.nil?
      end
      lines
    end

    def prepare_lines(text, width)
      raw_lines = text.to_s.split("\n")
      return wrap_lines(text, width) if raw_lines.empty?

      # Collapse repeated blank lines in the main content view.
      normalized = []
      raw_lines.each do |line|
        if line.strip.empty?
          next if normalized.last.to_s.strip.empty?
          normalized << ''
        else
          normalized << line
        end
      end

      number_lines = normalized.count { |line| line.match?(/\b\d{3}\b/) }
      ratio = number_lines.to_f / [normalized.length, 1].max

      # Avoid reflow on index-style pages with lots of page numbers.
      return wrap_lines(normalized.join("\n"), width) if ratio >= 0.1 || number_lines >= 3

      reflow_text(normalized, width)
    end

    def reflow_text(lines, width)
      paragraphs = []
      current = []

      lines.each do |line|
        stripped = line.strip
        if stripped.empty?
          paragraphs << current unless current.empty?
          paragraphs << []
          current = []
        else
          current << stripped
        end
      end
      paragraphs << current unless current.empty?

      output = []
      paragraphs.each do |para|
        if para.empty?
          output << ''
          next
        end

        text = para.join(' ')
        output.concat(wrap_lines(text, width))
      end

      output
    end
  end
end
