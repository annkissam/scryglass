# frozen_string_literal: true

## Hexes takes care of some console/view/IO work for Scryglass
module Hexes
  using ClipStringRefinement
  using AnsilessStringRefinement
  using ConstantDefinedStringRefinement

  def self._simple_screen_slice(screen_string)
    screen_height, screen_width = $stdout.winsize

    split_lines = screen_string.split("\n")

    ## Here we cut down the (rectangular if opacified) display array in both
    ##   dimensions (into a smaller rectangle), as needed, to fit the view.
    sliced_lines = split_lines.map do |string|
      ansi_length = string.length - string.ansiless_length
      slice_length = screen_width + ansi_length
      string[0, slice_length]
    end
    sliced_list = sliced_lines[0, screen_height]

    sliced_list.join("\n")
  end

  # def visible_body_slice(uncut_string)
  def self.simple_screen_slice(uncut_string)
    screen_height, screen_width = $stdout.winsize

    split_lines = uncut_string.split("\n")

    ## Here we cut down the split string array in both dimensions (into a smaller rectangle), as needed, to fit the view.
    sliced_lines = split_lines.map do |string|
      # string.ansi_slice(current_view_coords[:x], screen_width) || ''
      string.ansi_slice(0, screen_width)
    end
    sliced_list = sliced_lines[0, screen_height]

    sliced_list.join("\n")
  end

  def self.opacify_screen_string(screen_string)
    screen_height, screen_width = $stdout.winsize

    split_lines = screen_string.split("\n")
    rows_filled = split_lines.count

    blank_rows_at_bottom = [screen_height - rows_filled, 0].max

    # This takes all the unfilled spaces left after a newline, and makes them
    #   real spaces, so they'll overwrite whatever was there a second ago. Thus
    #   I don't have to worry about clearing the screen all the time, which was
    #   seemingly causing console chaff and some flickering.
    side_filled_string = split_lines.map do |line|
      margin_to_fill = screen_width - line.ansiless.length
      line + (' ' * margin_to_fill)
    end.join("\e[00m\n") # Also turns off ANSI text formatting at the end of
    #   each line, in case a formatted string had its "turn off formatting" code
    #   cut off from the end. (Reducing the need to end with one at all).

    blank_line = "\n" + (' ' * screen_width)

    side_filled_string + (blank_line * blank_rows_at_bottom)
  end

  def self.stdout_rescue
    @preserved_stdout_dup = $stdout.dup

    begin
      yielded_return = yield
    rescue => e
      # `e` is raised again in the `ensure` block after stdout is safely reset.
    ensure
      $stdout = @preserved_stdout_dup
      raise e if e
    end

    yielded_return
  end

  def self.capture_io(char_limit: nil)
    stdout_rescue do # Ensures that $stdout is reset no matter what
      temporary_io_channel = StringIO.new
      $stdout = temporary_io_channel
      Thread.abort_on_exception = true # So threads can return error text at all

      if char_limit
        background_output_thread = Thread.new { yield } # It's assumed that the
        #   yielded block will be printing something somewhat promptly.

        sleep 0.05 # Give it a head start (Sometimes makes a difference!)

        while temporary_io_channel.size < char_limit
          io_size = temporary_io_channel.size
          sleep 0.05
          new_io_size = temporary_io_channel.size
          break if new_io_size == io_size
        end
        background_output_thread.terminate
      else
        yield
      end

      temporary_io_channel.rewind
      captured_output = temporary_io_channel.read
      captured_output = captured_output.clip_at(char_limit) if char_limit

      captured_output
    end
  end

  def self.overwrite_screen(screen_string)
    csi = "\e["
    $stdout.write "#{csi}s" # Saves terminal cursor position
    $stdout.write "#{csi}1;1H" # Moves terminal cursor to top left corner

    $stdout.print "\r#{screen_string}"
    $stdout.write "#{csi}u" # Restores saved terminal cursor position
  end

  def self.hide_db_outputs
    necessary_constants = ['Logger', 'ActiveRecord::Base']
    necessary_constants_defined = necessary_constants.all?(&:constant_defined?)
    return yield unless necessary_constants_defined

    rails_logger_defined = 'Rails'.constant_defined? && !!Rails.try(:logger)

    ## These are purposefully preserved as global variables so retrieval, in
    ##   debugging or errored usage, is as easy as possible.
    $preserved_ar_base_logger = ActiveRecord::Base.logger.dup
    $preserved_rails_logger = Rails.logger.dup if rails_logger_defined

    begin
      ## Now we create an unused dump string to serve as the output
      ignored_output = StringIO.new
      ignored_log = Logger.new(ignored_output)
      ActiveRecord::Base.logger = ignored_log
      Rails.logger = ignored_log if rails_logger_defined

      yielded_return = yield
    rescue => e
      # `e` is raised again in the `ensure` after displays are safely reset.
    ensure
      ActiveRecord::Base.logger = $preserved_ar_base_logger
      Rails.logger = $preserved_rails_logger if rails_logger_defined
      raise e if e
    end

    yielded_return
  end
end
