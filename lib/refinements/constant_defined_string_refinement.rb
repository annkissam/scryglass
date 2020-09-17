module ConstantDefinedStringRefinement
  refine String do
    def constant_defined?
      begin
        !!Object.const_get(self)
      rescue
        false # Swallow expected error if not defined
      end
    end
  end
end
