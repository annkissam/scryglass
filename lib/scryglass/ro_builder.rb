# frozen_string_literal: true

module Scryglass
  module RoBuilder
    private

    def roify(object,
              parent_ro:,
              key: nil,
              key_value_relationship_indicator: false,
              special_sub_ro_type: nil,
              depth:)

      given_ro_params = {
        key: key,
        key_value_relationship_indicator: key_value_relationship_indicator,
        special_sub_ro_type: special_sub_ro_type,
        parent_ro: parent_ro,
        depth: depth
      }

      object_is_an_activerecord_enum = %w[ActiveRecord_Relation
                                          ActiveRecord_Associations_CollectionProxy]
                                       .include?(object.class.to_s.split('::').last)
      ro =
        if object.class == Hash
          roify_hash(object, **given_ro_params)
        elsif object.class == Array
          roify_array(object, **given_ro_params)
        elsif object_is_an_activerecord_enum
          roify_ar_relation(object, **given_ro_params)
        else
          Scryglass::Ro.new(
            scry_session: self,
            val: object,
            val_type: :nugget,
            **given_ro_params
          )
        end

      ro
    end

    def roify_array(array,
                    key:,
                    key_value_relationship_indicator:,
                    parent_ro:,
                    special_sub_ro_type: nil,
                    depth:)
      new_ro = Scryglass::Ro.new(
        scry_session: self,
        val: array,
        val_type: :bucket,
        key: key,
        key_value_relationship_indicator: key_value_relationship_indicator,
        special_sub_ro_type: special_sub_ro_type,
        parent_ro: parent_ro,
        depth: depth
      )
      return new_ro if array.empty?

      task = Prog::Task.new(max_count: array.count)
      progress_bar << task

      array.each do |o|
        new_ro.sub_ros << roify(o, parent_ro: new_ro, depth: depth + 1)
        task.tick
        print_progress_bar
      end

      new_ro
    end

    def roify_ar_relation(ar_relation,
                          key:,
                          key_value_relationship_indicator:,
                          special_sub_ro_type: nil,
                          parent_ro:,
                          depth:)
      new_ro = Scryglass::Ro.new(
        scry_session: self,
        val: ar_relation,
        val_type: :bucket,
        key: key,
        key_value_relationship_indicator: key_value_relationship_indicator,
        special_sub_ro_type: special_sub_ro_type,
        parent_ro: parent_ro,
        depth: depth
      )
      return new_ro if ar_relation.empty?

      task = Prog::Task.new(max_count: ar_relation.count)
      progress_bar << task

      ar_relation.each do |o|
        new_ro.sub_ros << roify(o, parent_ro: new_ro, depth: depth + 1)
        task.tick
        print_progress_bar
      end

      new_ro
    end

    def roify_hash(hash,
                   key:,
                   key_value_relationship_indicator:,
                   special_sub_ro_type: nil,
                   parent_ro:,
                   depth:)
      new_ro = Scryglass::Ro.new(
        scry_session: self,
        val: hash,
        val_type: :bucket,
        key: key,
        key_value_relationship_indicator: key_value_relationship_indicator,
        special_sub_ro_type: special_sub_ro_type,
        parent_ro: parent_ro,
        depth: depth
      )
      return new_ro if hash.empty?

      task = Prog::Task.new(max_count: hash.count)
      progress_bar << task

      hash.each do |k, v|
        new_ro.sub_ros << roify(v,
              parent_ro: new_ro,
              key: k,
              key_value_relationship_indicator: ' => ',
              depth: depth + 1)
        task.tick
        print_progress_bar
      end

      new_ro
    end

    def smart_open_target_ros
      original_ro_total = all_ros.count
      original_special_sub_ro_count = current_ro.special_sub_ros.count

      if special_command_targets.any?
        task = Prog::Task.new(max_count: special_command_targets.count)
        progress_bar << task

        target_ros = special_command_targets.dup # dup because some commands
        #   create ros which are added to all_ros and then this process starts
        #   adding them to the list of things it tries to act on!
        target_ros.each do |target_ro|
          smart_open(target_ro)
          task.tick
          print_progress_bar
        end
        self.special_command_targets = []
      else
        smart_open(current_ro)

        new_special_sub_ro_count = current_ro.special_sub_ros.count
        new_sub_ros_were_added = new_special_sub_ro_count != original_special_sub_ro_count
        expand!(current_ro) if new_sub_ros_were_added
      end

      new_ro_total = all_ros.count
      recalculate_indeces unless new_ro_total == original_ro_total
    end

    def build_instance_variables_for_target_ros
      original_ro_total = all_ros.count

      if special_command_targets.any?
        task = Prog::Task.new(max_count: special_command_targets.count)
        progress_bar << task

        target_ros = special_command_targets.dup # dup because some commands
        #   create ros which are added to all_ros and then this process starts
        #   adding them to the list of things it tries to act on!
        target_ros.each do |target_ro|
          build_iv_sub_ros_for(target_ro)
          task.tick
          print_progress_bar
        end
        self.special_command_targets = []
      else
        build_iv_sub_ros_for(current_ro)
        expand!(current_ro) if current_ro.iv_sub_ros.any?
      end

      new_ro_total = all_ros.count
      recalculate_indeces unless new_ro_total == original_ro_total
    end

    def build_activerecord_relations_for_target_ros
      original_ro_total = all_ros.count

      if special_command_targets.any?
        task = Prog::Task.new(max_count: special_command_targets.count)
        progress_bar << task

        target_ros = special_command_targets.dup # dup because some commands
        #   create ros which are added to all_ros and then this process starts
        #   adding them to the list of things it tries to act on!
        target_ros.each do |target_ro|
          build_ar_sub_ros_for(target_ro)
          task.tick
          print_progress_bar
        end
        self.special_command_targets = []
      else
        build_ar_sub_ros_for(current_ro)
        expand!(current_ro) if current_ro.ar_sub_ros.any?
      end
      new_ro_total = all_ros.count

      recalculate_indeces unless new_ro_total == original_ro_total
    end

    def build_enum_children_for_target_ros
      original_ro_total = all_ros.count

      if special_command_targets.any?
        task = Prog::Task.new(max_count: special_command_targets.count)
        progress_bar << task

        target_ros = special_command_targets.dup # dup because some commands
        #   create ros which are added to all_ros and then this process starts
        #   adding them to the list of things it tries to act on!
        target_ros.each do |target_ro|
          build_enum_sub_ros_for(target_ro)
          task.tick
          print_progress_bar
        end
        self.special_command_targets = []
      else
        build_enum_sub_ros_for(current_ro)
        expand!(current_ro) if current_ro.enum_sub_ros.any?
      end

      new_ro_total = all_ros.count
      recalculate_indeces unless new_ro_total == original_ro_total
    end

    def smart_open(ro)
      build_ar_sub_ros_for(ro) ||
      build_iv_sub_ros_for(ro) ||
      build_enum_sub_ros_for(ro)
    end

    def recalculate_indeces
      all_ordered_ros = []
      scanning_ro = top_ro

      task = Prog::Task.new(max_count: all_ros.count)
      progress_bar << task

      while scanning_ro
        all_ordered_ros << scanning_ro
        next_ro = scanning_ro.next_ro_without_using_index
        scanning_ro = next_ro
        task.tick
        print_progress_bar
      end

      self.all_ros = all_ordered_ros
      all_ros.each.with_index { |ro, i| ro.index = i }
      task.force_finish # Just in case
    end

    def build_iv_sub_ros_for(ro)
      return if ro.iv_sub_ros.any?

      iv_names = ro.value.instance_variables
      return if iv_names.empty?

      prog_task = Prog::Task.new(max_count: iv_names.count)
      progress_bar << prog_task

      iv_names.each do |iv_name|
        iv_value = rescue_to_viewwrapped_error do
                     ro.value.instance_variable_get(iv_name)
                   end
        iv_key = Scryglass::ViewWrapper.new(iv_name,
                                            string: iv_name.to_s) # to_s removes ':'
        ro.sub_ros << roify(iv_value,
                            parent_ro: ro,
                            key: iv_key,
                            key_value_relationship_indicator: ' : ',
                            special_sub_ro_type: :iv,
                            depth: ro.depth + 1)
        prog_task.tick
        print_progress_bar
      end

      true
    end

    def build_ar_sub_ros_for(ro)
      return if ro.ar_sub_ros.any?
      return unless ro.value.class.respond_to?(:reflections)

      reflections = ro.value.class.reflections

      include_empty_associations =
        Scryglass.config.include_empty_associations
      include_through_associations =
        Scryglass.config.include_through_associations
      include_scoped_associations =
        Scryglass.config.include_scoped_associations
      show_association_types =
        Scryglass.config.show_association_types

      through_filter = lambda do |info|
        include_through_associations || !info.options[:through]
      end

      scope_filter = lambda do |info|
        include_scoped_associations || !info.scope
        # This... `info.scope`
        #   is to get rid of extraneous custom scoped associations
        #   like current_primary_phone_number_record.
      end

      direct_close_reflections = reflections.select do |_, info|
                                   through_filter.call(info) &&
                                     scope_filter.call(info)
                                 end

      relation_names = direct_close_reflections.keys
      return if relation_names.empty?

      task = Prog::Task.new(max_count: relation_names.count)
      progress_bar << task

      direct_close_reflections.sort_by { |relation_name, _info| relation_name }
                              .each do |relation_name, info|
        ar_value = Hexes.hide_db_outputs do
          rescue_to_viewwrapped_error do
            ro.value.send(relation_name)
          end
        end

        relationship_type = info.macro.to_s.split('_')
                                .map { |s| s[0].upcase }.join('')
        relationship_type = "(#{relationship_type})"

        is_through = info.options.keys.include?(:through)
        if include_through_associations
          through_indicator = is_through ? '(t)' : '   '
        end

        is_scoped = !!info.scope
        if include_scoped_associations
          scoped_indicator = is_scoped ? '(s)' : '   '
        end

        relation_representation =
          if show_association_types
            "#{relationship_type}#{through_indicator}#{scoped_indicator} #{relation_name}"
          else
            relation_name.to_s
          end

        if (!ar_value || (ar_value.respond_to?(:empty?) && ar_value.empty?)) || include_empty_associations
          ar_key = Scryglass::ViewWrapper.new(
            relation_name,
            string: relation_representation
          )
          ro.sub_ros << roify(ar_value,
                              parent_ro: ro,
                              key: ar_key,
                              key_value_relationship_indicator: ': ',
                              special_sub_ro_type: :ar,
                              depth: ro.depth + 1)
        end

        task.tick
        print_progress_bar
      end

      true if ro.ar_sub_ros.any?
    end

    def build_enum_sub_ros_for(ro)
      return if ro.enum_sub_ros.any?
      return if ro.bucket?
      return unless ro.value.is_a?(Enumerable)

      pretend_klass = if ro.value.respond_to?(:keys)
                        Hash
                      elsif ro.value.respond_to?(:each)
                        Array
                      end

      if pretend_klass == Hash
        key_names = ro.value.keys
        return if key_names.empty?

        prog_task = Prog::Task.new(max_count: key_names.count)
        progress_bar << prog_task

        ro.value.each do |key, value|
          ro.sub_ros << roify(value,
                              parent_ro: ro,
                              key: key,
                              key_value_relationship_indicator: ' => ',
                              special_sub_ro_type: :enum,
                              depth: ro.depth + 1)
          prog_task.tick
          print_progress_bar
        end
      elsif pretend_klass == Array
        return if ro.value.count.zero?

        prog_task = Prog::Task.new(max_count: ro.value.count)
        progress_bar << prog_task

        ro.value.each do |value|
          ro.sub_ros << roify(value,
                              parent_ro: ro,
                              special_sub_ro_type: :enum,
                              depth: ro.depth + 1)
          prog_task.tick
          print_progress_bar
        end
      end

      true
    end

    def rescue_to_viewwrapped_error
      begin
        successful_yielded_return = yield
      rescue => e
        legible_error_string = [e.message, *e.backtrace].join("\n")
        viewwrapped_error = Scryglass::ViewWrapper.new(
          legible_error_string,
          string: '«ERROR»'
        )
      ensure
        viewwrapped_error || successful_yielded_return
      end
    end
  end
end
