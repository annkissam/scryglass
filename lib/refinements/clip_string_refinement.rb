module ClipStringRefinement
  refine String do
    using AnsilessStringRefinement

    # Warning: Still not going to work nicely if a string ends in an ansi code!
    def clip_at(clip_length, ignore_ansi_codes: false)
      length_method = ignore_ansi_codes ? :ansiless_length : :length
      original_length = send(length_method)

      clipped_string = if ignore_ansi_codes
                         self.ansi_slice(0...clip_length)
                       else
                         self[0...clip_length]
                       end
      if clipped_string.send(length_method) < original_length
        clipped_string =
          clipped_string.mark_as_abbreviated(ignore_ansi_codes: ignore_ansi_codes)
      end

      clipped_string
    end

    def ansiless_clip_at(clip_length)
      self.clip_at(clip_length, ignore_ansi_codes: true)
    end

    # Warning: Still not going to work nicely if a string ends in an ansi code!
    def mark_as_abbreviated(ignore_ansi_codes: false)
      self_dup = dup

      if ignore_ansi_codes
        self_dup.ansiless_set!(-1, '…') if self_dup.ansiless_pick(-1)
        self_dup.ansiless_set!(-2, '…') if self_dup.ansiless_pick(-2)
      else
        self_dup[-1] = '…' if self_dup[-1]
        self_dup[-2] = '…' if self_dup[-2]
      end

      self_dup
    end
  end
end
