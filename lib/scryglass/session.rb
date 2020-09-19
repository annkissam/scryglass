# frozen_string_literal: true

class Scryglass::Session
  include Scryglass::RoBuilder

  using AnsilessStringRefinement

  attr_accessor :all_ros, :current_ro, :special_command_targets

  attr_accessor :current_view_coords, :current_lens, :current_subject_type,
                :view_panels, :current_panel_type,
                :progress_bar

  attr_accessor :user_signals, :last_search, :number_to_move

  CURSOR_CHARACTER = '–' # These are en dashes (alt+dash), not hyphens or em dashes.

  SEARCH_PROMPT = "\e[7mSearch for (regex, case-sensitive): /\e[00m"

  SESSION_CLOSED_MESSAGE = '(Exited scry! Resume session with `scry` or `scry_resume`)'

  SUBJECT_TYPES = [
    :value,
    :key
  ].freeze

  CSI = "\e[" # "(C)ontrol (S)equence (I)ntroducer" for ANSI sequences

  def initialize(seed)
    self.all_ros = []
    self.current_lens = 0
    self.current_subject_type = :value
    self.current_panel_type = :tree
    self.special_command_targets = []
    self.number_to_move = ''
    self.user_signals = []
    self.progress_bar = Prog::Pipe.new

    top_ro = roify(seed, parent_ro: nil, depth: 1)
    top_ro.has_cursor = true
    self.current_ro = top_ro

    expand!(top_ro)

    self.view_panels = {
      tree: Scryglass::TreePanel.new(scry_session: self),
      lens: Scryglass::LensPanel.new(scry_session: self),
    }
  end

  def run_scry_ui(actions:)
    in_scry_session = true
    redraw = true

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

    while in_scry_session
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
      when 'esc'
        # Escape key functionality!
      when "\u0003"
        set_console_cursor_below_content
        raise IRB::Abort, 'Ctrl+C Detected'
      when 'q'
        in_scry_session = false
        visually_close_ui
      when '1'
        self.number_to_move += '1'
        redraw = false # This allows you to type multi-digit number very
        #   quickly and still have it process all the digits.
      when '2'
        self.number_to_move += '2'
        redraw = false
      when '3'
        self.number_to_move += '3'
        redraw = false
      when '4'
        self.number_to_move += '4'
        redraw = false
      when '5'
        self.number_to_move += '5'
        redraw = false
      when '6'
        self.number_to_move += '6'
        redraw = false
      when '7'
        self.number_to_move += '7'
        redraw = false
      when '8'
        self.number_to_move += '8'
        redraw = false
      when '9'
        self.number_to_move += '9'
        redraw = false
      when '0'
        if number_to_move.present? # You can append zeros to number_to_move...
          self.number_to_move += '0'
          redraw = false
        else # ...but otherwise it's understood to be a view||cursor reset.
          reset_the_view_or_cursor
        end
      when 'A' # Up arrow
        action_count = number_to_move.present? ? number_to_move.to_i : 1
        navigate_up_multiple(action_count)

        self.number_to_move = ''
        lens_view.recalculate_boundaries if current_panel_type == :lens
        tree_view.slide_view_to_cursor
      when 'B' # Down arrow
        action_count = number_to_move.present? ? number_to_move.to_i : 1
        navigate_down_multiple(action_count)

        self.number_to_move = ''
        lens_view.recalculate_boundaries if current_panel_type == :lens
        tree_view.slide_view_to_cursor
      when 'C' # Right arrow
        expand_targets
      when 'D' # Left arrow
        collapse_targets
        lens_view.recalculate_boundaries if current_panel_type == :lens
      when ' '
        toggle_view_panel
        lens_view.recalculate_boundaries if current_panel_type == :lens
      when 'l'
        scroll_lens_type
        lens_view.recalculate_boundaries if current_panel_type == :lens
      when 'L'
        toggle_current_subject_type
        lens_view.recalculate_boundaries if current_panel_type == :lens
      when 'w'
        current_view_panel.move_view_up(5)
      when 's'
        current_view_panel.move_view_down(5)
      when 'a'
        current_view_panel.move_view_left(5)
      when 'd'
        current_view_panel.move_view_right(5)
      when '∑' # Alt+w
        current_view_panel.move_view_up(50)
      when 'ß' # Alt+s
        current_view_panel.move_view_down(50)
      when 'å' # Alt+a
        current_view_panel.move_view_left(50)
      when '∂' # Alt+d
        current_view_panel.move_view_right(50)
      when '?'
        in_scry_session = run_help_screen_ui
      when '@'
        build_instance_variables_for_target_ros
        tree_view.recalculate_boundaries
        tree_view.slide_view_to_cursor # Just a nice-to-have
      when '.'
        build_activerecord_relations_for_target_ros
        tree_view.recalculate_boundaries
        tree_view.slide_view_to_cursor # Just a nice-to-have
      when '('
        build_enum_children_for_target_ros
        tree_view.recalculate_boundaries
        tree_view.slide_view_to_cursor # Just a nice-to-have
      when '|'
        sibling_ros = if current_ro.top_ro?
                        [top_ro]
                      else
                        current_ro.parent_ro.sub_ros.dup # If we don't dup,
                        #   then '-' can remove ros from `sub_ros`.
                      end
        if special_command_targets.sort == sibling_ros.sort
          self.special_command_targets = []
        else
          self.special_command_targets = sibling_ros
        end
      when '*'
        all_the_ros = all_ros.dup # If we don't dup,
        #   then '-' can remove ros from all_ros.
        if special_command_targets.sort == all_the_ros.sort
          self.special_command_targets = []
        else
          self.special_command_targets = all_the_ros
        end
      when '-'
        if special_command_targets.include?(current_ro)
          special_command_targets.delete(current_ro)
        else
          special_command_targets << current_ro
        end
      when '/'
        _screen_height, screen_width = $stdout.winsize
        $stdout.write "#{CSI}1;1H" # (Moves console cursor to top left corner)
        $stdout.print ' ' * screen_width
        $stdout.write "#{CSI}1;1H" # (Moves console cursor to top left corner)
        $stdout.print SEARCH_PROMPT
        $stdout.write "#{CSI}1;#{SEARCH_PROMPT.ansiless_length + 1}H" # (Moves
        #   console cursor to just after the search prompt, before user types)
        query = $stdin.gets.chomp
        if query.present?
          self.last_search = query
          go_to_next_search_result
        end
      when 'n'
        if last_search
          go_to_next_search_result
        else
          $stdout.write "#{CSI}1;1H" # (Moves console cursor to top left corner)
          $stdout.write "\e[7m-- No Search has been entered --\e[00m"
          sleep 2
        end
      when "\r" # [ENTER]
        visually_close_ui
        return subjects_of_target_ros
      end

      print "\a" if Time.now - wait_start_time > 4 && last_keypress != '?' # (Audio 'beep')
    end
  end

  def top_ro
    all_ros.first
  end

  def last_keypress
    last_two_signals = user_signals.last(2)
    last_two_signals.last || last_two_signals.first
  end

  private

  def print_progress_bar
    screen_height, _screen_width = $stdout.winsize
    bar = progress_bar.to_s
    $stdout.write "#{CSI}#{screen_height};1H" # (Moves console cursor to bottom left corner)
    print bar if bar.present?
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

  def colorize(screen_string)
    dot = '•'
    cyan_dot = "\e[36m#{dot}\e[00m" # cyan then back to *default*
    screen_string.gsub!('•', cyan_dot)

    screen_string
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
      $stdout.write "#{CSI}1;1H" # (Moves console cursor to top left corner)
      message = ' No Match Found '
      pad = SEARCH_PROMPT.length - message.length
      wing = '-' * (pad / 2)

      $stdout.write "\e[7m#{wing + message + wing}\e[00m"
      sleep 2
    end
  end

  def fetch_user_signal
    previous_signal = user_signals.last
    new_signal =
      begin
        Timeout.timeout(0.05) { $stdin.getch }
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
      when 'esc'
        # Escape key functionality!
        # return true
      when '?'
        current_help_screen_index += 1
      when 'q'
        $stdout.write "#{CSI}#{screen_height};1H" # (Moves console cursor to
        #   bottom left corner). This helps 'q' not print the console prompt at
        #   the top of the screen, overlapping with the old display.
        return false
      when "\u0003"
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
    tree_view.recalculate_boundaries # TODO: should these be conditional? If they are, I might need a potential tree view recalc after toggling lens view to tree view.
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
    tree_view.recalculate_boundaries
  end

  def reset_the_view_or_cursor
    if current_view_panel.current_view_coords != { x: 0, y: 0 }
      current_view_panel.current_view_coords = { x: 0, y: 0 }
    elsif current_panel_type == :tree
      move_cursor_to(top_ro)
    end
  end

  def draw_screen
    current_view_panel.ensure_correct_view_coords
    screen_string = current_view_panel.screen_string

    screen_string = colorize(screen_string) if Scryglass.config.dot_coloring
    Hexes.overwrite_screen(screen_string)
    $stdout.write "#{CSI}1;1H" # Moves terminal cursor to top left corner,
                               #   mostly for consistency.
  end

  def set_console_cursor_below_content
    bare_screen_string =
      current_view_panel.visible_header_string + "\n" +
      current_view_panel.visible_body_string
    split_lines = bare_screen_string.split("\n")
    rows_filled = split_lines.count
    $stdout.write "#{CSI}#{rows_filled};1H\n" # Moves console cursor to bottom
                                              #   of *content*, then one more.
  end

  def visually_close_ui
    _screen_height, screen_width = $stdout.winsize
    set_console_cursor_below_content
    puts '·' * screen_width, "\n"
    puts SESSION_CLOSED_MESSAGE
  end

  def subjects_of_target_ros
    if special_command_targets.any?
      return_targets = special_command_targets
      self.special_command_targets = []
      return return_targets.map(&:current_subject)
    end

    current_ro.current_subject
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
