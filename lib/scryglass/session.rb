# frozen_string_literal: true

class Scryglass::Session
  include Scryglass::RoBuilder

  using AnsilessStringRefinement

  attr_accessor :all_ros, :current_ro, :special_command_targets

  attr_accessor :current_view_coords, :current_lens, :current_subject_type,
                :view_panels, :current_panel_type,
                :progress_bar, :current_warning_messages

  attr_accessor :user_signals, :last_search, :number_to_move

  attr_accessor :session_manager, :signal_to_manager, :session_is_current,
                :tab_icon, :session_view_start_time

  CURSOR_CHARACTER = '–' # These are en dashes (alt+dash), not hyphens or em dashes.

  SEARCH_PROMPT = "\e[7mSearch for (regex, case-sensitive):  /\e[00m"

  VARNAME_PROMPT = "\e[7mName your object(s):  @\e[00m"

  SUBJECT_TYPES = [
    :value,
    :key
  ].freeze

  CSI = "\e[" # "(C)ontrol (S)equence (I)ntroducer" for ANSI sequences

  KEY_MAP = {
    escape: 'esc', # Not a normal keystroke, see: genuine_escape_key_press
    ctrl_c: "\u0003",
    quit_session: 'q',
    delete_session_tab: 'Q',
    change_session_right: "\t", # Tab
    change_session_left: 'Z', # Shift+Tab (well, one of its signals, after "\e" and "[")
    digit_1: '1',
    digit_2: '2',
    digit_3: '3',
    digit_4: '4',
    digit_5: '5',
    digit_6: '6',
    digit_7: '7',
    digit_8: '8',
    digit_9: '9',
    digit_0: '0',
    move_cursor_up: 'A',     # Up arrow (well, one of its signals, after "\e" and "[")
    move_cursor_down: 'B', # Down arrow (well, one of its signals, after "\e" and "[")
    open_bucket: 'C',     # Right arrow (well, one of its signals, after "\e" and "[")
    close_bucket: 'D',     # Left arrow (well, one of its signals, after "\e" and "[")
    homerow_move_cursor_up: 'k',   # To be like VIM arrow keys
    homerow_move_cursor_up_fast: 'K',   # To be like VIM arrow keys
    homerow_move_cursor_down: 'j', # To be like VIM arrow keys
    homerow_move_cursor_down_fast: 'J', # To be like VIM arrow keys
    homerow_open_bucket: 'l',      # To be like VIM arrow keys
    homerow_close_bucket: 'h',     # To be like VIM arrow keys
    # Note, shift-UP and shift-DOWN are not here, as those work very
    #   differently: by virtue of the type-a-number-first functionality.
    toggle_view_panel: ' ',
    switch_lens: '>',
    switch_subject_type: '<',
    move_view_up: 'w',
    move_view_down: 's',
    move_view_left: 'a',
    move_view_right: 'd',
    move_view_up_fast: '∑', # Alt+w
    move_view_down_fast: 'ß', # Alt+s
    move_view_left_fast: 'å', # Alt+a
    move_view_right_fast: '∂', # Alt+d
    control_screen: '?',
    build_instance_variables: '@',
    build_ar_relations: '.',
    build_enum_children: '(',
    smart_open: 'o',
    select_siblings: '|',
    select_all: '*',
    select_current: '-',
    start_search: '/',
    continue_search: 'n',
    return_objects: "\r", # [ENTER],
    name_objects: "="
  }.freeze

  PATIENT_ACTIONS = [
    :control_screen,
    :escape,
    :name_objects,
  ].freeze

  def initialize(seed)
    self.all_ros = []
    self.current_lens = 0
    self.current_subject_type = :value
    self.current_panel_type = :tree
    self.special_command_targets = []
    self.number_to_move = ''
    self.user_signals = []
    self.progress_bar = Prog::Pipe.new
    self.current_warning_messages = []
    self.session_manager = nil
    self.signal_to_manager = nil
    self.tab_icon = nil
    self.session_is_current = false
    self.session_view_start_time = nil

    top_ro = roify(seed, parent_ro: nil, depth: 1)
    top_ro.has_cursor = true
    self.current_ro = top_ro

    expand!(top_ro)

    self.view_panels = {
      tree: Scryglass::TreePanel.new(scry_session: self),
      lens: Scryglass::LensPanel.new(scry_session: self),
    }
  end

  def top_ro
    all_ros.first
  end

  def last_keypress
    last_two_signals = user_signals.last(2)
    last_two_signals.last || last_two_signals.first
  end

  def run_scry_ui
    redraw = true
    signal_to_manager = nil
    self.session_view_start_time = Time.now # For this particular tab/session

    ## On hold: Record/Playback Functionality:
    # case actions
    # when :record
    #   $scry_session_actions_performed = []
    # when :playback
    #   if $scry_session_actions_performed.blank?
    #     raise 'Could not find recording of previous session\'s actions'
    #   end
    #   @input_stack = $scry_session_actions_performed.dup
    # end

    # We print a full screen of lines so the first call of draw_screen doesn't
    #   write over any previous valuable content the user had in the console.
    print Hexes.opacify_screen_string(Hexes.simple_screen_slice(boot_screen))

    while true
      draw_screen if redraw
      redraw = true

      ## On hold: Record/Playback Functionality:
      # case actions
      # when :record
      #   self.user_input = $stdin.getch
      #   $scry_session_actions_performed << user_input
      # when :playback
      #   if @input_stack.any? # (IV to be easily accessible for debugging)
      #     self.user_input = @input_stack.shift
      #     sleep 0.05
      #   else
      #     self.user_input = $stdin.getch
      #   end
      # else
      #   self.user_input = $stdin.getch
      # end

      new_signal = fetch_user_signal

      wait_start_time = Time.now

      case new_signal
      when nil
      when KEY_MAP[:escape]
        case current_panel_type
        when :lens
          self.current_panel_type = :tree
        when :tree
          clear_tracked_values
        end
      when KEY_MAP[:ctrl_c]
        set_console_cursor_below_content
        raise IRB::Abort, 'Ctrl+C Detected'
      when KEY_MAP[:quit_session]
        self.signal_to_manager = :quit
        return
      when KEY_MAP[:delete_session_tab]
        self.signal_to_manager = :delete
        return
      when KEY_MAP[:control_screen]
        remain_in_scry_session = run_help_screen_ui
        unless remain_in_scry_session
          self.signal_to_manager = :quit_from_help
          return
        end
      when KEY_MAP[:digit_1]
        self.number_to_move += '1'
        # This allows you to type multi-digit number very
        #   quickly and still have it process all the digits:
        redraw = false
      when KEY_MAP[:digit_2]
        self.number_to_move += '2'
        redraw = false
      when KEY_MAP[:digit_3]
        self.number_to_move += '3'
        redraw = false
      when KEY_MAP[:digit_4]
        self.number_to_move += '4'
        redraw = false
      when KEY_MAP[:digit_5]
        self.number_to_move += '5'
        redraw = false
      when KEY_MAP[:digit_6]
        self.number_to_move += '6'
        redraw = false
      when KEY_MAP[:digit_7]
        self.number_to_move += '7'
        redraw = false
      when KEY_MAP[:digit_8]
        self.number_to_move += '8'
        redraw = false
      when KEY_MAP[:digit_9]
        self.number_to_move += '9'
        redraw = false
      when KEY_MAP[:digit_0]
        if number_to_move[0] # You can append zeros to existing number_to_move...
          self.number_to_move += '0'
          redraw = false
        else # ...but otherwise it's understood to be a view||cursor reset.
          reset_the_view_or_cursor
        end

      when KEY_MAP[:move_cursor_up]
        move_cursor_up_action
      when KEY_MAP[:move_cursor_down]
        move_cursor_down_action
      when KEY_MAP[:open_bucket]
        expand_targets
      when KEY_MAP[:close_bucket]
        collapse_targets

      when KEY_MAP[:homerow_move_cursor_up]
        move_cursor_up_action
      when KEY_MAP[:homerow_move_cursor_up_fast]
        move_cursor_up_action(12) # 12 matches the digits provided by shift+up
      when KEY_MAP[:homerow_move_cursor_down]
        move_cursor_down_action
      when KEY_MAP[:homerow_move_cursor_down_fast]
        move_cursor_down_action(12) # 12 matches the digits provided by shift+down
      when KEY_MAP[:homerow_open_bucket]
        expand_targets
      when KEY_MAP[:homerow_close_bucket]
        collapse_targets

      when KEY_MAP[:toggle_view_panel]
        toggle_view_panel
      when KEY_MAP[:switch_lens]
        scroll_lens_type
      when KEY_MAP[:switch_subject_type]
        toggle_current_subject_type

      when KEY_MAP[:move_view_up]
        current_view_panel.move_view_up(5)
      when KEY_MAP[:move_view_down]
        current_view_panel.move_view_down(5)
      when KEY_MAP[:move_view_left]
        current_view_panel.move_view_left(5)
      when KEY_MAP[:move_view_right]
        current_view_panel.move_view_right(5)

      when KEY_MAP[:move_view_up_fast]
        current_view_panel.move_view_up(50)
      when KEY_MAP[:move_view_down_fast]
        current_view_panel.move_view_down(50)
      when KEY_MAP[:move_view_left_fast]
        current_view_panel.move_view_left(50)
      when KEY_MAP[:move_view_right_fast]
        current_view_panel.move_view_right(50)

      when KEY_MAP[:build_instance_variables]
        build_instance_variables_for_target_ros
        tree_view.slide_view_to_cursor # Just a nice-to-have
      when KEY_MAP[:build_ar_relations]
        build_activerecord_relations_for_target_ros
        tree_view.slide_view_to_cursor # Just a nice-to-have
      when KEY_MAP[:build_enum_children]
        build_enum_children_for_target_ros
        tree_view.slide_view_to_cursor # Just a nice-to-have
      when KEY_MAP[:smart_open]
        smart_open_target_ros
        tree_view.slide_view_to_cursor # Just a nice-to-have

      when KEY_MAP[:select_siblings]
        sibling_ros = if current_ro.top_ro?
                        [top_ro]
                      else
                        current_ro.parent_ro.sub_ros.dup
                        # ^If we don't dup,
                        #   then '-' can remove ros from `sub_ros`.
                      end
        if special_command_targets.sort == sibling_ros.sort
          self.special_command_targets = []
        else
          self.special_command_targets = sibling_ros
        end
      when KEY_MAP[:select_all]
        all_the_ros = all_ros.dup
        # ^If we don't dup,
        #   then '-' can remove ros from all_ros.
        if special_command_targets.sort == all_the_ros.sort
          self.special_command_targets = []
        else
          self.special_command_targets = all_the_ros
        end
      when KEY_MAP[:select_current]
        if special_command_targets.include?(current_ro)
          special_command_targets.delete(current_ro)
        else
          special_command_targets << current_ro
        end

      when KEY_MAP[:start_search]
        initiate_search
      when KEY_MAP[:continue_search]
        if last_search
          go_to_next_search_result
        else
          message = { text: 'No Search has been entered', end_time: Time.now + 2 }
          self.current_warning_messages << message
        end

      when KEY_MAP[:change_session_right]
        self.signal_to_manager = :change_session_right
        return
      when KEY_MAP[:change_session_left]
        self.signal_to_manager = :change_session_left
        return
      when KEY_MAP[:name_objects]
        name_subjects_of_target_ros
      when KEY_MAP[:return_objects]
        self.signal_to_manager = :return
        subjects = subjects_of_target_ros
        self.special_command_targets = []
        return subjects
      end

      beep_if_user_had_to_wait(wait_start_time)
    end
  end

  def set_console_cursor_below_content(floor_the_cursor:)
    if floor_the_cursor
      screen_height, _screen_width = $stdout.winsize
      $stdout.write "#{CSI}#{screen_height};1H\n" # (Moves console cursor to bottom left corner, then one more)
      return
    end

    bare_screen_string =
      current_view_panel.visible_header_string + "\n" +
      current_view_panel.visible_body_string
    split_lines = bare_screen_string.split("\n")
    rows_filled = split_lines.count
    $stdout.write "#{CSI}#{rows_filled};1H\n" # Moves console cursor to bottom
                                              #   of *content*, then one more.
  end

  def tab_string
    top_ro_preview = top_ro.value_string
    tab = if session_is_current
            "\e[7m #{tab_icon}: #{top_ro_preview} \e[00m"
          else
            " \e[7m#{tab_icon}:\e[00m #{top_ro_preview} "
          end
    tab
  end

  def subjects_of_target_ros
    if special_command_targets.any?
      return special_command_targets.map(&:current_subject)
    end

    current_ro.current_subject
  end

  private

  def beep_if_user_had_to_wait(wait_start_time)
    patient_keys = KEY_MAP.slice(*PATIENT_ACTIONS).values
    user_has_waited_at_least_four_seconds =
      Time.now - wait_start_time > 4 &&
      !patient_keys.include?(last_keypress)
    print "\a" if user_has_waited_at_least_four_seconds # (Audio 'beep')
  end

  def initiate_search
    _screen_height, screen_width = $stdout.winsize
    $stdout.write "#{CSI}1;1H" # (Moves console cursor to top left corner)
    $stdout.print ' ' * screen_width
    $stdout.write "#{CSI}1;1H" # (Moves console cursor to top left corner)
    $stdout.print SEARCH_PROMPT
    $stdout.write "#{CSI}1;#{SEARCH_PROMPT.ansiless_length + 1}H" # (Moves
    #   console cursor to just after the search prompt, before user types)
    query = $stdin.gets.chomp
    unless query.empty?
      self.last_search = query
      go_to_next_search_result
    end
  end

  def move_cursor_up_action(action_count = nil)
    action_count ||= !number_to_move.empty? ? number_to_move.to_i : 1
    navigate_up_multiple(action_count)

    self.number_to_move = ''
    tree_view.slide_view_to_cursor
  end

  def move_cursor_down_action(action_count = nil)
    action_count ||= !number_to_move.empty? ? number_to_move.to_i : 1
    navigate_down_multiple(action_count)

    self.number_to_move = ''
    tree_view.slide_view_to_cursor
  end

  def clear_tracked_values
    self.special_command_targets = []
    self.last_search = nil
    self.number_to_move = ''
  end

  def print_progress_bar
    screen_height, _screen_width = $stdout.winsize
    bar = progress_bar.to_s
    $stdout.write "#{CSI}#{screen_height};1H" # (Moves console cursor to bottom left corner)
    print bar unless bar.tr(' ', '').empty?
  end

  def print_current_warning_messages
    return if current_warning_messages.empty?

    $stdout.write "#{CSI}1;1H" # (Moves console cursor to top left corner)
    wing = ' ' * 3

    self.current_warning_messages.reject! { |message| Time.now > message[:end_time] }
    messages = current_warning_messages.map { |message| message[:text] }
    print messages.map { |message| "\e[7m#{wing + message + wing}\e[00m" }.join("\n")
  end

  def print_session_tabs_bar_if_changed
    seconds_in_tab = Time.now - session_view_start_time
    if seconds_in_tab < 2
      $stdout.write "#{CSI}1;1H" # (Moves console cursor to top left corner)
      print session_manager.session_tabs_bar
    end
  end

  def current_view_panel
    view_panels[current_panel_type]
  end

  def tree_view
    view_panels[:tree]
  end

  def lens_view
    view_panels[:lens]
  end

  def display_active_searching_indicator
    $stdout.write "#{CSI}1;1H" # (Moves console cursor to top left corner)
    message = ' Searching... '
    pad = SEARCH_PROMPT.length - message.length
    wing = '-' * (pad / 2)

    $stdout.write "\e[7m#{wing + message + wing}\e[00m"
  end

  def go_to_next_search_result
    display_active_searching_indicator

    cut_point = current_ro.index
    search_set = ((cut_point + 1)...all_ros.count).to_a + (0...cut_point).to_a

    task = Prog::Task.new(max_count: search_set.count)
    progress_bar << task

    index_of_next_match = search_set.find do |index|
      scanned_ro = all_ros[index]
      task.tick
      print_progress_bar
      scanned_ro.key_string =~ /#{last_search}/ ||
        (scanned_ro.nugget? && scanned_ro.value_string =~ /#{last_search}/)
    end
    task.force_finish

    if index_of_next_match
      next_found_ro = all_ros[index_of_next_match]
      move_cursor_to(next_found_ro)

      scanning_ro = next_found_ro
      while scanning_ro.parent_ro
        expand!(scanning_ro.parent_ro)
        scanning_ro = scanning_ro.parent_ro
      end

      tree_view.recalculate_boundaries # Yes, necessary :)
      lens_view.recalculate_boundaries # Yes, necessary :)
      tree_view.current_view_coords = { y: 0, x: 0 }
      tree_view.slide_view_to_cursor
    else
      message = { text: 'No Match Found', end_time: Time.now + 2 }
      self.current_warning_messages << message
    end
  end

  def fetch_user_signal
    previous_signal = user_signals.last
    new_signal =
      begin
        Timeout.timeout(0.3) { $stdin.getch }
      rescue Timeout::Error
        nil
      end

    ## Since many keys, including arrow keys, result in several signals being
    ##   sent (e.g. DOWN: "\e" then "[" then "B" in RAPID succession), the
    ##   *pause* after a genuine escape key press (also "\e") is the only way
    ##   to distinguish it precisely.
    genuine_escape_key_press = new_signal.nil? && previous_signal == "\e"
    if genuine_escape_key_press
      new_signal = 'esc'
    end

    user_signals << new_signal unless new_signal.nil? && previous_signal.nil?

    new_signal
  end

  def run_help_screen_ui
    screen_height, _screen_width = $stdout.winsize

    in_help_screen = true
    current_help_screen_index = 0
    help_screens = [Scryglass::HELP_SCREEN, Scryglass::HELP_SCREEN_ADVANCED]

    while in_help_screen
      current_help_screen = help_screens[current_help_screen_index]
      sliced_help_screen = Hexes.simple_screen_slice(current_help_screen)
      help_screen_string = Hexes.opacify_screen_string(sliced_help_screen)
      Hexes.overwrite_screen(help_screen_string)

      new_signal = fetch_user_signal

      case new_signal
      when nil
      when KEY_MAP[:escape]
        return true
      when KEY_MAP[:control_screen]
        current_help_screen_index += 1
      when KEY_MAP[:quit_session]
        $stdout.write "#{CSI}#{screen_height};1H" # (Moves console cursor to
        #   bottom left corner). This helps 'q' not print the console prompt at
        #   the top of the screen, overlapping with the old display.
        return false
      when KEY_MAP[:ctrl_c]
        screen_height, _screen_width = $stdout.winsize
        puts "\n" * screen_height
        raise IRB::Abort, 'Ctrl+C Detected'
      end

      current_help_screen = help_screens[current_help_screen_index]
      unless current_help_screen
        return true
      end
    end
  end

  def collapse_targets
    if special_command_targets.any?
      target_ros = special_command_targets.dup # dup because some commands
      #  create ros which are added to all_ros and then this process starts
      #  adding them to the list of things it tries to act on!
      target_ros.each { |target_ro| collapse!(target_ro) }
      self.special_command_targets = []
    elsif current_ro.expanded
      collapse!(current_ro)
    elsif current_ro.parent_ro
      collapse!(current_ro.parent_ro)
    end

    move_cursor_to(current_ro.parent_ro) until current_ro.visible?
    tree_view.slide_view_to_cursor
  end

  def expand_targets
    if special_command_targets.any?
      target_ros = special_command_targets.dup # dup because some commands
      #  create ros which are added to all_ros and then this process starts
      #  adding them to the list of things it tries to act on!
      target_ros.each { |target_ro| expand!(target_ro) }
      self.special_command_targets = []
    else
      expand!(current_ro)
    end
  end

  def reset_the_view_or_cursor
    if current_view_panel.current_view_coords != { x: 0, y: 0 }
      current_view_panel.current_view_coords = { x: 0, y: 0 }
    elsif current_panel_type == :tree
      move_cursor_to(top_ro)
    end
  end

  def draw_screen
    current_view_panel.recalculate_boundaries # This now happens at every screen
    #   draw to account for the user changing the screen size. Otherwise glitch.
    current_view_panel.ensure_correct_view_coords
    screen_string = current_view_panel.screen_string

    Hexes.overwrite_screen(screen_string)
    $stdout.write "#{CSI}1;1H" # Moves terminal cursor to top left corner,
                               #   mostly for consistency.
    print_current_warning_messages
    print_session_tabs_bar_if_changed
  end

  def get_subject_name_from_user
    _screen_height, screen_width = $stdout.winsize
    $stdout.write "#{CSI}1;1H" # (Moves console cursor to top left corner)
    $stdout.print ' ' * screen_width
    $stdout.write "#{CSI}1;1H" # (Moves console cursor to top left corner)
    $stdout.print VARNAME_PROMPT
    $stdout.write "#{CSI}1;#{VARNAME_PROMPT.ansiless_length + 1}H" # (Moves
    #   console cursor to just after the varname prompt, before user types)
    $stdin.gets.chomp
  end

  def name_subjects_of_target_ros
    typed_name = get_subject_name_from_user
    typed_name = typed_name.tr(' ', '')

    if typed_name.empty?
      message = { text: 'Instance Variable name cannot be blank',
                  end_time: Time.now + 2 }
      self.current_warning_messages << message
      print "\a" # (Audio 'beep')
      return
    end

    current_console_binding = session_manager.current_console_binding
    preexisting_iv_names = current_console_binding
                             .eval('instance_variables') # Different than just `.instance_variables`
                             .map { |iv| iv.to_s.tr('@', '') }
    all_method_names = preexisting_iv_names |
                       current_console_binding.methods |
                       current_console_binding.singleton_methods |
                       current_console_binding.private_methods
    conflicting_method_name = all_method_names.find do |method_name|
      pure_method_name = method_name.to_s.tr('=', '')
      typed_name == pure_method_name
    end

    if conflicting_method_name
      message = { text: 'Instance Variable name conflict',
                  end_time: Time.now + 2 }
      self.current_warning_messages << message
      print "\a" # (Audio 'beep')
      return
    end

    set_iv_name_in_console =
      "@#{typed_name} = " \
      "$scry_session_manager.current_session.subjects_of_target_ros"
    current_console_binding.eval(set_iv_name_in_console)
    session_manager.current_binding_tracker.user_named_variables << "@#{typed_name}"

    message = { text: "#{subjects_of_target_ros.class} assigned to:  @#{typed_name}",
                end_time: Time.now + 2 }
    self.current_warning_messages << message

    self.special_command_targets = []
  end

  def navigate_up_multiple(action_count)
    task = Prog::Task.new(max_count: action_count)
    progress_bar << task
    action_count.times do
      navigate_up
      task.tick
      print_progress_bar
    end
  end

  def navigate_down_multiple(action_count)
    task = Prog::Task.new(max_count: action_count)
    progress_bar << task
    action_count.times do
      navigate_down
      task.tick
      print_progress_bar
    end
  end

  def expand!(ro)
    ro.expanded = true if ro.sub_ros.any?
  end

  def collapse!(ro)
    ro.expanded = false if ro.expanded
  end

  def toggle_view_panel
    self.current_panel_type =
      case current_panel_type
      when :tree
        :lens
      when :lens
        :tree
      end
  end

  def toggle_current_subject_type
    self.current_subject_type =
      case current_subject_type
      when :value
        :key
      when :key
        :value
      end
  end

  def scroll_lens_type
    self.current_lens += 1
  end

  def move_cursor_to(new_ro)
    current_ro.has_cursor = false
    new_ro.has_cursor = true
    self.current_ro = new_ro
  end

  def navigate_up
    next_up = current_ro.next_visible_ro_up
    move_cursor_to(next_up) if next_up
  end

  def navigate_down
    next_down = current_ro.next_visible_ro_down
    move_cursor_to(next_down) if next_down
  end

  def boot_screen
    screen_height, screen_width = $stdout.winsize
    stars = (1..(screen_height * screen_width))
            .to_a
            .map { rand(100).zero? ? '.' : ' ' }
    stars.each_slice(screen_width).map { |set| set.join('') }.join("\n")
  end
end
