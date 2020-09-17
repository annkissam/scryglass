module ArrayFitToRefinement
  refine Array do
    using ClipStringRefinement
    using AnsilessStringRefinement
    # Warning: Still not going to work nicely if a string ends in an ansi code!
    def fit_to(string_length_goal, fill: ' ', ignore_ansi_codes: true)
      string_array = self.map(&:to_s) # This also acts to dup
      length_method = ignore_ansi_codes ? :ansiless_length : :length
      length_result = string_array.join('').send(length_method)


      if length_result > string_length_goal
        string_array.compress_to(string_length_goal, ignore_ansi_codes: ignore_ansi_codes)
      elsif length_result < string_length_goal
        string_array.expand_to(string_length_goal, ignore_ansi_codes: ignore_ansi_codes, fill: fill)
      else # If it joins to the right length already, we still want to return the expected number of strings.
        spacers = [''] * (string_array.count - 1)
        string_array.zip(spacers).flatten.compact
      end
    end

    # Warning: Still not going to work nicely if a string ends in an ansi code!
    def compress_to(string_length_goal, ignore_ansi_codes:)
      working_array = self.map(&:to_s)
      original_string_count = self.count
      spacers = [''] * (original_string_count - 1)
      length_method = ignore_ansi_codes ? :ansiless_length : :length

      ## Ensure the strings are short enough to fit:
      slider = 0
      while working_array.join('').send(length_method) > string_length_goal
        longest_string_length = working_array.map { |s| s.send(length_method) }.max
        slider_index = slider % working_array.count
        if working_array[slider_index].send(length_method) >= longest_string_length
          working_array[slider_index] =
            working_array[slider_index].clip_at(working_array[slider_index].send(length_method) - 1,
                                                ignore_ansi_codes: ignore_ansi_codes)
        end
        slider += 1
      end

      working_array.zip(spacers).flatten.compact
    end

    def expand_to(string_length_goal, ignore_ansi_codes:, fill:)
      original_string_count = self.count
      working_array = self.map(&:to_s)
      spacers = [''] * (original_string_count - 1)
      length_method = ignore_ansi_codes ? :ansiless_length : :length

      ## Ensure the spacers are large enough to fill out to string_length_goal
      space_to_fill = string_length_goal - working_array.join('').send(length_method)
      first_pass_spacer_length = space_to_fill / spacers.count
      spacers.map! { fill * first_pass_spacer_length }

      ## Distribute the remaining space evenly among the last n spacers
      remaining_space = space_to_fill - spacers.join('').send(length_method)
      if remaining_space.positive?
        spacers =
          spacers[0...-remaining_space] +
          spacers[-remaining_space..-1].map! { |spacer| spacer + ' ' } #each { |task| task.working_length += 1 }
      end

      working_array.zip(spacers).flatten.compact
    end
  end
end
