# frozen_string_literal: true

# ==============================================================================
# Bánk's Repository - JSON quirks_mode Kompatibilitási Javítás
# ==============================================================================
# Megelőzi az "unknown keyword: quirks_mode" kivételt a Rails 7.1 süti és
# munkamenet-visszafejtési folyamataiban a JSON gem újabb verziói mellett.
# ==============================================================================

require "json"

module JSON
  class << self
    if method_defined?(:load)
      alias_method :_original_load_without_quirks, :load
      def load(source, proc = nil, options = {})
        if options.is_a?(Hash)
          opts = options.dup
          opts.delete(:quirks_mode)
          opts.delete("quirks_mode")
          _original_load_without_quirks(source, proc, opts)
        else
          _original_load_without_quirks(source, proc, options)
        end
      end
    end

    if method_defined?(:parse)
      alias_method :_original_parse_without_quirks, :parse
      def parse(source, opts = {})
        if opts.is_a?(Hash)
          o = opts.dup
          o.delete(:quirks_mode)
          o.delete("quirks_mode")
          _original_parse_without_quirks(source, o)
        else
          _original_parse_without_quirks(source, opts)
        end
      end
    end
  end
end
