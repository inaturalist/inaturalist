module DarwinCore
  module Helpers
    def dwc_filter_text(s)
      s.to_s.gsub(/\r\n|\n|\t/, " ")
    end
  end
end
