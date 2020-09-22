# frozen_string_literal: true
module AnsiSliceStringRefinement
  refine String do
    using AnsilessStringRefinement

    ## (This really might not do what you expect if your string has (or you are
    ##   printing) unescaped newlines).
    def ansi_slice(arg1, arg2 = nil) # i.e. like 'test'[0..2] and 'test'[2, 1]
      unless arg1.is_a?(Range)   && arg2.nil? ||
             arg1.is_a?(Integer) && arg1.is_a?(Integer)
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
        # char_is_applicable_ansi_code =
          # (char_is_ansi_escape_code && mock_index <= target_range.max)

        if within_target_range || char_is_ansi_escape_code
          result_string_array << char
        end

        mock_index += 1 unless char_is_ansi_escape_code
      end

      result_string_array.join('')
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
  end
end
