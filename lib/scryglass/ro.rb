# frozen_string_literal: true

module Scryglass
  # A ro is essentially a complex wrapper for an object that deals with how it is
  #   nested and displayed relative to other ros/objects.
  class Ro
    using ClipStringRefinement

    attr_accessor :key, :value, :val_type,
                  :key_string, :value_string, :lens_strings,
                  :key_value_relationship_indicator, :special_sub_ro_type,
                  :wrappers

    attr_accessor :has_cursor, :expanded,
                  :parent_ro, :sub_ros,
                  :depth, :index, :scry_session

    WRAPPER_TYPES = {
      'Hash' => '{}',
      'Array' => '[]',
      'ActiveRecord_Relation' => '<>',
      'ActiveRecord_Associations_CollectionProxy' => '‹›',
    }.freeze

    def initialize(scry_session:,
                   val:,
                   val_type:,
                   parent_ro:,
                   key:,
                   depth:,
                   key_value_relationship_indicator: false,
                   special_sub_ro_type: nil)
      key_clip_length = Scryglass.config.tree_view_key_string_clip_length
      value_clip_length = Scryglass.config.tree_view_value_string_clip_length

      self.has_cursor = false
      self.expanded = false

      self.key_value_relationship_indicator = key_value_relationship_indicator

      ## Open up ViewWrappers and grab their objects and their custom strings
      if key.class == Scryglass::ViewWrapper
        self.key_string = key.to_s.clip_at(key_clip_length)
        self.key = key.model
      else
        # Note: `.inspect` may return *true newlines* for objects with a custom
        #   `.inspect`, which will sabotage scry's display, so we gsub thusly:
        self.key_string = key.inspect
                             .gsub("\n", "\\n")
                             .clip_at(key_clip_length)
        self.key = key
      end
      if val.class == Scryglass::ViewWrapper
        self.value_string = val.to_s.clip_at(value_clip_length)
        self.value = val.model
      else
        # Note: `.inspect` may return *true newlines* for objects with a custom
        #   `.inspect`, which will sabotage scry's display, so we gsub thusly:
        self.value_string = val.inspect
                               .gsub("\n", "\\n")
                               .clip_at(value_clip_length)
        self.value = val
      end

      self.sub_ros = []
      self.parent_ro = parent_ro
      self.val_type = val_type
      self.special_sub_ro_type = special_sub_ro_type
      self.depth = depth
      self.wrappers = WRAPPER_TYPES[value.class.to_s.split('::').last] || '?¿'

      self.lens_strings = { key: {}, value: {} }

      self.index = scry_session.all_ros.count
      scry_session.all_ros << self
      self.scry_session = scry_session
    end

    def top_ro?
      parent_ro.nil?
    end

    def to_s
      value_indicator =
        bucket? ? bucket_indicator : value_string

      key_value_spacer =
        key_value_pair? ? key_string + key_value_relationship_indicator : ''
        dot = '•'
        dot = "\e[36m#{dot}\e[00m" if Scryglass.config.dot_coloring # cyan then back to *default*
      special_sub_ro_expansion_indicator =
        any_special_sub_ros? && !expanded ? dot : ' '

      left_fill_string + special_sub_ro_expansion_indicator +
        key_value_spacer + value_indicator
    end

    def next_visible_ro_down
      raise '(Must be called on a "visible" row)' unless visible?

      first_sub_ro = sub_ros.first
      return first_sub_ro if expanded && first_sub_ro
      return nil if top_ro?

      next_sibling = sibling_down
      return next_sibling if next_sibling

      # Note: since this ro is known to be visible, all its parents are, too.
      upward_feeler_ro = self.parent_ro
      parents_lower_sibling = upward_feeler_ro.sibling_down
      until parents_lower_sibling || upward_feeler_ro.top_ro?
        upward_feeler_ro = upward_feeler_ro.parent_ro
        parents_lower_sibling = upward_feeler_ro.sibling_down
      end

      parents_lower_sibling
    end

    def next_visible_ro_up
      raise '(Must be called on a "visible" row)' unless visible?

      return nil if top_ro?

      next_sibling = sibling_up
      return next_sibling if next_sibling

      # Note: since this ro is known to be visible, all its parents are, too.
      parent_ro
    end

    def current_subject
      send(scry_session.current_subject_type)
    end

    def iv_sub_ros
      sub_ros.select { |sub_ro| sub_ro.special_sub_ro_type == :iv }
    end

    def ar_sub_ros
      sub_ros.select { |sub_ro| sub_ro.special_sub_ro_type == :ar }
    end

    def enum_sub_ros
      sub_ros.select { |sub_ro| sub_ro.special_sub_ro_type == :enum }
    end

    # (Used for recalculate_indeces after new Ros have been injected)
    def next_ro_without_using_index
      return sub_ros.first if sub_ros.first
      return sibling_down if sibling_down
      return nil if top_ro?

      upward_feeler_ro = self
      until upward_feeler_ro.sibling_down || upward_feeler_ro.top_ro?
        upward_feeler_ro = upward_feeler_ro.parent_ro
      end
      upward_feeler_ro.sibling_down
    end

    def sibling_down
      return nil if top_ro?

      siblings = parent_ro.sub_ros
      self_index = siblings.index(self)
      return nil if self == siblings.last

      siblings[self_index + 1]
    end

    def sibling_up
      return nil if top_ro?

      siblings = parent_ro.sub_ros
      self_index = siblings.index(self)
      return nil if self_index.zero?

      siblings[self_index - 1]
    end

    ## This exists so that an easy *unordered array match* can occur elsewhere.
    def <=>(other)
      unless self.class == other.class
        raise ArgumentError, "Comparison of #{self.class} with #{other.class}"
      end

      object_id <=> other.object_id
    end


    def visible?
      return true if top_ro?

      scanning_ro = parent_ro
      until scanning_ro.top_ro? || !scanning_ro.expanded
        scanning_ro = scanning_ro.parent_ro
      end

      scanning_ro.expanded
    end

    def bucket?
      val_type == :bucket
    end

    def nugget?
      val_type == :nugget
    end

    def key_value_pair?
      !!key_value_relationship_indicator
    end

    def special_sub_ros
      sub_ros.select(&:special_sub_ro_type)
    end

    private

    def normal_sub_ros
      sub_ros.reject(&:special_sub_ro_type)
    end

    def any_normal_sub_ros?
      !!sub_ros.find { |ro| !ro.special_sub_ro_type }
    end

    def any_special_sub_ros?
      !!sub_ros.last&.special_sub_ro_type
    end

    def bucket_indicator
      return wrappers unless any_normal_sub_ros?

      if expanded
        wrappers[0]
      else
        # Number of dots indicating order of magnitude for Enumerable's count:
        #   Turning this off (the consistent three dots is more like an ellipsis,
        #   communicating with a solid preexisting symbol), but keeping the idea here:
        #     sub_ros_order_of_magnitude = normal_sub_ros.count.to_s.length
        #     wrappers.dup.insert(1, '•' * sub_ros_order_of_magnitude)
        dots = '•••'
        dots = "\e[36m#{dots}\e[00m" if Scryglass.config.dot_coloring # cyan then back to *default*
        wrappers.dup.insert(1, dots)
      end
    end

    def left_fill_string
      left_fill = if has_cursor
                    cursor_string
                  else
                    ' ' * cursor_length
                  end

      if scry_session.special_command_targets.any? && scry_session.special_command_targets.map(&:index).include?(index)
        left_fill[-2..-1] = '->'
      end
      left_fill
    end

    def cursor_length
      tab_length = Scryglass.config.tab_length

      consistent_margin = [4 - tab_length, 0].max

      (tab_length * depth) + consistent_margin
    end

    def cursor_char
      Scryglass::Session::CURSOR_CHARACTER
    end

    def cursor_string
      cursor = cursor_char * cursor_length

      cursor[0] = enum_status_char
      cursor[1] = iv_status_char
      cursor[2] = ar_status_char

      cursor
    end

    def enum_status_char
      enum_worth_checking = nugget? && value.is_a?(Enumerable)
      return cursor_char unless enum_worth_checking

      enum_check = Scryglass::Ro.safe_quick_check do
        # value.any? Can take an eternity for a few specific objects, breaking
        #   the session when the cursor passes over them. Also breaks on read-
        #   locked IO objects.
        enum_sub_ros.empty? && value.any?
      end

      return 'X' if enum_check.nil?

      return '(' if enum_check

      cursor_char
    end

    def iv_status_char
      return cursor_char unless iv_sub_ros.empty?

      iv_check = Scryglass::Ro.safe_quick_check do
        value.instance_variables.any?
      end

      return 'X' if iv_check.nil?

      return '@' if iv_check

      cursor_char
    end

    def ar_status_char
      return cursor_char unless ar_sub_ros.empty?

      iv_check = Scryglass::Ro.safe_quick_check do
        # Currently, this will always indicate hidden secrets if the object, with
        #   the given Scryglass config, doesn't yield any ar_sub_ros upon trying '.'
        value.class.respond_to?(:reflections) # TODO: maybe dig more here?
      end

      return 'X' if iv_check.nil?

      return '·' if iv_check

      cursor_char
    end

    class << self
      def safe_quick_check
        begin
          Timeout.timeout(0.05) do
            yield
          end
        rescue
          nil
        end
      end
    end
  end
end
