module DarwinCore
  module Helpers
    def dwc_filter_text(s)
      s.to_s.gsub( /\s+/, " " ).strip
    end
  end
end
