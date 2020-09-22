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
        self.key_string = key.inspect.clip_at(key_clip_length)
        self.key = key
      end
      if val.class == Scryglass::ViewWrapper
        self.value_string = val.to_s.clip_at(value_clip_length)
        self.value = val.model
      else
        self.value_string = val.inspect.clip_at(value_clip_length)
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

      special_sub_ro_expansion_indicator =
        special_sub_ros.any? && !expanded ? '•' : ' '

      left_fill_string + special_sub_ro_expansion_indicator +
        key_value_spacer + value_indicator
    end

    def next_visible_ro_down
      subsequent_ros = scry_session.all_ros[(index + 1)..-1]
      subsequent_ros.find(&:visible?)
    end

    def next_visible_ro_up
      preceding_ros = scry_session.all_ros[0...index]
      preceding_ros.reverse.find(&:visible?)
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
      return nil if top_ro?
      return sibling_down if sibling_down

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

    def bucket_indicator
      if expanded && normal_sub_ros.any?
        wrappers[0]
      elsif normal_sub_ros.any?
        # Number of dots indicating order of magnitude for Enumerable's count:
        #   Turning this off (the consistent three dots is more like an ellipsis,
        #   communicating with a solid preexisting symbol), but keeping the idea here:
        #     sub_ros_order_of_magnitude = normal_sub_ros.count.to_s.length
        #     wrappers.dup.insert(1, '•' * sub_ros_order_of_magnitude)
        wrappers.dup.insert(1, '•••')
      else
        wrappers
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

    def cursor_string
      cursor = Scryglass::Session::CURSOR_CHARACTER * cursor_length

      cursor[0] = '(' if has_enum_secrets?
      cursor[1] = '@' if has_iv_secrets?
      cursor[2] = '·' if has_ar_secrets?

      cursor
    end

    def has_enum_secrets?
      nugget? && value.is_a?(Enumerable) &&
                 value.any? &&
                 enum_sub_ros.empty?
    end

    def has_iv_secrets?
      value.instance_variables.any? && iv_sub_ros.empty?
    end

    # Currently, this will always indicate hidden secrets if the object, with
    #   the given Scryglass config, doesn't yield any ar_sub_ros upon trying '.'
    def has_ar_secrets?
      value.class.respond_to?(:reflections) && ar_sub_ros.empty?
    end
  end
end
