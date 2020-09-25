module AnsilessStringRefinement
  refine String do
    def ansiless
      gsub(/\e\[[\d\;]*m/, '')
    end

    def ansiless_length
      ansiless.length
    end

    ## Splits string into characters, with each ANSI escape code being its own
    ##   grouped item, like so:
    ##     irb> "PLAIN\e[32mCOLOR\e[0mPLAIN".ansi_string_breakout
    ##     => ["P", "L", "A", "I", "N", "\e[32m", "C", "O", "L", "O", "R",
    ##         "\e[0m", "P", "L", "A", "I", "N"]
    def ansi_string_breakout
      breakout_array = []
      working_self = self.dup

      while working_self[0]
        if (working_self =~ /\e\[[\d\;]*m/) == 0 # if begins with
          end_of_escape_code = (working_self.index('m'))
          leading_escape_code = working_self[0..end_of_escape_code]
          breakout_array << leading_escape_code
          working_self = working_self[(end_of_escape_code + 1)..-1]
        else
          leading_character = working_self[0]
          breakout_array << leading_character
          working_self = working_self[1..-1]
        end
      end

      breakout_array
    end

    def is_ansi_escape_code?
      (self =~ /^\e\[[\d\;]*m$/) == 0
    end

    ## Returns the indexed character of the real string, determined by the index
    ##   given in reference to its ANSIless display form. e.g.:
    ##     > s = "\e[31mTEST\e[00m"
    ##     > puts s
    ##       TEST
    ##     > s.ansiless_pick(1) = 'y'
    ##     > s
    ##       => "\e[31mTyST\e[00m"
    def ansiless_pick(given_index)
      ansiless_self = self.ansiless

      return nil if ansiless_self[given_index].nil?

      given_index = (given_index + ansiless_self.length) if given_index.negative?

      mock_index = 0 # A scanning index that *doesn't* count ANSI codes
      real_index = 0 # A scanning index that *does* count ANSI codes

      ansi_string_array = ansi_string_breakout

      until mock_index == given_index
        while ansi_string_array.first.is_ansi_escape_code?
          real_index += (ansi_string_array.shift.length)
        end

        ansi_string_array.shift

        while ansi_string_array.first.is_ansi_escape_code?
          real_index += (ansi_string_array.shift.length)
        end

        mock_index += 1
        real_index += 1
      end

      self[real_index]
    end

    ## Like ansiless_pick, but it can set that found string character instead
    def ansiless_set!(given_index, string)
      raise ArgumentError, 'First argument must be an Integer' unless given_index.is_a?(Integer)
      raise ArgumentError, 'Second argument must be a String'  unless string.is_a?(String)

      ansiless_self = self.ansiless

      return nil if ansiless_self[given_index].nil?

      given_index = (given_index + ansiless_self.length) if given_index.negative?


      new_string = string.to_s

      mock_index = 0 # A scanning index that *doesn't* count ANSI codes
      real_index = 0 # A scanning index that *does* count ANSI codes

      ansi_string_array = ansi_string_breakout

      until mock_index == given_index
        while ansi_string_array.first.is_ansi_escape_code?
          real_index += (ansi_string_array.shift.length)
        end

        ansi_string_array.shift

        while ansi_string_array.first.is_ansi_escape_code?
          real_index += (ansi_string_array.shift.length)
        end

        mock_index += 1
        real_index += 1
      end

      self[real_index] = new_string
    end

    def ansi_slice(arg1, arg2 = nil) # i.e. like 'test'[0..2] and 'test'[2, 1]
      unless (arg1.is_a?(Range)   && arg2.nil?) ||
             (arg1.is_a?(Integer) && arg2.is_a?(Integer))
      raise ArgumentError, 'ansi_slice takes either a single Range ' \
        'or two integers (index and length) as its arguments.'
      end

      target_range = arg1.is_a?(Range) ? arg1 : (arg1...(arg1 + arg2))

      if target_range.min.negative? || target_range.max.negative?
        raise ArgumentError, 'Range must be entirely positive!'
      end

      args = [arg1, arg2].compact
      return self[*args] if (self =~ /\e\[[\d\;]*m/).nil? # No work need be done

      ## And here we match the normal `:[]` behavior outside of boundaries, e.g:
      ##   irb> 'TEST'[4..9]
      ##   => ""
      ##   irb> 'TEST'[5..9]
      ##   => nil
      return nil if target_range.min > self.ansiless_length

      mock_index = 0 # A scanning index that *doesn't* count ANSI codes
      result_string_array = []

      ansi_string_breakout.each do |char|
        char_is_ansi_escape_code = char.is_ansi_escape_code?
        within_target_range =
          target_range.include?(mock_index)

        if within_target_range || char_is_ansi_escape_code
          result_string_array << char
        end

        mock_index += 1 unless char_is_ansi_escape_code
      end

      result_string_array.join('')
    end
  end
end
