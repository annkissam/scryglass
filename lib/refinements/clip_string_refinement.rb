module ClipStringRefinement
  refine String do
    using AnsilessStringRefinement

    # Warning: Still not going to work nicely if a string ends in an ansi code!
    def clip_at(clip_length, ignore_ansi_codes: false)
      length_method = ignore_ansi_codes ? :ansiless_length : :length
      original_length = send(length_method)
      ansi_length = ignore_ansi_codes ? length - ansiless_length : 0
      slice_length = clip_length + ansi_length
      clipped_string = self[0...slice_length]
      if clipped_string.send(length_method) < original_length
        clipped_string = clipped_string.mark_as_abbreviated
      end

      clipped_string
    end

    # Warning: Still not going to work nicely if a string ends in an ansi code!
    def mark_as_abbreviated
      self_dup = dup
      self_dup[-1] = '…' if self_dup[-1]
      self_dup[-2] = '…' if self_dup[-2]
      self_dup
    end
  end
end
