module AnsilessStringRefinement
  refine String do
    def ansiless
      gsub(/\e\[[\d\;]*m/, '')
    end

    def ansiless_length
      ansiless.length
    end
  end
end
