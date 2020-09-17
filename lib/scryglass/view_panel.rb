# frozen_string_literal: true

module Scryglass
  class ViewPanel
    using AnsilessStringRefinement

    attr_accessor :current_view_coords, :x_boundaries, :y_boundaries
    attr_accessor :scry_session

    def initialize(scry_session:)
      self.scry_session = scry_session
      self.current_view_coords = { x: 0, y: 0 }

      recalculate_boundaries
    end

    def ensure_correct_view_coords
      _screen_height, screen_width = $stdout.winsize
      top_boundary    = y_boundaries.min
      bottom_boundary = y_boundaries.max
      left_boundary   = x_boundaries.min
      right_boundary  = x_boundaries.max

      ## Snap View, Vertical
      screen_bottom_index = (body_screen_height - 1)
      top_edge_of_view = current_view_coords[:y]
      bottom_edge_of_view = current_view_coords[:y] + screen_bottom_index
      if bottom_edge_of_view > bottom_boundary
        current_view_coords[:y] = [bottom_boundary - screen_bottom_index, 0].max
      elsif top_edge_of_view < top_boundary
        current_view_coords[:y] = top_boundary
      end

      ## Snap View, Horizontal
      screen_right_edge_index = (screen_width - 1)
      left_edge_of_view = current_view_coords[:x]
      right_edge_of_view = current_view_coords[:x] + screen_right_edge_index
      if !x_boundaries.include?(left_edge_of_view)
        current_view_coords[:x] = left_boundary
      elsif !x_boundaries.include?(right_edge_of_view)
        current_view_coords[:x] = right_boundary - screen_right_edge_index
      end
    end

    def move_view_up(distance)
      current_view_coords[:y] -= distance
    end

    def move_view_down(distance)
      current_view_coords[:y] += distance
    end

    def move_view_left(distance)
      current_view_coords[:x] -= distance
    end

    def move_view_right(distance)
      current_view_coords[:x] += distance
    end

    def screen_string
      Hexes.opacify_screen_string(visible_header_string + "\n" + visible_body_string)
    end

    def recalculate_boundaries
      recalculate_y_boundaries
      recalculate_x_boundaries
    end

    def visible_header_string
      visible_header_slice(uncut_header_string)
    end

    def visible_body_string
      visible_body_slice(uncut_body_string)
    end

    private

    def visible_header_slice(uncut_header_string)
      Hexes.simple_screen_slice(uncut_header_string)
    end

    def body_screen_height
      screen_height, _screen_width = $stdout.winsize
      # It would be more efficient, but technically overall less accurate, to
      #   avoid recalculating visible_header_string here (and everywhere that calls this)
      screen_height - visible_header_string.split("\n").count
    end
  end
end
