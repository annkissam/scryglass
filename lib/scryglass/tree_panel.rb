# frozen_string_literal: true

module Scryglass
  class TreePanel < Scryglass::ViewPanel
    using ClipStringRefinement
    using AnsilessStringRefinement

    def slide_view_to_cursor
      cursor_tracking = Scryglass.config.cursor_tracking

      current_ro = scry_session.current_ro

      ## Here we calculate the ro_in_center_of_view:
      visible_ros_from_center = (body_screen_height / 2)
      scanning_ro = top_visible_ro_of_tree_view
      visible_ros_from_center.times do
        next_visible_ro = scanning_ro.next_visible_ro_down
        scanning_ro = next_visible_ro if next_visible_ro
      end
      ro_in_center_of_view = scanning_ro

      ## We don't need to do anything if current_ro is already in the center:
      relative_index = current_ro.index - ro_in_center_of_view.index
      return if relative_index.zero?

      ## Establish the number of visible ros between current_ro and center point
      index_span = [ro_in_center_of_view.index, current_ro.index]
      ros_between_them = scry_session.all_ros[index_span.min...index_span.max]
      visible_count_between_them = ros_between_them.count(&:visible?)

      direction = :up   if relative_index.negative?
      direction = :down if relative_index.positive?

      ## If view movement is needed, and how far, depends on the tracking config
      case cursor_tracking
      when :flexible_range
        flex_range = body_screen_height / 3
        if visible_count_between_them >= flex_range
          distance_to_flex_range = visible_count_between_them - flex_range
          move_view_up(distance_to_flex_range)   if direction == :up
          move_view_down(distance_to_flex_range) if direction == :down
        end
      when :dead_center
        move_view_up(visible_count_between_them)   if direction == :up
        move_view_down(visible_count_between_them) if direction == :down
      end
    end

    private

    def uncut_body_string
      body_array_from_ro(top_visible_ro_of_tree_view).join("\n")
    end

    def uncut_header_string
      _screen_height, screen_width = $stdout.winsize
      header_string = "Press '?' for controls\n".rjust(screen_width, ' ') +
                      '·' * screen_width
      if scry_session.special_command_targets.any?
        special_targets_message = "  (Next command will apply to all selected rows)"
        header_string[0...special_targets_message.length] = special_targets_message
      end
      header_string
    end

    def visible_body_slice(uncut_body_string)
      _screen_height, screen_width = $stdout.winsize

      split_lines = uncut_body_string.split("\n")
      sliced_lines = split_lines.map do |string|
        ansi_length = string.length - string.ansiless.length
        slice_length = screen_width + ansi_length
        string[current_view_coords[:x], slice_length] || '' # If I don't want to
        #   opacify here, I need to account for nils when the view is fully
        #   beyond the shorter lines.
      end

      sliced_lines.join("\n")
    end

    def recalculate_y_boundaries
      self.y_boundaries = 0...scry_session.all_ros.select(&:visible?).count
    end

    def recalculate_x_boundaries
      _screen_height, screen_width = $stdout.winsize

      split_lines = uncut_body_string.split("\n")
      length_of_longest_line = split_lines.map(&:length).max
      max_line_length = [length_of_longest_line, screen_width].max
      self.x_boundaries = 0...max_line_length
    end

    def top_visible_ro_of_tree_view
      top_ro = scry_session.top_ro

      scanning_ro = top_ro
      top_ros = [scanning_ro]
      until top_ros.count > current_view_coords[:y] || scanning_ro.next_visible_ro_down.nil? #I shouldn't need this?
        scanning_ro = scanning_ro.next_visible_ro_down
        top_ros << scanning_ro
      end
      top_ros.last
    end

    def body_array_from_ro(ro)
      y, _x = $stdout.winsize
      non_header_view_size = y - visible_header_string.split("\n").count
      display_array = []

      scanning_ro = ro
      display_array << scanning_ro.to_s

      while scanning_ro.next_visible_ro_down && display_array.count < non_header_view_size
        scanning_ro = scanning_ro.next_visible_ro_down
        display_array << scanning_ro.to_s
      end

      display_array
    end
  end
end
